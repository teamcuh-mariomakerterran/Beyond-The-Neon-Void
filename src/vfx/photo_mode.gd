class_name PhotoMode
extends CanvasLayer
## Photo mode (P) in exploration and battles: hides the HUD, gives a free
## camera and live control of the HD-2D tilt-shift stack, saves PNGs to
## user://photos/. Leaving puts the camera, HUD and the map's own look back
## exactly as they were; nothing here changes how the game looks normally.
##
##   P / Esc        leave            WASD / arrows / right-drag   pan
##   wheel / Q E    zoom             click                       focus line here
##   [ ]            blur strength    - =                         sharp band
##   1              look preset      V / G                       vignette / grain
##   F              freeze time      H                           hide this panel
##   Enter / F12    save photo       O                           open photo folder

const DIR := "user://photos"
const LOOKS := ["(map's own)", "hd2d_warm", "neon_noir", "cinematic", "dream", "toxic_haze", "off"]
const PAN_SPEED := 900.0
## The post shader's own defaults, for parameters a map never set.
const DEFAULTS := {"dof": 3.0, "focus_band": 0.16, "vignette": 0.55, "grain": 0.03, "focus_y": 0.5}

var active := false
var _cam: Camera2D
var _prev_cam: Camera2D
var _post: HD2DPost
var _own_post := false
var _saved_params: Dictionary = {}
var _saved_visible := true
var _saved_focus := 0.5
var _hidden: Array[CanvasItem] = []
var _hidden_layers: Array[CanvasLayer] = []
var _panel: PanelContainer
var _info: Label
var _toast: Label
var _look := 0
var _paused_before := false
var _drag := false


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if not active:
			if k == KEY_P:
				enter()
				get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		match k:
			KEY_P, KEY_ESCAPE: leave()
			KEY_BRACKETLEFT: _nudge("dof", -0.4, 0.0, 8.0)
			KEY_BRACKETRIGHT: _nudge("dof", 0.4, 0.0, 8.0)
			KEY_MINUS: _nudge("focus_band", -0.02, 0.02, 0.6)
			KEY_EQUAL: _nudge("focus_band", 0.02, 0.02, 0.6)
			KEY_1: _next_look()
			KEY_V: _post.set_param("vignette", 0.0 if _val("vignette") > 0.01 else 0.6)
			KEY_G: _post.set_param("grain", 0.0 if _val("grain") > 0.001 else 0.04)
			KEY_F: get_tree().paused = not get_tree().paused
			KEY_H: _panel.visible = not _panel.visible
			KEY_ENTER, KEY_KP_ENTER, KEY_F12: snap()
			KEY_O: OS.shell_open(ProjectSettings.globalize_path(DIR))
			KEY_Q: _zoom(1.0 / 1.15)
			KEY_E: _zoom(1.15)
		_refresh()
	elif active and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		get_viewport().set_input_as_handled()
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / 1.1)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_post.set_focus(mb.position.y / maxf(get_viewport().get_visible_rect().size.y, 1.0), true)
	elif active and event is InputEventMouseMotion:
		if _drag:
			_cam.position -= (event as InputEventMouseMotion).relative / _cam.zoom
		get_viewport().set_input_as_handled()  # no hover / x-ray under the cursor


func _process(delta: float) -> void:
	if not active:
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	if dir != Vector2.ZERO:
		_cam.position += dir.normalized() * PAN_SPEED * delta / _cam.zoom.x


func enter() -> void:
	if active:
		return
	active = true
	var vp := get_viewport()
	_prev_cam = vp.get_camera_2d()
	_cam = Camera2D.new()
	_cam.process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().add_child(_cam)
	if _prev_cam:
		_cam.global_position = _prev_cam.get_screen_center_position()
		_cam.zoom = _prev_cam.zoom
	_cam.make_current()
	# The map's own post stack, or a temporary one (removed on leave).
	_post = _find_post(get_parent())
	_own_post = _post == null
	if _own_post:
		_post = HD2DPost.new()
		get_parent().add_child(_post)
		_post.configure("off")
	_saved_params = _post.params.duplicate()
	_saved_visible = _post.visible
	_saved_focus = _val("focus_y")
	_post.focus_lock = true
	_look = 0
	# Hide every HUD layer (and the explore hint labels) above the post stack.
	for n: Node in get_parent().find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		if cl != self and cl != _post and cl.layer >= 10 and cl.visible:
			cl.visible = false
			_hidden_layers.append(cl)
	_paused_before = get_tree().paused
	_build_panel()
	_refresh()


func leave() -> void:
	if not active:
		return
	active = false
	get_tree().paused = _paused_before
	for cl in _hidden_layers:
		if is_instance_valid(cl):
			cl.visible = true
	_hidden_layers.clear()
	if _own_post:
		_post.queue_free()
	else:
		_post.configure("off", _saved_params)
		_post.visible = _saved_visible
		_post.focus_lock = false
		_post.set_focus(_saved_focus, true)
	_post = null
	if is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	_cam.queue_free()
	_cam = null
	if _panel:
		_panel.queue_free()
		_panel = null


## Saves the current frame (without this panel) to user://photos/. Returns the path.
func snap() -> String:
	var was := _panel.visible if _panel else false
	if _panel:
		_panel.visible = false
	if _toast:
		_toast.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if _panel:
		_panel.visible = was
	DirAccess.make_dir_recursive_absolute(DIR)
	var t := Time.get_datetime_dict_from_system()
	var path := "%s/neon_void_%04d%02d%02d_%02d%02d%02d.png" % [DIR, t.year, t.month, t.day, t.hour, t.minute, t.second]
	img.save_png(path)
	_say("Saved  " + ProjectSettings.globalize_path(path))
	if not Toasts.play_sfx("photo_saved"):
		Sfx.event("loot", -6.0, 1.4)
	return path


func _val(k: String) -> float:
	var v: Variant = _post.get_param(k) if _post else null
	return float(v) if v != null else float(DEFAULTS.get(k, 0.0))


func _zoom(f: float) -> void:
	_cam.zoom = (_cam.zoom * f).clamp(Vector2(0.25, 0.25), Vector2(6, 6))


func _nudge(k: String, d: float, lo: float, hi: float) -> void:
	_post.set_param(k, clampf(_val(k) + d, lo, hi))


func _next_look() -> void:
	_look = (_look + 1) % LOOKS.size()
	var name: String = LOOKS[_look]
	if _look == 0:
		_post.configure("off", _saved_params)
		_post.visible = _saved_visible or not _saved_params.is_empty()
	else:
		_post.configure(name)
	_post.focus_lock = true


static func _find_post(root: Node) -> HD2DPost:
	for n: Node in root.find_children("*", "HD2DPost", true, false):
		return n as HD2DPost
	return null


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", NeonTheme.panel_box(NeonTheme.CYAN, Color(0.02, 0.01, 0.05, 0.82)))
	_panel.position = Vector2(18, 18)
	add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	v.add_child(NeonTheme.label("PHOTO MODE", 18, NeonTheme.CYAN))
	_info = NeonTheme.label("", 13, NeonTheme.TEXT)
	v.add_child(_info)
	v.add_child(NeonTheme.label("WASD / right-drag pan  ·  wheel / Q E zoom  ·  click: focus line\n[ ] blur  ·  - = sharp band  ·  1 look  ·  V vignette  ·  G grain\nF freeze  ·  H hide panel  ·  Enter / F12 save  ·  O photo folder  ·  P leave", 12, NeonTheme.TEXT_DIM))
	_toast = NeonTheme.label("", 13, NeonTheme.AMBER)
	_toast.visible = false
	v.add_child(_toast)


func _refresh() -> void:
	if _info == null or _post == null:
		return
	_info.text = "Look: %s   Blur: %.1f   Band: %.2f   %s" % [LOOKS[_look], _val("dof"), _val("focus_band"), "FROZEN" if get_tree().paused else "live"]


func _say(text: String) -> void:
	if _toast:
		_toast.text = text
		_toast.visible = true
