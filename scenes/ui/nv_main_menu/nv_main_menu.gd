class_name NvMainMenu
extends Control
## Beyond: The Neon Void title menu. 640x360, matches the Python mockup.
## Grok's handoff (tools/handoff/nv_main_menu): the look is his and stays as
## is. Changes here: asset paths, loading that works in an exported game, and
## selection_changed (for the cursor sound). TitleScreen wraps it at 3x and
## hooks the signals up.

## The cursor moved to another item (keys or mouse).
signal selection_changed(index: int)
signal continue_pressed
signal new_game_pressed
signal load_pressed
signal options_pressed
signal credits_pressed
signal quit_pressed

@export var has_save: bool = true:
	set(v):
		has_save = v
		if not has_save and _sel == 0:
			_sel = 1
		if _ready_ok:
			_redraw()

@export var quit_on_quit: bool = true
@export var autoplay: bool = true

const W := 640
const H := 360
const FPS := 12.0
const LOOP := 32
const Y0 := 196
const STEP := 24
const FRAME_SEC := 1.0 / 12.0
const ITEMS := ["CONTINUE", "NEW GAME", "LOAD GAME", "OPTIONS", "CREDITS", "QUIT"]
const IDS := ["continue", "new_game", "load", "options", "credits", "quit"]
const ART := "res://scenes/ui/nv_main_menu/assets"

var _sel: int = 0
var _t: int = 0
var _accum: float = 0.0
var _ready_ok: bool = false
var _chrome: Array[Image] = []
var _on: Array[Image] = []
var _off: Array[Image] = []
var _disabled: Image
var _bar: Image
var _cursor: Image
var _item_x: Array[int] = []
var _off_x: Array[int] = []
var _lut: PackedByteArray = PackedByteArray()
var _out: Image
var _tex: ImageTexture
var _view: TextureRect
var bar_x: int = 216
var bar_dy: int = -6
var cursor_gap: int = 6


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_ALL
	_load_art()
	_view = TextureRect.new()
	_view.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture_filter = TEXTURE_FILTER_NEAREST
	_view.mouse_filter = MOUSE_FILTER_IGNORE
	_tex = ImageTexture.new()
	_out = Image.create(W, H, false, Image.FORMAT_RGBA8)
	add_child(_view)
	if not has_save and _sel == 0:
		_sel = 1
	_ready_ok = true
	_redraw()
	grab_focus()


func _load_art() -> void:
	var f := FileAccess.open(ART + "/layout.json", FileAccess.READ)
	var layout: Dictionary = JSON.parse_string(f.get_as_text())
	bar_x = int(layout["bar"]["x"])
	bar_dy = int(layout["bar"]["dy"])
	cursor_gap = int(layout["cursor"]["gap"])
	_lut.resize(256)
	var lut_src: Array = layout["lut85"]
	for i in 256:
		_lut[i] = int(lut_src[i])
	for i in ITEMS.size():
		var meta: Dictionary = layout["items"][i]
		_item_x.append(int(meta["x"]))
		_off_x.append(int(meta["off_x"]))
		_on.append(_png(ART + "/items/%s_on.png" % IDS[i]))
		_off.append(_png(ART + "/items/%s_off.png" % IDS[i]))
	_disabled = _png(ART + "/items/continue_disabled.png")
	_bar = _png(ART + "/bar.png")
	_cursor = _png(ART + "/cursor.png")
	for t in LOOP:
		_chrome.append(_png(ART + "/chrome/%02d.png" % t))


func _png(path: String) -> Image:
	# Imported (lossless) in the game and in exports; raw file as a fallback.
	var img: Image = null
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		img = tex.get_image() if tex else null
	if img == null:
		img = Image.load_from_file(ProjectSettings.globalize_path(path))
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _process(delta: float) -> void:
	if not autoplay:
		return
	_accum += delta
	var dirty := false
	while _accum >= FRAME_SEC:
		_accum -= FRAME_SEC
		_t += 1
		dirty = true
	if dirty:
		_redraw()


func set_time(t: int) -> void:
	_t = t
	_accum = 0.0
	if _ready_ok:
		_redraw()


func set_sel(i: int) -> void:
	_sel = clampi(i, 0, ITEMS.size() - 1)
	if not _enabled(_sel):
		move_sel(1)
		return
	if _ready_ok:
		_redraw()


func get_sel() -> int:
	return _sel


func get_time() -> int:
	return _t


func compose_image() -> Image:
	return _out.duplicate()


func _enabled(i: int) -> bool:
	return i != 0 or has_save


func move_sel(dir: int) -> void:
	var n: int = ITEMS.size()
	var i: int = _sel
	for _k in n:
		i = (i + dir + n) % n
		if _enabled(i):
			_sel = i
			_redraw()
			selection_changed.emit(_sel)
			return


func activate() -> void:
	if not _enabled(_sel):
		return
	match _sel:
		0:
			continue_pressed.emit()
		1:
			new_game_pressed.emit()
		2:
			load_pressed.emit()
		3:
			options_pressed.emit()
		4:
			credits_pressed.emit()
		5:
			quit_pressed.emit()
			if quit_on_quit:
				get_tree().quit()


func hover_at(pos: Vector2) -> void:
	var i := _hit(pos)
	if i >= 0 and i != _sel:
		_sel = i
		_redraw()
		selection_changed.emit(_sel)


func _hit(pos: Vector2) -> int:
	for i in ITEMS.size():
		if not _enabled(i):
			continue
		var r := Rect2(210, Y0 + i * STEP - 8, 220, STEP)
		if r.has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hover_at(event.position)
		if _hit(event.position) >= 0:
			activate()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if k == KEY_UP or k == KEY_W or event.is_action("ui_up"):
		move_sel(-1)
		accept_event()
	elif k == KEY_DOWN or k == KEY_S or event.is_action("ui_down"):
		move_sel(1)
		accept_event()
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE or event.is_action("ui_accept"):
		activate()
		accept_event()


func _redraw() -> void:
	if _chrome.is_empty():
		return
	var t: int = posmod(_t, LOOP)
	_out.copy_from(_chrome[t])
	for i in ITEMS.size():
		if i == _sel:
			continue
		var im: Image = _disabled if (i == 0 and not has_save) else _off[i]
		var x: int = int((W - im.get_width()) / 2)
		var y: int = Y0 + i * STEP
		_over(_out, im, x, y)
	var sx: int = _item_x[_sel]
	var sy: int = Y0 + _sel * STEP - 4
	_over(_out, _bar, bar_x, Y0 + _sel * STEP + bar_dy)
	var bob: int = int(_t / 3) % 2
	_over(_out, _cursor, sx - _cursor.get_width() - cursor_gap + bob, sy)
	_over(_out, _on[_sel], sx, sy)
	_apply_crt(_out)
	if _tex.get_width() != W:
		_tex.set_image(_out)
	else:
		_tex.update(_out)
	_view.texture = _tex


func _idiv(n: int, d: int) -> int:
	return int(float(n - n % d) / float(d))


func _rnddiv(n: int, d: int) -> int:
	return _idiv(n + _idiv(d, 2), d)


func _over(dst: Image, src: Image, ox: int, oy: int) -> void:
	var sw: int = src.get_width()
	var sh: int = src.get_height()
	for y in sh:
		for x in sw:
			var s: Color = src.get_pixel(x, y)
			var sa: int = s.a8
			if sa == 0:
				continue
			var dx: int = ox + x
			var dy: int = oy + y
			if dx < 0 or dy < 0 or dx >= W or dy >= H:
				continue
			if sa == 255:
				dst.set_pixel(dx, dy, Color8(s.r8, s.g8, s.b8, 255))
				continue
			var d: Color = dst.get_pixel(dx, dy)
			var inv: int = 255 - sa
			# Pillow alpha_composite rounds to nearest; dest is opaque here.
			var r: int = _rnddiv(s.r8 * sa + d.r8 * inv, 255)
			var g: int = _rnddiv(s.g8 * sa + d.g8 * inv, 255)
			var b: int = _rnddiv(s.b8 * sa + d.b8 * inv, 255)
			dst.set_pixel(dx, dy, Color8(r, g, b, 255))


func _apply_crt(img: Image) -> void:
	var data: PackedByteArray = img.get_data()
	var row: int = W * 4
	for y in range(0, H, 2):
		var i: int = y * row
		var end: int = i + row
		while i < end:
			data[i] = _lut[data[i]]
			data[i + 1] = _lut[data[i + 1]]
			data[i + 2] = _lut[data[i + 2]]
			i += 4
	img.set_data(W, H, false, Image.FORMAT_RGBA8, data)
