@tool
extends EditorPlugin

## AI Studio - use AI models and MCP agent tools from inside the Godot editor.
##
## Entry point: builds the services (config, LLM client, MCP manager, agent
## session, tool set), adds the dock, wires the Hermes Agent sampling bridge and
## auto-connects the configured MCP servers.

const DOCK_TITLE := "AI Studio"

var config: AIStudioConfig
var llm: AIStudioLLMClient
var mcp: AIStudioMcpManager
var tools: AIStudioGodotTools
var session: AIStudioAgentSession
var dock: AIStudioDock

var _dock_control: Control


func _enter_tree() -> void:
	# Collect editor errors/prints from the start for godot_editor_log.
	AIStudioEditorLog.install()
	config = AIStudioConfig.new()
	tools = AIStudioGodotTools.new()
	tools.apply_config(config)
	config.changed.connect(func(): tools.apply_config(config))
	llm = AIStudioLLMClient.new(config)
	add_child(llm)
	mcp = AIStudioMcpManager.new(config, self)
	session = AIStudioAgentSession.new(config, llm, mcp, tools)

	dock = AIStudioDock.new()
	dock.setup(config, llm, mcp, session, tools)
	dock.export_requested.connect(_export_transcript)
	_dock_control = dock
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, _dock_control)

	add_tool_menu_item("AI Studio: Focus panel", _focus_dock)
	add_tool_menu_item("AI Studio: New chat", _new_chat)
	add_tool_menu_item("AI Studio: Reload MCP servers", _reload_mcp)
	add_tool_menu_item("AI Studio: Export conversation as Markdown", _export_transcript)

	mcp.log_message.connect(_on_mcp_log)
	mcp.server_state_changed.connect(_on_server_state)
	mcp.set_sampling_handler(_on_sampling_request)

	if OS.get_environment("AI_STUDIO_SMOKE_TEST") == "1":
		# `AI_STUDIO_SMOKE_TEST=1 godot --editor --path <project>` verifies that
		# the plugin really came up inside a live editor session, then exits.
		_run_smoke_test.call_deferred()

	if bool(config.get_value("mcp", "auto_connect", true)):
		# Give the editor a moment to finish loading before spawning processes.
		await get_tree().create_timer(1.0).timeout
		if is_inside_tree():
			var untrusted := _untrusted_project_servers()
			mcp.connect_all()
			dock.mcp_view.refresh()
			if not untrusted.is_empty():
				# These only exist because the opened project asked for them.
				_notify("Project MCP server(s) not started: %s. Review them on the MCP tab." % ", ".join(untrusted), false)


## Servers the project file defines while the user has not trusted project files.
func _untrusted_project_servers() -> PackedStringArray:
	var out := PackedStringArray()
	if config.project_servers_allowed():
		return out
	for name in config.project_server_names():
		out.append(name)
	return out


## Editor-mode self check. Run with
##   AI_STUDIO_SMOKE_TEST=1 godot --headless --editor --path <project>
## It prints one line per check and exits with code 0/1, which makes it usable
## as an install verification step.
func _run_smoke_test() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var tally := {"passed": 0, "failed": 0}
	# GDScript lambdas capture by value, so the counters live in a Dictionary.
	var report := func(name: String, ok: bool, detail: String = "") -> void:
		if ok:
			tally["passed"] += 1
			lines.append("  ok   " + name)
		else:
			tally["failed"] += 1
			lines.append("  FAIL " + name + ("  (" + detail + ")" if not detail.is_empty() else ""))

	print("\n=== AI Studio editor smoke test ===")
	report.call("EditorInterface is reachable", AIStudioEditorEnv.available())
	report.call("editor interface instance", AIStudioEditorEnv.interface() != null)
	report.call("plugin icon texture", AIStudioIcons.plugin_icon() != null)
	report.call("dock is in the scene tree", _dock_control != null and _dock_control.is_inside_tree())
	report.call("dock has five tabs", dock != null and dock.tab_count() == 5,
		str(dock.tab_titles()) if dock != null else "no dock")
	if dock != null:
		var titles := dock.tab_titles()
		report.call("tabs are chat/model/mcp/tools/help",
			titles.has("Chat") and titles.has("Model") and titles.has("MCP") and
			titles.has("Tools") and titles.has("Help"), str(titles))
	report.call("toaster available",
		AIStudioEditorEnv.interface() != null and
		AIStudioEditorEnv.interface().get_editor_toaster() != null)
	report.call("tool registry populated", tools.definition_names().size() >= 20,
		"%d tools" % tools.definition_names().size())
	report.call("agent exposes tools", session.available_tools().size() >= 20)
	report.call("llm client is idle", llm != null and not llm.is_busy())
	report.call("mcp manager reports status", typeof(mcp.status()) == TYPE_DICTIONARY)
	report.call("provider configured", not config.get_provider_id().is_empty(),
		config.get_provider_id())

	var context := AIStudioEditorContext.build(config)
	report.call("editor context has content", context.length() > 40, str(context.length()) + " chars")
	report.call("editor context names the engine", context.contains("Godot"),
		context.substr(0, 80))
	var status: Dictionary = await tools.call_tool("godot_project_info", {})
	report.call("project_info runs inside the editor", bool(status.get("ok", false)),
		String(status.get("error", "")))
	var scene: Dictionary = await tools.call_tool("godot_scene_tree", {})
	report.call("scene_tree answers without a scene", scene.has("ok"),
		String(scene.get("error", "")))

	var tabs_ok := true
	for i in dock.tab_count() if dock != null else 0:
		dock.switch_tab(i)
		tabs_ok = tabs_ok and dock.current_tab() == i
	report.call("every tab can be shown", tabs_ok)
	if dock != null:
		dock.switch_tab(int(config.get_value("ui", "last_tab", 0)))

	# With AI_STUDIO_SMOKE_TEST_SCENE=<res:// scene> the editor also opens that
	# scene and drives the tools that need a live editor (scene edits, materials,
	# physics, lighting, saving) before everything is reported.
	var test_scene := OS.get_environment("AI_STUDIO_SMOKE_TEST_SCENE").strip_edges()
	if not test_scene.is_empty():
		await _run_scene_smoke_test(report, lines, test_scene)

	# Give the auto-connect (1 s after boot) a chance, then report what came up.
	await get_tree().create_timer(1.4).timeout
	var servers: Dictionary = mcp.status()
	lines.append("  info mcp servers: %d configured, %d tools exposed" % [
		servers.size(), mcp.tool_definitions().size()])
	for server_name in servers.keys():
		var entry: Dictionary = servers[server_name]
		lines.append("  info   %s -> %s (%d tools)" % [
			server_name, String(entry.get("state", "?")), int(entry.get("tools", 0))])

	for line in lines:
		print(line)
	print("=== smoke test: %d passed, %d failed ===" % [tally["passed"], tally["failed"]])
	get_tree().quit(1 if int(tally["failed"]) > 0 else 0)


## Opens a scene in the running editor and exercises every tool that needs one:
## reading the edited scene, editing it (nodes, material, physics, camera,
## lighting, saved to disk) plus the 3D inspection tools against a live scene.
func _run_scene_smoke_test(report: Callable, lines: PackedStringArray, scene_path: String) -> void:
	# open_scene_from_path() returns void, so ask the editor what it opened.
	# Right after boot the filesystem scan may not know the scene yet, so retry.
	var root := EditorInterface.get_edited_scene_root()
	for attempt in 12:
		if root != null and String(root.scene_file_path) == scene_path:
			break
		EditorInterface.open_scene_from_path(scene_path)
		await get_tree().create_timer(0.25).timeout
		root = EditorInterface.get_edited_scene_root()
	var opened := root != null and String(root.scene_file_path) == scene_path
	report.call("test scene opens", opened,
		"edited root is %s (%s)" % [String(root.name) if root != null else "null",
			String(root.scene_file_path) if root != null else "-"])
	if not opened:
		return

	# Tools that read the edited scene when no source is given.
	var bones: Dictionary = await tools.call_tool("godot_list_bones", {"classify": true})
	report.call("list_bones reads the edited scene", bool(bones.get("ok", false)),
		String(bones.get("error", "")) + String(bones.get("text", "")).substr(0, 60))
	report.call("skeleton bones found in the editor",
		String(bones.get("text", "")).contains("bones)"), String(bones.get("text", "")).substr(0, 80))
	var anims: Dictionary = await tools.call_tool("godot_animation_info", {})
	report.call("animation_info reads the edited scene", bool(anims.get("ok", false)),
		String(anims.get("error", "")))
	var mesh_info: Dictionary = await tools.call_tool("godot_mesh_info", {"node_path": "Body"})
	report.call("mesh_info reads a node in the edited scene", bool(mesh_info.get("ok", false)),
		String(mesh_info.get("error", "")))
	var tree: Dictionary = await tools.call_tool("godot_scene_tree", {})
	report.call("scene_tree sees the open scene", bool(tree.get("ok", false)) and
		String(tree.get("text", "")).contains("Skeleton3D"), String(tree.get("error", "")))

	# Editor-only edits: material, physics body, camera, lighting.
	var material_path: String = scene_path.get_base_dir() + "/smoke_material.tres"
	var material: Dictionary = await tools.call_tool("godot_create_material", {
		"output_path": material_path, "albedo_color": "#44aa88", "roughness": 0.35})
	report.call("create_material works in the editor", bool(material.get("ok", false)),
		String(material.get("error", "")))
	var assign: Dictionary = await tools.call_tool("godot_set_material", {
		"node_path": "Body", "material_path": material_path, "surface": -1})
	report.call("material assigned to a mesh instance", bool(assign.get("ok", false)),
		String(assign.get("error", "")))

	var body: Dictionary = await tools.call_tool("godot_add_physics_body", {
		"body_type": "character", "shape": "capsule", "name": "PlayerBody", "fit_to": "Body"})
	report.call("character body with a fitted capsule", bool(body.get("ok", false)),
		String(body.get("error", "")))
	report.call("capsule was fitted to the mesh", String(body.get("text", "")).contains("capsule r="),
		String(body.get("text", "")).substr(0, 120))
	var trimesh: Dictionary = await tools.call_tool("godot_add_physics_body", {
		"body_type": "static", "shape": "trimesh", "name": "StaticBody3D", "fit_to": "Body"})
	report.call("trimesh body from mesh", bool(trimesh.get("ok", false)), String(trimesh.get("error", "")))

	var camera: Dictionary = await tools.call_tool("godot_add_camera", {
		"name": "GameCamera", "position": "0,2,6", "look_at": "Body", "fov": 60})
	report.call("camera added and aimed", bool(camera.get("ok", false)),
		String(camera.get("error", "")))
	report.call("camera reported its aim", String(camera.get("text", "")).contains("looking at"),
		String(camera.get("text", "")).substr(0, 120))

	var environment: Dictionary = await tools.call_tool("godot_setup_3d_environment",
		{"sun_energy": 1.2, "background": "sky", "tonemap": "aces", "fog": true, "fog_density": 0.02})
	report.call("lighting and environment set up", bool(environment.get("ok", false)),
		String(environment.get("error", "")))
	report.call("environment mentions the sun", String(environment.get("text", "")).contains("DirectionalLight3D"),
		String(environment.get("text", "")).substr(0, 120))

	# A bad class/parameter must fail loudly instead of half-editing the scene.
	var bad: Dictionary = await tools.call_tool("godot_add_camera", {"look_at": "0,0"})
	report.call("bad arguments are rejected", bool(bad.get("ok", false)),
		"accepted '0,0' as a position")

	var saved: Dictionary = await tools.call_tool("godot_save_scenes", {"all": true})
	report.call("scene saved", bool(saved.get("ok", false)), String(saved.get("error", "")))
	await get_tree().create_timer(0.3).timeout
	var text := FileAccess.get_file_as_string(scene_path)
	for needle in ["CharacterBody3D", "CollisionShape3D", "Camera3D", "WorldEnvironment",
			"DirectionalLight3D", "smoke_material.tres"]:
		report.call("saved scene contains " + needle, text.contains(needle),
			"not found in the saved scene")
	lines.append("  info scene smoke edited and saved %s (%d bytes)" % [scene_path, text.length()])


func _exit_tree() -> void:
	AIStudioEditorLog.uninstall()
	if mcp != null:
		mcp.disconnect_all()
	if llm != null:
		llm.cancel()
	remove_tool_menu_item("AI Studio: Focus panel")
	remove_tool_menu_item("AI Studio: New chat")
	remove_tool_menu_item("AI Studio: Reload MCP servers")
	remove_tool_menu_item("AI Studio: Export conversation as Markdown")
	if _dock_control != null:
		remove_control_from_docks(_dock_control)
		_dock_control.queue_free()
		_dock_control = null
	config = null
	mcp = null
	llm = null
	tools = null
	session = null
	dock = null


func _get_plugin_icon() -> Texture2D:
	return AIStudioIcons.plugin_icon()


# ---------------------------------------------------------------------------
# Menu actions
# ---------------------------------------------------------------------------

func _focus_dock() -> void:
	if dock != null:
		dock.switch_tab(0)
		dock.chat_view.focus_input()


func _new_chat() -> void:
	if dock != null:
		dock._on_new_chat()
		dock.switch_tab(0)


func _reload_mcp() -> void:
	if mcp == null:
		return
	mcp.disconnect_all()
	mcp.connect_all()
	_notify("MCP servers reloaded.", false)


func _export_transcript() -> void:
	if session == null:
		return
	var markdown: String = session.export_markdown()
	var session_path: String = session.save()
	if session_path.is_empty():
		_notify("Could not write the session file (check the editor user data folder).", true)
	var md_path: String = "user://ai_studio/sessions/%s.md" % Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	AIStudioConfig.ensure_dir("user://ai_studio/sessions")
	var f := FileAccess.open(md_path, FileAccess.WRITE)
	if f != null:
		f.store_string(markdown)
		f = null
	var absolute := ProjectSettings.globalize_path(md_path)
	_notify("Conversation exported to " + absolute, false)
	OS.shell_show_in_file_manager(absolute)


# ---------------------------------------------------------------------------
# MCP integration
# ---------------------------------------------------------------------------

## Servers may ask us for a completion (MCP "sampling"). Forwarding these to the
## user's configured model is what makes Hermes-style agents first-class here.
func _on_sampling_request(params: Dictionary) -> Dictionary:
	if not bool(config.get_value("mcp", "allow_sampling", true)):
		return {"ok": false, "error": "Sampling is disabled in AI Studio settings."}
	if llm.is_busy():
		return {"ok": false, "error": "The assistant is busy with another request."}
	var messages: Array = []
	var system_text := String(params.get("systemPrompt", ""))
	if not system_text.is_empty():
		messages.append({"role": "system", "content": system_text})
	for m in params.get("messages", []) as Array:
		var role := String(m.get("role", "user"))
		var content = m.get("content", {})
		var text := ""
		if typeof(content) == TYPE_DICTIONARY:
			text = String(content.get("text", ""))
		elif typeof(content) == TYPE_STRING:
			text = String(content)
		elif typeof(content) == TYPE_ARRAY:
			for part in content:
				if typeof(part) == TYPE_DICTIONARY and String(part.get("type", "")) == "text":
					text += String(part.get("text", ""))
		messages.append({"role": "assistant" if role == "assistant" else "user", "content": text})
	messages.append({"role": "user", "content": "Answer the last request. Reply with the answer only."})
	var res: Dictionary = await llm.stream_chat(messages, [], {
		"stream": false,
		"max_tokens": int(config.get_value("mcp", "sampling_max_tokens", 2048)),
		"timeout_sec": 120.0,
	})
	if not bool(res.get("ok", false)):
		return {"ok": false, "error": String(res.get("error", "sampling failed"))}
	return {"ok": true, "text": String(res.get("text", "")), "model": String(res.get("model", ""))}


func _on_mcp_log(server: String, level: String, text: String) -> void:
	if level == "error":
		_notify("[%s] %s" % [server, text.substr(0, 160)], true)


func _on_server_state(server: String, state: String, detail: String) -> void:
	if state == "error":
		_notify("MCP '%s' failed: %s" % [server, detail.substr(0, 160)], true)


func _notify(message: String, is_error: bool) -> void:
	var toaster := EditorInterface.get_editor_toaster()
	if toaster == null:
		print("[AI Studio] ", message)
		return
	toaster.push_toast(message, EditorToaster.SEVERITY_ERROR if is_error else EditorToaster.SEVERITY_INFO)
