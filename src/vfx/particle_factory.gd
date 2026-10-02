class_name ParticleFactory
extends RefCounted
## Builds weather / ambience emitters from the presets in data/particles.json.
##
## Presets are painted onto map cells at a stack layer (fog at layers 1-3
## hugging mountain tops, storm clouds at layer 15...). The renderer merges
## neighbouring cells of the same preset/layer and calls make_for_cells() with
## the top-face diamonds of those cells; the returned Node2D holds one or more
## CPUParticles2D (CPU so gl_compatibility screenshots and old GPUs match).
##
## Preset keys (all optional except kind; see data/particles.json):
##   name, kind, color, color2       tint picked randomly between color..color2
##   amount                          particles per cell (total capped at MAX_AMOUNT)
##   lifetime, speed, spread, size   seconds, px/s, degrees, px (at tile_width 128)
##   gravity                         px/s², negative rises
##   fall_from                       px above the cells where falling kinds spawn
##   glow                            HDR multiplier (>1 blooms with hdr_2d)
##   texture                         res:// path; else a generated texture_kind
##   texture_kind                    soft | streak | square | cloud | mist | puff | ring
##   direction [x, y], alpha, align, blend (mix|add), explosiveness, damping,
##   spin (deg/s), fade (in_out|out|out_late|flicker_out|pulse|glitch),
##   scale_curve (flat|grow|grow_slight|shrink), rise (px band above the cell),
##   wander (px/s² tangential jitter), center (emit from cell centre only),
##   splash (rain: ground splash rings), lightning (storm flashes)
## Juice keys:
##   turbulence (px/s²; real GPU turbulence on Forward+/Mobile, CPU jitter
##   fallback on gl_compatibility / headless), wind [x, y] (px/s², gusting;
##   plus the global ParticleFactory.wind), depth (bool: a smaller, dimmer,
##   slower far layer behind the near one = parallax), stretch (streak length
##   per px/s of fall speed), droplets (rain: bouncing ground droplets),
##   lights (n tiny wandering PointLight2D wisps: fireflies, data motes),
##   fog_sheet (drifting noise-textured fog over the cells), flash_light
##   (storm lightning lights the area; default on with lightning)

const DATA_PATH := "res://data/particles.json"
const MAX_AMOUNT := 600
const MAX_POINTS := 2400
## Sizes/speeds in the presets are authored for this tile width.
const BASE_TILE_W := 128.0

const DEFAULTS := {
	"name": "", "kind": "custom", "color": "#ffffff", "color2": "", "amount": 6,
	"lifetime": 2.0, "speed": 30.0, "spread": 20.0, "size": 8.0, "gravity": 0.0,
	"fall_from": 0.0, "glow": 1.0, "texture": "", "texture_kind": "soft",
	"direction": [0, 1], "alpha": 1.0, "align": false, "blend": "mix",
	"explosiveness": 0.0, "damping": 0.0, "spin": 0.0, "fade": "in_out",
	"scale_curve": "flat", "rise": 0.0, "wander": 0.0, "center": false,
	"splash": false, "lightning": false,
	"turbulence": 0.0, "wind": [0, 0], "depth": false, "stretch": 0.0,
	"droplets": false, "lights": 0, "fog_sheet": false, "flash_light": true,
}

## Global wind (px/s²) added to every emitter built after it is set.
static var wind := Vector2.ZERO
## Tests/screenshots: never build GPUParticles2D.
static var force_cpu := false

static var _file_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _img_cache: Dictionary = {}
static var _icon_cache: Dictionary = {}
static var _add_material: CanvasItemMaterial


## All presets: id -> dict. Uses ContentDB.particles (with user:// overrides),
## falling back to reading the JSON directly if the autoload hasn't filled it.
static func presets() -> Dictionary:
	var db: Dictionary = ContentDB.particles if is_instance_valid(ContentDB) else {}
	if not db.is_empty():
		return db
	if _file_cache.is_empty() and FileAccess.file_exists(DATA_PATH):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if v is Dictionary:
			_file_cache = v
	return _file_cache


## A preset merged over DEFAULTS (empty dict for unknown ids).
static func get_preset(preset_id: String) -> Dictionary:
	var p: Variant = presets().get(preset_id)
	if not p is Dictionary:
		return {}
	var out := DEFAULTS.duplicate(true)
	out.merge(p, true)
	return out


## Emitter covering a screen-space region (e.g. the bounding box of merged
## cells). `cells` scales the particle count; `tile_w` scales sizes/speeds.
static func make(preset_id: String, region_px: Rect2, cells: int, tile_w: float) -> Node2D:
	var p := get_preset(preset_id)
	if p.is_empty():
		return _build(preset_id, p, PackedVector2Array(), 0, 1.0, Rect2())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(preset_id) ^ hash(region_px)
	var s := maxf(tile_w, 1.0) / BASE_TILE_W
	var n := clampi(maxi(cells, 1) * 12, 8, MAX_POINTS)
	var pts := PackedVector2Array()
	for i in n:
		var pt := region_px.position + Vector2(rng.randf(), rng.randf()) * region_px.size
		pts.append(_offset_point(p, pt, s, rng))
	return _build(preset_id, p, pts, maxi(cells, 1), s, region_px)


## Emitter over cell top faces. Each diamond is the 4 screen points [N, E, S, W]
## of one cell's top face at the painted layer (in the parent's coordinates).
static func make_for_cells(preset_id: String, diamonds: Array[PackedVector2Array]) -> Node2D:
	var p := get_preset(preset_id)
	if p.is_empty():
		return _build(preset_id, p, PackedVector2Array(), 0, 1.0, Rect2())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(preset_id) ^ diamonds.size()
	var tile_w := BASE_TILE_W
	var bounds := Rect2()
	for i in diamonds.size():
		var d := diamonds[i]
		if d.size() < 4:
			continue
		if i == 0:
			tile_w = absf(d[1].x - d[3].x)
			bounds = Rect2(d[0], Vector2.ZERO)
		for v in d:
			bounds = bounds.expand(v)
	var s := maxf(tile_w, 1.0) / BASE_TILE_W
	var cells := maxi(diamonds.size(), 1)
	var per := clampi(int(p["amount"]) * 2, 4, 24)
	per = mini(per, maxi(MAX_POINTS / cells, 1))
	var pts := PackedVector2Array()
	for d in diamonds:
		if d.size() < 4:
			continue
		for i in per:
			var pt: Vector2
			if bool(p["center"]):
				pt = (d[0] + d[2]) * 0.5 + Vector2(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.05, 0.05)) * tile_w
			else:
				# Uniform in the rhombus: N + u·(E−N) + v·(W−N).
				pt = d[0] + rng.randf() * (d[1] - d[0]) + rng.randf() * (d[3] - d[0])
			pts.append(_offset_point(p, pt, s, rng))
	return _build(preset_id, p, pts, cells, s, bounds)


static func _offset_point(p: Dictionary, pt: Vector2, s: float, rng: RandomNumberGenerator) -> Vector2:
	var fall := float(p["fall_from"]) * s
	if fall > 0.0:
		pt.y -= fall * rng.randf_range(0.9, 1.1)
	var rise := float(p["rise"]) * s
	if rise > 0.0:
		pt.y -= rng.randf() * rise
	return pt


static func _build(preset_id: String, p: Dictionary, pts: PackedVector2Array, cells: int, s: float, bounds: Rect2) -> Node2D:
	var root := Node2D.new()
	root.name = "Particles_" + preset_id
	root.set_meta("preset", preset_id)
	if p.is_empty():
		push_warning("ParticleFactory: unknown preset '%s'" % preset_id)
		return root
	var gusts: Array[Node] = []
	if bool(p["fog_sheet"]):
		var sheet := FogSheet.new()
		sheet.name = "FogSheet"
		sheet.setup(p, pts, s, bounds)
		root.add_child(sheet)
	if bool(p["depth"]):
		# Far layer: smaller, dimmer, slower, a touch higher → parallax depth.
		var far := p.duplicate()
		far["size"] = float(p["size"]) * 0.55
		far["speed"] = float(p["speed"]) * 0.72
		far["gravity"] = float(p["gravity"]) * 0.72
		far["alpha"] = float(p["alpha"]) * 0.5
		far["glow"] = maxf(float(p["glow"]) * 0.75, 0.6)
		far["amount"] = float(p["amount"]) * 0.7
		var far_pts := PackedVector2Array()
		for pt in pts:
			far_pts.append(pt + Vector2(0, -14.0 * s))
		var fe := _emitter(far, far_pts, cells, s)
		fe.name = "EmitterFar"
		fe.z_index = -1
		root.add_child(fe)
		gusts.append(fe)
	var em := _emitter(p, pts, cells, s)
	em.name = "Emitter"
	root.add_child(em)
	gusts.append(em)
	if bool(p["splash"]):
		var ground := PackedVector2Array()
		var fall := float(p["fall_from"]) * s
		for pt in pts:
			ground.append(pt + Vector2(0, fall))
		var sp := _splash_emitter(p, ground, cells, s)
		sp.name = "Splash"
		root.add_child(sp)
		if bool(p["droplets"]):
			var dr := _droplet_emitter(p, ground, cells, s)
			dr.name = "Droplets"
			root.add_child(dr)
	if int(p["lights"]) > 0:
		var wisps := Wisps.new()
		wisps.name = "Wisps"
		wisps.setup(p, pts, mini(int(p["lights"]) * maxi(cells / 4, 1), 8), s)
		root.add_child(wisps)
	var wv := _wind_of(p, s)
	if wv != Vector2.ZERO:
		var gust := WindGust.new()
		gust.name = "Wind"
		gust.emitters = gusts
		gust.wind = wv
		root.add_child(gust)
	if bool(p["lightning"]):
		var fx := LightningFlash.new()
		fx.name = "Lightning"
		fx.region = bounds
		fx.bolt_length = 300.0 * s
		fx.clouds = em
		fx.material = _additive()
		if bool(p["flash_light"]):
			fx.add_light(maxf(bounds.size.x, 200.0 * s))
		root.add_child(fx)
	return root


static func _wind_of(p: Dictionary, s: float) -> Vector2:
	var w: Variant = p["wind"]
	var v := Vector2(float(w[0]), float(w[1])) if w is Array and (w as Array).size() >= 2 else Vector2.ZERO
	return (v + wind) * s


## GPUParticles2D (real turbulence) only where the renderer supports it.
static func use_gpu(p: Dictionary) -> bool:
	if force_cpu or float(p["turbulence"]) <= 0.0:
		return false
	if DisplayServer.get_name() == "headless":
		return false
	var m := RenderingServer.get_current_rendering_method()
	return m == "forward_plus" or m == "mobile"


static func _emitter(p: Dictionary, pts: PackedVector2Array, cells: int, s: float) -> Node2D:
	if use_gpu(p):
		return _gpu_emitter(p, pts, cells, s)
	var em := CPUParticles2D.new()
	em.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	em.local_coords = true
	em.amount = clampi(int(round(float(p["amount"]) * cells)), 1, MAX_AMOUNT)
	em.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	em.emission_points = pts
	var tex := _texture_for(p)
	em.texture = tex
	var dir_arr: Array = p["direction"]
	var dir := Vector2(float(dir_arr[0]), float(dir_arr[1])) if dir_arr.size() >= 2 else Vector2.DOWN
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	dir = dir.normalized()
	em.direction = dir
	em.spread = float(p["spread"])
	var speed := float(p["speed"]) * s
	em.initial_velocity_min = speed * 0.8
	em.initial_velocity_max = speed * 1.2
	var g := float(p["gravity"]) * s
	em.gravity = Vector2(0, g) + _wind_of(p, s)
	var life := float(p["lifetime"])
	var fall := float(p["fall_from"]) * s
	if fall > 0.0 and float(p["damping"]) == 0.0:
		life = _fall_time(fall, speed * dir.y, g, life)
	em.lifetime = maxf(life, 0.05)
	em.lifetime_randomness = 0.0 if fall > 0.0 else 0.25
	em.preprocess = em.lifetime if float(p["explosiveness"]) < 0.5 else 0.0
	em.explosiveness = float(p["explosiveness"])
	em.randomness = 0.3
	em.damping_min = float(p["damping"]) * s * 0.7
	em.damping_max = float(p["damping"]) * s
	var spin := float(p["spin"])
	em.angular_velocity_min = -spin
	em.angular_velocity_max = spin
	if not bool(p["align"]):
		em.angle_min = -180.0 if spin > 20.0 else -12.0
		em.angle_max = 180.0 if spin > 20.0 else 12.0
	em.particle_flag_align_y = bool(p["align"])
	var wander := float(p["wander"]) * s
	# CPU stand-in for turbulence: random tangential + radial jitter.
	var turb := float(p["turbulence"]) * s
	em.tangential_accel_min = -wander - turb * 0.6
	em.tangential_accel_max = wander + turb * 0.6
	if turb > 0.0:
		em.radial_accel_min = -turb * 0.35
		em.radial_accel_max = turb * 0.35
	# `size` is the particle's longest side (a rain streak's length).
	var tex_w := float(maxi(tex.get_width(), tex.get_height())) if tex else 8.0
	var sz := _length_of(p, s)
	em.scale_amount_min = sz * 0.7 / tex_w
	em.scale_amount_max = sz * 1.2 / tex_w
	em.scale_amount_curve = _scale_curve(str(p["scale_curve"]))
	var glow := float(p["glow"])
	em.color = Color(glow, glow, glow, float(p["alpha"]))
	em.color_initial_ramp = _tint_ramp(p)
	em.color_ramp = _fade_ramp(str(p["fade"]))
	if str(p["blend"]) == "add":
		em.material = _additive()
	return em


## Seconds for a particle to fall `dist` px starting at vy with gravity g.
static func _fall_time(dist: float, vy: float, g: float, fallback: float) -> float:
	if absf(g) < 0.001:
		return dist / vy if vy > 0.001 else fallback
	var disc := vy * vy + 2.0 * g * dist
	if disc < 0.0:
		return fallback
	var t := (-vy + sqrt(disc)) / g
	return t if t > 0.0 else fallback


## Particle size; streaks stretch with fall speed ("stretch" px per px/s).
static func _length_of(p: Dictionary, s: float) -> float:
	var sz := float(p["size"]) * s
	var st := float(p["stretch"])
	if st > 0.0:
		var v := float(p["speed"]) * s + float(p["gravity"]) * s * 0.25
		sz = maxf(sz, v * st)
	return sz


static func _gpu_emitter(p: Dictionary, pts: PackedVector2Array, cells: int, s: float) -> GPUParticles2D:
	var em := GPUParticles2D.new()
	em.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	em.local_coords = true
	em.amount = clampi(int(round(float(p["amount"]) * cells)), 1, MAX_AMOUNT)
	var tex := _texture_for(p)
	em.texture = tex
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true
	# Emission points live in a float texture (one texel per point).
	var n := maxi(pts.size(), 1)
	var w := mini(n, 256)
	var h := int(ceil(float(n) / w))
	var img := Image.create(w, h, false, Image.FORMAT_RGF)
	var bounds := Rect2(pts[0] if pts.size() > 0 else Vector2.ZERO, Vector2.ZERO)
	for i in pts.size():
		img.set_pixel(i % w, i / w, Color(pts[i].x, pts[i].y, 0))
		bounds = bounds.expand(pts[i])
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	m.emission_point_texture = ImageTexture.create_from_image(img)
	m.emission_point_count = pts.size()
	var dir_arr: Array = p["direction"]
	var dir := Vector2(float(dir_arr[0]), float(dir_arr[1])) if dir_arr.size() >= 2 else Vector2.DOWN
	dir = dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	m.direction = Vector3(dir.x, dir.y, 0)
	m.spread = float(p["spread"])
	var speed := float(p["speed"]) * s
	m.initial_velocity_min = speed * 0.8
	m.initial_velocity_max = speed * 1.2
	var g := float(p["gravity"]) * s
	var wv := _wind_of(p, s)
	m.gravity = Vector3(wv.x, g + wv.y, 0)
	var life := float(p["lifetime"])
	var fall := float(p["fall_from"]) * s
	if fall > 0.0 and float(p["damping"]) == 0.0:
		life = _fall_time(fall, speed * dir.y, g, life)
	em.lifetime = maxf(life, 0.05)
	em.preprocess = em.lifetime if float(p["explosiveness"]) < 0.5 else 0.0
	em.explosiveness = float(p["explosiveness"])
	em.randomness = 0.3
	m.lifetime_randomness = 0.0 if fall > 0.0 else 0.25
	m.damping_min = float(p["damping"]) * s * 0.7
	m.damping_max = float(p["damping"]) * s
	var spin := float(p["spin"])
	m.angular_velocity_min = -spin
	m.angular_velocity_max = spin
	m.angle_min = -180.0 if spin > 20.0 else -12.0
	m.angle_max = 180.0 if spin > 20.0 else 12.0
	m.particle_flag_align_y = bool(p["align"])
	var wander := float(p["wander"]) * s
	m.tangential_accel_min = -wander
	m.tangential_accel_max = wander
	var turb := float(p["turbulence"])
	m.turbulence_enabled = true
	m.turbulence_noise_strength = clampf(turb / 20.0, 0.5, 12.0)
	m.turbulence_noise_scale = 4.0
	m.turbulence_noise_speed_random = 0.4
	m.turbulence_influence_min = 0.05
	m.turbulence_influence_max = 0.2
	var tex_w := float(maxi(tex.get_width(), tex.get_height())) if tex else 8.0
	var sz := _length_of(p, s)
	m.scale_min = sz * 0.7 / tex_w
	m.scale_max = sz * 1.2 / tex_w
	var sc := _scale_curve(str(p["scale_curve"]))
	if sc:
		var ct := CurveTexture.new()
		ct.curve = sc
		m.scale_curve = ct
	var glow := float(p["glow"])
	m.color = Color(glow, glow, glow, float(p["alpha"]))
	var it := GradientTexture1D.new()
	it.gradient = _tint_ramp(p)
	it.use_hdr = true
	m.color_initial_ramp = it
	var rt := GradientTexture1D.new()
	rt.gradient = _fade_ramp(str(p["fade"]))
	m.color_ramp = rt
	em.process_material = m
	em.visibility_rect = bounds.grow(maxf(sz * 2.0, 64.0) + fall + speed * em.lifetime)
	if str(p["blend"]) == "add":
		em.material = _additive()
	return em


## Rain: tiny droplets kicked up where drops land, falling back with gravity.
static func _droplet_emitter(p: Dictionary, pts: PackedVector2Array, cells: int, s: float) -> CPUParticles2D:
	var em := CPUParticles2D.new()
	em.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	em.local_coords = true
	em.amount = clampi(int(float(p["amount"]) * cells * 0.8), 1, MAX_AMOUNT / 2)
	em.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	em.emission_points = pts
	em.texture = generated_texture("soft")
	em.lifetime = 0.32
	em.preprocess = 0.32
	em.direction = Vector2.UP
	em.spread = 55.0
	em.initial_velocity_min = 50.0 * s
	em.initial_velocity_max = 110.0 * s
	em.gravity = Vector2(0, 700.0 * s)
	var sz := 4.0 * s / 64.0
	em.scale_amount_min = sz * 0.6
	em.scale_amount_max = sz * 1.2
	var glow := float(p["glow"]) * 1.2
	em.color = Color(glow, glow, glow, float(p["alpha"]))
	em.color_initial_ramp = _tint_ramp(p)
	em.color_ramp = _fade_ramp("out")
	if str(p["blend"]) == "add":
		em.material = _additive()
	return em


static func _splash_emitter(p: Dictionary, pts: PackedVector2Array, cells: int, s: float) -> CPUParticles2D:
	var em := CPUParticles2D.new()
	em.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	em.local_coords = true
	em.amount = clampi(int(float(p["amount"]) * cells * 0.5), 1, MAX_AMOUNT / 2)
	em.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	em.emission_points = pts
	em.texture = generated_texture("ring")
	em.lifetime = 0.3
	em.preprocess = 0.3
	em.gravity = Vector2.ZERO
	em.initial_velocity_min = 0.0
	em.initial_velocity_max = 0.0
	var sz := 10.0 * s / 32.0
	em.scale_amount_min = sz * 0.6
	em.scale_amount_max = sz * 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(1, 1))
	em.scale_amount_curve = curve
	var glow := float(p["glow"])
	em.color = Color(glow, glow, glow, float(p["alpha"]) * 0.9)
	em.color_initial_ramp = _tint_ramp(p)
	em.color_ramp = _fade_ramp("out")
	if str(p["blend"]) == "add":
		em.material = _additive()
	return em


static func _tint_ramp(p: Dictionary) -> Gradient:
	var c1 := Color(str(p["color"]))
	var c2s := str(p["color2"])
	var c2 := Color(c2s) if c2s != "" else c1
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	# Two-tone presets (neon rain) read better picking one tone or the other.
	if c1.h != c2.h and absf(c1.h - c2.h) > 0.2:
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	return g


static func _fade_ramp(fade: String) -> Gradient:
	var stops: Array = []
	match fade:
		"out": stops = [[0.0, 1.0], [0.6, 0.8], [1.0, 0.0]]
		"out_late": stops = [[0.0, 0.0], [0.08, 1.0], [0.85, 1.0], [1.0, 0.0]]
		"flicker_out": stops = [[0.0, 0.0], [0.1, 1.0], [0.3, 0.55], [0.45, 1.0], [0.6, 0.5], [0.75, 0.8], [1.0, 0.0]]
		"pulse": stops = [[0.0, 0.0], [0.15, 1.0], [0.3, 0.25], [0.45, 1.0], [0.6, 0.2], [0.8, 0.9], [1.0, 0.0]]
		"glitch": stops = [[0.0, 0.0], [0.1, 1.0], [0.25, 1.0], [0.26, 0.1], [0.32, 0.1], [0.33, 1.0], [0.55, 1.0], [0.56, 0.0], [0.6, 0.0], [0.61, 0.9], [0.8, 0.7], [1.0, 0.0]]
		"flat": stops = [[0.0, 1.0], [1.0, 1.0]]
		_: stops = [[0.0, 0.0], [0.25, 1.0], [0.7, 1.0], [1.0, 0.0]]
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for st: Array in stops:
		offs.append(float(st[0]))
		cols.append(Color(1, 1, 1, float(st[1])))
	var g := Gradient.new()
	g.offsets = offs
	g.colors = cols
	if fade == "glitch":
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	return g


static func _scale_curve(kind: String) -> Curve:
	var c := Curve.new()
	match kind:
		"grow":
			c.add_point(Vector2(0, 0.45))
			c.add_point(Vector2(1, 1))
		"grow_slight":
			c.add_point(Vector2(0, 0.8))
			c.add_point(Vector2(1, 1))
		"shrink":
			c.add_point(Vector2(0, 1))
			c.add_point(Vector2(1, 0.2))
		_:
			return null
	return c


static func _additive() -> CanvasItemMaterial:
	if _add_material == null:
		_add_material = CanvasItemMaterial.new()
		_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_material


static func _texture_for(p: Dictionary) -> Texture2D:
	var path := str(p["texture"])
	if path != "":
		var t := ForgeStore.load_texture(path)
		if t:
			return t
	return generated_texture(str(p["texture_kind"]))


# --- Procedural textures -----------------------------------------------------

## Cached generated texture: soft | streak | square | cloud | mist | puff | ring.
static func generated_texture(kind: String) -> Texture2D:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var tex := ImageTexture.create_from_image(_generated_image(kind))
	_tex_cache[kind] = tex
	return tex


static func _generated_image(kind: String) -> Image:
	if _img_cache.has(kind):
		return _img_cache[kind]
	var img: Image
	match kind:
		"streak": img = _img_streak()
		"square": img = _img_square()
		"cloud": img = _img_cloud(160, 104, 7)
		"mist": img = _img_cloud(160, 56, 11)
		"puff": img = _img_puff(64)
		"ring": img = _img_ring()
		_: img = _img_soft(64)
	_img_cache[kind] = img
	return img


static func _img_soft(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	return img


static func _img_streak() -> Image:
	var w := 8
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / (h - 1)  # 0 = tail (top), 1 = head (bottom, along velocity)
		var along := pow(t, 1.6) * clampf((1.0 - t) * 12.0, 0.0, 1.0)
		for x in w:
			var dx := absf(x - (w - 1) * 0.5) / (w * 0.5)
			var across := clampf(1.0 - dx, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, along * across * across))
	return img


static func _img_square() -> Image:
	var n := 8
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var edge := x == 0 or y == 0 or x == n - 1 or y == n - 1
			img.set_pixel(x, y, Color(1, 1, 1, 0.55 if edge else 1.0))
	return img


static func _img_ring() -> Image:
	var w := 32
	var h := 16
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var d := Vector2((x - (w - 1) * 0.5) / (w * 0.5), (y - (h - 1) * 0.5) / (h * 0.5)).length()
			var a := clampf(1.0 - absf(d - 0.75) / 0.2, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


## Round smoke/steam puff: soft disc with a noisy, billowing edge.
static func _img_puff(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.05
	noise.fractal_octaves = 2
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / (n * 0.5)
			var nz := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((1.0 - d) * 1.3 + (nz - 0.5) * 0.5, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a) * clampf((1.0 - d) * 4.0, 0.0, 1.0)
			var shade := lerpf(1.05, 0.7, float(y) / n) * lerpf(0.85, 1.1, nz)
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	return img


## Lumpy cloud bank: overlapping blobs + noise-eaten edges, lit from above.
static func _img_cloud(w: int, h: int, seed_value: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var blobs: Array[Vector3] = []
	for i in 7:
		var bx := rng.randf_range(0.22, 0.78) * w
		var by := rng.randf_range(0.45, 0.62) * h
		var br := rng.randf_range(0.2, 0.3) * minf(w, h * 1.6)
		blobs.append(Vector3(bx, by, br))
	for y in h:
		for x in w:
			var dens := 0.0
			for b in blobs:
				var d := Vector2((x - b.x) / b.z, (y - b.y) / (b.z * 0.72)).length()
				dens = maxf(dens, 1.0 - d)
			# Fade out towards the texture border so no hard edges show.
			var ex := minf(x, w - 1 - x) / (w * 0.12)
			var ey := minf(y, h - 1 - y) / (h * 0.12)
			var border := clampf(minf(ex, ey), 0.0, 1.0)
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((dens + (n - 0.5) * 0.7) * 1.7, 0.0, 1.0) * border
			a = a * a * (3.0 - 2.0 * a)
			var shade := lerpf(1.0, 0.62, float(y) / h) * lerpf(0.85, 1.1, n)
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	return img


# --- Palette icon ------------------------------------------------------------

## 32×32 palette icon: dark tile, preset-coloured rim and a glyph of its texture.
static func preview_icon(preset_id: String) -> Texture2D:
	if _icon_cache.has(preset_id):
		return _icon_cache[preset_id]
	var p := get_preset(preset_id)
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color("0b0714"))
	var col := Color(str(p.get("color", "#ffffff")))
	var c2s := str(p.get("color2", ""))
	var col2 := Color(c2s) if c2s != "" else col
	# Dark presets (storm clouds, smoke) get lifted so the glyph stays visible.
	if col.get_luminance() < 0.25:
		col = col.lightened(0.45)
		col2 = col2.lightened(0.45)
	for i in n:
		for e: Vector2i in [Vector2i(i, 0), Vector2i(i, n - 1), Vector2i(0, i), Vector2i(n - 1, i)]:
			img.set_pixelv(e, col.darkened(0.35))
	var kind := str(p.get("texture_kind", "soft"))
	var src := _generated_image(kind)
	var stamps: Array = []
	match kind:
		"streak": stamps = [[6, 3, 5, 18], [15, 8, 5, 18], [23, 2, 5, 18], [11, 14, 5, 14]]
		"cloud", "mist": stamps = [[2, 7, 28, 18], [6, 14, 22, 14]]
		"puff": stamps = [[4, 12, 14, 14], [12, 5, 16, 16], [16, 16, 12, 12]]
		"square": stamps = [[8, 20, 4, 4], [15, 13, 4, 4], [21, 7, 4, 4], [11, 7, 3, 3], [22, 20, 3, 3]]
		"ring": stamps = [[6, 10, 20, 10]]
		_: stamps = [[5, 18, 8, 8], [14, 8, 10, 10], [21, 19, 7, 7], [9, 5, 5, 5], [17, 23, 5, 5]]
	for i in stamps.size():
		var st: Array = stamps[i]
		var tint := col if i % 2 == 0 else col2
		_stamp(img, src, Rect2i(int(st[0]), int(st[1]), int(st[2]), int(st[3])), tint)
	if bool(p.get("lightning", false)):
		for pt: Vector2i in [Vector2i(17, 17), Vector2i(16, 19), Vector2i(18, 20), Vector2i(17, 22), Vector2i(16, 24), Vector2i(17, 18), Vector2i(17, 21), Vector2i(16, 23)]:
			img.set_pixelv(pt, Color("fff6a0"))
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[preset_id] = tex
	return tex


static func _stamp(dst: Image, src: Image, r: Rect2i, tint: Color) -> void:
	var scaled := src.duplicate() as Image
	scaled.resize(maxi(r.size.x, 1), maxi(r.size.y, 1), Image.INTERPOLATE_BILINEAR)
	for y in scaled.get_height():
		for x in scaled.get_width():
			var p := r.position + Vector2i(x, y)
			if p.x < 1 or p.y < 1 or p.x >= dst.get_width() - 1 or p.y >= dst.get_height() - 1:
				continue
			var s := scaled.get_pixel(x, y)
			var c := Color(tint.r * s.r, tint.g * s.g, tint.b * s.b, 1.0)
			dst.set_pixelv(p, dst.get_pixelv(p).lerp(c, s.a))


# --- Lightning ---------------------------------------------------------------

## Storm-cloud lightning: every few seconds a jagged bolt drops out of the cloud
## bank, the clouds light up from inside, and it fades in two quick pulses.
class LightningFlash extends Node2D:
	const DURATION := 0.5

	## Screen-space area of the clouds (bolts start inside it).
	var region: Rect2
	var bolt_length: float = 300.0
	## Cloud emitter brightened while flashing (optional).
	var clouds: CanvasItem
	var min_interval: float = 2.5
	var max_interval: float = 7.0
	var _rng := RandomNumberGenerator.new()
	var _next: float = 0.0
	var _t: float = -1.0
	var _bolts: Array[PackedVector2Array] = []
	var _origin: Vector2
	var _light: PointLight2D

	## A PointLight2D that lights the area under the storm on every flash.
	func add_light(radius: float) -> void:
		_light = PointLight2D.new()
		_light.name = "FlashLight"
		_light.texture = VFX.texture("light")
		_light.texture_scale = radius * 2.0 / float(_light.texture.get_width())
		_light.color = Color(0.78, 0.74, 1.0)
		_light.energy = 0.0
		_light.enabled = false
		_light.range_z_min = -4096
		_light.range_z_max = 4096
		add_child(_light)

	func _ready() -> void:
		_rng.randomize()
		_next = _rng.randf_range(0.8, max_interval)

	func _process(delta: float) -> void:
		if _t >= 0.0:
			_t += delta
			if _t > DURATION:
				_t = -1.0
				_next = _rng.randf_range(min_interval, max_interval)
			_apply()
		else:
			_next -= delta
			if _next <= 0.0:
				flash_now()

	## 0..1 brightness of the current flash (two pulses, then decay).
	func intensity() -> float:
		if _t < 0.0:
			return 0.0
		if _t < 0.07:
			return 1.0
		if _t < 0.13:
			return 0.25
		if _t < 0.2:
			return 0.9
		return clampf(1.0 - (_t - 0.2) / (DURATION - 0.2), 0.0, 1.0) * 0.8

	## Triggers a flash immediately (also handy for screenshots/cutscenes).
	func flash_now() -> void:
		_t = 0.0
		var r := region if region.has_area() else Rect2(-64, -32, 128, 64)
		_origin = r.position + Vector2(_rng.randf_range(0.25, 0.75), _rng.randf_range(0.4, 0.7)) * r.size
		_bolts.clear()
		var main := _bolt(_origin, bolt_length)
		_bolts.append(main)
		if main.size() > 4:
			_bolts.append(_bolt(main[main.size() / 3], bolt_length * 0.4))
		_apply()

	func _bolt(from: Vector2, length: float) -> PackedVector2Array:
		var pts := PackedVector2Array([from])
		var p := from
		var drift := _rng.randf_range(-0.35, 0.35)
		while p.y - from.y < length:
			p += Vector2(_rng.randf_range(-16, 16) + drift * 20.0, _rng.randf_range(14, 30))
			pts.append(p)
		return pts

	func _apply() -> void:
		var k := intensity()
		if is_instance_valid(clouds):
			clouds.self_modulate = Color(1, 1, 1).lerp(Color(2.0, 1.95, 2.6), k)
		if _light:
			_light.position = _origin + Vector2(0, bolt_length * 0.6)
			_light.energy = 2.4 * k
			_light.enabled = k > 0.0
		queue_redraw()

	func _draw() -> void:
		var k := intensity()
		if k <= 0.0:
			return
		var glow := ParticleFactory.generated_texture("soft")
		var rad := maxf(region.size.x, 160.0) * 0.45
		draw_texture_rect(glow, Rect2(_origin - Vector2(rad, rad * 0.6), Vector2(rad * 2, rad * 1.2)), false, Color(0.9, 0.85, 1.4, 0.6 * k))
		for i in _bolts.size():
			var w := 1.0 if i > 0 else 1.6
			draw_polyline(_bolts[i], Color(0.8, 0.7, 2.0, 0.35 * k), 10.0 * w, true)
			draw_polyline(_bolts[i], Color(3.0, 3.0, 4.0, k), 2.4 * w, true)



# --- Wind gusts --------------------------------------------------------------

## Breathes the wind part of each emitter's gravity so rain/snow sway in gusts.
class WindGust extends Node:
	var emitters: Array[Node] = []
	var wind := Vector2.ZERO
	var _base: Array = []
	var _t: float = 0.0

	func _ready() -> void:
		_t = randf() * 10.0
		for e in emitters:
			if e is CPUParticles2D:
				_base.append((e as CPUParticles2D).gravity)
			elif e is GPUParticles2D and (e as GPUParticles2D).process_material is ParticleProcessMaterial:
				var g := ((e as GPUParticles2D).process_material as ParticleProcessMaterial).gravity
				_base.append(Vector2(g.x, g.y))
			else:
				_base.append(Vector2.ZERO)

	## Gust multiplier on the wind (around 1.0).
	func gust(t: float) -> float:
		return 1.0 + 0.45 * sin(t * 0.9) + 0.25 * sin(t * 2.3 + 1.3) + 0.12 * sin(t * 5.1)

	func _process(delta: float) -> void:
		_t += delta
		var extra := wind * (gust(_t) - 1.0)
		for i in emitters.size():
			var e := emitters[i]
			if not is_instance_valid(e) or i >= _base.size():
				continue
			var g: Vector2 = _base[i] + extra
			if e is CPUParticles2D:
				(e as CPUParticles2D).gravity = g
			elif e is GPUParticles2D and (e as GPUParticles2D).process_material is ParticleProcessMaterial:
				((e as GPUParticles2D).process_material as ParticleProcessMaterial).gravity = Vector3(g.x, g.y, 0)


# --- Light-emitting wisps ----------------------------------------------------

## Fireflies / data motes that actually light their surroundings: a few
## PointLight2D wanderers with a visible glow core, pulsing out of phase.
class Wisps extends Node2D:
	var _lights: Array[PointLight2D] = []
	var _params: Array[Vector4] = []  # fx, fy, phase, pulse speed
	var _box := Rect2()
	var _cols: Array[Color] = []
	var _t: float = 0.0
	var _size: float = 6.0
	var _glow: float = 2.0

	func setup(p: Dictionary, pts: PackedVector2Array, n: int, s: float) -> void:
		material = ParticleFactory._additive()
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var b := Rect2(pts[0] if pts.size() > 0 else Vector2.ZERO, Vector2.ZERO)
		for pt in pts:
			b = b.expand(pt)
		_box = b.grow(4.0 * s)
		_size = float(p["size"]) * s * 1.4
		_glow = float(p["glow"])
		var c1 := Color(str(p["color"]))
		var c2s := str(p["color2"])
		var c2 := Color(c2s) if c2s != "" else c1
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(p["name"])) ^ pts.size()
		for i in maxi(n, 1):
			var l := PointLight2D.new()
			l.texture = VFX.texture("light")
			l.texture_scale = 120.0 * s / float(l.texture.get_width())
			var c := c1.lerp(c2, rng.randf())
			l.color = c
			l.energy = 0.0
			l.range_z_min = -4096
			l.range_z_max = 4096
			add_child(l)
			_lights.append(l)
			_cols.append(c)
			_params.append(Vector4(rng.randf_range(0.13, 0.3), rng.randf_range(0.17, 0.37), rng.randf() * TAU, rng.randf_range(1.2, 2.6)))
		_t = rng.randf() * 20.0
		_place()

	func _process(delta: float) -> void:
		_t += delta
		_place()
		queue_redraw()

	func _pos(i: int) -> Vector2:
		var q := _params[i]
		var u := 0.5 + 0.5 * sin(_t * q.x + q.z)
		var v := 0.5 + 0.5 * sin(_t * q.y + q.z * 1.7)
		return _box.position + Vector2(u, v) * _box.size

	func _pulse(i: int) -> float:
		var q := _params[i]
		return clampf(0.35 + 0.65 * sin(_t * q.w + q.z * 3.0), 0.0, 1.0)

	func _place() -> void:
		for i in _lights.size():
			_lights[i].position = _pos(i)
			_lights[i].energy = 1.5 * _pulse(i)

	func _draw() -> void:
		var tex := VFX.texture("core")
		for i in _lights.size():
			var k := _pulse(i)
			var c := _cols[i]
			var r := _size * (0.8 + 0.4 * k)
			draw_texture_rect(tex, Rect2(_pos(i) - Vector2(r, r), Vector2(r * 2, r * 2)), false, Color(c.r * _glow, c.g * _glow, c.b * _glow, k))


# --- Fog sheet ---------------------------------------------------------------

## Soft fog blobs over the painted cells whose alpha is eaten by two layers of
## world-space noise scrolling with the wind: fog that drifts and breathes
## instead of a few big sprites sliding around.
class FogSheet extends Node2D:
	const CODE := """
shader_type canvas_item;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 drift = vec2(0.012, 0.003);
uniform float density = 1.0;
varying vec2 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float n1 = texture(noise_tex, wpos * 0.0022 + TIME * drift).r;
	float n2 = texture(noise_tex, wpos * 0.0055 - TIME * drift * 1.9 + vec2(0.37, 0.11)).r;
	float n = smoothstep(0.2, 0.8, n1 * 0.7 + n2 * 0.45);
	COLOR = vec4(base.rgb, base.a * n * density);
}
"""
	static var _shader: Shader
	static var _noise: Texture2D
	var _blobs: Array[Rect2] = []
	var _color := Color.WHITE

	func setup(p: Dictionary, pts: PackedVector2Array, s: float, _bounds: Rect2) -> void:
		if _shader == null:
			_shader = Shader.new()
			_shader.code = CODE
		if _noise == null:
			var fn := FastNoiseLite.new()
			fn.seed = 11
			fn.frequency = 0.02
			fn.fractal_octaves = 3
			_noise = ImageTexture.create_from_image(fn.get_seamless_image(256, 256))
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("noise_tex", _noise)
		var dir_arr: Array = p["direction"]
		var dir := Vector2(float(dir_arr[0]), float(dir_arr[1])) if dir_arr.size() >= 2 else Vector2.RIGHT
		m.set_shader_parameter("drift", -dir.normalized() * 0.012 * maxf(float(p["speed"]) / 10.0, 0.3))
		m.set_shader_parameter("density", clampf(float(p["alpha"]) * 2.2, 0.2, 1.0))
		material = m
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var c := Color(str(p["color2"])) if str(p["color2"]) != "" else Color(str(p["color"]))
		_color = Color(c.r, c.g, c.b, 0.85)
		var r := float(p["size"]) * s * 0.55
		var step := maxi(pts.size() / 48, 1)
		for i in range(0, pts.size(), step):
			_blobs.append(Rect2(pts[i] - Vector2(r, r * 0.5), Vector2(r * 2, r)))

	func _draw() -> void:
		var tex := ParticleFactory.generated_texture("soft")
		for b in _blobs:
			draw_texture_rect(tex, b, false, _color)
