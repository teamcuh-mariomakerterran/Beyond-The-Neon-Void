class_name VFX
extends RefCounted
## One-shot visual effects library: layered, data-driven, self-freeing.
##
##     VFX.spawn(world, "plasma_explosion", ground_pos, {"scale": 1.2})
##     VFX.spawn(world, "electric_arc", caster_pos, {"to": target_pos})
##     VFX.spawn(world, "chain_lightning", caster_pos, {"targets": [p1, p2, p3]})
##
## Effects live in data/vfx.json ("effects": id -> def) with Forge/user
## overrides in user://content/vfx.json. An effect is a palette plus a list of
## parts, each with its own delay/life; the effect frees itself when the last
## part ends. `at` is the effect's GROUND point (sparks bounce on y = at.y);
## parts raise themselves with "pos": [x, y].
##
## Part types (see each class for its keys):
##   sim        VFXSim         CPU particles: sparks w/ gravity + floor bounce,
##                             embers, smoke, debris polygons, shards, motes on
##                             curves, orbiting glyphs, suction, trails
##   burst      VFXSim         GPUParticles2D burst with turbulence on
##                             Forward+/Mobile, VFXSim fallback elsewhere
##   lightning  VFXLightning   jagged branching arcs, re-randomised, chains
##   flash | ring | pillar | decal | tear | scan | streaks   VFXShape
##   shockwave | glitch        VFXScreen      SCREEN_TEXTURE refraction / RGB split
##   light      VFXLight       PointLight2D pulse so effects light the scene
##   trail      VFXTrail       projectile head + fading Line2D ribbon
##
## Colours: "#rrggbb", "#rrggbbaa", "#rrggbb*3" (HDR multiplier → blooms with
## hdr_2d), [r, g, b(, a)], or "$name" from the effect palette. params.color
## replaces palette "main"; params.palette merges over the palette.
##
## Effect keys: palette, parts, shake [intensity, secs], shake_delay,
## hit_stop secs, hit_stop_delay, z (absolute z_index, default 4080).
##
## spawn() params: to (Vector2, parent space), targets (Array[Vector2]),
## scale, color, palette, seed, z, floor_z (absolute z for decals),
## shake (bool), hit_stop (bool), texture (death_dissolve samples it).
##
## Juice signals: VFX.events.shake / hit_stop / screen_flash. Shakes are also
## forwarded to EventBus.camera_shake; hit-stop dips Engine.time_scale unless
## VFX.hit_stop_enabled is false or a handler sets VFX.events.handled_hit_stop.

const DATA_PATH := "res://data/vfx.json"
const USER_PATH := "user://content/vfx.json"
const DEFAULT_Z := 4080

## Signal hub (GDScript has no static signals).
class Events extends RefCounted:
	signal shake(intensity: float, duration: float)
	signal hit_stop(duration: float)
	signal screen_flash(color: Color, duration: float)
	signal effect_spawned(effect_id: String, node: Node2D)
	## Set true by a listener that implements hit-stop itself.
	var handled_hit_stop := false

static var events: Events = Events.new()
## Global switches (screenshots/tests turn the side effects off).
static var hit_stop_enabled := true
static var shake_enabled := true
## While true, effects don't advance on their own; call VFXEffect.step().
static var paused := false

static var _data: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _add_mat: CanvasItemMaterial
static var _hit_stop_until := 0


# --- Data --------------------------------------------------------------------

static func data() -> Dictionary:
	if _data.is_empty():
		reload()
	return _data


## Re-reads data/vfx.json and the user override (Forge edits).
static func reload() -> void:
	_data = {"effects": {}, "abilities": {}, "specials": {}, "types": {}, "kinds": {}}
	for path in [DATA_PATH, USER_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not v is Dictionary:
			push_warning("VFX: could not parse %s" % path)
			continue
		for k: String in v:
			if _data.get(k) is Dictionary and v[k] is Dictionary:
				(_data[k] as Dictionary).merge(v[k], true)
			else:
				_data[k] = v[k]


static func effect_ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in data()["effects"]:
		out.append(k)
	return out


static func has_effect(effect_id: String) -> bool:
	return data()["effects"].has(effect_id)


static func get_effect(effect_id: String) -> Dictionary:
	var e: Variant = data()["effects"].get(effect_id)
	return e if e is Dictionary else {}


# --- Spawning ----------------------------------------------------------------

## Spawns `effect_id` under `parent` with its ground point at `at` (parent
## space). Returns the effect root; it frees itself when done. Unknown ids
## spawn a small generic flash (with a warning) so callers never get null.
static func spawn(parent: Node, effect_id: String, at: Vector2, params := {}) -> Node2D:
	var def := get_effect(effect_id)
	if def.is_empty():
		push_warning("VFX: unknown effect '%s'" % effect_id)
		def = {"parts": [{"type": "flash", "life": 0.25, "size": 40, "color": "#ffffff*2"}]}
	var fx := VFXEffect.new()
	fx.name = "VFX_" + effect_id
	fx.setup(effect_id, def, at, params)
	if parent:
		parent.add_child(fx)
	_bus().effect_spawned.emit(effect_id, fx)
	return fx


## Seconds from spawn until the effect "lands" (projectiles arrive; impacts
## peak). Used to sync damage numbers / follow-up effects.
static func impact_time(effect_id: String) -> float:
	var def := get_effect(effect_id)
	if def.has("impact_at"):
		return float(def["impact_at"])
	var best := 0.0
	for p: Dictionary in def.get("parts", []):
		if str(p.get("type", "")) == "trail":
			best = maxf(best, float(p.get("delay", 0.0)) + float(p.get("travel", 0.3)))
	return best


# --- Juice -------------------------------------------------------------------

static func shake(intensity: float, duration: float) -> void:
	if not shake_enabled or intensity <= 0.0:
		return
	_bus().shake.emit(intensity, duration)
	var bus := _autoload("EventBus")
	if bus and bus.has_signal("camera_shake"):
		bus.emit_signal("camera_shake", intensity, duration)


## Freeze-frame: time_scale dips to ~0 for `duration` real seconds.
static func hit_stop(duration: float) -> void:
	if not hit_stop_enabled or duration <= 0.0:
		return
	var ev := _bus()
	ev.handled_hit_stop = false
	ev.hit_stop.emit(duration)
	if ev.handled_hit_stop:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var until := Time.get_ticks_msec() + int(duration * 1000.0)
	if until <= _hit_stop_until:
		return
	_hit_stop_until = until
	Engine.time_scale = 0.03
	var timer := tree.create_timer(duration, true, false, true)
	timer.timeout.connect(func() -> void:
		if Time.get_ticks_msec() >= _hit_stop_until - 5:
			Engine.time_scale = 1.0)


static func _bus() -> Events:
	if events == null:
		events = Events.new()
	return events


static func _autoload(n: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(n)


# --- Battle mapping ----------------------------------------------------------

## How a battle should present `ability`: {cast, travel, impact, mode, multi}.
## mode: "point" (impact at the target cell), "arc" (impact spawned at the
## caster with to = target, e.g. lightning), "stream" (a drain whose motes
## flow target → caster; also spawned at the caster with to = target),
## "chain" (caster → every affected unit).
## multi: spawn the impact on every affected unit instead of once.
## Lookup order: ability.vfx_id → vfx.json abilities[id] → specials[special]
## → kinds (heal/buff/debuff/utility) → types[damage_type].
static func plan_for_ability(ability: Resource, ranged: bool) -> Dictionary:
	var d := data()
	var plan := {"cast": "", "travel": "", "impact": "", "mode": "point", "multi": false}
	if ability == null:
		plan["impact"] = "impact_physical"
		return plan
	var aid := str(ability.get("id"))
	var vfx_id := str(ability.get("vfx_id")) if ability.get("vfx_id") != null else ""
	var special := str(ability.get("special")) if ability.get("special") != null else ""
	var dtype := str(ability.get("damage_type")) if ability.get("damage_type") != null else "physical"
	var kind_i: int = int(ability.get("kind")) if ability.get("kind") != null else 0
	var kind_name: String = ["ATTACK", "MAGIC", "HEAL", "BUFF", "DEBUFF", "UTILITY", "SPECIAL"][clampi(kind_i, 0, 6)]
	var aoe: int = int(ability.get("aoe_radius")) if ability.get("aoe_radius") != null else 0
	var charge: int = int(ability.get("charge_ticks")) if ability.get("charge_ticks") != null else 0
	var big := aoe >= 2 or charge >= 2
	var has_aoe := aoe >= 1
	var entry: Variant = null
	if vfx_id != "" and has_effect(vfx_id):
		entry = vfx_id
	elif d["abilities"].has(aid):
		entry = d["abilities"][aid]
	elif special != "":
		var specials: Dictionary = d["specials"]
		if specials.has(special):
			entry = specials[special]
		else:
			var head := special.split(".")[0]
			if specials.has(head):
				entry = specials[head]
	if entry == null and d["kinds"].has(kind_name) and (kind_name != "ATTACK" and kind_name != "MAGIC"):
		# Heals/buffs/debuffs read as their kind unless they carry an element.
		if dtype == "physical" or kind_name == "HEAL":
			entry = d["kinds"][kind_name]
	if entry == null:
		entry = d["types"].get(dtype, d["types"].get("physical", {}))
	if entry is String:
		plan["impact"] = entry
	elif entry is Dictionary:
		var e: Dictionary = entry
		for k: String in ["cast", "travel", "impact", "mode"]:
			if e.has(k):
				plan[k] = str(e[k])
		plan["multi"] = bool(e.get("multi", false))
		# Bigger casts escalate: "aoe" for any area, "big" for wide/charged.
		if big and e.has("big"):
			plan["impact"] = str(e["big"])
			plan["mode"] = str(e.get("big_mode", plan["mode"]))
		elif has_aoe and e.has("aoe"):
			plan["impact"] = str(e["aoe"])
			plan["mode"] = str(e.get("aoe_mode", plan["mode"]))
	if not ranged and plan["mode"] == "point":
		plan["travel"] = ""
	if plan["impact"] == "" or not has_effect(str(plan["impact"])):
		plan["impact"] = "impact_physical"
	for k: String in ["cast", "travel"]:
		if plan[k] != "" and not has_effect(str(plan[k])):
			plan[k] = ""
	return plan


# --- Colours -----------------------------------------------------------------

## Parses "#hex", "#hex*k", [r,g,b(,a)], Color, or "$name" via `palette`.
static func parse_color(v: Variant, palette: Dictionary = {}, fallback := Color.WHITE) -> Color:
	if v is Color:
		return v
	if v is Array:
		var a: Array = v
		if a.size() >= 3:
			return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
		return fallback
	if v is String or v is StringName:
		var s := str(v).strip_edges()
		if s.begins_with("$"):
			var key := s.substr(1)
			var mult := 1.0
			if "*" in key:
				mult = float(key.get_slice("*", 1))
				key = key.get_slice("*", 0)
			if palette.has(key):
				var c := parse_color(palette[key], {}, fallback)
				return Color(c.r * mult, c.g * mult, c.b * mult, c.a)
			return fallback
		var k := 1.0
		if "*" in s:
			k = float(s.get_slice("*", 1))
			s = s.get_slice("*", 0)
		if not Color.html_is_valid(s):
			return fallback
		var c := Color.html(s)
		return Color(c.r * k, c.g * k, c.b * k, c.a)
	return fallback


static func additive() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


# --- Procedural textures -----------------------------------------------------

## soft | core | streak | square | puff | ring (from ParticleFactory) plus
## shard | star | glyph | chip | beam | scorch | light | droplet | noise.
static func texture(kind: String) -> Texture2D:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var img: Image
	match kind:
		"core": img = _img_core(64)
		"shard": img = _img_shard()
		"star": img = _img_star(64)
		"glyph": img = _img_glyph()
		"chip": img = _img_chip()
		"beam": img = _img_beam()
		"scorch": img = _img_scorch(128)
		"light": img = _img_light(128)
		"droplet": img = _img_droplet()
		"soft", "streak", "square", "puff", "ring", "cloud", "mist":
			var t := ParticleFactory.generated_texture(kind)
			_tex_cache[kind] = t
			return t
		_: img = _img_core(64)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[kind] = tex
	return tex


## Hot core: tight bright centre with a long soft falloff (reads as bloom).
static func _img_core(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / (n * 0.5)
			var a := clampf(exp(-d * d * 9.0) * 0.85 + clampf(1.0 - d, 0.0, 1.0) * 0.25, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


## Ice shard / blade: a long thin diamond, brighter along the spine.
static func _img_shard() -> Image:
	var w := 16
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / (h - 1)
		var half := (1.0 - absf(t - 0.35) / (0.65 if t > 0.35 else 0.35)) * w * 0.5
		for x in w:
			var dx := absf(x - (w - 1) * 0.5)
			var a := clampf(half - dx + 0.5, 0.0, 1.0)
			var spine := clampf(1.0 - dx / maxf(half, 0.01), 0.0, 1.0)
			var s := lerpf(0.65, 1.0, spine)
			img.set_pixel(x, y, Color(s, s, s, a))
	return img


## Four-point lens flare star.
static func _img_star(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var p := Vector2(x - c, y - c) / (n * 0.5)
			var cross := maxf(exp(-absf(p.y) * 28.0) * (1.0 - absf(p.x)), exp(-absf(p.x) * 28.0) * (1.0 - absf(p.y)))
			var core := exp(-p.length_squared() * 30.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(cross + core, 0.0, 1.0)))
	return img


## Data glyph: hollow square with a bit pattern inside (crisp, 12×12).
static func _img_glyph() -> Image:
	var n := 12
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var bits := [Vector2i(3, 3), Vector2i(4, 3), Vector2i(7, 3), Vector2i(3, 5), Vector2i(6, 5), Vector2i(7, 5),
		Vector2i(4, 7), Vector2i(5, 7), Vector2i(8, 7), Vector2i(3, 8), Vector2i(7, 8), Vector2i(8, 8)]
	for y in n:
		for x in n:
			var edge := x == 0 or y == 0 or x == n - 1 or y == n - 1
			var a := 1.0 if edge else 0.0
			if bits.has(Vector2i(x, y)):
				a = 0.85
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


## Confetti chip / pixel: solid square with a lighter top-left bevel.
static func _img_chip() -> Image:
	var n := 6
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var s := 1.0 if (x == 0 or y == 0) else (0.7 if (x == n - 1 or y == n - 1) else 0.88)
			img.set_pixel(x, y, Color(s, s, s, 1.0))
	return img


## Light pillar: gaussian across x, fading towards the top.
static func _img_beam() -> Image:
	var w := 32
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / (h - 1)  # 0 top .. 1 bottom
		var along := pow(t, 0.7) * clampf((1.0 - t) * 14.0, 0.0, 1.0)
		for x in w:
			var dx := (x - (w - 1) * 0.5) / (w * 0.5)
			var across := exp(-dx * dx * 5.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(along * across * 1.15, 0.0, 1.0)))
	return img


## Burn mark: dark noisy disc, darker core, ragged rim.
static func _img_scorch(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.06
	noise.fractal_octaves = 3
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var p := Vector2(x - c, y - c)
			var d := p.length() / (n * 0.5)
			var nz := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var ang := atan2(p.y, p.x)
			var rag := 0.12 * sin(ang * 7.0 + nz * 4.0) + (nz - 0.5) * 0.35
			var a := clampf((1.0 - d + rag) * 2.2, 0.0, 1.0)
			a *= lerpf(0.75, 1.0, nz)
			var shade := lerpf(0.18, 0.5, clampf(d * 1.2 + (nz - 0.5) * 0.4, 0.0, 1.0))
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	return img


## PointLight2D falloff texture.
static func _img_light(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := clampf(Vector2(x - c, y - c).length() / (n * 0.5), 0.0, 1.0)
			var v := pow(1.0 - d, 2.2)
			img.set_pixel(x, y, Color(v, v, v, v))
	return img


## Water droplet: small soft teardrop.
static func _img_droplet() -> Image:
	var w := 8
	var h := 12
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := Vector2((x - 3.5) / 4.0, (y - 7.0) / 5.0)
			if y < 7:
				p.x *= 1.0 + (7 - y) * 0.25
			var a := clampf(1.0 - p.length(), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a * 2.0, 0.0, 1.0)))
	return img
