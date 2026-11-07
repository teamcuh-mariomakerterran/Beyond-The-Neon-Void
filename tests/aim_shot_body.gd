extends RefCounted
## Body of tests/aim_shot.gd: one unit on one tile, gun attached to the hand
## point, Unit.aim_and_fire(2), captured every frame (run with --fixed-fps 30).


func run(tree: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0]
	var weapon: String = args[1]
	var out: String = args[2]
	DirAccess.make_dir_recursive_absolute(out)
	var root := Node2D.new()
	tree.root.add_child(root)
	root.scale = Vector2(4.0, 4.0)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.11)
	bg.size = Vector2(400, 400)
	bg.position = Vector2(-100, -100)
	root.add_child(bg)
	var g := IsometricGrid.new()
	g.setup(3, 3)
	g.tile_width = 128.0
	g.tile_height = 64.0
	g.height_step = 32.0
	g.origin = Vector2(70, 110)
	var top := g.grid_to_world(Vector2i(0, 0))
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([top + Vector2(0, -32), top + Vector2(64, 0), top + Vector2(0, 32), top + Vector2(-64, 0)])
	poly.color = Color(0.18, 0.16, 0.3)
	root.add_child(poly)
	var cd: CharacterData = (ContentDB.get_all("characters")[0] as CharacterData).duplicate(true)
	cd.sprite_frames_path = folder
	cd.equipment = {}
	var u := Unit.new()
	u.grid = g
	u.setup(cd, Unit.Team.PLAYER, 1)
	root.add_child(u)
	u.place_at(Vector2i(0, 0))
	u.facing = Vector2i(1, 0)
	if u.hud:
		u.hud.visible = false
	for i in 4:
		await tree.process_frame
	u.gear = GearAttach.attach_to(u.sprite, folder, [weapon])
	var st := {"busy": true}
	var go := func() -> void:
		for i in 10:
			await tree.process_frame
		await u.aim_and_fire(2, 0.25)
		for i in 12:
			await tree.process_frame
		u.play_animation("idle")
		st["busy"] = false
	go.call()
	var n := 0
	var tail := 12
	var guard := 600
	while (st["busy"] or tail > 0) and guard > 0:
		guard -= 1
		await tree.process_frame
		if not st["busy"]:
			tail -= 1
		tree.root.get_texture().get_image().save_png("%s/f_%04d.png" % [out, n])
		n += 1
	print("captured ", n, " anim ", u.sprite.animation)
