@tool
class_name AIStudioMcpHttpTransport
extends RefCounted

## MCP "Streamable HTTP" transport (spec revision 2025-11-25).
##
## One POST per JSON-RPC message; a server may answer either
##   * Content-Type: application/json          -> a single response object, or
##   * Content-Type: text/event-stream         -> one or more SSE events that
##                                                carry the response.
## The `Mcp-Session-Id` returned by `initialize` is echoed on every later
## request, together with `MCP-Protocol-Version`.

signal message_received(message: Dictionary)
signal closed(reason: String)
signal log_line(level: String, text: String)

var session_id := ""
var protocol_version := "2025-11-25"

var _url := ""
var _headers: Dictionary = {}
var _host: Node
var _running := false
var _timeout_sec := 60.0
var _in_flight := 0


func _init(host: Node) -> void:
	_host = host


func kind() -> String:
	return "http"


func is_running() -> bool:
	return _running


func describe() -> String:
	return _url


func start(definition: Dictionary) -> Dictionary:
	_url = String(definition.get("url", "")).strip_edges()
	if _url.is_empty():
		return {"ok": false, "error": "No URL configured for this HTTP server."}
	if not (_url.begins_with("http://") or _url.begins_with("https://")):
		return {"ok": false, "error": "URL must start with http:// or https://"}
	_headers = definition.get("headers", {}).duplicate()
	protocol_version = String(definition.get("protocol_version", "2025-11-25"))
	_timeout_sec = float(definition.get("timeout_ms", 120000)) / 1000.0
	session_id = ""
	_running = true
	log_line.emit("info", "HTTP MCP endpoint: " + _url)
	return {"ok": true, "error": ""}


func stop() -> void:
	_running = false
	closed.emit("stopped")


## Sends one JSON-RPC message. Returns immediately; the answer (if any) is
## delivered through `message_received`.
func send(message: Dictionary) -> bool:
	if not _running:
		return false
	_in_flight += 1
	_post(message)
	return true


func _post(message: Dictionary) -> void:
	var headers := _headers.duplicate()
	headers["Content-Type"] = "application/json"
	headers["Accept"] = "application/json, text/event-stream"
	headers["MCP-Protocol-Version"] = protocol_version
	if not session_id.is_empty():
		headers["Mcp-Session-Id"] = session_id
	var body := JSON.stringify(message)
	var has_id := message.has("id")

	var fetch := AIStudioFetch.new()
	_host.add_child(fetch)
	var res: Dictionary = await fetch.fetch_json(_url, HTTPClient.METHOD_POST, headers, body, _timeout_sec,
		"application/json, text/event-stream")
	fetch.queue_free()
	_in_flight -= 1

	# Capture the session id assigned during initialize().
	for h in res.get("headers", []) as PackedStringArray:
		var lower := String(h).to_lower()
		if lower.begins_with("mcp-session-id:"):
			var value := String(h).substr(String(h).find(":") + 1).strip_edges()
			if not value.is_empty() and session_id.is_empty():
				session_id = value

	if not bool(res["ok"]) and int(res["status"]) != 202:
		var msg := String(res["error"])
		if msg.is_empty():
			msg = "HTTP %d" % int(res["status"])
		if have_session_error(int(res["status"]), res.get("body", "")):
			# Session expired: forget it so the next connect starts cleanly.
			session_id = ""
			log_line.emit("warning", "MCP session expired; it will be re-created on the next connect.")
		if not has_id:
			log_line.emit("warning", "Notification failed: " + msg)
			return
		message_received.emit(AIStudioJsonRpc.error(message.get("id"), -32000, msg))
		return

	if int(res["status"]) == 202 and not has_id:
		return  # accepted notification

	var events: Array = res.get("events", [])
	if not events.is_empty():
		for ev in events:
			if typeof(ev) == TYPE_DICTIONARY:
				message_received.emit(ev)
		return
	if res["json"] != null and typeof(res["json"]) == TYPE_DICTIONARY:
		message_received.emit(res["json"])
		return
	if has_id:
		message_received.emit(AIStudioJsonRpc.error(message.get("id"), -32700,
			"Server returned an empty or non-JSON response."))


static func have_session_error(status: int, body: String) -> bool:
	if status != 404 and status != 400:
		return false
	var lower := body.to_lower()
	return lower.contains("session") or lower.contains("mcp-session-id")


## Convenience: build an HTTP MCP definition.
static func make_definition(url: String, headers: Dictionary = {}) -> Dictionary:
	return AIStudioConfig.normalise_server({"transport": "http", "url": url, "headers": headers, "enabled": true})
