class_name PixelScreen
extends Control
## A sub-screen of the pixel title menu (Options, Load Game, Credits): drawn in
## the same 640x360 canvas as NvMainMenu, over its animated background, with
## the menu's own palette and Brian's PRESS START font at 2x, so it scales to
## the screen exactly like the menu. Rows can be toggles, sliders or actions.
##
##   Up / Down or W / S   move        Left / Right or A / D   change a value
##   Enter / Space         pick        Esc / Backspace         back
##   mouse: hover to select, click to pick (left / right half of a slider)

signal closed

const FONT := "res://assets/fonts/press_start/press_start_atlas.json"
## The menu's palette (sampled from Grok's art).
const BORDER := Color("6e1e82")
const FILL := Color("06050f")
const TEXT_OFF := Color("9678be")
const TEXT_DIM := Color("463858")
const CYAN := Color("4cfeec")
const MAGENTA := Color("fe0489")
const OUTLINE := Color("02000b")
const BAR := Color(0.996, 0.016, 0.537, 0.157)
const PANEL := Rect2i(120, 40, 400, 300)
const ROW_X := 148
const ROW_W := 344
const STEP := 24
const SIZE := 22   # 2x of the 11 px font
const SMALL := 11  # 1x
const SCROLL_SPEED := 14.0  # credits, px per second

var title := ""
## [{label, value: Callable -> String, detail: Callable -> String, left, right,
##   accept: Callable, enabled: Callable -> bool}]
var rows: Array[Dictionary] = []
## Credits mode: lines scroll up instead of rows ("# " = a heading).
var lines: Array[String] = []
var sel := 0
## The panel: full height for credits, otherwise just tall enough for the rows.
var panel := PANEL
var _scroll := 0.0
var _font: Font
var _t := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_ALL
	texture_filter = TEXTURE_FILTER_NEAREST


func _ready() -> void:
	_font = NeonTheme.font(FONT)
	if lines.is_empty() and not rows.is_empty():
		var h := clampi(56 + rows.size() * STEP + 16, 120, PANEL.size.y)
		panel = Rect2i(PANEL.position.x, (360 - h) / 2, PANEL.size.x, h)
	if not _enabled(sel):
		_move(1, false)
	grab_focus()


func add_row(label: String, accept: Callable = Callable(), value: Callable = Callable(), left: Callable = Callable(), right: Callable = Callable()) -> Dictionary:
	var r := {"label": label, "accept": accept, "value": value, "left": left, "right": right}
	rows.append(r)
	return r


func _enabled(i: int) -> bool:
	if i < 0 or i >= rows.size():
		return false
	var e: Variant = rows[i].get("enabled")
	return not (e is Callable) or bool((e as Callable).call())


func _move(d: int, sound: bool = true) -> void:
	var n := rows.size()
	var i := sel
	for _k in n:
		i = (i + d + n) % n
		if _enabled(i):
			if i != sel and sound:
				AudioManager.play_ui("menu_move")
			sel = i
			queue_redraw()
			return


func _call(key: String) -> void:
	if not _enabled(sel):
		return
	var cb: Variant = rows[sel].get(key)
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call()
		AudioManager.play_ui("confirm" if key == "accept" else "menu_move")
		queue_redraw()


func close() -> void:
	AudioManager.play_ui("cancel")
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	if not lines.is_empty():
		_scroll += SCROLL_SPEED * delta
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var k := (event as InputEventKey).keycode
	if k in [KEY_ESCAPE, KEY_BACKSPACE]:
		close()
	elif not lines.is_empty():
		if k in [KEY_UP, KEY_W]:
			_scroll = maxf(_scroll - STEP, 0.0)
		elif k in [KEY_DOWN, KEY_S]:
			_scroll += STEP
		elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and not event.echo:
			close()
	elif k in [KEY_UP, KEY_W]:
		_move(-1)
	elif k in [KEY_DOWN, KEY_S]:
		_move(1)
	elif k in [KEY_LEFT, KEY_A]:
		_call("left")
	elif k in [KEY_RIGHT, KEY_D]:
		_call("right")
	elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and not event.echo:
		_call("accept")
	else:
		return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not lines.is_empty():
		if event is InputEventMouseButton and event.pressed:
			close()
		return
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var i := row_at(event.position)
		if i >= 0 and i != sel and _enabled(i):
			AudioManager.play_ui("menu_move")
			sel = i
			queue_redraw()
		if event is InputEventMouseButton and i >= 0:
			var r := rows[i]
			# Sliders: click the left half to lower, the right half to raise.
			if (r.get("left") as Callable).is_valid() and not (r.get("accept") as Callable).is_valid():
				_call("left" if event.position.x < ROW_X + ROW_W * 0.6 else "right")
			else:
				_call("accept")
			accept_event()


func row_y(i: int) -> int:
	return panel.position.y + 56 + i * STEP


func row_at(p: Vector2) -> int:
	for i in rows.size():
		if Rect2(ROW_X - 8, row_y(i) - 6, ROW_W + 16, STEP).has_point(p):
			return i
	return -1


# --- drawing --------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(panel), FILL)
	draw_rect(Rect2(panel), BORDER, false, 1.0)
	_text_on(Vector2(panel.position.x + (panel.size.x - _width(title, SIZE)) * 0.5, panel.position.y + 22), title)
	if not lines.is_empty():
		_draw_credits()
	else:
		for i in rows.size():
			_draw_row(i)


func _draw_row(i: int) -> void:
	var r := rows[i]
	var y := row_y(i)
	var on := i == sel
	var col := TEXT_OFF if _enabled(i) else TEXT_DIM
	var label := str(r["label"])
	var value := ((r["value"] as Callable).call() as String) if (r.get("value") as Callable).is_valid() else ""
	var detail := ((r["detail"] as Callable).call() as String) if r.get("detail") is Callable else ""
	if on:
		draw_rect(Rect2(ROW_X - 8, y - 6, ROW_W + 16, STEP - 1), BAR)
		# The menu's cursor arrow, bobbing every 3 frames like the menu's.
		var bob := int(_t * 12.0 / 3.0) % 2
		_arrow(Vector2(ROW_X - 6 + bob, y - 2))
		_text_on(Vector2(ROW_X + 10, y + 9), label)
		if value != "":
			_text_on(Vector2(ROW_X + ROW_W - _width(value, SIZE), y + 9), value)
	else:
		_text(Vector2(ROW_X + 10, y + 9), label, col, SIZE)
		if value != "":
			_text(Vector2(ROW_X + ROW_W - _width(value, SIZE), y + 9), value, col, SIZE)
	if r.get("level") is Callable:
		_segments(Vector2(ROW_X + ROW_W, y + 1), int((r["level"] as Callable).call()), int(r.get("steps", 10)), on, col)
	if detail != "":
		_text(Vector2(ROW_X + ROW_W - _width(detail, SMALL), y + 9), detail, CYAN if on else col, SMALL)


func _draw_credits() -> void:
	var top := panel.position.y + 44
	var bottom := panel.end.y - 22
	var y := float(bottom) - _scroll
	var total := 0
	for l in lines:
		var head := l.begins_with("# ")
		var txt := l.substr(2) if head else l
		if y > top and y < bottom:
			var size := SIZE if head else SMALL * 2
			var x := panel.position.x + (panel.size.x - _width(txt, size)) * 0.5
			if head:
				_text_on(Vector2(x, y + 9), txt)
			else:
				_text(Vector2(x, y + 9), txt, TEXT_OFF, size)
		y += STEP
		total += STEP
	if _scroll > total + (bottom - top):
		_scroll = 0.0  # loop


func _width(s: String, size: int) -> float:
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if _font else 0.0


func _text(p: Vector2, s: String, c: Color, size: int) -> void:
	draw_string(_font, p.round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## The menu's selected look: dark outline, magenta drop, cyan face.
func _text_on(p: Vector2, s: String) -> void:
	p = p.round()
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(2, 2), Vector2(1, 2)]:
		draw_string(_font, p + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, OUTLINE)
	draw_string(_font, p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, MAGENTA)
	draw_string(_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, CYAN)


## A volume bar: `steps` segments right-aligned at `right`, the first `level` lit.
func _segments(right: Vector2, level: int, steps: int, on: bool, col: Color) -> void:
	var w := 6
	var gap := 2
	var x0 := right.x - steps * (w + gap) + gap
	for i in steps:
		var r := Rect2(x0 + i * (w + gap), right.y, w, 10)
		draw_rect(r.grow(1), OUTLINE)
		draw_rect(r, (CYAN if on else col) if i < level else TEXT_DIM.darkened(0.4))


func _arrow(p: Vector2) -> void:
	var pts := PackedVector2Array([p, p + Vector2(0, 12), p + Vector2(6, 6)])
	draw_colored_polygon(PackedVector2Array([p + Vector2(-1, -1), p + Vector2(-1, 13), p + Vector2(7, 6)]), OUTLINE)
	draw_colored_polygon(pts, CYAN)
