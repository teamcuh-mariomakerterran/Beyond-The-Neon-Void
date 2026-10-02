class_name VFXSim
extends VFXPart
## CPU particle layer drawn in _draw (deterministic, steppable, iso-aware).
##
## Emission: count, emit (0 = one burst, else seconds of continuous emission),
##   shape point | circle | ring | box | line (at→to) | disc, radius, box [w,h],
##   iso (squash y by 0.5, default true)
## Motion: dir (deg, −90 = up), spread (deg), radial (+1 outward / −1 inward),
##   speed [a,b], gravity (y or [x,y]), drag (1/s), turbulence (px/s²),
##   swirl (tangential px/s²), attract (px/s² toward attract_to anchor),
##   kill_radius, floor (bounce on the effect's ground plane y=0), floor_jitter,
##   bounce (restitution), friction, orbit {radius, speed [a,b], rise [a,b],
##   grow}, path "curve" (path_from → path_to bezier, arc, wobble)
## Look: plife [a,b] (particle seconds), size [a,b], size_curve [..],
##   stretch (velocity-aligned length per px/s), colors [..] (over life),
##   palette [..] (random per particle), fade out | in_out | flicker | late |
##   none | strobe, tex (VFX.texture kinds), render sprite | line | poly |
##   trail, width (line/trail), trail (history length), spin [a,b], align,
##   aspect (sprite h/w for non-square)

const MAX_PARTICLES := 600

class P:
	var pos: Vector2
	var vel: Vector2
	var age: float = 0.0
	var life: float = 1.0
	var size: float = 4.0
	var rot: float = 0.0
	var spin: float = 0.0
	var sd: float = 0.0
	var color: Color = Color.WHITE
	var floor_y: float = 0.0
	var resting := false
	var a0: float = 0.0  # orbit angle / curve lateral
	var r0: float = 0.0  # orbit radius
	var rise: float = 0.0
	var start: Vector2
	var hist := PackedVector2Array()
	var poly := PackedVector2Array()

var particles: Array[P] = []
var count: int = 20
var emit_time: float = 0.0
var _emitted: int = 0
var _tex: Texture2D
var _render := "sprite"
var _colors := PackedColorArray()
var _palette := PackedColorArray()
var _size_curve: Array = []
var _fade := "out"
var _gravity := Vector2.ZERO
var _floor_local := 0.0
var _attract_pt := Vector2.ZERO
var _path_a := Vector2.ZERO
var _path_b := Vector2.ZERO
var _max_plife := 1.0
var _gpu_requested := false
var _gpu: GPUParticles2D

## Use GPUParticles2D for "burst" parts even where turbulence is unsupported.
static var force_gpu := false


static func make_burst() -> VFXSim:
	var s := VFXSim.new()
	s._gpu_requested = true
	return s


## Turbulence-capable GPU particles: Forward+/Mobile with a real display.
static func gpu_available() -> bool:
	if force_gpu:
		return true
	if DisplayServer.get_name() == "headless":
		return false
	var m := RenderingServer.get_current_rendering_method()
	return m == "forward_plus" or m == "mobile"


func _setup() -> void:
	count = clampi(int(d.get("count", 20)), 1, MAX_PARTICLES)
	emit_time = num("emit", 0.0)
	_render = str(d.get("render", "sprite"))
	_tex = VFX.texture(str(d.get("tex", "core")))
	if str(d.get("tex", "")) in ["glyph", "chip", "square"]:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_colors = cols("colors", ["#ffffff"])
	if d.has("palette"):
		_palette = cols("palette")
	_size_curve = d.get("size_curve", [1.0, 1.0])
	_fade = str(d.get("fade", "out"))
	var g: Variant = d.get("gravity", 0.0)
	_gravity = vec("gravity", Vector2.ZERO) if g is Array else Vector2(0, float(g))
	_floor_local = -vec("pos", Vector2.ZERO).y + num("floor_offset", 0.0)
	_attract_pt = fx.anchor(str(d.get("attract_to", "at"))) - position + vec("attract_offset", Vector2.ZERO)
	_path_a = fx.anchor(str(d.get("path_from", "to"))) - position
	_path_b = fx.anchor(str(d.get("path_to", "at"))) - position + vec("path_offset", Vector2.ZERO)
	var pl: Variant = d.get("plife", 0.8)
	_max_plife = float(pl[1]) if pl is Array else float(pl)
	if not d.has("life"):
		life = emit_time + _max_plife
	if _gpu_requested and gpu_available():
		_build_gpu()


func _update(lt: float, dt: float) -> void:
	if _gpu:
		return
	# Emission.
	var want := count if emit_time <= 0.0 else mini(count, int(ceil(lt / emit_time * count)))
	while _emitted < want:
		_spawn()
		_emitted += 1
	# Integrate (sub-steps keep bounces stable on big dt).
	var steps := maxi(1, int(ceil(dt / 0.034)))
	var h := dt / steps
	for _s in steps:
		for p in particles:
			_integrate(p, h)
	for i in range(particles.size() - 1, -1, -1):
		if particles[i].age >= particles[i].life:
			particles.remove_at(i)


func _spawn() -> void:
	var p := P.new()
	p.sd = rng.randf() * 100.0
	p.life = rnd("plife", 0.8)
	p.size = rnd("size", 4.0)
	var off := _emit_offset()
	p.pos = off
	p.start = off
	var dir_deg := num("dir", -90.0) + rng.randf_range(-0.5, 0.5) * num("spread", 360.0)
	var dirv := Vector2.from_angle(deg_to_rad(dir_deg))
	var radial := num("radial", 0.0)
	if radial != 0.0 and off.length() > 0.001:
		var o := Vector2(off.x, off.y * (2.0 if bool(d.get("iso", true)) else 1.0)).normalized()
		dirv = (o * signf(radial)).lerp(dirv, clampf(1.0 - absf(radial), 0.0, 1.0)).normalized()
	var sp := rnd("speed", 0.0)
	p.vel = dirv * sp
	if bool(d.get("iso_vel", true)):
		p.vel.y *= lerpf(1.0, 0.55, absf(dirv.x))
	p.vel.y *= num("vy_scale", 1.0)
	p.rot = rng.randf_range(-PI, PI) if not bool(d.get("align", false)) else p.vel.angle()
	p.spin = deg_to_rad(rnd("spin", 0.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
	p.floor_y = _floor_local + rng.randf_range(-1.0, 1.0) * num("floor_jitter", 6.0)
	p.color = _palette[rng.randi() % _palette.size()] if not _palette.is_empty() else Color.WHITE
	if d.has("orbit"):
		var o: Dictionary = d["orbit"]
		p.a0 = rng.randf() * TAU if not o.has("even") else TAU * _emitted / float(count)
		p.r0 = float(o.get("radius", 30.0)) * rng.randf_range(0.85, 1.15)
		var osp: Variant = o.get("speed", 90.0)
		p.spin = deg_to_rad(rng.randf_range(float(osp[0]), float(osp[1])) if osp is Array else float(osp))
		var ri: Variant = o.get("rise", 20.0)
		p.rise = rng.randf_range(float(ri[0]), float(ri[1])) if ri is Array else float(ri)
		p.rot = 0.0
	if str(d.get("path", "")) == "curve":
		p.a0 = rng.randf_range(-1.0, 1.0)
		p.r0 = rng.randf_range(0.6, 1.4)
	if _render == "poly":
		var n := rng.randi_range(4, 7)
		for i in n:
			var ang := TAU * i / n + rng.randf_range(-0.3, 0.3)
			p.poly.append(Vector2.from_angle(ang) * rng.randf_range(0.55, 1.0) * 0.5)
	particles.append(p)


func _emit_offset() -> Vector2:
	var iso := 0.5 if bool(d.get("iso", true)) else 1.0
	var r := num("radius", 0.0)
	match str(d.get("shape", "point")):
		"circle", "disc":
			var a := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * r
			return Vector2(cos(a) * rr, sin(a) * rr * iso)
		"ring":
			var a := rng.randf() * TAU
			var rr := r * rng.randf_range(0.9, 1.1)
			return Vector2(cos(a) * rr, sin(a) * rr * iso)
		"box":
			var b := vec("box", Vector2(20, 20))
			var fy := rng.randf()
			if num("sweep", 0.0) != 0.0 and count > 1:
				# Emission sweeps top → bottom (disintegration) or bottom → top.
				var prog := float(_emitted) / (count - 1)
				fy = clampf((1.0 - prog if num("sweep", 0.0) > 0.0 else prog) + rng.randf_range(-0.06, 0.06), 0.0, 1.0)
			return Vector2(rng.randf_range(-0.5, 0.5) * b.x, -fy * b.y)
		"line":
			var to := fx.anchor("to") - position
			return to * rng.randf() + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * r
	return Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * r


func _integrate(p: P, h: float) -> void:
	p.age += h
	if d.has("orbit"):
		var o: Dictionary = d["orbit"]
		var grow := float(o.get("grow", 0.0))
		var ang := p.a0 + p.spin * p.age
		var r := p.r0 + grow * p.age
		p.pos = Vector2(cos(ang) * r, sin(ang) * r * 0.5 - p.rise * p.age)
		p.vel = Vector2(-sin(ang), cos(ang) * 0.5) * r * p.spin
		p.rot = 0.0
		_record(p)
		return
	if str(d.get("path", "")) == "curve":
		var u := clampf(p.age / p.life, 0.0, 1.0)
		var ue := u * u * (3.0 - 2.0 * u)
		var mid := (_path_a + _path_b) * 0.5
		var perp := (_path_b - _path_a).orthogonal().normalized()
		var ctrl := mid + perp * num("arc", 60.0) * p.a0 + Vector2(0, -num("lift", 40.0))
		var q := _path_a.lerp(ctrl, ue).lerp(ctrl.lerp(_path_b, ue), ue)
		var wob := sin(p.age * 14.0 + p.sd) * num("wobble", 6.0) * p.r0 * sin(u * PI)
		var np := q + perp * wob
		p.vel = (np - p.pos) / maxf(h, 0.0001)
		p.pos = np
		_record(p)
		return
	if p.resting:
		p.vel.x *= maxf(0.0, 1.0 - num("friction_ground", 6.0) * h)
		p.pos.x += p.vel.x * h
		return
	var acc := _gravity
	var turb := num("turbulence", 0.0)
	if turb > 0.0:
		acc += Vector2(sin(p.age * 5.3 + p.sd * 1.7) + sin(p.age * 11.1 + p.sd), cos(p.age * 4.7 + p.sd * 2.3) + sin(p.age * 9.7 - p.sd)) * turb * 0.5
	var sw := num("swirl", 0.0)
	var to_c := _attract_pt - p.pos
	if sw != 0.0 and to_c.length() > 0.5:
		acc += to_c.normalized().orthogonal() * sw
	var att := num("attract", 0.0)
	if att != 0.0:
		var dist := to_c.length()
		acc += to_c / maxf(dist, 1.0) * att * (1.0 + 60.0 / maxf(dist, 10.0))
		if dist < num("kill_radius", 4.0):
			p.age = p.life
	p.vel += acc * h
	var drag := num("drag", 0.0)
	if drag > 0.0:
		p.vel *= exp(-drag * h)
	p.pos += p.vel * h
	p.rot += p.spin * h
	if bool(d.get("align", false)) and p.vel.length_squared() > 1.0:
		p.rot = p.vel.angle()
	if bool(d.get("floor", false)) and p.pos.y > p.floor_y and p.vel.y > 0.0:
		p.pos.y = p.floor_y
		if bool(d.get("floor_kill", false)):
			p.age = p.life
			return
		var b := num("bounce", 0.4)
		p.vel.y = -p.vel.y * b * rng.randf_range(0.7, 1.1)
		p.vel.x *= num("friction", 0.7)
		p.spin *= 0.6
		if absf(p.vel.y) < 25.0:
			p.vel.y = 0.0
			p.resting = true
	_record(p)


func _record(p: P) -> void:
	if _render != "trail":
		return
	p.hist.append(p.pos)
	var n := int(d.get("trail", 8))
	if p.hist.size() > n:
		p.hist.remove_at(0)


func _alpha(p: P, u: float) -> float:
	match _fade:
		"none": return 1.0
		"in_out": return clampf(u * 6.0, 0.0, 1.0) * clampf((1.0 - u) * 3.0, 0.0, 1.0)
		"late": return clampf((1.0 - u) * 5.0, 0.0, 1.0)
		"flicker": return (1.0 - u) * (0.55 + 0.45 * sin(p.age * 38.0 + p.sd * 7.0))
		"strobe": return (1.0 - u * u) * (1.0 if fmod(p.age * 14.0 + p.sd, 1.0) < 0.6 else 0.15)
		"pop": return clampf(u * 12.0, 0.0, 1.0) * pow(1.0 - u, 1.5)
	return pow(1.0 - u, 1.3)


func _size_at(u: float) -> float:
	var n := _size_curve.size()
	if n == 0:
		return 1.0
	if n == 1:
		return float(_size_curve[0])
	var f := u * (n - 1)
	var i := mini(int(f), n - 2)
	return lerpf(float(_size_curve[i]), float(_size_curve[i + 1]), f - i)


func _draw() -> void:
	if _gpu or particles.is_empty():
		return
	var tw := float(_tex.get_width())
	var th := float(_tex.get_height())
	var stretch := num("stretch", 0.0)
	var width := num("width", 2.0)
	var aspect := num("aspect", th / tw)
	for p in particles:
		var u := clampf(p.age / p.life, 0.0, 1.0)
		var c := sample(_colors, u)
		if not _palette.is_empty():
			c = Color(p.color.r * c.r, p.color.g * c.g, p.color.b * c.b, p.color.a * c.a)
		c.a *= _alpha(p, u)
		if c.a <= 0.003:
			continue
		var sz := p.size * _size_at(u)
		match _render:
			"line":
				var dirn := p.vel.normalized() if p.vel.length_squared() > 1.0 else Vector2.DOWN
				var ln := sz + p.vel.length() * stretch
				draw_line(p.pos - dirn * ln, p.pos, c, width * _size_at(u))
			"trail":
				if p.hist.size() >= 2:
					var cs := PackedColorArray()
					for i in p.hist.size():
						var f := float(i + 1) / p.hist.size()
						cs.append(Color(c.r, c.g, c.b, c.a * f * f))
					draw_polyline_colors(p.hist, cs, width * _size_at(u))
				draw_set_transform(p.pos, 0.0, Vector2(sz / tw, sz / tw))
				draw_texture(_tex, -Vector2(tw, th) * 0.5, c)
				draw_set_transform(Vector2.ZERO)
			"poly":
				draw_set_transform(p.pos, p.rot, Vector2(sz, sz * 0.8))
				draw_colored_polygon(p.poly, c)
				var edge := Color(minf(c.r * 1.8 + 0.15, 4.0), minf(c.g * 1.8 + 0.15, 4.0), minf(c.b * 1.8 + 0.15, 4.0), c.a)
				draw_polyline(PackedVector2Array([p.poly[0], p.poly[1], p.poly[2]]), edge, 1.2 / maxf(sz, 1.0))
				draw_set_transform(Vector2.ZERO)
			_:
				var sx := sz / tw
				var sy := sz * aspect / th
				var rot := p.rot
				if stretch > 0.0:
					var v := p.vel.length()
					sy = (sz * aspect + v * stretch) / th
					rot = p.vel.angle() - PI * 0.5 if v > 1.0 else p.rot
				elif bool(d.get("align", false)):
					rot = p.rot - PI * 0.5
				draw_set_transform(p.pos, rot, Vector2(sx, sy))
				draw_texture(_tex, -Vector2(tw, th) * 0.5, c)
	draw_set_transform(Vector2.ZERO)


# --- GPU burst ---------------------------------------------------------------

func _build_gpu() -> void:
	var g := GPUParticles2D.new()
	g.name = "GPU"
	g.amount = count
	g.one_shot = true
	g.explosiveness = 1.0 if emit_time <= 0.0 else 0.0
	g.lifetime = maxf(_max_plife, 0.05) + (emit_time if emit_time > 0.0 else 0.0)
	g.local_coords = true
	g.texture = _tex
	g.visibility_rect = Rect2(-400, -400, 800, 800)
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true
	var dir_deg := num("dir", -90.0)
	m.direction = Vector3(cos(deg_to_rad(dir_deg)), sin(deg_to_rad(dir_deg)), 0)
	m.spread = num("spread", 360.0) * 0.5
	var sp: Variant = d.get("speed", 0.0)
	m.initial_velocity_min = float(sp[0]) if sp is Array else float(sp)
	m.initial_velocity_max = float(sp[1]) if sp is Array else float(sp)
	m.gravity = Vector3(_gravity.x, _gravity.y, 0)
	m.damping_min = num("drag", 0.0) * 40.0
	m.damping_max = num("drag", 0.0) * 60.0
	var r := num("radius", 0.0)
	if r > 0.0:
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = r
	var turb := num("turbulence", 0.0)
	if turb > 0.0 and RenderingServer.get_current_rendering_method() != "gl_compatibility":
		m.turbulence_enabled = true
		m.turbulence_noise_strength = clampf(turb / 100.0, 0.2, 8.0)
		m.turbulence_noise_scale = 3.0
		m.turbulence_influence_min = 0.05
		m.turbulence_influence_max = 0.25
	var tw := float(maxi(_tex.get_width(), 1))
	var sz: Variant = d.get("size", 4.0)
	m.scale_min = (float(sz[0]) if sz is Array else float(sz)) / tw
	m.scale_max = (float(sz[1]) if sz is Array else float(sz)) / tw
	var ramp := Gradient.new()
	ramp.remove_point(1)
	ramp.set_color(0, _colors[0])
	for i in range(1, maxi(_colors.size(), 2)):
		var c := _colors[mini(i, _colors.size() - 1)]
		var off := float(i) / maxf(_colors.size() - 1, 1)
		if i == _colors.size() - 1 or _colors.size() == 1:
			c.a = 0.0
		ramp.add_point(off, c)
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	gt.use_hdr = true
	m.color_ramp = gt
	m.angle_min = -180.0
	m.angle_max = 180.0
	g.process_material = m
	add_child(g)
	_gpu = g
