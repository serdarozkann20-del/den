@tool
class_name AIStudioMcpManager
extends RefCounted

## Owns one AIStudioMcpClient per configured MCP server, aggregates their tools
## into OpenAI-style function definitions, and routes tool calls back.
##
## Exposed tool names look like  mcp_<server>_<tool>  (sanitised to
## [A-Za-z0-9_-], max 64 chars) because some model providers reject anything
## else. The mapping back to (server, original tool) is kept in `_routes`.

signal server_state_changed(server: String, state: String, detail: String)
signal tools_changed()
signal log_message(server: String, level: String, text: String)

const LOG_LIMIT := 300

var config: AIStudioConfig
var _host: Node
var _clients: Dictionary = {}          # server name -> AIStudioMcpClient
var _states: Dictionary = {}           # server name -> {state, detail, tools, error}
var _logs: Dictionary = {}             # server name -> Array[String]
var _routes: Dictionary = {}           # exposed name -> {server, tool}
var _sampling_handler: Callable = Callable()


func _init(cfg: AIStudioConfig, host: Node) -> void:
	config = cfg
	_host = host


func set_sampling_handler(handler: Callable) -> void:
	_sampling_handler = handler
	for name in _clients.keys():
		_clients[name].set_sampling_handler(handler)


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func configured_servers() -> Dictionary:
	return config.mcp_servers()


## Starts every enabled server. Servers that only exist because the *project*
## ships a `.ai_studio.json` are skipped unless the user trusted them
## (`mcp.allow_project_servers`, MCP tab): a cloned project must not be able to
## spawn processes on someone's machine just by being opened.
func connect_all() -> void:
	var trusted := config.project_servers_allowed()
	for name in configured_servers().keys():
		var server_name := String(name)
		var def := AIStudioConfig.normalise_server(configured_servers()[name])
		if not bool(def.get("enabled", true)):
			continue
		if config.is_project_server(server_name) and not trusted:
			_ensure_log(server_name)
			_log(server_name, "warning",
				"Defined by the project's .ai_studio.json - not started automatically. Review it and press Connect, or enable 'Trust this project's servers' on the MCP tab.")
			continue
		connect_server(server_name)


func connect_server(server_name: String) -> void:
	var servers := configured_servers()
	if not servers.has(server_name):
		return
	if _clients.has(server_name):
		disconnect_server(server_name, false)
	var def := AIStudioConfig.normalise_server(servers[server_name])
	_ensure_log(server_name)
	_log(server_name, "info", "Connecting (%s)..." % def.get("transport"))
	var client := AIStudioMcpClient.new(server_name, def, _host)
	client._startup_timeout_ms = int(servers[server_name].get("startup_timeout_ms", config.get_value("mcp", "startup_timeout_ms", 15000)))
	client._tool_timeout_ms = int(servers[server_name].get("tool_timeout_ms", config.get_value("mcp", "tool_timeout_ms", 120000)))
	client.set_sampling_handler(_sampling_handler)
	client.state_changed.connect(_on_client_state.bind(server_name))
	client.tools_changed.connect(_on_client_tools.bind(server_name))
	client.log_message.connect(func(level: String, text: String): _log(server_name, level, text))
	_clients[server_name] = client
	client.connect_server()


func disconnect_server(server_name: String, remove: bool = true) -> void:
	if not _clients.has(server_name):
		return
	var client: AIStudioMcpClient = _clients[server_name]
	client.shutdown("disconnected by user")
	if remove:
		_clients.erase(server_name)
		_states[server_name] = {"state": AIStudioMcpClient.STATE_CLOSED, "detail": "disconnected", "tools": 0, "error": ""}
		_rebuild_routes()
		server_state_changed.emit(server_name, AIStudioMcpClient.STATE_CLOSED, "disconnected")
		tools_changed.emit()


func reload_server(server_name: String) -> void:
	if _clients.has(server_name):
		await _clients[server_name].reload()
	else:
		connect_server(server_name)


func disconnect_all() -> void:
	for name in _clients.keys():
		disconnect_server(String(name), false)
	_clients.clear()
	_rebuild_routes()
	tools_changed.emit()


func is_server_ready(server_name: String) -> bool:
	var client = _clients.get(server_name)
	return client != null and client.is_ready()


func client_for(server_name: String) -> AIStudioMcpClient:
	return _clients.get(server_name)


func status() -> Dictionary:
	var out := {}
	for name in configured_servers().keys():
		var state := "not connected"
		var detail := ""
		var tool_count := 0
		var error := ""
		if _states.has(name):
			state = String(_states[name].get("state", state))
			detail = String(_states[name].get("detail", ""))
			tool_count = int(_states[name].get("tools", 0))
			error = String(_states[name].get("error", ""))
		out[name] = {"state": state, "detail": detail, "tools": tool_count, "error": error}
	return out


# ---------------------------------------------------------------------------
# Tool exposure
# ---------------------------------------------------------------------------

## All MCP tools as OpenAI function definitions.
func tool_definitions() -> Array:
	var defs: Array = []
	for entry in _all_tools():
		var route: Dictionary = entry["route"]
		var tool: Dictionary = entry["tool"]
		defs.append({
			"type": "function",
			"function": {
				"name": String(route["exposed"]),
				"description": _describe(route, tool),
				"parameters": _clean_schema(tool.get("inputSchema", {"type": "object", "properties": {}})),
			},
		})
	return defs


func _describe(route: Dictionary, tool: Dictionary) -> String:
	var desc := String(tool.get("description", "")).strip_edges()
	if desc.is_empty():
		desc = "MCP tool '%s' on server '%s'." % [String(route["tool"]), String(route["server"])]
	var hints: PackedStringArray = PackedStringArray()
	var ann: Dictionary = tool.get("annotations", {}) if typeof(tool.get("annotations", {})) == TYPE_DICTIONARY else {}
	if bool(ann.get("readOnlyHint", false)):
		hints.append("read-only")
	if bool(ann.get("destructiveHint", false)):
		hints.append("destructive")
	if bool(ann.get("idempotentHint", false)):
		hints.append("idempotent")
	if bool(ann.get("openWorldHint", false)):
		hints.append("open-world")
	var suffix := " [MCP server: %s%s]" % [String(route["server"]), ", " + ", ".join(hints) if not hints.is_empty() else ""]
	return desc + suffix


## Returns {"ok", "text", "is_error", "error", "server", "tool"}
func call_exposed_tool(exposed_name: String, arguments: Dictionary) -> Dictionary:
	var route = _routes.get(exposed_name)
	if route == null:
		return {"ok": false, "text": "", "is_error": true, "error": "Unknown MCP tool: " + exposed_name}
	var client: AIStudioMcpClient = _clients.get(String(route["server"]))
	if client == null:
		return {"ok": false, "text": "", "is_error": true, "error": "Server '%s' is not connected." % route["server"]}
	var res: Dictionary = await client.call_tool(String(route["tool"]), arguments)
	res["server"] = String(route["server"])
	res["tool"] = String(route["tool"])
	return res


func is_exposed_tool(tool_name: String) -> bool:
	return _routes.has(tool_name)


## {"server": ..., "tool": ..., "exposed": ...} for an exposed tool name, or null.
func route_for(tool_name: String) -> Variant:
	return _routes.get(tool_name)


## True when the tool looks safe to run without asking the user.
func is_read_only(exposed_name: String) -> bool:
	var route = _routes.get(exposed_name)
	if route == null:
		return false
	for entry in _all_tools():
		if String(entry["route"]["exposed"]) == exposed_name:
			var ann: Dictionary = entry["tool"].get("annotations", {})
			return bool(ann.get("readOnlyHint", false))
	return false


func autoconnect_enabled() -> bool:
	return bool(config.get_value("mcp", "auto_connect", true))


func _all_tools() -> Array:
	var out: Array = []
	for server_name in _clients.keys():
		var client: AIStudioMcpClient = _clients[server_name]
		if not client.is_ready():
			continue
		for tool in client.tools:
			var exposed := _exposed_name(String(server_name), String(tool.get("name", "")))
			out.append({
				"route": {"server": String(server_name), "tool": String(tool.get("name", "")), "exposed": exposed},
				"tool": tool,
			})
	return out


func _rebuild_routes() -> void:
	_routes.clear()
	for entry in _all_tools():
		_routes[String(entry["route"]["exposed"])] = entry["route"]


## mcp_<server>_<tool>, sanitised and truncated to 64 characters.
static func _exposed_name(server_name: String, tool_name: String) -> String:
	var s := _sanitize(server_name)
	var t := _sanitize(tool_name)
	var full := "mcp_%s_%s" % [s, t]
	if full.length() > 64:
		full = full.substr(0, 64)
	return full


static func _sanitize(value: String) -> String:
	var out := ""
	for i in value.length():
		var c := value.substr(i, 1)
		var code := value.unicode_at(i)
		var ok_char := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) or c == "-" or c == "_"
		out += c if ok_char else "_"
	if out.is_empty():
		out = "x"
	return out


## Some providers are picky about JSON-Schema keywords ($schema, title, ...).
static func _clean_schema(schema: Variant) -> Variant:
	if typeof(schema) != TYPE_DICTIONARY:
		return {"type": "object", "properties": {}}
	var out := {}
	for key in (schema as Dictionary).keys():
		if key in ["$schema", "title", "examples", "default", "additionalProperties", "strict"]:
			continue
		var value = schema[key]
		if key == "properties" and typeof(value) == TYPE_DICTIONARY:
			var props := {}
			for pname in value.keys():
				props[pname] = _clean_schema(value[pname])
			out["properties"] = props
		elif key == "items":
			out["items"] = _clean_schema(value)
		else:
			out[key] = value
	if not out.has("type"):
		out["type"] = "object"
	if String(out.get("type", "")) == "object" and not out.has("properties"):
		out["properties"] = {}
	return out


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _on_client_state(state: String, detail: String, server_name: String) -> void:
	var entry: Dictionary = _states.get(server_name, {})
	entry["state"] = state
	entry["detail"] = detail
	# An error, or a close that the user did not ask for, is worth reporting.
	if state == AIStudioMcpClient.STATE_ERROR \
			or (state == AIStudioMcpClient.STATE_CLOSED and detail != "disconnected"):
		entry["error"] = detail
	var client = _clients.get(server_name)
	if client != null:
		entry["tools"] = client.tool_count()
	_states[server_name] = entry
	if state == AIStudioMcpClient.STATE_READY or state == AIStudioMcpClient.STATE_ERROR:
		_rebuild_routes()
	server_state_changed.emit(server_name, state, detail)
	tools_changed.emit()


func _on_client_tools(tools: Array, server_name: String) -> void:
	var entry: Dictionary = _states.get(server_name, {})
	entry["tools"] = tools.size()
	entry["state"] = "ready"
	_states[server_name] = entry
	_rebuild_routes()
	server_state_changed.emit(server_name, "ready", "%d tools" % tools.size())
	tools_changed.emit()


func _ensure_log(server_name: String) -> void:
	if not _logs.has(server_name):
		_logs[server_name] = []


func _log(server_name: String, level: String, text: String) -> void:
	_ensure_log(server_name)
	var arr: Array = _logs[server_name]
	arr.append("[%s] %s" % [level, text])
	while arr.size() > LOG_LIMIT:
		arr.pop_front()
	log_message.emit(server_name, level, text)


func logs(server_name: String) -> Array:
	return _logs.get(server_name, [])


func clear_logs(server_name: String = "") -> void:
	if server_name.is_empty():
		_logs.clear()
	else:
		_logs[server_name] = []
