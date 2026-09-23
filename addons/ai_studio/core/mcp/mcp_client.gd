@tool
class_name AIStudioMcpClient
extends RefCounted

## MCP client: owns one transport, performs the initialize handshake, keeps the
## tool list, and answers server-initiated requests (roots/list, sampling).
##
## Lifecycle:  new -> connecting -> ready -> closed/error
## Signals:
##   state_changed(state, detail)
##   tools_changed(tools)
##   log_message(level, text)

signal state_changed(state: String, detail: String)
signal tools_changed(tools: Array)
signal log_message(level: String, text: String)

const STATE_IDLE := "idle"
const STATE_CONNECTING := "connecting"
const STATE_READY := "ready"
const STATE_ERROR := "error"
const STATE_CLOSED := "closed"

var name := ""
var definition: Dictionary = {}
var state := STATE_IDLE
var server_info: Dictionary = {}
var server_capabilities: Dictionary = {}
var instructions := ""
var tools: Array = []
var last_error := ""

var transport: RefCounted
var _host: Node
var _next_id := 1
var _pending: Dictionary = {}
var _startup_timeout_ms := 15000
var _tool_timeout_ms := 120000
var _protocol_version := "2025-11-25"
var _roots: Array = []
var _sampling_handler: Callable = Callable()
var _handshake_done := false


func _init(server_name: String, server_definition: Dictionary, host: Node) -> void:
	name = server_name
	definition = AIStudioConfig.normalise_server(server_definition)
	_host = host
	_protocol_version = String(definition.get("protocol_version", _protocol_version))
	_startup_timeout_ms = int(definition.get("startup_timeout_ms", 15000))
	_tool_timeout_ms = int(definition.get("tool_timeout_ms", 120000))
	_roots = definition.get("roots", [])


func set_sampling_handler(handler: Callable) -> void:
	_sampling_handler = handler


func is_ready() -> bool:
	return state == STATE_READY


func tool_count() -> int:
	return tools.size()


# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------

func connect_server() -> Dictionary:
	if state == STATE_CONNECTING:
		return {"ok": false, "error": "already connecting"}
	if state == STATE_READY:
		return {"ok": true, "error": ""}
	_handshake_done = false
	_set_state(STATE_CONNECTING, "starting transport")

	if String(definition.get("transport", "stdio")) == "http":
		transport = AIStudioMcpHttpTransport.new(_host)
	else:
		transport = AIStudioMcpStdioTransport.new()
	transport.message_received.connect(_on_message)
	transport.closed.connect(_on_transport_closed)
	if transport.has_signal("log_line"):
		transport.log_line.connect(func(level: String, text: String): log_message.emit(level, text))

	var started: Dictionary = transport.start(definition)
	if not bool(started.get("ok", false)):
		last_error = String(started.get("error", "transport failed to start"))
		_set_state(STATE_ERROR, last_error)
		return {"ok": false, "error": last_error}

	var init := await _request("initialize", {
		"protocolVersion": _protocol_version,
		"capabilities": {
			"roots": {"listChanged": false},
			"sampling": {},
		},
		"clientInfo": {
			"name": "Godot AI Studio",
			"title": "Godot AI Studio",
			"version": "1.0.0",
		},
	}, _startup_timeout_ms)

	if not bool(init.get("ok", false)):
		last_error = String(init.get("error", "initialize failed"))
		_set_state(STATE_ERROR, last_error)
		_shutdown_transport()
		return {"ok": false, "error": last_error}

	var result: Dictionary = init["result"] if typeof(init["result"]) == TYPE_DICTIONARY else {}
	server_info = result.get("serverInfo", {})
	server_capabilities = result.get("capabilities", {})
	instructions = String(result.get("instructions", ""))
	var agreed := String(result.get("protocolVersion", _protocol_version))
	if transport is AIStudioMcpHttpTransport:
		(transport as AIStudioMcpHttpTransport).protocol_version = agreed

	_send_notification("notifications/initialized", {})
	_handshake_done = true
	if not instructions.is_empty():
		log_message.emit("info", "Server instructions: " + instructions.substr(0, 400))
	_set_state(STATE_CONNECTING, "loading tools")
	await refresh_tools()
	# READY means "usable": the handshake finished *and* the tool list is in.
	_set_state(STATE_READY, "connected to %s %s" % [
		String(server_info.get("name", name)), String(server_info.get("version", ""))])
	return {"ok": true, "error": ""}


func shutdown(reason: String = "disconnected") -> void:
	_shutdown_transport()
	_pending.clear()
	tools = []
	tools_changed.emit(tools)
	if state != STATE_ERROR:
		_set_state(STATE_CLOSED, reason)


func _shutdown_transport() -> void:
	_handshake_done = false
	if transport != null:
		if transport.has_method("stop"):
			transport.stop()
		transport = null


func _on_transport_closed(reason: String) -> void:
	_handshake_done = false
	if state == STATE_READY or state == STATE_CONNECTING:
		last_error = reason
		_set_state(STATE_CLOSED, reason)
	# Wake up anything waiting on a request that will never be answered.
	for id in _pending.keys():
		var entry: Dictionary = _pending[id]
		entry["done"] = true
		entry["result"] = {"ok": false, "result": null, "error": "connection closed: " + reason}
	_pending.clear()


func reload() -> Dictionary:
	shutdown("reload")
	state = STATE_IDLE
	return await connect_server()


# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------

func refresh_tools() -> Array:
	if not _handshake_done or transport == null:
		return []
	var all: Array = []
	var cursor := ""
	var guard := 0
	while true:
		guard += 1
		if guard > 50:
			log_message.emit("warning", "tools/list pagination aborted after 50 pages")
			break
		var params := {}
		if not cursor.is_empty():
			params["cursor"] = cursor
		var res: Dictionary = await _request("tools/list", params, _startup_timeout_ms)
		if not bool(res.get("ok", false)):
			last_error = String(res.get("error", "tools/list failed"))
			log_message.emit("error", "tools/list failed: " + last_error)
			tools = []
			tools_changed.emit(tools)
			return []
		var result: Dictionary = res["result"] if typeof(res["result"]) == TYPE_DICTIONARY else {}
		for t in result.get("tools", []) as Array:
			if typeof(t) != TYPE_DICTIONARY:
				continue
			var entry := {
				"name": String(t.get("name", "")),
				"title": String(t.get("title", "")),
				"description": String(t.get("description", "")),
				"inputSchema": t.get("inputSchema", {"type": "object", "properties": {}}),
				"outputSchema": t.get("outputSchema", null),
				"annotations": t.get("annotations", {}),
			}
			if not String(entry["name"]).is_empty():
				all.append(entry)
		cursor = String(result.get("nextCursor", ""))
		if cursor.is_empty():
			break
	tools = _apply_filter(all)
	tools_changed.emit(tools)
	log_message.emit("info", "%d tool(s) available" % tools.size())
	return tools


func _apply_filter(all: Array) -> Array:
	var allow: Array = definition.get("tool_allow", [])
	var deny: Array = definition.get("tool_deny", [])
	var out: Array = []
	for t in all:
		var tname := String(t["name"])
		if not allow.is_empty() and not _matches_any(tname, allow):
			continue
		if not deny.is_empty() and _matches_any(tname, deny):
			continue
		out.append(t)
	return out


static func _matches_any(tool_name: String, patterns: Array) -> bool:
	for p in patterns:
		var pattern := String(p)
		if pattern == "*" or pattern == tool_name:
			return true
		if pattern.ends_with("*") and tool_name.begins_with(pattern.substr(0, pattern.length() - 1)):
			return true
	return false


## Calls a tool. Returns
## {"ok": bool, "text": String, "content": Array, "is_error": bool, "error": String, "structured": Variant}
func call_tool(tool_name: String, arguments: Dictionary, timeout_ms: int = 0) -> Dictionary:
	if state != STATE_READY and not _handshake_done:
		return {"ok": false, "text": "", "content": [], "is_error": true, "error": "Server '%s' is not connected." % name, "structured": null}
	var res: Dictionary = await _request("tools/call", {"name": tool_name, "arguments": arguments},
		timeout_ms if timeout_ms > 0 else _tool_timeout_ms)
	if not bool(res.get("ok", false)):
		return {"ok": false, "text": "", "content": [], "is_error": true,
			"error": String(res.get("error", "tool call failed")), "structured": null}
	var result: Dictionary = res["result"] if typeof(res["result"]) == TYPE_DICTIONARY else {}
	var content: Array = result.get("content", [])
	var is_error := bool(result.get("isError", false))
	var text := content_to_text(content)
	if result.has("structuredContent"):
		var structured_text := JSON.stringify(result["structuredContent"], "  ")
		if not structured_text.is_empty() and structured_text != "{}":
			text += ("\n\n" if not text.is_empty() else "") + "structuredContent: " + structured_text
	return {
		"ok": not is_error,
		"text": text,
		"content": content,
		"is_error": is_error,
		"error": text if is_error else "",
		"structured": result.get("structuredContent", null),
	}


## Flattens MCP content blocks into readable text (used as the tool result we
## feed back to the model).
static func content_to_text(content: Array) -> String:
	var parts := PackedStringArray()
	for block in content:
		if typeof(block) != TYPE_DICTIONARY:
			parts.append(String(block))
			continue
		match String(block.get("type", "")):
			"text":
				parts.append(String(block.get("text", "")))
			"image":
				parts.append("[image %s, %d bytes of base64]" % [
					String(block.get("mimeType", "image")), String(block.get("data", "")).length()])
			"audio":
				parts.append("[audio %s]" % String(block.get("mimeType", "audio")))
			"resource":
				var res: Dictionary = block.get("resource", {})
				if res.has("text"):
					parts.append(String(res["text"]))
				else:
					parts.append("[resource %s (%s)]" % [String(res.get("uri", "")), String(res.get("mimeType", ""))])
			"resource_link":
				parts.append("[resource link %s]" % String(block.get("uri", "")))
			_:
				parts.append(JSON.stringify(block))
	return "\n".join(parts)


func list_resources() -> Array:
	if state != STATE_READY:
		return []
	var res: Dictionary = await _request("resources/list", {}, _startup_timeout_ms)
	if not bool(res.get("ok", false)):
		return []
	var result: Dictionary = res["result"] if typeof(res["result"]) == TYPE_DICTIONARY else {}
	return result.get("resources", [])


func ping() -> bool:
	if not _handshake_done:
		return false
	var res: Dictionary = await _request("ping", {}, 5000)
	return bool(res.get("ok", false))


# ---------------------------------------------------------------------------
# JSON-RPC plumbing
# ---------------------------------------------------------------------------

func _request(method: String, params: Dictionary, timeout_ms: int) -> Dictionary:
	if transport == null:
		return {"ok": false, "result": null, "error": "transport is not running"}
	var id := _next_id
	_next_id += 1
	_pending[id] = {"done": false, "result": {"ok": false, "result": null, "error": "no response"}}
	if not transport.send(AIStudioJsonRpc.request(id, method, params)):
		_pending.erase(id)
		return {"ok": false, "result": null, "error": "failed to send request"}
	var deadline := Time.get_ticks_msec() + maxi(timeout_ms, 1000)
	while true:
		var entry: Dictionary = _pending.get(id, {})
		if entry.is_empty():
			return {"ok": false, "result": null, "error": "request cancelled"}
		if bool(entry["done"]):
			var out: Dictionary = entry["result"]
			_pending.erase(id)
			return out
		if Time.get_ticks_msec() > deadline:
			_pending.erase(id)
			return {"ok": false, "result": null,
				"error": "Timeout after %.1fs waiting for '%s'" % [timeout_ms / 1000.0, method]}
		await _frame()
	return {"ok": false, "result": null, "error": "request loop ended unexpectedly"}


func _send_notification(method: String, params: Dictionary) -> void:
	if transport != null:
		transport.send(AIStudioJsonRpc.make_notification(method, params))


func _frame() -> void:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		await (loop as SceneTree).process_frame
	else:
		await Engine.get_main_loop().process_frame


func _on_message(message: Dictionary) -> void:
	if AIStudioJsonRpc.is_response(message):
		var id := int(message.get("id", -1))
		if _pending.has(id):
			_pending[id]["result"] = AIStudioJsonRpc.unwrap(message)
			_pending[id]["done"] = true
		return
	if AIStudioJsonRpc.is_request(message):
		_handle_server_request(message)
		return
	if AIStudioJsonRpc.is_notification(message):
		var method := String(message.get("method", ""))
		match method:
			"notifications/tools/list_changed":
				refresh_tools()
			"notifications/message":
				var params: Dictionary = message.get("params", {})
				log_message.emit(String(params.get("level", "info")), String(params.get("data", "")))
			_:
				log_message.emit("debug", "notification: " + method)
		return


## Servers may call back into the editor (roots, sampling, elicitation). We
## implement roots and - when enabled - forward sampling to the configured LLM,
## which is what makes Hermes Agent style servers usable from inside Godot.
func _handle_server_request(message: Dictionary) -> void:
	var method := String(message.get("method", ""))
	var id = message.get("id")
	match method:
		"roots/list":
			transport.send(AIStudioJsonRpc.result(id, {"roots": _roots}))
		"ping":
			transport.send(AIStudioJsonRpc.result(id, {}))
		"sampling/createMessage":
			if _sampling_handler.is_valid():
				var params: Dictionary = message.get("params", {})
				var reply: Dictionary = await _sampling_handler.call(params)
				if bool(reply.get("ok", false)):
					transport.send(AIStudioJsonRpc.result(id, {
						"role": "assistant",
						"content": {"type": "text", "text": String(reply.get("text", ""))},
						"model": String(reply.get("model", "")),
						"stopReason": "endTurn",
					}))
				else:
					transport.send(AIStudioJsonRpc.error(id, -32603, String(reply.get("error", "sampling failed"))))
			else:
				transport.send(AIStudioJsonRpc.error(id, -32601, "Sampling is not enabled in Godot AI Studio settings."))
		"elicitation/create":
			transport.send(AIStudioJsonRpc.error(id, -32601, "Elicitation is not supported by Godot AI Studio."))
		_:
			transport.send(AIStudioJsonRpc.error(id, -32601, "Method not found: " + method))


func _set_state(new_state: String, detail: String) -> void:
	state = new_state
	if new_state == STATE_ERROR:
		last_error = detail
	state_changed.emit(new_state, detail)
