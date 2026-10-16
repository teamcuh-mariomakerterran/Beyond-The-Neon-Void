class_name RoamingThreats
extends Node2D
## Visible encounters on explore maps: hostiles you can see coming. Every
## region whose encounter mode is "visible" (the default) spawns a few threats
## that wander inside the region and chase the player once they're close.
## Touching one starts its battle (the player comes back to the same spot);
## a beaten threat stays gone until its respawn time passes on the world clock.
## Regions set to mode "random" keep the classic invisible step rolls instead
## (ExploreScene.roll_encounter).
##
## Region "encounter": {mode: visible | random, missions: [ids], rate (random
## only), max_threats (2), aggro (4 cells), respawn_hours (12), speed (1.0)}

const WANDER_SPEED := 1.3  # cells / s
const CHASE_SPEED := 2.4
const CONTACT := 0.55  # cells
const SAFE_SPAWN := 4  # never spawn this close to the player
const GRACE := 1.5  # s after arriving before anyone can catch you

var scene: Node  # ExploreScene
var threats: Array[Threat] = []
var rng := RandomNumberGenerator.new()
var _grace := GRACE
var triggered: Threat = null


static func mode_of(region: Dictionary) -> String:
	var enc: Dictionary = region.get("encounter", {})
	if (enc.get("missions", []) as Array).is_empty():
		return ""
	return str(enc.get("mode", "visible"))


static func flag_of(map_id: String, region: Dictionary, n: int) -> String:
	return "threat:%s:%s:%d" % [map_id, region.get("id", ""), n]


## True if threat n of this region was beaten and hasn't respawned yet.
static func is_cleared(map_id: String, region: Dictionary, n: int) -> bool:
	var at: Variant = GameManager.story_flags.get(flag_of(map_id, region, n))
	if at == null:
		return false
	var hours := float((region.get("encounter", {}) as Dictionary).get("respawn_hours", 12))
	return float(CampaignManager.world_clock) - float(at) < hours


func setup(p_scene: Node) -> RoamingThreats:
	scene = p_scene
	var w: WorldMap = scene.world
	# Same spots for the same visit, new ones as the world clock moves on.
	rng.seed = hash(w.id) + CampaignManager.world_clock
	for r: Dictionary in w.regions:
		if mode_of(r) != "visible":
			continue
		var enc: Dictionary = r["encounter"]
		var cells: Array[Vector2i] = []
		for k: Variant in r.get("cells", []):
			var c := WorldMap.parse_key(str(k))
			if scene.can_step(c, c) and IsometricGrid.distance(c, scene.cell) >= SAFE_SPAWN:
				cells.append(c)
		var n_max := int(enc.get("max_threats", 2))
		for n in n_max:
			if cells.is_empty() or is_cleared(w.id, r, n):
				continue
			var ms: Array = enc["missions"]
			var t := Threat.new()
			t.region = r
			t.index = n
			t.mission_id = str(ms[rng.randi() % ms.size()])
			t.cell = cells[rng.randi() % cells.size()]
			t.fpos = Vector2(t.cell)
			t.aggro = float(enc.get("aggro", 4))
			t.speed_mult = float(enc.get("speed", 1.0))
			t.region_cells = {}
			for k2: Variant in r.get("cells", []):
				t.region_cells[str(k2)] = true
			t.wander_to = t.fpos
			add_child(t)
			t.build(w, _art_for(t.mission_id))
			threats.append(t)
	return self


## The art of the mission's first enemy (or "" for the hostile-signal marker).
static func _art_for(mission_id: String) -> String:
	var m := ContentDB.get_mission(mission_id)
	if m == null or m.enemies.is_empty():
		return ""
	var cd := ContentDB.get_character(str(m.enemies[0].get("character_id", "")))
	return cd.sprite_frames_path if cd else ""


## One frame. Returns the threat that caught the player, or null.
func tick(delta: float) -> Threat:
	if triggered:
		return null
	_grace = maxf(_grace - delta, 0.0)
	var w: WorldMap = scene.world
	var me := Vector2(scene.fpos) if scene.has_method("free_mode") and scene.free_mode() else Vector2(scene.cell)
	for t in threats:
		var to_player := me - t.fpos
		var in_zone: bool = t.region_cells.has(WorldMap.key(scene.cell))
		t.chasing = in_zone and to_player.length() <= t.aggro
		var goal := me if t.chasing else t.wander_to
		if not t.chasing and t.fpos.distance_to(t.wander_to) < 0.1:
			t.wander_to = _pick_wander(t)
			goal = t.wander_to
		var step := (goal - t.fpos)
		var spd := (CHASE_SPEED if t.chasing else WANDER_SPEED) * t.speed_mult * delta
		if step.length() > spd:
			step = step.normalized() * spd
		var np := t.fpos + step
		var nc := Vector2i(roundi(np.x), roundi(np.y))
		if nc == t.cell or _can_enter(t, t.cell, nc):
			t.fpos = np
			t.cell = nc
		elif not t.chasing:
			t.wander_to = t.fpos  # blocked: pick somewhere else next frame
		t.face(w, step)
		t.place(w, scene.grid)
		if _grace <= 0.0 and t.fpos.distance_to(me) <= CONTACT:
			triggered = t
			return t
	return null


func _can_enter(t: Threat, from: Vector2i, to: Vector2i) -> bool:
	if not t.region_cells.has(WorldMap.key(to)):
		return false  # threats stay on their turf
	if scene.mount_id != "":
		# can_step reads the player's mount rules; threats walk on foot.
		var keep: String = scene.mount_id
		scene.mount_id = ""
		var ok: bool = scene.can_step(from, to)
		scene.mount_id = keep
		return ok
	return scene.can_step(from, to)


func _pick_wander(t: Threat) -> Vector2:
	for i in 6:
		var c := t.cell + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		if c != t.cell and _can_enter(t, c, c):
			return Vector2(c)
	return t.fpos


## A hostile on the map: the enemy's own sprite, or a red signal in the fog.
class Threat extends Node2D:
	var region: Dictionary
	var index := 0
	var mission_id := ""
	var cell := Vector2i.ZERO
	var fpos := Vector2.ZERO
	var wander_to := Vector2.ZERO
	var aggro := 4.0
	var speed_mult := 1.0
	var region_cells: Dictionary = {}
	var chasing := false
	var facing := "SW"
	var _spr: AnimatedSprite2D
	var _set: Dictionary = {}
	var _anim := ""
	var _size := 32.0

	func build(w: WorldMap, art: String) -> void:
		_size = w.tile_height
		var us: Dictionary = {}
		if art != "":
			if PixelLab.is_root(art):
				us = PixelLab.unit_set(art)
			elif PixelMatrix.is_root(art):
				us = PixelMatrix.unit_set(art)
			elif art.ends_with(".json") and LatticeClip.is_clip(art):
				us = LatticeClip.unit_set(art)
		if us.get("ok", false):
			_spr = AnimatedSprite2D.new()
			_spr.sprite_frames = us["frames"]
			_spr.scale = Vector2.ONE * w.tile_width * float(us.get("per_tile", 1.0 / 64.0))
			_spr.modulate = Color(1.25, 0.85, 0.95)  # a hostile tint, still their art
			_set = us
			add_child(_spr)
			_play("idle")

	func face(w: WorldMap, step: Vector2) -> void:
		if step.length() < 0.001:
			_play("idle")
			return
		var s := Vector2((step.x - step.y) * w.tile_width * 0.5, (step.x + step.y) * w.tile_height * 0.5)
		facing = ("S" if s.y > 0.0 else "N") + ("E" if s.x > 0.0 else "W")
		_play("run" if chasing else "walk")

	func _play(anim: String) -> void:
		if _spr == null:
			return
		if anim == "run" and str(LatticeClip.resolve(_set, "run", facing)[0]) == "":
			anim = "walk"
		var k := anim + facing
		if k != _anim:
			_anim = k
			LatticeClip.play_on(_spr, _set, anim, facing)

	func place(w: WorldMap, g: IsometricGrid) -> void:
		position = w.to_screen(fpos, g.get_height(cell))
		z_index = (cell.x + cell.y) * 2 + 1
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var pulse := 0.5 + 0.5 * sin(t * (7.0 if chasing else 3.0) + index)
		# Ground glow: HDR red, so it blooms through the fog.
		draw_circle(Vector2.ZERO, _size * 0.55, Color(1.8, 0.1, 0.35, 0.18 + 0.12 * pulse))
		if _spr == null:
			var h := _size * 1.15
			var bob := sin(t * 2.5 + index) * 2.0
			var body := PackedVector2Array([Vector2(0, -h + bob), Vector2(_size * 0.32, -h * 0.55 + bob), Vector2(0, -h * 0.1 + bob), Vector2(-_size * 0.32, -h * 0.55 + bob)])
			draw_colored_polygon(body, Color(0.08, 0.0, 0.05, 0.9))
			draw_polyline(body + PackedVector2Array([body[0]]), Color(2.2, 0.25, 0.6), 2.0)
			# glitch scan lines across the signal
			for i in 3:
				var y := -h * (0.3 + 0.2 * i) + bob + fmod(t * 30.0 + i * 7.0, 6.0)
				draw_line(Vector2(-_size * 0.25, y), Vector2(_size * 0.25, y), Color(2.0, 0.3, 0.7, 0.5), 1.0)
		if chasing:
			var top := -_size * (2.6 if _spr else 1.5)
			draw_string(ThemeDB.fallback_font, Vector2(-5, top), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(2.4, 0.4, 0.6))
