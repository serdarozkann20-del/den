@tool
class_name AIStudioMcpStdioTransport
extends RefCounted

## MCP stdio transport: launches a child process (e.g. `hermes mcp serve`) and
## exchanges newline-delimited JSON-RPC messages with it.
##
## Reading happens on a worker thread because the pipes are blocking; every
## message is handed back to the main thread with call_deferred(). stderr is
## drained on a second thread and forwarded as log lines - that is usually
## where MCP servers explain why they refused to start.

signal message_received(message: Dictionary)
signal closed(reason: String)
signal log_line(level: String, text: String)

var _stdio: FileAccess
var _stderr: FileAccess
var _pid: int = 0
var _stdout_thread: Thread
var _stderr_thread: Thread
var _mutex := Mutex.new()
var _running := false
var _stopping := false
var _write_mutex := Mutex.new()


func kind() -> String:
	return "stdio"


func is_running() -> bool:
	return _running


func describe() -> String:
	return _command_line


var _command_line := ""


## `definition` is a normalised MCP server definition (see AIStudioConfig.normalise_server).
func start(definition: Dictionary) -> Dictionary:
	if _running:
		return {"ok": true, "error": ""}
	var command := String(definition.get("command", "")).strip_edges()
	if command.is_empty():
		return {"ok": false, "error": "No command configured for this stdio server."}
	var args: Array = []
	for a in definition.get("args", []):
		args.append(String(a))
	var env: Dictionary = definition.get("env", {})
	var cwd := String(definition.get("cwd", "")).strip_edges()
	var shell_wrap := bool(definition.get("shell_wrap", OS.get_name() == "Windows"))

	var exec_path := command
	var exec_args := PackedStringArray(args)

	# OS.execute_with_pipe() has no environment parameter, so when env vars are
	# needed (or a shell shim like npx.cmd must be resolved) we go through the
	# platform shell. Everything is quoted for that shell.
	if not env.is_empty() or shell_wrap or not cwd.is_empty() or _needs_shell(command):
		var line := _shell_quote_command(command, args)
		var prefix := PackedStringArray()
		for k in env.keys():
			prefix.append("%s=%s" % [String(k), _shell_quote(String(env[k]))])
		if OS.get_name() == "Windows":
			var win := ""
			for p in prefix:
				win += "set " + p + " && "
			if not cwd.is_empty():
				win += "cd /d " + _shell_quote(cwd) + " && "
			win += line
			exec_path = "cmd.exe"
			exec_args = PackedStringArray(["/d", "/s", "/c", win])
		else:
			var unix := ""
			for p in prefix:
				unix += p + " "
			if not cwd.is_empty():
				unix += "cd " + _shell_quote(cwd) + " && "
			unix += line
			exec_path = "/bin/sh"
			exec_args = PackedStringArray(["-c", unix])

	_command_line = exec_path + " " + " ".join(exec_args)
	var info := OS.execute_with_pipe(exec_path, exec_args)
	if info.is_empty() or not info.has("stdio"):
		var msg := "Failed to launch '%s'. Check that the command exists and is on PATH." % exec_path
		log_line.emit("error", msg)
		return {"ok": false, "error": msg}
	_stdio = info["stdio"] as FileAccess
	_stderr = info.get("stderr") as FileAccess
	_pid = int(info.get("pid", 0))
	_running = true
	_stopping = false

	_stdout_thread = Thread.new()
	_stdout_thread.start(_read_stdout)
	if _stderr != null:
		_stderr_thread = Thread.new()
		_stderr_thread.start(_read_stderr)
	log_line.emit("info", "Started: " + _command_line + (" (pid %d)" % _pid if _pid > 0 else ""))
	return {"ok": true, "error": ""}


func send(message: Dictionary) -> bool:
	if not _running or _stdio == null:
		return false
	var text := JSON.stringify(message)
	_write_mutex.lock()
	var ok := true
	if _stdio.is_open():
		_stdio.store_line(text)
		_stdio.flush()
	else:
		ok = false
	_write_mutex.unlock()
	if not ok:
		log_line.emit("error", "Cannot write to MCP server - pipe is closed.")
	return ok


func stop() -> void:
	if not _running:
		return
	_stopping = true
	_running = false
	_write_mutex.lock()
	if _stdio != null and _stdio.is_open():
		_stdio.close()
	_write_mutex.unlock()
	if _pid > 0:
		OS.kill(_pid)
	if _stdout_thread != null and _stdout_thread.is_started():
		_stdout_thread.wait_to_finish()
	_stdout_thread = null
	if _stderr_thread != null and _stderr_thread.is_started():
		_stderr_thread.wait_to_finish()
	_stderr_thread = null
	_stdio = null
	_stderr = null
	closed.emit("stopped")


func _read_stdout() -> void:
	while true:
		_mutex.lock()
		var stream := _stdio
		_mutex.unlock()
		if stream == null:
			break
		var line := ""
		var err := OK
		if stream.is_open():
			line = stream.get_line()
			err = stream.get_error()
		else:
			break
		if err != OK or (line.is_empty() and not stream.is_open()):
			break
		var trimmed := line.strip_edges()
		if trimmed.is_empty():
			continue
		var parsed = JSON.parse_string(trimmed)
		if typeof(parsed) != TYPE_DICTIONARY:
			log_line.emit("warning", "Non-JSON output from server: " + trimmed.substr(0, 300))
			continue
		message_received.emit.call_deferred(parsed)
	if not _stopping:
		closed.emit.call_deferred("server closed stdout")


func _read_stderr() -> void:
	while true:
		_mutex.lock()
		var stream := _stderr
		_mutex.unlock()
		if stream == null:
			break
		var line := ""
		var err := OK
		if stream.is_open():
			line = stream.get_line()
			err = stream.get_error()
		else:
			break
		if err != OK:
			break
		var trimmed := line.strip_edges()
		if not trimmed.is_empty():
			log_line.emit.call_deferred("stderr", trimmed.substr(0, 500))
	if not _stopping:
		log_line.emit.call_deferred("info", "stderr stream closed")


## Builds a shell-safe single line for the given command and args.
static func _shell_quote_command(command: String, args: Array) -> String:
	var parts := PackedStringArray([_shell_quote(command)])
	for a in args:
		parts.append(_shell_quote(String(a)))
	return " ".join(parts)


## npx/npm/pipx style shims are scripts on Windows and shells on Unix; running
## them through the shell is the reliable way to make them executable.
static func _needs_shell(command: String) -> bool:
	var lower := command.to_lower()
	return lower.ends_with(".cmd") or lower.ends_with(".bat") or lower.ends_with(".ps1") \
		or lower == "npx" or lower == "npm" or lower == "yarn" or lower == "pnpm" or lower == "uvx"


static func _shell_quote(value: String) -> String:
	if OS.get_name() == "Windows":
		if value.is_empty():
			return "\"\""
		if value.contains(" ") or value.contains("&") or value.contains("^") or value.contains("(") or value.contains("\""):
			return "\"" + value.replace("\"", "\\\"") + "\""
		return value
	if value.is_empty():
		return "''"
	if value.contains("'") or value.contains(" ") or value.contains("$") or value.contains("(") or value.contains("&"):
		return "'" + value.replace("'", "'\\''") + "'"
	return value


## Convenience: build a stdio MCP definition for a plain command.
static func make_definition(command: String, args: Array) -> Dictionary:
	return AIStudioConfig.normalise_server({"transport": "stdio", "command": command, "args": args, "enabled": true})
