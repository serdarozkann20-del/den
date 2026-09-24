@tool
class_name AIStudioAnimNameRules
extends RefCounted

## Animation-name rewriting shared by godot_animation_rename and the
## post-import scripts written by godot_import_animation_names. The block
## between the BEGIN/END markers is copied verbatim into those generated
## scripts, so the preview and the reimport always agree: keep it
## self-contained (no references to anything outside the block).

# BEGIN RULES
## Returns the new name for `anim_name`. An exact entry in `renames` wins
## (keys may be "anim" or "library/anim" when `library` is given); otherwise
## `cleanup` runs first ("strip_prefix" drops everything up to the last "|",
## e.g. "Armature|Run" -> "Run"; "snake_case" also lowercases and joins words
## with "_", e.g. "Armature|Run Fast" -> "run_fast"), then the regex
## `pattern` is replaced by `replacement` ($1 style groups allowed).
static func compute(anim_name: String, renames: Dictionary, pattern: String, replacement: String,
		cleanup: String, library: String = "") -> String:
	var full := anim_name if library.is_empty() else library + "/" + anim_name
	if renames.has(full):
		return String(renames[full])
	if renames.has(anim_name):
		return String(renames[anim_name])
	var n := anim_name
	if cleanup == "strip_prefix" or cleanup == "snake_case":
		var bar := n.rfind("|")
		if bar >= 0 and bar < n.length() - 1:
			n = n.substr(bar + 1)
		n = n.strip_edges()
	if cleanup == "snake_case":
		n = n.to_snake_case().to_lower()
		var junk := RegEx.create_from_string("[^a-z0-9_]+")
		n = junk.sub(n, "_", true)
		var runs := RegEx.create_from_string("_{2,}")
		n = runs.sub(n, "_", true)
		n = n.trim_prefix("_").trim_suffix("_")
	if not pattern.is_empty():
		var re := RegEx.create_from_string(pattern)
		if re.is_valid():
			n = re.sub(n, replacement, true)
	return n


## Godot rejects these characters in animation and library names.
static func is_valid_name(anim_name: String) -> bool:
	if anim_name.is_empty():
		return false
	for bad in ["/", ":", ",", "["]:
		if anim_name.contains(bad):
			return false
	return true
# END RULES


## Source text of the shared block, for generated scripts.
static func rules_source() -> String:
	var own := (AIStudioAnimNameRules as Script).resource_path
	var text := FileAccess.get_file_as_string(own)
	var start := text.find("# BEGIN RULES")
	var stop := text.find("# END RULES")
	if start < 0 or stop < 0:
		return ""
	return text.substr(start, stop - start + "# END RULES".length())
