extends RefCounted


func _wait(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame


func run(tree: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var map_id: String = args[0] if args.size() > 0 else "neon_expanse"
	var out: String = args[1] if args.size() > 1 else "user://world"
	tree.change_scene_to_file("res://scenes/editor/neon_forge.tscn")
	await _wait(tree, 10)
	tree.current_scene.call("show_section", "world")
	await _wait(tree, 5)
	var painter: ForgeWorldPainter = tree.current_scene.get("_world")
	painter.load_map(map_id)
	painter.set_mode(ForgeWorldPainter.Mode.OBJECTS)
	if args.size() > 2 and args[2] == "generate":
		painter.set_mode(ForgeWorldPainter.Mode.TILES)
		painter.sel_tiles = ["terrain:water", "terrain:sand", "terrain:grass", "terrain:forest", "terrain:rock", "terrain:snow"]
		painter.generate_terrain(Rect2i(), 9, 0.07, 0.32, 7)
	if args.size() > 2 and args[2] == "ramps":
		painter.new_map("ramp_demo", "encounter", 12, 12)
		var w: WorldMap = painter.world
		for x in 12:
			for y in 12:
				var h := 0 if x < 4 else (1 if x < 7 else 2)
				for z in h + 1:
					w.set_tile(Vector2i(x, y), z, "terrain:concrete" if z < h else ("terrain:grass" if h == 0 else ("terrain:rock" if h == 1 else "terrain:sand")))
		for y in range(2, 5):
			w.set_tile(Vector2i(3, y), 0, "terrain:grass", {"ramp": "x+"})
			w.set_tile(Vector2i(6, y), 1, "terrain:rock", {"ramp": "x+", "stairs": true})
		for y in range(7, 10):
			w.set_tile(Vector2i(3, y), 0, "terrain:grass", {"flip": true, "tint": "#e8d8ff"})
		painter._renderer.rebuild()
		await _wait(tree, 3)
		painter._snap_cam(w.to_screen(Vector2(5, 4), 1), 1.5)
	if args.size() > 2 and args[2] == "tactics":
		painter.set_mode(ForgeWorldPainter.Mode.GAMEPLAY)
		painter.tactics_view = true
		painter._hover_cell = Vector2i(painter.world.width / 2, painter.world.depth / 2)
		painter._hover_z = painter.world.top_z(painter._hover_cell)
	if args.size() > 2 and args[2] == "masks":
		painter.set_mode(ForgeWorldPainter.Mode.MASKS)
		painter.mask_tool = ForgeWorldPainter.Mask.ANCHOR
		painter.sel_anchor = painter.world.anchors[0] if not painter.world.anchors.is_empty() else {}
		painter._build_palette()
		painter._hover_cell = Vector2i(9, 6)
		painter._hover_z = 0
		await _wait(tree, 3)
		painter._snap_cam(painter.world.to_screen(Vector2(8, 7), 0), 0.62)
	await _wait(tree, 90)
	tree.root.get_texture().get_image().save_png(out + "_painter.png")
	var cm: Node = tree.root.get_node("CampaignManager")
	cm.set("current_explore", {"map_id": map_id, "spawn": 0})
	tree.change_scene_to_file("res://scenes/world/explore.tscn")
	await _wait(tree, 20)
	var ex: Node = tree.current_scene
	# Walk toward the first location so its label and prompt show.
	var locs: Array = ex.get("world").locations()
	var ancs: Array = ex.get("world").anchors
	if args.size() > 2 and args[2] == "masks" and not ancs.is_empty():
		ex.set("cell", Vector2i(int(ancs[0]["cell"][0]) - 1, int(ancs[0]["cell"][1])))
		ex.call("_place_avatar")
	elif not locs.is_empty():
		var c: Array = locs[0]["cell"]
		var target := Vector2i(int(c[0]), int(c[1]) + 1)
		ex.set("cell", target)
		ex.call("_place_avatar")
	await _wait(tree, 90)
	tree.root.get_texture().get_image().save_png(out + "_explore.png")
	print("saved ", out)
