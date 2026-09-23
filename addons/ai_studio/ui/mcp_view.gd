@tool
class_name AIStudioMcpView
extends VBoxContainer

## MCP servers: add/edit/connect, see tool counts, and read the connection log.
## Ships with ready-made presets for the Hermes Agent MCP server
## (`hermes mcp serve` over stdio, or an HTTP endpoint).

var config: AIStudioConfig
var manager: AIStudioMcpManager

var _list: VBoxContainer
var _log_view: RichTextLabel
var _log_server_picker: OptionButton
var _dialog: ConfirmationDialog
var _dialog_fields: Dictionary = {}
var _editing_name := ""
var _status_line: Label


func setup(cfg: AIStudioConfig, mcp_manager: AIStudioMcpManager) -> void:
	config = cfg
	manager = mcp_manager
	_build()
	manager.server_state_changed.connect(func(_a, _b, _c): refresh())
	manager.tools_changed.connect(refresh)
	manager.log_message.connect(func(_server, _level, _text): _append_logs())
	refresh()


func _build() -> void:
	add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)

	var add_button := MenuButton.new()
	add_button.text = "Add server"
	var popup := add_button.get_popup()
	popup.add_item("Hermes Agent (stdio: hermes mcp serve)", 0)
	popup.add_item("Hermes Agent (HTTP endpoint)", 1)
	popup.add_item("Filesystem (npx @modelcontextprotocol/server-filesystem)", 2)
	popup.add_item("Blank stdio server", 3)
	popup.add_item("Blank HTTP server", 4)
	popup.id_pressed.connect(_on_add_preset)
	header.add_child(add_button)

	var connect_all := Button.new()
	connect_all.text = "Connect all"
	connect_all.pressed.connect(func(): manager.connect_all())
	header.add_child(connect_all)

	var disconnect_all := Button.new()
	disconnect_all.text = "Disconnect all"
	disconnect_all.pressed.connect(func(): manager.disconnect_all())
	header.add_child(disconnect_all)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var reload := Button.new()
	reload.text = "Reload tools"
	reload.tooltip_text = "Ask every connected server for its current tool list"
	reload.pressed.connect(func(): _reload_all_tools())
	header.add_child(reload)
	add_child(header)

	var sampling := CheckBox.new()
	sampling.text = "Allow servers to use my selected model for sampling/createMessage"
	sampling.button_pressed = bool(config.get_value("mcp", "allow_sampling", true))
	sampling.tooltip_text = "Hermes-style servers may ask the editing assistant for a completion. Disable to answer those requests with an error instead."
	sampling.toggled.connect(func(on: bool): config.set_value("mcp", "allow_sampling", on))
	add_child(sampling)

	# A project can ship MCP definitions in res://.ai_studio.json. Those may spawn
	# processes, so they stay disconnected until the user says otherwise here.
	if not config.project_server_names().is_empty():
		var warn := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.20, 0.16, 0.08)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(8)
		warn.add_theme_stylebox_override("panel", style)
		var warn_box := VBoxContainer.new()
		var warn_label := Label.new()
		warn_label.text = "This project ships %d MCP server definition(s) in .ai_studio.json: %s" % [
			config.project_server_names().size(), ", ".join(config.project_server_names())]
		warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn_label.add_theme_font_size_override("font_size", 11)
		warn_box.add_child(warn_label)
		var trust := CheckBox.new()
		trust.text = "Trust this project's servers (start them with the editor)"
		trust.button_pressed = config.project_servers_allowed()
		trust.tooltip_text = "Leave this off unless you know what the project starts. A server definition is a command line that runs on your machine."
		trust.toggled.connect(func(on: bool):
			config.set_value("mcp", "allow_project_servers", on)
			if on:
				manager.connect_all()
			refresh())
		warn_box.add_child(trust)
		warn.add_child(warn_box)
		add_child(warn)

	_status_line = Label.new()
	_status_line.add_theme_font_size_override("font_size", 11)
	_status_line.modulate = Color(1, 1, 1, 0.7)
	add_child(_status_line)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	add_child(_section("Log"))

	var log_row := HBoxContainer.new()
	_log_server_picker = OptionButton.new()
	_log_server_picker.item_selected.connect(func(_i): _append_logs(true))
	log_row.add_child(_log_server_picker)
	var clear := Button.new()
	clear.text = "Clear"
	clear.pressed.connect(func():
		manager.clear_logs(_selected_log_server())
		_append_logs(true))
	log_row.add_child(clear)
	add_child(log_row)

	_log_view = RichTextLabel.new()
	_log_view.custom_minimum_size = Vector2(0, 140)
	_log_view.bbcode_enabled = true
	_log_view.scroll_following = true
	_log_view.selection_enabled = true
	_log_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_log_view)

	_build_dialog()


# ---------------------------------------------------------------------------
# Server list
# ---------------------------------------------------------------------------

func refresh() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()

	var servers := manager.configured_servers()
	var status := manager.status()

	var log_names: Array = ["(all servers)"]
	log_names.append_array(servers.keys())
	var previous := _selected_log_server()
	_log_server_picker.clear()
	for name in log_names:
		_log_server_picker.add_item(String(name))
	var idx := log_names.find(previous)
	_log_server_picker.select(maxi(idx, 0))

	if servers.is_empty():
		var empty := Label.new()
		empty.text = "No MCP servers yet. 'Add server' -> Hermes Agent presets are ready to use."
		empty.modulate = Color(1, 1, 1, 0.6)
		_list.add_child(empty)
		_status_line.text = "MCP disabled: no servers configured."
		return

	var ready := 0
	var tool_total := 0
	for name in servers.keys():
		var state: Dictionary = status.get(name, {})
		if String(state.get("state", "")) == "ready":
			ready += 1
			tool_total += int(state.get("tools", 0))
		_list.add_child(_server_row(String(name), AIStudioConfig.normalise_server(servers[name]), state))
	_status_line.text = "%d/%d server(s) connected, %d tool(s) exposed to the model." % [
		ready, servers.size(), tool_total]
	_append_logs()


func _server_row(server_name: String, def: Dictionary, state: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var status_text := String(state.get("state", "not connected"))
	style.bg_color = Color(0.10, 0.18, 0.12) if status_text == "ready" else (
		Color(0.22, 0.12, 0.12) if status_text == "error" else Color(0.12, 0.13, 0.15))
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	var title_row := HBoxContainer.new()
	var enabled := CheckBox.new()
	enabled.button_pressed = bool(def.get("enabled", true))
	enabled.tooltip_text = "Connect this server automatically"
	enabled.toggled.connect(func(on: bool):
		def["enabled"] = on
		config.set_mcp_server(server_name, def))
	title_row.add_child(enabled)
	var title := Label.new()
	var origin := "  · project file" if config.is_project_server(server_name) else ""
	title.text = "%s   [%s]%s" % [server_name, String(def.get("transport", "stdio")), origin]
	if config.is_project_server(server_name):
		title.tooltip_text = "Defined by res://.ai_studio.json (version controlled). It is only started automatically when you trust project servers above."
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var state_label := Label.new()
	state_label.text = status_text if status_text != "ready" else "ready · %d tools" % int(state.get("tools", 0))
	state_label.modulate = Color(1, 1, 1, 0.75)
	title_row.add_child(state_label)
	box.add_child(title_row)

	var detail := Label.new()
	var detail_text := ""
	if String(def.get("transport", "stdio")) == "stdio":
		detail_text = "command: %s %s" % [String(def.get("command", "")), " ".join(PackedStringArray(def.get("args", [])))]
	else:
		detail_text = "url: %s" % String(def.get("url", ""))
	if not String(state.get("error", "")).is_empty():
		detail_text += "\nlast error: " + String(state.get("error", ""))
	if not String(def.get("notes", "")).is_empty():
		detail_text += "\n" + String(def.get("notes", ""))
	detail.text = detail_text
	detail.add_theme_font_size_override("font_size", 11)
	detail.modulate = Color(1, 1, 1, 0.7)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)

	var buttons := HBoxContainer.new()
	var connect := Button.new()
	connect.text = "Reconnect" if status_text != "not connected" else "Connect"
	connect.pressed.connect(func(): manager.connect_server(server_name))
	buttons.add_child(connect)
	var disconnect := Button.new()
	disconnect.text = "Disconnect"
	disconnect.pressed.connect(func(): manager.disconnect_server(server_name))
	buttons.add_child(disconnect)
	var edit := Button.new()
	edit.text = "Edit"
	edit.pressed.connect(func(): open_editor(server_name, def))
	buttons.add_child(edit)
	var remove := Button.new()
	remove.text = "Remove"
	remove.pressed.connect(func():
		manager.disconnect_server(server_name)
		config.remove_mcp_server(server_name)
		refresh())
	buttons.add_child(remove)
	box.add_child(buttons)

	panel.add_child(box)
	return panel


# ---------------------------------------------------------------------------
# Add / edit dialog
# ---------------------------------------------------------------------------

func _build_dialog() -> void:
	_dialog = ConfirmationDialog.new()
	_dialog.title = "MCP server"
	_dialog.min_size = Vector2(620, 520)
	var form := VBoxContainer.new()
	form.name = "Form"
	form.add_theme_constant_override("separation", 4)
	_dialog.add_child(form)
	_dialog.confirmed.connect(_on_dialog_confirmed)
	add_child(_dialog)


func _field(form: Node, key: String, label_text: String, value: String, placeholder: String = "") -> LineEdit:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	row.add_child(label)
	var field := LineEdit.new()
	field.text = value
	field.placeholder_text = placeholder
	row.add_child(field)
	form.add_child(row)
	_dialog_fields[key] = field
	return field


func open_editor(server_name: String, def: Dictionary) -> void:
	_editing_name = server_name
	var form: VBoxContainer = _dialog.get_node("Form")
	for child in form.get_children():
		child.queue_free()
	_dialog_fields.clear()

	var name_field := _field(form, "name", "Server name (used in tool names)", server_name)
	name_field.editable = server_name.is_empty()

	var transport := OptionButton.new()
	transport.add_item("stdio (local command)")
	transport.add_item("http (Streamable HTTP URL)")
	var title := Label.new()
	title.text = "Transport"
	title.add_theme_font_size_override("font_size", 11)
	form.add_child(title)
	form.add_child(transport)
	_dialog_fields["transport"] = transport

	_field(form, "command", "Command (stdio)", String(def.get("command", "")), "hermes")
	_field(form, "args", "Arguments, space separated", " ".join(PackedStringArray(def.get("args", []))), "mcp serve")
	_field(form, "env", "Environment variables (KEY=VALUE, one per line)", _dict_to_lines(def.get("env", {})))
	_field(form, "cwd", "Working directory (optional)", String(def.get("cwd", "")))
	_field(form, "url", "URL (http)", String(def.get("url", "")), "http://127.0.0.1:8765/mcp")
	_field(form, "headers", "HTTP headers (Name: value, one per line)", _dict_to_lines(def.get("headers", {})))
	_field(form, "tool_allow", "Tool allowlist (comma separated globs, empty = all)", ", ".join(PackedStringArray(def.get("tool_allow", []))))
	_field(form, "tool_deny", "Tool denylist (comma separated globs)", ", ".join(PackedStringArray(def.get("tool_deny", []))))
	_field(form, "notes", "Notes", String(def.get("notes", "")))

	var wrap := CheckBox.new()
	wrap.text = "Run through the platform shell (needed for npx/.cmd shims and env vars)"
	wrap.button_pressed = bool(def.get("shell_wrap", OS.get_name() == "Windows"))
	form.add_child(wrap)
	_dialog_fields["shell_wrap"] = wrap

	var auto_approve := CheckBox.new()
	auto_approve.text = "Run this server's tools without asking for approval"
	auto_approve.button_pressed = bool(def.get("auto_approve", false))
	form.add_child(auto_approve)
	_dialog_fields["auto_approve"] = auto_approve

	transport.select(0 if String(def.get("transport", "stdio")) == "stdio" else 1)
	_dialog.popup_centered()


func _on_add_preset(id: int) -> void:
	var def := {}
	var name := ""
	match id:
		0:
			name = "hermes-agent"
			def = AIStudioConfig.hermes_agent_presets()["hermes-stdio"]
		1:
			name = "hermes-agent-http"
			def = AIStudioConfig.hermes_agent_presets()["hermes-http"]
		2:
			name = "filesystem"
			def = {"transport": "stdio", "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", ProjectSettings.globalize_path("res://")],
				"shell_wrap": OS.get_name() == "Windows", "notes": "Reference MCP filesystem server rooted at this project."}
		3:
			name = "new-server"
			def = {"transport": "stdio", "command": "", "args": []}
		4:
			name = "new-http-server"
			def = {"transport": "http", "url": ""}
	var base := name
	var index := 2
	var existing := manager.configured_servers()
	while existing.has(name):
		name = "%s-%d" % [base, index]
		index += 1
	open_editor(name, AIStudioConfig.normalise_server(def))


func _on_dialog_confirmed() -> void:
	var def := {}
	def["transport"] = "stdio" if int(_dialog_fields["transport"].selected) == 0 else "http"
	def["command"] = _dialog_fields["command"].text.strip_edges()
	def["args"] = _dialog_fields["args"].text.split(" ", false)
	def["env"] = _lines_to_dict(_dialog_fields["env"].text)
	def["cwd"] = _dialog_fields["cwd"].text.strip_edges()
	def["url"] = _dialog_fields["url"].text.strip_edges()
	def["headers"] = _lines_to_dict(_dialog_fields["headers"].text)
	def["tool_allow"] = _split_list(_dialog_fields["tool_allow"].text)
	def["tool_deny"] = _split_list(_dialog_fields["tool_deny"].text)
	def["notes"] = _dialog_fields["notes"].text.strip_edges()
	def["shell_wrap"] = _dialog_fields["shell_wrap"].button_pressed
	def["auto_approve"] = _dialog_fields["auto_approve"].button_pressed
	def["enabled"] = true
	var name: String = String(_dialog_fields["name"].text).strip_edges()
	if name.is_empty():
		name = "server"
	config.set_mcp_server(name, def)
	refresh()
	if bool(def["enabled"]):
		manager.connect_server(name)


# ---------------------------------------------------------------------------
# Logs
# ---------------------------------------------------------------------------

func _selected_log_server() -> String:
	if _log_server_picker == null or _log_server_picker.item_count == 0:
		return ""
	var text := _log_server_picker.get_item_text(_log_server_picker.selected)
	return "" if text == "(all servers)" else text


func _append_logs(rebuild: bool = false) -> void:
	if _log_view == null:
		return
	var selected := _selected_log_server()
	var servers: Array = manager.configured_servers().keys() if selected.is_empty() else [selected]
	var lines := PackedStringArray()
	for name in servers:
		for entry in manager.logs(String(name)):
			var text := String(entry)
			var color := "#c8c8c8"
			if text.begins_with("[error]") or text.begins_with("[stderr]"):
				color = "#ff9d9d"
			elif text.begins_with("[warning]"):
				color = "#ffd479"
			elif text.begins_with("[info]"):
				color = "#9dd0ff"
			lines.append("[color=%s]%s[/color]" % [color, AIStudioMarkdown._escape(text)])
	if rebuild:
		_log_view.text = "\n".join(lines)
	else:
		_log_view.text = "\n".join(lines)


func _reload_all_tools() -> void:
	for name in manager.configured_servers().keys():
		var client = manager.client_for(String(name))
		if client != null and client.is_ready():
			await client.refresh_tools()
	refresh()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _dict_to_lines(dict: Variant) -> String:
	if typeof(dict) != TYPE_DICTIONARY:
		return ""
	var out := PackedStringArray()
	for k in (dict as Dictionary).keys():
		out.append("%s=%s" % [String(k), String(dict[k])])
	return "\n".join(out)


static func _lines_to_dict(text: String) -> Dictionary:
	var out := {}
	for line in text.split("\n"):
		var l := String(line).strip_edges()
		if l.is_empty() or not l.contains("="):
			continue
		var idx := l.find("=")
		out[l.substr(0, idx).strip_edges()] = l.substr(idx + 1).strip_edges()
	return out


static func _split_list(text: String) -> Array:
	var out: Array = []
	for part in text.split(",", false):
		var t := String(part).strip_edges()
		if not t.is_empty():
			out.append(t)
	return out


static func _section(title: String) -> Label:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(1, 1, 1, 0.85)
	return label
