@tool
class_name AIStudioEditorContext
extends RefCounted

## Builds the "what is going on in the editor right now" block that is attached
## to every request. Kept compact on purpose: the model only needs enough to
## make good tool calls, and tool calls fetch the details on demand.

const MAX_CHARS := 12000


static func build(config: AIStudioConfig) -> String:
	var lines := PackedStringArray()
	lines.append("## Godot editor context")
	lines.append("- Engine: Godot %s" % Engine.get_version_info().get("string", "?"))
	if not AIStudioEditorEnv.available():
		lines.append("- (editor state unavailable: this code path only runs inside the Godot editor)")
		return "\n".join(lines)
	lines.append("- Project: %s (%s)" % [
		String(ProjectSettings.get_setting("application/config/name", "(unnamed)")),
		ProjectSettings.globalize_path("res://")])
	lines.append("- Main scene: %s" % String(ProjectSettings.get_setting("application/run/main_scene", "(none)")))
	lines.append("- Edited scene: %s" % (EditorInterface.get_current_path() if EditorInterface.get_current_path() != "" else "(none open)"))
	lines.append("- Game running: %s" % ("yes" if EditorInterface.is_playing_scene() else "no"))

	if bool(config.get_value("general", "include_scene_context", true)):
		var root := EditorInterface.get_edited_scene_root()
		if root != null:
			var tree_lines := PackedStringArray()
			_walk(root, 0, 6, tree_lines)
			lines.append("\n### Current scene tree (%s)" % EditorInterface.get_current_path())
			lines.append("```")
			lines.append_array(tree_lines)
			lines.append("```")

	if bool(config.get_value("general", "include_selection", true)):
		var selected: Array = EditorInterface.get_selection().get_selected_nodes()
		if not selected.is_empty():
			var sel := PackedStringArray()
			for n in selected:
				if n is Node:
					sel.append("- %s (%s)%s" % [n.name, n.get_class(),
						" script: %s" % n.get_script().resource_path if n.get_script() != null else ""])
			lines.append("\n### Selected nodes")
			lines.append_array(sel)

	var script_editor := EditorInterface.get_script_editor()
	if script_editor != null:
		var current: Script = script_editor.get_current_script()
		if current != null and current.resource_path != "":
			lines.append("\n### Script open in the script editor: %s" % current.resource_path)

	if bool(config.get_value("general", "include_project_settings", false)):
		var max_lines := int(config.get_value("ui", "max_context_lines", 400))
		lines.append("\n### Project settings (truncated)")
		var count := 0
		for p in ProjectSettings.get_property_list():
			var name := String(p["name"])
			if not (name.begins_with("application/") or name.begins_with("display/") or name.begins_with("input/")):
				continue
			lines.append("- %s = %s" % [name, var_to_str(ProjectSettings.get_setting(name))])
			count += 1
			if count >= max_lines:
				lines.append("- ... [truncated]")
				break

	var text := "\n".join(lines)
	if text.length() > MAX_CHARS:
		text = text.substr(0, MAX_CHARS) + "\n... [context truncated]"
	return text


static func default_system_prompt() -> String:
	return """You are AI Studio, an assistant embedded in the Godot %s editor.

You help with the exact project that is open. Prefer using the provided tools to inspect the real project instead of guessing: read the actual scripts and scenes before proposing or making changes.

Rules:
- The tool `godot_class_reference` is authoritative for the running engine version. Check it before using an API you are not certain about; do not invent methods, properties, enums or signals.
- Make the smallest change that solves the task, then use read tools to verify the result.
- Prefer editing existing files over creating new ones; keep the project's existing style and structure.
- Mutating tools require user approval, so explain what you are about to do in one short sentence first.
- Use GDScript 4 syntax (typed where natural, tabs for indentation, `@tool` when editor-time behaviour is wanted, `@export`, signal connections via `signal.connect(callable)`).
- When you change a scene, describe the node paths you touched so the user can review it in the editor.
- The currently edited scene: use godot_add_node / godot_set_node_property (undo aware). Other scene files: use godot_scene_* tools. After writing scripts run godot_validate_scripts.
- Animation names: godot_animation_rename (scenes/libraries/SpriteFrames, updates references), godot_import_animation_names for .glb/.fbx models (names there are restored on reimport), godot_animation_edit to fix track paths/bones/loop/speed. After script or scene changes check godot_editor_log. godot_run_editor_script is the last resort for anything else.
- To test the game: godot_game_bridge action=enable (once per project), godot_play_scene, then the game_* tools (game_get_scene_tree, game_screenshot, game_click, game_get_errors ...; game_commands lists the rest, game_command runs them).
- Be concise: short answers, code in fenced blocks. No filler.""" % Engine.get_version_info().get("string", "4.x")


static func _walk(node: Node, depth: int, max_depth: int, out: PackedStringArray) -> void:
	if depth > max_depth:
		return
	var line := "%s%s (%s)" % ["  ".repeat(depth), node.name, node.get_class()]
	var script: Script = node.get_script()
	if script != null:
		line += " [script: %s]" % script.resource_path
	if node.scene_file_path != "" and depth > 0:
		line += " [instance: %s]" % node.scene_file_path
	out.append(line)
	for child in node.get_children():
		_walk(child, depth + 1, max_depth, out)
