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
	if args.size() > 2 and args[2] == "tactics":
		painter.set_mode(ForgeWorldPainter.Mode.GAMEPLAY)
		painter.tactics_view = true
		painter._hover_cell = Vector2i(painter.world.width / 2, painter.world.depth / 2)
		painter._hover_z = painter.world.top_z(painter._hover_cell)
	await _wait(tree, 90)
	tree.root.get_texture().get_image().save_png(out + "_painter.png")
	var cm: Node = tree.root.get_node("CampaignManager")
	cm.set("current_explore", {"map_id": map_id, "spawn": 0})
	tree.change_scene_to_file("res://scenes/world/explore.tscn")
	await _wait(tree, 20)
	var ex: Node = tree.current_scene
	# Walk toward the first location so its label and prompt show.
	var locs: Array = ex.get("world").locations()
	if not locs.is_empty():
		var c: Array = locs[0]["cell"]
		var target := Vector2i(int(c[0]), int(c[1]) + 1)
		ex.set("cell", target)
		ex.call("_place_avatar")
	await _wait(tree, 90)
	tree.root.get_texture().get_image().save_png(out + "_explore.png")
	print("saved ", out)
