extends RefCounted
## Body of particle_preview.gd: a dark board with one 3×3 iso patch per preset.

const TILE_W := 96.0
const TILE_H := 48.0
const STEP := 24.0
const COLS := 5
const PANEL := Vector2(384, 360)
## Stack layer each preset is shown at (storm clouds float high, fog hugs a rise).
const LAYERS := {"storm_clouds": 6, "fog": 2}

var _patches: Array = []  # [center, raised]


func run(tree: SceneTree, args: PackedStringArray) -> void:
	var out: String = args[0] if args.size() > 0 and not args[0].begins_with("--") else "res://docs/screenshots/particles_preview.png"
	var root := tree.root
	var bg := ColorRect.new()
	bg.color = Color("07040d")
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	var board := Node2D.new()
	root.add_child(board)
	var ground := Node2D.new()
	ground.draw.connect(_draw_ground.bind(ground))
	board.add_child(ground)
	var ids := ParticleFactory.presets().keys()
	var storms: Array[Node] = []
	for i in ids.size():
		var id := str(ids[i])
		var panel := Vector2(i % COLS, i / COLS) * PANEL
		var center := panel + Vector2(PANEL.x * 0.5, PANEL.y - 92)
		var layer: int = LAYERS.get(id, 0)
		var raised := id == "fog"
		_patches.append([center, raised])
		var diamonds: Array[PackedVector2Array] = []
		for y in 3:
			for x in 3:
				var c := center + Vector2((x - y) * TILE_W * 0.5, (x + y - 2) * TILE_H * 0.5)
				var lift := layer * STEP
				diamonds.append(PackedVector2Array([c + Vector2(0, -TILE_H * 0.5 - lift), c + Vector2(TILE_W * 0.5, -lift), c + Vector2(0, TILE_H * 0.5 - lift), c + Vector2(-TILE_W * 0.5, -lift)]))
		var fx := ParticleFactory.make_for_cells(id, diamonds)
		board.add_child(fx)
		if fx.has_node("Lightning"):
			storms.append(fx.get_node("Lightning"))
		var icon := TextureRect.new()
		icon.texture = ParticleFactory.preview_icon(id)
		icon.position = panel + Vector2(16, 14)
		icon.custom_minimum_size = Vector2(32, 32)
		root.add_child(icon)
		var label := Label.new()
		label.text = "%s  [%s]" % [str(ParticleFactory.get_preset(id).get("name", id)).to_upper(), id]
		label.position = panel + Vector2(56, 18)
		label.add_theme_font_override("font", NeonTheme.mono())
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", NeonTheme.TEXT_DIM)
		root.add_child(label)
	ground.queue_redraw()
	# ~2 s of simulation on top of each emitter's preprocess.
	for f in 120:
		await tree.process_frame
	if not args.has("--no-flash"):
		for s in storms:
			s.call("flash_now")
	for f in 2:
		await tree.process_frame
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img.save_png(out)
	print("saved ", out, " ", img.get_size())


func _draw_ground(ci: Node2D) -> void:
	for p: Array in _patches:
		var center: Vector2 = p[0]
		for y in 3:
			for x in 3:
				var c := center + Vector2((x - y) * TILE_W * 0.5, (x + y - 2) * TILE_H * 0.5)
				var h := 2.0 if bool(p[1]) and x == 1 and y == 1 else (1.0 if bool(p[1]) else 0.0)
				_column(ci, c, h * STEP)


func _column(ci: Node2D, c: Vector2, lift: float) -> void:
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	var t := c + Vector2(0, -lift)
	var n := t + Vector2(0, -hh)
	var e := t + Vector2(hw, 0)
	var s := t + Vector2(0, hh)
	var w := t + Vector2(-hw, 0)
	var base := lift + 8.0
	ci.draw_colored_polygon(PackedVector2Array([w, s, s + Vector2(0, base), w + Vector2(0, base)]), Color("1a1626"))
	ci.draw_colored_polygon(PackedVector2Array([s, e, e + Vector2(0, base), s + Vector2(0, base)]), Color("120f1c"))
	ci.draw_colored_polygon(PackedVector2Array([n, e, s, w]), Color("2a2438"))
	ci.draw_polyline(PackedVector2Array([n, e, s, w, n]), Color(0.45, 0.3, 0.7, 0.9), 1.0)
