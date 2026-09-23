@tool
class_name AIStudioConfig
extends RefCounted

## Persistent plugin configuration.
##
## Stored in the editor's user data directory:
##     <user data>/ai_studio/config.cfg        (Windows: %APPDATA%/Godot/ai_studio/...)
## and never inside the project, so API keys cannot be committed to git by
## accident. Keys may also be supplied through environment variables (see
## AIStudioProviders.key_env) - environment values always win over the file,
## which makes CI / shared machines safe.
##
## Project-local overrides are supported for *non-secret* settings only, via
##     <project>/.ai_studio.json
## which is handy for per-project model choices and MCP server definitions that
## a team wants to share in version control.

signal changed()

const CONFIG_DIR := "user://ai_studio"
const CONFIG_PATH := "user://ai_studio/config.cfg"
const PROJECT_OVERRIDE_PATH := "res://.ai_studio.json"
const SCHEMA_VERSION := 1

const DEFAULTS := {
	"general": {
		"provider": "openai",
		"model": "",
		"mode": "agent",                    # "chat" | "agent"
		"stream": true,
		"temperature": 0.4,
		"max_tokens": 0,                    # 0 = provider default
		"max_tool_steps": 12,
		"request_timeout_sec": 180,
		"confirm_mutations": true,           # ask before Godot tools change the project
		"approve_mcp_tools": true,           # MCP tools ask by default
		"auto_approve_safe_tools": true,     # read-only Godot tools never ask
		"include_scene_context": true,
		"include_selection": true,
		"include_project_settings": false,
		"system_prompt": "",
		"save_sessions": true,
		"store_keys_in_config": true,        # off => keep keys in env vars only
	},
	"ui": {
		"last_tab": 0,
		"show_tool_cards": true,
		"max_context_lines": 400,
	},
	"mcp": {
		"enabled": true,
		"auto_connect": true,
		"allow_project_servers": false,      # .ai_studio.json may not spawn processes without consent
		"startup_timeout_ms": 15000,
		"tool_timeout_ms": 120000,
		"protocol_version": "2025-11-25",
		"allow_sampling": true,              # let servers ask our model for completions
		"sampling_max_tokens": 2048,
	},
}

## Keys that a project-local `.ai_studio.json` is *not* allowed to change.
##
## The file is committed to version control and therefore travels with any
## cloned project, so it must never be able to lower a safety barrier (approval
## prompts, sampling, auto-starting MCP servers) or smuggle in a secret.
const PROJECT_OVERRIDE_BLOCKED := {
	"general": ["confirm_mutations", "approve_mcp_tools", "auto_approve_safe_tools", "system_prompt"],
	"mcp": ["auto_connect", "allow_project_servers", "allow_sampling", "enabled"],
	"providers": ["api_key"],
}

var data: Dictionary = {}
var project_override: Dictionary = {}
var _config := ConfigFile.new()


func _init() -> void:
	reset_to_defaults()
	load_from_disk()


# ---------------------------------------------------------------------------
# Loading / saving
# ---------------------------------------------------------------------------

func reset_to_defaults() -> void:
	data = DEFAULTS.duplicate(true)


func load_from_disk() -> void:
	var err := _config.load(CONFIG_PATH)
	if err != OK:
		reset_to_defaults()
		_load_project_override()
		return
	var loaded := {}
	for section in _config.get_sections():
		var parts := section.split("/")
		for value_key in _config.get_section_keys(section):
			_assign_nested(loaded, parts, value_key, _config.get_value(section, value_key))
	data = _deep_merge(DEFAULTS.duplicate(true), loaded)
	_load_project_override()


## Writes one value into a nested Dictionary along a "a/b/c" style path.
## Dictionaries merge (so `[mcp]` and `[mcp/servers/x]` cannot erase each other
## regardless of the order sections come back from ConfigFile), scalars replace.
static func _assign_nested(target: Dictionary, path_parts: PackedStringArray, key: String, value: Variant) -> void:
	var cursor: Dictionary = target
	for part in path_parts:
		if not cursor.has(part) or typeof(cursor[part]) != TYPE_DICTIONARY:
			cursor[part] = {}
		cursor = cursor[part]
	if typeof(cursor.get(key)) == TYPE_DICTIONARY and typeof(value) == TYPE_DICTIONARY:
		cursor[key] = _deep_merge(cursor[key], value)
	else:
		cursor[key] = value


func _load_project_override() -> void:
	project_override = {}
	if not FileAccess.file_exists(PROJECT_OVERRIDE_PATH):
		return
	var f := FileAccess.open(PROJECT_OVERRIDE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		project_override = parsed


func save() -> Error:
	ensure_dir(CONFIG_DIR)
	data["schema_version"] = SCHEMA_VERSION
	_config = ConfigFile.new()
	for key in DEFAULTS.keys():
		if key == "mcp":
			continue  # written below, section by section (see _write_mcp_sections)
		var section: Dictionary = data.get(key, {})
		for field in section.keys():
			_config.set_value(key, field, section[field])
	# MCP servers live only in their own `mcp/servers/<name>` sections so that a
	# `[mcp]` section can never shadow them (the old duplicate form is still read,
	# see load_from_disk()).
	var mcp_section: Dictionary = data.get("mcp", {})
	for field in mcp_section.keys():
		if field == "servers":
			continue
		_config.set_value("mcp", field, mcp_section[field])
	var servers = mcp_section.get("servers", {})
	if typeof(servers) != TYPE_DICTIONARY:
		servers = {}
	for name in servers.keys():
		var srv: Dictionary = servers[name]
		for field in srv.keys():
			_config.set_value("mcp/servers/" + String(name), field, srv[field])
	var store_keys := bool(get_value("general", "store_keys_in_config", true))
	var has_stored_key := false
	for pid in AIStudioProviders.ids():
		var prov: Dictionary = data.get("providers", {}).get(pid, {})
		for field in prov.keys():
			if field == "api_key":
				if not store_keys:
					continue
				if not String(prov[field]).is_empty():
					has_stored_key = true
			_config.set_value("providers/" + pid, field, prov[field])
	var err := _config.save(CONFIG_PATH)
	if err == OK and has_stored_key:
		_restrict_permissions()
	changed.emit()
	return err


## Best effort "chmod 600" so a config holding an API key is not world readable.
func _restrict_permissions() -> void:
	if OS.get_name() == "Windows":
		return
	var abs_path := ProjectSettings.globalize_path(CONFIG_PATH)
	OS.execute("chmod", PackedStringArray(["600", abs_path]), [], false)


# ---------------------------------------------------------------------------
# Generic accessors
# ---------------------------------------------------------------------------

## Reads a setting. `res://.ai_studio.json` wins over the stored value for the
## keys it is allowed to set (see PROJECT_OVERRIDE_BLOCKED): without that, a
## project file could silently turn approval prompts off or pin an API key.
func get_value(section: String, key: String, default: Variant = null) -> Variant:
	var override_sec: Dictionary = project_override.get(section, {})
	if override_sec.has(key) and not _override_blocked(section, key):
		return override_sec[key]
	var sec: Dictionary = data.get(section, {})
	if sec.has(key):
		return sec[key]
	return default


static func _override_blocked(section: String, key: String) -> bool:
	return (PROJECT_OVERRIDE_BLOCKED.get(section, []) as Array).has(key)


func set_value(section: String, key: String, value: Variant, autosave: bool = true) -> void:
	if not data.has(section):
		data[section] = {}
	data[section][key] = value
	if autosave:
		save()


func get_provider_id() -> String:
	var id := String(get_value("general", "provider", AIStudioProviders.DEFAULT_ID))
	if not AIStudioProviders.PROVIDERS.has(id):
		return AIStudioProviders.DEFAULT_ID
	return id


func set_provider_id(id: String) -> void:
	# Remember the model per provider before switching, so moving between, say,
	# a 9Router combo and OpenAI does not leak one provider's model into the other.
	var previous := get_provider_id()
	var current_model := get_model()
	if not current_model.is_empty() and previous != id:
		set_provider_field(previous, "model", current_model, false)
	set_value("general", "provider", id, false)
	var info := AIStudioProviders.get_info(id)
	var remembered := String(get_provider_field(id, "model", ""))
	set_value("general", "model", remembered if not remembered.is_empty() else String(info.get("default_model", "")))


func get_model() -> String:
	return String(get_value("general", "model", ""))


# ---------------------------------------------------------------------------
# Providers
# ---------------------------------------------------------------------------

func get_provider_field(provider_id: String, key: String, default: Variant = null) -> Variant:
	var override_prov: Dictionary = project_override.get("providers", {}).get(provider_id, {})
	if override_prov.has(key) and not _override_blocked("providers", key):
		return override_prov[key]
	var prov: Dictionary = data.get("providers", {}).get(provider_id, {})
	if prov.has(key):
		return prov[key]
	return default


func set_provider_field(provider_id: String, key: String, value: Variant, autosave: bool = true) -> void:
	if not data.has("providers"):
		data["providers"] = {}
	if not data["providers"].has(provider_id):
		data["providers"][provider_id] = {}
	data["providers"][provider_id][key] = value
	if autosave:
		save()


func base_url(provider_id: String = "") -> String:
	var pid := provider_id if not provider_id.is_empty() else get_provider_id()
	var info := AIStudioProviders.get_info(pid)
	var custom := String(get_provider_field(pid, "base_url", ""))
	var chosen := custom if not custom.is_empty() else String(info.get("base_url", ""))
	var out := _strip_trailing_slash(chosen)
	if bool(info.get("normalize_base_url", false)):
		out = normalize_openai_base(out)
	return out


## OpenAI-compatible gateways are usually spoken to at `<host>:<port>/v1`.
## Users type `http://localhost:20128` (as 9Router's own docs do in places) and
## then every request 404s, so a URL without a path gets `/v1` appended.
static func normalize_openai_base(url: String) -> String:
	var u := _strip_trailing_slash(url)
	if u.is_empty():
		return u
	var scheme_end := u.find("://")
	if scheme_end < 0:
		return u
	var rest := u.substr(scheme_end + 3)
	if rest.find("/") < 0:
		return u + "/v1"
	return u



func api_style(provider_id: String = "") -> String:
	var pid := provider_id if not provider_id.is_empty() else get_provider_id()
	return AIStudioProviders.api_of(pid)


## Raw key as configured (config file). Prefer resolve_api_key().
func stored_api_key(provider_id: String) -> String:
	return String(get_provider_field(provider_id, "api_key", ""))


## Effective API key: environment variable first, then the stored value.
func resolve_api_key(provider_id: String = "") -> String:
	var pid := provider_id if not provider_id.is_empty() else get_provider_id()
	var info := AIStudioProviders.get_info(pid)
	for env_name in info.get("key_env", []) as Array:
		var v := OS.get_environment(String(env_name))
		if not v.strip_edges().is_empty():
			return v.strip_edges()
	var stored := stored_api_key(pid)
	if not stored.is_empty():
		return stored
	# Local providers do not need a real key; send a placeholder so clients that
	# insist on an Authorization header still work.
	if not bool(info.get("needs_key", true)):
		return "sk-local"
	return ""


func key_source(provider_id: String) -> String:
	var info := AIStudioProviders.get_info(provider_id)
	for env_name in info.get("key_env", []) as Array:
		if not OS.get_environment(String(env_name)).strip_edges().is_empty():
			return "env:" + String(env_name)
	if not stored_api_key(provider_id).is_empty():
		return "config file"
	if not bool(info.get("needs_key", true)):
		return "not required"
	return ""


func extra_headers(provider_id: String) -> Dictionary:
	var base: Dictionary = (AIStudioProviders.get_info(provider_id).get("extra_headers", {}) as Dictionary).duplicate()
	var custom = get_provider_field(provider_id, "extra_headers", {})
	if typeof(custom) == TYPE_DICTIONARY:
		base.merge(custom, true)
	elif typeof(custom) == TYPE_STRING and not String(custom).strip_edges().is_empty():
		var parsed = JSON.parse_string(String(custom))
		if typeof(parsed) == TYPE_DICTIONARY:
			base.merge(parsed, true)
	return base


## Models the user has discovered/entered for this provider.
func known_models(provider_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cached = get_provider_field(provider_id, "known_models", [])
	if typeof(cached) == TYPE_ARRAY:
		for m in cached:
			out.append(String(m))
	return out


func set_known_models(provider_id: String, models: PackedStringArray) -> void:
	set_provider_field(provider_id, "known_models", Array(models))


# ---------------------------------------------------------------------------
# MCP servers
# ---------------------------------------------------------------------------

func mcp_servers() -> Dictionary:
	var mcp: Dictionary = data.get("mcp", {})
	var servers = mcp.get("servers", {})
	if typeof(servers) != TYPE_DICTIONARY:
		return {}
	var merged := (servers as Dictionary).duplicate(true)
	var override_servers: Dictionary = project_override.get("mcp", {}).get("servers", {})
	for name in override_servers.keys():
		merged[name] = _deep_merge(merged.get(name, {}), override_servers[name])
	return merged


func mcp_server(name: String) -> Dictionary:
	return mcp_servers().get(name, {})


## Servers that only exist because the *project* ships a `.ai_studio.json`.
##
## A cloned project can therefore ask the editor to launch a process; the plugin
## never does that on its own unless the user opted in with
## `mcp.allow_project_servers` (MCP tab: "Trust this project's servers").
func project_server_names() -> PackedStringArray:
	var out := PackedStringArray()
	var override_servers: Dictionary = project_override.get("mcp", {}).get("servers", {})
	for name in override_servers.keys():
		out.append(String(name))
	return out


func is_project_server(name: String) -> bool:
	return project_server_names().has(name)


func project_servers_allowed() -> bool:
	return bool(get_value("mcp", "allow_project_servers", false))


func set_mcp_server(name: String, definition: Dictionary) -> void:
	if not data.has("mcp"):
		data["mcp"] = DEFAULTS["mcp"].duplicate(true)
	if not data["mcp"].has("servers"):
		data["mcp"]["servers"] = {}
	data["mcp"]["servers"][name] = definition
	save()


func remove_mcp_server(name: String) -> void:
	if data.has("mcp") and data["mcp"].has("servers"):
		data["mcp"]["servers"].erase(name)
		save()


## Normalises a possibly partial server definition into a complete one.
static func normalise_server(def: Dictionary) -> Dictionary:
	var out := {
		"enabled": true,
		"transport": "stdio",       # "stdio" | "http"
		"command": "",
		"args": [],
		"env": {},
		"cwd": "",
		"shell_wrap": OS.get_name() == "Windows",
		"url": "",
		"headers": {},
		"tool_allow": [],
		"tool_deny": [],
		"auto_approve": false,
		"notes": "",
	}
	out.merge(def, true)
	# A definition that only carries a url is an HTTP server; one with a
	# command is a stdio server. Only guess when the caller did not say.
	if not def.has("transport"):
		var has_url := not String(def.get("url", "")).strip_edges().is_empty()
		var has_command := not String(def.get("command", "")).strip_edges().is_empty()
		out["transport"] = "http" if has_url and not has_command else "stdio"
	out["transport"] = String(out["transport"]).to_lower()
	if typeof(out["args"]) == TYPE_STRING:
		out["args"] = _split_args(String(out["args"]))
	if typeof(out["args"]) != TYPE_ARRAY:
		out["args"] = []
	if typeof(out["tool_allow"]) == TYPE_STRING:
		out["tool_allow"] = _split_csv(String(out["tool_allow"]))
	if typeof(out["tool_deny"]) == TYPE_STRING:
		out["tool_deny"] = _split_csv(String(out["tool_deny"]))
	if typeof(out["env"]) != TYPE_DICTIONARY:
		out["env"] = {}
	if typeof(out["headers"]) != TYPE_DICTIONARY:
		out["headers"] = {}
	return out


static func _split_args(s: String) -> Array:
	var out: Array = []
	for part in s.split(" ", false):
		if not part.is_empty():
			out.append(part)
	return out


static func _split_csv(s: String) -> Array:
	var out: Array = []
	for part in s.split(",", false):
		var t := part.strip_edges()
		if not t.is_empty():
			out.append(t)
	return out


# ---------------------------------------------------------------------------
# Hermes Agent MCP presets
# ---------------------------------------------------------------------------

## Ready-to-use MCP definitions for Nous Research's Hermes Agent.
## `hermes mcp serve` exposes Hermes' own tools over stdio; a hosted HTTP
## endpoint can be used instead by switching transport to "http".
static func hermes_agent_presets() -> Dictionary:
	return {
		"hermes-stdio": {
			"enabled": true,
			"transport": "stdio",
			"command": "hermes",
			"args": ["mcp", "serve"],
			"shell_wrap": OS.get_name() == "Windows",
			"notes": "Hermes Agent as an MCP server (stdio). Requires `hermes mcp serve` support; install Hermes from github.com/NousResearch/hermes-agent.",
		},
		"hermes-http": {
			"enabled": false,
			"transport": "http",
			"url": "http://127.0.0.1:8765/mcp",
			"headers": {},
			"notes": "Hermes Agent MCP over HTTP. Start it with `hermes serve-mcp --transport http --port 8765` (or wherever your deployment listens).",
		},
	}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a user:// directory (the *_absolute DirAccess helpers need a real path).
static func ensure_dir(path: String) -> void:
	var absolute := path
	if path.begins_with("user://") or path.begins_with("res://"):
		absolute = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		DirAccess.make_dir_recursive_absolute(absolute)


static func redact(secret: String) -> String:
	var s := secret.strip_edges()
	if s.is_empty():
		return ""
	if s.length() <= 8:
		return "****"
	return s.substr(0, 4) + "..." + s.substr(s.length() - 4)


static func _strip_trailing_slash(url: String) -> String:
	var out := url.strip_edges()
	while out.ends_with("/"):
		out = out.substr(0, out.length() - 1)
	return out


static func _deep_merge(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in overlay.keys():
		if typeof(out.get(key)) == TYPE_DICTIONARY and typeof(overlay[key]) == TYPE_DICTIONARY:
			out[key] = _deep_merge(out[key], overlay[key])
		else:
			out[key] = overlay[key]
	return out
