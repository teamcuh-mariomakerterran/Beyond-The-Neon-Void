extends RefCounted
## World format v2 tests: stacks, projection/picking, v1 conversion, battle
## grid flattening, save round-trip, World Painter tools and exploration.

var _fails := 0
var _passes := 0
var tree: SceneTree


func run(p_tree: SceneTree) -> int:
	tree = p_tree
	test_stacks()
	test_projection()
	test_roundtrip_and_v1()
	test_to_grid()
	await test_painter()
	await test_explore()
	print("=== world: %d passed, %d failed ===" % [_passes, _fails])
	return _fails


func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("FAIL [world]: ", msg)


func _map() -> WorldMap:
	var w := WorldMap.new()
	w.id = "t_world"
	w.width = 8
	w.depth = 8
	return w


func test_stacks() -> void:
	var w := _map()
	w.set_tile(Vector2i(2, 2), 0, "terrain:concrete")
	w.set_tile(Vector2i(2, 2), 3, "terrain:catwalk")
	w.set_tile(Vector2i(2, 2), -2, "terrain:metal_grate")
	var zs: Array = w.stack_at(Vector2i(2, 2)).map(func(e: Array) -> int: return int(e[0]))
	check(zs == [-2, 0, 3], "stack sorted by layer incl. negative: %s" % [zs])
	check(w.top_z(Vector2i(2, 2)) == 3 and w.top_tile(Vector2i(2, 2)) == "terrain:catwalk", "top of stack")
	w.set_tile(Vector2i(2, 2), 0, "terrain:crate")
	check(w.tile_at(Vector2i(2, 2), 0) == "terrain:crate" and w.stack_at(Vector2i(2, 2)).size() == 3, "overwrite same layer")
	check(w.remove_tile(Vector2i(2, 2), 3) and w.top_z(Vector2i(2, 2)) == 0, "remove layer")
	w.set_tile(Vector2i(99, 0), 0, "x")
	check(not w.tiles.has(Vector2i(99, 0)), "out of bounds ignored")
	w.set_particle(Vector2i(1, 1), 3, "fog")
	w.set_particle(Vector2i(1, 2), 3, "fog")
	w.set_particle(Vector2i(1, 2), 15, "storm_clouds")
	var groups := w.particle_groups()
	check(groups.has("fog|3") and (groups["fog|3"] as Array).size() == 2 and groups.has("storm_clouds|15"), "particle groups")


func test_projection() -> void:
	var w := _map()
	for c: Vector2i in [Vector2i(0, 0), Vector2i(3, 5), Vector2i(7, 1)]:
		for z: int in [-3, 0, 4]:
			check(w.pick_plane(w.to_screen(Vector2(c), z) + Vector2(5, 3), z) == c, "plane pick %s z%d" % [c, z])
	w.set_tile(Vector2i(3, 3), 0, "terrain:concrete")
	w.set_tile(Vector2i(4, 4), 6, "terrain:concrete")
	# A tall column in front hides the one behind it.
	var hit := w.pick_top(w.to_screen(Vector2(4, 4), 6))
	check(not hit.is_empty() and hit[0] == Vector2i(4, 4) and int(hit[1]) == 6, "pick_top finds tall front column")


func test_roundtrip_and_v1() -> void:
	var w := _map()
	w.kind = "world"
	w.set_tile(Vector2i(1, 2), 0, "god_tiles/grass/grass_01")
	w.set_tile(Vector2i(1, 2), -1, "god_tiles/stone/stone_01")
	w.set_particle(Vector2i(1, 2), 2, "fog")
	var o := w.add_object("res://assets/structures/27_neon_bar.png", Vector2i(1, 2), 0, "location")
	o["location"] = {"type": "city", "name": "Test City", "target_map": "t_hub"}
	w.add_detail("res://assets/details/crater.png", Vector2(1.3, 2.2), 0)
	w.gameplay[Vector2i(1, 2)] = {"cover": 1}
	var json := JSON.parse_string(JSON.stringify(w.to_dict())) as Dictionary
	var w2 := WorldMap.from_dict(json)
	check(w2.kind == "world" and w2.stack_at(Vector2i(1, 2)).size() == 2, "round-trip stacks")
	check(w2.tile_at(Vector2i(1, 2), -1) == "god_tiles/stone/stone_01", "round-trip negative layer")
	check(w2.particle_groups().has("fog|2"), "round-trip particles")
	check(w2.locations().size() == 1 and str(w2.locations()[0]["location"]["name"]) == "Test City", "round-trip location")
	check(w2.details.size() == 1 and int(w2.gameplay[Vector2i(1, 2)]["cover"]) == 1, "round-trip details + gameplay")
	# Classic maps convert to one-tile stacks.
	var v1 := ContentDB.get_map("supply_works_dock")
	var wv := WorldMap.from_dict(v1)
	check(wv.tiles.size() == int(v1["width"]) * int(v1["depth"]), "v1 → stacks: every cell")
	check(wv.top_tile(Vector2i(0, 9)) == "terrain:metal_grate", "v1 terrain becomes terrain: tile id")


func test_to_grid() -> void:
	var w := _map()
	for x in 8:
		for y in 8:
			w.set_tile(Vector2i(x, y), 0, "terrain:concrete")
	w.set_tile(Vector2i(2, 2), 1, "terrain:concrete")
	w.set_tile(Vector2i(2, 2), 2, "terrain:crate")
	w.remove_tile(Vector2i(5, 5), 0)
	w.set_tile(Vector2i(6, 6), -3, "terrain:concrete")
	w.remove_tile(Vector2i(6, 6), 0)
	w.gameplay[Vector2i(1, 1)] = {"walkable": false}
	w.add_object("", Vector2i(3, 3), 0, "structure")
	var g := w.to_grid()
	check(g.get_height(Vector2i(2, 2)) == 2 and not g.is_walkable(Vector2i(2, 2)), "grid height = top layer, crate rules")
	check(not g.is_walkable(Vector2i(5, 5)), "empty column is a hole")
	check(g.get_height(Vector2i(6, 6)) == -3 and g.is_walkable(Vector2i(6, 6)), "below-ground column walkable at -3")
	check(not g.is_walkable(Vector2i(1, 1)), "gameplay override")
	check(not g.is_walkable(Vector2i(3, 3)) and g.get_cell(Vector2i(3, 3)).blocks_los, "structure blocks")
	check(g.tile_width == w.tile_width, "grid uses map tile size")
	# A 2×2 building claims its footprint (front corner = its cell).
	var big := w.add_object("res://assets/structures/27_neon_bar.png", Vector2i(6, 3), 0, "structure")
	check(WorldMap.footprint(big) == 2 and WorldMap.footprint_cells(big).size() == 4, "structures default to a 2×2 footprint")
	var g2 := w.to_grid()
	check(not g2.is_walkable(Vector2i(5, 2)) and not g2.is_walkable(Vector2i(6, 3)) and g2.is_walkable(Vector2i(7, 3)), "footprint blocks its cells only")
	check(w.objects_at(Vector2i(5, 3)).has(big) and is_equal_approx(WorldMap.distance_to(big, Vector2i(7, 3)), 1.0), "objects_at / distance use the footprint")
	big["footprint"] = 1
	check(w.to_grid().is_walkable(Vector2i(5, 2)), "footprint override 1")


func _press(p: ForgeWorldPainter, cell: Vector2i, z: int) -> void:
	p._hover_cell = cell
	p._hover_z = z
	p._drag_start = cell
	p._down = true
	p._last_applied.clear()
	p._press()


func test_painter() -> void:
	var p := ForgeWorldPainter.new()
	tree.root.add_child(p)
	await tree.process_frame
	p.new_map("t_paint", "world", 12, 12)
	p.set_mode(ForgeWorldPainter.Mode.TILES)
	p.set_tool(ForgeWorldPainter.Tool.BRUSH)
	p.sel_tiles = ["terrain:concrete", "terrain:catwalk"]
	p.brush_size = 3
	p.set_layer(2)
	_press(p, Vector2i(5, 5), 2)
	check(p.world.tiles.size() == 9, "3×3 brush paints 9 columns (%d)" % p.world.tiles.size())
	check(p.world.stack_at(Vector2i(5, 5)).size() == 1 and p.world.top_z(Vector2i(5, 5)) == 2, "brush paints only the chosen layer")
	p.solid_column = true
	_press(p, Vector2i(9, 9), 3)
	check(p.world.stack_at(Vector2i(9, 9)).size() == 4, "solid column fills layers 0..3 on empty ground")
	p.set_layer(5)
	_press(p, Vector2i(5, 5), 5)
	var zs5: Array = p.world.stack_at(Vector2i(5, 5)).map(func(e: Array) -> int: return int(e[0]))
	check(zs5 == [2, 3, 4, 5], "solid column fills down to the tile below: %s" % [zs5])
	p.solid_column = false
	var ids := {}
	for c: Vector2i in p.world.tiles:
		for e: Array in p.world.tiles[c]:
			ids[e[1]] = true
	check(ids.size() == 2, "multi-select cycles tiles")
	# Rectangle: fills on release only.
	p.set_tool(ForgeWorldPainter.Tool.RECT)
	p.set_layer(-2)
	_press(p, Vector2i(0, 0), -2)
	p._hover_cell = Vector2i(3, 2)
	check(p.world.tile_at(Vector2i(3, 2), -2) == "", "rectangle not filled before release")
	p._release()
	check(p.world.tile_at(Vector2i(3, 2), -2) != "" and p.world.tile_at(Vector2i(0, 0), -2) != "", "rectangle fills 4×3 below ground")
	# Undo restores.
	p.undo_last()
	check(p.world.tile_at(Vector2i(3, 2), -2) == "", "undo rectangle")
	p.redo_last()
	check(p.world.tile_at(Vector2i(3, 2), -2) != "", "redo rectangle")
	# Fill a layer.
	p.set_tool(ForgeWorldPainter.Tool.FILL)
	p.sel_tiles = ["terrain:metal_grate"]
	p.set_layer(0)
	_press(p, Vector2i(11, 11), 0)
	check(p.world.tile_at(Vector2i(0, 11), 0) == "terrain:metal_grate" and p.world.tile_at(Vector2i(5, 5), 0) == "terrain:metal_grate", "flood fill empty layer")
	# Erase with the brush.
	p.set_tool(ForgeWorldPainter.Tool.ERASE)
	p.brush_size = 1
	_press(p, Vector2i(11, 11), 0)
	check(p.world.tile_at(Vector2i(11, 11), 0) == "", "erase")
	# Particles.
	p.set_mode(ForgeWorldPainter.Mode.PARTICLES)
	p.set_tool(ForgeWorldPainter.Tool.BRUSH)
	p.sel_particle = "fog"
	p.brush_size = 2
	p.set_layer(3)
	_press(p, Vector2i(4, 4), 3)
	check(p.world.particle_groups().has("fog|3") and (p.world.particle_groups()["fog|3"] as Array).size() == 4, "paint fog 2×2 at layer 3")
	# Objects + location.
	p.set_mode(ForgeWorldPainter.Mode.OBJECTS)
	var structs := ForgeStore.list_assets("structures")
	p.sel_object = structs[0] if not structs.is_empty() else "res://missing.png"
	p._hover_world = p.world.to_screen(Vector2(5, 5), 2)
	_press(p, Vector2i(5, 5), 2)
	check(p.world.objects.size() == 1 and str(p.world.objects[0]["kind"]) in ["structure", "prop"], "place object")
	check(p.selected == p.world.objects[0], "placed object is selected")
	p.duplicate_selected()
	check(p.world.objects.size() == 2, "duplicate object")
	p.delete_selected()
	check(p.world.objects.size() == 1, "delete object")
	# Gameplay: spawns.
	p.set_mode(ForgeWorldPainter.Mode.GAMEPLAY)
	p.play_tool = ForgeWorldPainter.Play.SPAWN
	p.set_tool(ForgeWorldPainter.Tool.BRUSH)
	_press(p, Vector2i(5, 6), 0)
	check((p.world.spawns["player"] as Array).size() == 1, "spawn placed")
	check(p._numbered_siblings("res://nothing/here_1.png").is_empty(), "no siblings → no frames")
	# Copy an area (all layers) and stamp it elsewhere, lifted to the stack layer.
	p.set_mode(ForgeWorldPainter.Mode.TILES)
	p.world.tiles.clear()
	p.world.set_tile(Vector2i(0, 0), 0, "terrain:concrete")
	p.world.set_tile(Vector2i(1, 0), 0, "terrain:concrete")
	p.world.set_tile(Vector2i(1, 0), 1, "terrain:crate")
	p.set_tool(ForgeWorldPainter.Tool.COPY)
	_press(p, Vector2i(0, 0), 0)
	p._hover_cell = Vector2i(1, 0)
	p._release()
	check(p.tool == ForgeWorldPainter.Tool.STAMP and (p.clipboard["tiles"] as Array).size() == 3, "copy area → stamp tool armed")
	p.set_layer(4)
	_press(p, Vector2i(6, 6), 4)
	check(p.world.tile_at(Vector2i(6, 6), 4) == "terrain:concrete" and p.world.tile_at(Vector2i(7, 6), 5) == "terrain:crate", "stamp lands lifted to layer 4")
	# Scatter: random pick + density.
	p.world.tiles.clear()
	p.set_tool(ForgeWorldPainter.Tool.RECT)
	p.sel_tiles = ["terrain:grass", "terrain:forest", "terrain:rock"]
	p.paint_random = true
	p.density = 40
	p.set_layer(0)
	_press(p, Vector2i(0, 0), 0)
	p._hover_cell = Vector2i(9, 9)
	p._release()
	var n := p.world.tiles.size()
	check(n > 15 and n < 70, "density 40%% paints a partial rectangle (%d / 100)" % n)
	var kinds := {}
	for c: Vector2i in p.world.tiles:
		kinds[p.world.top_tile(c)] = true
	check(kinds.size() == 3, "random pick uses every selected tile")
	p.paint_random = false
	p.density = 100
	# Neon lights + ambient survive a save round-trip and build PointLight2Ds.
	p.set_mode(ForgeWorldPainter.Mode.OBJECTS)
	p.set_tool(ForgeWorldPainter.Tool.BRUSH)
	p.sel_object = "light:neon_pink"
	p.world.set_tile(Vector2i(3, 3), 0, "terrain:concrete")
	_press(p, Vector2i(3, 3), 0)
	var lights := p.world.objects.filter(func(o: Dictionary) -> bool: return o.get("light") is Dictionary)
	check(lights.size() == 1 and str(lights[0]["light"]["preset"]) == "neon_pink", "place neon light")
	p.world.ambient = "#4a4f86"
	p._renderer.rebuild_lighting()
	check(p._renderer._lights_root.get_child_count() == 1 and p._renderer._ambient.color == Color("#4a4f86"), "renderer builds light + ambient")
	var rt := WorldMap.from_dict(JSON.parse_string(JSON.stringify(p.world.to_dict())))
	check(rt.ambient == "#4a4f86" and rt.objects.filter(func(o: Dictionary) -> bool: return o.get("light") is Dictionary).size() == 1, "lights + ambient round-trip")
	# Autosave writes only when dirty, and SAVE clears it.
	p.world.id = "t_autosave"
	p.dirty = true
	p._autosave()
	check(FileAccess.file_exists(p._autosave_path()), "autosave written")
	DirAccess.remove_absolute(p._autosave_path())
	# Juice: a fresh tile is mid-drop, then settles.
	p._renderer.pop(Vector2i(3, 3), 0)
	check(p._renderer.pop_progress(Vector2i(3, 3), 0) < 1.0 and p._renderer.is_popping(Vector2i(3, 3)), "tile pop animating")
	check(p._renderer.pop_progress(Vector2i(40, 40), 0) == 1.0, "untouched tile not popping")
	p.queue_free()
	await tree.process_frame


func test_explore() -> void:
	var w := _map()
	w.id = "t_explore"
	w.kind = "world"
	for x in 8:
		for y in 8:
			w.set_tile(Vector2i(x, y), 0, "terrain:concrete")
	w.set_tile(Vector2i(4, 1), 3, "terrain:concrete")  # cliff: too tall to climb
	var o := w.add_object("", Vector2i(6, 6), 0, "location")
	o["location"] = {"type": "city", "name": "Rust Harbor", "target_map": "", "radius": 1.5}
	w.spawns["player"] = [[1, 1]]
	ContentDB.maps[w.id] = w.to_dict()
	CampaignManager.current_explore = {"map_id": w.id, "spawn": 0}
	var ex := ExploreScene.new()
	tree.root.add_child(ex)
	await tree.process_frame
	check(ex.cell == Vector2i(1, 1), "explore starts on spawn")
	check(not ex.can_step(Vector2i(4, 0), Vector2i(4, 1)), "cliffs block")
	check(not ex.can_step(Vector2i(6, 5), Vector2i(6, 6)), "locations block their tile")
	var path := ex.walk_path(Vector2i(1, 1), Vector2i(5, 6))
	check(not path.is_empty() and path[path.size() - 1] == Vector2i(5, 6), "click-to-walk path")
	ex.cell = Vector2i(5, 6)
	check(ex._interactable() == ex.world.objects[0], "location in reach")
	check(not ex.is_known(ex.world.objects[0]), "undiscovered shows ?")
	ex._update_labels()
	check((ex._labels.values()[0] as Label).text == "?", "label is ? before first visit")
	GameManager.set_story_flag(ExploreScene.visited_flag(w.id, str(o["id"])))
	ex._update_labels()
	check((ex._labels.values()[0] as Label).text == "Rust Harbor", "label shows name after visit")
	GameManager.story_flags.erase(ExploreScene.visited_flag(w.id, str(o["id"])))
	ex.queue_free()
	ContentDB.maps.erase(w.id)
	await tree.process_frame
