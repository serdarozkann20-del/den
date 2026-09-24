@tool
class_name AIStudioGameCatalog
extends RefCounted

## Runtime command catalog for the game bridge (GENERATED - do not edit by hand).
##
## One entry per runtime tool of godot-mcp (https://github.com/tugcantopaloglu/godot-mcp,
## MIT, (c) Tugcan Topaloglu and Solomon Elias). Parameter names are already in
## the snake_case the in-game server expects. `defaults` mirror the upstream
## client defaults, `json_keys` are arguments that travel as JSON text and are
## decoded before they are sent, `timeout_ms` is how long the editor waits.

const COMMANDS := {
	"game_screenshot": {
		"command": "screenshot",
		"description": "Screenshot the running game (returns base64 PNG)",
		"properties": {},
		"required": [],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_click": {
		"command": "click",
		"description": "Click at a position in the running Godot game window",
		"properties": {
			"x": {
				"type": "number",
				"description": "X coordinate to click",
			},
			"y": {
				"type": "number",
				"description": "Y coordinate to click",
			},
			"button": {
				"type": "number",
				"description": "Mouse button (1=left, 2=right, 3=middle). Default: 1",
			},
		},
		"required": ["x", "y"],
		"defaults": {
			"x": 0,
			"y": 0,
			"button": 1,
		},
		"timeout_ms": 10000,
	},
	"game_key_press": {
		"command": "key_press",
		"description": "Send a key press or input action to the running game",
		"properties": {
			"key": {
				"type": "string",
				"description": "Key name (e.g. \"W\", \"Space\", \"Escape\", \"Enter\")",
			},
			"action": {
				"type": "string",
				"description": "Godot input action name (e.g. \"move_forward\", \"ui_accept\")",
			},
			"pressed": {
				"type": "boolean",
				"description": "Press (true) or release (false). Default: true (auto-release)",
			},
		},
		"required": [],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_mouse_move": {
		"command": "mouse_move",
		"description": "Move the mouse in the running Godot game",
		"properties": {
			"x": {
				"type": "number",
				"description": "Absolute X position",
			},
			"y": {
				"type": "number",
				"description": "Absolute Y position",
			},
			"relative_x": {
				"type": "number",
				"description": "Relative X movement",
			},
			"relative_y": {
				"type": "number",
				"description": "Relative Y movement",
			},
		},
		"required": ["x", "y"],
		"defaults": {
			"x": 0,
			"y": 0,
			"relative_x": 0,
			"relative_y": 0,
		},
		"timeout_ms": 10000,
	},
	"game_get_ui": {
		"command": "get_ui_elements",
		"description": "Get visible UI elements from the running game",
		"properties": {},
		"required": [],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_get_scene_tree": {
		"command": "get_scene_tree",
		"description": "Get scene tree structure of the running game",
		"properties": {},
		"required": [],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_eval": {
		"command": "eval",
		"description": "Execute GDScript in the running game. Use \"return\" for values.",
		"properties": {
			"code": {
				"type": "string",
				"description": "GDScript code to execute. Use \"return\" to return values.",
			},
		},
		"required": ["code"],
		"defaults": {},
		"timeout_ms": 30000,
	},
	"game_get_property": {
		"command": "get_property",
		"description": "Get a property value from any node in the running game by its path",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node (e.g., \"/root/Player\", \"/root/Main/Enemy\")",
			},
			"property": {
				"type": "string",
				"description": "Property name to get (e.g., \"position\", \"health\", \"visible\")",
			},
		},
		"required": ["node_path", "property"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_set_property": {
		"command": "set_property",
		"description": "Set a property on a node in the running game",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node",
			},
			"property": {
				"type": "string",
				"description": "Property name to set",
			},
			"value": {
				"type": "string",
				"description": "Value to set. Use objects for vectors/colors Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"type_hint": {
				"type": "string",
				"description": "Optional type hint: \"Vector2\", \"Vector3\", \"Color\"",
			},
		},
		"required": ["node_path", "property", "value"],
		"defaults": {
			"type_hint": "",
		},
		"timeout_ms": 10000,
		"json_keys": ["value"],
	},
	"game_call_method": {
		"command": "call_method",
		"description": "Call a method on any node in the running game with optional arguments",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node",
			},
			"method": {
				"type": "string",
				"description": "Method name to call",
			},
			"args": {
				"type": "string",
				"description": "Optional array of arguments to pass to the method Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
		},
		"required": ["node_path", "method"],
		"defaults": {
			"args": [],
		},
		"timeout_ms": 10000,
		"json_keys": ["args"],
	},
	"game_get_node_info": {
		"command": "get_node_info",
		"description": "Get node info: class, properties, signals, methods, children",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node (e.g., \"/root/Player\")",
			},
		},
		"required": ["node_path"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_instantiate_scene": {
		"command": "instantiate_scene",
		"description": "Load a PackedScene and add it as a child of a node in the running game",
		"properties": {
			"scene_path": {
				"type": "string",
				"description": "Resource path to the scene (e.g., \"res://scenes/enemy.tscn\")",
			},
			"parent_path": {
				"type": "string",
				"description": "Path to the parent node. Default: \"/root\"",
			},
		},
		"required": ["scene_path"],
		"defaults": {
			"parent_path": "/root",
		},
		"timeout_ms": 10000,
	},
	"game_remove_node": {
		"command": "remove_node",
		"description": "Remove and free a node from the running game's scene tree",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node to remove",
			},
		},
		"required": ["node_path"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_change_scene": {
		"command": "change_scene",
		"description": "Switch to a different scene file in the running game",
		"properties": {
			"scene_path": {
				"type": "string",
				"description": "Resource path to the scene (e.g., \"res://scenes/levels/level2.tscn\")",
			},
		},
		"required": ["scene_path"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_pause": {
		"command": "pause",
		"description": "Pause or unpause the running game",
		"properties": {
			"paused": {
				"type": "boolean",
				"description": "True to pause, false to unpause. Default: true",
			},
		},
		"required": [],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_performance": {
		"command": "get_performance",
		"description": "Get performance metrics (FPS, memory, draw calls)",
		"properties": {},
		"required": [],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_wait": {
		"command": "wait",
		"description": "Wait N frames in the running game",
		"properties": {
			"frames": {
				"type": "number",
				"description": "Number of frames to wait. Default: 1",
			},
			"frame_type": {
				"type": "string",
				"enum": ["render", "physics"],
				"description": "Frame to wait on: \"physics\" (fixed 60Hz ticks) or \"render\". Default: render",
			},
		},
		"required": [],
		"defaults": {
			"frames": 1,
			"frame_type": "render",
		},
		"timeout_ms": 30000,
	},
	"game_connect_signal": {
		"command": "connect_signal",
		"description": "Connect a signal from one node to a method on another node in the running game",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the source node that emits the signal",
			},
			"signal_name": {
				"type": "string",
				"description": "Name of the signal to connect",
			},
			"target_path": {
				"type": "string",
				"description": "Path to the target node that receives the signal",
			},
			"method": {
				"type": "string",
				"description": "Method name to call on the target node",
			},
		},
		"required": ["node_path", "signal_name", "target_path", "method"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_disconnect_signal": {
		"command": "disconnect_signal",
		"description": "Disconnect a signal connection in the running game",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the source node",
			},
			"signal_name": {
				"type": "string",
				"description": "Name of the signal",
			},
			"target_path": {
				"type": "string",
				"description": "Path to the target node",
			},
			"method": {
				"type": "string",
				"description": "Method name on the target",
			},
		},
		"required": ["node_path", "signal_name", "target_path", "method"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_emit_signal": {
		"command": "emit_signal",
		"description": "Emit a signal on a node in the running game, optionally with arguments",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node",
			},
			"signal_name": {
				"type": "string",
				"description": "Name of the signal to emit",
			},
			"args": {
				"type": "string",
				"description": "Optional arguments to pass with the signal Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
		},
		"required": ["node_path", "signal_name"],
		"defaults": {
			"args": [],
		},
		"timeout_ms": 10000,
		"json_keys": ["args"],
	},
	"game_play_animation": {
		"command": "play_animation",
		"description": "Control an AnimationPlayer node: play, stop, pause, or list animations",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the AnimationPlayer node",
			},
			"action": {
				"type": "string",
				"description": "Action: \"play\", \"stop\", \"pause\", or \"get_list\"",
			},
			"animation": {
				"type": "string",
				"description": "Animation name (required for \"play\" action)",
			},
		},
		"required": ["node_path"],
		"defaults": {
			"action": "play",
			"animation": "",
		},
		"timeout_ms": 10000,
	},
	"game_tween_property": {
		"command": "tween_property",
		"description": "Tween a node property in the running game",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node",
			},
			"property": {
				"type": "string",
				"description": "Property to tween (e.g., \"position\", \"modulate\")",
			},
			"final_value": {
				"type": "string",
				"description": "Target value. Use {x,y} for Vector2, {x,y,z} for Vector3, {r,g,b,a} for Color Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"duration": {
				"type": "number",
				"description": "Duration in seconds. Default: 1.0",
			},
			"trans_type": {
				"type": "number",
				"description": "Tween.TransitionType enum value. Default: 0 (LINEAR)",
			},
			"ease_type": {
				"type": "number",
				"description": "Tween.EaseType enum value. Default: 2 (IN_OUT)",
			},
		},
		"required": ["node_path", "property", "final_value"],
		"defaults": {
			"duration": 1.0,
			"trans_type": 0,
			"ease_type": 2,
		},
		"timeout_ms": 10000,
		"json_keys": ["final_value"],
	},
	"game_get_nodes_in_group": {
		"command": "get_nodes_in_group",
		"description": "Get all nodes belonging to a specific group in the running game",
		"properties": {
			"group": {
				"type": "string",
				"description": "Group name (e.g., \"enemies\", \"player\", \"checkpoints\")",
			},
		},
		"required": ["group"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_find_nodes_by_class": {
		"command": "find_nodes_by_class",
		"description": "Find all nodes of a specific class type in the running game",
		"properties": {
			"class_name": {
				"type": "string",
				"description": "Class name to search for (e.g., \"CharacterBody3D\", \"Light3D\")",
			},
			"root_path": {
				"type": "string",
				"description": "Root node path to start searching from. Default: \"/root\"",
			},
		},
		"required": ["class_name"],
		"defaults": {
			"root_path": "/root",
		},
		"timeout_ms": 10000,
	},
	"game_reparent_node": {
		"command": "reparent_node",
		"description": "Move a node to a new parent in the running game's scene tree",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node to move",
			},
			"new_parent_path": {
				"type": "string",
				"description": "Path to the new parent node",
			},
			"keep_global_transform": {
				"type": "boolean",
				"description": "Whether to keep the global transform. Default: true",
			},
		},
		"required": ["node_path", "new_parent_path"],
		"defaults": {
			"keep_global_transform": true,
		},
		"timeout_ms": 10000,
	},
	"game_key_hold": {
		"command": "key_hold",
		"description": "Hold a key down without auto-releasing",
		"properties": {
			"key": {
				"type": "string",
				"description": "Key name (e.g. \"W\", \"Space\", \"Shift\")",
			},
			"action": {
				"type": "string",
				"description": "Godot input action name (e.g. \"move_forward\")",
			},
		},
		"required": [],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_key_release": {
		"command": "key_release",
		"description": "Release a previously held key",
		"properties": {
			"key": {
				"type": "string",
				"description": "Key name to release",
			},
			"action": {
				"type": "string",
				"description": "Godot input action name to release",
			},
		},
		"required": [],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_scroll": {
		"command": "scroll",
		"description": "Send mouse scroll wheel event at position",
		"properties": {
			"x": {
				"type": "number",
				"description": "X position for scroll event",
			},
			"y": {
				"type": "number",
				"description": "Y position for scroll event",
			},
			"direction": {
				"type": "string",
				"description": "\"up\", \"down\", \"left\", or \"right\". Default: \"up\"",
			},
			"amount": {
				"type": "number",
				"description": "Scroll amount (clicks). Default: 1",
			},
		},
		"required": ["x", "y"],
		"defaults": {
			"x": 0,
			"y": 0,
			"direction": "up",
			"amount": 1,
		},
		"timeout_ms": 10000,
	},
	"game_mouse_drag": {
		"command": "mouse_drag",
		"description": "Drag mouse between two points over N frames",
		"properties": {
			"from_x": {
				"type": "number",
				"description": "Start X coordinate",
			},
			"from_y": {
				"type": "number",
				"description": "Start Y coordinate",
			},
			"to_x": {
				"type": "number",
				"description": "End X coordinate",
			},
			"to_y": {
				"type": "number",
				"description": "End Y coordinate",
			},
			"button": {
				"type": "number",
				"description": "Mouse button (1=left). Default: 1",
			},
			"steps": {
				"type": "number",
				"description": "Number of frames for the drag. Default: 10",
			},
		},
		"required": ["from_x", "from_y", "to_x", "to_y"],
		"defaults": {
			"button": 1,
			"steps": 10,
		},
		"timeout_ms": 30000,
	},
	"game_gamepad": {
		"command": "gamepad",
		"description": "Send gamepad button or axis input event",
		"properties": {
			"type": {
				"type": "string",
				"description": "\"button\" or \"axis\"",
			},
			"index": {
				"type": "number",
				"description": "Button or axis index",
			},
			"value": {
				"type": "number",
				"description": "Value: 0/1 for buttons, -1.0 to 1.0 for axes",
			},
			"device": {
				"type": "number",
				"description": "Gamepad device index. Default: 0",
			},
		},
		"required": ["type", "index", "value"],
		"defaults": {
			"device": 0,
		},
		"timeout_ms": 10000,
	},
	"game_get_camera": {
		"command": "get_camera",
		"description": "Get active camera position, rotation, and size",
		"properties": {},
		"required": [],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_set_camera": {
		"command": "set_camera",
		"description": "Move or rotate the active camera",
		"properties": {
			"position": {
				"type": "object",
				"description": "{x,y} or {x,y,z} for camera position",
			},
			"rotation": {
				"type": "object",
				"description": "{x,y,z} rotation in degrees",
			},
			"zoom": {
				"type": "object",
				"description": "{x,y} zoom for Camera2D",
			},
			"fov": {
				"type": "number",
				"description": "Field of view for Camera3D",
			},
		},
		"required": [],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_raycast": {
		"command": "raycast",
		"description": "Cast a ray and return collision results",
		"properties": {
			"from": {
				"type": "object",
				"description": "Start point {x,y} or {x,y,z}",
			},
			"to": {
				"type": "object",
				"description": "End point {x,y} or {x,y,z}",
			},
			"collision_mask": {
				"type": "number",
				"description": "Collision mask. Default: 0xFFFFFFFF",
			},
		},
		"required": ["from", "to"],
		"defaults": {
			"collision_mask": 4294967295,
		},
		"timeout_ms": 10000,
	},
	"game_get_audio": {
		"command": "get_audio",
		"description": "Get audio bus layout and playing streams",
		"properties": {},
		"required": [],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_spawn_node": {
		"command": "spawn_node",
		"description": "Create a new node of any type at runtime",
		"properties": {
			"type": {
				"type": "string",
				"description": "Node class name (e.g. \"Sprite2D\", \"CharacterBody3D\")",
			},
			"name": {
				"type": "string",
				"description": "Name for the new node. Default: auto-generated",
			},
			"parent_path": {
				"type": "string",
				"description": "Parent node path. Default: \"/root\"",
			},
			"properties": {
				"type": "object",
				"description": "Properties to set on the new node",
			},
		},
		"required": ["type"],
		"defaults": {
			"name": "",
			"parent_path": "/root",
		},
		"timeout_ms": 10000,
	},
	"game_set_shader_param": {
		"command": "set_shader_param",
		"description": "Set a shader parameter on a node's material",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node with a ShaderMaterial",
			},
			"param_name": {
				"type": "string",
				"description": "Shader parameter name",
			},
			"value": {
				"type": "string",
				"description": "Value to set (number, object, array, etc.) Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"type_hint": {
				"type": "string",
				"description": "Optional type hint (e.g. \"Color\", \"Vector2\")",
			},
		},
		"required": ["node_path", "param_name", "value"],
		"defaults": {},
		"timeout_ms": 10000,
		"json_keys": ["value"],
	},
	"game_audio_play": {
		"command": "audio_play",
		"description": "Play, stop, or pause an AudioStreamPlayer node",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to AudioStreamPlayer/2D/3D node",
			},
			"action": {
				"type": "string",
				"description": "Action: play, stop, pause, resume",
			},
			"stream": {
				"type": "string",
				"description": "Optional res:// path to load a new stream",
			},
			"volume": {
				"type": "number",
				"description": "Volume (linear 0-1)",
			},
			"pitch": {
				"type": "number",
				"description": "Pitch scale",
			},
			"bus": {
				"type": "string",
				"description": "Audio bus name",
			},
			"from_position": {
				"type": "number",
				"description": "Start position in seconds",
			},
		},
		"required": ["node_path"],
		"defaults": {
			"action": "play",
		},
		"timeout_ms": 10000,
	},
	"game_audio_bus": {
		"command": "audio_bus",
		"description": "Set volume, mute, or solo on an audio bus",
		"properties": {
			"bus_name": {
				"type": "string",
				"description": "Bus name. Default: \"Master\"",
			},
			"volume": {
				"type": "number",
				"description": "Volume (linear 0-1)",
			},
			"mute": {
				"type": "boolean",
				"description": "Mute the bus",
			},
			"solo": {
				"type": "boolean",
				"description": "Solo the bus",
			},
		},
		"required": [],
		"defaults": {
			"bus_name": "Master",
		},
		"timeout_ms": 10000,
	},
	"game_navigate_path": {
		"command": "navigate_path",
		"description": "Query a navigation path between two points",
		"properties": {
			"start": {
				"type": "object",
				"description": "Start point {x,y} or {x,y,z}",
			},
			"end": {
				"type": "object",
				"description": "End point {x,y} or {x,y,z}",
			},
			"optimize": {
				"type": "boolean",
				"description": "Use string-pulling optimization. Default: true",
			},
		},
		"required": ["start", "end"],
		"defaults": {
			"optimize": true,
		},
		"timeout_ms": 10000,
	},
	"game_tilemap": {
		"command": "tilemap",
		"description": "Get or set cells in a TileMapLayer node",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to TileMapLayer node",
			},
			"action": {
				"type": "string",
				"description": "Action: set_cells, get_cell, erase_cells, get_used_cells",
			},
			"x": {
				"type": "number",
				"description": "Cell X coordinate (for get_cell)",
			},
			"y": {
				"type": "number",
				"description": "Cell Y coordinate (for get_cell)",
			},
			"cells": {
				"type": "string",
				"description": "Array of cell objects for set_cells/erase_cells Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"source_id": {
				"type": "number",
				"description": "Filter by source_id (for get_used_cells)",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
		"json_keys": ["cells"],
	},
	"game_add_collision": {
		"command": "add_collision",
		"description": "Add a collision shape to a physics body node",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Path to CollisionBody/Area node",
			},
			"shape_type": {
				"type": "string",
				"description": "Shape: box, sphere/circle, capsule, cylinder, ray, segment",
			},
			"shape_params": {
				"type": "object",
				"description": "Shape dimensions (e.g. {radius, height})",
			},
			"collision_layer": {
				"type": "number",
				"description": "Collision layer bitmask",
			},
			"collision_mask": {
				"type": "number",
				"description": "Collision mask bitmask",
			},
			"disabled": {
				"type": "boolean",
				"description": "Start disabled",
			},
		},
		"required": ["parent_path", "shape_type"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_environment": {
		"command": "environment",
		"description": "Get or set environment and post-processing settings",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: get or set. Default: set",
			},
			"background_mode": {
				"type": "number",
				"description": "0=clear, 1=custom_color, 2=sky, 3=canvas",
			},
			"background_color": {
				"type": "object",
				"description": "Background color {r,g,b,a}",
			},
			"ambient_light_color": {
				"type": "object",
				"description": "Ambient light color {r,g,b,a}",
			},
			"ambient_light_energy": {
				"type": "number",
				"description": "Ambient light energy",
			},
			"fog_enabled": {
				"type": "boolean",
				"description": "Enable fog",
			},
			"fog_density": {
				"type": "number",
				"description": "Fog density",
			},
			"fog_light_color": {
				"type": "object",
				"description": "Fog light color {r,g,b,a}",
			},
			"glow_enabled": {
				"type": "boolean",
				"description": "Enable glow",
			},
			"glow_intensity": {
				"type": "number",
				"description": "Glow intensity",
			},
			"glow_bloom": {
				"type": "number",
				"description": "Glow bloom",
			},
			"tonemap_mode": {
				"type": "number",
				"description": "0=linear, 1=reinhardt, 2=filmic, 3=aces",
			},
			"ssao_enabled": {
				"type": "boolean",
				"description": "Enable SSAO",
			},
			"ssao_radius": {
				"type": "number",
				"description": "SSAO radius",
			},
			"ssao_intensity": {
				"type": "number",
				"description": "SSAO intensity",
			},
			"ssr_enabled": {
				"type": "boolean",
				"description": "Enable SSR",
			},
			"brightness": {
				"type": "number",
				"description": "Brightness adjustment",
			},
			"contrast": {
				"type": "number",
				"description": "Contrast adjustment",
			},
			"saturation": {
				"type": "number",
				"description": "Saturation adjustment",
			},
		},
		"required": [],
		"defaults": {
			"action": "set",
		},
		"timeout_ms": 10000,
	},
	"game_manage_group": {
		"command": "manage_group",
		"description": "Add or remove a node from a group, or list groups",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node",
			},
			"action": {
				"type": "string",
				"description": "Action: add, remove, get_groups, clear_group",
			},
			"group": {
				"type": "string",
				"description": "Group name",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_create_timer": {
		"command": "create_timer",
		"description": "Create a Timer node with configuration",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path. Default: \"/root\"",
			},
			"wait_time": {
				"type": "number",
				"description": "Timer duration in seconds. Default: 1.0",
			},
			"one_shot": {
				"type": "boolean",
				"description": "One-shot mode. Default: false",
			},
			"autostart": {
				"type": "boolean",
				"description": "Auto-start the timer. Default: false",
			},
			"name": {
				"type": "string",
				"description": "Optional timer node name",
			},
		},
		"required": [],
		"defaults": {
			"parent_path": "/root",
			"wait_time": 1.0,
			"one_shot": false,
			"autostart": false,
		},
		"timeout_ms": 10000,
	},
	"game_set_particles": {
		"command": "set_particles",
		"description": "Configure GPUParticles2D/3D node properties",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to GPUParticles node",
			},
			"emitting": {
				"type": "boolean",
				"description": "Enable/disable emission",
			},
			"amount": {
				"type": "number",
				"description": "Number of particles",
			},
			"lifetime": {
				"type": "number",
				"description": "Particle lifetime in seconds",
			},
			"one_shot": {
				"type": "boolean",
				"description": "One-shot mode",
			},
			"speed_scale": {
				"type": "number",
				"description": "Speed scale",
			},
			"explosiveness": {
				"type": "number",
				"description": "Explosiveness ratio (0-1)",
			},
			"randomness": {
				"type": "number",
				"description": "Randomness ratio (0-1)",
			},
			"process_material": {
				"type": "object",
				"description": "ParticleProcessMaterial settings",
			},
		},
		"required": ["node_path"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_create_animation": {
		"command": "create_animation",
		"description": "Create an animation with tracks and keyframes",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to AnimationPlayer node",
			},
			"animation_name": {
				"type": "string",
				"description": "Name for the new animation",
			},
			"length": {
				"type": "number",
				"description": "Animation length in seconds. Default: 1.0",
			},
			"loop_mode": {
				"type": "number",
				"description": "0=none, 1=linear, 2=pingpong",
			},
			"tracks": {
				"type": "string",
				"description": "Array of track definitions Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"library": {
				"type": "string",
				"description": "Animation library name. Default: \"\"",
			},
		},
		"required": ["node_path", "animation_name"],
		"defaults": {
			"length": 1.0,
			"loop_mode": 0,
			"tracks": [],
		},
		"timeout_ms": 10000,
		"json_keys": ["tracks"],
	},
	"game_serialize_state": {
		"command": "serialize_state",
		"description": "Save or load node tree state as JSON",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Root node path. Default: \"/root\"",
			},
			"action": {
				"type": "string",
				"description": "Action: save or load. Default: save",
			},
			"data": {
				"type": "object",
				"description": "State data to restore (for load)",
			},
			"max_depth": {
				"type": "number",
				"description": "Max tree depth to serialize. Default: 5",
			},
		},
		"required": [],
		"defaults": {
			"node_path": "/root",
			"action": "save",
			"max_depth": 5,
		},
		"timeout_ms": 10000,
	},
	"game_physics_body": {
		"command": "physics_body",
		"description": "Configure physics body properties (mass, velocity, etc.)",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to physics body node",
			},
			"gravity_scale": {
				"type": "number",
				"description": "Gravity scale",
			},
			"mass": {
				"type": "number",
				"description": "Body mass",
			},
			"linear_velocity": {
				"type": "object",
				"description": "Linear velocity {x,y} or {x,y,z}",
			},
			"angular_velocity": {
				"type": "string",
				"description": "Angular velocity (float for 2D, {x,y,z} for 3D) Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"linear_damp": {
				"type": "number",
				"description": "Linear damping",
			},
			"angular_damp": {
				"type": "number",
				"description": "Angular damping",
			},
			"friction": {
				"type": "number",
				"description": "Physics material friction",
			},
			"bounce": {
				"type": "number",
				"description": "Physics material bounce",
			},
			"freeze": {
				"type": "boolean",
				"description": "Freeze the body",
			},
			"sleeping": {
				"type": "boolean",
				"description": "Put body to sleep",
			},
		},
		"required": ["node_path"],
		"defaults": {},
		"timeout_ms": 10000,
		"json_keys": ["angular_velocity"],
	},
	"game_create_joint": {
		"command": "create_joint",
		"description": "Create a physics joint between two bodies",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path for the joint",
			},
			"joint_type": {
				"type": "string",
				"description": "Joint type: pin_2d, spring_2d, groove_2d, pin_3d, hinge_3d, cone_3d, slider_3d",
			},
			"node_a_path": {
				"type": "string",
				"description": "Path to first body",
			},
			"node_b_path": {
				"type": "string",
				"description": "Path to second body",
			},
			"stiffness": {
				"type": "number",
				"description": "Spring stiffness (spring_2d)",
			},
			"damping": {
				"type": "number",
				"description": "Spring damping (spring_2d)",
			},
			"length": {
				"type": "number",
				"description": "Length (spring_2d, groove_2d)",
			},
			"softness": {
				"type": "number",
				"description": "Softness (pin_2d)",
			},
		},
		"required": ["parent_path", "joint_type"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_bone_pose": {
		"command": "bone_pose",
		"description": "Get or set bone poses on a Skeleton3D node",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to Skeleton3D node",
			},
			"action": {
				"type": "string",
				"description": "Action: list, get, or set. Default: list",
			},
			"bone_index": {
				"type": "number",
				"description": "Bone index",
			},
			"bone_name": {
				"type": "string",
				"description": "Bone name (alternative to index)",
			},
			"position": {
				"type": "object",
				"description": "Bone position {x,y,z}",
			},
			"rotation": {
				"type": "object",
				"description": "Bone rotation quaternion {x,y,z,w}",
			},
			"scale": {
				"type": "object",
				"description": "Bone scale {x,y,z}",
			},
		},
		"required": ["node_path"],
		"defaults": {
			"action": "list",
		},
		"timeout_ms": 10000,
	},
	"game_ui_theme": {
		"command": "ui_theme",
		"description": "Apply theme overrides to a Control node",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to Control node",
			},
			"overrides": {
				"type": "object",
				"description": "Theme overrides: {colors, constants, fontSizes}",
			},
		},
		"required": ["node_path", "overrides"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_viewport": {
		"command": "viewport",
		"description": "Create or configure a SubViewport node",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: create, configure, or get",
			},
			"parent_path": {
				"type": "string",
				"description": "Parent path (for create)",
			},
			"node_path": {
				"type": "string",
				"description": "SubViewport path (for configure/get)",
			},
			"width": {
				"type": "number",
				"description": "Viewport width",
			},
			"height": {
				"type": "number",
				"description": "Viewport height",
			},
			"msaa": {
				"type": "number",
				"description": "MSAA level (0=disabled, 1=2x, 2=4x, 3=8x)",
			},
			"transparent_bg": {
				"type": "boolean",
				"description": "Transparent background",
			},
			"name": {
				"type": "string",
				"description": "Viewport name (for create)",
			},
		},
		"required": [],
		"defaults": {
			"action": "create",
		},
		"timeout_ms": 10000,
	},
	"game_debug_draw": {
		"command": "debug_draw",
		"description": "Draw debug lines, spheres, or boxes in 3D",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: line, sphere, box, or clear",
			},
			"from": {
				"type": "object",
				"description": "Line start {x,y,z}",
			},
			"to": {
				"type": "object",
				"description": "Line end {x,y,z}",
			},
			"center": {
				"type": "object",
				"description": "Sphere/box center {x,y,z}",
			},
			"radius": {
				"type": "number",
				"description": "Sphere radius. Default: 0.5",
			},
			"size": {
				"type": "object",
				"description": "Box size {x,y,z}",
			},
			"color": {
				"type": "object",
				"description": "Draw color {r,g,b,a}. Default: red",
			},
			"duration": {
				"type": "number",
				"description": "Frames to persist (0=permanent)",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_http_request": {
		"command": "http_request",
		"description": "HTTP GET/POST/PUT/DELETE with headers and body",
		"properties": {
			"url": {
				"type": "string",
				"description": "Request URL",
			},
			"method": {
				"type": "string",
				"description": "HTTP method: GET, POST, PUT, DELETE. Default: GET",
			},
			"headers": {
				"type": "object",
				"description": "Request headers as key-value pairs",
			},
			"body": {
				"type": "string",
				"description": "Request body string",
			},
			"timeout": {
				"type": "number",
				"description": "Timeout in seconds. Default: 30",
			},
		},
		"required": ["url"],
		"defaults": {
			"method": "GET",
		},
		"timeout_ms": 35000,
	},
	"game_websocket": {
		"command": "websocket",
		"description": "WebSocket client connect/disconnect/send messages",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: connect, disconnect, send, status",
			},
			"url": {
				"type": "string",
				"description": "WebSocket URL (for connect)",
			},
			"message": {
				"type": "string",
				"description": "Message to send (for send)",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 15000,
	},
	"game_multiplayer": {
		"command": "multiplayer",
		"description": "ENet multiplayer create server/client/disconnect",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: create_server, create_client, disconnect, status",
			},
			"port": {
				"type": "number",
				"description": "Server port. Default: 7000",
			},
			"address": {
				"type": "string",
				"description": "Server address for client. Default: 127.0.0.1",
			},
			"max_clients": {
				"type": "number",
				"description": "Max clients for server. Default: 32",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_rpc": {
		"command": "rpc",
		"description": "Call or configure RPC methods on nodes",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node",
			},
			"action": {
				"type": "string",
				"description": "Action: call, configure",
			},
			"method": {
				"type": "string",
				"description": "Method name",
			},
			"args": {
				"type": "string",
				"description": "Arguments for the RPC call Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"mode": {
				"type": "string",
				"description": "RPC mode: any_peer, authority",
			},
			"sync": {
				"type": "string",
				"description": "Sync mode: call_local, call_remote",
			},
			"channel": {
				"type": "number",
				"description": "Transfer channel",
			},
		},
		"required": ["node_path", "action", "method"],
		"defaults": {},
		"timeout_ms": 10000,
		"json_keys": ["args"],
	},
	"game_touch": {
		"command": "touch",
		"description": "Simulate touch press/release/drag and gestures",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: press, release, drag",
			},
			"x": {
				"type": "number",
				"description": "Touch X position",
			},
			"y": {
				"type": "number",
				"description": "Touch Y position",
			},
			"index": {
				"type": "number",
				"description": "Touch index. Default: 0",
			},
			"to_x": {
				"type": "number",
				"description": "Drag end X (for drag)",
			},
			"to_y": {
				"type": "number",
				"description": "Drag end Y (for drag)",
			},
			"steps": {
				"type": "number",
				"description": "Drag steps. Default: 10",
			},
		},
		"required": ["action", "x", "y"],
		"defaults": {
			"x": 0,
			"y": 0,
		},
		"timeout_ms": 15000,
	},
	"game_input_state": {
		"command": "input_state",
		"description": "Query pressed keys, mouse position, connected pads",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: query, warp_mouse, set_mouse_mode",
			},
			"x": {
				"type": "number",
				"description": "Mouse X (for warp_mouse)",
			},
			"y": {
				"type": "number",
				"description": "Mouse Y (for warp_mouse)",
			},
			"mouse_mode": {
				"type": "string",
				"description": "Mode: visible, hidden, captured, confined",
			},
		},
		"required": [],
		"defaults": {
			"action": "query",
		},
		"timeout_ms": 10000,
	},
	"game_input_action": {
		"command": "input_action",
		"description": "Manage runtime InputMap actions and strength",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: set_strength, add_action, remove_action, list",
			},
			"action_name": {
				"type": "string",
				"description": "Input action name",
			},
			"strength": {
				"type": "number",
				"description": "Action strength 0.0-1.0",
			},
			"key": {
				"type": "string",
				"description": "Key name (for add_action)",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_list_signals": {
		"command": "list_signals",
		"description": "List all signals on a node with connections",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node",
			},
		},
		"required": ["node_path"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_await_signal": {
		"command": "await_signal",
		"description": "Await a signal with timeout and return args",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node",
			},
			"signal_name": {
				"type": "string",
				"description": "Signal name to await",
			},
			"timeout": {
				"type": "number",
				"description": "Timeout in seconds. Default: 10",
			},
		},
		"required": ["node_path", "signal_name"],
		"defaults": {
			"timeout": 10,
		},
		"timeout_ms": 10000,
	},
	"game_script": {
		"command": "script",
		"description": "Attach, detach, or get source of node scripts",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node",
			},
			"action": {
				"type": "string",
				"description": "Action: attach, detach, get_source",
			},
			"source": {
				"type": "string",
				"description": "GDScript source code (for attach)",
			},
			"class_name": {
				"type": "string",
				"description": "Class the script extends",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_window": {
		"command": "window",
		"description": "Get/set window size, fullscreen, title, position",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: get or set. Default: get",
			},
			"width": {
				"type": "number",
				"description": "Window width",
			},
			"height": {
				"type": "number",
				"description": "Window height",
			},
			"fullscreen": {
				"type": "boolean",
				"description": "Fullscreen mode",
			},
			"borderless": {
				"type": "boolean",
				"description": "Borderless mode",
			},
			"title": {
				"type": "string",
				"description": "Window title",
			},
			"position": {
				"type": "object",
				"description": "Window position {x, y}",
			},
			"vsync": {
				"type": "boolean",
				"description": "Enable vsync",
			},
		},
		"required": [],
		"defaults": {
			"action": "get",
		},
		"timeout_ms": 10000,
	},
	"game_os_info": {
		"command": "os_info",
		"description": "Get platform, locale, screen, adapter, memory info",
		"properties": {},
		"required": [],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_time_scale": {
		"command": "time_scale",
		"description": "Get/set Engine.time_scale and timing info",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: get or set. Default: get",
			},
			"time_scale": {
				"type": "number",
				"description": "Time scale value (for set)",
			},
		},
		"required": [],
		"defaults": {
			"action": "get",
		},
		"timeout_ms": 10000,
	},
	"game_process_mode": {
		"command": "process_mode",
		"description": "Set node process mode (pausable/always/disabled)",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to the node",
			},
			"mode": {
				"type": "string",
				"description": "Mode: inherit, pausable, when_paused, always, disabled",
			},
		},
		"required": ["node_path", "mode"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_world_settings": {
		"command": "world_settings",
		"description": "Get/set gravity, physics FPS, and world settings",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: get or set. Default: get",
			},
			"gravity": {
				"type": "number",
				"description": "Gravity magnitude",
			},
			"gravity_direction": {
				"type": "object",
				"description": "Gravity direction vector {x,y,z}",
			},
			"physics_fps": {
				"type": "number",
				"description": "Physics ticks per second",
			},
		},
		"required": [],
		"defaults": {
			"action": "get",
		},
		"timeout_ms": 10000,
	},
	"game_csg": {
		"command": "csg",
		"description": "Create/configure CSG nodes with boolean operations",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"action": {
				"type": "string",
				"description": "Action: create or configure",
			},
			"csg_type": {
				"type": "string",
				"description": "CSG type: box, sphere, cylinder, mesh, combiner",
			},
			"node_path": {
				"type": "string",
				"description": "Node path (for configure)",
			},
			"operation": {
				"type": "string",
				"description": "Boolean op: union, intersection, subtraction",
			},
			"size": {
				"type": "object",
				"description": "Size {x,y,z} (box)",
			},
			"radius": {
				"type": "number",
				"description": "Radius (sphere/cylinder)",
			},
			"height": {
				"type": "number",
				"description": "Height (cylinder)",
			},
			"material": {
				"type": "string",
				"description": "Material resource path",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_multimesh": {
		"command": "multimesh",
		"description": "Create/configure MultiMeshInstance3D for instancing",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"action": {
				"type": "string",
				"description": "Action: create, set_instance, get_info",
			},
			"node_path": {
				"type": "string",
				"description": "Node path (for set_instance/get_info)",
			},
			"mesh_type": {
				"type": "string",
				"description": "Mesh: box, sphere, cylinder, quad",
			},
			"count": {
				"type": "number",
				"description": "Instance count",
			},
			"index": {
				"type": "number",
				"description": "Instance index (for set_instance)",
			},
			"transform": {
				"type": "object",
				"description": "Transform {origin:{x,y,z}, rotation:{x,y,z}}",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_procedural_mesh": {
		"command": "procedural_mesh",
		"description": "Generate meshes via ArrayMesh from vertex data",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"vertices": {
				"type": "string",
				"description": "Vertex positions [[x,y,z],...] Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"normals": {
				"type": "string",
				"description": "Vertex normals [[x,y,z],...] Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"uvs": {
				"type": "string",
				"description": "UV coordinates [[u,v],...] Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"indices": {
				"type": "string",
				"description": "Triangle indices [i0,i1,i2,...] Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["parent_path", "vertices"],
		"defaults": {},
		"timeout_ms": 10000,
		"json_keys": ["vertices", "normals", "uvs", "indices"],
	},
	"game_light_3d": {
		"command": "light_3d",
		"description": "Create/configure 3D lights (directional/omni/spot)",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"action": {
				"type": "string",
				"description": "Action: create or configure",
			},
			"light_type": {
				"type": "string",
				"description": "Type: directional, omni, spot",
			},
			"node_path": {
				"type": "string",
				"description": "Node path (for configure)",
			},
			"color": {
				"type": "object",
				"description": "Light color {r,g,b}",
			},
			"energy": {
				"type": "number",
				"description": "Light energy/intensity",
			},
			"range": {
				"type": "number",
				"description": "Light range (omni/spot)",
			},
			"shadows": {
				"type": "boolean",
				"description": "Enable shadow casting",
			},
			"spot_angle": {
				"type": "number",
				"description": "Spot cone angle in degrees",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_mesh_instance": {
		"command": "mesh_instance",
		"description": "Create MeshInstance3D with primitive meshes",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"mesh_type": {
				"type": "string",
				"description": "Mesh: box, sphere, cylinder, capsule, plane, quad",
			},
			"size": {
				"type": "object",
				"description": "Mesh size {x,y,z}",
			},
			"radius": {
				"type": "number",
				"description": "Mesh radius",
			},
			"height": {
				"type": "number",
				"description": "Mesh height",
			},
			"material": {
				"type": "string",
				"description": "Material resource path or color hex",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["parent_path", "mesh_type"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_gridmap": {
		"command": "gridmap",
		"description": "GridMap set/get/clear cells and query used cells",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to GridMap node",
			},
			"action": {
				"type": "string",
				"description": "Action: set_cell, get_cell, clear, get_used",
			},
			"x": {
				"type": "number",
				"description": "Cell X coordinate",
			},
			"y": {
				"type": "number",
				"description": "Cell Y coordinate",
			},
			"z": {
				"type": "number",
				"description": "Cell Z coordinate",
			},
			"item": {
				"type": "number",
				"description": "MeshLibrary item index",
			},
			"orientation": {
				"type": "number",
				"description": "Cell orientation index",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_3d_effects": {
		"command": "3d_effects",
		"description": "Create ReflectionProbe, Decal, or FogVolume",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"effect_type": {
				"type": "string",
				"description": "Type: reflection_probe, decal, fog_volume",
			},
			"size": {
				"type": "object",
				"description": "Effect size {x,y,z}",
			},
			"intensity": {
				"type": "number",
				"description": "Effect intensity",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["parent_path", "effect_type"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_gi": {
		"command": "gi",
		"description": "Create/configure VoxelGI or LightmapGI",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"gi_type": {
				"type": "string",
				"description": "Type: voxel_gi or lightmap_gi",
			},
			"size": {
				"type": "object",
				"description": "Extents size {x,y,z}",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["parent_path", "gi_type"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_path_3d": {
		"command": "path_3d",
		"description": "Create Path3D/Curve3D and manage curve points",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"action": {
				"type": "string",
				"description": "Action: create, add_point, set_points, get_points",
			},
			"node_path": {
				"type": "string",
				"description": "Path3D node path (for add/set/get)",
			},
			"points": {
				"type": "string",
				"description": "Array of points [{x,y,z},...] Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"point": {
				"type": "object",
				"description": "Single point {x,y,z}",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
		"json_keys": ["points"],
	},
	"game_sky": {
		"command": "sky",
		"description": "Create/configure Sky with procedural/physical sky",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: create or configure",
			},
			"sky_type": {
				"type": "string",
				"description": "Type: procedural or physical",
			},
			"top_color": {
				"type": "object",
				"description": "Sky top color {r,g,b}",
			},
			"bottom_color": {
				"type": "object",
				"description": "Horizon bottom color {r,g,b}",
			},
			"sun_energy": {
				"type": "number",
				"description": "Sun energy/brightness",
			},
			"ground_color": {
				"type": "object",
				"description": "Ground color {r,g,b}",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_camera_attributes": {
		"command": "camera_attributes",
		"description": "Configure DOF, exposure, auto-exposure on camera",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: get or set",
			},
			"dof_blur_far": {
				"type": "number",
				"description": "DOF far blur distance",
			},
			"dof_blur_near": {
				"type": "number",
				"description": "DOF near blur distance",
			},
			"dof_blur_amount": {
				"type": "number",
				"description": "DOF blur amount",
			},
			"exposure_multiplier": {
				"type": "number",
				"description": "Exposure multiplier",
			},
			"auto_exposure": {
				"type": "boolean",
				"description": "Enable auto exposure",
			},
			"auto_exposure_scale": {
				"type": "number",
				"description": "Auto exposure scale",
			},
		},
		"required": [],
		"defaults": {
			"action": "get",
		},
		"timeout_ms": 10000,
	},
	"game_navigation_3d": {
		"command": "navigation_3d",
		"description": "Create/configure NavigationRegion3D and bake",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"action": {
				"type": "string",
				"description": "Action: create, bake, configure",
			},
			"node_path": {
				"type": "string",
				"description": "Node path (for bake/configure)",
			},
			"cell_size": {
				"type": "number",
				"description": "Navigation cell size",
			},
			"agent_radius": {
				"type": "number",
				"description": "Agent radius",
			},
			"agent_height": {
				"type": "number",
				"description": "Agent height",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 30000,
	},
	"game_physics_3d": {
		"command": "physics_3d",
		"description": "Area3D queries and point/shape intersection tests",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: overlap, point_query, shape_query, ray",
			},
			"node_path": {
				"type": "string",
				"description": "Area3D/node path (for overlap)",
			},
			"from": {
				"type": "object",
				"description": "Ray/point origin {x,y,z}",
			},
			"to": {
				"type": "object",
				"description": "Ray end {x,y,z}",
			},
			"collision_mask": {
				"type": "number",
				"description": "Collision mask bitmask",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 15000,
	},
	"game_canvas": {
		"command": "canvas",
		"description": "Create/configure CanvasLayer and CanvasModulate",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"action": {
				"type": "string",
				"description": "Action: create_layer, create_modulate, configure",
			},
			"node_path": {
				"type": "string",
				"description": "Node path (for configure)",
			},
			"layer": {
				"type": "number",
				"description": "Canvas layer number",
			},
			"offset": {
				"type": "object",
				"description": "CanvasLayer offset {x,y} (for configure)",
			},
			"visible": {
				"type": "boolean",
				"description": "CanvasLayer visibility (for configure)",
			},
			"color": {
				"type": "object",
				"description": "Modulate color {r,g,b,a}",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_canvas_draw": {
		"command": "canvas_draw",
		"description": "2D drawing: line/rect/circle/polygon/text/clear",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path for draw node",
			},
			"action": {
				"type": "string",
				"description": "Action: line, rect, circle, polygon, text, clear",
			},
			"from": {
				"type": "object",
				"description": "Start point {x,y}",
			},
			"to": {
				"type": "object",
				"description": "End point {x,y}",
			},
			"center": {
				"type": "object",
				"description": "Center point {x,y}",
			},
			"radius": {
				"type": "number",
				"description": "Circle radius",
			},
			"rect": {
				"type": "object",
				"description": "Rectangle {x,y,w,h}",
			},
			"points": {
				"type": "string",
				"description": "Polygon points [{x,y},...] Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"position": {
				"type": "object",
				"description": "Text position {x,y} (baseline, for text)",
			},
			"text": {
				"type": "string",
				"description": "Text to draw",
			},
			"font_size": {
				"type": "number",
				"description": "Text font size. Default: 16",
			},
			"color": {
				"type": "object",
				"description": "Draw color {r,g,b,a}",
			},
			"width": {
				"type": "number",
				"description": "Line width. Default: 2",
			},
			"filled": {
				"type": "boolean",
				"description": "Fill shape. Default: true",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
		"json_keys": ["points"],
	},
	"game_light_2d": {
		"command": "light_2d",
		"description": "Create/configure 2D lights and light occluders",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"action": {
				"type": "string",
				"description": "Action: create_point, create_directional, create_occluder",
			},
			"node_path": {
				"type": "string",
				"description": "Node path (for configure)",
			},
			"color": {
				"type": "object",
				"description": "Light color {r,g,b,a}",
			},
			"energy": {
				"type": "number",
				"description": "Light energy",
			},
			"range": {
				"type": "number",
				"description": "Light texture range",
			},
			"points": {
				"type": "string",
				"description": "Occluder polygon points [{x,y},...] (for create_occluder) Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
		"json_keys": ["points"],
	},
	"game_parallax": {
		"command": "parallax",
		"description": "Create/configure ParallaxBackground and layers",
		"properties": {
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"action": {
				"type": "string",
				"description": "Action: create_background, add_layer, configure",
			},
			"node_path": {
				"type": "string",
				"description": "Node path (for configure)",
			},
			"motion_scale": {
				"type": "object",
				"description": "Motion scale {x,y} (ParallaxLayer)",
			},
			"motion_offset": {
				"type": "object",
				"description": "Motion offset {x,y} (ParallaxLayer)",
			},
			"mirroring": {
				"type": "object",
				"description": "Mirroring {x,y} (ParallaxLayer)",
			},
			"scroll_offset": {
				"type": "object",
				"description": "Scroll offset {x,y} (ParallaxBackground configure)",
			},
			"scroll_base_offset": {
				"type": "object",
				"description": "Scroll base offset {x,y} (ParallaxBackground configure)",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_shape_2d": {
		"command": "shape_2d",
		"description": "Line2D/Polygon2D point manipulation",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to Line2D/Polygon2D node",
			},
			"action": {
				"type": "string",
				"description": "Action: add_point, set_points, clear, get_points",
			},
			"points": {
				"type": "string",
				"description": "Array of points [{x,y},...] Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"point": {
				"type": "object",
				"description": "Single point {x,y}",
			},
			"width": {
				"type": "number",
				"description": "Line width",
			},
			"color": {
				"type": "object",
				"description": "Color {r,g,b,a}",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
		"json_keys": ["points"],
	},
	"game_path_2d": {
		"command": "path_2d",
		"description": "Path2D/Curve2D management and AnimatedSprite2D",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: create, add_point, set_points, get_points",
			},
			"parent_path": {
				"type": "string",
				"description": "Parent node path (for create)",
			},
			"node_path": {
				"type": "string",
				"description": "Path2D node path",
			},
			"points": {
				"type": "string",
				"description": "Array of points [{x,y},...] Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
			"point": {
				"type": "object",
				"description": "Single point {x,y}",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
		"json_keys": ["points"],
	},
	"game_physics_2d": {
		"command": "physics_2d",
		"description": "Area2D queries and 2D point/shape intersections",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: overlap, point_query, shape_query, ray",
			},
			"node_path": {
				"type": "string",
				"description": "Area2D/node path (for overlap)",
			},
			"from": {
				"type": "object",
				"description": "Origin point {x,y}",
			},
			"to": {
				"type": "object",
				"description": "End point {x,y} (for ray)",
			},
			"position": {
				"type": "object",
				"description": "Query position {x,y} (point_query/shape_query)",
			},
			"radius": {
				"type": "number",
				"description": "Circle radius (shape_query circle)",
			},
			"size": {
				"type": "object",
				"description": "Rectangle size {x,y} (shape_query rectangle)",
			},
			"shape_type": {
				"type": "string",
				"description": "Shape: circle or rectangle (shape_query)",
			},
			"max_results": {
				"type": "number",
				"description": "Max results. Default: 32",
			},
			"collision_mask": {
				"type": "number",
				"description": "Collision mask bitmask",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 15000,
	},
	"game_animation_tree": {
		"command": "animation_tree",
		"description": "AnimationTree state machine travel and params",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to AnimationTree node",
			},
			"action": {
				"type": "string",
				"description": "Action: travel, set_param, get_state, get_params",
			},
			"state_name": {
				"type": "string",
				"description": "State name (for travel)",
			},
			"param_name": {
				"type": "string",
				"description": "Parameter name",
			},
			"param_value": {
				"type": "string",
				"description": "Parameter value Pass JSON text (e.g. {\"x\":1,\"y\":2}, [1,2,3], 5, true) or a plain string.",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
		"json_keys": ["param_value"],
	},
	"game_animation_control": {
		"command": "animation_control",
		"description": "AnimationPlayer seek/queue/speed/info control",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to AnimationPlayer node",
			},
			"action": {
				"type": "string",
				"description": "Action: seek, queue, set_speed, get_info, stop",
			},
			"animation_name": {
				"type": "string",
				"description": "Animation name",
			},
			"position": {
				"type": "number",
				"description": "Seek position in seconds",
			},
			"speed": {
				"type": "number",
				"description": "Playback speed scale",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_skeleton_ik": {
		"command": "skeleton_ik",
		"description": "SkeletonIK3D start/stop/set target position",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to SkeletonIK3D node",
			},
			"action": {
				"type": "string",
				"description": "Action: start, stop, set_target",
			},
			"target": {
				"type": "object",
				"description": "Target position {x,y,z}",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_audio_effect": {
		"command": "audio_effect",
		"description": "Add/remove/configure audio bus effects",
		"properties": {
			"bus_name": {
				"type": "string",
				"description": "Audio bus name. Default: Master",
			},
			"action": {
				"type": "string",
				"description": "Action: add, remove, configure, list",
			},
			"effect_type": {
				"type": "string",
				"description": "Effect: reverb, delay, chorus, eq, compressor, limiter",
			},
			"index": {
				"type": "number",
				"description": "Effect index",
			},
			"properties": {
				"type": "object",
				"description": "Effect properties to set (for configure)",
			},
			"enabled": {
				"type": "boolean",
				"description": "Enable/disable the effect (for configure)",
			},
		},
		"required": ["action"],
		"defaults": {
			"bus_name": "Master",
		},
		"timeout_ms": 10000,
	},
	"game_audio_bus_layout": {
		"command": "audio_bus_layout",
		"description": "Create/remove audio buses and routing",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: add, remove, set_send, list",
			},
			"bus_name": {
				"type": "string",
				"description": "Bus name",
			},
			"send_to": {
				"type": "string",
				"description": "Send target bus name",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_audio_spatial": {
		"command": "audio_spatial",
		"description": "Configure AudioStreamPlayer3D spatial properties",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to AudioStreamPlayer3D",
			},
			"action": {
				"type": "string",
				"description": "Action: configure, get_info",
			},
			"max_distance": {
				"type": "number",
				"description": "Maximum audible distance",
			},
			"unit_size": {
				"type": "number",
				"description": "Unit size for distance attenuation",
			},
			"max_db": {
				"type": "number",
				"description": "Maximum volume in dB",
			},
			"attenuation_model": {
				"type": "string",
				"description": "Model: inverse, inverse_square, logarithmic",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_locale": {
		"command": "locale",
		"description": "Set/get locale and translate strings at runtime",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: get, set, translate",
			},
			"locale": {
				"type": "string",
				"description": "Locale code (e.g. en, es, fr)",
			},
			"key": {
				"type": "string",
				"description": "Translation key (for translate)",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_ui_control": {
		"command": "ui_control",
		"description": "Set focus, anchors, tooltip, mouse filter on Control",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to Control node",
			},
			"action": {
				"type": "string",
				"description": "Action: configure, grab_focus, release_focus, get_info",
			},
			"anchor_preset": {
				"type": "number",
				"description": "Anchor preset value",
			},
			"tooltip": {
				"type": "string",
				"description": "Tooltip text",
			},
			"mouse_filter": {
				"type": "string",
				"description": "Mouse filter: stop, pass, ignore",
			},
			"min_size": {
				"type": "object",
				"description": "Minimum size {x,y}",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_ui_text": {
		"command": "ui_text",
		"description": "LineEdit/TextEdit/RichTextLabel text operations",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to text control",
			},
			"action": {
				"type": "string",
				"description": "Action: get, set, append, clear, select, bbcode",
			},
			"text": {
				"type": "string",
				"description": "Text content",
			},
			"caret_position": {
				"type": "number",
				"description": "Caret column position",
			},
			"selection_from": {
				"type": "number",
				"description": "Selection start",
			},
			"selection_to": {
				"type": "number",
				"description": "Selection end",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_ui_popup": {
		"command": "ui_popup",
		"description": "Show/hide/popup for Popup/Dialog/Window nodes",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to Popup/Dialog/Window",
			},
			"action": {
				"type": "string",
				"description": "Action: popup_centered, popup, hide, get_info",
			},
			"size": {
				"type": "object",
				"description": "Popup size {x,y}",
			},
			"title": {
				"type": "string",
				"description": "Dialog title text",
			},
			"text": {
				"type": "string",
				"description": "Dialog body text",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_ui_tree": {
		"command": "ui_tree",
		"description": "Tree control: get/select/collapse/add/remove items",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to Tree control",
			},
			"action": {
				"type": "string",
				"description": "Action: get_items, select, collapse, expand, add, remove",
			},
			"item_path": {
				"type": "string",
				"description": "Item path (slash-separated indices)",
			},
			"text": {
				"type": "string",
				"description": "Item text (for add)",
			},
			"column": {
				"type": "number",
				"description": "Column index. Default: 0",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_ui_item_list": {
		"command": "ui_item_list",
		"description": "ItemList/OptionButton: get/select/add/remove items",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to ItemList/OptionButton",
			},
			"action": {
				"type": "string",
				"description": "Action: get_items, select, add, remove, clear",
			},
			"index": {
				"type": "number",
				"description": "Item index",
			},
			"text": {
				"type": "string",
				"description": "Item text (for add)",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_ui_tabs": {
		"command": "ui_tabs",
		"description": "TabContainer/TabBar: get/set current tab",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to TabContainer/TabBar",
			},
			"action": {
				"type": "string",
				"description": "Action: get_tabs, set_current, set_title",
			},
			"index": {
				"type": "number",
				"description": "Tab index",
			},
			"title": {
				"type": "string",
				"description": "Tab title",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_ui_menu": {
		"command": "ui_menu",
		"description": "PopupMenu/MenuBar: add/remove/get menu items",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to PopupMenu/MenuBar",
			},
			"action": {
				"type": "string",
				"description": "Action: get_items, add, remove, set_checked, clear",
			},
			"index": {
				"type": "number",
				"description": "Item index",
			},
			"text": {
				"type": "string",
				"description": "Item text (for add)",
			},
			"checked": {
				"type": "boolean",
				"description": "Checked state",
			},
			"id": {
				"type": "number",
				"description": "Item ID",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_ui_range": {
		"command": "ui_range",
		"description": "ProgressBar/Slider/SpinBox/ColorPicker get/set",
		"properties": {
			"node_path": {
				"type": "string",
				"description": "Path to Range/ColorPicker node",
			},
			"action": {
				"type": "string",
				"description": "Action: get or set",
			},
			"value": {
				"type": "number",
				"description": "Value (for Range nodes)",
			},
			"min_value": {
				"type": "number",
				"description": "Minimum value",
			},
			"max_value": {
				"type": "number",
				"description": "Maximum value",
			},
			"step": {
				"type": "number",
				"description": "Step value",
			},
			"color": {
				"type": "object",
				"description": "Color {r,g,b,a} (for ColorPicker)",
			},
		},
		"required": ["node_path", "action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_render_settings": {
		"command": "render_settings",
		"description": "Get/set MSAA, FXAA, TAA, scaling mode/scale",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: get or set",
			},
			"msaa_2d": {
				"type": "number",
				"description": "MSAA 2D mode (0-3)",
			},
			"msaa_3d": {
				"type": "number",
				"description": "MSAA 3D mode (0-3)",
			},
			"fxaa": {
				"type": "boolean",
				"description": "Enable FXAA",
			},
			"taa": {
				"type": "boolean",
				"description": "Enable TAA",
			},
			"scaling_mode": {
				"type": "number",
				"description": "Scaling mode (0=bilinear, 1=FSR1, 2=FSR2)",
			},
			"scaling_scale": {
				"type": "number",
				"description": "Render scale (0.0-1.0)",
			},
		},
		"required": [],
		"defaults": {
			"action": "get",
		},
		"timeout_ms": 10000,
	},
	"game_resource": {
		"command": "resource",
		"description": "Runtime resource load, save, or preload",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: load, save, exists",
			},
			"path": {
				"type": "string",
				"description": "Resource path (res://)",
			},
			"node_path": {
				"type": "string",
				"description": "Node path (for save - saves node resource)",
			},
			"property": {
				"type": "string",
				"description": "Property name holding the resource",
			},
		},
		"required": ["action", "path"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_visual_shader": {
		"command": "visual_shader",
		"description": "Create and edit VisualShader graphs: add/connect/disconnect nodes",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: create, add_node, connect, disconnect, get_nodes, apply",
			},
			"node_path": {
				"type": "string",
				"description": "Target node path (for apply)",
			},
			"shader_type": {
				"type": "string",
				"description": "Shader type: spatial, canvas_item, particles, sky, fog",
			},
			"node_class": {
				"type": "string",
				"description": "VisualShaderNode class name (for add_node)",
			},
			"position": {
				"type": "object",
				"description": "Node position {x, y} (for add_node)",
			},
			"from_node": {
				"type": "number",
				"description": "Source node ID (for connect/disconnect)",
			},
			"from_port": {
				"type": "number",
				"description": "Source port index",
			},
			"to_node": {
				"type": "number",
				"description": "Destination node ID (for connect/disconnect)",
			},
			"to_port": {
				"type": "number",
				"description": "Destination port index",
			},
			"shader_id": {
				"type": "number",
				"description": "Shader resource ID (for multi-shader scenes)",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_terrain": {
		"command": "terrain",
		"description": "Create/modify terrain meshes from heightmap data",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: create, modify, get_height, paint",
			},
			"parent_path": {
				"type": "string",
				"description": "Parent node path",
			},
			"node_path": {
				"type": "string",
				"description": "Terrain node path",
			},
			"height_data": {
				"type": "array",
				"description": "Array of float height values (for create)",
				"items": {
					"type": "number",
				},
			},
			"width": {
				"type": "number",
				"description": "Terrain width in vertices",
			},
			"depth": {
				"type": "number",
				"description": "Terrain depth in vertices",
			},
			"max_height": {
				"type": "number",
				"description": "Maximum terrain height",
			},
			"x": {
				"type": "number",
				"description": "X position (for modify/get_height/paint)",
			},
			"z": {
				"type": "number",
				"description": "Z position (for modify/get_height/paint)",
			},
			"radius": {
				"type": "number",
				"description": "Brush radius (for modify/paint)",
			},
			"height_delta": {
				"type": "number",
				"description": "Height change amount (for modify)",
			},
			"color": {
				"type": "object",
				"description": "Vertex color {r,g,b,a} (for paint)",
			},
			"name": {
				"type": "string",
				"description": "Node name",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
	"game_video": {
		"command": "video",
		"description": "Video playback control: play, pause, stop, seek on VideoStreamPlayer",
		"properties": {
			"action": {
				"type": "string",
				"description": "Action: create, play, pause, stop, seek, get_status",
			},
			"node_path": {
				"type": "string",
				"description": "Path to VideoStreamPlayer node",
			},
			"parent_path": {
				"type": "string",
				"description": "Parent node path (for create)",
			},
			"video_path": {
				"type": "string",
				"description": "res:// path to video file",
			},
			"position": {
				"type": "number",
				"description": "Seek position in seconds",
			},
			"volume": {
				"type": "number",
				"description": "Volume (linear 0-1)",
			},
			"loop": {
				"type": "boolean",
				"description": "Enable looping",
			},
			"autoplay": {
				"type": "boolean",
				"description": "Auto-play on ready",
			},
			"name": {
				"type": "string",
				"description": "Node name (for create)",
			},
		},
		"required": ["action"],
		"defaults": {},
		"timeout_ms": 10000,
	},
}
