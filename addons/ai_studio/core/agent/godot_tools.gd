@tool
class_name AIStudioGodotTools
extends RefCounted

## The built-in tool set that lets a model read and modify the Godot project it
## is running in. Every tool is declared with a JSON schema plus a `safe` flag:
## safe tools only read, everything else is gated behind user approval (unless
## the user turns approvals off in Settings).
##
## Read-only safety rails: everything is confined to the project directory.
## Write safety rails: res:// only, text formats only, size limits, no writes
## into addons/ai_studio itself, and a .bak copy of overwritten files.

const MAX_READ_BYTES := 400_000
const MAX_WRITE_BYTES := 2_000_000
const TEXT_EXTENSIONS := ["gd", "tscn", "tres", "godot", "json", "cfg", "md", "txt", "csv", "tsv",
	"shader", "gdshader", "gdshaderinc", "po", "pot", "svg", "xml", "yaml", "yml", "ini", "env.example"]
const WRITE_EXTENSIONS := ["gd", "cs", "tscn", "tres", "json", "cfg", "md", "txt", "csv", "shader", "gdshader",
	"gdshaderinc", "po", "pot", "svg", "xml", "yaml", "yml", "ini"]

var _handlers: Dictionary = {}
var _definitions: Array = []
## Tools that can only run inside a real editor session (they talk to
## EditorInterface). Headless/exported runs get a clean error instead.
var _editor_only: Dictionary = {}
var _screenshot_dir := "user://ai_studio/shots"
## Per-call safety for tools whose risk depends on the arguments
## (e.g. game_command is read-only for some commands only).
var _safe_fns: Dictionary = {}
## Tool categories hidden from the model (still callable by name).
var _hidden_categories: Dictionary = {"game_all": true}
var game_bridge: AIStudioGameBridge = null
## Tools that always ask before running, even with approvals switched off.
var _always_confirm: Dictionary = {}


func _init() -> void:
	_register_all()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func definitions(include_unsafe: bool = true, include_hidden: bool = false) -> Array:
	var out: Array = []
	for d in _definitions:
		var name := String(d["function"]["name"])
		if not include_unsafe and not bool(_handlers[name]["safe"]):
			continue
		if not include_hidden and _hidden_categories.has(String(_handlers[name]["category"])):
			continue
		out.append(d.duplicate(true))
	return out


## Applies the tool-visibility settings. Runtime game tools: off, compact
## (default: everyday commands + game_command) or every command as a tool.
func apply_config(config: AIStudioConfig) -> void:
	_hidden_categories = {}
	if not bool(config.get_value("general", "game_tools", true)):
		_hidden_categories["game"] = true
		_hidden_categories["game_all"] = true
	elif not bool(config.get_value("general", "expose_all_game_commands", false)):
		_hidden_categories["game_all"] = true


func category_of(tool_name: String) -> String:
	return String(_handlers.get(tool_name, {}).get("category", ""))


func definition_names() -> PackedStringArray:
	var out := PackedStringArray()
	for d in _definitions:
		out.append(String(d["function"]["name"]))
	return out


func is_safe(tool_name: String) -> bool:
	return bool(_handlers.get(tool_name, {}).get("safe", false))


## Like is_safe(), but also consults argument-dependent rules.
func is_safe_call(tool_name: String, args: Dictionary) -> bool:
	if _safe_fns.has(tool_name):
		return bool((_safe_fns[tool_name] as Callable).call(args))
	return is_safe(tool_name)


## Marks a tool as always needing the user's approval (see agent_session).
func always_confirm(tool_name: String) -> void:
	_always_confirm[tool_name] = true


func requires_confirmation(tool_name: String) -> bool:
	return _always_confirm.has(tool_name)


func _set_safe_fn(tool_name: String, fn: Callable) -> void:
	_safe_fns[tool_name] = fn


func has(tool_name: String) -> bool:
	return _handlers.has(tool_name)


## Executes a tool. Always returns {"ok": bool, "text": String, "error": String}.
func call_tool(tool_name: String, args: Dictionary) -> Dictionary:
	if not _handlers.has(tool_name):
		return {"ok": false, "text": "", "error": "Unknown tool: " + tool_name}
	if _editor_only.has(tool_name) and not AIStudioEditorEnv.available():
		return {"ok": false, "text": "",
			"error": "Tool '%s' needs a running Godot editor and is unavailable here." % tool_name}
	var handler: Callable = _handlers[tool_name]["handler"]
	var out = await handler.call(args)
	if out == null:
		return {"ok": false, "text": "",
			"error": "Tool '%s' returned nothing - it hit a script error, see the Godot output." % tool_name}
	if typeof(out) != TYPE_DICTIONARY:
		return {"ok": true, "text": String(out), "error": ""}
	if not out.has("ok"):
		out["ok"] = true
	if not out.has("error"):
		out["error"] = ""
	if not out.has("text"):
		out["text"] = ""
	return out


# ---------------------------------------------------------------------------
# Registration helpers
# ---------------------------------------------------------------------------

func _add(name: String, description: String, parameters: Dictionary, handler: Callable, safe: bool, category: String) -> void:
	_definitions.append({
		"type": "function",
		"function": {"name": name, "description": description, "parameters": parameters},
	})
	_handlers[name] = {"handler": handler, "safe": safe, "category": category}


static func _obj(props: Dictionary, required: Array = []) -> Dictionary:
	var out := {"type": "object", "properties": props}
	if not required.is_empty():
		out["required"] = required
	return out


static func _str(desc: String, default: String = "") -> Dictionary:
	var out := {"type": "string", "description": desc}
	if not default.is_empty():
		out["default"] = default
	return out


static func _bool(desc: String, default: bool = false) -> Dictionary:
	return {"type": "boolean", "description": desc, "default": default}


static func _int(desc: String, default: int = 0) -> Dictionary:
	return {"type": "integer", "description": desc, "default": default}


func _ok(text: String) -> Dictionary:
	return {"ok": true, "text": text, "error": ""}


func _err(message: String) -> Dictionary:
	return {"ok": false, "text": "", "error": message}


func _register_all() -> void:
	# ---------------- read-only ----------------
	_add("godot_project_info",
		"Overview of the Godot project: engine version, project name, main scene, settings summary, top level folders, counts of scenes/scripts, autoloads and input actions.",
		_obj({}), func(_a): return _tool_project_info(), true, "context")

	_add("godot_scene_tree",
		"The node tree of the currently edited scene, with node types, names, scripts and selected markers.",
		_obj({"max_depth": _int("How deep to descend (default 8, max 32).", 8)}),
		func(a): return _tool_scene_tree(a), true, "context")

	_add("godot_get_selection",
		"Nodes currently selected in the editor, with their important properties.",
		_obj({}), func(_a): return _tool_selection(), true, "context")

	_add("godot_editor_state",
		"Editors path/state: edited scene, open scenes, unsaved scenes, files selected in the FileSystem dock, whether the game is running.",
		_obj({}), func(_a): return _tool_editor_state(), true, "context")

	_add("godot_get_node",
		"Details of one node: class, script, properties (values), signals with connections, and children names.",
		_obj({
			"node_path": _str("Path relative to the edited scene root, e.g. 'Player/Sprite2D'. Empty = the scene root."),
			"include_properties": _bool("Include full property list (can be long).", true),
		}, ["node_path"]),
		func(a): return _tool_get_node(a), true, "context")

	_add("godot_read_file",
		"Read a text file from the project (res:// path). Supports line ranges; output is truncated for very large files.",
		_obj({
			"path": _str("res:// path, e.g. 'res://scripts/player.gd'."),
			"start_line": _int("First line (1-based, default 1).", 1),
			"line_count": _int("How many lines to return (default 0 = all).", 0),
		}, ["path"]),
		func(a): return _tool_read_file(a), true, "files")

	_add("godot_list_dir",
		"List files and folders inside a project directory.",
		_obj({"path": _str("res:// directory (default 'res://').", "res://"),
			"recursive": _bool("Descend into subfolders (default false).", false)}),
		func(a): return _tool_list_dir(a), true, "files")

	_add("godot_find_files",
		"Find project files by name/path pattern and optionally by text content (like grep).",
		_obj({
			"pattern": _str("Glob for the path, e.g. '*.gd' or 'scenes/**/*.tscn'."),
			"contains": _str("Optional text that the file must contain."),
			"max_results": _int("Maximum results (default 60).", 60),
		}, ["pattern"]),
		func(a): return _tool_find_files(a), true, "files")

	_add("godot_project_settings",
		"Read ProjectSettings values (supports a glob, e.g. 'display/*' or 'input/*').",
		_obj({"pattern": _str("Glob pattern, default 'application/*'.", "application/*"),
			"max_results": _int("Maximum entries (default 60).", 60)}),
		func(a): return _tool_project_settings(a), true, "context")

	_add("godot_class_reference",
		"Engine class reference from the running editor (ClassDB): inheritance, methods, properties, signals, constants. Use it before writing code against an API you are unsure about.",
		_obj({
			"class_name": _str("Engine class, e.g. 'CharacterBody2D'."),
			"member": _str("Optional: only show this method/property/signal/constant."),
			"show_inherited": _bool("Include inherited members (default false).", false),
		}, ["class_name"]),
		func(a): return _tool_class_reference(a), true, "context")

	_add("godot_capture_screenshot",
		"Capture a PNG of the editor's 2D/3D viewport (useful for vision models, and returned as a file path).",
		_obj({"view": _str("'3d' or '2d'.", "3d")}),
		func(a): return _tool_capture(a), true, "context")

	# ---------------- mutating (approval gated) ----------------
	_add("godot_write_file",
		"Create or overwrite a text file in the project (res:// only). A .bak copy is written next to files that already exist.",
		_obj({
			"path": _str("res:// path to write."),
			"content": _str("Full new file content."),
		}, ["path", "content"]),
		func(a): return _tool_write_file(a), false, "files")

	_add("godot_add_node",
		"Add a node to the edited scene (undo aware). Provide the parent path relative to the scene root, the class name, and an optional node name.",
		_obj({
			"parent_path": _str("Parent path relative to the scene root; '' or '.' means the root."),
			"type": _str("Engine class, e.g. 'Node2D', 'Sprite2D', 'Label'."),
			"name": _str("Node name (optional)."),
			"properties": {"type": "object", "description": "Optional properties to set, e.g. {\"position\": \"Vector2(100, 50)\"}", "additionalProperties": true},
		}, ["parent_path", "type"]),
		func(a): return _tool_add_node(a), false, "scene")

	_add("godot_rename_node",
		"Rename a node in the edited scene (undo aware).",
		_obj({"node_path": _str("Node path relative to the scene root."), "new_name": _str("New node name.")},
			["node_path", "new_name"]),
		func(a): return _tool_rename_node(a), false, "scene")

	_add("godot_remove_node",
		"Remove (delete) a node and its children from the edited scene (undo aware).",
		_obj({"node_path": _str("Node path relative to the scene root.")}, ["node_path"]),
		func(a): return _tool_remove_node(a), false, "scene")

	_add("godot_set_node_property",
		"Set a property on a node in the edited scene (undo aware). Values are parsed as Godot literals, so 'Vector2(10, 20)', 'true', '3.5' and '\"text\"' all work.",
		_obj({
			"node_path": _str("Node path relative to the scene root."),
			"property": _str("Property name, e.g. 'position' or 'text'."),
			"value": _str("New value as a Godot literal or JSON."),
		}, ["node_path", "property", "value"]),
		func(a): return _tool_set_property(a), false, "scene")

	_add("godot_instantiate_scene",
		"Instance a PackedScene (.tscn) as a child of a node in the edited scene (undo aware).",
		_obj({
			"scene_path": _str("res:// path to the .tscn/.scn file."),
			"parent_path": _str("Parent node path relative to the scene root ('' = root)."),
			"name": _str("Optional instance name."),
		}, ["scene_path", "parent_path"]),
		func(a): return _tool_instantiate(a), false, "scene")

	_add("godot_attach_script",
		"Create a GDScript file (if needed) and attach it to a node in the edited scene.",
		_obj({
			"node_path": _str("Node path relative to the scene root."),
			"script_path": _str("res:// path of the .gd file, e.g. 'res://scripts/player.gd'."),
			"content": _str("Script source. If empty and the file exists, the existing script is attached."),
		}, ["node_path", "script_path"]),
		func(a): return _tool_attach_script(a), false, "scene")

	_add("godot_open_scene",
		"Open a scene in the editor (and optionally a script in the script editor).",
		_obj({
			"scene_path": _str("res:// path of the scene."),
			"script_path": _str("Optional res:// path of a script to open."),
			"line": _int("Line to jump to (1-based).", 0),
		}, ["scene_path"]),
		func(a): return _tool_open_scene(a), false, "navigation")

	_add("godot_save_scenes",
		"Save the current scene (and optionally all open scenes).",
		_obj({"all": _bool("Save every open scene instead of only the edited one.", false)}),
		func(a): return _tool_save_scenes(a), false, "navigation")

	_add("godot_play_scene",
		"Run a scene in the editor (starts the game). Empty path runs the currently edited scene.",
		_obj({"scene_path": _str("Optional res:// path of the scene to run.")}),
		func(a): return _tool_play_scene(a), false, "navigation")

	_add("godot_stop_playing",
		"Stop the running game.",
		_obj({}), func(_a): return _tool_stop_playing(), false, "navigation")

	_add("godot_rescan_filesystem",
		"Ask the editor to rescan the project filesystem (useful after generating files outside the editor).",
		_obj({}), func(_a): return _tool_rescan(), false, "files")

	# 3D, rig, animation, material, physics and import tools live in their own
	# module and register into this registry (they reuse the guards below).
	AIStudioGodot3DTools.new(self).register()

	# Project, scene-file, resource, script, input/autoload/layer, export and CI
	# tools, plus the runtime game bridge (ported from godot-mcp).
	AIStudioGodotMcpTools.new(self).register()
	game_bridge = AIStudioGameBridge.new(self)
	game_bridge.register()

	# Animation-name fixes, in-place animation edits, editor script and log.
	AIStudioGodotAnimTools.new(self).register()

	# Everything below drives EditorInterface and therefore only works in the
	# editor; call_tool() turns these into a readable error anywhere else.
	for name in ["godot_scene_tree", "godot_get_selection", "godot_editor_state",
			"godot_get_node", "godot_capture_screenshot", "godot_add_node",
			"godot_rename_node", "godot_remove_node", "godot_set_node_property",
			"godot_instantiate_scene", "godot_attach_script", "godot_open_scene",
			"godot_save_scenes", "godot_play_scene", "godot_stop_playing",
			"godot_rescan_filesystem"]:
		_editor_only[name] = true


# ---------------------------------------------------------------------------
# Context / read-only tools
# ---------------------------------------------------------------------------

func _tool_project_info() -> Dictionary:
	var lines := PackedStringArray()
	lines.append("Godot: %s" % Engine.get_version_info().get("string", "?"))
	lines.append("Project name: %s" % ProjectSettings.get_setting("application/config/name", "(unnamed)"))
	lines.append("Main scene: %s" % ProjectSettings.get_setting("application/run/main_scene", "(none)"))
	lines.append("Rendering method: %s" % ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"))
	lines.append("Project root: res://  (absolute: %s)" % ProjectSettings.globalize_path("res://"))
	var autoloads := PackedStringArray()
	for p in ProjectSettings.get_property_list():
		var name := String(p["name"])
		if name.begins_with("autoload/"):
			autoloads.append("%s=%s" % [name.trim_prefix("autoload/"), str(ProjectSettings.get_setting(name))])
	lines.append("Autoloads (%d): %s" % [autoloads.size(), ", ".join(autoloads) if autoloads.size() > 0 else "none"])
	var actions := PackedStringArray()
	for p in InputMap.get_actions():
		actions.append(String(p))
	lines.append("Input actions (%d): %s" % [actions.size(), ", ".join(actions).substr(0, 400)])
	var stats := _count_assets()
	lines.append("Files: %d scenes, %d scripts, %d resources" % [stats["scenes"], stats["scripts"], stats["resources"]])
	lines.append("Top level entries: " + ", ".join(_top_level_entries()))
	if AIStudioEditorEnv.available():
		var edited := EditorInterface.get_edited_scene_root()
		if edited != null:
			lines.append("Edited scene: %s (root %s)" % [EditorInterface.get_current_path(), edited.name])
	return _ok("\n".join(lines))


func _tool_scene_tree(args: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _err("No scene is open in the editor.")
	var depth := clampi(int(args.get("max_depth", 8)), 1, 32)
	var lines := PackedStringArray()
	_walk(root, root, 0, depth, lines)
	return _ok("Scene: %s\n%s" % [EditorInterface.get_current_path(), "\n".join(lines)])


func _tool_selection() -> Dictionary:
	var selection := EditorInterface.get_selection()
	var nodes: Array = selection.get_selected_nodes()
	if nodes.is_empty():
		return _ok("Nothing is selected in the editor.")
	var out := PackedStringArray()
	for n in nodes:
		if n is Node:
			out.append("%s (%s) at %s" % [n.name, n.get_class(), _path_of(n)])
			var script: Script = n.get_script()
			if script != null:
				out.append("    script: %s" % script.resource_path)
			for prop in _interesting_properties(n):
				out.append("    %s = %s" % [prop, var_to_str(n.get(prop))])
	return _ok("Selected nodes (%d):\n%s" % [nodes.size(), "\n".join(out)])


func _tool_editor_state() -> Dictionary:
	var lines := PackedStringArray()
	lines.append("Current scene path: %s" % EditorInterface.get_current_path())
	var open_scenes := PackedStringArray()
	for s in EditorInterface.get_open_scenes():
		open_scenes.append(String(s))
	lines.append("Open scenes: %s" % (", ".join(open_scenes) if not open_scenes.is_empty() else "none"))
	var unsaved := PackedStringArray()
	for s in EditorInterface.get_unsaved_scenes():
		unsaved.append(String(s))
	lines.append("Unsaved scenes: %s" % (", ".join(unsaved) if not unsaved.is_empty() else "none"))
	var selected_paths := PackedStringArray()
	for p in EditorInterface.get_selected_paths():
		selected_paths.append(String(p))
	lines.append("FileSystem selection: %s" % (", ".join(selected_paths) if not selected_paths.is_empty() else "none"))
	lines.append("Current directory in FileSystem dock: %s" % EditorInterface.get_current_directory())
	lines.append("Game running: %s" % ("yes" if EditorInterface.is_playing_scene() else "no"))
	lines.append("Edited scene root: %s" % str(EditorInterface.get_edited_scene_root()))
	var script_editor := EditorInterface.get_script_editor()
	if script_editor != null:
		var current: Script = script_editor.get_current_script()
		if current != null:
			lines.append("Script editor is showing: %s" % current.resource_path)
			if script_editor.has_method("get_current_editor"):
				var te = script_editor.call("get_current_editor")
				if te != null and te.has_method("get_caret_line"):
					lines.append("Caret line: %d" % int(te.call("get_caret_line")))
	return _ok("\n".join(lines))


func _tool_get_node(args: Dictionary) -> Dictionary:
	var node := _resolve_node(String(args.get("node_path", "")))
	if node == null:
		return _err("Node not found: " + String(args.get("node_path", "")))
	var lines := PackedStringArray()
	lines.append("Node: %s" % node.name)
	lines.append("Class: %s" % node.get_class())
	lines.append("Path: %s" % _path_of(node))
	lines.append("Scene file (if instanced): %s" % (node.scene_file_path if node.scene_file_path != "" else "(part of this scene)"))
	var script: Script = node.get_script()
	lines.append("Script: %s" % (script.resource_path if script != null else "(none)"))
	lines.append("Groups: " + ", ".join(PackedStringArray(node.get_groups().map(func(g): return String(g)))))
	lines.append("Children: " + ", ".join(PackedStringArray(node.get_children().map(func(c): return "%s (%s)" % [c.name, c.get_class()]))))
	if bool(args.get("include_properties", true)):
		var props := PackedStringArray()
		var prop_list := node.get_property_list()
		for p in prop_list:
			var usage := int(p.get("usage", 0))
			if usage & PROPERTY_USAGE_EDITOR == 0 or usage & PROPERTY_USAGE_STORAGE == 0:
				continue
			var name := String(p["name"])
			if name.begins_with("metadata/") or name.begins_with("_") or name == "script":
				continue
			props.append("    %s = %s" % [name, var_to_str(node.get(name))])
		lines.append("Properties (%d):\n%s" % [props.size(), "\n".join(props)])
	var signals := PackedStringArray()
	for s in node.get_signal_list():
		var sname := String(s["name"])
		var conns := node.get_signal_connection_list(sname)
		if not conns.is_empty():
			var targets := PackedStringArray()
			for c in conns:
				targets.append(str(c.get("callable", "")))
			signals.append("    %s -> %s" % [sname, ", ".join(targets)])
	if not signals.is_empty():
		lines.append("Connected signals:\n%s" % "\n".join(signals))
	return _ok("\n".join(lines))


func _tool_read_file(args: Dictionary) -> Dictionary:
	var path := String(args.get("path", ""))
	var check := _validate_project_path(path, false)
	if not check["ok"]:
		return check
	if not FileAccess.file_exists(path):
		return _err("File does not exist: " + path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _err("Could not open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
	var text := f.get_as_text()
	f = null
	var lines := text.split("\n")
	var start := maxi(int(args.get("start_line", 1)) - 1, 0)
	var count := int(args.get("line_count", 0))
	var end := lines.size() if count <= 0 else mini(start + count, lines.size())
	var slice := lines.slice(start, end)
	var body := "\n".join(slice)
	if body.length() > MAX_READ_BYTES:
		body = body.substr(0, MAX_READ_BYTES) + "\n... [truncated at %d bytes]" % MAX_READ_BYTES
	return _ok("%s (lines %d-%d of %d):\n%s" % [path, start + 1, end, lines.size(), body])


func _tool_list_dir(args: Dictionary) -> Dictionary:
	var path := String(args.get("path", "res://"))
	var check := _validate_project_path(path, false)
	if not check["ok"]:
		return check
	var dir := DirAccess.open(path)
	if dir == null:
		return _err("Cannot open directory: " + path)
	var out := PackedStringArray()
	var files := 0
	var folders := 0
	for d in dir.get_directories():
		folders += 1
		out.append("  [dir] " + d)
	for f in dir.get_files():
		files += 1
		out.append("  " + f)
	if bool(args.get("recursive", false)):
		for d in dir.get_directories():
			if d.begins_with(".") or d == "addons":
				continue
			var sub := String(path).path_join(d)
			var nested := DirAccess.open(sub)
			if nested == null:
				continue
			for f in nested.get_files():
				out.append("  " + sub.path_join(f))
	return _ok("%s: %d folder(s), %d file(s)\n%s" % [path, folders, files, "\n".join(out)])


func _tool_find_files(args: Dictionary) -> Dictionary:
	var pattern := String(args.get("pattern", "*"))
	var contains := String(args.get("contains", ""))
	var max_results := clampi(int(args.get("max_results", 60)), 1, 400)
	var matches := PackedStringArray()
	_find_recursive("res://", pattern, contains, max_results, matches)
	return _ok("Found %d match(es) for '%s'%s:\n%s" % [
		matches.size(), pattern, " containing '%s'" % contains if not contains.is_empty() else "", "\n".join(matches)])


func _tool_project_settings(args: Dictionary) -> Dictionary:
	var pattern := String(args.get("pattern", "application/*"))
	var max_results := clampi(int(args.get("max_results", 60)), 1, 500)
	var out := PackedStringArray()
	var count := 0
	for p in ProjectSettings.get_property_list():
		var name := String(p["name"])
		if not name.match(pattern):
			continue
		var value: Variant = ProjectSettings.get_setting(name)
		out.append("%s = %s" % [name, var_to_str(value)])
		count += 1
		if count >= max_results:
			out.append("... [truncated]")
			break
	return _ok("ProjectSettings matching '%s' (%d):\n%s" % [pattern, count, "\n".join(out)])


func _tool_class_reference(args: Dictionary) -> Dictionary:
	var cname := String(args.get("class_name", "")).strip_edges()
	if cname.is_empty():
		return _err("class_name is required")
	if not ClassDB.class_exists(cname):
		var suggestions := PackedStringArray()
		for c in ClassDB.get_class_list():
			if String(c).to_lower().contains(cname.to_lower()):
				suggestions.append(String(c))
			if suggestions.size() >= 10:
				break
		return _err("Unknown class '%s'. Similar: %s" % [cname, ", ".join(suggestions) if not suggestions.is_empty() else "(none)"])

	var only := String(args.get("member", "")).strip_edges()
	var inherited := bool(args.get("show_inherited", false))
	var lines := PackedStringArray()
	lines.append("class %s extends %s" % [cname, ClassDB.get_parent_class(cname) if ClassDB.get_parent_class(cname) != "" else "(Object)"])
	lines.append("Instantiable: %s  |  Exposed to scripts: %s" % [str(ClassDB.can_instantiate(cname)), str(ClassDB.is_class_enabled(cname))])
	var chain := PackedStringArray()
	var cur := ClassDB.get_parent_class(cname)
	while cur != "":
		chain.append(cur)
		cur = ClassDB.get_parent_class(cur)
	lines.append("Inheritance chain: %s" % ", ".join(chain))

	lines.append("\nMethods:")
	for m in ClassDB.class_get_method_list(cname, not inherited):
		var mname := String(m["name"])
		if mname.begins_with("_"):
			continue
		if not only.is_empty() and mname != only:
			continue
		lines.append("  " + _signature(m))
	lines.append("\nProperties:")
	for p in ClassDB.class_get_property_list(cname, not inherited):
		var pname := String(p["name"])
		if pname.begins_with("_") or int(p.get("usage", 0)) & PROPERTY_USAGE_EDITOR == 0:
			continue
		if not only.is_empty() and pname != only:
			continue
		lines.append("  %s: %s" % [pname, _type_name(int(p["type"]), String(p.get("class_name", "")))])
	lines.append("\nSignals:")
	for s in ClassDB.class_get_signal_list(cname, not inherited):
		var sname := String(s["name"])
		if not only.is_empty() and sname != only:
			continue
		var sig_args := PackedStringArray()
		for a in s.get("args", []):
			sig_args.append("%s: %s" % [String(a["name"]), _type_name(int(a["type"]), String(a.get("class_name", "")))])
		lines.append("  signal %s(%s)" % [sname, ", ".join(sig_args)])
	lines.append("\nConstants:")
	var consts := PackedStringArray()
	for c in ClassDB.class_get_integer_constant_list(cname, not inherited):
		var cname2 := String(c)
		if not only.is_empty() and cname2 != only:
			continue
		consts.append("  %s = %d" % [cname2, ClassDB.class_get_integer_constant(cname, cname2)])
	lines.append("\n".join(consts))
	return _ok("\n".join(lines))


func _tool_capture(args: Dictionary) -> Dictionary:
	var view := String(args.get("view", "3d")).to_lower()
	var viewport: Viewport = EditorInterface.get_editor_viewport_3d() if view == "3d" else EditorInterface.get_editor_viewport_2d()
	if viewport == null:
		return _err("Editor viewport is not available.")
	var tex := viewport.get_texture()
	if tex == null:
		return _err("Editor viewport has no texture yet (open a 2D/3D scene first).")
	var image := tex.get_image()
	if image == null:
		return _err("Could not read viewport image.")
	AIStudioConfig.ensure_dir(_screenshot_dir)
	var path := "%s/viewport_%s_%d.png" % [_screenshot_dir, view, Time.get_unix_time_from_system()]
	var err := image.save_png(path)
	if err != OK:
		return _err("Could not save screenshot (%s)" % error_string(err))
	return {"ok": true, "text": "Saved %s screenshot to %s (%dx%d)." % [view, path, image.get_width(), image.get_height()],
		"error": "", "image_path": path}


# ---------------------------------------------------------------------------
# Mutating tools
# ---------------------------------------------------------------------------

func _tool_write_file(args: Dictionary) -> Dictionary:
	var path := String(args.get("path", ""))
	var check := _validate_project_path(path, true)
	if not check["ok"]:
		return check
	if String(path).get_extension().to_lower() not in WRITE_EXTENSIONS:
		return _err("Refusing to write '%s'. Allowed text formats: %s" % [path, ", ".join(WRITE_EXTENSIONS)])
	var content := String(args.get("content", ""))
	if content.to_utf8_buffer().size() > MAX_WRITE_BYTES:
		return _err("Refusing to write more than %d bytes." % MAX_WRITE_BYTES)
	var existed := FileAccess.file_exists(path)
	if existed:
		var original := FileAccess.get_file_as_string(path)
		var bak := path + ".bak"
		var bf := FileAccess.open(bak, FileAccess.WRITE)
		if bf != null:
			bf.store_string(original)
			bf = null
	var dir := String(path).get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return _err("Could not open %s for writing (%s)" % [path, error_string(FileAccess.get_open_error())])
	f.store_string(content)
	f = null
	if AIStudioEditorEnv.available():
		EditorInterface.get_resource_filesystem().update_file(path)
	var note := " (previous content saved as %s.bak)" % path if existed else ""
	return _ok("Wrote %d bytes to %s%s" % [content.to_utf8_buffer().size(), path, note])


func _tool_add_node(args: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _err("No scene is open in the editor.")
	var parent := _resolve_node(String(args.get("parent_path", "")))
	if parent == null:
		return _err("Parent node not found: " + String(args.get("parent_path", "")))
	var type := String(args.get("type", "")).strip_edges()
	if not ClassDB.class_exists(type) or not ClassDB.can_instantiate(type):
		return _err("'%s' is not an instantiable engine class." % type)
	var node = ClassDB.instantiate(type)
	if node == null:
		return _err("Could not instantiate '%s'." % type)
	if node is not Node:
		return _err("'%s' is not a Node." % type)
	if args.has("name") and not String(args["name"]).is_empty():
		node.name = _unique_name(String(args["name"]), parent)
	var props: Dictionary = args.get("properties", {}) if typeof(args.get("properties", {})) == TYPE_DICTIONARY else {}
	var old_values := {}
	for prop in props.keys():
		if node.get(String(prop)) != null or String(prop) in node:
			old_values[prop] = node.get(String(prop))
			node.set(String(prop), _parse_value(props[prop]))

	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("AI Studio: add " + type)
	ur.add_do_method(parent, "add_child", node)
	ur.add_do_method(node, "set_owner", root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()
	EditorInterface.edit_node(node)
	return _ok("Added %s '%s' under %s. Scene tree now: %s" % [type, node.name, _path_of(parent), _tree_summary(root)])


func _tool_rename_node(args: Dictionary) -> Dictionary:
	var node := _resolve_node(String(args.get("node_path", "")))
	if node == null:
		return _err("Node not found: " + String(args.get("node_path", "")))
	var root := EditorInterface.get_edited_scene_root()
	if node == root:
		return _err("Renaming the scene root from a tool is not supported; rename the scene file instead.")
	var new_name := String(args.get("new_name", "")).strip_edges()
	if new_name.is_empty():
		return _err("new_name is required")
	var old_name := String(node.name)
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("AI Studio: rename node")
	ur.add_do_property(node, "name", new_name)
	ur.add_undo_property(node, "name", old_name)
	ur.commit_action()
	return _ok("Renamed %s to %s" % [old_name, new_name])


func _tool_remove_node(args: Dictionary) -> Dictionary:
	var node := _resolve_node(String(args.get("node_path", "")))
	if node == null:
		return _err("Node not found: " + String(args.get("node_path", "")))
	var root := EditorInterface.get_edited_scene_root()
	if node == root:
		return _err("Refusing to delete the scene root.")
	var parent := node.get_parent()
	if parent == null:
		return _err("Node has no parent.")
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("AI Studio: delete node")
	ur.add_do_method(parent, "remove_child", node)
	ur.add_undo_method(parent, "add_child", node)
	ur.add_undo_method(node, "set_owner", root)
	ur.commit_action()
	return _ok("Deleted %s (%s)" % [node.name, node.get_class()])


func _tool_set_property(args: Dictionary) -> Dictionary:
	var node := _resolve_node(String(args.get("node_path", "")))
	if node == null:
		return _err("Node not found: " + String(args.get("node_path", "")))
	var prop := String(args.get("property", ""))
	if prop.is_empty():
		return _err("property is required")
	if prop == "script":
		return _err("Use godot_attach_script to change a node's script.")
	var old_value = node.get(prop)
	if old_value == null and not (prop in node):
		var list := PackedStringArray()
		for p in node.get_property_list():
			if int(p.get("usage", 0)) & PROPERTY_USAGE_EDITOR != 0:
				list.append(String(p["name"]))
		return _err("Property '%s' does not exist on %s. Available: %s" % [prop, node.get_class(), ", ".join(list).substr(0, 500)])
	var new_value = _parse_value(args.get("value", ""))
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("AI Studio: set " + prop)
	ur.add_do_property(node, prop, new_value)
	ur.add_undo_property(node, prop, old_value)
	ur.commit_action()
	return _ok("Set %s.%s = %s (was %s)" % [_path_of(node), prop, var_to_str(node.get(prop)), var_to_str(old_value)])


func _tool_instantiate(args: Dictionary) -> Dictionary:
	var scene_path := String(args.get("scene_path", ""))
	if not ResourceLoader.exists(scene_path):
		return _err("Scene not found: " + scene_path)
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return _err("Could not load scene: " + scene_path)
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _err("No scene is open in the editor.")
	var parent := _resolve_node(String(args.get("parent_path", "")))
	if parent == null:
		return _err("Parent node not found: " + String(args.get("parent_path", "")))
	var instance := packed.instantiate()
	if args.has("name") and not String(args["name"]).is_empty():
		instance.name = _unique_name(String(args["name"]), parent)
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("AI Studio: instance scene")
	ur.add_do_method(parent, "add_child", instance)
	ur.add_do_method(instance, "set_owner", root)
	ur.add_do_reference(instance)
	ur.add_undo_method(parent, "remove_child", instance)
	ur.commit_action()
	EditorInterface.edit_node(instance)
	return _ok("Instanced %s as '%s' under %s." % [scene_path, instance.name, _path_of(parent)])


func _tool_attach_script(args: Dictionary) -> Dictionary:
	var node := _resolve_node(String(args.get("node_path", "")))
	if node == null:
		return _err("Node not found: " + String(args.get("node_path", "")))
	var script_path := String(args.get("script_path", ""))
	var check := _validate_project_path(script_path, true)
	if not check["ok"]:
		return check
	if String(script_path).get_extension().to_lower() != "gd":
		return _err("Scripts must be .gd files.")
	var content := String(args.get("content", ""))
	if not content.is_empty():
		var write := _tool_write_file({"path": script_path, "content": content})
		if not bool(write["ok"]):
			return write
	if not FileAccess.file_exists(script_path):
		return _err("Script does not exist and no content was provided: " + script_path)
	if AIStudioEditorEnv.available():
		EditorInterface.get_resource_filesystem().update_file(script_path)
	var script: Script = ResourceLoader.load(script_path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if script == null:
		var errors := ""
		var body := FileAccess.get_file_as_string(script_path)
		var test := GDScript.new()
		test.source_code = body
		var err := test.reload()
		if err != OK:
			errors = " (script has errors, line %d: %s)" % [test.get_last_error_line(), test.get_last_error()]
		return _err("Could not load script %s%s" % [script_path, errors])
	var ur := EditorInterface.get_editor_undo_redo()
	var old_script = node.get_script()
	ur.create_action("AI Studio: attach script")
	ur.add_do_property(node, "script", script)
	ur.add_undo_property(node, "script", old_script)
	ur.commit_action()
	return _ok("Attached %s to %s." % [script_path, _path_of(node)])


func _tool_open_scene(args: Dictionary) -> Dictionary:
	var scene_path := String(args.get("scene_path", ""))
	if not ResourceLoader.exists(scene_path):
		return _err("Scene not found: " + scene_path)
	EditorInterface.open_scene_from_path(scene_path)
	var script_path := String(args.get("script_path", ""))
	if not script_path.is_empty() and ResourceLoader.exists(script_path):
		var script: Script = load(script_path)
		if script != null:
			var line := maxi(int(args.get("line", 1)), 1)
			EditorInterface.edit_script(script, line - 1)
	return _ok("Opened %s%s" % [scene_path, " and %s" % script_path if not script_path.is_empty() else ""])


func _tool_save_scenes(args: Dictionary) -> Dictionary:
	if bool(args.get("all", false)):
		EditorInterface.save_all_scenes()
		return _ok("Saved all open scenes.")
	var err := EditorInterface.save_scene()
	if err != OK:
		return _err("Could not save the scene (%s)" % error_string(err))
	return _ok("Saved %s" % EditorInterface.get_current_path())


func _tool_play_scene(args: Dictionary) -> Dictionary:
	var path := String(args.get("scene_path", "")).strip_edges()
	if path.is_empty():
		EditorInterface.play_current_scene()
		return _ok("Started the currently edited scene.")
	if not ResourceLoader.exists(path):
		return _err("Scene not found: " + path)
	EditorInterface.play_custom_scene(path)
	return _ok("Started " + path)


func _tool_stop_playing() -> Dictionary:
	if not EditorInterface.is_playing_scene():
		return _ok("Nothing is playing.")
	EditorInterface.stop_playing_scene()
	return _ok("Stopped the running game.")


func _tool_rescan() -> Dictionary:
	EditorInterface.get_resource_filesystem().scan()
	return _ok("Filesystem rescan requested.")


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _walk(node: Node, root: Node, depth: int, max_depth: int, out: PackedStringArray) -> void:
	if depth > max_depth:
		return
	var indent := "  ".repeat(depth)
	var line := "%s%s (%s)%s" % [indent, node.name, node.get_class(), " [selected]" if _is_selected(node) else ""]
	var script: Script = node.get_script()
	if script != null:
		line += "  <script: %s>" % script.resource_path
	if node.scene_file_path != "" and node != root:
		line += "  <instance of %s>" % node.scene_file_path
	out.append(line)
	for child in node.get_children():
		_walk(child, root, depth + 1, max_depth, out)


func _tree_summary(root: Node) -> String:
	var parts := PackedStringArray()
	for c in root.get_children():
		parts.append("%s (%s)" % [c.name, c.get_class()])
	return ", ".join(parts) if not parts.is_empty() else "(empty)"


func _is_selected(node: Node) -> bool:
	return EditorInterface.get_selection().get_selected_nodes().has(node)


func _resolve_node(path: String) -> Node:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return null
	var p := path.strip_edges()
	if p.is_empty() or p == "." or p == "/" or p == String(root.name):
		return root
	if p.begins_with(String(root.name) + "/"):
		p = p.substr(String(root.name).length() + 1)
	if p.begins_with("/"):
		p = p.substr(1)
	return root.get_node_or_null(NodePath(p))


func _path_of(node: Node) -> String:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return String(node.name)
	return String(root.get_path_to(node))


static func _unique_name(base: String, parent: Node) -> String:
	var name := base
	var index := 2
	while parent.has_node(NodePath(name)):
		name = "%s%d" % [base, index]
		index += 1
	return name


static func _interesting_properties(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for p in ["position", "global_position", "rotation", "scale", "size", "text", "visible", "modulate", "current", "stream", "autoplay"]:
		if p in node:
			out.append(p)
	return out


static func _parse_value(value: Variant) -> Variant:
	if typeof(value) != TYPE_STRING:
		return value
	var s := String(value).strip_edges()
	if s.is_empty():
		return ""
	var parsed = JSON.parse_string(s)
	if parsed != null and (s.begins_with("{") or s.begins_with("[") or s.begins_with("\"") or s == "true" or s == "false" or s == "null" or s.is_valid_float()):
		return parsed
	var v = str_to_var(s)
	return v if v != null else s


static func _type_name(type: int, class_name_str: String) -> String:
	if type == TYPE_OBJECT and not class_name_str.is_empty():
		return class_name_str
	return type_string(type)


static func _signature(m: Dictionary) -> String:
	var args := PackedStringArray()
	for a in m.get("args", []):
		var text := "%s: %s" % [String(a["name"]), _type_name(int(a["type"]), String(a.get("class_name", "")))]
		if a.has("default_value"):
			text += " = " + str(a["default_value"]).replace("\n", " ")
		args.append(text)
	var ret := "void" if int(m.get("return", {}).get("type", TYPE_NIL)) == TYPE_NIL else _type_name(int(m["return"]["type"]), String(m["return"].get("class_name", "")))
	return "%s %s(%s)" % [ret, String(m["name"]), ", ".join(args)]


## Confines paths to the project and blocks the plugin's own folders.
func _validate_project_path(path: String, for_write: bool) -> Dictionary:
	var p := path.strip_edges().replace("\\", "/")
	if p.is_empty():
		return {"ok": false, "text": "", "error": "Path is required."}
	if p.contains(".."):
		return {"ok": false, "text": "", "error": "Path may not contain '..'."}
	if not p.begins_with("res://"):
		return {"ok": false, "text": "", "error": "Only res:// paths are allowed (got '%s')." % p}
	if p.begins_with("res://.godot") or p.contains("/.godot/") or p.contains("/.git/"):
		return {"ok": false, "text": "", "error": "Refusing to touch engine/git internals."}
	if for_write and p.begins_with("res://addons/ai_studio"):
		return {"ok": false, "text": "", "error": "Refusing to modify the AI Studio addon itself."}
	return {"ok": true, "text": "", "error": ""}


func _count_assets() -> Dictionary:
	var stats := {"scenes": 0, "scripts": 0, "resources": 0}
	_count_recursive("res://", stats)
	return stats


func _count_recursive(path: String, stats: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		match String(f).get_extension().to_lower():
			"tscn", "scn":
				stats["scenes"] += 1
			"gd", "cs":
				stats["scripts"] += 1
			"tres", "res":
				stats["resources"] += 1
	for d in dir.get_directories():
		if d.begins_with("."):
			continue
		_count_recursive(String(path).path_join(d), stats)


func _top_level_entries() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open("res://")
	if dir == null:
		return out
	for d in dir.get_directories():
		if not d.begins_with("."):
			out.append(d + "/")
	for f in dir.get_files():
		out.append(String(f))
	return out


func _find_recursive(path: String, pattern: String, contains: String, max_results: int, matches: PackedStringArray) -> void:
	if matches.size() >= max_results:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if matches.size() >= max_results:
			return
		var full := String(path).path_join(String(f))
		if not full.match(pattern) and not String(f).match(pattern):
			continue
		if not contains.is_empty():
			var ext := String(f).get_extension().to_lower()
			if ext not in TEXT_EXTENSIONS:
				continue
			var text := FileAccess.get_file_as_string(full)
			if not text.contains(contains):
				continue
			var line := _line_of(text, contains)
			matches.append("%s:%d: %s" % [full, line, _context_line(text, line)])
		else:
			matches.append(full)
	for d in dir.get_directories():
		if String(d).begins_with("."):
			continue
		_find_recursive(String(path).path_join(String(d)), pattern, contains, max_results, matches)


static func _line_of(text: String, needle: String) -> int:
	var idx := text.find(needle)
	if idx < 0:
		return 1
	return text.substr(0, idx).count("\n") + 1


static func _context_line(text: String, line: int) -> String:
	var lines := text.split("\n")
	if line - 1 >= 0 and line - 1 < lines.size():
		return String(lines[line - 1]).strip_edges().substr(0, 200)
	return ""
