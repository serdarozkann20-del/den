@tool
class_name AIStudioEditorLog
extends Logger

## Collects the editor's own prints, warnings and errors (including script
## errors with file and line) into a ring buffer for godot_editor_log.
## Installed by the plugin in _enter_tree and removed in _exit_tree. Logger
## callbacks can arrive from any thread, so everything goes through a mutex,
## and nothing in here may print (that would recurse).

const MAX_ENTRIES := 2000
const TYPE_NAMES := ["error", "warning", "script_error", "shader_error"]

static var _instance: AIStudioEditorLog = null

var _mutex := Mutex.new()
var _entries: Array = []
var _next_id := 1


static func install() -> void:
	if _instance != null:
		return
	_instance = AIStudioEditorLog.new()
	OS.add_logger(_instance)


static func uninstall() -> void:
	if _instance == null:
		return
	OS.remove_logger(_instance)
	_instance = null


static func installed() -> bool:
	return _instance != null


## Entries newer than `since_id`, oldest first. kinds: "all", "errors"
## (errors + warnings) or "messages" (plain prints).
static func entries(kinds: String = "all", since_id: int = 0) -> Array:
	if _instance == null:
		return []
	return _instance._snapshot(kinds, since_id)


static func clear() -> void:
	if _instance != null:
		_instance._mutex.lock()
		_instance._entries.clear()
		_instance._mutex.unlock()


static func last_id() -> int:
	if _instance == null:
		return 0
	_instance._mutex.lock()
	var id := _instance._next_id - 1
	_instance._mutex.unlock()
	return id


func _snapshot(kinds: String, since_id: int) -> Array:
	var out: Array = []
	_mutex.lock()
	for e in _entries:
		if int(e["id"]) <= since_id:
			continue
		var is_msg := String(e["type"]) == "message" or String(e["type"]) == "stderr"
		if kinds == "errors" and is_msg:
			continue
		if kinds == "messages" and not is_msg:
			continue
		out.append(e.duplicate())
	_mutex.unlock()
	return out


func _push(entry: Dictionary) -> void:
	_mutex.lock()
	entry["id"] = _next_id
	entry["time"] = Time.get_time_string_from_system()
	_next_id += 1
	_entries.append(entry)
	if _entries.size() > MAX_ENTRIES:
		_entries = _entries.slice(_entries.size() - MAX_ENTRIES)
	_mutex.unlock()


func _log_message(message: String, error: bool) -> void:
	var text := message.strip_edges(false, true)
	if text.is_empty():
		return
	_push({"type": "stderr" if error else "message", "message": text})


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var entry := {
		"type": TYPE_NAMES[error_type] if error_type >= 0 and error_type < TYPE_NAMES.size() else "error",
		"message": rationale if not rationale.is_empty() else code,
		"file": file, "line": line, "function": function,
	}
	if not rationale.is_empty() and not code.is_empty() and code != rationale:
		entry["condition"] = code
	# Engine-side errors raised from a script: point at the script frame too.
	for bt in script_backtraces:
		if bt != null and bt.get_frame_count() > 0:
			entry["script_file"] = bt.get_frame_file(0)
			entry["script_line"] = bt.get_frame_line(0)
			entry["script_function"] = bt.get_frame_function(0)
			break
	_push(entry)
