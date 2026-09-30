class_name InputActions
extends RefCounted
## Registers the game's input actions in code, so project.godot stays readable
## and rebinding UI can later just edit InputMap at runtime.

const BINDINGS := {
	"interact": [KEY_E, KEY_ENTER],
	"cancel": [KEY_ESCAPE, KEY_BACKSPACE],
	"end_turn": [KEY_T],
	"wait": [KEY_SPACE],
	"move_mode": [KEY_M],
	"cam_left": [KEY_A, KEY_LEFT],
	"cam_right": [KEY_D, KEY_RIGHT],
	"cam_up": [KEY_W, KEY_UP],
	"cam_down": [KEY_S, KEY_DOWN],
	"cam_rotate": [KEY_Q],
	"toggle_threat": [KEY_TAB],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
	"toggle_editor": [KEY_F1],
}
const MOUSE_BINDINGS := {
	"mouse_left": MOUSE_BUTTON_LEFT,
	"mouse_right": MOUSE_BUTTON_RIGHT,
}


static func register() -> void:
	for action: String in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action: String in MOUSE_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BINDINGS[action]
		InputMap.action_add_event(action, mb)
