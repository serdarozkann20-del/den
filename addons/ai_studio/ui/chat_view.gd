@tool
class_name AIStudioChatView
extends VBoxContainer

## Chat panel: message list, streaming output, tool cards with approval buttons.

signal stop_requested()
signal new_chat_requested()
signal export_requested()
signal settings_requested()

var session: AIStudioAgentSession

var _messages_box: VBoxContainer
var _scroll: ScrollContainer
var _status: Label
var _input: TextEdit
var _send_button: Button
var _stop_button: Button
var _mode_button: OptionButton
var _context_check: CheckBox

var _stream_panel: PanelContainer
var _stream_label: RichTextLabel
var _stream_text := ""
var _stream_thinking := ""
var _busy := false
var _tool_cards: Dictionary = {}


func setup(agent_session: AIStudioAgentSession) -> void:
	session = agent_session
	_build()
	_connect_session()


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build() -> void:
	add_theme_constant_override("separation", 6)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	add_child(header)

	_mode_button = OptionButton.new()
	_mode_button.add_item("Agent (tools)")
	_mode_button.add_item("Chat (no tools)")
	_mode_button.tooltip_text = "Agent mode lets the model use Godot tools and MCP servers."
	_mode_button.item_selected.connect(func(index: int):
		session.config.set_value("general", "mode", "agent" if index == 0 else "chat"))
	header.add_child(_mode_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var new_button := Button.new()
	new_button.text = "New"
	new_button.tooltip_text = "Start a new conversation"
	new_button.pressed.connect(func(): new_chat_requested.emit())
	header.add_child(new_button)

	var export_button := Button.new()
	export_button.text = "Export"
	export_button.tooltip_text = "Save this conversation as Markdown"
	export_button.pressed.connect(func(): export_requested.emit())
	header.add_child(export_button)

	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(func(): settings_requested.emit())
	header.add_child(settings_button)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_messages_box = VBoxContainer.new()
	_messages_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages_box.add_theme_constant_override("separation", 8)
	_scroll.add_child(_messages_box)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 4)
	add_child(input_row)

	_context_check = CheckBox.new()
	_context_check.text = "Attach editor context"
	_context_check.button_pressed = true
	_context_check.tooltip_text = "Send the current scene tree, selection and open script with each message."
	_context_check.toggled.connect(func(on: bool): session.config.set_value("ui", "attach_context", on))
	input_row.add_child(_context_check)

	var input_spacer := Control.new()
	input_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(input_spacer)

	_send_button = Button.new()
	_send_button.text = "Send  (Ctrl+Enter)"
	_send_button.pressed.connect(_on_send_pressed)
	input_row.add_child(_send_button)

	_stop_button = Button.new()
	_stop_button.text = "Stop"
	_stop_button.disabled = true
	_stop_button.pressed.connect(func(): stop_requested.emit())
	input_row.add_child(_stop_button)

	_input = TextEdit.new()
	_input.placeholder_text = "Ask about this project, or tell the agent what to build. Ctrl+Enter sends."
	_input.custom_minimum_size = Vector2(0, 84)
	_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_input.gui_input.connect(_on_input_gui_input)
	add_child(_input)

	_status = Label.new()
	_status.text = "Ready."
	_status.add_theme_font_size_override("font_size", 11)
	_status.modulate = Color(1, 1, 1, 0.7)
	add_child(_status)

	_sync_from_config()


func _sync_from_config() -> void:
	var agent_mode := String(session.config.get_value("general", "mode", "agent")) == "agent"
	_mode_button.select(0 if agent_mode else 1)
	_context_check.button_pressed = bool(session.config.get_value("ui", "attach_context", true))


func _connect_session() -> void:
	session.assistant_started.connect(_on_assistant_started)
	session.text_delta.connect(_on_text_delta)
	session.thinking_delta.connect(_on_thinking_delta)
	session.message_added.connect(_on_message_added)
	session.approval_required.connect(_on_approval_required)
	session.tool_call_finished.connect(_on_tool_call_finished)
	session.status_changed.connect(_on_status_changed)
	session.error_occurred.connect(_on_error)
	session.turn_finished.connect(_on_turn_finished)


# ---------------------------------------------------------------------------
# Sending
# ---------------------------------------------------------------------------

func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and event.ctrl_pressed:
		accept_event()
		_on_send_pressed()


func _on_send_pressed() -> void:
	var text := _input.text.strip_edges()
	if text.is_empty() or _busy:
		return
	_input.text = ""
	_send(text)


func _send(text: String) -> void:
	_busy = true
	_send_button.disabled = true
	_stop_button.disabled = false
	_status.text = "Working..."
	var context := ""
	if _context_check.button_pressed:
		context = AIStudioEditorContext.build(session.config)
	session.send(text, context)


func set_busy(busy: bool) -> void:
	_busy = busy
	_send_button.disabled = busy
	_stop_button.disabled = not busy


func focus_input() -> void:
	_input.grab_focus()


# ---------------------------------------------------------------------------
# Session callbacks
# ---------------------------------------------------------------------------

func _on_assistant_started() -> void:
	_stream_text = ""
	_stream_thinking = ""
	_stream_label = RichTextLabel.new()
	_stream_label.bbcode_enabled = true
	_stream_label.fit_content = true
	_stream_label.selection_enabled = true
	_stream_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stream_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stream_panel = _make_panel()
	var box := VBoxContainer.new()
	box.add_child(_role_label("AI Studio"))
	_stream_label.text = "..."
	box.add_child(_stream_label)
	_stream_panel.add_child(box)
	_messages_box.add_child(_stream_panel)
	_scroll_to_bottom()


func _on_text_delta(text: String) -> void:
	if _stream_label == null:
		_on_assistant_started()
	_stream_text += text
	_stream_label.text = AIStudioMarkdown.to_bbcode(_stream_text + " ▌")
	_scroll_to_bottom()


func _on_thinking_delta(text: String) -> void:
	if _stream_label == null:
		_on_assistant_started()
	_stream_thinking += text
	_stream_label.text = "[color=#808080][i]" + AIStudioMarkdown.to_bbcode(_stream_thinking) + "[/i][/color]"


func _on_message_added(message: Dictionary, _index: int) -> void:
	var role := String(message.get("role", ""))
	match role:
		"system":
			var content := String(message.get("content", ""))
			if content.begins_with("## Godot editor context"):
				_add_context_chip(content)
			return
		"assistant":
			var text := String(message.get("content", ""))
			var calls: Array = message.get("tool_calls", [])
			if text.strip_edges().is_empty() and calls.is_empty():
				return
			if _stream_panel != null:
				_stream_panel.queue_free()
				_stream_panel = null
				_stream_label = null
			var panel := _make_panel()
			var box := VBoxContainer.new()
			box.add_child(_role_label("AI Studio"))
			if not text.strip_edges().is_empty():
				box.add_child(_rich(text))
			var thinking := String(message.get("thinking", ""))
			if not thinking.strip_edges().is_empty():
				var thinking_label := _rich("[color=#808080][i]%s[/i][/color]" % AIStudioMarkdown.to_bbcode(thinking))
				thinking_label.visible = false
				var toggle := Button.new()
				toggle.text = "Show reasoning"
				toggle.flat = true
				toggle.pressed.connect(func(): thinking_label.visible = not thinking_label.visible)
				box.add_child(toggle)
				box.add_child(thinking_label)
			panel.add_child(box)
			_messages_box.add_child(panel)
		"user":
			var panel := _make_panel()
			var box := VBoxContainer.new()
			box.add_child(_role_label("You"))
			box.add_child(_rich(String(message.get("content", ""))))
			panel.add_child(box)
			_messages_box.add_child(panel)
		"tool":
			var card := _make_panel(Color(0.13, 0.16, 0.20))
			var box := VBoxContainer.new()
			var title := Label.new()
			title.text = "tool result · %s" % String(message.get("name", "tool"))
			title.add_theme_font_size_override("font_size", 11)
			box.add_child(title)
			var body := String(message.get("content", ""))
			var label := _rich("[code]%s[/code]" % AIStudioMarkdown._escape(body.substr(0, 4000)))
			label.visible = false
			var toggle := Button.new()
			toggle.text = "Show result"
			toggle.flat = true
			toggle.pressed.connect(func():
				label.visible = not label.visible
				toggle.text = "Hide result" if label.visible else "Show result")
			box.add_child(toggle)
			box.add_child(label)
			card.add_child(box)
			_messages_box.add_child(card)
	_scroll_to_bottom()


func _on_tool_call_started(call: Dictionary) -> void:
	var card := _make_panel(Color(0.16, 0.17, 0.10))
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "▶ %s" % String(call.get("name", "tool"))
	title.add_theme_font_size_override("font_size", 12)
	box.add_child(title)
	box.add_child(_rich("[code]%s[/code]" % AIStudioMarkdown._escape(
		AIStudioMarkdown.pretty(call.get("arguments", {}), 1200))))
	card.add_child(box)
	card.set_meta("call_id", String(call.get("id", "")))
	_messages_box.add_child(card)
	_tool_cards[String(call.get("id", ""))] = card
	_scroll_to_bottom()


func _on_approval_required(call: Dictionary) -> void:
	var card := _make_panel(Color(0.22, 0.18, 0.08))
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Permission needed: %s" % String(call.get("name", "tool"))
	box.add_child(title)
	var preview := String(call.get("name", ""))
	if preview.begins_with("mcp_"):
		title.text = "Permission needed (MCP): %s" % String(call.get("name", "tool"))
	box.add_child(_rich("[code]%s[/code]" % AIStudioMarkdown._escape(
		AIStudioMarkdown.pretty(call.get("arguments", {}), 2000))))
	var row := HBoxContainer.new()
	var call_id := String(call.get("id", ""))
	var approve := Button.new()
	approve.text = "Approve"
	approve.pressed.connect(func():
		session.resolve_approval(call_id, "approve")
		card.queue_free())
	row.add_child(approve)
	var approve_all := Button.new()
	approve_all.text = "Approve all this turn"
	approve_all.pressed.connect(func():
		session.resolve_approval(call_id, "approve_all")
		card.queue_free())
	row.add_child(approve_all)
	var deny := Button.new()
	deny.text = "Deny"
	deny.pressed.connect(func():
		session.resolve_approval(call_id, "deny")
		card.queue_free())
	row.add_child(deny)
	box.add_child(row)
	card.add_child(box)
	_messages_box.add_child(card)
	_scroll_to_bottom()


func _on_tool_call_finished(call: Dictionary, result: Dictionary) -> void:
	var call_id := String(call.get("id", ""))
	var card: PanelContainer = _tool_cards.get(call_id)
	if card != null:
		card.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.20, 0.12) if bool(result.get("ok", false)) else Color(0.24, 0.10, 0.10)))
		var title: Label = card.get_child(0).get_child(0)
		title.text = ("✔ " if bool(result.get("ok", false)) else "✖ ") + String(call.get("name", "tool"))
	var body := String(result.get("text", "")) if bool(result.get("ok", false)) else String(result.get("error", ""))
	if not body.strip_edges().is_empty():
		var box: VBoxContainer = card.get_child(0) if card != null else null
		if box != null:
			box.add_child(_rich("[code]%s[/code]" % AIStudioMarkdown._escape(body.substr(0, 3000))))
	_scroll_to_bottom()


func _on_status_changed(status: String, detail: String) -> void:
	match status:
		"idle":
			_status.text = "Ready."
			set_busy(false)
		"error":
			_status.text = "Error: " + detail
			set_busy(false)
		_:
			_status.text = detail


func _on_error(message: String) -> void:
	var panel := _make_panel(Color(0.24, 0.10, 0.10))
	panel.add_child(_rich("[b]Error[/b]\n" + AIStudioMarkdown.to_bbcode(message)))
	_messages_box.add_child(panel)
	_scroll_to_bottom()


func _on_turn_finished(summary: Dictionary) -> void:
	set_busy(false)
	var reason := String(summary.get("stop_reason", ""))
	if reason == "error":
		_status.text = "Stopped after an error. See Settings for the API key / model."
	elif reason == "max_steps":
		_status.text = "Stopped: the tool-step limit was reached. Raise 'Max tool steps' in Settings if this was expected."
	elif reason == "cancelled":
		_status.text = "Cancelled."
	else:
		var usage: Dictionary = summary.get("usage", {})
		_status.text = "Ready. Tokens: %d in / %d out." % [int(usage.get("input", 0)), int(usage.get("output", 0))]


func _add_context_chip(context: String) -> void:
	var label := Label.new()
	var lines := context.split("\n").size()
	label.text = "· editor context attached (%d lines) ·" % lines
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color(1, 1, 1, 0.45)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_messages_box.add_child(label)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_panel(color := Color(0.11, 0.12, 0.14)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(color))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


static func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	return style


static func _role_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(1, 1, 1, 0.6)
	return label


static func _rich(markdown: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.selection_enabled = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = AIStudioMarkdown.to_bbcode(markdown) if not markdown.begins_with("[") else markdown
	return label


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	if _scroll != null:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func clear() -> void:
	for child in _messages_box.get_children():
		child.queue_free()
	_stream_panel = null
	_stream_label = null
	_tool_cards.clear()
