extends RefCounted
## Body of tests/hop_shot.gd: a short path up one ledge (2 height steps) and
## back to flat ground, captured every frame (run with --fixed-fps 30).

const PATH := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const HEIGHTS := {Vector2i(2, 0): 2, Vector2i(3, 0): 2}


func run(tree: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0]
	var out: String = args[1]
	Unit.jump_with_anim = args.size() < 3 or args[2] != "walk"
	DirAccess.make_dir_recursive_absolute(out)
	var root := Node2D.new()
	tree.root.add_child(root)
	root.scale = Vector2(2.4, 2.4)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.11)
	bg.size = Vector2(900, 600)
	bg.position = Vector2(-200, -200)
	root.add_child(bg)
	var g := IsometricGrid.new()
	g.setup(5, 3)
	g.tile_width = 128.0
	g.tile_height = 64.0
	g.height_step = 32.0
	g.origin = Vector2(110, 150)
	for c: Vector2i in HEIGHTS:
		g.set_height(c, HEIGHTS[c])
	var cells: Array = []
	for y in range(2, -1, -1):
		for x in 5:
			cells.append(Vector2i(x, y - 1))
	cells.sort_custom(func(a: Vector2i, b2: Vector2i) -> bool: return a.x + a.y < b2.x + b2.y)
	for c: Vector2i in cells:
		if c.y < 0 or c.y > 0:
			continue
		_tile(root, g, c)
	var cd: CharacterData = (ContentDB.get_all("characters")[0] as CharacterData).duplicate(true)
	cd.sprite_frames_path = folder
	cd.equipment = {}
	var u := Unit.new()
	u.grid = g
	u.setup(cd, Unit.Team.PLAYER, 1)
	root.add_child(u)
	u.place_at(PATH[0])
	u.facing = Vector2i(1, 0)
	if u.hud:
		u.hud.visible = false
	for i in 10:
		await tree.process_frame
	var path: Array[Vector2i] = []
	for p: Vector2i in PATH:
		path.append(p)
	# Lambdas copy locals in GDScript: share state through a Dictionary.
	var st := {"moving": true}
	var mover := func() -> void:
		await u.move_along(path, true)
		st["moving"] = false
	mover.call()
	var n := 0
	var tail := 20
	var guard := 1200
	while (st["moving"] or tail > 0) and guard > 0:
		guard -= 1
		await tree.process_frame
		if not st["moving"]:
			tail -= 1
		if true:

			tree.root.get_texture().get_image().save_png("%s/f_%04d.png" % [out, n])
			n += 1
	print("captured ", n)


func _tile(root: Node2D, g: IsometricGrid, c: Vector2i) -> void:
	var top := g.grid_to_world(c)
	var w := g.tile_width * 0.5
	var h := g.tile_height * 0.5
	var lift := g.get_height(c) * g.height_step
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([top + Vector2(0, -h), top + Vector2(w, 0), top + Vector2(0, h), top + Vector2(-w, 0)])
	poly.color = Color(0.18, 0.16, 0.3) if (c.x + c.y) % 2 == 0 else Color(0.22, 0.2, 0.36)
	if lift > 0.0:
		var side := Polygon2D.new()
		side.polygon = PackedVector2Array([top + Vector2(-w, 0), top + Vector2(0, h), top + Vector2(w, 0), top + Vector2(w, lift), top + Vector2(0, h + lift), top + Vector2(-w, lift)])
		side.color = Color(0.1, 0.09, 0.18)
		root.add_child(side)
	root.add_child(poly)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([top + Vector2(0, -h), top + Vector2(w, 0), top + Vector2(0, h), top + Vector2(-w, 0), top + Vector2(0, -h)])
	edge.width = 2
	edge.default_color = Color(0.0, 0.9, 1.0, 0.45)
	root.add_child(edge)
