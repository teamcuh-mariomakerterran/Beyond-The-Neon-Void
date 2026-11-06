class_name UnitGallery
extends Node2D
## Test scene: every unit folder in assets/units (PixelLab exports, PixelMatrix
## packs) in all 8 facings, playing the same action side by side, so new
## characters and animations can be checked at a glance. Nothing here is
## game logic; it only reads the same loaders the battle units use.
##
##   ← →  / A D      previous / next action (idle, walk, run, attack…)
##   W               weapon on / off (the pilot blade, on bodies with a rig.json)
##   wheel / ↑ ↓     scroll        Esc   back to the title

const SCENE := "res://scenes/test/unit_gallery.tscn"
const ROOT := "res://assets/units"
const BLADE := "res://assets/gear/weapons/pilot_blade"
const FACINGS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const CELL := Vector2(150, 190)
const LEFT := 230.0
const TOP := 150.0
const SCALE := 2.0

## One row per unit: {dir, name, set, sprites: [AnimatedSprite2D x8], actions}.
var rows: Array[Dictionary] = []
## Actions any unit has, in a friendly order.
var actions: Array[String] = []
var action := "idle"
var weapons := false
var _cam: Camera2D
var _hud: Label


## Unit folders the loaders understand, sorted (pool characters first).
static func unit_dirs() -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(ROOT):
		return out
	var names := Array(DirAccess.get_directories_at(ROOT))
	names.sort_custom(func(a: String, b: String) -> bool:
		if a.begins_with("pool_") != b.begins_with("pool_"):
			return a.begins_with("pool_")
		return a.naturalnocasecmp_to(b) < 0)
	for n: String in names:
		var d := ROOT.path_join(n)
		if PixelLab.is_root(d) or PixelMatrix.is_root(d):
			out.append(d)
	return out


func _ready() -> void:
	RenderingServer.set_default_clear_color(NeonTheme.BG)
	add_child(NeonTheme.glow_environment())
	_cam = Camera2D.new()
	_cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_cam)
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_hud = NeonTheme.label("", 15, NeonTheme.TEXT)
	_hud.position = Vector2(20, 14)
	ui.add_child(_hud)
	build()


## Loads every unit and lays out the grid.
func build() -> void:
	for r: Dictionary in rows:
		for s: Node in r["sprites"]:
			s.queue_free()
		(r["label"] as Node).queue_free()
	rows.clear()
	var seen := {}
	for c in FACINGS.size():
		var head := NeonTheme.label(FACINGS[c], 20, NeonTheme.CYAN)
		head.position = Vector2(LEFT + c * CELL.x - 10, TOP - 64)
		add_child(head)
	var y := TOP
	for d in unit_dirs():
		var us: Dictionary = PixelLab.unit_set(d) if PixelLab.is_root(d) else PixelMatrix.unit_set(d)
		if not us.get("ok", false):
			continue
		var sf: SpriteFrames = us["frames"]
		var acts: Array[String] = []
		for a: StringName in sf.get_animation_names():
			var act := str(a).left(str(a).rfind("_")) if "_" in str(a) else str(a)
			if not act in acts:
				acts.append(act)
			seen[act] = true
		var lab := NeonTheme.label("%s\n%d actions" % [d.get_file(), acts.size()], 14, NeonTheme.TEXT_DIM)
		lab.position = Vector2(20, y + CELL.y * 0.3)
		add_child(lab)
		var sprites: Array[AnimatedSprite2D] = []
		for c in FACINGS.size():
			var spr := AnimatedSprite2D.new()
			spr.sprite_frames = sf
			# Same size as in battle (a 128 px tile), then doubled for a close look.
			spr.scale = Vector2.ONE * 128.0 * float(us.get("per_tile", 1.0 / 64.0)) * SCALE
			spr.position = Vector2(LEFT + c * CELL.x, y + CELL.y * 0.85)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(spr)
			sprites.append(spr)
		rows.append({"dir": d, "name": d.get_file(), "set": us, "sprites": sprites, "actions": acts, "label": lab, "gear": []})
		y += CELL.y
	var order := ["idle", "walk", "run", "attack", "cast", "hit", "death"]
	actions.clear()
	for a: String in order:
		if seen.has(a):
			actions.append(a)
	for a2: String in seen:
		if not a2 in actions:
			actions.append(a2)
	if not action in actions and not actions.is_empty():
		action = actions[0]
	play()


## Plays the current action in every cell (idle where a unit lacks it).
func play() -> void:
	for r: Dictionary in rows:
		var us: Dictionary = r["set"]
		for c in FACINGS.size():
			var spr: AnimatedSprite2D = r["sprites"][c]
			if not LatticeClip.play_on(spr, us, action, FACINGS[c]):
				LatticeClip.play_on(spr, us, "idle", FACINGS[c])
	_refresh_weapons()
	_update_hud()


func _refresh_weapons() -> void:
	for r: Dictionary in rows:
		for g: Node in r["gear"]:
			if is_instance_valid(g):
				g.queue_free()
		(r["gear"] as Array).clear()
		for spr: AnimatedSprite2D in r["sprites"]:
			for ch in spr.get_children():
				spr.remove_child(ch)
				ch.queue_free()
			if not weapons:
				continue
			var g := GearAttach.attach_to(spr, str(r["dir"]), [BLADE])
			if g:
				(r["gear"] as Array).append(g)


func _update_hud() -> void:
	var with_rig := rows.filter(func(r: Dictionary) -> bool: return FileAccess.file_exists(str(r["dir"]).path_join("rig.json"))).size()
	_hud.text = "UNIT GALLERY  ·  %d units  ·  action: %s  (%d / %d)   ·   weapon %s (%d with a rig)\n← → action   W weapon   wheel / ↑ ↓ scroll   Esc back" % [
		rows.size(), action.to_upper(), actions.find(action) + 1, actions.size(), "ON" if weapons else "OFF", with_rig]


## For screenshots (tests/screenshot.gd "preset:walk:weapon").
func preset(act: String, weapon: String = "") -> void:
	if actions.has(act):
		action = act
	weapons = weapon == "weapon"
	play()


func step_action(d: int) -> void:
	if actions.is_empty():
		return
	action = actions[(actions.find(action) + d + actions.size()) % actions.size()]
	play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_RIGHT, KEY_D: step_action(1)
			KEY_LEFT, KEY_A: step_action(-1)
			KEY_W:
				weapons = not weapons
				play()
			KEY_UP: _scroll(-CELL.y)
			KEY_DOWN: _scroll(CELL.y)
			KEY_ESCAPE: SceneManager.change_scene("res://scenes/main.tscn")
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll(-60)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll(60)


func _scroll(dy: float) -> void:
	var bottom := maxf(0.0, TOP + rows.size() * CELL.y - get_viewport_rect().size.y + 40)
	_cam.position.y = clampf(_cam.position.y + dy, 0.0, bottom)
