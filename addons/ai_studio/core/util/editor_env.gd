@tool
class_name AIStudioEditorEnv
extends RefCounted

## Is the editor actually there?
##
## The addon scripts are @tool scripts, so inside the editor `Engine.is_editor_hint()`
## is true and the EditorInterface singleton can be used. When the same classes
## are exercised outside an editor session (headless test runs, `--script`
## execution, or a game build that accidentally includes the addon) the
## singleton resolves to a stub without any editor methods, so everything that
## touches the editor has to be guarded.

static var _checked := false
static var _available := false


static func available() -> bool:
	if not _checked:
		_checked = true
		_available = Engine.is_editor_hint() and Engine.has_singleton("EditorInterface") \
			and Engine.get_singleton("EditorInterface") != null \
			and Engine.get_singleton("EditorInterface").has_method("get_current_path")
	return _available


## EditorInterface when usable, otherwise null (never the stub).
static func interface() -> Object:
	return Engine.get_singleton("EditorInterface") if available() else null
