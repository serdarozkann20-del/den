@tool
class_name AIStudioAgentSession
extends RefCounted

## One conversation: keeps the canonical message list, runs the model/tool loop,
## and asks for user approval before anything mutates the project.
##
## Loop: user -> model -> (tool calls -> approve? -> execute -> results) -> model
## ... until the model stops calling tools or `max_tool_steps` is reached.

signal message_added(message: Dictionary, index: int)
signal assistant_started()
signal text_delta(text: String)
signal thinking_delta(text: String)
signal tool_call_started(call: Dictionary)
signal tool_call_finished(call: Dictionary, result: Dictionary)
signal approval_required(call: Dictionary)
signal approval_resolved(call_id: String, decision: String)
signal status_changed(status: String, detail: String)
signal turn_finished(summary: Dictionary)
signal error_occurred(message: String)

const SESSION_DIR := "user://ai_studio/sessions"

var config: AIStudioConfig
var llm: AIStudioLLMClient
var mcp: AIStudioMcpManager
var godot_tools: AIStudioGodotTools

var messages: Array = []
var busy := false
var session_title := "New chat"
var created_at := 0
var usage_totals := {"input": 0, "output": 0}
var last_error := ""

var _cancelled := false
var _decisions: Dictionary = {}
var _auto_approve_rest := false
## call id -> call, for tools that are blocked on a user approval right now.
var _pending_approvals: Dictionary = {}


func _init(cfg: AIStudioConfig, llm_client: AIStudioLLMClient, mcp_manager: AIStudioMcpManager, tools: AIStudioGodotTools) -> void:
	config = cfg
	llm = llm_client
	mcp = mcp_manager
	godot_tools = tools
	created_at = int(Time.get_unix_time_from_system())
	new_session()


func new_session() -> void:
	messages = [{"role": "system", "content": _system_prompt()}]
	session_title = "New chat"
	_cancelled = false
	_decisions.clear()
	_pending_approvals.clear()
	_auto_approve_rest = false
	usage_totals = {"input": 0, "output": 0}
	last_error = ""


func _system_prompt() -> String:
	var custom := String(config.get_value("general", "system_prompt", "")).strip_edges()
	return custom if not custom.is_empty() else AIStudioEditorContext.default_system_prompt()


func cancel() -> void:
	_cancelled = true
	if llm != null:
		llm.cancel()


## Called by the UI when the user answers an approval prompt.
## decision: "approve" | "approve_all" | "deny"
func resolve_approval(call_id: String, decision: String) -> void:
	_decisions[call_id] = decision
	approval_resolved.emit(call_id, decision)


## True while the loop is blocked on a tool that still needs a user decision.
## The UI uses this to keep the Stop button meaningful; the entry is added and
## removed by _execute_with_approval().
func is_waiting_for_approval() -> bool:
	return not _pending_approvals.is_empty()


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

func send(user_text: String, context: String = "") -> Dictionary:
	if busy:
		return {"ok": false, "error": "The assistant is already answering. Press Stop first."}
	busy = true
	_cancelled = false
	_auto_approve_rest = false

	var content: Variant = user_text
	var user_message := {"role": "user", "content": content}
	messages.append(user_message)
	message_added.emit(user_message, messages.size() - 1)
	if session_title == "New chat" and not user_text.strip_edges().is_empty():
		session_title = user_text.strip_edges().substr(0, 48)

	# Refresh the editor context block on every turn so the model sees the
	# current scene, selection and open script.
	var ctx := context if not context.is_empty() else AIStudioEditorContext.build(config)
	if not ctx.strip_edges().is_empty():
		var ctx_msg := {"role": "system", "content": ctx}
		messages.append(ctx_msg)
		message_added.emit(ctx_msg, messages.size() - 1)

	var steps_max := clampi(int(config.get_value("general", "max_tool_steps", 12)), 1, 50)
	var created_calls: Array = []
	var final_text := ""
	var stop_reason := "max_steps"

	for step in steps_max:
		if _cancelled:
			stop_reason = "cancelled"
			break
		status_changed.emit("thinking", "Waiting for %s..." % _model_label())
		assistant_started.emit()
		var tool_defs := available_tools()
		var opts := {
			"provider": config.get_provider_id(),
			"model": config.get_model(),
			"stream": bool(config.get_value("general", "stream", true)),
			"timeout_sec": float(config.get_value("general", "request_timeout_sec", 180)),
			"temperature": float(config.get_value("general", "temperature", 0.4)),
			"max_tokens": int(config.get_value("general", "max_tokens", 0)),
		}
		var res: Dictionary = await llm.stream_chat(messages, tool_defs, opts)
		if _cancelled:
			stop_reason = "cancelled"
			break
		if not bool(res.get("ok", false)):
			last_error = String(res.get("error", "Request failed"))
			error_occurred.emit(last_error)
			status_changed.emit("error", last_error)
			stop_reason = "error"
			break

		_accumulate_usage(res.get("usage", {}))
		# The client reports here when the endpoint refused an optional field and
		# the request had to be reduced (see AIStudioLLMClient._next_degradation).
		if not String(res.get("note", "")).is_empty():
			status_changed.emit("notice", "%s: %s" % [_model_label(), String(res["note"])])
		final_text = String(res.get("text", ""))
		var calls: Array = res.get("tool_calls", [])
		var assistant_message := {
			"role": "assistant",
			"content": final_text,
			"thinking": String(res.get("thinking", "")),
			"tool_calls": calls,
		}
		messages.append(assistant_message)
		message_added.emit(assistant_message, messages.size() - 1)

		if calls.is_empty():
			stop_reason = "stop"
			break

		# Execute every requested tool, then loop back to the model.
		var progress := false
		for call in calls:
			if _cancelled:
				break
			created_calls.append(call)
			tool_call_started.emit(call)
			var result := await _execute_with_approval(call)
			var tool_message := {
				"role": "tool",
				"name": String(call.get("name", "")),
				"tool_call_id": String(call.get("id", "")),
				"content": String(result.get("text", "")) if bool(result.get("ok", false)) else "ERROR: " + String(result.get("error", "tool failed")),
			}
			messages.append(tool_message)
			message_added.emit(tool_message, messages.size() - 1)
			tool_call_finished.emit(call, result)
			progress = true
		if not progress:
			stop_reason = "no_tool_progress"
			break
		if step == steps_max - 1:
			stop_reason = "max_steps"

	busy = false
	var summary := {
		"ok": stop_reason != "error",
		"stop_reason": stop_reason,
		"text": final_text,
		"tool_calls": created_calls.size(),
		"usage": usage_totals.duplicate(),
		"error": last_error,
	}
	status_changed.emit("idle", stop_reason)
	turn_finished.emit(summary)
	if bool(config.get_value("general", "save_sessions", true)):
		save()
	return summary


## Tools the model may call: built-in Godot tools plus every MCP tool.
func available_tools() -> Array:
	var out: Array = []
	if String(config.get_value("general", "mode", "agent")) == "chat":
		return out
	out.append_array(godot_tools.definitions())
	if mcp != null:
		out.append_array(mcp.tool_definitions())
	return out


func _execute_with_approval(call: Dictionary) -> Dictionary:
	var call_id := String(call.get("id", ""))
	var tool_name := String(call.get("name", ""))
	var args: Dictionary = call.get("arguments", {}) if typeof(call.get("arguments", {})) == TYPE_DICTIONARY else {}
	if args.has("__raw"):
		return {"ok": false, "text": "", "error": "The model produced malformed tool arguments: " + String(args["__raw"]).substr(0, 200)}

	var needs_approval := _needs_approval(tool_name)
	if needs_approval and not _auto_approve_rest:
		_pending_approvals[call_id] = call
		status_changed.emit("approval", "Waiting for your approval: %s" % tool_name)
		approval_required.emit(call)
		var decision := await _await_decision(call_id)
		_pending_approvals.erase(call_id)
		if decision == "approve_all":
			_auto_approve_rest = true
		elif decision == "deny":
			return {"ok": false, "text": "", "error": "The user denied this tool call. Do not retry it; explain what you wanted to do and ask how to proceed."}
		status_changed.emit("running", "Running %s..." % tool_name)

	if godot_tools.has(tool_name):
		return await godot_tools.call_tool(tool_name, args)
	if mcp != null and mcp.is_exposed_tool(tool_name):
		return await mcp.call_exposed_tool(tool_name, args)
	return {"ok": false, "text": "", "error": "Unknown tool: " + tool_name}


## Approval policy:
##   * read-only Godot tools            -> always allowed
##   * Godot tools that change the scene/files -> allowed when
##     `general.confirm_mutations` is false, otherwise ask
##   * MCP tools -> ask, unless the user turned `general.approve_mcp_tools` off
##     or that specific server is marked `auto_approve` in its config
func _needs_approval(tool_name: String) -> bool:
	if godot_tools.has(tool_name):
		if godot_tools.is_safe(tool_name):
			return false
		return bool(config.get_value("general", "confirm_mutations", true))
	var route = mcp.route_for(tool_name) if mcp != null else null
	if route != null:
		var server_def: Dictionary = config.mcp_server(String(route["server"]))
		if bool(server_def.get("auto_approve", false)):
			return false
		return bool(config.get_value("general", "approve_mcp_tools", true))
	return true


func _await_decision(call_id: String) -> String:
	while not _decisions.has(call_id):
		if _cancelled:
			return "deny"
		await _frame()
	var decision := String(_decisions[call_id])
	_decisions.erase(call_id)
	return decision


func _model_label() -> String:
	var model := config.get_model()
	return model if not model.is_empty() else config.get_provider_id()


func _accumulate_usage(usage: Variant) -> void:
	if typeof(usage) != TYPE_DICTIONARY or (usage as Dictionary).is_empty():
		return
	var u: Dictionary = usage
	usage_totals["input"] += int(u.get("prompt_tokens", u.get("input_tokens", 0)))
	usage_totals["output"] += int(u.get("completion_tokens", u.get("output_tokens", 0)))


func _frame() -> void:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		await (loop as SceneTree).process_frame
	else:
		OS.delay_msec(20)


# ---------------------------------------------------------------------------
# Sessions on disk
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"title": session_title,
		"created_at": created_at,
		"provider": config.get_provider_id(),
		"model": config.get_model(),
		"usage": usage_totals.duplicate(),
		"messages": messages.duplicate(true),
	}


func load_dict(data: Dictionary) -> void:
	messages = data.get("messages", [])
	session_title = String(data.get("title", "New chat"))
	created_at = int(data.get("created_at", 0))
	usage_totals = data.get("usage", {"input": 0, "output": 0})


func save() -> String:
	AIStudioConfig.ensure_dir(SESSION_DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var path := "%s/%s.json" % [SESSION_DIR, stamp]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(to_dict(), "  "))
	f = null
	return path


## Removes the per-turn editor context system messages so an exported or
## reloaded transcript stays readable.
func transcript_messages() -> Array:
	var out: Array = []
	for m in messages:
		if String(m.get("role", "")) == "system" and String(m.get("content", "")).begins_with("## Godot editor context"):
			continue
		out.append(m)
	return out


func export_markdown() -> String:
	var lines := PackedStringArray()
	lines.append("# %s" % session_title)
	lines.append("")
	lines.append("- Provider: %s" % config.get_provider_id())
	lines.append("- Model: %s" % config.get_model())
	lines.append("- Date: %s" % Time.get_datetime_string_from_system())
	lines.append("- Tokens: %d in / %d out" % [usage_totals["input"], usage_totals["output"]])
	lines.append("")
	for m in transcript_messages():
		match String(m.get("role", "")):
			"user":
				lines.append("## You\n\n%s\n" % String(m.get("content", "")))
			"assistant":
				var text := String(m.get("content", ""))
				if not text.strip_edges().is_empty():
					lines.append("## Assistant\n\n%s\n" % text)
				for c in m.get("tool_calls", []) as Array:
					lines.append("> tool call: `%s(%s)`\n" % [String(c.get("name", "")), JSON.stringify(c.get("arguments", {}))])
			"tool":
				lines.append("<details><summary>tool result: %s</summary>\n\n```\n%s\n```\n\n</details>\n" % [
					String(m.get("name", "")), String(m.get("content", "")).substr(0, 4000)])
	return "\n".join(lines)
