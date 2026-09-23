@tool
class_name AIStudioGodot3DTools
extends RefCounted

## 3D / rig / animation tools for the AI Studio agent.
##
## These cover what a 3D game actually needs in the editor: knowing what is
## inside an imported model (skeletons, bones, meshes, blend shapes), building
## BoneMap resources and retargeting animations for rigs that have no bone map
## yet, inspecting and fixing animation track paths, reading/writing per-asset
## import settings (retarget, shadows, LOD...), and scaffolding the things every
## 3D scene needs: materials, collision/physics bodies, a camera and lighting.
##
## Registered into an AIStudioGodotTools instance, which owns the registry, the
## project-path guard and the editor-availability gate (`host` is intentionally
## untyped so the two classes do not reference each other cyclically).

var host = null   # AIStudioGodotTools

## Words that rigs put in front of real bone names; removed before matching.
const NOISE_WORDS := ["mixamorig", "armature", "def", "deform", "biped", "bip", "bone", "bn",
	"j", "f", "rig", "ctrl", "ik", "fk", "twist", "end", "nub", "null", "skeleton", "sk",
	"joint", "jnt", "org", "grp", "loc"]

## Side markers: they select Left/Right, they are not part of the bone's name.
const SIDE_WORDS := ["left", "right", "l", "r"]

## profile bone base name -> short aliases, all lowercase and stripped of
## separators and zero padding. Names here are written WITHOUT the Left/Right
## prefix: the side is detected from the source bone and re-applied to the
## profile name afterwards, so one entry covers both arms (or legs, or eyes).
## The profile's own names are added to the table automatically.
const BONE_ALIASES := {
	"Root": ["root"],
	"Hips": ["hips", "pelvis", "hip"],
	"Spine": ["spine", "abdomen", "lowerback", "waist", "spine0"],
	"Chest": ["chest", "spine1", "torso"],
	"UpperChest": ["upperchest", "spine2", "spine3", "chestupper"],
	"Neck": ["neck", "neck1"],
	"Head": ["head"],
	"Jaw": ["jaw"],
	"Shoulder": ["shoulder", "clavicle", "collar", "scapula"],
	"UpperArm": ["upperarm", "arm", "armupper", "arm1"],
	"LowerArm": ["lowerarm", "forearm", "armlower", "elbow", "arm2"],
	"Hand": ["hand", "wrist", "hand1"],
	"ThumbMetacarpal": ["thumb1", "metacarpal1"],
	"ThumbProximal": ["thumb2", "thumb"],
	"ThumbDistal": ["thumb3", "thumb4"],
	"IndexProximal": ["index1", "indexa", "fingera"],
	"IndexIntermediate": ["index2", "indexb", "fingerb"],
	"IndexDistal": ["index3", "index4", "indexc", "fingerc", "indextip"],
	"MiddleProximal": ["middle1", "middlea", "middlefinger1"],
	"MiddleIntermediate": ["middle2", "middleb", "middlefinger2"],
	"MiddleDistal": ["middle3", "middle4", "middlec", "middlefingertip"],
	"RingProximal": ["ring1", "ringa", "ringfinger1"],
	"RingIntermediate": ["ring2", "ringb", "ringfinger2"],
	"RingDistal": ["ring3", "ring4", "ringc", "ringfingertip"],
	"LittleProximal": ["little1", "pinky1", "pinkie1", "littlea"],
	"LittleIntermediate": ["little2", "pinky2", "pinkie2", "littleb"],
	"LittleDistal": ["little3", "little4", "pinky3", "pinkie3", "littlec", "littlefingertip"],
	"UpperLeg": ["upperleg", "upleg", "thigh", "legupper", "leg1"],
	"LowerLeg": ["lowerleg", "lowleg", "leg", "calf", "shin", "knee", "leg2"],
	"Foot": ["foot", "ankle"],
	"Toes": ["toes", "toe", "toebase", "ball", "toe1"],
}

const TRACK_TYPE_NAMES := ["value", "position_3d", "rotation_3d", "scale_3d", "blend_shape",
	"method", "bezier", "audio", "animation"]
const INTERP_NAMES := ["nearest", "linear", "cubic"]
const LOOP_NAMES := ["none", "linear", "ping-pong"]


func _init(host_tools) -> void:
	host = host_tools


# ---------------------------------------------------------------------------
# registration
# ---------------------------------------------------------------------------

func register() -> void:
	host._add("godot_list_bones",
		"List every bone of a skeleton: index, name, parent, rest transform, and (optionally) which SkeletonProfileHumanoid bone it maps to. Works on the edited scene or on any res:// scene/model (.tscn, .glb, .fbx, .blend...). Use this first when a rig has no bone map.",
		host._obj({
			"source": host._str("res:// scene or model to inspect (default: the edited scene)."),
			"skeleton_node": host._str("Path of the Skeleton3D inside that scene (default: the first one found)."),
			"include_rest": host._bool("Include the rest position/rotation of each bone.", true),
			"classify": host._bool("Also report the humanoid profile bone each bone most likely corresponds to.", false),
		}),
		func(args): return _tool_list_bones(args), true, "rig")

	host._add("godot_create_bone_map",
		"Create a BoneMap resource (.tres) that maps a skeleton to SkeletonProfileHumanoid, using bone-name heuristics (Mixamo, Blender/Rigify, Unreal, Godot humanoid, generic). Optionally writes retarget/bone_map into the model's .import file so Godot retargets animations for you.",
		host._obj({
			"source": host._str("res:// scene/model that contains the skeleton (default: the edited scene)."),
			"skeleton_node": host._str("Path of the Skeleton3D (default: the first one found)."),
			"output_path": host._str("Where to save the BoneMap, e.g. res://models/hero_bonemap.tres."),
			"profile": host._str("'humanoid' (default) or a res:// path to a custom SkeletonProfile."),
			"manual": {"type": "object", "description": "{ProfileBone: skeleton bone name} overrides for the heuristic matching."},
			"extra_aliases": {"type": "object", "description": "{ProfileBone: 'alias1, alias2'} extra name aliases."},
			"write_import": host._bool("Also set retarget/bone_map in the model's .import file.", false),
			"rest_fixer": host._bool("With write_import, also enable retarget/rest_fixer.", true),
		}, ["output_path"]),
		func(args): return _tool_create_bone_map(args), false, "rig")

	host._add("godot_animation_info",
		"Overview of the animations in a scene or in an animation resource/library: every AnimationPlayer, its libraries, animations, length, loop mode and track counts.",
		host._obj({
			"source": host._str("res:// scene, .res/.tres Animation or AnimationLibrary (default: the edited scene)."),
			"node_path": host._str("Only inspect this AnimationPlayer (default: all of them)."),
		}),
		func(args): return _tool_animation_info(args), true, "animation")

	host._add("godot_animation_tracks",
		"List the tracks of one animation (paths, types, key counts) and check every track path against a scene: reports nodes and bones that do not exist. This is the tool that explains why a retargeted animation plays nothing.",
		host._obj({
			"source": host._str("res:// scene the animation lives in or targets (default: the edited scene)."),
			"node_path": host._str("AnimationPlayer node path (default: the first one)."),
			"animation": host._str("Animation name to inspect."),
			"check_against": host._str("Scene/model used for the path check (default: 'source')."),
			"names_only": host._bool("Return just the track paths, no diagnostics.", false),
		}, ["animation"]),
		func(args): return _tool_animation_tracks(args), true, "animation")

	host._add("godot_retarget_animation",
		"Rewrite an animation so it plays on another skeleton: swaps a node-path prefix and/or translates bone names to the target rig (via a BoneMap, or by matching the target skeleton's bone names through the humanoid profile). Saves a new Animation resource and never touches the original.",
		host._obj({
			"animation_path": host._str("res:// .res/.tres animation, or the AnimationLibrary to take it from."),
			"source": host._str("Scene to read the animation from (used when animation_path is empty)."),
			"node_path": host._str("AnimationPlayer node path inside that scene."),
			"animation": host._str("Animation name inside the player/library."),
			"from_prefix": host._str("Node path prefix used by the animation, e.g. 'Skeleton3D' or 'Armature/Skeleton3D'."),
			"to_prefix": host._str("Replacement prefix, e.g. 'Armature/Skeleton3D'."),
			"bone_map_path": host._str("BoneMap (.tres) describing the TARGET skeleton; bone names are translated through it."),
			"target_source": host._str("Scene/model containing the TARGET skeleton (alternative to bone_map_path)."),
			"target_skeleton": host._str("Skeleton3D path inside target_source."),
			"extra_aliases": {"type": "object", "description": "{ProfileBone: 'alias1, alias2'} extra name aliases."},
			"output_path": host._str("Where to save the retargeted Animation (default: <animation>_retargeted.tres)."),
			"dry_run": host._bool("Report the changes without writing a file.", false),
		}, ["animation"]),
		func(args): return _tool_retarget_animation(args), false, "animation")

	host._add("godot_mesh_info",
		"Inspect a mesh: surfaces, vertex/face counts, size (AABB), materials, blend shapes and the skeleton a skinned mesh is bound to. Accepts a node in a scene or a mesh resource path.",
		host._obj({
			"source": host._str("res:// scene containing the node (default: the edited scene)."),
			"node_path": host._str("MeshInstance3D node path."),
			"mesh_path": host._str("Instead of a node: a res:// mesh resource (.res/.mesh/.obj)."),
			"surface_limit": host._int("How many surfaces to describe in detail (default 8).", 8),
		}),
		func(args): return _tool_mesh_info(args), true, "3d")

	host._add("godot_create_material",
		"Create a StandardMaterial3D (.tres) with albedo/metallic/roughness/emission/transparency/cull/UV settings and optional textures. Prints the path so it can be assigned with godot_set_material.",
		host._obj({
			"output_path": host._str("res:// path for the material, e.g. res://materials/rock.tres."),
			"albedo_color": host._str("Colour: '#rrggbb', '#rrggbbaa' or 'r,g,b,a'."),
			"metallic": {"type": "number", "description": "0-1."},
			"roughness": {"type": "number", "description": "0-1."},
			"emission_color": host._str("Emission colour; enables emission."),
			"emission_energy": {"type": "number", "description": "Emission strength (default 1)."},
			"transparency": host._str("disabled | alpha | alpha_scissor | alpha_hash | depth_prepass"),
			"cull_mode": host._str("back | front | disabled"),
			"shading_mode": host._str("per_pixel (default) | unshaded"),
			"vertex_color_use_as_albedo": host._bool("Multiply albedo by vertex colours.", false),
			"uv1_scale": host._str("UV1 scale as 'x,y' (e.g. '2,2')."),
			"albedo_texture": host._str("res:// texture path."),
			"normal_texture": host._str("res:// texture path."),
			"textures": {"type": "object", "description": "{material property: res:// texture path}, e.g. {'roughness_texture': '...'}."},
		}, ["output_path"]),
		func(args): return _tool_create_material(args), false, "3d")

	host._add("godot_set_material",
		"Assign a material to a MeshInstance3D (one surface or all of them) in the edited scene, undo aware.",
		host._obj({
			"node_path": host._str("MeshInstance3D node path."),
			"material_path": host._str("res:// material resource."),
			"surface": host._int("-1 (default) = every surface, otherwise a surface index.", -1),
		}, ["node_path", "material_path"]),
		func(args): return _tool_set_material(args), false, "3d")

	host._add("godot_add_physics_body",
		"Add a StaticBody3D / RigidBody3D / Area3D / CharacterBody3D with a matching CollisionShape3D to the edited scene. The shape can be fitted automatically to a MeshInstance3D's bounds (box, capsule, sphere, cylinder) or built from the mesh (trimesh, convex), and layers/masks can be set.",
		host._obj({
			"body_type": host._str("static | rigid | area | character (default character)."),
			"shape": host._str("box | sphere | capsule | cylinder | trimesh | convex | none (default box)."),
			"parent_path": host._str("Where to add the body (default: the scene root)."),
			"name": host._str("Node name (default: the body type)."),
			"fit_to": host._str("MeshInstance3D whose bounds define the shape (default: the first mesh under parent)."),
			"size": host._str("Explicit size as 'x,y,z' (overrides fit_to)."),
			"radius": {"type": "number", "description": "Explicit radius for sphere/capsule/cylinder."},
			"height": {"type": "number", "description": "Explicit height for capsule/cylinder."},
			"offset": host._str("Shape offset as 'x,y,z'."),
			"mass": {"type": "number", "description": "Rigid body mass."},
			"collision_layer": host._int("Collision layer bits (default 1).", 1),
			"collision_mask": host._int("Collision mask bits (default 1).", 1),
			"floor_snap_length": {"type": "number", "description": "CharacterBody3D floor snap length (default 0.3)."},
		}),
		func(args): return _tool_add_physics_body(args), false, "3d")

	host._add("godot_add_camera",
		"Add a Camera3D to the edited scene, optionally aimed at a node or a point, with fov/current settings. Undo aware.",
		host._obj({
			"parent_path": host._str("Parent node (default: the scene root)."),
			"name": host._str("Node name (default: Camera3D)."),
			"position": host._str("Position as 'x,y,z'."),
			"look_at": host._str("Node path or 'x,y,z' point to look at."),
			"fov": {"type": "number", "description": "Field of view in degrees (default 70)."},
			"current": host._bool("Make it the active camera of the scene.", true),
		}),
		func(args): return _tool_add_camera(args), false, "3d")

	host._add("godot_setup_3d_environment",
		"Light and finish a 3D scene in one step: adds a DirectionalLight3D (with shadows) and a WorldEnvironment with a procedural sky, ambient light, optional fog and tone mapping. Undo aware.",
		host._obj({
			"parent_path": host._str("Parent node (default: the scene root)."),
			"sun_energy": {"type": "number", "description": "Sun energy (default 1.0)."},
			"sun_rotation_degrees": host._str("Sun rotation as 'x,y,z' degrees (default '-45,-35,0')."),
			"sun_color": host._str("Sun colour (default white)."),
			"shadows": host._bool("Enable sun shadows.", true),
			"background": host._str("sky (default) | color | clear."),
			"background_color": host._str("Colour when background=color."),
			"sky_top_color": host._str("Zenith colour of the procedural sky."),
			"sky_horizon_color": host._str("Horizon colour of the procedural sky."),
			"ground_color": host._str("Ground colour of the procedural sky."),
			"ambient_energy": {"type": "number", "description": "Ambient light multiplier (default 1.0)."},
			"fog": host._bool("Enable depth fog.", false),
			"fog_density": {"type": "number", "description": "Fog density (default 0.01)."},
			"fog_color": host._str("Fog colour."),
			"tonemap": host._str("linear | reinhard | filmic | aces | agx (default filmic)."),
			"replace_existing": host._bool("Replace an existing light/environment instead of adding more.", false),
		}),
		func(args): return _tool_setup_environment(args), false, "3d")

	host._add("godot_get_import_settings",
		"Read the .import file of an asset (model, texture, audio...): importer, type and every import parameter, including retarget settings for 3D models.",
		host._obj({
			"resource_path": host._str("res:// path of the source asset, e.g. res://models/hero.glb."),
			"filter": host._str("Only keys containing this text (glob-ish, e.g. 'retarget')."),
			"section": host._str("params (default) | all."),
		}, ["resource_path"]),
		func(args): return _tool_get_import_settings(args), true, "import")

	host._add("godot_set_import_settings",
		"Change import parameters of an asset by editing its .import file (values are parsed as Godot literals: true, 1.5, [1,2], \"res://...\"). Optionally asks the editor to reimport immediately. Supports anything the importer knows, e.g. retarget/bone_map, retarget/rest_fixer, meshes/generate_lods, physics bodies.",
		host._obj({
			"resource_path": host._str("res:// path of the source asset."),
			"settings": {"type": "object", "description": "{import parameter: value}, e.g. {'retarget/bone_map': 'res://hero_bonemap.tres'}."},
			"section": host._str("params (default) | remap | deps."),
			"reimport": host._bool("Ask the editor to reimport the asset afterwards.", true),
		}, ["resource_path", "settings"]),
		func(args): return _tool_set_import_settings(args), false, "import")

	# These drive EditorInterface; the host turns them into a clean error when no
	# editor is running. Everything else works on files and stays available.
	var gate: Dictionary = host._editor_only
	for name in ["godot_set_material", "godot_add_physics_body", "godot_add_camera",
			"godot_setup_3d_environment"]:
		gate[name] = true


# ---------------------------------------------------------------------------
# scene / node helpers
# ---------------------------------------------------------------------------

## Opens `source` (a res:// scene or model) or falls back to the edited scene.
## Returns {ok, root, label, temp, error}; call _close_scene() when temp is true.
func _open_scene(source: String, need_editor: bool = false) -> Dictionary:
	var s := source.strip_edges()
	if s.is_empty():
		if not AIStudioEditorEnv.available():
			return {"ok": false, "root": null, "label": "", "temp": false,
				"error": "No 'source' given and no editor is running: pass a res:// scene or model path."}
		var edited: Node = EditorInterface.get_edited_scene_root()
		if edited == null:
			return {"ok": false, "root": null, "label": "", "temp": false,
				"error": "No scene is open in the editor; pass 'source' as a res:// path instead."}
		return {"ok": true, "root": edited, "label": "(edited scene) " + String(edited.name),
			"temp": false, "error": ""}
	var check: Dictionary = host._validate_project_path(s, false)
	if not bool(check["ok"]):
		return {"ok": false, "root": null, "label": s, "temp": false, "error": String(check["error"])}
	if not ResourceLoader.exists(s):
		return {"ok": false, "root": null, "label": s, "temp": false, "error": "Not found: " + s}
	var res = load(s)
	if res == null:
		return {"ok": false, "root": null, "label": s, "temp": false, "error": "Could not load " + s}
	if res is Node:
		return {"ok": true, "root": res, "label": s, "temp": true, "error": ""}
	if res is PackedScene:
		var instance: Node = (res as PackedScene).instantiate()
		if instance == null:
			return {"ok": false, "root": null, "label": s, "temp": false,
				"error": "Could not instantiate " + s}
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			var holder := Node.new()
			holder.name = "AIStudioToolHolder"
			(loop as SceneTree).root.add_child(holder)
			holder.add_child(instance)
			holder.set_meta("ai_studio_holder", true)
			instance.set_meta("ai_studio_holder_parent", holder)
		return {"ok": true, "root": instance, "label": s, "temp": true, "error": ""}
	return {"ok": false, "root": null, "label": s, "temp": false,
		"error": "%s loads as %s, not a scene or node." % [s, res.get_class()]}


func _close_scene(opened: Dictionary) -> void:
	if not bool(opened.get("temp", false)):
		return
	var root = opened.get("root", null)
	if root == null or not is_instance_valid(root) or not (root is Node):
		return
	var holder = root.get_meta("ai_studio_holder_parent", null)
	if holder != null and is_instance_valid(holder):
		(holder as Node).queue_free()
	else:
		root.queue_free()


func _node_in(root: Node, path: String) -> Node:
	var p := path.strip_edges()
	if p.is_empty() or p == "." or p == "/":
		return root
	if root == null:
		return null
	if p.begins_with(String(root.name) + "/"):
		p = p.substr(String(root.name).length() + 1)
	if p.begins_with("/"):
		p = p.substr(1)
	return root.get_node_or_null(NodePath(p))


func _find_first(node: Node, class_name_filter: String, exclude_root: bool = false) -> Node:
	if node == null:
		return null
	if not exclude_root and node.is_class(class_name_filter):
		return node
	for child in node.get_children():
		var found := _find_first(child, class_name_filter, false)
		if found != null:
			return found
	return null


func _collect(node: Node, class_name_filter: String, out: Array = []) -> Array:
	if node.is_class(class_name_filter):
		out.append(node)
	for child in node.get_children():
		_collect(child, class_name_filter, out)
	return out


func _node_path_from(root: Node, node: Node) -> String:
	if root == null or node == null or node == root:
		return "."
	return String(root.get_path_to(node))


func _skeletons_in(root: Node) -> Array:
	return _collect(root, "Skeleton3D")


func _skeleton_of(root: Node, path: String) -> Dictionary:
	if root == null:
		return {"ok": false, "node": null, "error": "No scene loaded."}
	if not path.strip_edges().is_empty():
		var node := _node_in(root, path)
		if node == null:
			return {"ok": false, "node": null, "error": "Node not found: " + path}
		if not (node is Skeleton3D):
			return {"ok": false, "node": null,
				"error": "%s is a %s, not a Skeleton3D." % [path, node.get_class()]}
		return {"ok": true, "node": node, "error": ""}
	var found := _find_first(root, "Skeleton3D")
	if found == null:
		var names: Array = []
		for child in _collect(root, "Node3D"):
			names.append("%s (%s)" % [_node_path_from(root, child), child.get_class()])
			if names.size() >= 25:
				break
		return {"ok": false, "node": null,
			"error": "No Skeleton3D found. Nodes available: " + (", ".join(names) if not names.is_empty() else "(none)")}
	return {"ok": true, "node": found, "error": ""}


# ---------------------------------------------------------------------------
# bone-name classification
# ---------------------------------------------------------------------------

## Splits a bone name into lowercase tokens: camelCase, digits and separators
## all become boundaries ("mixamorig:LeftUpLeg2" -> [mixamorig, left, up, leg, 2]).
static func _tokens(raw: String) -> PackedStringArray:
	var out := PackedStringArray()
	var current := ""
	var last := ""
	for i in raw.length():
		var c := raw.substr(i, 1)
		var lower := c.to_lower()
		var is_alpha := lower >= "a" and lower <= "z"
		var is_digit := c >= "0" and c <= "9"
		if not (is_alpha or is_digit):
			if not current.is_empty():
				out.append(current)
				current = ""
			last = ""
			continue
		if not current.is_empty():
			var prev_digit := last >= "0" and last <= "9"
			var cur_upper := c >= "A" and c <= "Z"
			if (is_digit and not prev_digit) or (cur_upper and not prev_digit):
				out.append(current)
				current = ""
		current += lower
		last = c
	if not current.is_empty():
		out.append(current)
	return out


static func _has_token(tokens: PackedStringArray, wanted: String) -> bool:
	for t in tokens:
		if t == wanted:
			return true
	return false


static func _is_digits(token: String) -> bool:
	if token.is_empty():
		return false
	for i in token.length():
		var c := token.substr(i, 1)
		if c < "0" or c > "9":
			return false
	return true


## "Left"/"right" from tokens: 'left', 'l' or a trailing '.l' style token.
static func _side_of(tokens: PackedStringArray) -> String:
	if _has_token(tokens, "left") or _has_token(tokens, "l"):
		return "L"
	if _has_token(tokens, "right") or _has_token(tokens, "r"):
		return "R"
	return ""


## Candidate compact forms of a bone name, most specific first.
static func _candidates(raw: String) -> PackedStringArray:
	var tokens := _tokens(raw)
	var kept := PackedStringArray()
	var nodigits := PackedStringArray()
	for t in tokens:
		if NOISE_WORDS.has(t) or SIDE_WORDS.has(t):
			continue
		kept.append(t)
		if not _is_digits(t):
			nodigits.append(t)
	var out := PackedStringArray()
	for parts in [kept, nodigits]:
		var compact := ""
		for p in parts:
			compact += str(int(p)) if _is_digits(p) else p
		if compact.is_empty():
			continue
		out.append(compact)
		var stripped := compact.trim_prefix("hand")
		if stripped != compact and not stripped.is_empty():
			out.append(stripped)
	return out


static var _profile_cache := PackedStringArray()


static func _profile_bone_names() -> PackedStringArray:
	if _profile_cache.is_empty():
		var profile := SkeletonProfileHumanoid.new()
		for i in profile.bone_size:
			_profile_cache.append(String(profile.get_bone_name(i)))
	return _profile_cache


## alias -> profile bone BASE name (no Left/Right prefix).
static func _alias_table(extra: Dictionary = {}) -> Dictionary:
	var table := {}
	for profile_bone in _profile_bone_names():
		var short := profile_bone
		if short.begins_with("Left") or short.begins_with("Right"):
			short = short.substr(4)
		table[short.to_lower()] = short
	for base in BONE_ALIASES.keys():
		for alias in BONE_ALIASES[base]:
			table[alias] = base
	for base in extra.keys():
		for alias in String(extra[base]).split(",", false):
			var key := String(alias).strip_edges().to_lower()
			if not key.is_empty():
				table[key] = String(base)
	return table


## Which SkeletonProfileHumanoid bone does this skeleton bone correspond to?
## Returns "" when nothing matches (or when a side is needed but unknown).
static func classify_bone(raw: String, table: Dictionary) -> String:
	var tokens := _tokens(raw)
	var side := _side_of(tokens)
	var names := _profile_bone_names()
	for candidate in _candidates(raw):
		if not table.has(candidate):
			continue
		var base := String(table[candidate])
		if names.has("Left" + base):
			if side.is_empty():
				continue
			return ("Left" if side == "L" else "Right") + base
		return base
	return ""


## Maps skeleton bone names onto profile bones.
## Returns {ok, mapping: {profile_bone: bone_name}, unmapped_bones: [..],
##          missing_required: [profile bones], error}
func _map_skeleton(skeleton: Skeleton3D, manual: Dictionary = {}, extra_aliases: Dictionary = {}) -> Dictionary:
	if skeleton == null:
		return {"ok": false, "mapping": {}, "unmapped_bones": [], "missing_required": [],
			"error": "No skeleton."}
	var profile := SkeletonProfileHumanoid.new()
	var table := _alias_table(extra_aliases)
	var mapping := {}
	var bones_by_profile := {}
	# A bone that already carries a profile name wins over a heuristic match.
	for i in skeleton.get_bone_count():
		var bone_name := String(skeleton.get_bone_name(i))
		var profile_bone := classify_bone(bone_name, table)
		if profile_bone.is_empty():
			continue
		var exact := bone_name.to_lower() == profile_bone.to_lower()
		if not mapping.has(profile_bone) or exact:
			mapping[profile_bone] = bone_name
			bones_by_profile[profile_bone] = i
	for profile_bone in manual.keys():
		var target := String(manual[profile_bone]).strip_edges()
		if target.is_empty():
			mapping.erase(String(profile_bone))
			continue
		if skeleton.find_bone(target) < 0:
			return {"ok": false, "mapping": mapping, "unmapped_bones": [], "missing_required": [],
				"error": "manual mapping points at a bone that does not exist: %s" % target}
		mapping[String(profile_bone)] = target
	var unmapped_bones := PackedStringArray()
	for i in skeleton.get_bone_count():
		var bone_name := String(skeleton.get_bone_name(i))
		var used := false
		for profile_bone in mapping.keys():
			if String(mapping[profile_bone]) == bone_name:
				used = true
				break
		if not used:
			unmapped_bones.append(bone_name)
	var missing_required := PackedStringArray()
	for i in profile.bone_size:
		var profile_bone := String(profile.get_bone_name(i))
		if bool(profile.is_required(i)) and not mapping.has(profile_bone):
			missing_required.append(profile_bone)
	return {"ok": true, "mapping": mapping, "profile": profile, "unmapped_bones": unmapped_bones,
		"missing_required": missing_required, "error": ""}


# ---------------------------------------------------------------------------
# skeletons / bone maps
# ---------------------------------------------------------------------------

func _tool_list_bones(args: Dictionary) -> Dictionary:
	var opened := _open_scene(String(args.get("source", "")))
	if not bool(opened["ok"]):
		return host._err(String(opened["error"]))
	var root: Node = opened["root"]
	var found := _skeleton_of(root, String(args.get("skeleton_node", "")))
	if not bool(found["ok"]):
		_close_scene(opened)
		return host._err(String(found["error"]))
	var skeleton: Skeleton3D = found["node"]
	var include_rest := bool(args.get("include_rest", true))
	var classify := bool(args.get("classify", false))
	var table := _alias_table() if classify else {}

	var lines := PackedStringArray()
	lines.append("Skeleton: %s -> %s (%d bones)" % [opened["label"],
		_path_label(root, skeleton), skeleton.get_bone_count()])
	var classified := 0
	for i in skeleton.get_bone_count():
		var name := String(skeleton.get_bone_name(i))
		var parent := skeleton.get_bone_parent(i)
		var parent_name := String(skeleton.get_bone_name(parent)) if parent >= 0 else "-"
		var line := "%3d | %-28s | parent: %-24s" % [i, name, parent_name]
		if include_rest:
			var rest := skeleton.get_bone_rest(i)
			var euler := rest.basis.get_euler()
			line += " | rest pos %s rot %s" % [_vec(rest.origin),
				_vec(Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z)))]
		if classify:
			var profile_bone := classify_bone(name, table)
			if not profile_bone.is_empty():
				classified += 1
			line += " | humanoid: %s" % (profile_bone if not profile_bone.is_empty() else "-")
		lines.append(line)
	if classify:
		lines.append("Humanoid match: %d of %d bones (SkeletonProfileHumanoid)" % [
			classified, skeleton.get_bone_count()])
	_close_scene(opened)
	return host._ok("\n".join(lines))


func _tool_create_bone_map(args: Dictionary) -> Dictionary:
	var output_path := String(args.get("output_path", "")).strip_edges()
	var check: Dictionary = host._validate_project_path(output_path, true)
	if not bool(check["ok"]):
		return host._err(String(check["error"]))
	if output_path.get_extension().to_lower() != "tres":
		return host._err("output_path should end in .tres (a BoneMap is a text resource).")

	var opened := _open_scene(String(args.get("source", "")))
	if not bool(opened["ok"]):
		return host._err(String(opened["error"]))
	var root: Node = opened["root"]
	var found := _skeleton_of(root, String(args.get("skeleton_node", "")))
	if not bool(found["ok"]):
		_close_scene(opened)
		return host._err(String(found["error"]))
	var skeleton: Skeleton3D = found["node"]

	var profile: SkeletonProfile = SkeletonProfileHumanoid.new()
	var profile_arg := String(args.get("profile", "humanoid")).strip_edges()
	if not profile_arg.is_empty() and profile_arg != "humanoid":
		var pcheck: Dictionary = host._validate_project_path(profile_arg, false)
		if not bool(pcheck["ok"]):
			_close_scene(opened)
			return host._err(String(pcheck["error"]))
		var loaded = load(profile_arg)
		if loaded is SkeletonProfile:
			profile = loaded
		else:
			_close_scene(opened)
			return host._err("%s is not a SkeletonProfile resource." % profile_arg)

	var manual: Dictionary = args.get("manual", {}) if typeof(args.get("manual", {})) == TYPE_DICTIONARY else {}
	var extra: Dictionary = args.get("extra_aliases", {}) if typeof(args.get("extra_aliases", {})) == TYPE_DICTIONARY else {}
	var mapped := _map_skeleton(skeleton, manual, extra)
	if not bool(mapped["ok"]):
		_close_scene(opened)
		return host._err(String(mapped["error"]))

	var mapping: Dictionary = mapped["mapping"]
	var bone_map := BoneMap.new()
	bone_map.profile = profile
	for profile_bone in mapping.keys():
		bone_map.set_skeleton_bone_name(StringName(profile_bone), StringName(String(mapping[profile_bone])))

	var existed := FileAccess.file_exists(output_path)
	if existed:
		var original := FileAccess.get_file_as_string(output_path)
		var bf := FileAccess.open(output_path + ".bak", FileAccess.WRITE)
		if bf != null:
			bf.store_string(original)
			bf = null
	var err := ResourceSaver.save(bone_map, output_path)
	if err != OK:
		_close_scene(opened)
		return host._err("Could not save the BoneMap: %s" % error_string(err))

	var lines := PackedStringArray()
	lines.append("BoneMap for %s -> %s saved to %s" % [opened["label"],
		_path_label(root, skeleton), output_path])
	lines.append("Profile: %s (%d bones, %d mapped, %d required missing)" % [
		profile.get_class(), profile.bone_size, mapping.size(),
		(mapped["missing_required"] as PackedStringArray).size()])
	var ordered: Array = mapping.keys()
	ordered.sort()
	for profile_bone in ordered:
		lines.append("  %-24s <- %s" % [profile_bone, mapping[profile_bone]])
	if not (mapped["missing_required"] as PackedStringArray).is_empty():
		lines.append("Missing REQUIRED profile bones (animations that use them will not retarget): " +
			", ".join(mapped["missing_required"]))
	if not (mapped["unmapped_bones"] as PackedStringArray).is_empty():
		lines.append("Skeleton bones without a profile bone (%d): %s" % [
			(mapped["unmapped_bones"] as PackedStringArray).size(),
			", ".join((mapped["unmapped_bones"] as PackedStringArray).slice(0, 30))])
	lines.append("Tip: fix anything wrong with 'manual' ({ProfileBone: skeleton bone}) and re-run; " +
		"the file is always rewritten from scratch.")

	var import_note := ""
	if bool(args.get("write_import", false)):
		import_note = _apply_bone_map_to_import(String(args.get("source", "")), output_path,
			bool(args.get("rest_fixer", true)))
		if not import_note.is_empty():
			lines.append(import_note)
	_close_scene(opened)
	return host._ok("\n".join(lines))


## Writes retarget/bone_map (+ rest_fixer) into <model>.import when the source is
## an imported asset; returns a note for the tool output.
func _apply_bone_map_to_import(source: String, bone_map_path: String, rest_fixer: bool) -> String:
	var src := source.strip_edges()
	if src.is_empty():
		return "write_import: skipped, the skeleton came from the edited scene (set the bone map on the import manually, or pass a model path as 'source')."
	if src.begins_with("res://") and src.get_extension().to_lower() in ["tscn", "scn"]:
		return "write_import: skipped, %s is a Godot scene, not an imported model." % src
	var import_path := src + ".import"
	if not FileAccess.file_exists(import_path):
		return "write_import: no %s found - is the asset imported?" % import_path
	var applied := _write_import_keys(import_path, {
		"retarget/bone_map": bone_map_path,
		"retarget/rest_fixer": rest_fixer,
	})
	if not bool(applied["ok"]):
		return "write_import failed: " + String(applied["error"])
	if AIStudioEditorEnv.available():
		EditorInterface.get_resource_filesystem().update_file(src)
		return "Wrote retarget/bone_map (+rest_fixer) to %s and asked the editor to reimport %s." % [import_path, src]
	return "Wrote retarget/bone_map (+rest_fixer) to %s (reimport it in the editor)." % import_path


func _write_import_keys(import_path: String, settings: Dictionary) -> Dictionary:
	var cf := ConfigFile.new()
	var err := cf.load(import_path)
	if err != OK:
		return {"ok": false, "error": "could not parse %s (%s)" % [import_path, error_string(err)]}
	var bak := FileAccess.open(import_path + ".bak", FileAccess.WRITE)
	if bak != null:
		bak.store_string(FileAccess.get_file_as_string(import_path))
		bak = null
	for key in settings.keys():
		cf.set_value("params", String(key), settings[key])
	err = cf.save(import_path)
	if err != OK:
		return {"ok": false, "error": "could not write %s (%s)" % [import_path, error_string(err)]}
	return {"ok": true, "error": ""}


# ---------------------------------------------------------------------------
# animations
# ---------------------------------------------------------------------------

## Gathers animations from a player, an AnimationLibrary or a single Animation.
## Returns {ok, source_label, entries: [{player_label, library, name, animation}], error}
func _animations(args: Dictionary) -> Dictionary:
	var source := String(args.get("source", "")).strip_edges()
	var wanted_player := String(args.get("node_path", "")).strip_edges()
	var opened := _open_scene(source)
	if not bool(opened["ok"]):
		return {"ok": false, "entries": [], "error": String(opened["error"]), "opened": opened}
	var root = opened["root"]
	var entries: Array = []
	var scene_root: Node = root if root is Node else null
	if root is AnimationMixer:
		_gather_player(root, opened["label"], entries)
	elif root is AnimationLibrary:
		_gather_library(root, opened["label"], entries)
	elif root is Animation:
		entries.append({"player_label": opened["label"], "library": "", "name": "(resource)",
			"animation": root})
	elif scene_root != null:
		var players := _collect(scene_root, "AnimationPlayer")
		if not players.is_empty():
			for p in players:
				if not wanted_player.is_empty() and _node_path_from(scene_root, p) != wanted_player:
					continue
				_gather_player(p as AnimationMixer, "%s -> %s" % [opened["label"], _node_path_from(scene_root, p)], entries)
		else:
			var mixers := _collect(scene_root, "AnimationMixer")
			for m in mixers:
				_gather_player(m as AnimationMixer, "%s -> %s" % [opened["label"], _node_path_from(scene_root, m)], entries)
	if entries.is_empty():
		_close_scene(opened)
		var hint := "AnimationPlayer" if not wanted_player.is_empty() else "AnimationPlayer, AnimationLibrary or Animation resource"
		return {"ok": false, "entries": [], "error": "No animations found in %s (looked for %s)." % [opened["label"], hint],
			"opened": opened}
	return {"ok": true, "entries": entries, "error": "", "opened": opened, "root": scene_root}


func _gather_player(mixer: AnimationMixer, label: String, out: Array) -> void:
	for library_name in mixer.get_animation_library_list():
		var lib: AnimationLibrary = mixer.get_animation_library(library_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			out.append({"player_label": label, "library": String(library_name),
				"name": String(anim_name), "animation": lib.get_animation(anim_name)})


func _gather_library(lib: AnimationLibrary, label: String, out: Array) -> void:
	for anim_name in lib.get_animation_list():
		out.append({"player_label": label, "library": "(resource)",
			"name": String(anim_name), "animation": lib.get_animation(anim_name)})


static func _track_type_name(animation: Animation, track: int) -> String:
	var t := animation.track_get_type(track)
	if t >= 0 and t < TRACK_TYPE_NAMES.size():
		return TRACK_TYPE_NAMES[t]
	return "type_%d" % t


func _animation_find(entries: Array, name: String) -> Animation:
	for entry in entries:
		if String(entry["name"]) == name:
			return entry["animation"]
	return null


func _tool_animation_info(args: Dictionary) -> Dictionary:
	var got := _animations(args)
	if not bool(got["ok"]):
		return host._err(String(got["error"]))
	var entries: Array = got["entries"]
	var lines := PackedStringArray()
	var by_player := {}
	for entry in entries:
		by_player[String(entry["player_label"])] = true
	lines.append("Source: %s" % String((got["opened"] as Dictionary)["label"]))
	lines.append("%d animation(s) in %d mixer(s)" % [entries.size(), by_player.size()])
	var current_player := ""
	for entry in entries:
		var player := String(entry["player_label"])
		if player != current_player:
			current_player = player
			lines.append("%s  (library: %s)" % [player, String(entry["library"])])
		var animation: Animation = entry["animation"]
		var types := {}
		var keys := 0
		for t in animation.get_track_count():
			var type_name := _track_type_name(animation, t)
			types[type_name] = int(types.get(type_name, 0)) + 1
			keys += animation.track_get_key_count(t)
		var parts := PackedStringArray()
		for type_name in types.keys():
			parts.append("%s %d" % [type_name, types[type_name]])
		lines.append("  - %-32s %.2fs loop=%-9s tracks=%d (%s) keys=%d" % [
			String(entry["name"]), animation.length,
			LOOP_NAMES[animation.loop_mode] if animation.loop_mode < LOOP_NAMES.size() else str(animation.loop_mode),
			animation.get_track_count(), ", ".join(parts), keys])
	_close_scene(got["opened"])
	return host._ok("\n".join(lines))


func _tool_animation_tracks(args: Dictionary) -> Dictionary:
	var animation_name := String(args.get("animation", "")).strip_edges()
	if animation_name.is_empty():
		return host._err("'animation' is required (see godot_animation_info for the names).")
	var got := _animations(args)
	if not bool(got["ok"]):
		return host._err(String(got["error"]))
	var animation := _animation_find(got["entries"], animation_name)
	var root: Node = got["root"]
	if animation == null:
		var names := PackedStringArray()
		for entry in got["entries"]:
			names.append(String(entry["name"]))
		_close_scene(got["opened"])
		return host._err("Animation '%s' not found. Available: %s" % [animation_name, ", ".join(names)])

	if bool(args.get("names_only", false)):
		var paths := PackedStringArray()
		for t in animation.get_track_count():
			paths.append(str(animation.track_get_path(t)))
		_close_scene(got["opened"])
		return host._ok("\n".join(paths))

	var lines := PackedStringArray()
	lines.append("Animation '%s': %.2fs, %d tracks, loop=%s" % [animation_name, animation.length,
		animation.get_track_count(),
		LOOP_NAMES[animation.loop_mode] if animation.loop_mode < LOOP_NAMES.size() else str(animation.loop_mode)])
	for t in animation.get_track_count():
		var path := animation.track_get_path(t)
		lines.append(" [%2d] %-11s %-44s keys=%-4d interp=%s" % [t, _track_type_name(animation, t),
			str(path), animation.track_get_key_count(t),
			INTERP_NAMES[animation.track_get_interpolation_type(t)]])
		if animation.track_get_type(t) == Animation.TYPE_VALUE and animation.track_get_key_count(t) > 0:
			lines.append("        first value: %s" % var_to_str(animation.track_get_key_value(t, 0)).substr(0, 120))

	# Path diagnostics: which nodes/bones the tracks expect.
	var check_source := String(args.get("check_against", "")).strip_edges()
	if check_source.is_empty():
		check_source = String(args.get("source", "")).strip_edges()
	var message := _check_track_paths(animation, root, check_source)
	if not message.is_empty():
		lines.append("")
		lines.append(message)
	_close_scene(got["opened"])
	return host._ok("\n".join(lines))


## Cross-checks the node and bone names used by an animation against a scene.
func _check_track_paths(animation: Animation, animated_root: Node, check_source: String) -> String:
	var target_root: Node = null
	var opened := {}
	if check_source.is_empty():
		target_root = animated_root
	else:
		opened = _open_scene(check_source)
		if not bool(opened["ok"]):
			return "Path check skipped: " + String(opened["error"])
		target_root = opened["root"]
	if target_root == null or not (target_root is Node):
		return "Path check skipped: pass 'check_against' (or use a scene as 'source') so the track paths can be resolved."
	var seen := {}
	var lines := PackedStringArray()
	lines.append("Path check against %s:" % (check_source if not check_source.is_empty() else "(same scene)"))
	var missing := 0
	var checked := 0
	for t in animation.get_track_count():
		var path: NodePath = animation.track_get_path(t)
		var key := str(path)
		if seen.has(key):
			continue
		seen[key] = true
		checked += 1
		var text := key
		var subpath := ""
		var node_part := text
		var colon := text.find(":")
		if colon >= 0:
			node_part = text.substr(0, colon)
			subpath = text.substr(colon + 1)
		if node_part.is_empty():
			node_part = "."
		var host_node := target_root.get_node_or_null(NodePath(node_part))
		if host_node == null:
			lines.append("  MISS  %s  (node '%s' does not exist here)" % [key, node_part])
			missing += 1
			continue
		if subpath.is_empty():
			lines.append("  ok    %s" % key)
			continue
		var head := subpath
		if head.contains(":"):
			head = head.substr(0, head.find(":"))
		if head in host_node:
			# A plain property track on the node itself (e.g. "Sun:light_energy").
			lines.append("  ok    %s  (property exists on %s)" % [key, node_part])
			continue
		if host_node is Skeleton3D:
			var skeleton: Skeleton3D = host_node
			if skeleton.find_bone(head) >= 0:
				lines.append("  ok    %s  (bone exists on %s)" % [key, node_part])
			else:
				lines.append("  MISS  %s  (bone '%s' is not on %s - rename the track or the bone)" % [
					key, head, node_part])
				missing += 1
			continue
		lines.append("  WARN  %s  (node exists but has no '%s' - property or bone name changed?)" % [key, subpath])
	if missing > 0:
		lines.append("Result: %d of %d unique track targets are missing. Use godot_retarget_animation to rewrite them." % [missing, checked])
	else:
		lines.append("Result: all %d track targets resolve." % checked)
	if not opened.is_empty():
		_close_scene(opened)
	return "\n".join(lines)


func _tool_retarget_animation(args: Dictionary) -> Dictionary:
	var animation_name := String(args.get("animation", "")).strip_edges()
	var animation: Animation = null
	var entries: Array = []
	var opened := {}
	var source_label := ""

	var animation_path := String(args.get("animation_path", "")).strip_edges()
	if not animation_path.is_empty():
		var check: Dictionary = host._validate_project_path(animation_path, false)
		if not bool(check["ok"]):
			return host._err(String(check["error"]))
		if not ResourceLoader.exists(animation_path):
			return host._err("Not found: " + animation_path)
		var res = load(animation_path)
		if res is Animation:
			animation = res
			source_label = animation_path
			if animation_name.is_empty():
				animation_name = animation.resource_name if not animation.resource_name.is_empty() else animation_path.get_file().get_basename()
		elif res is AnimationLibrary:
			_gather_library(res, animation_path, entries)
			source_label = animation_path
		else:
			return host._err("%s is a %s, not an Animation or AnimationLibrary." % [animation_path, res.get_class() if res != null else "null"])
	else:
		var lookup := args.duplicate()
		if not animation_name.is_empty():
			lookup["animation"] = animation_name
		var got := _animations(lookup)
		if not bool(got["ok"]):
			return host._err(String(got["error"]))
		entries = got["entries"]
		opened = got["opened"]
		source_label = String((got["opened"] as Dictionary)["label"])

	if animation == null:
		if animation_name.is_empty() and entries.size() == 1:
			animation_name = String(entries[0]["name"])
		for entry in entries:
			if String(entry["name"]) == animation_name:
				animation = entry["animation"]
				break
	if animation == null:
		var names := PackedStringArray()
		for entry in entries:
			names.append(String(entry["name"]))
		if not opened.is_empty():
			_close_scene(opened)
		return host._err("Animation '%s' not found in %s. Available: %s" % [animation_name, source_label,
			", ".join(names) if not names.is_empty() else "(none)"])

	var from_prefix := String(args.get("from_prefix", "")).strip_edges()
	var to_prefix := String(args.get("to_prefix", "")).strip_edges()
	var extra_aliases: Dictionary = args.get("extra_aliases", {}) if typeof(args.get("extra_aliases", {})) == TYPE_DICTIONARY else {}

	# Bone translation: explicit BoneMap, or the target skeleton's own bone names.
	var map_profile_to_bone := {}      # profile bone -> target bone
	var map_note := ""
	var bone_map_path := String(args.get("bone_map_path", "")).strip_edges()
	if not bone_map_path.is_empty():
		var check: Dictionary = host._validate_project_path(bone_map_path, false)
		if not bool(check["ok"]):
			if not opened.is_empty():
				_close_scene(opened)
			return host._err(String(check["error"]))
		var bm = load(bone_map_path)
		if bm is not BoneMap:
			if not opened.is_empty():
				_close_scene(opened)
			return host._err("%s is not a BoneMap." % bone_map_path)
		var bone_map: BoneMap = bm
		var profile: SkeletonProfile = bone_map.profile
		if profile == null:
			if not opened.is_empty():
				_close_scene(opened)
			return host._err("The BoneMap has no profile set.")
		for i in profile.bone_size:
			var profile_bone := String(profile.get_bone_name(i))
			var target := String(bone_map.get_skeleton_bone_name(StringName(profile_bone)))
			if not target.is_empty():
				map_profile_to_bone[profile_bone] = target
		map_note = "verified against %s (%d bones)" % [bone_map_path, map_profile_to_bone.size()]
	var target_source := String(args.get("target_source", "")).strip_edges()
	if map_profile_to_bone.is_empty() and not target_source.is_empty():
		var target_opened := _open_scene(target_source)
		if not bool(target_opened["ok"]):
			if not opened.is_empty():
				_close_scene(opened)
			return host._err(String(target_opened["error"]))
		var target_found := _skeleton_of(target_opened["root"], String(args.get("target_skeleton", "")))
		if not bool(target_found["ok"]):
			_close_scene(target_opened)
			if not opened.is_empty():
				_close_scene(opened)
			return host._err(String(target_found["error"]))
		var target_skeleton: Skeleton3D = target_found["node"]
		var mapped := _map_skeleton(target_skeleton, {}, extra_aliases)
		map_profile_to_bone = mapped["mapping"]
		map_note = "matched to %s (%d bones)" % [target_source, map_profile_to_bone.size()]
		_close_scene(target_opened)
	if not opened.is_empty():
		_close_scene(opened)

	var table := _alias_table(extra_aliases)
	var result := animation.duplicate(true) as Animation
	result.resource_name = animation_name
	var changes := PackedStringArray()
	var prefix_swaps := 0
	var bone_remaps := 0
	var unmatched := PackedStringArray()
	for t in result.get_track_count():
		var path: NodePath = result.track_get_path(t)
		var text := str(path)
		var new_text := text
		if not from_prefix.is_empty():
			if new_text == from_prefix:
				new_text = to_prefix
				prefix_swaps += 1
			elif new_text.begins_with(from_prefix + "/") or new_text.begins_with(from_prefix + ":"):
				# The animation writes "Skeleton3D:Hips:position", so both the
				# child separator and the property separator count.
				new_text = to_prefix + new_text.substr(from_prefix.length())
				prefix_swaps += 1
		var node_part := new_text
		var subpath := ""
		var colon := new_text.find(":")
		if colon >= 0:
			node_part = new_text.substr(0, colon)
			subpath = new_text.substr(colon + 1)
		if not subpath.is_empty() and not map_profile_to_bone.is_empty():
			var property := ""
			var bone := subpath
			var inner := subpath.find(":")
			if inner >= 0:
				bone = subpath.substr(0, inner)
				property = subpath.substr(inner)
			var profile_bone := classify_bone(bone, table)
			if not profile_bone.is_empty() and map_profile_to_bone.has(profile_bone):
				var target_bone := String(map_profile_to_bone[profile_bone])
				if target_bone != bone:
					subpath = target_bone + property
					bone_remaps += 1
			elif not profile_bone.is_empty():
				unmatched.append("%s (%s)" % [bone, profile_bone])
			else:
				unmatched.append(bone)
		if not subpath.is_empty():
			new_text = node_part + ":" + subpath
		if new_text != text:
			result.track_set_path(t, NodePath(new_text))
			changes.append("  %-42s -> %s" % [text, new_text])

	var lines := PackedStringArray()
	lines.append("Retargeted '%s' from %s" % [animation_name, source_label])
	if not map_note.is_empty():
		lines.append("Bone translation: " + map_note)
	lines.append("Tracks: %d scanned, %d rewritten (%d prefix swaps, %d bone renames)" % [
		result.get_track_count(), changes.size(), prefix_swaps, bone_remaps])
	for change in changes:
		lines.append(change)
	if not unmatched.is_empty():
		lines.append("Bones left untouched because they have no target (%d): %s" % [
			unmatched.size(), ", ".join(unmatched.slice(0, 30))])

	if bool(args.get("dry_run", false)):
		lines.append("dry_run: no file written.")
		return host._ok("\n".join(lines))

	var output_path := String(args.get("output_path", "")).strip_edges()
	if output_path.is_empty():
		var base := animation_name.to_lower().replace(" ", "_")
		output_path = "res://%s_retargeted.tres" % base
	var check2: Dictionary = host._validate_project_path(output_path, true)
	if not bool(check2["ok"]):
		return host._err(String(check2["error"]))
	if FileAccess.file_exists(output_path):
		var original := FileAccess.get_file_as_string(output_path)
		var bf := FileAccess.open(output_path + ".bak", FileAccess.WRITE)
		if bf != null:
			bf.store_string(original)
			bf = null
	var err := ResourceSaver.save(result, output_path)
	if err != OK:
		return host._err("Could not save %s (%s)" % [output_path, error_string(err)])
	if AIStudioEditorEnv.available():
		EditorInterface.get_resource_filesystem().update_file(output_path)
	lines.append("Saved %s" % output_path)
	lines.append("To use it: add it to an AnimationPlayer's library (AnimationPlayer -> Animation -> Library -> Add Animation) or pass it to a script with load(\"%s\")." % output_path)
	return host._ok("\n".join(lines))


# ---------------------------------------------------------------------------
# meshes and materials
# ---------------------------------------------------------------------------

func _tool_mesh_info(args: Dictionary) -> Dictionary:
	var mesh_path := String(args.get("mesh_path", "")).strip_edges()
	var mesh: Mesh = null
	var origin := ""
	if not mesh_path.is_empty():
		var check: Dictionary = host._validate_project_path(mesh_path, false)
		if not bool(check["ok"]):
			return host._err(String(check["error"]))
		if not ResourceLoader.exists(mesh_path):
			return host._err("Not found: " + mesh_path)
		var res = load(mesh_path)
		if res is Mesh:
			mesh = res
			origin = mesh_path
		elif res is PackedScene:
			var opened := _open_scene(mesh_path)
			if not bool(opened["ok"]):
				return host._err(String(opened["error"]))
			var inst := _find_first(opened["root"], "MeshInstance3D")
			if inst == null:
				_close_scene(opened)
				return host._err("No MeshInstance3D inside " + mesh_path)
			mesh = (inst as MeshInstance3D).mesh
			origin = "%s -> %s" % [mesh_path, _node_path_from(opened["root"], inst)]
			_close_scene(opened)
		else:
			return host._err("%s is a %s, not a Mesh." % [mesh_path, res.get_class() if res != null else "null"])
	else:
		var opened2 := _open_scene(String(args.get("source", "")))
		if not bool(opened2["ok"]):
			return host._err(String(opened2["error"]))
		var node := _node_in(opened2["root"], String(args.get("node_path", "")))
		if node == null:
			_close_scene(opened2)
			return host._err("Node not found: " + String(args.get("node_path", "")))
		if node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
		elif node is CSGShape3D or node.is_class("GeometryInstance3D"):
			var gi: GeometryInstance3D = node
			var prop = gi.get("mesh")
			if prop is Mesh:
				mesh = prop
		origin = "%s -> %s" % [String(opened2["label"]), _node_path_from(opened2["root"], node)]
		if mesh == null:
			var lines0 := PackedStringArray()
			lines0.append("%s has no mesh (class %s)." % [_node_path_from(opened2["root"], node), node.get_class()])
			if node is MeshInstance3D:
				lines0.append("Set a mesh or use godot_mesh_info with mesh_path.")
			if node is Skeleton3D:
				lines0.append("This is a skeleton; use godot_list_bones instead.")
			_close_scene(opened2)
			return host._ok("\n".join(lines0))
		var detail := _describe_mesh_instance(node as Node, mesh, int(args.get("surface_limit", 8)), opened2["root"])
		_close_scene(opened2)
		return host._ok(detail)

	var lines := PackedStringArray()
	lines.append("Mesh: %s (%s)" % [origin, mesh.get_class()])
	var aabb := mesh.get_aabb()
	lines.append("Boundaries: size %s, centre %s (min %s, max %s)" % [
		_vec(aabb.size), _vec(aabb.get_center()), _vec(aabb.position), _vec(aabb.end)])
	lines.append("Surfaces (%d):" % mesh.get_surface_count())
	var limit := maxi(int(args.get("surface_limit", 8)), 1)
	for s in mesh.get_surface_count():
		if s >= limit:
			lines.append("  ... %d more surfaces" % (mesh.get_surface_count() - limit))
			break
		var arrays := mesh.surface_get_arrays(s)
		var vertices: Variant = arrays[Mesh.ARRAY_VERTEX] if arrays.size() > Mesh.ARRAY_VERTEX else null
		var indices: Variant = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX else null
		var vert_count := (vertices as PackedVector3Array).size() if vertices != null else 0
		var tri_count := 0
		if indices != null:
			tri_count = int((indices as PackedInt32Array).size() / 3.0)
		elif vert_count > 0:
			tri_count = int(vert_count / 3.0)
		var material := mesh.surface_get_material(s)
		lines.append("  [%d] %d verts, %d triangles, format=%s, material=%s" % [s, vert_count, tri_count,
			_mesh_format_name(mesh.surface_get_format(s) if mesh.has_method("surface_get_format") else 0),
			(material.resource_path if material != null and not material.resource_path.is_empty() else
				(material.get_class() if material != null else "none"))])
	if mesh is ArrayMesh:
		var am: ArrayMesh = mesh
		lines.append("Blend shapes (%d): %s" % [am.get_blend_shape_count(),
			", ".join(PackedStringArray(_blend_shape_names(am))) if am.get_blend_shape_count() > 0 else "none"])
		if am.get_blend_shape_mode() != Mesh.BLEND_SHAPE_MODE_NORMALIZED:
			lines.append("Blend shape mode: %d" % am.get_blend_shape_mode())
	return host._ok("\n".join(lines))


func _describe_mesh_instance(node: Node, mesh: Mesh, surface_limit: int, scene_root: Node) -> String:
	var lines := PackedStringArray()
	lines.append("Node: %s (%s)" % [node.name, node.get_class()])
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		var skeleton := mi.get_node_or_null(mi.skeleton)
		lines.append("Mesh: %s (%d surfaces)" % [mesh.get_class(), mesh.get_surface_count()])
		var aabb := mi.get_aabb()
		lines.append("Bounds: size %s, centre %s" % [_vec(aabb.size), _vec(aabb.get_center())])
		for s in mini(mesh.get_surface_count(), surface_limit):
			var override := mi.get_surface_override_material(s)
			var material := override if override != null else mesh.surface_get_material(s)
			lines.append("  [%d] material=%s%s" % [s,
				(material.resource_path if material != null and not material.resource_path.is_empty() else (material.get_class() if material != null else "none")),
				" (override)" if override != null else ""])
		if mesh is ArrayMesh:
			var am: ArrayMesh = mesh
			lines.append("Blend shapes (%d): %s" % [am.get_blend_shape_count(),
				", ".join(PackedStringArray(_blend_shape_names(am))) if am.get_blend_shape_count() > 0 else "none"])
			var shaped := PackedStringArray()
			for b in am.get_blend_shape_count():
				var value := mi.get_blend_shape_value(b)
				if absf(value) > 0.001:
					shaped.append("%s=%.2f" % [am.get_blend_shape_name(b), value])
			if not shaped.is_empty():
				lines.append("  driving: " + ", ".join(shaped))
		if mi.skin != null:
			lines.append("Skin: %s" % (mi.skin.resource_path if not mi.skin.resource_path.is_empty() else mi.skin.get_class()))
		if skeleton is Skeleton3D:
			lines.append("Skeleton: %s (%d bones) - use godot_list_bones for the bone list" % [
				_node_path_from(scene_root, skeleton), (skeleton as Skeleton3D).get_bone_count()])
		elif mi.skeleton != NodePath():
			lines.append("Skeleton path (unresolved): %s" % str(mi.skeleton))
	else:
		lines.append("Mesh: %s (%d surfaces)" % [mesh.get_class(), mesh.get_surface_count()])
	return "\n".join(lines)


static func _blend_shape_names(mesh: ArrayMesh) -> PackedStringArray:
	var out := PackedStringArray()
	for i in mesh.get_blend_shape_count():
		out.append(String(mesh.get_blend_shape_name(i)))
	return out


static func _mesh_format_name(flags: int) -> String:
	var parts := PackedStringArray()
	if flags & Mesh.ARRAY_FORMAT_NORMAL:
		parts.append("normal")
	if flags & Mesh.ARRAY_FORMAT_TANGENT:
		parts.append("tangent")
	if flags & Mesh.ARRAY_FORMAT_TEX_UV:
		parts.append("uv")
	if flags & Mesh.ARRAY_FORMAT_TEX_UV2:
		parts.append("uv2")
	if flags & Mesh.ARRAY_FORMAT_COLOR:
		parts.append("color")
	if flags & Mesh.ARRAY_FORMAT_BONES:
		parts.append("bones")
	if flags & Mesh.ARRAY_FORMAT_WEIGHTS:
		parts.append("weights")
	if flags & Mesh.ARRAY_FORMAT_INDEX:
		parts.append("indexed")
	return ", ".join(parts) if not parts.is_empty() else "vertices only"


func _tool_create_material(args: Dictionary) -> Dictionary:
	var output_path := String(args.get("output_path", "")).strip_edges()
	var check: Dictionary = host._validate_project_path(output_path, true)
	if not bool(check["ok"]):
		return host._err(String(check["error"]))
	if not output_path.get_extension().to_lower() in ["tres", "res"]:
		return host._err("output_path should end in .tres or .res.")

	var material := StandardMaterial3D.new()
	var notes := PackedStringArray()
	if args.has("albedo_color"):
		var colour: Variant = _parse_color(String(args["albedo_color"]))
		if colour == null:
			return host._err("Could not parse albedo_color '%s'." % args["albedo_color"])
		material.albedo_color = colour
	if args.has("metallic"):
		material.metallic = clampf(float(args["metallic"]), 0.0, 1.0)
	if args.has("roughness"):
		material.roughness = clampf(float(args["roughness"]), 0.0, 1.0)
	if args.has("emission_color"):
		var emission: Variant = _parse_color(String(args["emission_color"]))
		if emission == null:
			return host._err("Could not parse emission_color.")
		material.emission_enabled = true
		material.emission = emission
		if args.has("emission_energy"):
			material.emission_energy_multiplier = float(args["emission_energy"])
	if args.has("transparency"):
		var mode := String(args["transparency"]).to_lower()
		match mode:
			"disabled":
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			"alpha":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			"alpha_scissor", "scissor":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			"alpha_hash":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			"depth_prepass", "alpha_depth_prepass":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			_:
				return host._err("Unknown transparency '%s'." % mode)
		notes.append("transparency=" + mode)
	if args.has("cull_mode"):
		var cull := String(args["cull_mode"]).to_lower()
		match cull:
			"back":
				material.cull_mode = BaseMaterial3D.CULL_BACK
			"front":
				material.cull_mode = BaseMaterial3D.CULL_FRONT
			"disabled", "two_sided", "double":
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_:
				return host._err("Unknown cull_mode '%s'." % cull)
	if args.has("shading_mode"):
		var shading := String(args["shading_mode"]).to_lower()
		match shading:
			"unshaded":
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			"per_pixel", "per_pixel_lighting":
				material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			"per_vertex":
				material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			_:
				return host._err("Unknown shading_mode '%s'." % shading)
	if args.has("vertex_color_use_as_albedo"):
		material.vertex_color_use_as_albedo = bool(args["vertex_color_use_as_albedo"])
	if args.has("uv1_scale"):
		var scale: Variant = _parse_vec(String(args["uv1_scale"]), Vector3.ONE)
		if scale == null:
			return host._err("Could not parse uv1_scale.")
		material.uv1_scale = scale

	var textures: Dictionary = {}
	if args.has("albedo_texture"):
		textures["albedo_texture"] = String(args["albedo_texture"])
	if args.has("normal_texture"):
		textures["normal_texture"] = String(args["normal_texture"])
	var extra_textures: Dictionary = args.get("textures", {}) if typeof(args.get("textures", {})) == TYPE_DICTIONARY else {}
	for key in extra_textures.keys():
		textures[String(key)] = String(extra_textures[key])
	for key in textures.keys():
		var tex_path := String(textures[key]).strip_edges()
		if tex_path.is_empty():
			continue
		var tcheck: Dictionary = host._validate_project_path(tex_path, false)
		if not bool(tcheck["ok"]):
			return host._err("Texture '%s': %s" % [tex_path, tcheck["error"]])
		if not ResourceLoader.exists(tex_path):
			return host._err("Texture not found: " + tex_path)
		if not (key in material):
			return host._err("StandardMaterial3D has no property '%s'." % key)
		material.set(key, load(tex_path))
		notes.append(key + "=" + tex_path)

	var existed := FileAccess.file_exists(output_path)
	if existed:
		var original := FileAccess.get_file_as_string(output_path)
		var bf := FileAccess.open(output_path + ".bak", FileAccess.WRITE)
		if bf != null:
			bf.store_string(original)
			bf = null
	var err := ResourceSaver.save(material, output_path)
	if err != OK:
		return host._err("Could not save the material (%s)" % error_string(err))
	if AIStudioEditorEnv.available():
		EditorInterface.get_resource_filesystem().update_file(output_path)
	var lines := PackedStringArray()
	lines.append("Saved StandardMaterial3D to %s%s" % [output_path, " (previous file kept as .bak)" if existed else ""])
	lines.append("albedo=%s metallic=%.2f roughness=%.2f emission=%s cull=%d shading=%d" % [
		material.albedo_color, material.metallic, material.roughness,
		str(material.emission_enabled), material.cull_mode, material.shading_mode])
	if not notes.is_empty():
		lines.append("Set: " + ", ".join(notes))
	lines.append("Assign it with godot_set_material (node_path, material_path).")
	return host._ok("\n".join(lines))


func _tool_set_material(args: Dictionary) -> Dictionary:
	var node_path := String(args.get("node_path", "")).strip_edges()
	var material_path := String(args.get("material_path", "")).strip_edges()
	if node_path.is_empty() or material_path.is_empty():
		return host._err("node_path and material_path are required.")
	var check: Dictionary = host._validate_project_path(material_path, false)
	if not bool(check["ok"]):
		return host._err(String(check["error"]))
	if not ResourceLoader.exists(material_path):
		return host._err("Material not found: " + material_path)
	var material = load(material_path)
	if not (material is Material):
		return host._err("%s is a %s, not a Material." % [material_path, material.get_class()])
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		return host._err("No scene is open in the editor.")
	var node := _node_in(root, node_path)
	if node == null:
		return host._err("Node not found: " + node_path)
	if not (node is MeshInstance3D):
		return host._err("%s is a %s; materials can only be assigned to MeshInstance3D." % [node_path, node.get_class()])
	var mi: MeshInstance3D = node
	var surface := int(args.get("surface", -1))
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("AI Studio: assign material")
	var assigned := PackedStringArray()
	if surface < 0:
		var count := mi.get_surface_override_material_count()
		if count == 0 and mi.mesh != null:
			count = mi.mesh.get_surface_count()
		for s in count:
			ur.add_do_method(mi, "set_surface_override_material", s, material)
			ur.add_undo_method(mi, "set_surface_override_material", s, mi.get_surface_override_material(s))
			assigned.append(str(s))
	else:
		ur.add_do_method(mi, "set_surface_override_material", surface, material)
		ur.add_undo_method(mi, "set_surface_override_material", surface, mi.get_surface_override_material(surface))
		assigned.append(str(surface))
	ur.commit_action()
	return host._ok("Assigned %s to surfaces [%s] of %s." % [material_path, ", ".join(assigned), node_path])


# ---------------------------------------------------------------------------
# physics, camera, lighting
# ---------------------------------------------------------------------------

func _add_with_undo(root: Node, parent: Node, node: Node, action: String) -> void:
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action(action)
	ur.add_do_method(parent, "add_child", node)
	ur.add_do_method(node, "set_owner", root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()


func _tool_add_physics_body(args: Dictionary) -> Dictionary:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		return host._err("No scene is open in the editor.")
	var parent := _node_in(root, String(args.get("parent_path", "")))
	if parent == null:
		return host._err("Parent node not found: " + String(args.get("parent_path", "")).strip_edges())
	if not (parent is Node3D):
		return host._err("Physics bodies need a Node3D parent (%s is %s)." % [parent.name, parent.get_class()])

	var body_type := String(args.get("body_type", "character")).to_lower()
	var body: CollisionObject3D = null
	var class_name_used := ""
	match body_type:
		"static", "staticbody", "staticbody3d":
			body = StaticBody3D.new()
			class_name_used = "StaticBody3D"
		"rigid", "rigidbody", "rigidbody3d":
			body = RigidBody3D.new()
			class_name_used = "RigidBody3D"
		"area", "area3d":
			body = Area3D.new()
			class_name_used = "Area3D"
		"character", "characterbody", "characterbody3d", "kinematic":
			body = CharacterBody3D.new()
			class_name_used = "CharacterBody3D"
		_:
			return host._err("Unknown body_type '%s' (static|rigid|area|character)." % body_type)
	var name := String(args.get("name", "")).strip_edges()
	body.name = name if not name.is_empty() else class_name_used
	if body is RigidBody3D and args.has("mass"):
		(body as RigidBody3D).mass = float(args["mass"])
	if args.has("collision_layer"):
		body.collision_layer = int(args["collision_layer"])
	if args.has("collision_mask"):
		body.collision_mask = int(args["collision_mask"])
	if body is CharacterBody3D and args.has("floor_snap_length"):
		(body as CharacterBody3D).floor_snap_length = float(args["floor_snap_length"])

	var shape_kind := String(args.get("shape", "box")).to_lower()
	var shape_note := "no collision shape requested"
	var shape: Shape3D = null
	var fit: MeshInstance3D = null
	if shape_kind != "none":
		var fit_path := String(args.get("fit_to", "")).strip_edges()
		if not fit_path.is_empty():
			var node := _node_in(root, fit_path)
			if node == null:
				return host._err("fit_to node not found: " + fit_path)
			if not (node is MeshInstance3D):
				return host._err("fit_to must be a MeshInstance3D (%s is %s)." % [fit_path, node.get_class()])
			fit = node
		else:
			fit = _find_first(parent, "MeshInstance3D") as MeshInstance3D
		var aabb := AABB()
		if fit != null and fit.mesh != null:
			aabb = fit.mesh.get_aabb()
			aabb = AABB(aabb.position * fit.scale.abs(), aabb.size * fit.scale.abs())
		var size: Vector3 = aabb.size
		if args.has("size"):
			var parsed: Variant = _parse_vec(String(args["size"]), Vector3.ONE)
			if parsed == null:
				return host._err("Could not parse size.")
			size = parsed
		elif size == Vector3.ZERO:
			size = Vector3(1, 1, 1)
		match shape_kind:
			"box":
				var box := BoxShape3D.new()
				box.size = size
				shape = box
				shape_note = "box %s" % _vec(size)
			"sphere":
				var sphere := SphereShape3D.new()
				sphere.radius = float(args["radius"]) if args.has("radius") else maxf(maxf(size.x, size.y), size.z) * 0.5
				shape = sphere
				shape_note = "sphere r=%.3f" % sphere.radius
			"capsule":
				var capsule := CapsuleShape3D.new()
				capsule.radius = float(args["radius"]) if args.has("radius") else maxf(size.x, size.z) * 0.5
				capsule.height = float(args["height"]) if args.has("height") else maxf(size.y, capsule.radius * 2.0)
				shape = capsule
				shape_note = "capsule r=%.3f h=%.3f" % [capsule.radius, capsule.height]
			"cylinder":
				var cylinder := CylinderShape3D.new()
				cylinder.radius = float(args["radius"]) if args.has("radius") else maxf(size.x, size.z) * 0.5
				cylinder.height = float(args["height"]) if args.has("height") else maxf(size.y, cylinder.radius * 2.0)
				shape = cylinder
				shape_note = "cylinder r=%.3f h=%.3f" % [cylinder.radius, cylinder.height]
			"trimesh", "convex":
				if fit == null or fit.mesh == null:
					return host._err("'%s' shapes need a mesh: set fit_to to a MeshInstance3D with a mesh." % shape_kind)
				shape = fit.mesh.create_trimesh_shape() if shape_kind == "trimesh" else fit.mesh.create_convex_shape()
				if shape == null:
					return host._err("Could not build a %s shape from %s (is the mesh in the right format?)." % [shape_kind, fit.name])
				shape_note = "%s from %s" % [shape_kind, _node_path_from(root, fit)]
			_:
				return host._err("Unknown shape '%s' (box|sphere|capsule|cylinder|trimesh|convex|none)." % shape_kind)

	var added := [body]
	_add_with_undo(root, parent, body, "AI Studio: add " + class_name_used)
	if shape != null:
		var collider := CollisionShape3D.new()
		collider.name = "CollisionShape3D"
		collider.shape = shape
		if args.has("offset"):
			var offset: Variant = _parse_vec(String(args["offset"]), Vector3.ZERO)
			if offset == null:
				return host._err("Could not parse offset.")
			collider.position = offset
		_add_with_undo(root, body, collider, "AI Studio: add collision shape")
		added.append(collider)
	EditorInterface.edit_node(body)
	var lines := PackedStringArray()
	lines.append("Added %s '%s' under %s" % [class_name_used, body.name, _node_path_from(root, parent)])
	lines.append("Collision: " + shape_note)
	if fit != null:
		lines.append("Fitted to mesh: %s (bounds size %s)" % [_node_path_from(root, fit), _vec((fit as MeshInstance3D).mesh.get_aabb().size)])
	lines.append("Layer %d / mask %d%s" % [body.collision_layer, body.collision_mask,
		", mass %.2f" % (body as RigidBody3D).mass if body is RigidBody3D else ""])
	lines.append("Nodes touched: " + ", ".join(PackedStringArray(added.map(func(n): return _node_path_from(root, n)))))
	return host._ok("\n".join(lines))


func _tool_add_camera(args: Dictionary) -> Dictionary:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		return host._err("No scene is open in the editor.")
	var parent := _node_in(root, String(args.get("parent_path", "")))
	if parent == null:
		return host._err("Parent node not found.")
	if not (parent is Node3D):
		return host._err("Cameras need a Node3D parent (%s is %s)." % [parent.name, parent.get_class()])
	var camera := Camera3D.new()
	var name := String(args.get("name", "")).strip_edges()
	camera.name = name if not name.is_empty() else "Camera3D"
	if args.has("position"):
		var pos: Variant = _parse_vec(String(args["position"]), Vector3.ZERO)
		if pos == null:
			return host._err("Could not parse position.")
		camera.position = pos
	if args.has("fov"):
		camera.fov = float(args["fov"])
	camera.current = bool(args.get("current", true))
	_add_with_undo(root, parent, camera, "AI Studio: add Camera3D")
	var aim_note := "not aimed"
	var look := String(args.get("look_at", "")).strip_edges()
	if not look.is_empty():
		var target: Vector3 = Vector3.INF
		var node := _node_in(root, look)
		if node != null and node is Node3D:
			target = (node as Node3D).global_position
		else:
			var parsed: Variant = _parse_vec(look, Vector3.ZERO)
			if parsed != null:
				target = parsed
		if target != Vector3.INF:
			var in_tree := camera.is_inside_tree()
			if in_tree:
				camera.look_at(target, Vector3.UP)
			else:
				camera.look_at_from_position(camera.position, target, Vector3.UP)
			aim_note = "looking at %s -> rotation %.1f,%.1f,%.1f" % [look,
				rad_to_deg(camera.rotation.x), rad_to_deg(camera.rotation.y), rad_to_deg(camera.rotation.z)]
	EditorInterface.edit_node(camera)
	return host._ok("Added Camera3D '%s' under %s at %s (%s, fov %.1f, current=%s).\n%s" % [
		camera.name, _node_path_from(root, parent), _vec(camera.position), aim_note, camera.fov,
		str(camera.current), "Use godot_capture_screenshot with view '3d' to check the framing."])


func _tool_setup_environment(args: Dictionary) -> Dictionary:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		return host._err("No scene is open in the editor.")
	var parent := _node_in(root, String(args.get("parent_path", "")))
	if parent == null:
		return host._err("Parent node not found.")
	if not (parent is Node3D):
		return host._err("Lights and environments need a Node3D parent.")
	var replace := bool(args.get("replace_existing", false))
	var lines := PackedStringArray()

	var light: DirectionalLight3D = _find_first(parent, "DirectionalLight3D") as DirectionalLight3D
	if light != null and replace:
		light.light_energy = float(args.get("sun_energy", 1.0))
		light.shadow_enabled = bool(args.get("shadows", true))
		lines.append("Reused existing DirectionalLight3D %s" % _node_path_from(root, light))
	else:
		var created_light := DirectionalLight3D.new()
		created_light.name = "Sun"
		created_light.light_energy = float(args.get("sun_energy", 1.0))
		created_light.shadow_enabled = bool(args.get("shadows", true))
		if args.has("sun_color"):
			var sun_colour: Variant = _parse_color(String(args["sun_color"]))
			if sun_colour == null:
				return host._err("Could not parse sun_color.")
			created_light.light_color = sun_colour
		_add_with_undo(root, parent, created_light, "AI Studio: add sun")
		light = created_light
		lines.append("Added DirectionalLight3D 'Sun' under %s" % _node_path_from(root, parent))
	var rotation_text := String(args.get("sun_rotation_degrees", "-45,-35,0"))
	var degrees: Variant = _parse_vec(rotation_text, Vector3(-45, -35, 0))
	if degrees == null:
		return host._err("Could not parse sun_rotation_degrees.")
	light.rotation_degrees = degrees
	lines.append("Sun: energy %.2f, shadows=%s, rotation %s" % [light.light_energy, str(light.shadow_enabled), _vec(degrees)])

	var environment := Environment.new()
	var background := String(args.get("background", "sky")).to_lower()
	match background:
		"sky":
			var sky := Sky.new()
			var sky_material := ProceduralSkyMaterial.new()
			if args.has("sky_top_color"):
				var c: Variant = _parse_color(String(args["sky_top_color"]))
				if c == null:
					return host._err("Could not parse sky_top_color.")
				sky_material.sky_top_color = c
			if args.has("sky_horizon_color"):
				var c2: Variant = _parse_color(String(args["sky_horizon_color"]))
				if c2 == null:
					return host._err("Could not parse sky_horizon_color.")
				sky_material.sky_horizon_color = c2
			if args.has("ground_color"):
				var c3: Variant = _parse_color(String(args["ground_color"]))
				if c3 == null:
					return host._err("Could not parse ground_color.")
				sky_material.ground_bottom_color = c3
			sky.sky_material = sky_material
			environment.sky = sky
			environment.background_mode = Environment.BG_SKY
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			lines.append("Background: procedural sky")
		"color":
			environment.background_mode = Environment.BG_COLOR
			var bg: Variant = _parse_color(String(args.get("background_color", "#101828")))
			if bg == null:
				return host._err("Could not parse background_color.")
			environment.background_color = bg
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			lines.append("Background: colour %s" % bg)
		"clear":
			environment.background_mode = Environment.BG_CLEAR_COLOR
			environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			lines.append("Background: clear")
		_:
			return host._err("Unknown background '%s' (sky|color|clear)." % background)
	if args.has("ambient_energy"):
		environment.ambient_light_energy = float(args["ambient_energy"])
	if bool(args.get("fog", false)):
		environment.fog_enabled = true
		environment.fog_density = float(args.get("fog_density", 0.01))
		if args.has("fog_color"):
			var fog_colour: Variant = _parse_color(String(args["fog_color"]))
			if fog_colour == null:
				return host._err("Could not parse fog_color.")
			environment.fog_light_color = fog_colour
		lines.append("Fog: density %.4f" % environment.fog_density)
	var tonemap := String(args.get("tonemap", "filmic")).to_lower()
	match tonemap:
		"linear":
			environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		"reinhard":
			environment.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
		"filmic":
			environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		"aces":
			environment.tonemap_mode = Environment.TONE_MAPPER_ACES
		"agx":
			environment.tonemap_mode = Environment.TONE_MAPPER_AGX
		_:
			return host._err("Unknown tonemap '%s' (linear|reinhard|filmic|aces|agx)." % tonemap)

	var world: WorldEnvironment = _find_first(parent, "WorldEnvironment") as WorldEnvironment
	if world != null and replace:
		world.environment = environment
		lines.append("Replaced the Environment on %s" % _node_path_from(root, world))
	else:
		var created_world := WorldEnvironment.new()
		created_world.name = "WorldEnvironment"
		created_world.environment = environment
		_add_with_undo(root, parent, created_world, "AI Studio: add WorldEnvironment")
		world = created_world
		lines.append("Added WorldEnvironment under %s" % _node_path_from(root, parent))
	lines.append("Tonemap: " + tonemap)
	if _find_first(parent, "Camera3D") == null:
		lines.append("No Camera3D in the scene yet - add one with godot_add_camera so the setup is visible.")
	EditorInterface.edit_node(world)
	return host._ok("\n".join(lines))


# ---------------------------------------------------------------------------
# import settings
# ---------------------------------------------------------------------------

func _import_path_for(resource_path: String) -> Dictionary:
	var p := resource_path.strip_edges()
	var check: Dictionary = host._validate_project_path(p, false)
	if not bool(check["ok"]):
		return {"ok": false, "error": String(check["error"])}
	if not FileAccess.file_exists(p):
		return {"ok": false, "error": "Not found in the project: " + p}
	var import_path := p + ".import"
	if not FileAccess.file_exists(import_path):
		return {"ok": false, "error": "%s has no .import file (not imported by the editor?)." % p}
	return {"ok": true, "import_path": import_path, "error": ""}


func _tool_get_import_settings(args: Dictionary) -> Dictionary:
	var resource_path := String(args.get("resource_path", ""))
	var found := _import_path_for(resource_path)
	if not bool(found["ok"]):
		return host._err(String(found["error"]))
	var cf := ConfigFile.new()
	var err := cf.load(String(found["import_path"]))
	if err != OK:
		return host._err("Could not parse %s (%s)" % [found["import_path"], error_string(err)])
	var filter := String(args.get("filter", "")).strip_edges().to_lower()
	var section := String(args.get("section", "params")).strip_edges().to_lower()
	var lines := PackedStringArray()
	lines.append("Import settings for %s (%s)" % [resource_path, found["import_path"]])
	var sections := ["remap", "params", "deps"] if section == "all" else [section]
	for sec in sections:
		if not cf.has_section(sec):
			continue
		lines.append("[%s]" % sec)
		var keys := cf.get_section_keys(sec)
		for key in keys:
			var key_text := String(key)
			if not filter.is_empty() and not key_text.to_lower().contains(filter):
				continue
			lines.append("  %-46s = %s" % [key_text, var_to_str(cf.get_value(sec, key))])
	if not filter.is_empty():
		lines.append("(filtered by '%s')" % filter)
	return host._ok("\n".join(lines))


func _tool_set_import_settings(args: Dictionary) -> Dictionary:
	var resource_path := String(args.get("resource_path", ""))
	var found := _import_path_for(resource_path)
	if not bool(found["ok"]):
		return host._err(String(found["error"]))
	var settings: Dictionary = args.get("settings", {}) if typeof(args.get("settings", {})) == TYPE_DICTIONARY else {}
	if settings.is_empty():
		return host._err("'settings' is required: {key: value}.")
	for key in settings.keys():
		if String(key).begins_with("dest_files") or String(key) == "importer":
			return host._err("'%s' is managed by the editor and cannot be set." % key)
	var section := String(args.get("section", "params")).strip_edges()
	if section.is_empty():
		section = "params"
	if not ["params", "remap", "deps"].has(section):
		return host._err("section must be params, remap or deps.")
	var cf := ConfigFile.new()
	var err := cf.load(String(found["import_path"]))
	if err != OK:
		return host._err("Could not parse %s (%s)" % [found["import_path"], error_string(err)])
	var bak := FileAccess.open(String(found["import_path"]) + ".bak", FileAccess.WRITE)
	if bak != null:
		bak.store_string(FileAccess.get_file_as_string(String(found["import_path"])))
		bak = null
	var lines := PackedStringArray()
	lines.append("Updated %s" % found["import_path"])
	for key in settings.keys():
		var key_text := String(key)
		var value: Variant = _coerce_import_value(settings[key])
		var before: Variant = cf.get_value(section, key_text) if cf.has_section_key(section, key_text) else null
		cf.set_value(section, key_text, value)
		lines.append("  %s: %s -> %s" % [key_text, var_to_str(before), var_to_str(value)])
	err = cf.save(String(found["import_path"]))
	if err != OK:
		return host._err("Could not write %s (%s)" % [found["import_path"], error_string(err)])
	if bool(args.get("reimport", true)) and AIStudioEditorEnv.available():
		EditorInterface.get_resource_filesystem().update_file(resource_path)
		lines.append("Asked the editor to reimport %s (it may take a moment)." % resource_path)
	elif bool(args.get("reimport", true)):
		lines.append("No editor running: the asset is reimported next time the project is opened.")
	return host._ok("\n".join(lines))


## Import values arrive as strings from the model; turn them into real values.
static func _coerce_import_value(value: Variant) -> Variant:
	if typeof(value) != TYPE_STRING:
		return value
	var text := String(value).strip_edges()
	if text.is_empty():
		return ""
	var parsed = str_to_var(text)
	if parsed == null and not text.begins_with("null"):
		var bools := {"true": true, "false": false, "yes": true, "no": false, "on": true, "off": false}
		if bools.has(text.to_lower()):
			return bools[text.to_lower()]
		return text
	return parsed


# ---------------------------------------------------------------------------
# small parsing helpers
# ---------------------------------------------------------------------------

static func _vec(v: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z]


static func _parse_vec(text: String, fallback: Vector3) -> Variant:
	var parts := _numbers(text)
	if parts.size() >= 3:
		return Vector3(parts[0], parts[1], parts[2])
	if parts.size() == 2:
		# Two components: a plane (UV scale) - keep the third axis neutral.
		return Vector3(parts[0], parts[1], 1.0)
	if parts.size() == 1:
		return fallback * parts[0]
	return null


static func _parse_color(text: String) -> Variant:
	var t := text.strip_edges()
	if t.is_empty():
		return null
	if t.begins_with("#"):
		return Color.from_string(t, Color.WHITE)
	if t.begins_with("Color("):
		var parsed = str_to_var(t)
		if parsed is Color:
			return parsed
		return null
	var parts := _numbers(t)
	if parts.size() == 3:
		return Color(parts[0], parts[1], parts[2])
	if parts.size() == 4:
		return Color(parts[0], parts[1], parts[2], parts[3])
	if Color.html_is_valid(t):
		return Color.from_string(t, Color.WHITE)
	return null


static func _numbers(text: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var current := ""
	for i in text.length():
		var c := text.substr(i, 1)
		var numeric := (c >= "0" and c <= "9") or c == "-" or c == "+" or c == "." or c == "e" or c == "E"
		if numeric:
			current += c
		else:
			if not current.is_empty() and current.is_valid_float():
				out.append(current.to_float())
			current = ""
	if not current.is_empty() and current.is_valid_float():
		out.append(current.to_float())
	return out


func _path_label(root: Node, node: Node) -> String:
	var path := _node_path_from(root, node)
	return path if not path.is_empty() else "."
