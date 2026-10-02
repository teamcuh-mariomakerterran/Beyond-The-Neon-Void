class_name AdditionWidget
extends CanvasLayer
## The Addition prompt: a square closes onto the target square in time with
## each beat — press confirm (Space / Enter / click / A) as they meet.
## Await `run()`; it returns how many beats were hit.

signal done(hits: int)

const LEAD := 0.55  # seconds the closing square is visible before its beat
const START_DELAY := 0.7

var ability: Ability
var level: int = 1
var hits: int = 0
var _beats: Array = []
var _t0: float = 0.0
var _next: int = 0
var _over: bool = false
var _flash: Array = []  # [{text, color, t}]
var _canvas: Control


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func run(p_ability: Ability, p_level: int) -> int:
	ability = p_ability
	level = p_level
	_beats = Additions.beats(ability)
	layer = 90
	_canvas = Panel.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.0)
	_canvas.add_theme_stylebox_override("panel", sb)
	_canvas.draw.connect(_draw_widget)
	add_child(_canvas)
	_t0 = now() + START_DELAY
	await done
	return hits


func _process(_d: float) -> void:
	if _canvas:
		_canvas.queue_redraw()
	if _over:
		return
	var t := now() - _t0
	# Let a beat pass without a press → the chain ends.
	if _next < _beats.size() and t > float(_beats[_next]) + Additions.window(ability, level):
		_end("MISS", NeonTheme.MAGENTA)


func _unhandled_input(event: InputEvent) -> void:
	if _over:
		return
	var pressed := event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	press(now() - _t0)


## One press at chain time `t` (public for tests).
func press(t: float) -> void:
	if _over:
		return
	if Additions.judge(ability, level, _next, t) >= 0:
		hits += 1
		_next += 1
		_flash.append({"text": "×%d" % hits, "color": NeonTheme.GREEN, "t": now()})
		if _next >= _beats.size():
			_end("FINAL CUT!" if _beats.size() >= 6 else "PERFECT", NeonTheme.CYAN)
	else:
		_end("TOO EARLY" if t < float(_beats[mini(_next, _beats.size() - 1)]) else "MISS", NeonTheme.MAGENTA)


func _end(text: String, color: Color) -> void:
	_over = true
	_flash.append({"text": text, "color": color, "t": now()})
	await get_tree().create_timer(0.55).timeout
	done.emit(hits)
	queue_free()


func _draw_widget() -> void:
	var c := _canvas
	var size := c.size
	var center := size * Vector2(0.5, 0.42)
	var t := now() - _t0
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.05, 0.45))
	var font := NeonTheme.mono()
	c.draw_string(font, center + Vector2(-300, -170), ability.display_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 600, 30, NeonTheme.CYAN)
	# Beat pips along the bottom: hit / pending / missed.
	var n := _beats.size()
	for i in n:
		var p := center + Vector2((i - (n - 1) * 0.5) * 34.0, 150)
		var col := NeonTheme.GREEN if i < hits else (Color(1, 1, 1, 0.25) if not _over else Color(NeonTheme.MAGENTA, 0.4))
		c.draw_circle(p, 9, col)
	# Target square + the closing square for the current beat.
	var base := 70.0
	var target := Rect2(center - Vector2(base, base) * 0.5, Vector2(base, base))
	c.draw_rect(target, Color(1.6, 1.6, 1.8, 0.9), false, 3.0)
	if not _over and _next < n:
		var dt := float(_beats[_next]) - t
		if dt < LEAD:
			var k := clampf(dt / LEAD, -0.3, 1.0)
			var s := base * (1.0 + 2.2 * maxf(k, 0.0))
			var col2 := NeonTheme.GREEN if absf(dt) <= Additions.window(ability, level) else NeonTheme.MAGENTA
			c.draw_rect(Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), Color(col2, 0.95), false, 4.0)
	# Feedback words.
	var y := 0.0
	for f: Dictionary in _flash:
		var age := now() - float(f["t"])
		if age < 0.8:
			c.draw_string(font, center + Vector2(-200, 110 - age * 40 - y), str(f["text"]), HORIZONTAL_ALIGNMENT_CENTER, 400, 34, Color(f["color"], 1.0 - age / 0.8))
	c.draw_string(font, center + Vector2(-300, 200), "SPACE / ENTER / CLICK when the squares meet", HORIZONTAL_ALIGNMENT_CENTER, 600, 14, NeonTheme.TEXT_DIM)
