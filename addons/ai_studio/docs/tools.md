# Built-in tools

AI Studio gives the model its own Godot tools, and MCP servers can add more. The tools run
inside the editor process. Tools that only read do not ask for approval. Tools that change
something ask first, unless you switched approval off. You can also run any tool yourself from
the **Tools** section of the dock.

Some of these tools are ports of [godot-mcp](https://github.com/tugcantopaloglu/godot-mcp)
(MIT, see `runtime/LICENSE.godot-mcp.txt`). They need no Node.js server and no extra headless
Godot processes, and they share the editor's safety rules:

* paths stay inside `res://`, and `..` is rejected;
* the model cannot edit the plugin's own files or disable the plugin;
* deleted files go to the system trash;
* a scene file that is open with unsaved changes is never overwritten.

## Editor: current scene

`godot_scene_tree`, `godot_get_node`, `godot_get_selection`, `godot_editor_state`,
`godot_add_node`, `godot_rename_node`, `godot_remove_node`, `godot_set_node_property`,
`godot_instantiate_scene`, `godot_attach_script`, `godot_open_scene`, `godot_save_scenes`,
`godot_play_scene`, `godot_stop_playing`, `godot_capture_screenshot`.

These tools work on the scene open in the editor and support undo.

## Scene files on disk (godot-mcp)

| Tool | What it does |
|---|---|
| `godot_read_scene` | Node tree, properties, signal connections and instanced scenes of a `.tscn` |
| `godot_create_scene` | New scene with a chosen root type (optionally a script) |
| `godot_scene_add_node` | Add a node, or instance a scene, under any parent, with properties |
| `godot_scene_modify_node` | Set properties (`Vector2(1, 2)`, `Color(...)`, `res://` paths, JSON) |
| `godot_scene_remove_node` | Remove a node and its children |
| `godot_scene_restructure` | Rename, move (reparent), duplicate or reorder nodes |
| `godot_scene_signals` | List, add or remove signal connections (checks signal and method) |
| `godot_save_scene_as` | Save a copy or variant of a scene |
| `godot_export_mesh_library` | Build a `MeshLibrary` from a scene of `MeshInstance3D` nodes |

If the scene is open in the editor, it is reloaded after the edit.

## Resources, scripts and files (godot-mcp)

`godot_create_resource`, `godot_read_resource`, `godot_modify_resource` (materials, themes,
curves, gradients, any `Resource` type); `godot_get_uid`, `godot_update_uids`;
`godot_create_script` (GDScript or C# templates); `godot_create_shader`;
`godot_validate_scripts` (compiles scripts and reports errors with line numbers);
`godot_manage_files` (copy, move, delete to trash, make directories).

## Project configuration (godot-mcp)

`godot_set_project_setting`, `godot_set_main_scene`, `godot_manage_autoloads`,
`godot_manage_input_map` (keys, mouse buttons, joypad buttons and axes),
`godot_manage_layers` (physics, render and navigation layer names),
`godot_manage_plugins`, `godot_manage_translations`, `godot_manage_export_presets`,
`godot_export_project` (runs a headless export and reports the size),
`godot_manage_ci` (GitHub Actions workflow, Dockerfile).

## Animation names and animation fixes

Animation names often arrive broken: `mixamo.com`, `Armature|Take 001`,
`CharacterArmature|Run`. These tools fix them.

| Tool | What it does |
|---|---|
| `godot_animation_rename` | Renames animations or library keys in AnimationPlayer/AnimationTree, AnimationLibrary `.tres` files or SpriteFrames (AnimatedSprite2D/3D). |
| `godot_animation_find_references` | Finds where names are used and can rewrite those uses. |
| `godot_animation_edit` | Fixes existing animations in place: track paths, bone names, broken tracks, loop mode, length and speed, copy or move to another library. |
| `godot_import_animation_names` | Fixes names that come from `.glb`/`.fbx` models. |

**godot_animation_rename**

* Takes exact renames, automatic clean-up (`strip_prefix`: `Armature|Run` → `Run`;
  `snake_case`: `Armature|Run Fast` → `run_fast`) or a regex.
* Rejects invalid names (`/ : , [`) and names that clash with existing ones.
* By default it also updates:
  * `autoplay` and the assigned animation;
  * the AnimationTree nodes (state machines, blend trees, blend spaces);
  * the AnimatedSprite `animation` and `autoplay` properties;
  * across the project, `play("old")`-style uses in scripts and the `animation = "old"` properties
    in other scenes and resources.
* If another scene or resource still defines the old name itself, uses in that file and in
  scripts are only reported, not changed.
* `dry_run` shows the plan without changing anything.

**godot_animation_find_references**

* Lists each use with its kind:
  * `use`: an animation call or property;
  * `maybe`: a matching string with no animation keyword in the line;
  * `definition`: the name itself, in a library or SpriteFrames;
  * `state`: a state-machine state name.
* With `renames` and `apply=true` it rewrites the `use` matches. Backups go to
  `user://ai_studio/backups/`.

**godot_animation_edit** can:

* change a track-path prefix (`Armature/Skeleton3D` → `Skeleton3D`);
* rename bones (a map, or a regex such as `^mixamorig[:_]`);
* remove tracks whose node, bone, blend shape or property does not exist, or whose path matches
  a regex;
* set the loop mode or length, and bake a playback speed into the key times;
* copy or move an animation to another library of the same player, or to a `.tres`
  AnimationLibrary.

**godot_import_animation_names**

Every reimport restores the names inside a model, so renaming them in a scene does not last.
This tool:

* `list`: shows the names, with a preview when you give rules;
* `apply`: writes a small `EditorScenePostImport` script with your rules, sets it as the
  model's import script and reimports;
* `extract`: saves renamed copies to an AnimationLibrary;
* `remove`: unhooks the script and moves it to the trash.

The generated script contains the same renaming code as the preview, so the result matches.

Undo and saving:

* Changes to the scene open in the editor go into its undo history (Ctrl+Z). You save the scene
  yourself.
* Other scenes and library files are saved right away.

## Editor script and editor log

* `godot_run_editor_script` runs a short GDScript in the editor, for things the other tools
  cannot do.
  * You can give it a function body or a script with `func run()`; `await` is allowed.
  * It returns the prints, the errors (with line numbers) and the return value.
  * There is no sandbox and no timeout, so **it always asks for approval**, even with
    approvals switched off.
* `godot_editor_log` reads:
  * errors and warnings from the editor, with file and line (collected from the moment the
    plugin starts);
  * the debugger's Errors tab for the running or last game;
  * or the text of the Output panel, which also shows the game's `print` output.

## Running game: the game bridge

The `game_*` tools look at the game while it runs and control it: they read the live scene tree,
take screenshots, simulate input, read and set properties, call methods and spawn nodes.

1. `godot_game_bridge` with `action=enable` adds the autoload
   `AIStudioGameBridgeServer` (`runtime/game_bridge_server.gd`) to the project. You do this once.
2. Start the game with `godot_play_scene` or F5.
3. Use the `game_*` tools. `godot_game_bridge` with no action shows the connection status.

The autoload does nothing unless all of these are true:

* the game was started from this editor (`editor_runtime` feature);
* the editor passed `AI_STUDIO_BRIDGE=1` to it.

When those conditions are not met, the autoload removes itself on startup, so exported builds
and games started some other way never open a port. When the bridge does run:

* it listens only on `127.0.0.1` (port 9090, or `AI_STUDIO_BRIDGE_PORT`);
* every request must carry a random token that the editor creates each session.

`action=disable` removes the autoload.

The dock shows these by default:

* `game_screenshot`, `game_get_scene_tree`, `game_get_ui`, `game_get_node_info`,
  `game_get_property`, `game_set_property`, `game_call_method`, `game_click`,
  `game_key_press`, `game_mouse_move`, `game_input_action`, `game_wait`, `game_eval`,
  `game_performance`;
* `game_get_logs` and `game_get_errors`, which return the game's output and its
  `push_error`/`push_warning` messages with the script file and line;
* `game_commands`, which lists or searches all 110 commands with their parameters;
* `game_command`, which runs any of them by name.

The other commands include:

* physics and joints, raycasts, cameras and lights;
* 2D and 3D nodes (CSG, GridMap, MultiMesh, paths, navigation, sky, GI and more);
* animation, audio and UI controls;
* tweens, timers and signals;
* networking (HTTP, WebSocket, multiplayer);
* rendering settings.

To give each command its own tool, tick *Expose every game command as its own tool* in
Settings. That raises the tool count from 83 to 177, and some providers limit a request to
128 tools. Untick *Offer runtime game tools (game_\*) to the model* to hide all `game_*` tools.
A project's `.ai_studio.json` cannot change either setting.

Commands that only read state or simulate input run without asking for approval:

* reading: screenshot, scene tree, UI, properties, node info, groups, class search, camera,
  audio, signals, OS info, performance, logs, errors;
* input: click, keys, mouse, scroll, drag, gamepad, touch, input actions;
* `game_wait`.

Everything else asks for approval, including `game_eval`, spawning or removing nodes, HTTP
requests and saving resources.
