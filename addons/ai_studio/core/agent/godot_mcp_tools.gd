@tool
class_name AIStudioGodotMcpTools
extends RefCounted

## Project / scene-file / resource tools ported from godot-mcp
## (https://github.com/tugcantopaloglu/godot-mcp, MIT, (c) Tugcan Topaloglu and
## Solomon Elias).
##
## Upstream runs these as a Node.js MCP server that launches a headless Godot
## per call and edits project.godot with regular expressions. Here they run
## inside the editor process instead: scenes are edited through PackedScene /
## SceneState, project settings through ProjectSettings (so the editor sees the
## change immediately), and scripts are validated with the engine's own
## compiler. Every path goes through the host's project-path guard.
##
## Scene *files* can be edited without opening them. If the scene is open in
## the editor it is reloaded after the edit; if it is open with unsaved changes
## the edit is refused instead of silently discarding them.

var host = null   # AIStudioGodotTools (untyped to avoid a cyclic class reference)

const MAX_VALIDATE := 60
const MAX_LIST := 2000
const EXPORT_TIMEOUT_SEC := 900.0
const LAYER_TYPES := {
	"render_2d": "2d_render", "physics_2d": "2d_physics", "navigation_2d": "2d_navigation",
	"render_3d": "3d_render", "physics_3d": "3d_physics", "navigation_3d": "3d_navigation",
	"avoidance": "avoidance",
	# upstream spellings
	"render": "3d_render", "navigation": "3d_navigation",
}
const CSHARP_OVERRIDES := {
	"_Ready": "public override void _Ready()",
	"_Process": "public override void _Process(double delta)",
	"_PhysicsProcess": "public override void _PhysicsProcess(double delta)",
	"_Input": "public override void _Input(InputEvent @event)",
	"_UnhandledInput": "public override void _UnhandledInput(InputEvent @event)",
	"_EnterTree": "public override void _EnterTree()",
	"_ExitTree": "public override void _ExitTree()",
}
const GDSCRIPT_STUBS := {
	"_ready": "func _ready() -> void:",
	"_process": "func _process(delta: float) -> void:",
	"_physics_process": "func _physics_process(delta: float) -> void:",
	"_input": "func _input(event: InputEvent) -> void:",
	"_unhandled_input": "func _unhandled_input(event: InputEvent) -> void:",
	"_enter_tree": "func _enter_tree() -> void:",
	"_exit_tree": "func _exit_tree() -> void:",
	"_init": "func _init() -> void:",
	"_draw": "func _draw() -> void:",
}


func _init(host_tools) -> void:
	host = host_tools


# ---------------------------------------------------------------------------
# registration
# ---------------------------------------------------------------------------

func register() -> void:
	var props_schema := {"type": "object", "description": "Property values keyed by property name. Values may be JSON (numbers, bools, {x,y}/{x,y,z} vectors, {r,g,b,a} or \"#rrggbb\" colors) or Godot literals as strings, e.g. \"Vector2(10, 20)\" or \"res://icon.svg\" for resources.", "additionalProperties": true}

	# ---------------- scene files (read) ----------------
	host._add("godot_read_scene",
		"Read a .tscn/.scn file without opening it: every node with type, parent path, instanced sub-scene, groups, the properties stored in the file, and all signal connections.",
		host._obj({
			"scene_path": host._str("res:// path of the scene."),
			"include_properties": host._bool("Include stored property values.", true),
		}, ["scene_path"]),
		func(a): return _tool_read_scene(a), true, "scene_file")

	# ---------------- scene files (write) ----------------
	host._add("godot_create_scene",
		"Create a new scene file with a single root node (it is not opened). Afterwards add nodes with godot_scene_add_node, or open it with godot_open_scene.",
		host._obj({
			"scene_path": host._str("res:// path of the new .tscn."),
			"root_type": host._str("Root node class or global script class.", "Node2D"),
			"root_name": host._str("Root node name (default: from the file name)."),
			"overwrite": host._bool("Replace an existing file.", false),
		}, ["scene_path"]),
		func(a): return _tool_create_scene(a), false, "scene_file")

	host._add("godot_scene_add_node",
		"Add a node to a scene FILE (works whether or not it is open; an open scene is reloaded). Use godot_add_node instead to edit the scene currently being edited with undo.",
		host._obj({
			"scene_path": host._str("res:// path of the scene."),
			"parent_path": host._str("Parent node path inside the scene ('' or '.' = root, e.g. 'Player/Body')."),
			"type": host._str("Node class or global script class, e.g. 'Sprite2D'."),
			"name": host._str("Node name."),
			"values": props_schema,
			"scene_instance": host._str("Instead of 'type': res:// path of a scene to instance here."),
		}, ["scene_path", "name"]),
		func(a): return _tool_scene_add_node(a), false, "scene_file")

	host._add("godot_scene_modify_node",
		"Set properties on a node in a scene FILE. Also attaches a script ('script' = res:// path, or '' to detach) and sets textures (\"texture\": \"res://img.png\"). Values are converted to the property's real type.",
		host._obj({
			"scene_path": host._str("res:// path of the scene."),
			"node_path": host._str("Node path inside the scene ('' = root)."),
			"values": props_schema,
		}, ["scene_path", "node_path", "values"]),
		func(a): return _tool_scene_modify_node(a), false, "scene_file")

	host._add("godot_scene_remove_node",
		"Remove a node (and its children) from a scene FILE.",
		host._obj({
			"scene_path": host._str("res:// path of the scene."),
			"node_path": host._str("Node path inside the scene."),
		}, ["scene_path", "node_path"]),
		func(a): return _tool_scene_remove_node(a), false, "scene_file")

	host._add("godot_scene_restructure",
		"Rename, duplicate, move (reparent) or reorder a node inside a scene FILE.",
		host._obj({
			"scene_path": host._str("res:// path of the scene."),
			"action": {"type": "string", "enum": ["rename", "duplicate", "move", "reorder"], "description": "What to do."},
			"node_path": host._str("Node path inside the scene."),
			"new_name": host._str("rename: the new name; duplicate: optional name of the copy."),
			"new_parent_path": host._str("move: path of the new parent."),
			"index": host._int("reorder: new child index (-1 = last).", -1),
		}, ["scene_path", "action", "node_path"]),
		func(a): return _tool_scene_restructure(a), false, "scene_file")

	host._add("godot_scene_signals",
		"List, add or remove persistent signal connections stored in a scene FILE.",
		host._obj({
			"scene_path": host._str("res:// path of the scene."),
			"action": {"type": "string", "enum": ["list", "add", "remove"], "description": "What to do."},
			"source_path": host._str("Emitting node path ('' = root)."),
			"signal_name": host._str("Signal name, e.g. 'pressed'."),
			"target_path": host._str("Receiving node path ('' = root)."),
			"method": host._str("Method on the target."),
		}, ["scene_path", "action"]),
		func(a): return _tool_scene_signals(a), false, "scene_file")

	host._add("godot_save_scene_as",
		"Re-save a scene file, optionally to a new path (creates a copy/variant). Re-saving also refreshes UIDs and the file format.",
		host._obj({
			"scene_path": host._str("res:// path of the scene."),
			"new_path": host._str("Optional res:// target path."),
		}, ["scene_path"]),
		func(a): return _tool_save_scene_as(a), false, "scene_file")

	host._add("godot_export_mesh_library",
		"Build a MeshLibrary (for GridMap) from a scene: each child with a MeshInstance3D becomes an item, with its CollisionShape3D if present.",
		host._obj({
			"scene_path": host._str("res:// scene containing the meshes."),
			"output_path": host._str("Where to save the MeshLibrary (.tres/.res)."),
			"items": {"type": "array", "items": {"type": "string"}, "description": "Only these child names (default: all)."},
		}, ["scene_path", "output_path"]),
		func(a): return _tool_export_mesh_library(a), false, "scene_file")

	# ---------------- resources ----------------
	host._add("godot_create_resource",
		"Create and save a Resource of any class (StandardMaterial3D, Theme, Environment, Curve, AudioStreamRandomizer, a custom Resource script class...) with initial properties. Theme items can be set as 'Button/colors/font_color'.",
		host._obj({
			"resource_type": host._str("Class name or global script class."),
			"resource_path": host._str("res:// path to save to (.tres or .res)."),
			"values": props_schema,
			"overwrite": host._bool("Replace an existing file.", false),
		}, ["resource_type", "resource_path"]),
		func(a): return _tool_create_resource(a), false, "resources")

	host._add("godot_read_resource",
		"Read a resource file: class, script and all stored property values (Themes also list their items).",
		host._obj({"resource_path": host._str("res:// path of the resource.")}, ["resource_path"]),
		func(a): return _tool_read_resource(a), true, "resources")

	host._add("godot_modify_resource",
		"Change properties of a resource file and save it. Theme items can be set as 'Button/colors/font_color', 'Label/font_sizes/font_size' etc.",
		host._obj({
			"resource_path": host._str("res:// path of the resource."),
			"values": props_schema,
		}, ["resource_path", "values"]),
		func(a): return _tool_modify_resource(a), false, "resources")

	host._add("godot_get_uid",
		"The UID (uid://...) of a file, from the editor's filesystem cache or its .uid sidecar.",
		host._obj({"path": host._str("res:// path of the file.")}, ["path"]),
		func(a): return _tool_get_uid(a), true, "resources")

	host._add("godot_update_uids",
		"Re-save every scene and resource under a folder so UID references are refreshed, and generate missing .uid files for scripts/shaders.",
		host._obj({"folder": host._str("res:// folder to process.", "res://")}),
		func(a): return _tool_update_uids(a), false, "resources")

	# ---------------- scripts & shaders ----------------
	host._add("godot_validate_scripts",
		"Compile GDScript files with the engine's own compiler and report parse/type errors with line numbers, without running them. Pass paths, or scope='changed' (git changes) / 'all'.",
		host._obj({
			"paths": {"type": "array", "items": {"type": "string"}, "description": "res:// .gd files to check (overrides scope)."},
			"scope": {"type": "string", "enum": ["changed", "all"], "description": "'changed' = files changed according to git (default), 'all' = every .gd in the project (max 60)."},
		}),
		func(a): return _tool_validate_scripts(a), true, "scripts")

	host._add("godot_create_script",
		"Create a GDScript (.gd) or C# (.cs) file from a template (extends, class_name, method stubs) or from full source, then validate it. Refuses to overwrite unless asked.",
		host._obj({
			"path": host._str("res:// path ending in .gd or .cs."),
			"extends": host._str("Base class.", "Node"),
			"class_name": host._str("Optional class_name (C#: must match the file name)."),
			"methods": {"type": "array", "items": {"type": "string"}, "description": "Method stubs, e.g. ['_ready', '_process'] (C#: '_Ready', '_Process')."},
			"namespace": host._str("C# only: optional namespace."),
			"source": host._str("Full source; overrides the template."),
			"overwrite": host._bool("Replace an existing file.", false),
		}, ["path"]),
		func(a): return _tool_create_script(a), false, "scripts")

	host._add("godot_create_shader",
		"Create a .gdshader file (from source, or a template of the given shader type).",
		host._obj({
			"path": host._str("res:// path ending in .gdshader."),
			"shader_type": {"type": "string", "enum": ["spatial", "canvas_item", "particles", "sky", "fog"], "description": "Template type when no source is given."},
			"source": host._str("Full shader source (optional)."),
			"overwrite": host._bool("Replace an existing file.", false),
		}, ["path"]),
		func(a): return _tool_create_shader(a), false, "scripts")

	# ---------------- files ----------------
	host._add("godot_manage_files",
		"Delete, move/rename or copy a file, or create a folder inside the project. Moving a file also moves its .import/.uid sidecars so references keep working. Deleted files go to the system trash when possible.",
		host._obj({
			"action": {"type": "string", "enum": ["delete", "move", "copy", "mkdir"], "description": "What to do."},
			"path": host._str("res:// source file (or the folder for mkdir)."),
			"new_path": host._str("move/copy: res:// destination."),
		}, ["action", "path"]),
		func(a): return _tool_manage_files(a), false, "files")

	# ---------------- project configuration ----------------
	host._add("godot_set_project_setting",
		"Set (or erase) a project setting and save project.godot, e.g. 'display/window/size/viewport_width' = 1280. Values are parsed as Godot literals / JSON.",
		host._obj({
			"name": host._str("Full setting path, e.g. 'application/config/name'."),
			"value": host._str("New value as a Godot literal or JSON. Ignored when erase is true."),
			"erase": host._bool("Remove the setting instead (back to its default).", false),
		}, ["name"]),
		func(a): return _tool_set_project_setting(a), false, "project")

	host._add("godot_set_main_scene",
		"Set application/run/main_scene (the scene F5 runs).",
		host._obj({"scene_path": host._str("res:// path of the scene.")}, ["scene_path"]),
		func(a): return _tool_set_main_scene(a), false, "project")

	host._add("godot_manage_autoloads",
		"List, add or remove autoload singletons.",
		host._obj({
			"action": {"type": "string", "enum": ["list", "add", "remove"], "description": "What to do."},
			"name": host._str("Singleton name (add/remove)."),
			"path": host._str("add: res:// script or scene."),
			"global": host._bool("add: make it a global variable (the usual choice).", true),
		}, ["action"]),
		func(a): return _tool_manage_autoloads(a), false, "project")

	host._add("godot_manage_input_map",
		"List, add or remove input actions and bind keys, mouse buttons or joypad buttons/axes to them.",
		host._obj({
			"action": {"type": "string", "enum": ["list", "add", "remove", "clear_events"], "description": "add creates the action if needed and appends the given bindings."},
			"action_name": host._str("Input action name (add/remove/clear_events)."),
			"keys": {"type": "array", "items": {"type": "string"}, "description": "Keys, e.g. ['W', 'Up', 'Space', 'Ctrl+S']."},
			"mouse_buttons": {"type": "array", "items": {"type": "integer"}, "description": "Mouse buttons (1 left, 2 right, 3 middle, 4/5 wheel)."},
			"joy_buttons": {"type": "array", "items": {"type": "integer"}, "description": "Joypad button indices (0 = A/Cross...)."},
			"joy_axes": {"type": "array", "items": {"type": "string"}, "description": "Joypad axes as 'axis:direction', e.g. '0:-1' for left stick left."},
			"deadzone": {"type": "number", "description": "Deadzone for a new action (default 0.2)."},
		}, ["action"]),
		func(a): return _tool_manage_input_map(a), false, "project")

	host._add("godot_manage_layers",
		"List or name render/physics/navigation/avoidance layers.",
		host._obj({
			"action": {"type": "string", "enum": ["list", "set"], "description": "What to do."},
			"layer_type": {"type": "string", "enum": ["render_2d", "physics_2d", "navigation_2d", "render_3d", "physics_3d", "navigation_3d", "avoidance"], "description": "Layer family (set)."},
			"layer": host._int("Layer number 1-32 (set).", 1),
			"name": host._str("Layer name (set); empty clears it."),
		}, ["action"]),
		func(a): return _tool_manage_layers(a), false, "project")

	host._add("godot_manage_plugins",
		"List the editor plugins in addons/ and enable or disable them.",
		host._obj({
			"action": {"type": "string", "enum": ["list", "enable", "disable"], "description": "What to do."},
			"plugin": host._str("Plugin folder name under addons/ (enable/disable)."),
		}, ["action"]),
		func(a): return _tool_manage_plugins(a), false, "project")

	host._add("godot_manage_translations",
		"List, add or remove translation files (.po/.translation/.csv imports) in the project's localization settings.",
		host._obj({
			"action": {"type": "string", "enum": ["list", "add", "remove"], "description": "What to do."},
			"path": host._str("res:// path of the translation (add/remove)."),
		}, ["action"]),
		func(a): return _tool_manage_translations(a), false, "project")

	# ---------------- export / CI ----------------
	host._add("godot_manage_export_presets",
		"List, add or remove export presets in export_presets.cfg.",
		host._obj({
			"action": {"type": "string", "enum": ["list", "add", "remove"], "description": "What to do."},
			"name": host._str("Preset name (add/remove)."),
			"platform": host._str("add: platform, e.g. 'Windows Desktop', 'Linux', 'macOS', 'Web', 'Android'."),
			"export_path": host._str("add: default output path, e.g. 'build/game.exe'."),
			"runnable": host._bool("add: mark it runnable.", false),
		}, ["action"]),
		func(a): return _tool_manage_export_presets(a), false, "export")

	host._add("godot_export_project",
		"Export the project with a preset by running this Godot binary headless (needs the export templates installed). Can take minutes.",
		host._obj({
			"preset": host._str("Export preset name."),
			"output_path": host._str("Output file; relative paths are relative to the project folder."),
			"mode": {"type": "string", "enum": ["release", "debug", "pack"], "description": "release (default), debug, or pack (.pck/.zip only)."},
		}, ["preset", "output_path"]),
		func(a): return await _tool_export_project(a), false, "export")

	host._add("godot_manage_ci",
		"Create or read a GitHub Actions workflow or a Dockerfile that exports the project headless with this Godot version.",
		host._obj({
			"target": {"type": "string", "enum": ["github_actions", "docker"], "description": "Which file."},
			"action": {"type": "string", "enum": ["read", "create"], "description": "What to do."},
			"presets": {"type": "array", "items": {"type": "string"}, "description": "Export preset names to build (default: all presets)."},
			"godot_version": host._str("Godot version, e.g. '4.7.2-stable' (default: this editor's version)."),
			"overwrite": host._bool("Replace an existing file.", false),
		}, ["target", "action"]),
		func(a): return _tool_manage_ci(a), false, "export")

	for name in ["godot_manage_plugins"]:
		host._editor_only[name] = true


# ---------------------------------------------------------------------------
# shared helpers
# ---------------------------------------------------------------------------

func _editor() -> bool:
	return AIStudioEditorEnv.available()


func _res_path(raw: Variant) -> String:
	var p := String(raw if raw != null else "").strip_edges().replace("\\", "/")
	if p.is_empty():
		return p
	if not p.begins_with("res://") and not p.begins_with("uid://"):
		p = "res://" + p.trim_prefix("/")
	if p.begins_with("uid://"):
		var id := ResourceUID.text_to_id(p)
		if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id):
			p = ResourceUID.get_id_path(id)
	return p


func _check(path: String, for_write: bool) -> Dictionary:
	return host._validate_project_path(path, for_write)


func _notify_fs(path: String) -> void:
	if _editor():
		EditorInterface.get_resource_filesystem().update_file(path)


func _rescan() -> void:
	if _editor():
		EditorInterface.get_resource_filesystem().scan()


func _ensure_dir_for(path: String) -> Error:
	var dir := path.get_base_dir()
	if dir.is_empty() or DirAccess.dir_exists_absolute(dir):
		return OK
	return DirAccess.make_dir_recursive_absolute(dir)


func _json(value: Variant) -> String:
	return JSON.stringify(value, "  ", false)


## Instantiates an engine class or a global script class (class_name).
func _instantiate_class(type_name: String) -> Object:
	var t := type_name.strip_edges()
	if t.is_empty():
		return null
	if ClassDB.class_exists(t):
		if not ClassDB.can_instantiate(t):
			return null
		return ClassDB.instantiate(t)
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == t:
			var script = load(String(entry.get("path", "")))
			if script is Script and (script as Script).can_instantiate():
				return (script as Script).new()
			return null
	if t.begins_with("res://") and ResourceLoader.exists(t):
		var s = load(t)
		if s is Script and (s as Script).can_instantiate():
			return (s as Script).new()
	return null


## Converts a JSON-ish value into the type the property really has.
func _convert(target: Object, prop: String, value: Variant) -> Variant:
	var type_id := TYPE_NIL
	var hint_string := ""
	for p in target.get_property_list():
		if String(p["name"]) == prop:
			type_id = int(p.get("type", TYPE_NIL))
			hint_string = String(p.get("hint_string", ""))
			break
	if typeof(value) == TYPE_STRING:
		var s := String(value).strip_edges()
		if type_id == TYPE_OBJECT or (type_id == TYPE_NIL and s.begins_with("res://")):
			if s.is_empty() or s == "null":
				return null
			if s.begins_with("res://") or s.begins_with("uid://"):
				var rp := _res_path(s)
				if ResourceLoader.exists(rp):
					return load(rp)
			return _literal(s)
		if type_id == TYPE_STRING or type_id == TYPE_STRING_NAME or type_id == TYPE_NODE_PATH:
			# Plain text stays text; only an explicitly quoted string is unquoted.
			if s.length() >= 2 and s.begins_with("\"") and s.ends_with("\""):
				var unq = _literal(s)
				if typeof(unq) == TYPE_STRING:
					return type_convert(unq, type_id)
			return type_convert(String(value), type_id)
		if (type_id == TYPE_COLOR or (target is Theme and prop.contains("/colors/"))) and Color.html_is_valid(s):
			return Color.html(s)
		if target is Theme and (prop.contains("/fonts/") or prop.contains("/icons/") or prop.contains("/styles/")) and s.begins_with("res://"):
			var tp := _res_path(s)
			return load(tp) if ResourceLoader.exists(tp) else null
		value = _literal(s)
	if typeof(value) == TYPE_DICTIONARY and target is Theme and prop.contains("/colors/"):
		type_id = TYPE_COLOR
	if typeof(value) == TYPE_DICTIONARY:
		var d: Dictionary = value
		match type_id:
			TYPE_VECTOR2:
				return Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
			TYPE_VECTOR2I:
				return Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))
			TYPE_VECTOR3:
				return Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))
			TYPE_VECTOR3I:
				return Vector3i(int(d.get("x", 0)), int(d.get("y", 0)), int(d.get("z", 0)))
			TYPE_VECTOR4:
				return Vector4(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)), float(d.get("w", 0)))
			TYPE_COLOR:
				return Color(float(d.get("r", 0)), float(d.get("g", 0)), float(d.get("b", 0)), float(d.get("a", 1)))
			TYPE_QUATERNION:
				return Quaternion(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)), float(d.get("w", 1)))
			TYPE_RECT2:
				var rpos: Dictionary = d.get("position", {})
				var rsize: Dictionary = d.get("size", {})
				return Rect2(float(rpos.get("x", 0)), float(rpos.get("y", 0)), float(rsize.get("x", 0)), float(rsize.get("y", 0)))
			TYPE_AABB:
				var apos: Dictionary = d.get("position", {})
				var asize: Dictionary = d.get("size", {})
				return AABB(_v3(apos), _v3(asize))
			TYPE_BASIS:
				return Basis(_v3(d.get("x", {"x": 1})), _v3(d.get("y", {"y": 1})), _v3(d.get("z", {"z": 1})))
			TYPE_TRANSFORM3D:
				var bd: Dictionary = d.get("basis", {})
				var basis := Basis.IDENTITY
				if bd.has("x"):
					basis = Basis(_v3(bd.get("x", {})), _v3(bd.get("y", {})), _v3(bd.get("z", {})))
				return Transform3D(basis, _v3(d.get("origin", {})))
			TYPE_TRANSFORM2D:
				return Transform2D(_v2(d.get("x", {"x": 1})), _v2(d.get("y", {"y": 1})), _v2(d.get("origin", {})))
	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value
		match type_id:
			TYPE_VECTOR2:
				if arr.size() >= 2:
					return Vector2(float(arr[0]), float(arr[1]))
			TYPE_VECTOR3:
				if arr.size() >= 3:
					return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
			TYPE_COLOR:
				if arr.size() >= 3:
					return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]) if arr.size() > 3 else 1.0)
			TYPE_PACKED_VECTOR2_ARRAY:
				var pv2 := PackedVector2Array()
				for item in arr:
					pv2.append(_v2(item) if typeof(item) == TYPE_DICTIONARY else Vector2(float(item[0]), float(item[1])))
				return pv2
			TYPE_PACKED_VECTOR3_ARRAY:
				var pv3 := PackedVector3Array()
				for item in arr:
					pv3.append(_v3(item) if typeof(item) == TYPE_DICTIONARY else Vector3(float(item[0]), float(item[1]), float(item[2])))
				return pv3
	if type_id in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] and typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		return type_convert(value, type_id)
	if type_id != TYPE_NIL and type_id != TYPE_OBJECT and typeof(value) != type_id:
		var converted = type_convert(value, type_id)
		if converted != null:
			return converted
	return value


## Parses JSON or a Godot literal ("Vector2(1, 2)", "Color(...)") without
## printing parse errors; anything else stays a plain string.
static func _literal(value: Variant) -> Variant:
	if typeof(value) != TYPE_STRING:
		return value
	var s := String(value).strip_edges()
	if s.is_empty():
		return ""
	if s.is_valid_int():
		return int(s)
	var first := s.substr(0, 1)
	if first in ["{", "[", "\""] or s in ["true", "false", "null"] or s.is_valid_float():
		var json := JSON.new()
		if json.parse(s) == OK:
			return json.data
	if s.contains("(") and s.ends_with(")") and s.substr(0, 1) == s.substr(0, 1).to_upper():
		var v = str_to_var(s)
		if v != null:
			return v
	if first in ["{", "["]:
		var v2 = str_to_var(s)
		if v2 != null:
			return v2
	return String(value)


static func _v2(d: Variant) -> Vector2:
	if typeof(d) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(d.get("x", 0)), float(d.get("y", 0)))


static func _v3(d: Variant) -> Vector3:
	if typeof(d) != TYPE_DICTIONARY:
		return Vector3.ZERO
	return Vector3(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("z", 0)))


## Sets properties and returns a list of problems (unknown props).
func _apply_properties(target: Object, props: Variant) -> PackedStringArray:
	var problems := PackedStringArray()
	if typeof(props) != TYPE_DICTIONARY:
		return problems
	for key in (props as Dictionary).keys():
		var prop := String(key)
		if prop == "script":
			var sp := _res_path(props[key])
			if sp.is_empty() or sp == "null":
				target.set_script(null)
				continue
			if not ResourceLoader.exists(sp):
				problems.append("script not found: " + sp)
				continue
			var script = load(sp)
			if not (script is Script):
				problems.append("not a script: " + sp)
				continue
			target.set_script(script)
			continue
		var exists := prop in target
		if not exists and target is Theme:
			exists = prop.count("/") == 2
		if not exists and not prop.contains(":") and not prop.contains("/"):
			problems.append("%s has no property '%s'" % [target.get_class(), prop])
			continue
		var converted = _convert(target, prop, props[key])
		target.set(prop, converted)
	return problems


# ---------------------------------------------------------------------------
# scene file access
# ---------------------------------------------------------------------------

## Opens a scene file for editing. Returns {ok, root, packed, path, reopen, error}.
func _open_scene_file(raw_path: Variant, for_write: bool) -> Dictionary:
	var path := _res_path(raw_path)
	var check := _check(path, for_write)
	if not bool(check["ok"]):
		return {"ok": false, "error": check["error"]}
	if not (path.ends_with(".tscn") or path.ends_with(".scn")):
		return {"ok": false, "error": "Not a scene file (.tscn/.scn): " + path}
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Scene not found: " + path}
	var reopen := false
	if for_write and _editor():
		if Array(EditorInterface.get_open_scenes()).has(path):
			if Array(EditorInterface.get_unsaved_scenes()).has(path):
				return {"ok": false, "error": "%s is open in the editor with unsaved changes. Save it first (godot_save_scenes), or edit it with the undo-aware tools (godot_add_node, godot_set_node_property, ...)." % path}
			reopen = true
	var packed = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if not (packed is PackedScene):
		return {"ok": false, "error": "Could not load scene: " + path}
	var root: Node = (packed as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if root == null:
		return {"ok": false, "error": "Could not instantiate scene: " + path}
	return {"ok": true, "root": root, "packed": packed, "path": path, "reopen": reopen, "error": ""}


func _save_scene_file(opened: Dictionary, target_path: String = "") -> Dictionary:
	var root: Node = opened["root"]
	var path: String = target_path if not target_path.is_empty() else String(opened["path"])
	var packed := PackedScene.new()
	var err := packed.pack(root)
	root.free()
	if err != OK:
		return host._err("Could not pack the scene (%s)." % error_string(err))
	_ensure_dir_for(path)
	err = ResourceSaver.save(packed, path)
	if err != OK:
		return host._err("Could not save %s (%s)." % [path, error_string(err)])
	_notify_fs(path)
	if _editor() and target_path.is_empty() and bool(opened.get("reopen", false)):
		EditorInterface.reload_scene_from_path(path)
	return host._ok("")


func _discard(opened: Dictionary) -> void:
	var root = opened.get("root", null)
	if root != null and is_instance_valid(root):
		(root as Node).free()


func _scene_node(root: Node, raw: Variant) -> Node:
	var p := String(raw if raw != null else "").strip_edges()
	if p.is_empty() or p == "." or p == "/" or p == "root" or p == String(root.name):
		return root
	for prefix in ["root/", "/root/", String(root.name) + "/", "/"]:
		if p.begins_with(prefix):
			p = p.substr(prefix.length())
			break
	if p.is_empty():
		return root
	return root.get_node_or_null(NodePath(p))


func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	if not node.scene_file_path.is_empty() and node != owner:
		return  # children of an instanced scene belong to that scene
	for c in node.get_children():
		_set_owner_recursive(c, owner)


func _rel(root: Node, node: Node) -> String:
	return "." if node == root else String(root.get_path_to(node))


# ---------------------------------------------------------------------------
# scene tools
# ---------------------------------------------------------------------------

func _tool_read_scene(args: Dictionary) -> Dictionary:
	var path := _res_path(args.get("scene_path", ""))
	var check := _check(path, false)
	if not bool(check["ok"]):
		return check
	if not ResourceLoader.exists(path):
		return host._err("Scene not found: " + path)
	var packed = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if not (packed is PackedScene):
		return host._err("Not a scene: " + path)
	var state: SceneState = (packed as PackedScene).get_state()
	var with_props := bool(args.get("include_properties", true))
	var nodes: Array = []
	for i in state.get_node_count():
		var entry := {
			"path": String(state.get_node_path(i)),
			"name": String(state.get_node_name(i)),
		}
		var type := String(state.get_node_type(i))
		if not type.is_empty():
			entry["type"] = type
		var inst: PackedScene = state.get_node_instance(i)
		if inst != null:
			entry["instance"] = inst.resource_path
		var groups := state.get_node_groups(i)
		if not groups.is_empty():
			entry["groups"] = Array(groups)
		if with_props:
			var props := {}
			for j in state.get_node_property_count(i):
				var pname := String(state.get_node_property_name(i, j))
				props[pname] = _describe_value(state.get_node_property_value(i, j))
			if not props.is_empty():
				entry["properties"] = props
		nodes.append(entry)
	var connections: Array = []
	for c in state.get_connection_count():
		connections.append({
			"from": String(state.get_connection_source(c)),
			"signal": String(state.get_connection_signal(c)),
			"to": String(state.get_connection_target(c)),
			"method": String(state.get_connection_method(c)),
			"flags": state.get_connection_flags(c),
		})
	var base: SceneState = state.get_base_scene_state()
	var out := {"scene": path, "node_count": nodes.size(), "nodes": nodes, "connections": connections}
	if base != null and not base.get_path().is_empty():
		out["inherits"] = base.get_path()
	return host._ok(_json(out))


func _describe_value(v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return v
		TYPE_OBJECT:
			if v == null:
				return null
			if v is Resource:
				var r: Resource = v
				if not r.resource_path.is_empty() and not r.resource_path.contains("::"):
					return "%s(\"%s\")" % [r.get_class(), r.resource_path]
				return "<%s (embedded)>" % r.get_class()
			return "<%s>" % (v as Object).get_class()
	var text := var_to_str(v)
	return text if text.length() <= 400 else text.substr(0, 400) + "..."


func _tool_create_scene(args: Dictionary) -> Dictionary:
	var path := _res_path(args.get("scene_path", ""))
	var check := _check(path, true)
	if not bool(check["ok"]):
		return check
	if path.get_extension() not in ["tscn", "scn"]:
		return host._err("scene_path must end in .tscn or .scn")
	if FileAccess.file_exists(path) and not bool(args.get("overwrite", false)):
		return host._err("%s already exists (pass overwrite=true to replace it)." % path)
	var type := String(args.get("root_type", "Node2D")).strip_edges()
	if type.is_empty():
		type = "Node2D"
	var obj := _instantiate_class(type)
	if obj == null or not (obj is Node):
		if obj != null and not (obj is RefCounted):
			obj.free()
		return host._err("'%s' is not an instantiable Node class." % type)
	var root: Node = obj
	var root_name := String(args.get("root_name", "")).strip_edges()
	root.name = root_name if not root_name.is_empty() else path.get_file().get_basename().to_pascal_case()
	var res := _save_scene_file({"root": root, "path": path, "reopen": false}, path)
	if not bool(res["ok"]):
		return res
	return host._ok("Created %s with root %s (%s)." % [path, root_name if not root_name.is_empty() else path.get_file().get_basename().to_pascal_case(), type])


func _tool_scene_add_node(args: Dictionary) -> Dictionary:
	var opened := _open_scene_file(args.get("scene_path", ""), true)
	if not bool(opened["ok"]):
		return host._err(opened["error"])
	var root: Node = opened["root"]
	var parent := _scene_node(root, args.get("parent_path", ""))
	if parent == null:
		_discard(opened)
		return host._err("Parent not found in scene: " + String(args.get("parent_path", "")))
	var node: Node = null
	var inst_path := _res_path(args.get("scene_instance", ""))
	if not inst_path.is_empty():
		var chk := _check(inst_path, false)
		if not bool(chk["ok"]) or not ResourceLoader.exists(inst_path):
			_discard(opened)
			return host._err("scene_instance not found: " + inst_path)
		var sub = load(inst_path)
		if not (sub is PackedScene):
			_discard(opened)
			return host._err("Not a scene: " + inst_path)
		if inst_path == String(opened["path"]):
			_discard(opened)
			return host._err("A scene cannot instance itself.")
		node = (sub as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	else:
		var type := String(args.get("type", "")).strip_edges()
		var obj := _instantiate_class(type)
		if obj == null or not (obj is Node):
			if obj != null and not (obj is RefCounted):
				obj.free()
			_discard(opened)
			return host._err("'%s' is not an instantiable Node class (pass 'type' or 'scene_instance')." % type)
		node = obj
	var wanted := String(args.get("name", "")).strip_edges()
	if not wanted.is_empty():
		node.name = host._unique_name(wanted, parent)
	var problems := _apply_properties(node, args.get("properties", {}))
	parent.add_child(node, true)
	_set_owner_recursive(node, root)
	var msg := "Added %s '%s' to %s." % [node.get_class() if inst_path.is_empty() else inst_path, _rel(root, node), opened["path"]]
	var res := _save_scene_file(opened)
	if not bool(res["ok"]):
		return res
	if not problems.is_empty():
		msg += " Warnings: " + "; ".join(problems)
	return host._ok(msg)


func _tool_scene_modify_node(args: Dictionary) -> Dictionary:
	var opened := _open_scene_file(args.get("scene_path", ""), true)
	if not bool(opened["ok"]):
		return host._err(opened["error"])
	var root: Node = opened["root"]
	var node := _scene_node(root, args.get("node_path", ""))
	if node == null:
		_discard(opened)
		return host._err("Node not found in scene: " + String(args.get("node_path", "")))
	var props = args.get("properties", {})
	if typeof(props) != TYPE_DICTIONARY or (props as Dictionary).is_empty():
		_discard(opened)
		return host._err("properties must be a non-empty object.")
	var problems := _apply_properties(node, props)
	var changed := PackedStringArray()
	for key in (props as Dictionary).keys():
		if String(key) == "script":
			changed.append("script=%s" % (node.get_script().resource_path if node.get_script() != null else "none"))
		elif String(key) in node:
			changed.append("%s=%s" % [key, str(_describe_value(node.get(String(key))))])
	var node_label := _rel(root, node)
	var res := _save_scene_file(opened)
	if not bool(res["ok"]):
		return res
	var msg := "Updated %s in %s: %s" % [node_label, opened["path"], ", ".join(changed)]
	if not problems.is_empty():
		msg += ". Warnings: " + "; ".join(problems)
	return host._ok(msg)


func _tool_scene_remove_node(args: Dictionary) -> Dictionary:
	var opened := _open_scene_file(args.get("scene_path", ""), true)
	if not bool(opened["ok"]):
		return host._err(opened["error"])
	var root: Node = opened["root"]
	var node := _scene_node(root, args.get("node_path", ""))
	if node == null:
		_discard(opened)
		return host._err("Node not found in scene: " + String(args.get("node_path", "")))
	if node == root:
		_discard(opened)
		return host._err("Refusing to remove the scene root.")
	var label := _rel(root, node)
	node.get_parent().remove_child(node)
	node.free()
	var res := _save_scene_file(opened)
	if not bool(res["ok"]):
		return res
	return host._ok("Removed %s from %s." % [label, opened["path"]])


func _tool_scene_restructure(args: Dictionary) -> Dictionary:
	var opened := _open_scene_file(args.get("scene_path", ""), true)
	if not bool(opened["ok"]):
		return host._err(opened["error"])
	var root: Node = opened["root"]
	var node := _scene_node(root, args.get("node_path", ""))
	if node == null:
		_discard(opened)
		return host._err("Node not found in scene: " + String(args.get("node_path", "")))
	var action := String(args.get("action", ""))
	var msg := ""
	match action:
		"rename":
			var new_name := String(args.get("new_name", "")).strip_edges()
			if new_name.is_empty() or not new_name.validate_node_name() == new_name:
				_discard(opened)
				return host._err("new_name is missing or contains invalid characters (. : @ / \" %).")
			if node != root and node.get_parent().has_node(NodePath(new_name)):
				_discard(opened)
				return host._err("A sibling named '%s' already exists." % new_name)
			var old := String(node.name)
			node.name = new_name
			msg = "Renamed %s to %s" % [old, new_name]
		"duplicate":
			if node == root:
				_discard(opened)
				return host._err("Cannot duplicate the scene root.")
			var dup := node.duplicate()
			var dup_name := String(args.get("new_name", "")).strip_edges()
			dup.name = host._unique_name(dup_name if not dup_name.is_empty() else String(node.name), node.get_parent())
			node.get_parent().add_child(dup, true)
			node.get_parent().move_child(dup, node.get_index() + 1)
			_set_owner_recursive(dup, root)
			msg = "Duplicated %s as %s" % [_rel(root, node), _rel(root, dup)]
		"move":
			if node == root:
				_discard(opened)
				return host._err("Cannot move the scene root.")
			var new_parent := _scene_node(root, args.get("new_parent_path", ""))
			if new_parent == null:
				_discard(opened)
				return host._err("New parent not found: " + String(args.get("new_parent_path", "")))
			if new_parent == node or node.is_ancestor_of(new_parent):
				_discard(opened)
				return host._err("Cannot move a node into itself or one of its children.")
			var before := _rel(root, node)
			node.owner = null
			for d in node.find_children("*", "", true, false):
				if d.owner == root:
					d.owner = null
			node.reparent(new_parent, false)
			_set_owner_recursive(node, root)
			msg = "Moved %s to %s" % [before, _rel(root, node)]
		"reorder":
			if node == root:
				_discard(opened)
				return host._err("The root has no siblings.")
			var idx := int(args.get("index", -1))
			node.get_parent().move_child(node, idx)
			msg = "Moved %s to child index %d" % [_rel(root, node), node.get_index()]
		_:
			_discard(opened)
			return host._err("Unknown action '%s' (rename, duplicate, move, reorder)." % action)
	var res := _save_scene_file(opened)
	if not bool(res["ok"]):
		return res
	return host._ok("%s in %s." % [msg, opened["path"]])


func _tool_scene_signals(args: Dictionary) -> Dictionary:
	var action := String(args.get("action", "list"))
	if action == "list":
		var read := _tool_read_scene({"scene_path": args.get("scene_path", ""), "include_properties": false})
		if not bool(read["ok"]):
			return read
		var data = JSON.parse_string(String(read["text"]))
		var conns: Array = data.get("connections", [])
		for c in conns:
			c["flags"] = int(c.get("flags", 0))
		return host._ok(_json({"scene": data.get("scene", ""), "connections": conns}))
	var opened := _open_scene_file(args.get("scene_path", ""), true)
	if not bool(opened["ok"]):
		return host._err(opened["error"])
	var root: Node = opened["root"]
	var source := _scene_node(root, args.get("source_path", ""))
	var target := _scene_node(root, args.get("target_path", ""))
	var signal_name := String(args.get("signal_name", "")).strip_edges()
	var method := String(args.get("method", "")).strip_edges()
	if source == null or target == null:
		_discard(opened)
		return host._err("source_path or target_path not found in the scene.")
	if signal_name.is_empty():
		_discard(opened)
		return host._err("signal_name is required.")
	var msg := ""
	if action == "add":
		if method.is_empty():
			_discard(opened)
			return host._err("method is required for add.")
		if not source.has_signal(signal_name):
			var no_sig := "%s (%s) has no signal '%s'." % [_rel(root, source), source.get_class(), signal_name]
			_discard(opened)
			return host._err(no_sig)
		var callable := Callable(target, method)
		if source.is_connected(signal_name, callable):
			_discard(opened)
			return host._ok("Already connected.")
		var err := source.connect(signal_name, callable, Object.CONNECT_PERSIST)
		if err != OK:
			_discard(opened)
			return host._err("connect failed (%s)." % error_string(err))
		msg = "Connected %s.%s -> %s.%s()" % [_rel(root, source), signal_name, _rel(root, target), method]
		if not target.has_method(method):
			msg += " (note: the target has no method '%s' yet - add it to its script)" % method
	elif action == "remove":
		var removed := 0
		for c in source.get_signal_connection_list(signal_name):
			var cb: Callable = c["callable"]
			if cb.get_object() == target and (method.is_empty() or String(cb.get_method()) == method):
				source.disconnect(signal_name, cb)
				removed += 1
		if removed == 0:
			_discard(opened)
			return host._err("No matching connection found.")
		msg = "Removed %d connection(s) of %s.%s" % [removed, _rel(root, source), signal_name]
	else:
		_discard(opened)
		return host._err("Unknown action '%s' (list, add, remove)." % action)
	var res := _save_scene_file(opened)
	if not bool(res["ok"]):
		return res
	return host._ok("%s in %s." % [msg, opened["path"]])


func _tool_save_scene_as(args: Dictionary) -> Dictionary:
	var new_path := _res_path(args.get("new_path", ""))
	if not new_path.is_empty():
		var chk := _check(new_path, true)
		if not bool(chk["ok"]):
			return chk
		if new_path.get_extension() not in ["tscn", "scn"]:
			return host._err("new_path must end in .tscn or .scn")
	var opened := _open_scene_file(args.get("scene_path", ""), new_path.is_empty())
	if not bool(opened["ok"]):
		return host._err(opened["error"])
	var res := _save_scene_file(opened, new_path)
	if not bool(res["ok"]):
		return res
	return host._ok("Saved %s%s." % [opened["path"], (" as " + new_path) if not new_path.is_empty() else ""])


func _tool_export_mesh_library(args: Dictionary) -> Dictionary:
	var out_path := _res_path(args.get("output_path", ""))
	var chk := _check(out_path, true)
	if not bool(chk["ok"]):
		return chk
	if out_path.get_extension() not in ["tres", "res", "meshlib"]:
		return host._err("output_path must end in .tres, .res or .meshlib")
	var opened := _open_scene_file(args.get("scene_path", ""), false)
	if not bool(opened["ok"]):
		return host._err(opened["error"])
	var root: Node = opened["root"]
	var wanted: Array = args.get("items", []) if typeof(args.get("items", [])) == TYPE_ARRAY else []
	var lib := MeshLibrary.new()
	var id := 0
	var names := PackedStringArray()
	for child in root.get_children():
		if not wanted.is_empty() and not wanted.has(String(child.name)):
			continue
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi == null:
			for d in child.find_children("*", "MeshInstance3D", true, false):
				mi = d
				break
		if mi == null or mi.mesh == null:
			continue
		lib.create_item(id)
		lib.set_item_name(id, String(child.name))
		lib.set_item_mesh(id, mi.mesh)
		lib.set_item_mesh_transform(id, mi.transform if mi != child else Transform3D.IDENTITY)
		var shapes: Array = []
		for cs in child.find_children("*", "CollisionShape3D", true, false):
			var shape_node := cs as CollisionShape3D
			if shape_node.shape != null:
				shapes.append(shape_node.shape)
				shapes.append(shape_node.transform)
		if not shapes.is_empty():
			lib.set_item_shapes(id, shapes)
		names.append(String(child.name))
		id += 1
	_discard(opened)
	if id == 0:
		return host._err("No child with a MeshInstance3D + mesh found in the scene.")
	_ensure_dir_for(out_path)
	var err := ResourceSaver.save(lib, out_path)
	if err != OK:
		return host._err("Could not save %s (%s)." % [out_path, error_string(err)])
	_notify_fs(out_path)
	return host._ok("MeshLibrary with %d item(s) saved to %s: %s" % [id, out_path, ", ".join(names)])


# ---------------------------------------------------------------------------
# resources
# ---------------------------------------------------------------------------

func _tool_create_resource(args: Dictionary) -> Dictionary:
	var path := _res_path(args.get("resource_path", ""))
	var chk := _check(path, true)
	if not bool(chk["ok"]):
		return chk
	if path.get_extension() not in ["tres", "res"]:
		return host._err("resource_path must end in .tres or .res")
	if FileAccess.file_exists(path) and not bool(args.get("overwrite", false)):
		return host._err("%s already exists (pass overwrite=true to replace it)." % path)
	var type := String(args.get("resource_type", "")).strip_edges()
	var obj := _instantiate_class(type)
	if obj == null:
		return host._err("'%s' is not an instantiable class." % type)
	if not (obj is Resource):
		if not (obj is RefCounted):
			obj.free()
		return host._err("'%s' is not a Resource." % type)
	var res: Resource = obj
	var problems := _apply_properties(res, args.get("properties", {}))
	_ensure_dir_for(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		return host._err("Could not save %s (%s)." % [path, error_string(err)])
	_notify_fs(path)
	var msg := "Created %s (%s)." % [path, type]
	if not problems.is_empty():
		msg += " Warnings: " + "; ".join(problems)
	return host._ok(msg)


func _tool_read_resource(args: Dictionary) -> Dictionary:
	var path := _res_path(args.get("resource_path", ""))
	var chk := _check(path, false)
	if not bool(chk["ok"]):
		return chk
	if not ResourceLoader.exists(path):
		return host._err("Resource not found: " + path)
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return host._err("Could not load " + path)
	var props := {}
	for p in (res as Object).get_property_list():
		var usage := int(p.get("usage", 0))
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var pname := String(p["name"])
		if pname in ["resource_path", "resource_local_to_scene", "resource_name", "script"] and (res as Object).get(pname) in [null, "", false]:
			continue
		props[pname] = _describe_value((res as Object).get(pname))
	var out := {"path": path, "type": (res as Object).get_class(), "properties": props}
	var script: Script = (res as Object).get_script()
	if script != null:
		out["script"] = script.resource_path
		var gname := String(script.get_global_name())
		if not gname.is_empty():
			out["script_class"] = gname
	if res is Theme:
		var theme: Theme = res
		var items := {}
		for t in theme.get_type_list():
			var entry := {}
			for c in theme.get_color_list(t):
				entry["colors/" + c] = theme.get_color(c, t).to_html()
			for c in theme.get_constant_list(t):
				entry["constants/" + c] = theme.get_constant(c, t)
			for c in theme.get_font_size_list(t):
				entry["font_sizes/" + c] = theme.get_font_size(c, t)
			for c in theme.get_stylebox_list(t):
				entry["styles/" + c] = theme.get_stylebox(c, t).get_class()
			for c in theme.get_font_list(t):
				entry["fonts/" + c] = _describe_value(theme.get_font(c, t))
			for c in theme.get_icon_list(t):
				entry["icons/" + c] = _describe_value(theme.get_icon(c, t))
			items[t] = entry
		out["theme_items"] = items
	return host._ok(_json(out))


func _tool_modify_resource(args: Dictionary) -> Dictionary:
	var path := _res_path(args.get("resource_path", ""))
	var chk := _check(path, true)
	if not bool(chk["ok"]):
		return chk
	if not ResourceLoader.exists(path):
		return host._err("Resource not found: " + path)
	if path.get_extension() in ["tscn", "scn"]:
		return host._err("Use the godot_scene_* tools for scenes.")
	if FileAccess.file_exists(path + ".import"):
		return host._err("%s is an imported asset; change it with godot_set_import_settings instead." % path)
	# The cached instance is the one the editor (and open scenes) use, so edit it.
	var res = load(path)
	if not (res is Resource):
		return host._err("Could not load " + path)
	var props = args.get("properties", {})
	if typeof(props) != TYPE_DICTIONARY or (props as Dictionary).is_empty():
		return host._err("properties must be a non-empty object.")
	var problems := _apply_properties(res, props)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		return host._err("Could not save %s (%s)." % [path, error_string(err)])
	(res as Resource).emit_changed()
	_notify_fs(path)
	var msg := "Updated %s: %s" % [path, ", ".join(PackedStringArray((props as Dictionary).keys()))]
	if not problems.is_empty():
		msg += ". Warnings: " + "; ".join(problems)
	return host._ok(msg)


func _tool_get_uid(args: Dictionary) -> Dictionary:
	var path := _res_path(args.get("path", ""))
	var chk := _check(path, false)
	if not bool(chk["ok"]):
		return chk
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return host._err("File not found: " + path)
	var id := ResourceLoader.get_resource_uid(path)
	if id != ResourceUID.INVALID_ID:
		return host._ok(_json({"path": path, "uid": ResourceUID.id_to_text(id)}))
	if FileAccess.file_exists(path + ".uid"):
		return host._ok(_json({"path": path, "uid": FileAccess.get_file_as_string(path + ".uid").strip_edges(), "source": ".uid file"}))
	return host._ok(_json({"path": path, "uid": null, "note": "No UID yet. Run godot_update_uids (or save the file in the editor) to generate one."}))


func _tool_update_uids(args: Dictionary) -> Dictionary:
	var folder := _res_path(args.get("folder", "res://"))
	if folder.is_empty():
		folder = "res://"
	var chk := _check(folder, true)
	if not bool(chk["ok"]):
		return chk
	var files := PackedStringArray()
	_collect_files(folder, ["tscn", "tres", "gd", "gdshader", "shader"], files, 10000)
	var saved := 0
	var generated := 0
	var failed := PackedStringArray()
	var open_unsaved: Array = Array(EditorInterface.get_unsaved_scenes()) if _editor() else []
	for f in files:
		if f.begins_with("res://addons/ai_studio"):
			continue
		var ext := f.get_extension()
		if ext in ["tscn", "tres"]:
			if open_unsaved.has(f):
				failed.append(f + " (open with unsaved changes)")
				continue
			var res = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_REUSE)
			if res == null or ResourceSaver.save(res, f) != OK:
				failed.append(f)
			else:
				saved += 1
		elif not FileAccess.file_exists(f + ".uid"):
			var sres = load(f)
			if sres != null and ResourceSaver.save(sres, f) == OK:
				generated += 1
			else:
				failed.append(f)
	_rescan()
	var msg := "Re-saved %d scene/resource file(s), generated %d missing .uid file(s) under %s." % [saved, generated, folder]
	if not failed.is_empty():
		msg += " Failed: " + ", ".join(failed.slice(0, 30))
	return host._ok(msg)


func _collect_files(path: String, exts: Array, out: PackedStringArray, limit: int) -> void:
	if out.size() >= limit:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if out.size() >= limit:
			return
		if exts.is_empty() or String(f).get_extension().to_lower() in exts:
			out.append(path.path_join(String(f)))
	for d in dir.get_directories():
		if String(d).begins_with("."):
			continue
		_collect_files(path.path_join(String(d)), exts, out, limit)


# ---------------------------------------------------------------------------
# scripts
# ---------------------------------------------------------------------------

## Captures compiler errors while a script is (re)compiled.
class _CompileLog extends Logger:
	var mutex := Mutex.new()
	var entries: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		entries.append({"file": file, "line": line, "message": rationale if not rationale.is_empty() else code,
			"type": error_type, "function": function})
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _tool_validate_scripts(args: Dictionary) -> Dictionary:
	var paths := PackedStringArray()
	var explicit = args.get("paths", [])
	var note := ""
	if typeof(explicit) == TYPE_ARRAY and not (explicit as Array).is_empty():
		for p in explicit:
			paths.append(_res_path(p))
	elif String(args.get("scope", "changed")) == "all":
		_collect_files("res://", ["gd"], paths, 100000)
	else:
		var changed := _git_changed_scripts()
		if changed.has("error"):
			return host._err(String(changed["error"]) + " Pass 'paths' or scope='all' instead.")
		paths = changed["paths"]
		if paths.is_empty():
			return host._ok("No changed .gd files according to git.")
	var filtered := PackedStringArray()
	var from_scope := typeof(explicit) != TYPE_ARRAY or (explicit as Array).is_empty()
	for p in paths:
		# Third-party addons are only checked when asked for explicitly.
		if from_scope and p.begins_with("res://addons/"):
			continue
		filtered.append(p)
	if filtered.size() > MAX_VALIDATE:
		note = " (checked the first %d of %d files)" % [MAX_VALIDATE, filtered.size()]
		filtered = filtered.slice(0, MAX_VALIDATE)
	var results: Array = []
	var failed := 0
	for p in filtered:
		var r := _compile_script(p)
		if not bool(r["ok"]):
			failed += 1
		results.append(r)
	var lines := PackedStringArray()
	lines.append("%d script(s) checked, %d with errors%s." % [results.size(), failed, note])
	for r in results:
		if bool(r["ok"]):
			lines.append("OK   " + String(r["path"]))
		else:
			lines.append("FAIL " + String(r["path"]))
			for e in r["errors"]:
				lines.append("     line %s: %s" % [str(e.get("line", "?")), String(e.get("message", ""))])
	var out: Dictionary = host._ok("\n".join(lines))
	out["failed"] = failed
	return out


func _compile_script(path: String) -> Dictionary:
	var chk := _check(path, false)
	if not bool(chk["ok"]):
		return {"path": path, "ok": false, "errors": [{"message": chk["error"]}]}
	if path.get_extension() != "gd":
		return {"path": path, "ok": false, "errors": [{"message": "Not a .gd file."}]}
	if not FileAccess.file_exists(path):
		return {"path": path, "ok": false, "errors": [{"message": "File not found."}]}
	var log := _CompileLog.new()
	OS.add_logger(log)
	# CACHE_MODE_IGNORE compiles the file on disk from scratch, without touching
	# the instance the editor already uses.
	var script = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	OS.remove_logger(log)
	var errors: Array = []
	log.mutex.lock()
	for e in log.entries:
		if int(e["type"]) == Logger.ERROR_TYPE_WARNING:
			continue
		var file := String(e["file"])
		if file == path or file.begins_with("res://"):
			errors.append({"line": int(e["line"]) if file == path else 0,
				"message": String(e["message"]).trim_prefix("Parse Error: ") + ("" if file == path else " (in %s:%d)" % [file, int(e["line"])])})
	log.mutex.unlock()
	var ok := errors.is_empty() and script is GDScript
	if not ok and errors.is_empty():
		errors.append({"message": "Failed to load/compile."})
	return {"path": path, "ok": ok, "errors": errors}


func _git_changed_scripts() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://")
	var outputs: Array = []
	for git_args in [["diff", "--name-only", "--relative"], ["diff", "--name-only", "--relative", "--cached"],
			["ls-files", "--others", "--exclude-standard"]]:
		var out: Array = []
		var code := OS.execute("git", PackedStringArray(["-C", root] + git_args), out, true)
		if code != 0:
			return {"error": "git is not available or this project is not a git repository."}
		outputs.append(String(out[0]) if not out.is_empty() else "")
	var seen := {}
	var paths := PackedStringArray()
	for text in outputs:
		for line in String(text).split("\n"):
			var rel := String(line).strip_edges().replace("\\", "/")
			if rel.get_extension().to_lower() != "gd":
				continue
			var p := "res://" + rel
			if seen.has(p) or not FileAccess.file_exists(p):
				continue
			seen[p] = true
			paths.append(p)
	return {"paths": paths}


func _tool_create_script(args: Dictionary) -> Dictionary:
	var path := _res_path(args.get("path", ""))
	var chk := _check(path, true)
	if not bool(chk["ok"]):
		return chk
	var ext := path.get_extension().to_lower()
	if ext not in ["gd", "cs"]:
		return host._err("path must end in .gd or .cs")
	if FileAccess.file_exists(path) and not bool(args.get("overwrite", false)):
		return host._err("%s already exists (pass overwrite=true to replace it)." % path)
	var base := String(args.get("extends", "Node")).strip_edges()
	if base.is_empty():
		base = "Node"
	var cls := String(args.get("class_name", "")).strip_edges()
	var methods: Array = args.get("methods", []) if typeof(args.get("methods", [])) == TYPE_ARRAY else []
	var source := String(args.get("source", ""))
	if ext == "cs":
		var file_base := path.get_file().get_basename()
		if not file_base.is_valid_ascii_identifier():
			return host._err("C# file name '%s' must be a valid class name (Godot requires class name == file name)." % file_base)
		if not cls.is_empty() and cls != file_base:
			return host._err("class_name '%s' must match the file name '%s' for C# scripts." % [cls, file_base])
		if source.is_empty():
			source = _csharp_template(file_base, base, String(args.get("namespace", "")), methods)
	elif source.is_empty():
		var lines := PackedStringArray()
		if not cls.is_empty():
			if not cls.is_valid_ascii_identifier():
				return host._err("class_name must be a valid identifier.")
			lines.append("class_name " + cls)
		lines.append("extends " + base)
		for m in methods:
			var mname := String(m).strip_edges()
			if mname.is_empty():
				continue
			lines.append("")
			lines.append("")
			lines.append(String(GDSCRIPT_STUBS.get(mname, "func %s() -> void:" % mname)))
			lines.append("\tpass")
		source = "\n".join(lines) + "\n"
	var write: Dictionary = host._tool_write_file({"path": path, "content": source})
	if not bool(write["ok"]):
		return write
	if ext == "cs":
		return host._ok("Created C# script %s. Build the C# project to compile it." % path)
	var v := _compile_script(path)
	if bool(v["ok"]):
		return host._ok("Created %s (compiles cleanly)." % path)
	var errs := PackedStringArray()
	for e in v["errors"]:
		errs.append("line %s: %s" % [str(e.get("line", "?")), String(e.get("message", ""))])
	return host._ok("Created %s, but it does not compile yet:\n%s" % [path, "\n".join(errs)])


func _csharp_template(cls: String, base: String, namespace_name: String, methods: Array) -> String:
	# File-scoped namespaces keep the class at one indentation level either way.
	var blocks := PackedStringArray()
	var seen := {}
	for m in methods:
		var name := String(m).strip_edges()
		if name.is_empty() or seen.has(name):
			continue
		seen[name] = true
		var sig := String(CSHARP_OVERRIDES.get(name, "public void %s()" % name))
		blocks.append("\t%s\n\t{\n\t}" % sig)
	var text := "using Godot;\n\n"
	if not namespace_name.is_empty():
		text += "namespace %s;\n\n" % namespace_name
	text += "public partial class %s : %s\n{\n%s\n}\n" % [cls, base, "\n\n".join(blocks)]
	return text


func _tool_create_shader(args: Dictionary) -> Dictionary:
	var path := _res_path(args.get("path", ""))
	var chk := _check(path, true)
	if not bool(chk["ok"]):
		return chk
	if path.get_extension() != "gdshader":
		return host._err("path must end in .gdshader")
	if FileAccess.file_exists(path) and not bool(args.get("overwrite", false)):
		return host._err("%s already exists (pass overwrite=true to replace it)." % path)
	var source := String(args.get("source", ""))
	if source.is_empty():
		var type := String(args.get("shader_type", "spatial"))
		match type:
			"canvas_item":
				source = "shader_type canvas_item;\n\nvoid fragment() {\n\tCOLOR = texture(TEXTURE, UV);\n}\n"
			"particles":
				source = "shader_type particles;\n\nvoid start() {\n}\n\nvoid process() {\n}\n"
			"sky":
				source = "shader_type sky;\n\nvoid sky() {\n\tCOLOR = mix(vec3(0.3, 0.4, 0.6), vec3(0.6, 0.8, 1.0), clamp(EYEDIR.y, 0.0, 1.0));\n}\n"
			"fog":
				source = "shader_type fog;\n\nvoid fog() {\n\tDENSITY = 0.05;\n}\n"
			_:
				source = "shader_type spatial;\n\nuniform vec4 albedo : source_color = vec4(1.0);\n\nvoid fragment() {\n\tALBEDO = albedo.rgb;\n}\n"
	return host._tool_write_file({"path": path, "content": source})


# ---------------------------------------------------------------------------
# files
# ---------------------------------------------------------------------------

func _tool_manage_files(args: Dictionary) -> Dictionary:
	var action := String(args.get("action", ""))
	var path := _res_path(args.get("path", ""))
	var chk := _check(path, true)
	if not bool(chk["ok"]):
		return chk
	if path == "res://" or path == "res://project.godot":
		return host._err("Refusing to touch the project root or project.godot.")
	match action:
		"mkdir":
			if DirAccess.dir_exists_absolute(path):
				return host._ok("Folder already exists: " + path)
			var err := DirAccess.make_dir_recursive_absolute(path)
			if err != OK:
				return host._err("Could not create %s (%s)." % [path, error_string(err)])
			_rescan()
			return host._ok("Created folder " + path)
		"delete":
			if DirAccess.dir_exists_absolute(path):
				return host._err("Deleting folders is not supported; delete the files inside it instead.")
			if not FileAccess.file_exists(path):
				return host._err("File not found: " + path)
			if _editor() and Array(EditorInterface.get_open_scenes()).has(path):
				return host._err("%s is open in the editor; close it first." % path)
			var abs_path := ProjectSettings.globalize_path(path)
			var err := OS.move_to_trash(abs_path)
			var how := "moved to the trash"
			if err != OK:
				err = DirAccess.remove_absolute(abs_path)
				how = "deleted"
			if err != OK:
				return host._err("Could not delete %s (%s)." % [path, error_string(err)])
			for side in [".import", ".uid"]:
				if FileAccess.file_exists(path + side):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(path + side))
			_rescan()
			return host._ok("%s %s." % [path, how])
		"move", "copy":
			var dest := _res_path(args.get("new_path", ""))
			var dchk := _check(dest, true)
			if not bool(dchk["ok"]):
				return dchk
			if not FileAccess.file_exists(path):
				return host._err("File not found: " + path)
			if FileAccess.file_exists(dest):
				return host._err("Destination already exists: " + dest)
			_ensure_dir_for(dest)
			var err := OK
			if action == "move":
				if _editor() and Array(EditorInterface.get_open_scenes()).has(path):
					return host._err("%s is open in the editor; close it first." % path)
				err = DirAccess.rename_absolute(path, dest)
				if err == OK:
					for side in [".import", ".uid"]:
						if FileAccess.file_exists(path + side):
							DirAccess.rename_absolute(path + side, dest + side)
			else:
				err = DirAccess.copy_absolute(path, dest)
			if err != OK:
				return host._err("Could not %s %s (%s)." % [action, path, error_string(err)])
			_rescan()
			var note := ""
			if action == "move" and path.get_extension() in ["gd", "tscn", "tres", "gdshader"]:
				note = " References by uid:// keep working; plain res:// references to the old path must be updated."
			return host._ok("%s %s -> %s.%s" % ["Moved" if action == "move" else "Copied", path, dest, note])
	return host._err("Unknown action '%s' (delete, move, copy, mkdir)." % action)


# ---------------------------------------------------------------------------
# project configuration
# ---------------------------------------------------------------------------

func _save_settings() -> Dictionary:
	var err := ProjectSettings.save()
	if err != OK:
		return host._err("Could not save project.godot (%s)." % error_string(err))
	return host._ok("")


func _tool_set_project_setting(args: Dictionary) -> Dictionary:
	var name := String(args.get("name", "")).strip_edges()
	if name.is_empty() or not name.contains("/"):
		return host._err("name must be a full setting path such as 'application/config/name'.")
	if name.begins_with("editor_plugins/") or name.begins_with("autoload/"):
		return host._err("Use godot_manage_plugins / godot_manage_autoloads for that.")
	var old: Variant = ProjectSettings.get_setting(name) if ProjectSettings.has_setting(name) else null
	if bool(args.get("erase", false)):
		ProjectSettings.set_setting(name, null)
		var r := _save_settings()
		return r if not bool(r["ok"]) else host._ok("Erased %s (was %s)." % [name, var_to_str(old)])
	if not args.has("value"):
		return host._err("value is required.")
	var value: Variant = _literal(args.get("value"))
	# Keep the setting's existing type (e.g. "1280" -> int, 1 -> float, "x" -> StringName).
	if old != null and typeof(value) != typeof(old) and typeof(value) != TYPE_STRING:
		value = type_convert(value, typeof(old))
	elif old != null and typeof(value) == TYPE_STRING and typeof(old) in [TYPE_STRING_NAME, TYPE_NODE_PATH]:
		value = type_convert(value, typeof(old))
	ProjectSettings.set_setting(name, value)
	var res := _save_settings()
	if not bool(res["ok"]):
		return res
	return host._ok("%s = %s (was %s). Some settings need a project restart (Project > Reload Current Project)." % [name, var_to_str(value), var_to_str(old)])


func _tool_set_main_scene(args: Dictionary) -> Dictionary:
	var path := _res_path(args.get("scene_path", ""))
	var chk := _check(path, false)
	if not bool(chk["ok"]):
		return chk
	if not ResourceLoader.exists(path) or path.get_extension() not in ["tscn", "scn"]:
		return host._err("Scene not found: " + path)
	var id := ResourceLoader.get_resource_uid(path)
	var value := ResourceUID.id_to_text(id) if id != ResourceUID.INVALID_ID else path
	ProjectSettings.set_setting("application/run/main_scene", value)
	var res := _save_settings()
	return res if not bool(res["ok"]) else host._ok("Main scene set to %s (%s)." % [path, value])


func _tool_manage_autoloads(args: Dictionary) -> Dictionary:
	var action := String(args.get("action", "list"))
	match action:
		"list":
			var items: Array = []
			for p in ProjectSettings.get_property_list():
				var key := String(p["name"])
				if key.begins_with("autoload/"):
					var raw := String(ProjectSettings.get_setting(key))
					var target := raw.trim_prefix("*")
					if target.begins_with("uid://"):
						target = _res_path(target)
					items.append({"name": key.trim_prefix("autoload/"), "path": target, "global": raw.begins_with("*")})
			return host._ok(_json({"autoloads": items}))
		"add":
			var name := String(args.get("name", "")).strip_edges()
			var path := _res_path(args.get("path", ""))
			if not name.is_valid_ascii_identifier():
				return host._err("name must be a valid identifier.")
			if ClassDB.class_exists(name):
				return host._err("'%s' is an engine class name; pick another name." % name)
			var chk := _check(path, false)
			if not bool(chk["ok"]):
				return chk
			if not ResourceLoader.exists(path) or path.get_extension() not in ["gd", "tscn", "scn", "cs"]:
				return host._err("path must be an existing script or scene: " + path)
			var stored := ("*" if bool(args.get("global", true)) else "") + path
			ProjectSettings.set_setting("autoload/" + name, stored)
			ProjectSettings.set_order("autoload/" + name, _next_autoload_order())
			var res := _save_settings()
			return res if not bool(res["ok"]) else host._ok("Autoload %s -> %s added. It is available in the next game run; editor code sees it after Project > Reload Current Project." % [name, path])
		"remove":
			var rname := String(args.get("name", "")).strip_edges()
			if not ProjectSettings.has_setting("autoload/" + rname):
				return host._err("No autoload named '%s'." % rname)
			if rname == AIStudioGameBridge.AUTOLOAD_NAME:
				return host._err("Use godot_game_bridge to disable the AI Studio game bridge.")
			ProjectSettings.set_setting("autoload/" + rname, null)
			var res2 := _save_settings()
			return res2 if not bool(res2["ok"]) else host._ok("Autoload %s removed." % rname)
	return host._err("Unknown action '%s' (list, add, remove)." % action)


func _next_autoload_order() -> int:
	var highest := 0
	for p in ProjectSettings.get_property_list():
		if String(p["name"]).begins_with("autoload/"):
			highest = maxi(highest, ProjectSettings.get_order(String(p["name"])))
	return highest + 1


func _tool_manage_input_map(args: Dictionary) -> Dictionary:
	var action := String(args.get("action", "list"))
	if action == "list":
		var out := {}
		for p in ProjectSettings.get_property_list():
			var key := String(p["name"])
			if not key.begins_with("input/"):
				continue
			var entry = ProjectSettings.get_setting(key)
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var events := PackedStringArray()
			for ev in (entry as Dictionary).get("events", []):
				if ev is InputEvent:
					events.append((ev as InputEvent).as_text())
			out[key.trim_prefix("input/")] = {"deadzone": entry.get("deadzone", 0.5), "events": Array(events)}
		return host._ok(_json({"actions": out, "note": "Built-in ui_* actions are only listed when the project overrides them."}))
	var name := String(args.get("action_name", "")).strip_edges()
	if name.is_empty() or name.contains("/") or name.contains(" "):
		return host._err("action_name is required (no spaces or slashes).")
	var key := "input/" + name
	match action:
		"remove":
			if not ProjectSettings.has_setting(key):
				return host._err("No input action '%s' in project settings." % name)
			ProjectSettings.set_setting(key, null)
			var r := _save_settings()
			return r if not bool(r["ok"]) else host._ok("Input action '%s' removed." % name)
		"add", "clear_events":
			var entry: Dictionary = {}
			if ProjectSettings.has_setting(key) and typeof(ProjectSettings.get_setting(key)) == TYPE_DICTIONARY:
				entry = (ProjectSettings.get_setting(key) as Dictionary).duplicate(true)
			if not entry.has("deadzone"):
				entry["deadzone"] = float(args.get("deadzone", 0.2))
			var events: Array = entry.get("events", []) if action == "add" else []
			var added := PackedStringArray()
			var problems := PackedStringArray()
			if action == "add":
				for k in _arr(args.get("keys", [])):
					var ev := _key_event(String(k))
					if ev == null:
						problems.append("unknown key '%s'" % k)
					elif not _has_event(events, ev):
						events.append(ev)
						added.append(ev.as_text())
				for b in _arr(args.get("mouse_buttons", [])):
					var mb := InputEventMouseButton.new()
					mb.button_index = int(b) as MouseButton
					if not _has_event(events, mb):
						events.append(mb)
						added.append(mb.as_text())
				for b in _arr(args.get("joy_buttons", [])):
					var jb := InputEventJoypadButton.new()
					jb.button_index = int(b) as JoyButton
					jb.device = -1
					if not _has_event(events, jb):
						events.append(jb)
						added.append(jb.as_text())
				for a in _arr(args.get("joy_axes", [])):
					var parts := String(a).split(":")
					var jm := InputEventJoypadMotion.new()
					jm.axis = int(parts[0]) as JoyAxis
					jm.axis_value = -1.0 if parts.size() > 1 and float(parts[1]) < 0 else 1.0
					jm.device = -1
					if not _has_event(events, jm):
						events.append(jm)
						added.append(jm.as_text())
			entry["events"] = events
			ProjectSettings.set_setting(key, entry)
			var r2 := _save_settings()
			if not bool(r2["ok"]):
				return r2
			if not InputMap.has_action(name):
				InputMap.add_action(name, float(entry["deadzone"]))
			var msg := "Input action '%s' now has %d binding(s)" % [name, events.size()]
			if not added.is_empty():
				msg += "; added: " + ", ".join(added)
			if not problems.is_empty():
				msg += ". Problems: " + "; ".join(problems)
			return host._ok(msg + ".")
	return host._err("Unknown action '%s' (list, add, remove, clear_events)." % action)


static func _arr(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


static func _has_event(events: Array, ev: InputEvent) -> bool:
	for e in events:
		if e is InputEvent and (e as InputEvent).is_match(ev, true) and e.get_class() == ev.get_class():
			return true
	return false


static func _key_event(text: String) -> InputEventKey:
	var parts := text.strip_edges().split("+")
	var ev := InputEventKey.new()
	var key_name := String(parts[parts.size() - 1]).strip_edges()
	for i in parts.size() - 1:
		match String(parts[i]).strip_edges().to_lower():
			"ctrl", "control":
				ev.ctrl_pressed = true
			"shift":
				ev.shift_pressed = true
			"alt":
				ev.alt_pressed = true
			"meta", "cmd", "command", "super":
				ev.meta_pressed = true
	var aliases := {"esc": "Escape", "return": "Enter", "del": "Delete", "spacebar": "Space",
		"ctrl": "Ctrl", "arrowup": "Up", "arrowdown": "Down", "arrowleft": "Left", "arrowright": "Right"}
	var lookup := String(aliases.get(key_name.to_lower(), key_name))
	var code := OS.find_keycode_from_string(lookup)
	if code == KEY_NONE and lookup.length() == 1:
		code = OS.find_keycode_from_string(lookup.to_upper())
	if code == KEY_NONE:
		return null
	ev.physical_keycode = code as Key
	return ev


func _tool_manage_layers(args: Dictionary) -> Dictionary:
	var action := String(args.get("action", "list"))
	if action == "list":
		var out := {}
		for family in ["2d_render", "2d_physics", "2d_navigation", "3d_render", "3d_physics", "3d_navigation", "avoidance"]:
			var named := {}
			for i in range(1, 33):
				var key := "layer_names/%s/layer_%d" % [family, i]
				if ProjectSettings.has_setting(key):
					var v := String(ProjectSettings.get_setting(key))
					if not v.is_empty():
						named[str(i)] = v
			if not named.is_empty():
				out[family] = named
		return host._ok(_json({"layers": out}))
	if action != "set":
		return host._err("Unknown action '%s' (list, set)." % action)
	var family := String(LAYER_TYPES.get(String(args.get("layer_type", "")), ""))
	if family.is_empty():
		return host._err("layer_type must be one of: render_2d, physics_2d, navigation_2d, render_3d, physics_3d, navigation_3d, avoidance.")
	var layer := int(args.get("layer", 0))
	if layer < 1 or layer > 32:
		return host._err("layer must be between 1 and 32.")
	var key := "layer_names/%s/layer_%d" % [family, layer]
	ProjectSettings.set_setting(key, String(args.get("name", "")))
	var res := _save_settings()
	return res if not bool(res["ok"]) else host._ok("%s = \"%s\"" % [key, String(args.get("name", ""))])


func _tool_manage_plugins(args: Dictionary) -> Dictionary:
	var action := String(args.get("action", "list"))
	var available := PackedStringArray()
	var dir := DirAccess.open("res://addons")
	if dir != null:
		for d in dir.get_directories():
			if FileAccess.file_exists("res://addons/%s/plugin.cfg" % d):
				available.append(String(d))
	if action == "list":
		var items: Array = []
		for p in available:
			var cfg := ConfigFile.new()
			cfg.load("res://addons/%s/plugin.cfg" % p)
			items.append({"plugin": p, "name": String(cfg.get_value("plugin", "name", p)),
				"version": String(cfg.get_value("plugin", "version", "")),
				"enabled": EditorInterface.is_plugin_enabled(p)})
		return host._ok(_json({"plugins": items}))
	var plugin := String(args.get("plugin", "")).strip_edges().trim_prefix("res://addons/").trim_suffix("/")
	if not available.has(plugin):
		return host._err("No plugin '%s' in addons/ (available: %s)." % [plugin, ", ".join(available)])
	if plugin == "ai_studio":
		return host._err("AI Studio cannot enable or disable itself.")
	if action == "enable" or action == "disable":
		EditorInterface.set_plugin_enabled(plugin, action == "enable")
		return host._ok("Plugin '%s' %s (now %s)." % [plugin, action + "d", "enabled" if EditorInterface.is_plugin_enabled(plugin) else "disabled"])
	return host._err("Unknown action '%s' (list, enable, disable)." % action)


func _tool_manage_translations(args: Dictionary) -> Dictionary:
	var key := "internationalization/locale/translations"
	var current := PackedStringArray(ProjectSettings.get_setting(key, PackedStringArray()))
	var action := String(args.get("action", "list"))
	if action == "list":
		return host._ok(_json({"translations": Array(current)}))
	var path := _res_path(args.get("path", ""))
	var chk := _check(path, false)
	if not bool(chk["ok"]):
		return chk
	match action:
		"add":
			if not ResourceLoader.exists(path):
				return host._err("Translation not found: " + path)
			if current.has(path):
				return host._ok("Already registered: " + path)
			current.append(path)
		"remove":
			if not current.has(path):
				return host._err("Not registered: " + path)
			current.remove_at(current.find(path))
		_:
			return host._err("Unknown action '%s' (list, add, remove)." % action)
	ProjectSettings.set_setting(key, current)
	var res := _save_settings()
	return res if not bool(res["ok"]) else host._ok("Translations: " + ", ".join(current))


# ---------------------------------------------------------------------------
# export / CI
# ---------------------------------------------------------------------------

const PRESETS_PATH := "res://export_presets.cfg"


func _load_presets() -> ConfigFile:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(PRESETS_PATH):
		cfg.load(PRESETS_PATH)
	return cfg


func _preset_sections(cfg: ConfigFile) -> Array:
	var out: Array = []
	for s in cfg.get_sections():
		if String(s).begins_with("preset.") and String(s).count(".") == 1:
			out.append(String(s))
	out.sort_custom(func(a, b): return int(String(a).get_slice(".", 1)) < int(String(b).get_slice(".", 1)))
	return out


func _preset_platform(preset: String) -> String:
	var cfg := _load_presets()
	for s in _preset_sections(cfg):
		if String(cfg.get_value(s, "name", "")) == preset:
			return String(cfg.get_value(s, "platform", ""))
	return ""


func _preset_names() -> PackedStringArray:
	var cfg := _load_presets()
	var out := PackedStringArray()
	for s in _preset_sections(cfg):
		out.append(String(cfg.get_value(s, "name", "")))
	return out


func _tool_manage_export_presets(args: Dictionary) -> Dictionary:
	var cfg := _load_presets()
	var action := String(args.get("action", "list"))
	var sections := _preset_sections(cfg)
	if action == "list":
		var items: Array = []
		for s in sections:
			items.append({"name": cfg.get_value(s, "name", ""), "platform": cfg.get_value(s, "platform", ""),
				"runnable": cfg.get_value(s, "runnable", false), "export_path": cfg.get_value(s, "export_path", "")})
		return host._ok(_json({"presets": items}))
	var name := String(args.get("name", "")).strip_edges()
	if name.is_empty():
		return host._err("name is required.")
	match action:
		"add":
			for s in sections:
				if String(cfg.get_value(s, "name", "")) == name:
					return host._err("A preset named '%s' already exists." % name)
			var platform := String(args.get("platform", "")).strip_edges()
			if platform.is_empty():
				return host._err("platform is required, e.g. 'Windows Desktop', 'Linux', 'macOS', 'Web', 'Android'.")
			var idx := sections.size()
			var sec := "preset.%d" % idx
			cfg.set_value(sec, "name", name)
			cfg.set_value(sec, "platform", platform)
			cfg.set_value(sec, "runnable", bool(args.get("runnable", false)))
			cfg.set_value(sec, "dedicated_server", false)
			cfg.set_value(sec, "custom_features", "")
			cfg.set_value(sec, "export_filter", "all_resources")
			cfg.set_value(sec, "include_filter", "")
			cfg.set_value(sec, "exclude_filter", "")
			cfg.set_value(sec, "export_path", String(args.get("export_path", "")))
			cfg.set_value(sec + ".options", "__placeholder", null)
			var err := cfg.save(PRESETS_PATH)
			if err != OK:
				return host._err("Could not write export_presets.cfg (%s)." % error_string(err))
			return host._ok("Preset '%s' (%s) added. Open Project > Export once to let Godot fill in the platform defaults." % [name, platform])
		"remove":
			var found := ""
			for s in sections:
				if String(cfg.get_value(s, "name", "")) == name:
					found = s
			if found.is_empty():
				return host._err("No preset named '%s'." % name)
			# Rebuild with contiguous indices, as Godot expects.
			var fresh := ConfigFile.new()
			var n := 0
			for s in sections:
				if s == found:
					continue
				for sub in [s, s + ".options"]:
					if not cfg.has_section(sub):
						continue
					var target := "preset.%d%s" % [n, ".options" if sub.ends_with(".options") else ""]
					for k in cfg.get_section_keys(sub):
						fresh.set_value(target, k, cfg.get_value(sub, k))
				n += 1
			var err2 := fresh.save(PRESETS_PATH)
			if err2 != OK:
				return host._err("Could not write export_presets.cfg (%s)." % error_string(err2))
			return host._ok("Preset '%s' removed." % name)
	return host._err("Unknown action '%s' (list, add, remove)." % action)


func _tool_export_project(args: Dictionary) -> Dictionary:
	var preset := String(args.get("preset", "")).strip_edges()
	if not _preset_names().has(preset):
		return host._err("No export preset named '%s'. Presets: %s" % [preset, ", ".join(_preset_names())])
	var project_dir := ProjectSettings.globalize_path("res://")
	var output := String(args.get("output_path", "")).strip_edges()
	if output.is_empty() or output.contains(".."):
		return host._err("output_path is required and may not contain '..'.")
	if output.begins_with("res://"):
		output = ProjectSettings.globalize_path(output)
	elif not output.is_absolute_path():
		output = project_dir.path_join(output)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var flag := {"release": "--export-release", "debug": "--export-debug", "pack": "--export-pack"}.get(String(args.get("mode", "release")), "--export-release")
	var exe := OS.get_executable_path()
	var run := await _run_process(exe, PackedStringArray(["--headless", "--path", project_dir, flag, preset, output]), EXPORT_TIMEOUT_SEC)
	var tail := String(run["output"])
	if tail.length() > 4000:
		tail = "...\n" + tail.substr(tail.length() - 4000)
	if not bool(run["ok"]) or not FileAccess.file_exists(output):
		return host._err("Export failed (exit %s). Output:\n%s" % [str(run["code"]), tail])
	var size := 0
	var fh := FileAccess.open(output, FileAccess.READ)
	if fh != null:
		size = fh.get_length()
		fh = null
	return host._ok("Exported '%s' to %s (%d bytes).\n%s" % [preset, output, size, tail.substr(maxi(0, tail.length() - 1200))])


## Runs a process without freezing the editor: pipes are polled once per frame.
func _run_process(exe: String, argv: PackedStringArray, timeout_sec: float) -> Dictionary:
	var proc := OS.execute_with_pipe(exe, argv, false)
	if proc.is_empty():
		return {"ok": false, "code": -1, "output": "Could not start " + exe}
	var pid: int = proc["pid"]
	var io: FileAccess = proc["stdio"]
	var err_pipe: FileAccess = proc["stderr"]
	var buf := PackedByteArray()
	var started := Time.get_ticks_msec()
	var tree := Engine.get_main_loop() as SceneTree
	while true:
		var a := io.get_buffer(65536)
		var b := err_pipe.get_buffer(65536)
		buf.append_array(a)
		buf.append_array(b)
		if not OS.is_process_running(pid) and a.is_empty() and b.is_empty():
			break
		if Time.get_ticks_msec() - started > int(timeout_sec * 1000.0):
			OS.kill(pid)
			return {"ok": false, "code": -1, "output": buf.get_string_from_utf8() + "\n(timed out and was stopped)"}
		if tree != null:
			await tree.process_frame
		else:
			OS.delay_msec(20)
	var code := OS.get_process_exit_code(pid)
	return {"ok": code == 0, "code": code, "output": buf.get_string_from_utf8()}


func _tool_manage_ci(args: Dictionary) -> Dictionary:
	var target := String(args.get("target", ""))
	var path := ""
	match target:
		"github_actions":
			path = "res://.github/workflows/godot-export.yml"
		"docker":
			path = "res://Dockerfile"
		_:
			return host._err("target must be github_actions or docker.")
	var action := String(args.get("action", "read"))
	if action == "read":
		if not FileAccess.file_exists(path):
			return host._err("%s does not exist yet (use action=create)." % path)
		return host._ok(FileAccess.get_file_as_string(path))
	if action != "create":
		return host._err("action must be read or create.")
	if FileAccess.file_exists(path) and not bool(args.get("overwrite", false)):
		return host._err("%s already exists (pass overwrite=true to replace it)." % path)
	var presets := PackedStringArray()
	for p in _arr(args.get("presets", [])):
		presets.append(String(p))
	if presets.is_empty():
		presets = _preset_names()
	if presets.is_empty():
		return host._err("No export presets yet. Add one with godot_manage_export_presets first.")
	var info := Engine.get_version_info()
	var version := String(args.get("godot_version", "")).strip_edges()
	if version.is_empty():
		version = "%d.%d%s-%s" % [info["major"], info["minor"], (".%d" % info["patch"]) if int(info["patch"]) > 0 else "", info["status"]]
	# Godot names export template folders "4.7.2.stable", release files "4.7.2-stable".
	var templates_dir := version.replace("-", ".")
	var mono := ProjectSettings.has_setting("dotnet/project/assembly_name") and not _find_csproj().is_empty()
	var suffix := "_mono" if mono else ""
	if mono:
		templates_dir += ".mono"
	var editor_zip := "Godot_v%s%s_linux%s.zip" % [version, suffix, "_x86_64" if mono else ".x86_64"]
	var editor_bin := "Godot_v%s%s_linux.x86_64" % [version, suffix] if not mono else "Godot_v%s_mono_linux_x86_64/Godot_v%s_mono_linux.x86_64" % [version, version]
	var tpz := "Godot_v%s%s_export_templates.tpz" % [version, suffix]
	var base_url := "https://github.com/godotengine/godot/releases/download/%s" % version
	var text := ""
	if target == "docker":
		var lines := PackedStringArray([
			"# Headless export of this Godot project. Generated by AI Studio.",
			"FROM ubuntu:24.04",
			"ARG GODOT_VERSION=%s" % version,
			"RUN apt-get update && apt-get install -y --no-install-recommends wget unzip ca-certificates fontconfig && rm -rf /var/lib/apt/lists/*",
			"RUN wget -q %s/%s && unzip -q %s && mv %s /usr/local/bin/godot && chmod +x /usr/local/bin/godot && rm %s" % [base_url, editor_zip, editor_zip, editor_bin, editor_zip],
			"RUN wget -q %s/%s && mkdir -p /root/.local/share/godot/export_templates/%s && unzip -q %s && mv templates/* /root/.local/share/godot/export_templates/%s/ && rm -rf templates %s" % [base_url, tpz, templates_dir, tpz, templates_dir, tpz],
			"WORKDIR /game",
			"COPY . .",
			"RUN godot --headless --import || true",
		])
		var cmds := PackedStringArray()
		for p in presets:
			var slug := p.to_snake_case().replace(" ", "_").replace("/", "_")
			cmds.append("mkdir -p build/%s && godot --headless --export-release \"%s\" build/%s/%s" % [slug, p, slug, _default_binary_name(_preset_platform(p))])
		lines.append("RUN " + " && ".join(cmds))
		text = "\n".join(lines) + "\n"
	else:
		var steps := PackedStringArray()
		for p in presets:
			var slug := p.to_snake_case().replace(" ", "_").replace("/", "_")
			steps.append("      - name: Export %s\n        run: |\n          mkdir -p build/%s\n          godot --headless --export-release \"%s\" build/%s/%s" % [p, slug, p, slug, _default_binary_name(_preset_platform(p))])
		text = """# Exports the project on every push. Generated by AI Studio.
name: Godot export
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:
jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true
      - name: Install Godot %s
        run: |
          wget -q %s/%s
          unzip -q %s
          sudo mv %s /usr/local/bin/godot
          sudo chmod +x /usr/local/bin/godot
          wget -q %s/%s
          mkdir -p ~/.local/share/godot/export_templates/%s
          unzip -q %s
          mv templates/* ~/.local/share/godot/export_templates/%s/
      - name: Import assets
        run: godot --headless --import || true
%s
      - uses: actions/upload-artifact@v4
        with:
          name: builds
          path: build/
""" % [version, base_url, editor_zip, editor_zip, editor_bin, base_url, tpz, templates_dir, tpz, templates_dir, "\n".join(steps)]
	var parent := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		DirAccess.make_dir_recursive_absolute(parent)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return host._err("Could not write %s (%s)." % [path, error_string(FileAccess.get_open_error())])
	f.store_string(text)
	f = null
	_notify_fs(path)
	return host._ok("Wrote %s for Godot %s, presets: %s." % [path, version, ", ".join(presets)])


func _find_csproj() -> String:
	var dir := DirAccess.open("res://")
	if dir == null:
		return ""
	for f in dir.get_files():
		if String(f).get_extension() == "csproj":
			return String(f)
	return ""


static func _default_binary_name(platform: String) -> String:
	var name := String(ProjectSettings.get_setting("application/config/name", "game")).to_snake_case()
	if name.is_empty():
		name = "game"
	var p := platform.to_lower()
	if p.contains("windows"):
		return name + ".exe"
	if p.contains("web") or p.contains("html"):
		return "index.html"
	if p.contains("mac"):
		return name + ".zip"
	if p.contains("android"):
		return name + ".apk"
	return name + ".x86_64"
