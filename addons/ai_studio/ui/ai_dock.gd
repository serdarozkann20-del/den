@tool
class_name AIStudioDock
extends VBoxContainer

## The dock shown in the Godot editor: Chat | Model | MCP | Tools | Help.

signal export_requested()

var config: AIStudioConfig
var llm: AIStudioLLMClient
var mcp: AIStudioMcpManager
var session: AIStudioAgentSession
var tools: AIStudioGodotTools

var chat_view: AIStudioChatView
var settings_view: AIStudioSettingsView
var mcp_view: AIStudioMcpView

var _tabs: TabContainer
var _tools_list: VBoxContainer
var _tool_picker: OptionButton
var _tool_args: TextEdit
var _tool_output: RichTextLabel
var _help: RichTextLabel


func setup(cfg: AIStudioConfig, llm_client: AIStudioLLMClient, mcp_manager: AIStudioMcpManager,
		agent_session: AIStudioAgentSession, godot_tools: AIStudioGodotTools) -> void:
	config = cfg
	llm = llm_client
	mcp = mcp_manager
	session = agent_session
	tools = godot_tools
	_build()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 4)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_tabs)

	chat_view = AIStudioChatView.new()
	chat_view.name = "Chat"
	chat_view.setup(session)
	chat_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_view.new_chat_requested.connect(_on_new_chat)
	chat_view.export_requested.connect(func(): export_requested.emit())
	chat_view.stop_requested.connect(func(): session.cancel())
	chat_view.settings_requested.connect(func(): switch_tab(1))
	_tabs.add_child(chat_view)

	settings_view = AIStudioSettingsView.new()
	settings_view.name = "Model"
	settings_view.setup(config, llm, session)
	settings_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(settings_view)

	mcp_view = AIStudioMcpView.new()
	mcp_view.name = "MCP"
	mcp_view.setup(config, mcp)
	mcp_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(mcp_view)

	_tabs.add_child(_build_tools_tab())

	_help = RichTextLabel.new()
	_help.name = "Help"
	_help.bbcode_enabled = true
	_help.selection_enabled = true
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.text = _help_text()
	_tabs.add_child(_help)

	switch_tab(int(config.get_value("ui", "last_tab", 0)))
	_tabs.tab_changed.connect(func(index: int): config.set_value("ui", "last_tab", index, false))


# ---------------------------------------------------------------------------
# Tools tab
# ---------------------------------------------------------------------------

func _build_tools_tab() -> Control:
	var root := VBoxContainer.new()
	root.name = "Tools"
	root.add_theme_constant_override("separation", 6)

	var hint := Label.new()
	hint.text = "Tools the model can call. Read-only tools run freely; anything that changes the project asks for approval first."
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.65)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 180)
	root.add_child(scroll)

	_tools_list = VBoxContainer.new()
	_tools_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tools_list)

	root.add_child(_section("Run a tool by hand (debugging)"))

	var row := HBoxContainer.new()
	_tool_picker = OptionButton.new()
	_tool_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for name in tools.definition_names():
		_tool_picker.add_item(name)
	_tool_picker.item_selected.connect(_on_tool_selected)
	row.add_child(_tool_picker)
	var run := Button.new()
	run.text = "Run"
	run.pressed.connect(_run_selected_tool)
	row.add_child(run)
	root.add_child(row)

	_tool_args = TextEdit.new()
	_tool_args.custom_minimum_size = Vector2(0, 70)
	_tool_args.text = "{}"
	root.add_child(_tool_args)

	_tool_output = RichTextLabel.new()
	_tool_output.bbcode_enabled = true
	_tool_output.fit_content = true
	_tool_output.custom_minimum_size = Vector2(0, 90)
	_tool_output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_tool_output)

	rebuild_tools_list()
	mcp.tools_changed.connect(rebuild_tools_list)
	return root


func rebuild_tools_list() -> void:
	if _tools_list == null:
		return
	for child in _tools_list.get_children():
		child.queue_free()
	var builtin := tools.definitions()
	for d in builtin:
		var name := String(d["function"]["name"])
		var safe := tools.is_safe(name)
		var label := Label.new()
		label.text = "%s  %s" % ["[read-only]" if safe else "[asks]", name]
		label.add_theme_font_size_override("font_size", 11)
		label.modulate = Color(0.75, 0.9, 1.0) if safe else Color(1.0, 0.85, 0.65)
		_tools_list.add_child(label)
		var desc := Label.new()
		desc.text = String(d["function"]["description"]).substr(0, 160)
		desc.add_theme_font_size_override("font_size", 10)
		desc.modulate = Color(1, 1, 1, 0.55)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tools_list.add_child(desc)
	var mcp_tools := mcp.tool_definitions()
	if not mcp_tools.is_empty():
		var header := Label.new()
		header.text = "\nMCP tools (%d)" % mcp_tools.size()
		header.add_theme_font_size_override("font_size", 12)
		_tools_list.add_child(header)
		for d in mcp_tools:
			var name := String(d["function"]["name"])
			var label := Label.new()
			label.text = "%s  %s" % ["[read-only]" if mcp.is_read_only(name) else "[asks]", name]
			label.add_theme_font_size_override("font_size", 11)
			label.modulate = Color(0.75, 0.9, 1.0) if mcp.is_read_only(name) else Color(1.0, 0.85, 0.65)
			_tools_list.add_child(label)


func _on_tool_selected(index: int) -> void:
	var name := _tool_picker.get_item_text(index)
	var schema := {}
	for d in tools.definitions():
		if String(d["function"]["name"]) == name:
			schema = d["function"]["parameters"]
			break
	var example := {}
	for key in (schema.get("properties", {}) as Dictionary).keys():
		var prop: Dictionary = schema["properties"][key]
		match String(prop.get("type", "string")):
			"integer", "number":
				example[key] = 0
			"boolean":
				example[key] = false
			"object":
				example[key] = {}
			_:
				example[key] = ""
	_tool_args.text = JSON.stringify(example, "  ")


func _run_selected_tool() -> void:
	var name := _tool_picker.get_item_text(_tool_picker.selected)
	var args = JSON.parse_string(_tool_args.text)
	if typeof(args) != TYPE_DICTIONARY:
		_tool_output.text = "[color=#ff9d9d]Arguments must be a JSON object.[/color]"
		return
	var res: Dictionary = await tools.call_tool(name, args)
	_tool_output.text = AIStudioMarkdown.to_bbcode(String(res.get("text", "")) if bool(res.get("ok", false))
		else "ERROR: " + String(res.get("error", "")))


# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

## Number of tabs in the dock (used by the smoke test and docs).
func tab_count() -> int:
	return _tabs.get_tab_count() if _tabs != null else 0


func tab_titles() -> PackedStringArray:
	var out := PackedStringArray()
	if _tabs == null:
		return out
	for i in _tabs.get_tab_count():
		out.append(_tabs.get_tab_title(i))
	return out


func switch_tab(index: int) -> void:
	if _tabs != null:
		_tabs.current_tab = clampi(index, 0, _tabs.get_tab_count() - 1)


func current_tab() -> int:
	return _tabs.current_tab if _tabs != null else 0


func _on_new_chat() -> void:
	session.new_session()
	chat_view.clear()
	chat_view.set_busy(false)


func _help_text() -> String:
	return """[b]AI Studio[/b] - talk to a model about this project, and let it use tools.

[b]1. Pick a model[/b]
Open the [i]Model[/i] tab, choose a provider, paste an API key (or set the matching environment variable) and press [i]Refresh models[/i]. The list comes straight from your provider, so it always matches what your account can use.

Supported out of the box: OpenAI, Anthropic, Google Gemini (native + OpenAI-compatible), Nous Portal Hermes models, the Hermes Agent subscription proxy, OpenRouter, Ollama, LM Studio and any custom OpenAI-compatible endpoint.

[b]2. Chat[/b]
[i]Agent[/i] mode lets the model call tools: read scripts and scenes, inspect the engine class reference, add nodes, set properties, write files, run the scene... Every change asks for approval first (unless you turn that off in the Model tab).

[i]Chat[/i] mode is a plain conversation with your project context attached.

[b]3D assets[/b]
Ask for a rig report and it lists the bones it finds - including which humanoid bone each one is. From there it can write a BoneMap for a rig that has none, retarget animations onto another skeleton, add collision fitted to a mesh, set up camera/sun/sky, and edit per-asset import settings (retarget, LODs). Details in [code]docs/3d.md[/code].

[b]3. MCP servers[/b]
The [i]MCP[/i] tab manages Model Context Protocol servers. Tools from connected servers become callable by the model.

Hermes Agent presets:
[code]stdio:  hermes mcp serve[/code]
[code]http:   http://127.0.0.1:8765/mcp[/code]

Configure Hermes itself in [code]~/.hermes/config.yaml[/code]; Godot only needs to reach the server.

[b]Where things are stored[/b]
API keys and settings: the editor's user data folder ([code]user://ai_studio/config.cfg[/code]), never inside the project. Conversations: [code]user://ai_studio/sessions/[/code].

[b]Tip[/b] The engine class reference tool reads ClassDB from [i]your[/i] Godot build, so the model never has to guess an API.
"""


static func _section(title: String) -> Label:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(1, 1, 1, 0.85)
	return label
