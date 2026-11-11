class_name PixelMenuLayer
extends CanvasLayer
## Opens the game's pixel menus (GameMenus) over any scene: a 640x360 canvas
## shown at an exact 3x in a centred 1920x1080 frame, over a dimmed screen,
## exactly like the title menu. Screens stack (pause → options → back). While
## anything is open the game is paused; the last screen closing resumes it.
##
##   PixelMenuLayer.open_pause(self, can_save, extra_rows)   (Esc in game scenes)

const W := 640
const H := 360
const SCALE := 3

var stack: Array[PixelScreen] = []
var _vp: SubViewport
var _was_paused := false


## Opens the pause menu over `host`'s scene; returns the layer (null if one is open).
static func open_pause(host: Node, can_save: bool, extra: Array = []) -> PixelMenuLayer:
	if is_open(host):
		return null
	var layer := PixelMenuLayer.new()
	host.add_child(layer)
	layer.push(GameMenus.pause(layer, can_save, extra))
	AudioManager.play_ui("open")
	return layer


static func is_open(host: Node) -> bool:
	for c in host.get_children():
		if c is PixelMenuLayer and not c.is_queued_for_deletion():
			return true
	return false


func _init() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.stretch_shrink = SCALE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.custom_minimum_size = Vector2(W * SCALE, H * SCALE)
	center.add_child(frame)
	_vp = SubViewport.new()
	_vp.disable_3d = true
	_vp.transparent_bg = true
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vp.handle_input_locally = true
	frame.add_child(_vp)
	for s in stack:
		if s.get_parent() == null:
			_vp.add_child(s)


## Shows `s` on top; the screen under it hides until `s` closes.
func push(s: PixelScreen) -> void:
	if not stack.is_empty():
		_show(stack.back(), false)
	stack.append(s)
	s.closed.connect(func() -> void: _pop(s))
	if _vp:
		_vp.add_child(s)


func _pop(s: PixelScreen) -> void:
	stack.erase(s)
	if stack.is_empty():
		close_all()
	else:
		_show(stack.back(), true)


func _show(s: PixelScreen, on: bool) -> void:
	s.visible = on
	s.set_process_unhandled_input(on)
	if on:
		s.grab_focus()


## Closes every screen and resumes the game.
func close_all() -> void:
	for s in stack.duplicate():
		if is_instance_valid(s):
			s.queue_free()
	stack.clear()
	if is_inside_tree():
		get_tree().paused = _was_paused
	AudioManager.play_ui("close")
	queue_free()
