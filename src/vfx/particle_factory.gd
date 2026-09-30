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
}

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
	var em := _emitter(p, pts, cells, s)
	em.name = "Emitter"
	root.add_child(em)
	if bool(p["splash"]):
		var ground := PackedVector2Array()
		var fall := float(p["fall_from"]) * s
		for pt in pts:
			ground.append(pt + Vector2(0, fall))
		var sp := _splash_emitter(p, ground, cells, s)
		sp.name = "Splash"
		root.add_child(sp)
	if bool(p["lightning"]):
		var fx := LightningFlash.new()
		fx.name = "Lightning"
		fx.region = bounds
		fx.bolt_length = 300.0 * s
		fx.clouds = em
		fx.material = _additive()
		root.add_child(fx)
	return root


static func _emitter(p: Dictionary, pts: PackedVector2Array, cells: int, s: float) -> CPUParticles2D:
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
	em.gravity = Vector2(0, g)
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
	em.tangential_accel_min = -wander
	em.tangential_accel_max = wander
	# `size` is the particle's longest side (a rain streak's length).
	var tex_w := float(maxi(tex.get_width(), tex.get_height())) if tex else 8.0
	var sz := float(p["size"]) * s
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
