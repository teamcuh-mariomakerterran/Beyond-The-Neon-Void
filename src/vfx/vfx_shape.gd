class_name VFXShape
extends VFXPart
## Procedurally drawn layers (type picks the look):
##  flash    size, squash, colors [..], attack, rays (count), ray_len, ray_width
##  streaks  count, len [a,b], width, colors, spread (deg), dir — speed lines
##  ring     r0, r1, width, count, stagger, squash, colors, dashes, rotate
##  pillar   width, height, colors [outer, core], base (ellipse radius)
##  decal    radius, squash, color (burn), ember (hot rim colour), ember_time
##  tear     size [w,h], colors [edge1, edge2, inside], open, close
##  scan     box [w,h], colors [wire, scan], sweeps
## All share palette colours, delay/life and the additive default blend
## (decals default to mix).

var _type := "flash"
var _soft: Texture2D
var _seeds := PackedFloat32Array()


func default_blend() -> String:
	return "mix" if str(d.get("type", "")) == "decal" else "add"


func _setup() -> void:
	_type = str(d.get("type", "flash"))
	_soft = VFX.texture("core")
	for i in 64:
		_seeds.append(rng.randf())
	if _type == "decal":
		# Decals sit on the floor: below the effect (and units if floor_z given).
		if fx.params.has("floor_z"):
			z_as_relative = false
			z_index = int(fx.params["floor_z"])
		elif not d.has("z"):
			z_index = -2


func _draw() -> void:
	if t < 0.0:
		return
	match _type:
		"flash": _draw_flash()
		"streaks": _draw_streaks()
		"ring": _draw_ring()
		"pillar": _draw_pillar()
		"decal": _draw_decal()
		"tear": _draw_tear()
		"scan": _draw_scan()


func _draw_flash() -> void:
	var e := envelope(num("attack", 0.03), num("power", 2.0))
	var stops := cols("colors", ["$main", "#ffffff*3"])
	var size := num("size", 60.0) * lerpf(0.7, 1.15, minf(t / maxf(num("attack", 0.03) * 3.0, 0.001), 1.0))
	var sq := num("squash", 0.7)
	for i in stops.size():
		var c := stops[i]
		c.a *= e
		var s := size * lerpf(1.0, 0.35, float(i) / maxf(stops.size() - 1, 1))
		draw_texture_rect(_soft, Rect2(-Vector2(s, s * sq), Vector2(s * 2, s * 2 * sq)), false, c)
	var rays := int(num("rays", 0))
	if rays > 0:
		var star := VFX.texture("star")
		var rl := num("ray_len", size * 2.2) * lerpf(0.6, 1.0, e)
		var c2 := stops[stops.size() - 1]
		c2.a *= e
		draw_texture_rect(star, Rect2(-Vector2(rl, rl * 0.55), Vector2(rl * 2, rl * 1.1)), false, c2)
		for r in rays:
			var ang := TAU * r / rays + _seeds[r] * 0.6 + t * num("ray_spin", 0.0)
			var ln := rl * lerpf(0.5, 1.0, _seeds[r + 8])
			var dirv := Vector2(cos(ang), sin(ang) * sq)
			var w := num("ray_width", 3.0) * e
			var tip := dirv * ln
			var side := dirv.orthogonal().normalized() * w
			draw_colored_polygon(PackedVector2Array([side, tip, -side, -dirv * w]), c2)


func _draw_streaks() -> void:
	var e := envelope(num("attack", 0.02), 1.2)
	var stops := cols("colors", ["#ffffff*2"])
	var n := int(num("count", 10))
	var base_dir := num("dir", 0.0)
	var spread := num("spread", 360.0)
	var lr := vec("len", Vector2(40, 90))
	var travel := num("travel", 40.0)
	for i in mini(n, 32):
		var ang := deg_to_rad(base_dir + (_seeds[i] - 0.5) * spread)
		var dirv := Vector2(cos(ang), sin(ang) * num("squash", 0.6))
		var ln := lerpf(lr.x, lr.y, _seeds[i + 32])
		var start := dirv * (num("inner", 10.0) + travel * k())
		var c := sample(stops, _seeds[i])
		c.a *= e
		var w := num("width", 2.5)
		var side := dirv.orthogonal().normalized() * w * 0.5
		var tip := start + dirv * ln * lerpf(1.0, 0.4, k())
		draw_colored_polygon(PackedVector2Array([start + side, tip, start - side]), c)


func _draw_ring() -> void:
	var n := int(num("count", 1))
	var stops := cols("colors", ["$main", "#ffffff*2"])
	var sq := num("squash", 0.5)
	var dashes := int(num("dashes", 0))
	for i in n:
		var lt := t - i * num("stagger", 0.08)
		if lt < 0.0:
			continue
		var u := clampf(lt / maxf(life - i * num("stagger", 0.08), 0.01), 0.0, 1.0)
		var ease_u := 1.0 - pow(1.0 - u, num("ease", 3.0))
		var r := lerpf(num("r0", 4.0), num("r1", 80.0), ease_u)
		var c := sample(stops, u)
		c.a *= pow(1.0 - u, num("power", 1.2)) * clampf(lt / 0.03, 0.0, 1.0)
		var w := num("width", 4.0) * lerpf(1.0, num("thin", 0.3), u)
		var segs := 48
		var rot := num("rotate", 0.0) * lt
		if dashes > 0:
			for s in dashes:
				var a0 := TAU * s / dashes + rot
				var a1 := a0 + TAU / dashes * num("dash_fill", 0.55)
				_arc(r, sq, a0, a1, 6, c, w)
		else:
			_arc(r, sq, 0.0, TAU, segs, c, w)
		if bool(d.get("fill", false)):
			var fc := Color(c.r, c.g, c.b, c.a * 0.18)
			var poly := PackedVector2Array()
			for s in segs:
				var a := TAU * s / segs
				poly.append(Vector2(cos(a) * r, sin(a) * r * sq))
			draw_colored_polygon(poly, fc)


func _arc(r: float, sq: float, a0: float, a1: float, segs: int, c: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for s in segs + 1:
		var a := lerpf(a0, a1, float(s) / segs)
		pts.append(Vector2(cos(a) * r, sin(a) * r * sq))
	draw_polyline(pts, c, w)


func _draw_pillar() -> void:
	var e := envelope(num("attack", 0.08), 1.0)
	var stops := cols("colors", ["$main", "#ffffff*3"])
	var beam := VFX.texture("beam")
	var h := num("height", 220.0) * lerpf(0.3, 1.0, minf(t / maxf(num("attack", 0.08) * 2.0, 0.01), 1.0))
	var w := num("width", 40.0)
	var pulse := 1.0 + 0.12 * sin(t * 30.0)
	var outer := stops[0]
	outer.a *= e
	draw_texture_rect(beam, Rect2(-w * pulse, -h, w * 2 * pulse, h), false, outer)
	var core := stops[stops.size() - 1]
	core.a *= e
	var cw := w * 0.32 * lerpf(1.6, 0.6, k())
	draw_texture_rect(beam, Rect2(-cw, -h * 0.98, cw * 2, h * 0.98), false, core)
	var br := num("base", w * 1.4)
	draw_texture_rect(_soft, Rect2(-br, -br * 0.4, br * 2, br * 0.8), false, outer)


func _draw_decal() -> void:
	var tex := VFX.texture("scorch")
	var r := num("radius", 40.0) * lerpf(0.6, 1.0, minf(t / 0.08, 1.0))
	var sq := num("squash", 0.5)
	var fade := clampf((life - t) / maxf(num("fade", 1.0), 0.01), 0.0, 1.0)
	var c := col("color", "#0a0610")
	c.a *= fade * num("alpha", 0.85)
	draw_texture_rect(tex, Rect2(-r, -r * sq, r * 2, r * 2 * sq), false, c)
	var et := num("ember_time", 1.2)
	if t < et:
		var ec := col("ember", "$main")
		var ek := pow(1.0 - t / et, 1.5)
		ec.a *= ek
		# Glowing ring of embers along the burn's rim.
		for i in 18:
			var a := TAU * i / 18.0 + _seeds[i] * 0.3
			var rr := r * lerpf(0.55, 0.95, _seeds[i + 18])
			var p := Vector2(cos(a) * rr, sin(a) * rr * sq)
			var s := lerpf(2.0, 5.0, _seeds[i + 36]) * (0.6 + 0.4 * ek)
			draw_texture_rect(_soft, Rect2(p - Vector2(s, s), Vector2(s * 2, s * 2)), false, ec)
		var inner := ec
		inner.a *= 0.35
		draw_texture_rect(_soft, Rect2(-r * 0.7, -r * 0.7 * sq, r * 1.4, r * 1.4 * sq), false, inner)


func _draw_tear() -> void:
	var size := vec("size", Vector2(46, 90))
	var open_t := num("open", 0.18)
	var close_t := num("close", 0.25)
	var o := minf(t / open_t, 1.0)
	o = 1.0 - pow(1.0 - o, 3.0)
	if t > life - close_t:
		o *= clampf((life - t) / close_t, 0.0, 1.0)
	var stops := cols("colors", ["#ff2e88*2.5", "#3fd2ff*2.5", "#06000c"])
	var h := size.y * o
	var w := size.x * lerpf(0.15, 1.0, o)
	var rows := 18
	var frame := int(t * 24.0)
	var inside := stops[mini(2, stops.size() - 1)]
	for r in rows:
		var y0 := -h * float(r + 1) / rows
		var rh := h / rows + 0.5
		var jit := sin(float(frame * 7 + r * 13)) * 0.5 + 0.5
		var shift := (jit - 0.5) * w * 0.35 if fmod(jit * 10.0, 1.0) < 0.45 else 0.0
		var rw := w * (0.6 + 0.4 * sin(float(r) / rows * PI))
		var x0 := -rw * 0.5 + shift
		var ic := inside
		ic.a *= 0.92
		draw_rect(Rect2(x0, y0, rw, rh), ic)
		var e1 := stops[0]
		var e2 := stops[mini(1, stops.size() - 1)]
		draw_rect(Rect2(x0 - 3, y0, 3, rh), e1)
		draw_rect(Rect2(x0 + rw, y0, 3, rh), e2)
		if jit > 0.82:
			var bar := e2 if r % 2 == 0 else e1
			bar.a *= 0.6
			draw_rect(Rect2(x0 - rw * 0.4, y0, rw * 1.8, 2), bar)
	# Glow behind the slit + scanlines inside.
	var gc := stops[0]
	gc.a *= 0.35 * o
	draw_texture_rect(_soft, Rect2(-w * 1.6, -h * 1.15, w * 3.2, h * 1.3), false, gc)
	var sl := stops[mini(1, stops.size() - 1)]
	sl.a *= 0.25
	for i in int(h / 4.0):
		draw_line(Vector2(-w * 0.3, -i * 4.0), Vector2(w * 0.3, -i * 4.0), sl, 1.0)


func _draw_scan() -> void:
	var box := vec("box", Vector2(44, 56))
	var stops := cols("colors", ["#3fd2ff*2", "#39ff9f*3"])
	var hw := box.x * 0.5
	var hh := box.x * 0.25
	var build := minf(t / (life * 0.6), 1.0)
	var top := -box.y * build
	var fade := clampf((life - t) / 0.25, 0.0, 1.0)
	var wire := stops[0]
	wire.a *= fade
	var n := Vector2(0, -hh)
	var e := Vector2(hw, 0)
	var s := Vector2(0, hh)
	var w := Vector2(-hw, 0)
	var base := PackedVector2Array([n, e, s, w, n])
	draw_polyline(base, wire, 1.5)
	var up := Vector2(0, top)
	for p in [n, e, s, w]:
		draw_line(p, p + up, wire, 1.5)
	if build >= 1.0:
		var tp := PackedVector2Array([n + up, e + up, s + up, w + up, n + up])
		draw_polyline(tp, wire, 1.5)
	# Scan plane sweeping up and down.
	var sweeps := num("sweeps", 2.0)
	var ph := 0.5 - 0.5 * cos(t / life * TAU * sweeps)
	var y := -box.y * ph
	var sc := stops[mini(1, stops.size() - 1)]
	sc.a *= fade
	var plane := PackedVector2Array([n + Vector2(0, y), e + Vector2(0, y), s + Vector2(0, y), w + Vector2(0, y)])
	var fill := Color(sc.r, sc.g, sc.b, sc.a * 0.18)
	draw_colored_polygon(plane, fill)
	plane.append(plane[0])
	draw_polyline(plane, sc, 2.0)
	# Hologram fill: horizontal scanlines inside the built part.
	var hl := Color(wire.r, wire.g, wire.b, wire.a * 0.12)
	var yy := 0.0
	while yy > top:
		draw_line(w + Vector2(0, yy), e + Vector2(0, yy), hl, 1.0)
		yy -= 4.0
