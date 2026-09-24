@tool
class_name AIStudioSettingsView
extends ScrollContainer

## Providers, API keys, model choice and agent behaviour.

var config: AIStudioConfig
var llm: AIStudioLLMClient
var session: AIStudioAgentSession

var _provider_picker: OptionButton
var _key_field: LineEdit
var _key_source: Label
var _base_url: LineEdit
var _model_field: LineEdit
var _model_picker: OptionButton
var _model_status: Label
var _notes: Label
var _test_status: Label
var _system_prompt: TextEdit
var _refresh_button: Button

var _field_by_key: Dictionary = {}


func setup(cfg: AIStudioConfig, llm_client: AIStudioLLMClient, agent_session: AIStudioAgentSession) -> void:
	config = cfg
	llm = llm_client
	session = agent_session
	_build()
	_reload_provider_ui()


func _build() -> void:
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# ---------------- provider ----------------
	root.add_child(_section("Model provider"))

	var prov_row := HBoxContainer.new()
	prov_row.add_child(_label("Provider"))
	_provider_picker = OptionButton.new()
	_provider_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in AIStudioProviders.labels():
		_provider_picker.add_item(String(entry["label"]))
		_provider_picker.set_item_metadata(_provider_picker.item_count - 1, String(entry["id"]))
	_provider_picker.item_selected.connect(func(_i): _on_provider_changed())
	prov_row.add_child(_provider_picker)
	root.add_child(prov_row)

	var key_row := HBoxContainer.new()
	key_row.add_child(_label("API key"))
	_key_field = LineEdit.new()
	_key_field.secret = true
	_key_field.placeholder_text = "sk-..."
	_key_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_field.text_changed.connect(_on_key_changed)
	key_row.add_child(_key_field)
	var key_help := Button.new()
	key_help.text = "Get a key"
	key_help.tooltip_text = "Open the provider's API key page in your browser"
	key_help.pressed.connect(_open_key_page)
	key_row.add_child(key_help)
	root.add_child(key_row)

	_key_source = _hint("")
	root.add_child(_key_source)

	var url_row := HBoxContainer.new()
	url_row.add_child(_label("Base URL"))
	_base_url = LineEdit.new()
	_base_url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_base_url.text_submitted.connect(func(_text: String): _commit_base_url(); _refresh_models())
	# Committing on focus loss as well: otherwise a URL that is typed and then
	# left by clicking elsewhere is silently never saved.
	_base_url.focus_exited.connect(_commit_base_url)
	url_row.add_child(_base_url)
	var url_save := Button.new()
	url_save.text = "Apply"
	url_save.pressed.connect(func(): _commit_base_url(); _refresh_models())
	url_row.add_child(url_save)
	root.add_child(url_row)

	_notes = _hint("")
	_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_notes)

	# ---------------- model ----------------
	root.add_child(_section("Model"))

	var model_row := HBoxContainer.new()
	model_row.add_child(_label("Model ID"))
	_model_field = LineEdit.new()
	_model_field.placeholder_text = "e.g. gpt-5-mini, claude-sonnet-4-6, kr/claude-sonnet-4.5, my-combo"
	_model_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_field.tooltip_text = "Any model id the endpoint accepts. Routers (9Router, LiteLLM, OpenRouter) also take their own aliases and combo names. Press Enter or click 'Use typed model' to save."
	_model_field.text_submitted.connect(func(_text: String): _commit_model())
	# Typed model ids must not be lost when the field simply loses focus - that
	# is what made combo/alias names look like they "did not work".
	_model_field.focus_exited.connect(_commit_model)
	model_row.add_child(_model_field)
	var model_use := Button.new()
	model_use.text = "Use typed model"
	model_use.tooltip_text = "Save the id in the field, even if it is not in the list above (router aliases, combo names)"
	model_use.pressed.connect(func(): _commit_model(); _refresh_models())
	model_row.add_child(model_use)
	root.add_child(model_row)

	var model_row2 := HBoxContainer.new()
	_model_picker = OptionButton.new()
	_model_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_picker.item_selected.connect(func(index: int):
		var model := String(_model_picker.get_item_metadata(index))
		if model.is_empty():
			model = _model_picker.get_item_text(index)
		_model_field.text = model
		config.set_value("general", "model", model)
		config.set_provider_field(config.get_provider_id(), "model", model))
	model_row2.add_child(_model_picker)
	_refresh_button = Button.new()
	_refresh_button.text = "Refresh models"
	_refresh_button.tooltip_text = "Ask the provider for the list of models your key can use"
	_refresh_button.pressed.connect(_refresh_models)
	model_row2.add_child(_refresh_button)
	var test_button := Button.new()
	test_button.text = "Test"
	test_button.tooltip_text = "Send a tiny request to verify key + model"
	test_button.pressed.connect(_test_connection)
	model_row2.add_child(test_button)
	root.add_child(model_row2)

	_model_status = _hint("")
	_model_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_model_status)

	_test_status = _hint("")
	_test_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_test_status)

	# ---------------- behaviour ----------------
	root.add_child(_section("Agent behaviour"))

	root.add_child(_check("stream", "Stream responses (recommended)", true))
	root.add_child(_check("confirm_mutations", "Ask before tools change the project", true))
	root.add_child(_check("approve_mcp_tools", "Ask before MCP tools run", true))
	root.add_child(_check("include_scene_context", "Include the current scene tree in context", true))
	root.add_child(_check("include_selection", "Include the selected nodes in context", true))
	root.add_child(_check("include_project_settings", "Include project settings in context (large)", false))
	root.add_child(_check("save_sessions", "Save conversations to user://ai_studio/sessions", true))
	root.add_child(_check("store_keys_in_config", "Store the API key in the local config file", true))
	root.add_child(_check("game_tools", "Offer runtime game tools (game_*) to the model", true))
	root.add_child(_check("expose_all_game_commands", "Expose every game command as its own tool (+100 tools; some providers cap tools at 128)", false))
	root.add_child(_hint("Keys are read from environment variables first (OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY, NOUS_API_KEY, OPENROUTER_API_KEY). Stored keys live outside the project, in the editor's user data folder, chmod 600 where supported."))

	root.add_child(_number("temperature", "Temperature", 0.0, 2.0, 0.05))
	root.add_child(_number("max_tokens", "Max output tokens (0 = provider default)", 0, 128000, 256))
	root.add_child(_number("max_tool_steps", "Max tool steps per message", 1, 50, 1))
	root.add_child(_number("request_timeout_sec", "Request timeout (seconds)", 10, 1800, 10))

	root.add_child(_section("System prompt"))
	_system_prompt = TextEdit.new()
	_system_prompt.custom_minimum_size = Vector2(0, 140)
	_system_prompt.text = String(config.get_value("general", "system_prompt", ""))
	_system_prompt.placeholder_text = AIStudioEditorContext.default_system_prompt().substr(0, 200) + "..."
	var prompt_row := HBoxContainer.new()
	var prompt_save := Button.new()
	prompt_save.text = "Save prompt"
	prompt_save.pressed.connect(func():
		config.set_value("general", "system_prompt", _system_prompt.text)
		session.new_session()
		_test_status.text = "System prompt saved. New conversations will use it.")
	prompt_row.add_child(prompt_save)
	var prompt_reset := Button.new()
	prompt_reset.text = "Reset to default"
	prompt_reset.pressed.connect(func():
		_system_prompt.text = ""
		config.set_value("general", "system_prompt", "")
		session.new_session()
		_test_status.text = "Using the built-in system prompt again.")
	prompt_row.add_child(prompt_reset)
	root.add_child(prompt_row)
	root.add_child(_system_prompt)

	root.add_child(_section("Danger zone"))
	var wipe := Button.new()
	wipe.text = "Clear stored API keys"
	wipe.pressed.connect(func():
		for pid in AIStudioProviders.ids():
			config.set_provider_field(pid, "api_key", "", false)
		config.save()
		_reload_provider_ui()
		_test_status.text = "Stored keys cleared.")
	root.add_child(wipe)


# ---------------------------------------------------------------------------
# Provider handling
# ---------------------------------------------------------------------------

func _on_provider_changed() -> void:
	var pid := _selected_provider()
	config.set_provider_id(pid)
	_reload_provider_ui()


func _selected_provider() -> String:
	var index := _provider_picker.selected
	if index < 0:
		return AIStudioProviders.DEFAULT_ID
	return String(_provider_picker.get_item_metadata(index))


func _reload_provider_ui() -> void:
	var pid := config.get_provider_id()
	for i in _provider_picker.item_count:
		if String(_provider_picker.get_item_metadata(i)) == pid:
			_provider_picker.select(i)
			break
	var info := AIStudioProviders.get_info(pid)
	_base_url.text = config.base_url(pid)
	_key_field.text = config.stored_api_key(pid)
	_model_field.text = String(config.get_value("general", "model", ""))
	var src := config.key_source(pid)
	_key_source.text = "Key source: %s" % (src if not src.is_empty() else "not configured")
	_notes.text = String(info.get("notes", ""))
	_notes.visible = not String(info.get("notes", "")).is_empty()
	_populate_models()
	_sync_checks()


func _populate_models() -> void:
	_model_picker.clear()
	var pid := config.get_provider_id()
	var models := config.known_models(pid)
	if models.is_empty():
		for hint in AIStudioProviders.get_info(pid).get("hints", []) as Array:
			models.append(String(hint))
	for m in models:
		_model_picker.add_item(m)
		_model_picker.set_item_metadata(_model_picker.item_count - 1, m)
	var current := config.get_model()
	if not current.is_empty() and not models.has(current):
		# A router alias or combo name that the provider does not list.
		_model_picker.add_item(current + "  (typed)")
		_model_picker.set_item_metadata(_model_picker.item_count - 1, current)
		_model_picker.select(_model_picker.item_count - 1)
	if models.is_empty() and current.is_empty():
		_model_picker.add_item("(press Refresh models)")
		_model_picker.set_item_metadata(0, "")
	_model_status.text = "%d model(s) known for this provider. Refresh loads the live list from the provider; a model id that is not listed (router alias, combo name) can be typed in directly." % models.size()


## Saves whatever is in the model field. Used by Enter, by focus loss and before
## Test/Refresh - typing a model and clicking elsewhere used to change nothing.
func _commit_model() -> void:
	var pid := config.get_provider_id()
	var typed := _model_field.text.strip_edges()
	if typed == config.get_model():
		return
	config.set_value("general", "model", typed, false)
	config.set_provider_field(pid, "model", typed, true)
	_populate_models()


## Saves the base URL and shows the normalised form (so `http://host:port`
## visibly becomes `http://host:port/v1`).
func _commit_base_url() -> void:
	var pid := config.get_provider_id()
	var typed := _base_url.text.strip_edges()
	config.set_provider_field(pid, "base_url", typed)
	var effective := config.base_url(pid)
	if effective != typed:
		_base_url.text = effective
		_model_status.text = "Base URL saved as %s." % effective


func _on_key_changed(text: String) -> void:
	var pid := config.get_provider_id()
	config.set_provider_field(pid, "api_key", text.strip_edges(), false)
	config.save()
	var src := config.key_source(pid)
	_key_source.text = "Key source: %s" % (src if not src.is_empty() else "not configured")


func _open_key_page() -> void:
	var url := String(AIStudioProviders.get_info(config.get_provider_id()).get("key_url", ""))
	if url.is_empty():
		_test_status.text = "This provider has no documented key page."
		return
	OS.shell_open(url)


func _refresh_models() -> void:
	var pid := config.get_provider_id()
	# Whatever was typed is what the user means, so persist it before asking the
	# provider anything (also covers "typed a combo, then pressed Refresh").
	_commit_model()
	_refresh_button.disabled = true
	_model_status.text = "Loading models from %s..." % pid
	config.set_provider_field(pid, "base_url", _base_url.text)
	var res: Dictionary = await llm.list_models(pid)
	_refresh_button.disabled = false
	if not bool(res["ok"]):
		_model_status.text = "Could not load models: " + String(res["error"])
		return
	var models: PackedStringArray = res["models"]
	config.set_known_models(pid, models)
	if config.get_model().is_empty() and models.size() > 0:
		var preferred := AIStudioProviders.default_model(pid)
		var chosen := preferred if models.has(preferred) else String(models[0])
		config.set_value("general", "model", chosen)
		config.set_provider_field(pid, "model", chosen)
	_populate_models()
	_model_field.text = config.get_model()
	_model_status.text = "Loaded %d model(s)." % models.size()


func _test_connection() -> void:
	var pid := config.get_provider_id()
	_commit_model()
	_commit_base_url()
	_test_status.text = "Testing %s / %s ..." % [pid, config.get_model()]
	var messages := [
		{"role": "system", "content": "You are a connectivity test. Answer with exactly: OK"},
		{"role": "user", "content": "Reply with OK."},
	]
	var res: Dictionary = await llm.stream_chat(messages, [], {
		"provider": pid, "model": config.get_model(), "stream": false, "timeout_sec": 45.0,
	})
	if bool(res.get("ok", false)):
		_test_status.text = "Success: %s replied with '%s'." % [String(res.get("model", "")), String(res.get("text", "")).strip_edges().substr(0, 80)]
	else:
		_test_status.text = "Failed: " + String(res.get("error", "unknown error"))


# ---------------------------------------------------------------------------
# Generic field helpers
# ---------------------------------------------------------------------------

func _check(key: String, text: String, default: bool) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = bool(config.get_value("general", key, default))
	box.toggled.connect(func(on: bool): config.set_value("general", key, on))
	_field_by_key[key] = box
	return box


func _number(key: String, text: String, minimum: float, maximum: float, step: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_label(text))
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value = float(config.get_value("general", key, 0.0))
	spin.value_changed.connect(func(value: float): config.set_value("general", key, value))
	row.add_child(spin)
	_field_by_key[key] = spin
	return row


func _sync_checks() -> void:
	# MCP-related toggles live on the MCP tab but reflect the same config keys.
	pass


static func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(210, 0)
	return label


static func _hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(1, 1, 1, 0.62)
	return label


static func _section(title: String) -> Label:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(1, 1, 1, 0.85)
	return label
