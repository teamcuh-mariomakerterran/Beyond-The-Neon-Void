class_name VFXLightning
extends VFXPart
## Jagged, branching electric arcs, re-randomised every `refresh` seconds.
## Keys: to ("to" anchor | "chain" = every params.targets in turn | [x,y]
## offset), jag (displacement, fraction of length), detail (subdivisions),
## branches, branch_len, refresh (s), widths [glow, mid, core],
## colors [glow, mid, core], hop_delay (chain), flicker (0..1), end_glow (px).

var _bolts: Array[PackedVector2Array] = []
var _branches: Array[PackedVector2Array] = []
var _since := 999.0
var _hops: Array[Vector2] = []
var _cols := PackedColorArray()
var _widths := PackedFloat32Array()
var _glow_tex: Texture2D


func _setup() -> void:
	_cols = cols("colors", ["$main*0.6", "$main", "#ffffff*3"])
	var w: Variant = d.get("widths", [14.0, 5.0, 1.8])
	for x: Variant in w:
		_widths.append(float(x))
	while _widths.size() < 3:
		_widths.append(1.0)
	while _cols.size() < 3:
		_cols.append(_cols[_cols.size() - 1])
	_glow_tex = VFX.texture("core")
	_hops.append(Vector2.ZERO)
	var to: Variant = d.get("to", "to")
	if to is Array:
		_hops.append(vec("to", Vector2(140, -20)))
	elif str(to) == "chain":
		for tl in fx.targets_local:
			_hops.append(tl - position)
		if _hops.size() == 1:
			_hops.append(fx.target_local - position)
	else:
		_hops.append(fx.anchor(str(to)) - position + vec("to_offset", Vector2.ZERO))


func _update(_lt: float, dt: float) -> void:
	_since += dt
	if _since >= num("refresh", 0.033) or _bolts.is_empty():
		_since = 0.0
		_regen()


## How many hops are lit by now.
func _hops_lit() -> int:
	var hd := num("hop_delay", 0.0)
	if hd <= 0.0:
		return _hops.size() - 1
	return clampi(int(t / hd) + 1, 1, _hops.size() - 1)


func _regen() -> void:
	_bolts.clear()
	_branches.clear()
	for i in _hops_lit():
		var a := _hops[i]
		var b := _hops[i + 1]
		var pts := _jagged(a, b, num("jag", 0.18), int(num("detail", 5)))
		_bolts.append(pts)
		for j in int(num("branches", 2)):
			if pts.size() < 4:
				break
			var start := pts[rng.randi_range(1, pts.size() - 3)]
			var dirv := (b - a).normalized().rotated(rng.randf_range(-1.1, 1.1))
			var blen := (b - a).length() * num("branch_len", 0.3) * rng.randf_range(0.5, 1.0)
			_branches.append(_jagged(start, start + dirv * blen, num("jag", 0.18) * 1.3, 3))


## Midpoint displacement between a and b.
func _jagged(a: Vector2, b: Vector2, jag: float, detail: int) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	var amp := (b - a).length() * jag
	for _l in detail:
		var np := PackedVector2Array()
		for i in pts.size() - 1:
			var p := pts[i]
			var q := pts[i + 1]
			np.append(p)
			var n := (q - p).orthogonal().normalized()
			np.append((p + q) * 0.5 + n * rng.randf_range(-amp, amp))
		np.append(pts[pts.size() - 1])
		pts = np
		amp *= 0.55
	return pts


func _draw() -> void:
	if _bolts.is_empty():
		return
	var e := envelope(num("attack", 0.03), 1.0)
	var fl := num("flicker", 0.35)
	e *= 1.0 - fl + fl * (0.5 + 0.5 * sin(t * 90.0 + rng.randf() * 3.0))
	for pass_i in 3:
		var c := _cols[pass_i]
		c.a *= e
		for b in _bolts:
			draw_polyline(b, c, _widths[pass_i])
		c.a *= 0.7
		for br in _branches:
			draw_polyline(br, c, _widths[pass_i] * 0.55)
	var eg := num("end_glow", 26.0)
	if eg > 0.0:
		var gc := _cols[1]
		gc.a *= e * 0.9
		for i in _hops_lit() + 1:
			var r := eg * (1.4 if i > 0 else 1.0) * (0.85 + rng.randf() * 0.3)
			draw_texture_rect(_glow_tex, Rect2(_hops[i] - Vector2(r, r * 0.8), Vector2(r * 2, r * 1.6)), false, gc)
		var core := _cols[2]
		core.a *= e
		for i in _hops_lit() + 1:
			var r2 := eg * 0.35
			draw_texture_rect(_glow_tex, Rect2(_hops[i] - Vector2(r2, r2), Vector2(r2 * 2, r2 * 2)), false, core)
