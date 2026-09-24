@tool
class_name AIStudioGameBridge
extends RefCounted

## Runtime tools: inspect and drive the game while it runs from the editor.
##
## The command set and the in-game server come from godot-mcp
## (https://github.com/tugcantopaloglu/godot-mcp, MIT, (c) Tugcan Topaloglu and
## Solomon Elias). The game side is `runtime/game_bridge_server.gd`, registered
## as an autoload by `godot_game_bridge action=enable`. It only starts in a game
## launched by this editor (and only when AI_STUDIO_BRIDGE=1 is inherited from
## the editor process), listens on 127.0.0.1 and requires a per-editor-session
## token, so exported builds and other local processes are not affected.
##
## Protocol: one JSON object per line, {command, params, id, token} ->
## {..., id} or {error, id}.
##
## Tool exposure: 108 runtime commands would blow past the 128-tool limit of
## some providers, so by default the model sees a compact set (the everyday
## commands as their own tools + `game_command` for everything else +
## `game_commands` to look up parameters). "Expose every game command as its
## own tool" in Settings registers all of them individually.

const AUTOLOAD_NAME := "AIStudioGameBridgeServer"
const SERVER_SCRIPT := "res://addons/ai_studio/runtime/game_bridge_server.gd"
const DEFAULT_PORT := 9090
const CONNECT_TIMEOUT_MS := 6000
const MAX_TEXT := 60000

## Everyday commands that get their own tool even in the compact set.
const CORE_COMMANDS := ["game_screenshot", "game_get_scene_tree", "game_get_ui", "game_get_node_info",
	"game_get_property", "game_set_property", "game_call_method", "game_click", "game_key_press",
	"game_mouse_move", "game_input_action", "game_wait", "game_eval", "game_performance"]

## Commands that only read game state or simulate player input. They run
## without an approval prompt; everything else (spawning, editing nodes,
## eval, HTTP, saving resources, ...) asks like other mutating tools.
const SAFE_COMMANDS := ["game_screenshot", "game_get_ui", "game_get_scene_tree", "game_get_property",
	"game_get_node_info", "game_performance", "game_wait", "game_get_nodes_in_group",
	"game_find_nodes_by_class", "game_get_camera", "game_get_audio", "game_list_signals",
	"game_os_info", "game_click", "game_key_press", "game_mouse_move", "game_key_hold",
	"game_key_release", "game_scroll", "game_mouse_drag", "game_gamepad", "game_touch",
	"game_input_action", "game_get_logs", "game_get_errors"]

## Extra commands implemented by the AI Studio server itself.
const EXTRA_COMMANDS := {
	"game_get_logs": {
		"command": "get_logs",
		"description": "New print() output of the running game since the last call.",
		"properties": {}, "required": [], "defaults": {}, "timeout_ms": 10000,
	},
	"game_get_errors": {
		"command": "get_errors",
		"description": "New errors and warnings (push_error, push_warning, script and engine errors, with file:line) of the running game since the last call.",
		"properties": {}, "required": [], "defaults": {}, "timeout_ms": 10000,
	},
}

var host = null   # AIStudioGodotTools
var port := DEFAULT_PORT
var token := ""
var _peer: StreamPeerTCP = null
var _buffer := PackedByteArray()
var _next_id := 1
var _busy := false
var _commands: Dictionary = {}


func _init(host_tools) -> void:
	host = host_tools
	_commands = AIStudioGameCatalog.COMMANDS.duplicate()
	for k in EXTRA_COMMANDS.keys():
		_commands[k] = EXTRA_COMMANDS[k]
	var env_port := OS.get_environment("AI_STUDIO_BRIDGE_PORT")
	if env_port.is_valid_int():
		port = int(env_port)
	if AIStudioEditorEnv.available():
		# Games launched by the editor inherit these, which is how the in-game
		# server knows it may start and which token to accept.
		token = OS.get_environment("AI_STUDIO_BRIDGE_TOKEN")
		if token.is_empty():
			token = Crypto.new().generate_random_bytes(16).hex_encode()
			OS.set_environment("AI_STUDIO_BRIDGE_TOKEN", token)
		OS.set_environment("AI_STUDIO_BRIDGE", "1")
		OS.set_environment("AI_STUDIO_BRIDGE_PORT", str(port))


# ---------------------------------------------------------------------------
# registration
# ---------------------------------------------------------------------------

func register() -> void:
	host._add("godot_game_bridge",
		"Status of the runtime game bridge, or enable/disable it. The bridge (an autoload that only runs in games started from this editor) is what the game_* tools talk to. After enabling, (re)start the game with godot_play_scene.",
		host._obj({"action": {"type": "string", "enum": ["status", "enable", "disable"], "description": "Default: status."}}),
		func(a): return await _tool_bridge(a), false, "game")
	host._set_safe_fn("godot_game_bridge", func(a): return String(a.get("action", "status")) == "status")

	host._add("game_commands",
		"Look up the runtime game commands: without 'names' lists every command with a one-line description; with 'names' returns their full parameter schemas. Run them with game_command.",
		host._obj({
			"names": {"type": "array", "items": {"type": "string"}, "description": "Command names, e.g. ['game_spawn_node', 'game_tween_property']."},
			"filter": host._str("Only list commands whose name or description contains this text."),
		}),
		func(a): return _tool_commands(a), true, "game")

	host._add("game_command",
		"Run any runtime game command (see game_commands for the list and parameters) in the game running from the editor: spawn nodes, tween, animation, physics queries, audio, camera, UI, tilemaps, lights, particles, networking, etc.",
		host._obj({
			"command": host._str("Command name, e.g. 'game_spawn_node' (the 'game_' prefix is optional)."),
			"params": {"type": "object", "description": "Parameters as listed by game_commands (snake_case).", "additionalProperties": true},
		}, ["command"]),
		func(a): return await _tool_generic(a), false, "game")
	host._set_safe_fn("game_command", func(a): return SAFE_COMMANDS.has(_canonical(String(a.get("command", "")))))

	for name in _commands.keys():
		var entry: Dictionary = _commands[name]
		var tool_name := String(name)
		host._add(tool_name, String(entry["description"]) + " (runtime: needs the game running from the editor)",
			_schema(entry),
			func(a): return await run_command(tool_name, a), SAFE_COMMANDS.has(tool_name),
			"game" if (CORE_COMMANDS.has(tool_name) or EXTRA_COMMANDS.has(tool_name)) else "game_all")

	for name in ["godot_game_bridge", "game_command"] + _commands.keys():
		host._editor_only[name] = true


func _schema(entry: Dictionary) -> Dictionary:
	var props: Dictionary = (entry["properties"] as Dictionary).duplicate(true)
	return host._obj(props, entry.get("required", []))


static func _canonical(name: String) -> String:
	var n := name.strip_edges()
	return n if n.begins_with("game_") else "game_" + n


# ---------------------------------------------------------------------------
# tools
# ---------------------------------------------------------------------------

func is_installed() -> bool:
	return ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME)


func _tool_bridge(args: Dictionary) -> Dictionary:
	var action := String(args.get("action", "status"))
	match action:
		"status":
			var lines := PackedStringArray()
			lines.append("Bridge autoload: %s" % ("installed" if is_installed() else "not installed (run godot_game_bridge action=enable)"))
			var playing := EditorInterface.is_playing_scene()
			lines.append("Game running: %s" % ("yes (" + EditorInterface.get_playing_scene() + ")" if playing else "no"))
			lines.append("Port: 127.0.0.1:%d" % port)
			if playing and is_installed():
				var ping := await _request("ping", {}, 3000)
				lines.append("Connection: " + ("ok" if not ping.has("error") else "failed - " + String(ping["error"])))
			return host._ok("\n".join(lines))
		"enable":
			if is_installed():
				return host._ok("The game bridge is already enabled.")
			ProjectSettings.set_setting("autoload/" + AUTOLOAD_NAME, "*" + SERVER_SCRIPT)
			ProjectSettings.set_order("autoload/" + AUTOLOAD_NAME, 100000)
			var err := ProjectSettings.save()
			if err != OK:
				return host._err("Could not save project.godot (%s)." % error_string(err))
			var note := " Restart the running game to use it." if EditorInterface.is_playing_scene() else " Start the game (godot_play_scene) to use the game_* tools."
			return host._ok("Game bridge enabled: autoload %s -> %s. It only runs in games started from this editor; exported builds remove it immediately.%s" % [AUTOLOAD_NAME, SERVER_SCRIPT, note])
		"disable":
			if not is_installed():
				return host._ok("The game bridge is not enabled.")
			ProjectSettings.set_setting("autoload/" + AUTOLOAD_NAME, null)
			var err2 := ProjectSettings.save()
			if err2 != OK:
				return host._err("Could not save project.godot (%s)." % error_string(err2))
			_disconnect()
			return host._ok("Game bridge disabled (autoload removed).")
	return host._err("Unknown action '%s' (status, enable, disable)." % action)


func _tool_commands(args: Dictionary) -> Dictionary:
	var names = args.get("names", [])
	if typeof(names) == TYPE_ARRAY and not (names as Array).is_empty():
		var out := {}
		for n in names:
			var key := _canonical(String(n))
			if not _commands.has(key):
				out[key] = "unknown command"
				continue
			var e: Dictionary = _commands[key]
			out[key] = {"description": e["description"], "parameters": _schema(e),
				"defaults": e.get("defaults", {}), "asks_approval": not SAFE_COMMANDS.has(key)}
		return host._ok(JSON.stringify(out, "  "))
	var filter := String(args.get("filter", "")).to_lower()
	var lines := PackedStringArray()
	var keys: Array = _commands.keys()
	keys.sort()
	for k in keys:
		var desc := String(_commands[k]["description"])
		if not filter.is_empty() and not (String(k).contains(filter) or desc.to_lower().contains(filter)):
			continue
		lines.append("%s - %s%s" % [k, desc, "" if SAFE_COMMANDS.has(k) else " [asks]"])
	return host._ok("%d runtime commands (run with game_command; get parameters with game_commands names=[...]):\n%s" % [lines.size(), "\n".join(lines)])


func _tool_generic(args: Dictionary) -> Dictionary:
	var name := _canonical(String(args.get("command", "")))
	if not _commands.has(name):
		return host._err("Unknown game command '%s'. Use game_commands to list them." % name)
	var params = args.get("params", {})
	if typeof(params) == TYPE_STRING:
		params = JSON.parse_string(String(params))
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	return await run_command(name, params)


## Validates, fills defaults, sends the command and formats the reply.
func run_command(tool_name: String, args: Dictionary) -> Dictionary:
	var entry: Dictionary = _commands.get(tool_name, {})
	if entry.is_empty():
		return host._err("Unknown game command: " + tool_name)
	var ready := _ready_check()
	if not ready.is_empty():
		return host._err(ready)
	var params := {}
	var props: Dictionary = entry["properties"]
	for k in (entry.get("defaults", {}) as Dictionary).keys():
		params[k] = entry["defaults"][k]
	for k in args.keys():
		var key := String(k)
		if not props.has(key):
			var snake := key.to_snake_case()
			if props.has(snake):
				key = snake
		params[key] = args[k]
	for k in entry.get("json_keys", []):
		if params.has(k) and typeof(params[k]) == TYPE_STRING:
			var parsed = JSON.parse_string(String(params[k]))
			if parsed != null:
				params[k] = parsed
	var missing := PackedStringArray()
	for r in entry.get("required", []):
		if not params.has(r) or params[r] == null or (typeof(params[r]) == TYPE_STRING and String(params[r]).is_empty() and r != "value"):
			missing.append(String(r))
	if not missing.is_empty():
		return host._err("%s needs: %s" % [tool_name, ", ".join(missing)])
	var timeout := int(entry.get("timeout_ms", 10000))
	if tool_name == "game_await_signal":
		timeout = int(float(params.get("timeout", 10)) * 1000.0) + 2000
	var reply := await _request(String(entry["command"]), params, timeout)
	if reply.has("error"):
		return host._err("%s failed: %s" % [tool_name, str(reply["error"])])
	reply.erase("id")
	if tool_name == "game_screenshot":
		return _save_screenshot(reply)
	var text := JSON.stringify(reply, "  ")
	if text.length() > MAX_TEXT:
		text = text.substr(0, MAX_TEXT) + "\n... (truncated, %d chars total)" % text.length()
	return host._ok(text)


func _ready_check() -> String:
	if not AIStudioEditorEnv.available():
		return "The game tools need the Godot editor."
	if not is_installed():
		return "The game bridge is not enabled for this project. Run godot_game_bridge with action=enable, then start the game with godot_play_scene."
	if not EditorInterface.is_playing_scene():
		return "The game is not running. Start it with godot_play_scene (the bridge autoload must be enabled before the game starts)."
	return ""


func _save_screenshot(reply: Dictionary) -> Dictionary:
	var data := String(reply.get("data", ""))
	if data.is_empty():
		return host._err("The game returned no image.")
	var bytes := Marshalls.base64_to_raw(data)
	AIStudioConfig.ensure_dir(host._screenshot_dir)
	var path := "%s/game_%d_%d.png" % [host._screenshot_dir, Time.get_unix_time_from_system(), Time.get_ticks_msec() % 1000]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return host._err("Could not save the screenshot (%s)." % error_string(FileAccess.get_open_error()))
	f.store_buffer(bytes)
	f = null
	return {"ok": true, "error": "", "image_path": path,
		"text": "Saved game screenshot to %s (%dx%d, absolute: %s)." % [path, int(reply.get("width", 0)), int(reply.get("height", 0)), ProjectSettings.globalize_path(path)]}


# ---------------------------------------------------------------------------
# transport
# ---------------------------------------------------------------------------

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _disconnect() -> void:
	if _peer != null:
		_peer.disconnect_from_host()
	_peer = null
	_buffer.clear()


func _ensure_connected() -> String:
	if _peer != null:
		_peer.poll()
		if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			return ""
		_disconnect()
	var started := Time.get_ticks_msec()
	var last_error := ""
	# The game may still be booting right after godot_play_scene: keep trying.
	while Time.get_ticks_msec() - started < CONNECT_TIMEOUT_MS:
		if not EditorInterface.is_playing_scene():
			return "The game stopped."
		var peer := StreamPeerTCP.new()
		var err := peer.connect_to_host("127.0.0.1", port)
		if err != OK:
			last_error = error_string(err)
		else:
			var attempt_start := Time.get_ticks_msec()
			while Time.get_ticks_msec() - attempt_start < 1000:
				peer.poll()
				var status := peer.get_status()
				if status == StreamPeerTCP.STATUS_CONNECTED:
					_peer = peer
					_buffer.clear()
					return ""
				if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
					last_error = "connection refused"
					break
				await _tree().process_frame
		await _tree().create_timer(0.25).timeout
	return "Could not reach the game bridge on 127.0.0.1:%d (%s). Is the bridge enabled (godot_game_bridge) and was the game started after enabling it?" % [port, last_error]


## Sends one command and waits for its reply. Requests are serialized because
## the in-game server handles one command at a time.
func _request(command: String, params: Dictionary, timeout_ms: int) -> Dictionary:
	var tree := _tree()
	if tree == null:
		return {"error": "No SceneTree."}
	var wait_start := Time.get_ticks_msec()
	while _busy:
		if Time.get_ticks_msec() - wait_start > timeout_ms:
			return {"error": "Another game command is still running."}
		await tree.process_frame
	_busy = true
	var result := await _request_locked(command, params, timeout_ms)
	_busy = false
	return result


func _request_locked(command: String, params: Dictionary, timeout_ms: int) -> Dictionary:
	var conn_error := await _ensure_connected()
	if not conn_error.is_empty():
		return {"error": conn_error}
	var id := _next_id
	_next_id += 1
	var line := JSON.stringify({"command": command, "params": params, "id": id, "token": token}) + "\n"
	var err := _peer.put_data(line.to_utf8_buffer())
	if err != OK:
		_disconnect()
		return {"error": "Send failed (%s)." % error_string(err)}
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		_peer.poll()
		var status := _peer.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED:
			_disconnect()
			return {"error": "The game closed the connection (did it stop or crash? check game_get_errors after restarting)."}
		var available := _peer.get_available_bytes()
		if available > 0:
			var chunk: Array = _peer.get_data(available)
			if int(chunk[0]) == OK:
				_buffer.append_array(chunk[1])
		while true:
			var nl := _buffer.find(10)
			if nl < 0:
				break
			var raw := _buffer.slice(0, nl).get_string_from_utf8().strip_edges()
			_buffer = _buffer.slice(nl + 1)
			if raw.is_empty():
				continue
			var parsed = JSON.parse_string(raw)
			if typeof(parsed) != TYPE_DICTIONARY:
				continue
			var reply: Dictionary = parsed
			var reply_id = reply.get("id", null)
			if reply_id != null and int(reply_id) != id:
				continue  # late reply to an earlier, timed-out request
			return reply
		await _tree().process_frame
	return {"error": "No reply within %d ms (the game may be paused in the debugger or busy)." % timeout_ms}
