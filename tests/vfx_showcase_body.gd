extends RefCounted
## Body of vfx_showcase.gd: a 4×6 board of iso floor patches, one VFX each,
## frozen at a good moment (VFX.paused + advance_to), then a 3-frame strip of
## plasma_explosion.

const COLS := 6
const PANEL := Vector2(320, 270)
const TILE := Vector2(96, 48)
const SCALE := 1.5
const CASTER := Color(0.25, 0.85, 1.0)
const FOE := Color(1.0, 0.25, 0.55)

## id -> {t: seconds to freeze at, at/to/targets: offsets from the panel's
## ground point, dummies: [[offset, colour, alpha]]}
const SHOTS := {
	"impact_physical": {"t": 0.07, "dummies": [[Vector2(0, -4), FOE, 1.0]]},
	"impact_kinetic": {"t": 0.12, "dummies": [[Vector2(0, -4), FOE, 1.0]]},
	"impact_tech": {"t": 0.1, "dummies": [[Vector2(0, -4), FOE, 1.0]]},
	"plasma_burst": {"t": 0.08},
	"plasma_explosion": {"t": 0.2},
	"electric_arc": {"t": 0.1, "at": Vector2(-100, 22), "to": Vector2(96, -12), "dummies": [[Vector2(-100, 22), CASTER, 1.0], [Vector2(96, -12), FOE, 1.0]]},
	"chain_lightning": {"t": 0.36, "at": Vector2(-118, 30), "targets": [Vector2(-22, -26), Vector2(56, 26), Vector2(120, -22)],
		"dummies": [[Vector2(-118, 30), CASTER, 1.0], [Vector2(-22, -26), FOE, 1.0], [Vector2(56, 26), FOE, 1.0], [Vector2(120, -22), FOE, 1.0]]},
	"cryo_shatter": {"t": 0.2},
	"void_implosion": {"t": 0.36},
	"essence_drain": {"t": 0.52, "at": Vector2(-96, 22), "to": Vector2(92, -12), "dummies": [[Vector2(-96, 22), CASTER, 1.0], [Vector2(92, -12), FOE, 1.0]]},
	"heal_bloom": {"t": 0.5, "dummies": [[Vector2(0, -2), CASTER, 1.0]]},
	"buff_aura": {"t": 0.55, "dummies": [[Vector2(0, -2), CASTER, 1.0]]},
	"debuff_curse": {"t": 0.62, "dummies": [[Vector2(0, -2), FOE, 1.0]]},
	"summon_portal": {"t": 0.62},
	"teleport_glitch": {"t": 0.13, "dummies": [[Vector2(0, -2), CASTER, 0.45]]},
	"droid_build": {"t": 0.85},
	"level_up": {"t": 0.38, "dummies": [[Vector2(0, -2), CASTER, 1.0]]},
	"crit_hit": {"t": 0.09, "dummies": [[Vector2(0, -4), FOE, 1.0]]},
	"death_dissolve": {"t": 0.5, "dummies": [[Vector2(0, -2), FOE, 0.35]], "color": "#ff2e88"},
	"footstep_dust": {"t": 0.14, "dummies": [[Vector2(10, -2), CASTER, 1.0]]},
	"landing_dust": {"t": 0.16, "dummies": [[Vector2(0, -2), CASTER, 1.0]]},
	"water_splash": {"t": 0.22, "water": true},
	"neon_sign_sparks": {"t": 0.3, "sign": true},
	"rain_splash": {"t": 0.12, "water": true},
}

var _floor: Array = []  # [ground point, water?, sign?]
var _dummies: Array = []  # [pos, colour, alpha]


func run(tree: SceneTree, args: PackedStringArray) -> void:
	var out: String = args[0] if args.size() > 0 else "res://docs/screenshots/vfx_showcase.png"
	var seq_out: String = args[1] if args.size() > 1 else "res://docs/screenshots/vfx_plasma_sequence.png"
	VFX.paused = true
	VFX.hit_stop_enabled = false
	VFX.shake_enabled = false
	var root := tree.root
	_environment(root)
	var stage := _stage(root)
	var ids: Array = SHOTS.keys()
	for id: String in VFX.effect_ids():
		if not ids.has(id) and ids.size() < 24:
			ids.append(id)
	for i in ids.size():
		var id := str(ids[i])
		var shot: Dictionary = SHOTS.get(id, {"t": 0.15})
		var panel := Vector2(i % COLS, i / COLS) * PANEL
		var g := panel + Vector2(PANEL.x * 0.5, PANEL.y - 74)
		_floor.append([g, bool(shot.get("water", false)), bool(shot.get("sign", false))])
		for dm: Array in shot.get("dummies", []):
			_dummies.append([g + dm[0] * 0.85, dm[1], dm[2]])
		var params := {"scale": SCALE, "seed": 1000 + i}
		if shot.has("to"):
			params["to"] = g + shot["to"] * 0.85
		if shot.has("targets"):
			var tg: Array = []
			for o: Vector2 in shot["targets"]:
				tg.append(g + o * 0.85)
			params["targets"] = tg
		if shot.has("color"):
			params["color"] = shot["color"]
		var at: Vector2 = g + shot.get("at", Vector2.ZERO) * 0.85
		var fx := VFX.spawn(stage, id, at, params) as VFXEffect
		fx.advance_to(float(shot["t"]))
		_label(root, panel, id, float(shot["t"]))
	stage.get_node("Floor").queue_redraw()
	for f in 3:
		await tree.process_frame
	_save(root, out, Rect2())
	# --- plasma_explosion over time -------------------------------------
	for c in stage.get_children():
		if c is VFXEffect:
			c.free()
	for c in root.get_children():
		if c is Label:
			c.free()
	_floor.clear()
	_dummies.clear()
	var times := [0.05, 0.3, 1.1]
	for i in 3:
		var g := Vector2(320 + i * 640, 610)
		_floor.append([g, false, false])
		var fx := VFX.spawn(stage, "plasma_explosion", g, {"scale": 2.2, "seed": 77}) as VFXEffect
		fx.advance_to(times[i])
		_label(root, Vector2(i * 640, 180), "plasma_explosion", times[i])
	stage.get_node("Floor").set_meta("big", true)
	stage.get_node("Floor").queue_redraw()
	for f in 3:
		await tree.process_frame
	_save(root, seq_out, Rect2(0, 180, 1920, 640))
	VFX.paused = false
	VFX.hit_stop_enabled = true
	VFX.shake_enabled = true


func _environment(root: Window) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 0.6)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var bg := ColorRect.new()
	bg.color = Color("07040d")
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)


func _stage(root: Window) -> Node2D:
	var stage := Node2D.new()
	stage.name = "Stage"
	root.add_child(stage)
	var fl := Node2D.new()
	fl.name = "Floor"
	fl.draw.connect(_draw_floor.bind(fl))
	stage.add_child(fl)
	# A dim ambient so PointLight2D pulses visibly lift the floor.
	var cm := CanvasModulate.new()
	cm.color = Color(0.78, 0.74, 0.9)
	stage.add_child(cm)
	return stage


func _label(root: Window, panel: Vector2, id: String, t: float) -> void:
	var label := Label.new()
	label.text = "%s   t=%.2fs" % [id, t]
	label.position = panel + Vector2(14, 10)
	label.add_theme_font_override("font", NeonTheme.mono())
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", NeonTheme.TEXT_DIM)
	root.add_child(label)


func _save(root: Window, path: String, crop: Rect2) -> void:
	var img := root.get_texture().get_image()
	if crop.has_area():
		img = img.get_region(Rect2i(crop))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _draw_floor(ci: Node2D) -> void:
	var big: bool = ci.get_meta("big", false)
	var tile := TILE * (1.4 if big else 1.0)
	var n := 5 if big else 3
	for f: Array in _floor:
		var g: Vector2 = f[0]
		for y in n:
			for x in n:
				var o := Vector2((x - y) * tile.x * 0.5, (x + y - (n - 1)) * tile.y * 0.5)
				_tile(ci, g + o, tile, bool(f[1]))
		if bool(f[2]):
			_sign(ci, g)
	for dm: Array in _dummies:
		_dummy(ci, dm[0], dm[1], dm[2])


func _tile(ci: Node2D, c: Vector2, tile: Vector2, water: bool) -> void:
	var hw := tile.x * 0.5
	var hh := tile.y * 0.5
	var n := c + Vector2(0, -hh)
	var e := c + Vector2(hw, 0)
	var s := c + Vector2(0, hh)
	var w := c + Vector2(-hw, 0)
	var depth := 14.0
	ci.draw_colored_polygon(PackedVector2Array([w, s, s + Vector2(0, depth), w + Vector2(0, depth)]), Color("15111f"))
	ci.draw_colored_polygon(PackedVector2Array([s, e, e + Vector2(0, depth), s + Vector2(0, depth)]), Color("0e0b16"))
	ci.draw_colored_polygon(PackedVector2Array([n, e, s, w]), Color("1c3a5a") if water else Color("2a2438"))
	ci.draw_polyline(PackedVector2Array([n, e, s, w, n]), Color(0.35, 0.6, 0.9, 0.6) if water else Color(0.42, 0.28, 0.66, 0.85), 1.0)


func _sign(ci: Node2D, g: Vector2) -> void:
	# A broken neon sign on a pole: the sparks rain out of its corner.
	ci.draw_rect(Rect2(g + Vector2(46, -150), Vector2(6, 150)), Color("1a1626"))
	var box := Rect2(g + Vector2(-60, -160), Vector2(112, 44))
	ci.draw_rect(box, Color("120c1c"))
	ci.draw_rect(box, Color(1.6, 0.3, 0.9), false, 3.0)
	ci.draw_string(NeonTheme.mono(), box.position + Vector2(12, 30), "N  OD L S", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.4, 0.4, 1.0))


func _dummy(ci: Node2D, p: Vector2, col: Color, alpha: float) -> void:
	var dim := col.darkened(0.55)
	dim.a = alpha
	var c := Color(col, alpha)
	var s := SCALE
	var ring := PackedVector2Array()
	for i in 24:
		var ang := TAU * i / 24.0
		ring.append(p + Vector2(cos(ang) * 18.0, sin(ang) * 9.0) * s)
	ci.draw_colored_polygon(ring, Color(col, 0.15 * alpha))
	var body := PackedVector2Array()
	for v: Vector2 in [Vector2(-10, 0), Vector2(-12, -22), Vector2(-7, -34), Vector2(7, -34), Vector2(12, -22), Vector2(10, 0)]:
		body.append(p + v * s)
	ci.draw_colored_polygon(body, dim)
	body.append(body[0])
	ci.draw_polyline(body, c, 2.0)
	ci.draw_circle(p + Vector2(0, -41) * s, 7.0 * s, dim)
	ci.draw_arc(p + Vector2(0, -41) * s, 7.0 * s, 0, TAU, 20, c, 2.0)
	ci.draw_line(p + Vector2(-4, -42) * s, p + Vector2(4, -42) * s, c.lightened(0.4), 3.0)
