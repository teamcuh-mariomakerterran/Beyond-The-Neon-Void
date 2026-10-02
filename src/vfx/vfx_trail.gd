class_name VFXTrail
extends VFXPart
## Projectile: a glowing head flies from the anchor to "to" along an arc and
## leaves a Line2D ribbon that tapers and fades. On arrival the effect emits
## `impacted`. Keys: travel (s), arc (px of lob), wiggle (px), wiggle_freq,
## width, colors [tail .. head], head (px), head_colors, ribbon (points kept),
## fade (s the ribbon lingers after arrival), spin_ribbon (helix offset).

var line: Line2D
var line2: Line2D
var _to := Vector2.ZERO
var _head := Vector2.ZERO
var _arrived := false
var _since_arrival := 0.0
var _soft: Texture2D
var _points := PackedVector2Array()
var _points2 := PackedVector2Array()


func _setup() -> void:
	_to = fx.anchor(str(d.get("to", "to"))) - position + vec("to_offset", Vector2.ZERO)
	_soft = VFX.texture("core")
	if not d.has("life"):
		life = num("travel", 0.3) + num("fade", 0.3)
	line = _make_line(num("width", 8.0), cols("colors", ["$main*0.0", "$main", "#ffffff*3"]))
	if num("spin_ribbon", 0.0) > 0.0:
		line2 = _make_line(num("width", 8.0) * 0.6, cols("colors2", ["$main*0.0", "$alt", "#ffffff*2"]))


func _make_line(w: float, stops: PackedColorArray) -> Line2D:
	var l := Line2D.new()
	l.width = w
	var wc := Curve.new()
	wc.add_point(Vector2(0, 0.0))
	wc.add_point(Vector2(0.7, 0.7))
	wc.add_point(Vector2(1, 1))
	l.width_curve = wc
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	for i in stops.size():
		offs.append(float(i) / maxf(stops.size() - 1, 1))
	g.offsets = offs
	g.colors = stops
	l.gradient = g
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.texture_mode = Line2D.LINE_TEXTURE_NONE
	l.antialiased = false
	if material:
		l.material = material
	add_child(l)
	return l


func _pos_at(u: float) -> Vector2:
	var p := Vector2.ZERO.lerp(_to, u)
	p.y -= sin(u * PI) * num("arc", 0.0)
	var perp := _to.orthogonal().normalized()
	p += perp * sin(u * PI * num("wiggle_freq", 3.0)) * num("wiggle", 0.0) * sin(u * PI)
	return p


func _update(lt: float, dt: float) -> void:
	var travel := num("travel", 0.3)
	var u := clampf(lt / travel, 0.0, 1.0)
	var keep := int(num("ribbon", 14))
	if not _arrived:
		# Sub-sample so fast bolts still leave a smooth ribbon.
		var sub := 3
		for i in sub:
			var uu := clampf((lt - dt * (sub - 1 - i) / sub) / travel, 0.0, 1.0)
			var hp := _pos_at(uu)
			_points.append(hp)
			if line2:
				var ph := lt * 40.0 + i * 0.3
				_points2.append(hp + _to.orthogonal().normalized() * sin(ph) * num("spin_ribbon", 6.0))
		_head = _pos_at(u)
		if u >= 1.0:
			_arrived = true
	else:
		_since_arrival += dt
		keep = int(keep * clampf(1.0 - _since_arrival / maxf(num("fade", 0.3), 0.01), 0.0, 1.0))
	while _points.size() > maxi(keep, 0):
		_points.remove_at(0)
	while _points2.size() > maxi(keep, 0):
		_points2.remove_at(0)
	line.points = _points
	if line2:
		line2.points = _points2


func _draw() -> void:
	if _arrived or t < 0.0:
		return
	var hs := num("head", 14.0)
	var hc := cols("head_colors", ["$main", "#ffffff*3"])
	for i in hc.size():
		var s := hs * lerpf(1.0, 0.4, float(i) / maxf(hc.size() - 1, 1)) * (0.9 + 0.2 * sin(t * 50.0))
		draw_texture_rect(_soft, Rect2(_head - Vector2(s, s), Vector2(s * 2, s * 2)), false, hc[i])
