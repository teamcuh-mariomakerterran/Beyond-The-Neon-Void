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
	test_validator()
	test_sync_blade()
	await test_strips_and_cutaway()
	await test_sculpt_ramps_mirror()
	await test_regions_and_links()
	await test_lattice_clip()
	test_location_graph()
	await test_cables()
	await test_status_looks()
	await test_signage()
	await test_cues()
	await test_passives()
	test_dev_console()
	await test_pixel_matrix()
	test_ui_icons()
	test_cover()
	test_masks_and_anchors()
	test_npc_stages()
	test_vault_demo()
	test_campaign_fixes()
	await test_streaming()
	test_pixellab()
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


func test_validator() -> void:
	var w := _map()
	w.kind = "encounter"
	for x in 8:
		for y in 8:
			w.set_tile(Vector2i(x, y), 0, "terrain:concrete")
	w.remove_tile(Vector2i(4, 4), 0)
	w.set_tile(Vector2i(7, 7), 9, "terrain:concrete")  # a pillar top nobody can climb
	for y in 8:
		w.remove_tile(Vector2i(6, y), 0)  # a chasm cuts the enemy off
	w.set_tile(Vector2i(0, 0), 1, "god_tiles/nope/missing")
	w.spawns["player"] = [[4, 4]]
	var o := w.add_object("res://assets/does_not_exist.png", Vector2i(1, 1), 0, "location")
	o["location"] = {"name": "Nowhere", "target_map": "no_such_map"}
	o["loot_item_id"] = "no_such_item"
	w.set_particle(Vector2i(2, 2), 3, "no_such_preset")
	var issues := MapValidator.validate(w, [{"character_id": "doctrine_warden", "cell": [7, 7], "level": 1}])
	var text := "\n".join(issues.map(func(i: Dictionary) -> String: return str(i["text"])))
	check(text.contains("spawn 4,4"), "validator: spawn on a hole")
	check(text.contains("missing map 'no_such_map'"), "validator: broken location link")
	check(text.contains("art file missing"), "validator: missing art")
	check(text.contains("no_such_item"), "validator: unknown loot")
	check(text.contains("no_such_preset"), "validator: unknown particle")
	check(text.contains("god_tiles/nope/missing"), "validator: unknown tile")
	w.spawns["player"] = [[0, 4]]
	var issues2 := MapValidator.validate(w, [{"character_id": "doctrine_warden", "cell": [7, 7], "level": 1}])
	check(issues2.any(func(i: Dictionary) -> bool: return str(i["text"]).contains("can't be reached")), "validator: unreachable enemy")
	check(issues2[0]["level"] == MapValidator.ERROR, "errors sort first")
	check(MapValidator.validate(WorldMap.from_dict(ContentDB.get_map("neon_expanse"))).filter(func(i: Dictionary) -> bool: return i["level"] == MapValidator.ERROR).is_empty(), "demo world has no errors")


func test_sync_blade() -> void:
	var two := ContentDB.get_ability("add_two_step")
	var cut := ContentDB.get_ability("add_final_cut")
	check(two != null and cut != null and Additions.beats(cut).size() == 8, "addition chains load")
	check(Additions.judge(two, 1, 0, 0.05) == 0 and Additions.judge(two, 1, 1, 0.45) == 1, "on-beat presses land")
	check(Additions.judge(two, 1, 1, 0.2) == -1, "early press misses")
	check(Additions.multiplier(cut, 8) > Additions.multiplier(cut, 7) + 1.0, "full chain fires the finisher")
	check(Additions.multiplier(two, 0) == 0.5 and Additions.auto_hits(cut) == 5, "glance + auto mode 70%%")
	var ch := CharacterData.new()
	for i in 30:
		Additions.record_use(ch, "add_two_step")
	check(Additions.mastery(ch, "add_two_step") == 3 and Additions.window(two, 3) > Additions.window(two, 1), "chain mastery widens the window")
	# The widget: perfect presses on every beat land the whole chain.
	var w := AdditionWidget.new()
	tree.root.add_child(w)
	w.ability = two
	w.level = 1
	w._beats = Additions.beats(two)
	w.press(0.01)
	w.press(0.46)
	check(w.hits == 2 and w._over, "widget: two perfect presses → full chain")
	w.queue_free()
	# Stardust unlocks the class.
	var cls := ContentDB.get_class_res("sync_blade")
	GameManager.story_flags.erase("found_stardust")
	var hero := CharacterData.new()
	check(cls != null and not ClassLibrary.is_unlocked_for("sync_blade", hero), "Sync Blade locked before Stardust")
	GameManager.give_item("key_stardust")
	check(ClassLibrary.is_unlocked_for("sync_blade", hero), "Stardust unlocks Sync Blade")
	GameManager.story_flags.erase("found_stardust")
	var exp := WorldMap.from_dict(ContentDB.get_map("neon_expanse"))
	check(exp.objects.any(func(o: Dictionary) -> bool: return str(o.get("loot_item_id", "")) == "key_stardust"), "Stardust is hidden in the world")


func test_strips_and_cutaway() -> void:
	var w := _map()
	w.width = 80
	w.depth = 80
	for x in 80:
		for y in 80:
			w.set_tile(Vector2i(x, y), 0, "terrain:concrete")
	var r := WorldRenderer.new()
	r.world = w
	tree.root.add_child(r)
	# 6400 columns → strips per diagonal within each 32×32 chunk (far fewer nodes).
	check(r._columns.size() < 520 and r._columns.size() >= 159, "strip renderer: %d nodes for 6400 columns" % r._columns.size())
	w.remove_tile(Vector2i(3, 4), 0)
	r.refresh_column(Vector2i(3, 4))
	var sv: WorldRenderer.StripView = r._columns[WorldRenderer.strip_key(Vector2i(3, 4))]
	check(not sv.cells.has(Vector2i(3, 4)) and sv.cells.has(Vector2i(4, 3)), "strip tracks its columns")
	# Cutaway: a tall column right in front of the focus fades; one behind doesn't.
	w.set_tile(Vector2i(11, 11), 6, "terrain:concrete")
	var focus := w.to_screen(Vector2(10, 10), 0)
	r.set_cutaway(focus, 20, 0)
	check(r.cutaway_alpha(w.to_screen(Vector2(11, 11), 6), 22, 6) < 1.0, "x-ray fades the column in front")
	check(r.cutaway_alpha(w.to_screen(Vector2(9, 9), 0), 18, 0) == 1.0, "x-ray leaves what's behind")
	r.set_cutaway(Vector2.INF, 0, 0)
	check(r.cutaway_alpha(w.to_screen(Vector2(11, 11), 6), 22, 6) == 1.0, "x-ray off")
	r.queue_free()
	await tree.process_frame


func test_sculpt_ramps_mirror() -> void:
	var p := ForgeWorldPainter.new()
	tree.root.add_child(p)
	await tree.process_frame
	p.new_map("t_sculpt", "encounter", 10, 10)
	for x in 10:
		for y in 10:
			p.world.set_tile(Vector2i(x, y), 0, "terrain:grass")
	p.set_mode(ForgeWorldPainter.Mode.TILES)
	p.set_tool(ForgeWorldPainter.Tool.SCULPT)
	p.brush_size = 1
	p.sculpt_mode = "raise"
	_press(p, Vector2i(5, 5), 0)
	check(p.world.top_z(Vector2i(5, 5)) == 1 and p.world.top_tile(Vector2i(5, 5)) == "terrain:grass", "sculpt raise copies the top tile up")
	p.sculpt_mode = "flatten"
	p.set_layer(3)
	_press(p, Vector2i(2, 2), 3)
	check(p.world.top_z(Vector2i(2, 2)) == 3 and p.world.stack_at(Vector2i(2, 2)).size() == 4, "flatten fills up to the layer")
	p.set_layer(0)
	_press(p, Vector2i(2, 2), 0)
	check(p.world.top_z(Vector2i(2, 2)) == 0, "flatten cuts down to the layer")
	p.sculpt_mode = "lower"
	_press(p, Vector2i(5, 5), 0)
	check(p.world.top_z(Vector2i(5, 5)) == 0, "sculpt lower")
	p.world.set_tile(Vector2i(7, 7), 4, "terrain:rock")
	p.sculpt_mode = "smooth"
	_press(p, Vector2i(7, 7), 0)
	check(p.world.top_z(Vector2i(7, 7)) == 1, "smooth pulls a spike toward its neighbours (got %d)" % p.world.top_z(Vector2i(7, 7)))
	# Ramp points uphill at the neighbour one step higher.
	p.world.set_tile(Vector2i(4, 3), 1, "terrain:grass")
	p.set_tool(ForgeWorldPainter.Tool.RAMP)
	p.sel_tiles = ["terrain:grass"]
	_press(p, Vector2i(3, 3), 0)
	check(str(p.world.tile_opts(Vector2i(3, 3), 0).get("ramp", "")) == "x+", "ramp auto-faces uphill (x+)")
	var rt := WorldMap.from_dict(JSON.parse_string(JSON.stringify(p.world.to_dict())))
	check(str(rt.tile_opts(Vector2i(3, 3), 0).get("ramp", "")) == "x+", "ramp survives save/load")
	# Mirror X paints both sides.
	p.mirror_x = true
	p.set_tool(ForgeWorldPainter.Tool.BRUSH)
	p.sel_tiles = ["terrain:sand"]
	_press(p, Vector2i(1, 8), 0)
	check(p.world.tile_at(Vector2i(8, 8), 0) == "terrain:sand" and p.world.tile_at(Vector2i(1, 8), 0) == "terrain:sand", "mirror X")
	p.mirror_x = false
	# Variation stamps flip / tint options.
	p.vary_tiles = true
	_press(p, Vector2i(0, 0), 0)
	check(p.world.tile_opts(Vector2i(0, 0), 0).has("tint"), "variation adds a tint")
	p.vary_tiles = false
	# Recent tiles + number keys.
	p._remember_tile("terrain:rock")
	p._remember_tile("terrain:sand")
	p.pick_recent(1)
	check(p.sel_tiles == ["terrain:rock"], "recent tile 2 = rock")
	p.queue_free()
	await tree.process_frame


func test_regions_and_links() -> void:
	# Regions: paint + triggers fire on enter, once.
	var w := _map()
	w.id = "t_regions"
	w.kind = "hub"
	for x in 8:
		for y in 8:
			w.set_tile(Vector2i(x, y), 0, "terrain:concrete")
	var r := w.add_region("Alley Mouth")
	r["cells"] = ["3,3", "3,4"]
	r["triggers"] = [{"on": "enter", "do": "flag", "arg": "t_seen_alley", "once": true}, {"on": "exit", "do": "flag", "arg": "t_left_alley"}]
	check(w.regions_at(Vector2i(3, 4)).size() == 1 and w.regions_at(Vector2i(5, 5)).is_empty(), "regions_at")
	var rt := WorldMap.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	check(rt.regions.size() == 1 and (rt.regions[0]["triggers"] as Array).size() == 2, "regions round-trip")
	w.spawns["player"] = [[2, 3]]
	ContentDB.maps[w.id] = w.to_dict()
	CampaignManager.current_explore = {"map_id": w.id, "spawn": 0}
	for f in ["t_seen_alley", "t_left_alley"]:
		GameManager.story_flags.erase(f)
	var ex := ExploreScene.new()
	tree.root.add_child(ex)
	await tree.process_frame
	ex.cell = Vector2i(3, 3)
	await ex._update_regions()
	check(GameManager.check_story_flag("t_seen_alley"), "enter trigger fired")
	ex.cell = Vector2i(5, 5)
	await ex._update_regions()
	check(GameManager.check_story_flag("t_left_alley"), "exit trigger fired")
	var reg: Dictionary = ex.world.regions[0]
	check(GameManager.check_story_flag(ExploreScene.trigger_flag(w.id, reg, 0)), "once-trigger remembered")
	reg["encounter"] = {"rate": 1.0, "missions": ["m01_the_brew_plan"]}
	ex.cell = Vector2i(3, 3)
	check(ex.roll_encounter() == "m01_the_brew_plan", "encounter roll at 100%")
	ex.queue_free()
	ContentDB.maps.erase(w.id)
	for f in ["t_seen_alley", "t_left_alley", ExploreScene.trigger_flag(w.id, reg, 0)]:
		GameManager.story_flags.erase(f)
	# Painter: paint a region with the brush.
	var p := ForgeWorldPainter.new()
	tree.root.add_child(p)
	await tree.process_frame
	p.new_map("t_rgn_paint", "hub", 8, 8)
	p.set_mode(ForgeWorldPainter.Mode.REGIONS)
	p.sel_region = p.world.add_region("Market")
	p.set_tool(ForgeWorldPainter.Tool.BRUSH)
	p.brush_size = 2
	_press(p, Vector2i(4, 4), 0)
	check((p.sel_region["cells"] as Array).size() == 4, "brush paints region cells")
	p.queue_free()
	await tree.process_frame
	# Asset links: rename rewrites references; repair finds moved files.
	DirAccess.make_dir_recursive_absolute("res://assets/_t_refs/a")
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.save_png("res://assets/_t_refs/a/thing_one.png")
	var jf := FileAccess.open("res://data/_t_refs.json", FileAccess.WRITE)
	jf.store_string('{"x": "res://assets/_t_refs/a/thing_one.png"}')
	jf.close()
	var n := AssetRefs.rename("res://assets/_t_refs/a/thing_one.png", "res://assets/_t_refs/b/thing_one.png", false)
	check(n == 1 and FileAccess.get_file_as_string("res://data/_t_refs.json").contains("_t_refs/b/thing_one.png"), "rename rewrites links")
	# Simulate an outside move: file moved, link left behind → repair finds it.
	DirAccess.make_dir_recursive_absolute("res://assets/_t_refs/c")
	DirAccess.rename_absolute("res://assets/_t_refs/b/thing_one.png", "res://assets/_t_refs/c/thing_one.png")
	check(AssetRefs.broken().any(func(b: Dictionary) -> bool: return str(b["path"]).contains("_t_refs/b/thing_one")), "broken link detected")
	var fix := AssetRefs.repair_all(false)
	check(int(fix["fixed"]) >= 1 and FileAccess.get_file_as_string("res://data/_t_refs.json").contains("_t_refs/c/thing_one.png"), "repair re-links moved file")
	DirAccess.remove_absolute("res://data/_t_refs.json")
	DirAccess.remove_absolute("res://assets/_t_refs/c/thing_one.png")
	for d in ["c", "b", "a"]:
		DirAccess.remove_absolute("res://assets/_t_refs/" + d)
	DirAccess.remove_absolute("res://assets/_t_refs")
	AssetRefs.reindex()


func test_lattice_clip() -> void:
	# Fixture: 4 frames of 32×24 in a horizontal strip, with holds + order.
	var dir := "user://t_clip"
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(128, 24, false, Image.FORMAT_RGBA8)
	for i in 4:
		img.fill_rect(Rect2i(i * 32 + 4, 2, 24, 22), Color(0.2 * i, 1.0, 1.0))
	img.save_png(dir + "/bl_t_strip.png")
	var clip_dict := {"format": "lattice.clip", "version": 1, "name": "bl_t", "loop": true, "cell": [32, 24], "frames": 4,
		"layout": "horizontal", "rects": [], "fps": 10, "frameMs": 100, "holds": [1, 3, 1, 1], "tickSequence": [0, 1, 2, 3],
		"anchor": [16, 23], "buildingBBox": [4, 2, 28, 24], "textures": {"strip": "bl_t_strip.png"},
		"sourceArt": {"footprint": {"w": 2, "h": 2}}, "phaseSeed": 0,
		"emitters": {"beacons": [[10.0, 5.0]], "windows": [[20.0, 10.0], [22.0, 12.0]]}, "overlayClip": null}
	var f := FileAccess.open(dir + "/bl_t.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(clip_dict))
	f.close()
	var path := dir + "/bl_t.json"
	check(LatticeClip.is_clip(path) and LatticeClip.find_for_png(dir + "/bl_t_strip.png") == path, "clip detected next to its strip")
	var c := LatticeClip.load_clip(path)
	check(c["ok"] and (c["rects"] as Array).size() == 4 and is_equal_approx(float(c["total"]), 600.0), "clip loads: 4 frames, holds → 600 ms")
	check(LatticeClip.frame_at(c, 0.05) == 0 and LatticeClip.frame_at(c, 0.15) == 1 and LatticeClip.frame_at(c, 0.35) == 1 and LatticeClip.frame_at(c, 0.45) == 2, "holds stretch frame 1 to 300 ms")
	check(LatticeClip.frame_at(c, 0.65) == 0, "clip loops")
	check(int(c["footprint"]) == 2 and WorldMap.footprint({"asset": path, "kind": "prop"}) == 2, "clip footprint becomes the object footprint")
	check(LatticeClip.light_points(c, 5).size() == 3, "light points from beacons + windows")
	var w := _map()
	w.set_tile(Vector2i(3, 3), 0, "terrain:concrete")
	var o := w.add_object(path, Vector2i(3, 3), 0, "structure")
	var r := WorldRenderer.new()
	r.world = w
	tree.root.add_child(r)
	await tree.process_frame
	var node := r.object_node(str(o["id"]))
	check(node != null and node._clip.get("ok", false), "renderer plays the clip")
	check(r._lights_root.get_child_count() == 3, "clip lights hung on beacons/windows (%d)" % r._lights_root.get_child_count())
	r.queue_free()
	await tree.process_frame
	for fn in ["bl_t.json", "bl_t_strip.png"]:
		DirAccess.remove_absolute(dir + "/" + fn)
	DirAccess.remove_absolute(dir)
	await test_lattice_real_export()
	await test_lattice_units()


## The animator's real bl_036_04 JSONs (tests/fixtures/lattice) with stand-in
## strips: opaque near-black main strip + transparent overlay strip.
func test_lattice_real_export() -> void:
	var dir := "user://t_clip_real"
	DirAccess.make_dir_recursive_absolute(dir)
	for fn in ["bl_036_04_clip.json", "bl_036_04_overlay_clip.json"]:
		DirAccess.copy_absolute("res://tests/fixtures/lattice/" + fn, dir + "/" + fn)
	var bg := Color8(10, 10, 15)
	var main := Image.create(412 * 24, 341, false, Image.FORMAT_RGBA8)
	main.fill(bg)
	var ov := Image.create(412 * 24, 341, false, Image.FORMAT_RGBA8)
	for i in 24:
		main.fill_rect(Rect2i(i * 412 + 60, 100, 290, 220), Color8(60, 30, 80))
		main.fill_rect(Rect2i(i * 412 + 180, 180, 40, 40), bg)  # dark courtyard, enclosed
		ov.fill_rect(Rect2i(i * 412 + 200 + i, 120, 4, 4), Color(1, 0.3, 0.8))
	main.save_png(dir + "/bl_036_04_strip.png")
	ov.save_png(dir + "/bl_036_04_overlay_strip.png")
	var path := dir + "/bl_036_04_clip.json"
	check(LatticeClip.find_for_png(dir + "/bl_036_04_strip.png") == path, "strip finds its _clip.json")
	check(LatticeClip.find_for_png(dir + "/bl_036_04_overlay_strip.png") == dir + "/bl_036_04_overlay_clip.json", "overlay strip finds its _overlay_clip.json")
	var c := LatticeClip.load_clip(path)
	check(c["ok"] and (c["rects"] as Array).size() == 24 and str(c["overlay"]).ends_with("bl_036_04_overlay_clip.json"), "real export loads with its overlay")
	var img: Image = (c["tex"] as Texture2D).get_image()
	check(img.get_pixel(2, 2).a == 0.0 and img.get_pixel(412 * 23 + 5, 330).a == 0.0, "opaque near-black backdrop keyed out on every frame")
	check(img.get_pixel(100, 150).a == 1.0 and img.get_pixel(412 * 5 + 195, 195).a == 1.0, "building and its enclosed dark courtyard kept")
	var o := LatticeClip.load_clip(dir + "/bl_036_04_overlay_clip.json")
	check(o["ok"] and (o["tex"] as Texture2D).get_image().get_pixel(201, 121).a == 1.0, "transparent overlay left untouched")
	check(DirAccess.get_files_at(LatticeClip.KEY_DIR).size() > 0, "keyed strip cached")
	for fn in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + fn)
	DirAccess.remove_absolute(dir)


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
	# Terrain generator: bands by height, deterministic per seed, region-limited.
	p.sel_tiles = ["terrain:water", "terrain:grass", "terrain:rock"]
	var gn := p.generate_terrain(Rect2i(0, 0, 12, 12), 6, 0.08, 0.3, 42)
	var top_ids := {}
	var max_h := 0
	for c: Vector2i in p.world.tiles:
		top_ids[p.world.top_tile(c)] = true
		max_h = maxi(max_h, p.world.top_z(c))
	check(gn == 144 and top_ids.size() >= 2 and max_h > 0 and max_h <= 6, "generator: %d cols, tops %s, max h %d" % [gn, top_ids.keys(), max_h])
	var snap: Dictionary = (p.world.to_dict()["tiles"] as Dictionary).duplicate(true)
	p.generate_terrain(Rect2i(0, 0, 12, 12), 6, 0.08, 0.3, 42)
	check(p.world.to_dict()["tiles"] == snap, "generator deterministic for a seed")
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
	# Rotate a quarter turn: the 2×1 strip becomes 1×2.
	p.transform_clipboard(true)
	var spots := {}
	for t: Array in p.clipboard["tiles"]:
		spots[Vector2i(int(t[0]), int(t[1]))] = true
	check(spots.has(Vector2i(0, 0)) and spots.has(Vector2i(0, 1)) and spots.size() == 2, "rotate stamp: %s" % [spots.keys()])
	# Save + reload through data/stamps.
	var sp := p.save_stamp("test stamp zz")
	check(FileAccess.file_exists(sp) and ForgeWorldPainter.list_stamps().has(sp), "stamp saved + listed")
	p.clipboard = {}
	p.load_stamp(sp)
	check((p.clipboard["tiles"] as Array).size() == 3 and p.tool == ForgeWorldPainter.Tool.STAMP, "stamp reloaded")
	DirAccess.remove_absolute(sp)
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


func _write_clip(path: String, d: Dictionary, w: int, h: int, frames: int, rows: int = 1) -> void:
	var img := Image.create(w * frames, h * rows, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(2, 2, w - 4, h - 4), Color(0.5, 0.8, 1.0))
	img.save_png(path.get_base_dir().path_join(str(d["textures"]["strip"])))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


## Lattice CLIP_FORMAT_GUIDE rules + unit packs (gold_vehicles naming).
func test_lattice_units() -> void:
	var root := "user://t_units"
	var gv := root + "/gold_vehicles/tanks"
	var gvd := root + "/gold_vehicles_damage/tanks"
	DirAccess.make_dir_recursive_absolute(gv)
	DirAccess.make_dir_recursive_absolute(gvd)
	var base := {"format": "lattice.clip", "version": 1, "layout": "horizontal", "fps": 10, "frameMs": 100, "holds": null}
	var mk := func(dir: String, name: String, extra: Dictionary, w: int, h: int, n: int) -> void:
		var d := base.duplicate(true)
		d.merge(extra, true)
		d["name"] = name
		d["cell"] = [w, h]
		d["frames"] = n
		d["textures"] = {"strip": name + "_strip.png"}
		_write_clip(dir + "/" + name + "_clip.json", d, w, h, n)
	mk.call(gv, "gv_g04_SE_idle", {"kind": "idle", "facing": "SE", "loop": true, "anchor": [46, 60]}, 136, 63, 4)
	mk.call(gv, "gv_g04_NW_idle", {"kind": "idle", "facing": "NW", "loop": true, "anchor": [30, 50]}, 73, 84, 4)
	mk.call(gv, "gv_g04_SE_fire", {"kind": "attack", "facing": "SE", "loop": false, "holds": [1, 1, 2, 3], "anchor": [46, 60]}, 136, 63, 4)
	mk.call(gv, "gv_g04_SE_fire_overlay", {"kind": "attack_overlay", "facing": "SE", "overlayOf": "gv_g04_SE_fire"}, 136, 63, 4)
	mk.call(gvd, "gvd_g04_SE_death", {"kind": "death", "facing": "SE", "loop": false, "endsOn": "gvd_g04_SE_wreck", "anchor": [60, 70]}, 160, 80, 3)
	mk.call(gvd, "gvd_g04_SE_wreck", {"kind": "wreck", "facing": "SE", "loop": true, "anchor": [60, 70]}, 160, 80, 2)
	mk.call(gvd, "gvd_g04_SE_dmg_light", {"kind": "damage_overlay", "facing": "SE", "overlay": true, "loop": true}, 160, 80, 2)
	# Guide rules.
	var fire := LatticeClip.load_clip(gv + "/gv_g04_SE_fire_clip.json")
	check(is_equal_approx(float(fire["total"]), 700.0) and not fire["loop"] and fire["kind"] == "aim_fire", "holds are ticks (1+1+2+3 × 100 ms), attack ≡ aim_fire, one-shot")
	var noloop := base.duplicate(true)
	noloop.merge({"name": "x", "cell": [8, 8], "frames": 2, "textures": {"strip": "x_strip.png"}, "pivot": {"x": 3, "y": 7}})
	_write_clip(root + "/x_clip.json", noloop, 8, 8, 2)
	var xc := LatticeClip.load_clip(root + "/x_clip.json")
	check(xc["ok"] and not xc["loop"] and xc["anchor"] == Vector2(3, 7), "missing loop = false; {x,y} pivot is the anchor")
	check(LatticeClip.is_overlay(gvd + "/gvd_g04_SE_dmg_light_clip.json") and LatticeClip.is_overlay(gv + "/gv_g04_SE_fire_overlay_clip.json") and not LatticeClip.is_overlay(gv + "/gv_g04_SE_idle_clip.json"), "overlay / damage_overlay clips recognised")
	check(LatticeClip.point({"x": 4, "y": 5}) == Vector2(4, 5) and LatticeClip.point({"frame": 1, "x": 4, "y": 5}) == Vector2(4, 5) and LatticeClip.point([1, 2]) == Vector2(1, 2), "emitter points in every shape")
	# dirs-rows: rows = N..NW, pick one facing.
	var rows := base.duplicate(true)
	var rr: Array = []
	for di in 8:
		for fi in 3:
			rr.append({"i": di * 3 + fi, "dir": LatticeClip.FACINGS[di], "frame": fi, "x": fi * 16, "y": di * 20, "w": 16, "h": 20})
	rows.merge({"name": "walk84", "kind": "walk", "loop": true, "layout": "dirs-rows", "dirOrder": LatticeClip.FACINGS, "cell": [16, 20], "frames": 3, "rects": rr, "textures": {"strip": "walk84_strip.png"}}, true)
	_write_clip(root + "/walk84_clip.json", rows, 16, 20, 3, 8)
	var sw := LatticeClip.load_clip(root + "/walk84_clip.json", "SW")
	check(sw["ok"] and (sw["rects"] as Array).size() == 3 and (sw["rects"][0] as Rect2).position.y == 100.0, "dirs-rows: SW is row 5")
	var rs := LatticeClip.unit_set(root + "/walk84_clip.json")
	check(rs["ok"] and (rs["frames"] as SpriteFrames).has_animation("walk_NE") and (rs["frames"] as SpriteFrames).get_animation_names().size() == 8, "dirs-rows sheet → 8 walk facings")
	# Unit set across gold_vehicles + gold_vehicles_damage.
	var us := LatticeClip.unit_set(gv + "/gv_g04_SE_idle_clip.json")
	var sf: SpriteFrames = us["frames"]
	check(us["ok"] and sf.has_animation("idle_SE") and sf.has_animation("idle_NW") and sf.has_animation("attack_SE") and sf.has_animation("death_SE") and sf.has_animation("wreck_SE"), "unit pack: idle/attack/death/wreck gathered (%s)" % str(sf.get_animation_names()))
	check(sf.get_animation_names().size() == 5, "overlays and damage stages left out")
	check(is_equal_approx(sf.get_frame_duration("attack_SE", 3), 3.0) and is_equal_approx(sf.get_animation_speed("attack_SE"), 10.0), "holds carried into SpriteFrames")
	check(str(us["next"].get("death_SE", "")) == "wreck_SE", "death chains to wreck (endsOn)")
	check(LatticeClip.facing_of(Vector2i(1, 0)) == "SE" and LatticeClip.facing_of(Vector2i(0, -1)) == "NE", "grid facing → screen diagonal")
	check(LatticeClip.resolve(us, "idle", "NE") == ["idle_NW", true], "missing NE idle mirrors NW")
	check(LatticeClip.resolve(us, "attack", "SW") == ["attack_SE", true] and LatticeClip.resolve(us, "cast", "SE")[0] == "attack_SE", "attack mirrors; cast falls back to attack")
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	LatticeClip.play_on(spr, us, "idle", "SW")
	check(spr.flip_h and spr.offset == -Vector2(136 - 46, 60), "mirrored anchor offset")
	spr.free()
	# A unit wearing the pack.
	var cd := CharacterData.new()
	cd.sprite_frames_path = gv + "/gv_g04_SE_idle_clip.json"
	var u := Unit.new()
	u.data = cd
	tree.root.add_child(u)
	await tree.process_frame
	check(u.sprite != null and str(u.sprite.animation) == "idle_SE", "unit plays its Lattice idle (%s)" % (str(u.sprite.animation) if u.sprite else "no sprite"))
	u.facing = Vector2i(-1, 0)
	check(str(u.sprite.animation) == "idle_NW" and not u.sprite.flip_h, "turning swaps facing clip")
	u.play_animation("attack")
	check(str(u.sprite.animation) == "attack_SE" and not u.sprite.flip_h, "NW attack (no NW/NE clip) falls back to SE")
	u.queue_free()
	await tree.process_frame
	for d in [gv, gvd, root + "/gold_vehicles", root + "/gold_vehicles_damage", root]:
		for fn in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d + "/" + fn)
	for d in [gv, gvd, root + "/gold_vehicles", root + "/gold_vehicles_damage", root]:
		DirAccess.remove_absolute(d)


func test_location_graph() -> void:
	var world_d := {"id": "g_world", "format": 2, "kind": "world", "objects": [
		{"id": "o1", "cell": [1, 1], "location": {"name": "Kowloon", "target_map": "g_hub"}},
		{"id": "o2", "cell": [2, 2], "location": {"name": "Lost", "target_map": "g_nowhere"}}]}
	var hub_d := {"id": "g_hub", "format": 2, "kind": "hub", "objects": [], "regions": [
		{"name": "Back door", "cells": ["1,1"], "triggers": [{"on": "enter", "do": "teleport", "arg": "g_bar:3,4"}]}]}
	var bar_d := {"id": "g_bar", "format": 2, "kind": "interior"}
	check(LocationGraph.links_of("g_hub", hub_d) == [{"from": "g_hub", "to": "g_bar", "label": "Back door", "how": "teleport"}], "teleport triggers are links")
	var g := LocationGraph.new()
	g.build({"g_world": world_d, "g_bar": bar_d}, hub_d)
	check(g.nodes.size() == 4 and g.nodes["g_nowhere"]["missing"], "live map included; broken link gets a ghost node")
	check(g.edges.size() == 3 and g.incoming("g_bar") == 1, "doors + teleports drawn as edges")
	var r_world: Rect2 = g.nodes["g_world"]["rect"]
	var r_hub: Rect2 = g.nodes["g_hub"]["rect"]
	var r_bar: Rect2 = g.nodes["g_bar"]["rect"]
	check(r_world.position.x < r_hub.position.x and r_hub.position.x < r_bar.position.x, "columns: world → hub → interior")
	check(g.node_at(r_hub.get_center()) == "g_hub", "click finds the node")
	var picked := {"id": ""}
	g.map_chosen.connect(func(id: String) -> void: picked["id"] = id)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = g.nodes["g_nowhere"]["rect"].get_center()
	g._gui_input(ev)
	ev.position = r_bar.get_center()
	g._gui_input(ev)
	check(picked["id"] == "g_bar", "clicking a missing map does nothing, a real one opens it")
	# Real demo data: the world map's door reaches the hub.
	var real := LocationGraph.new()
	real.build(ContentDB.maps)
	var found := false
	for e: Dictionary in real.edges:
		if e["from"] == "neon_expanse" and e["to"] == "neo_kowloon_hub":
			found = true
	check(found, "neon_expanse → neo_kowloon_hub link found in the demo maps")
	g.free()
	real.free()


func test_cables() -> void:
	# Network maths: 4 buildings in a row, 2 anchors each, 100 px apart.
	var pts: Array = []
	for b in 4:
		for k in 2:
			pts.append({"pos": Vector2(b * 100.0, k * 30.0), "owner": "b%d" % b})
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var mst := CableNet.link_anchors(pts, 150.0, 0.0, rng)
	check(mst.size() == 7, "MST joins all 8 anchors with 7 spans (%d)" % mst.size())
	var same := false
	var too_long := false
	for e: Array in mst:
		same = same or pts[e[0]]["owner"] == pts[e[1]]["owner"]
		too_long = too_long or (pts[e[0]]["pos"] as Vector2).distance_to(pts[e[1]]["pos"]) > 150.0
	check(not same and not too_long, "spans only between different buildings, never longer than max")
	rng.seed = 1
	var dense := CableNet.link_anchors(pts, 150.0, 0.5, rng)
	check(dense.size() > mst.size() and dense.size() <= mst.size() + 4, "extra spans add density (%d)" % dense.size())
	var far: Array = [{"pos": Vector2.ZERO, "owner": "a"}, {"pos": Vector2(1000, 0), "owner": "b"}]
	check(CableNet.link_anchors(far, 150.0, 1.0, rng).is_empty(), "no span across a too-wide gap")
	check(CableNet.curve(Vector2.ZERO, Vector2(100, 0), 18.0, 2.0, 1.0, 0.0) == Vector2.ZERO and CableNet.curve(Vector2.ZERO, Vector2(100, 0), 18.0, 2.0, 1.0, 1.0).is_equal_approx(Vector2(100, 0)), "sag and sway are zero at the anchors")
	check(CableNet.curve(Vector2.ZERO, Vector2(100, 0), 18.0, 0.0, 0.0, 0.5).y == 18.0, "sag peaks mid-span")
	# Renderer: tall structures get roofline anchors and are strung together.
	var dir := "user://t_cables"
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(100, 300, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 60, 100, 240), Color(0.3, 0.2, 0.5))  # roof at y = 60
	img.save_png(dir + "/tower.png")
	var w := _map()
	w.kind = "hub"
	for x in 12:
		for y in 12:
			w.set_tile(Vector2i(x, y), 0, "terrain:concrete")
	for c: Vector2i in [Vector2i(2, 2), Vector2i(4, 2), Vector2i(2, 4)]:
		var o := w.add_object(dir + "/tower.png", c, 0, "structure")
		o["scale"] = w.tile_width * 0.8 / 100.0
	var small := w.add_object(dir + "/tower.png", Vector2i(8, 8), 0, "prop")
	small["scale"] = 0.2
	var r := WorldRenderer.new()
	r.world = w
	tree.root.add_child(r)
	for i in 4:
		await tree.process_frame
	check(r.cables.anchors.size() == 6, "2 roof anchors per tall structure, none on props (%d)" % r.cables.anchors.size())
	check(r.cables.spans.size() >= 2, "buildings strung together (%d spans)" % r.cables.spans.size())
	var uvs: Array = CableNet.auto_uvs(r.object_node(str(w.objects[0]["id"])), false)
	check(absf(float(uvs[0][1]) - 0.015) < 0.02, "auto anchor sits on the roofline (%s)" % str(uvs))
	w.objects[1]["cables"] = "none"
	r.refresh_object(w.objects[1])
	for i in 4:
		await tree.process_frame
	check(r.cables.anchors.size() == 4, "\"none\" removes a building from the web")
	w.cables["enabled"] = false
	r.cables.mark_dirty()
	for i in 4:
		await tree.process_frame
	check(r.cables.spans.is_empty(), "map setting turns the web off")
	check(WorldMap.from_dict(w.to_dict()).cables.get("enabled") == false, "cable settings saved with the map")
	r.queue_free()
	await tree.process_frame
	DirAccess.remove_absolute(dir + "/tower.png")
	DirAccess.remove_absolute(dir)


func test_status_looks() -> void:
	var c := StatusLook.combine(["poisoned", "petrified"])
	check(c["grey"] == 1.0 and c["crack"] == 1.0 and c["freeze"], "petrify: grey, cracked, frozen")
	check(c["tint"] == Color("#7dff4a"), "tint from the only tinted status")
	var c2 := StatusLook.combine(["poisoned", "burning"])
	check(c2["tint"] == Color("#ff7a2a") and c2["pulse_speed"] == 1.2 and c2["heat"] == 0.8, "stacked: highest-priority tint, strongest numbers")
	check(StatusLook.combine([])["grey"] == 0.0, "no statuses, no look")
	for id: String in StatusLook.looks():
		check(ContentDB.get_status(id) != null, "status look '%s' matches a real status" % id)
	# On a unit: material appears with the status, sprite inherits it.
	var cd: CharacterData = ContentDB.get_all("characters")[0]
	var u := Unit.new()
	u.setup(cd, Unit.Team.PLAYER, 1)
	tree.root.add_child(u)
	await tree.process_frame
	check(u.material == null, "healthy unit: no status shader")
	u.apply_status("banished")
	var mat := u.material as ShaderMaterial
	check(mat != null and mat.shader == StatusLook.SHADER, "status shader attached")
	await tree.create_timer(1.0).timeout
	check(float(mat.get_shader_parameter("sink_px")) > 40.0, "banish sinks the unit into the floor (%s px)" % str(mat.get_shader_parameter("sink_px")))
	check(u.has_status_tag("untouchable") and DamageCalculator.hit_chance(u, u, ContentDB.get_all("abilities")[0], null) == 0.0, "banished: can't be hit")
	u.remove_status("banished")
	await tree.create_timer(1.0).timeout
	check(float(mat.get_shader_parameter("sink_px")) < 1.0, "returns from banishment")
	u.apply_status("petrified")
	check(u.has_status_tag("stone") and u.is_disabled(), "petrified: stone and can't act")
	u.queue_free()
	await tree.process_frame


func test_signage() -> void:
	check(Signage.fill("SOUL COINS {soul_coins}") == "SOUL COINS %d" % GameManager.soul_coins, "stats lines fill live numbers")
	check(not Signage.items("propaganda").is_empty() and not Signage.items("ads").is_empty(), "propaganda + ads have content")
	EventBus.broadcast_line.emit("news", "T-HEADLINE: test unit wins")
	check(str(Signage.items("news")[0]["text"]) == "T-HEADLINE: test unit wins", "live headlines lead the news feed")
	check(str(Signage.items("custom", "OPEN 24H")[0]["text"]) == "OPEN 24H", "custom text")
	var w := _map()
	for x in 6:
		for y in 6:
			w.set_tile(Vector2i(x, y), 0, "terrain:concrete")
	var dir := "user://t_sign"
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.3))
	img.save_png(dir + "/b.png")
	var o := w.add_object(dir + "/b.png", Vector2i(2, 2), 0, "structure")
	o["screen"] = {"corners": [[0.2, 0.2], [0.8, 0.25], [0.8, 0.5], [0.2, 0.45]], "feed": "news", "mode": "crt"}
	var o2 := w.add_object(dir + "/b.png", Vector2i(4, 2), 0, "structure")
	o2["screen"] = {"feed": "news"}
	var r := WorldRenderer.new()
	r.world = w
	tree.root.add_child(r)
	for i in 3:
		await tree.process_frame
	var n1 := r.object_node(str(o["id"]))
	var n2 := r.object_node(str(o2["id"]))
	check(n1._screen != null and n1._screen.points.size() == 4 and n1._screen.tex != null, "screen quad placed on the sprite")
	check(n1._screen.points[0].is_equal_approx(n1._rect.position + Vector2(0.2, 0.2) * n1._rect.size), "corners follow the sprite box")
	check(n1._screen.tex == n2._screen.tex, "same feed shares one render")
	check(n1._screen_light != null and n1._screen_light.color == Signage.FEED_COLORS["news"], "screen glows in its feed colour")
	o.erase("screen")
	r.refresh_object(o)
	await tree.process_frame
	check(n1._screen == null, "removing the screen removes the quad")
	r.queue_free()
	await tree.process_frame
	DirAccess.remove_absolute(dir + "/b.png")
	DirAccess.remove_absolute(dir)


func test_cues() -> void:
	check(Cues.resolve("hit.crit.fire") == "hit.crit" and Cues.resolve("hit.weird") == "hit" and Cues.resolve("nothing.here") == "", "cue names fall back to their parent")
	var got := {"id": "", "key": ""}
	var probe := func(id: String, key: String, _c: Dictionary) -> void:
		got["id"] = id
		got["key"] = key
	Cues.fired.connect(probe)
	Cues.fire("status.petrified", {})
	check(got["key"] == "status.petrified" and Cues.history[-1] == "status.petrified", "fire runs the defined cue and logs it")
	# Override stack: the slowest time scale wins; base comes back after.
	var base := Engine.time_scale
	Cues.push("time_scale", 0.5, 0.3)
	Cues.push("time_scale", 0.05, 0.06)
	check(is_equal_approx(Cues.effective("time_scale", 1.0), 0.05), "hit-stop beats slow-mo while both run")
	await tree.create_timer(0.12, true, false, true).timeout
	check(is_equal_approx(Cues.effective("time_scale", 1.0), 0.5), "hit-stop ends, slow-mo still holds")
	await tree.create_timer(0.35, true, false, true).timeout
	await tree.process_frame
	check(is_equal_approx(Engine.time_scale, base), "time scale restored when the stack empties")
	Cues.push("zoom", 1.2, 0.4, "punch")
	await tree.create_timer(0.08, true, false, true).timeout
	check(Cues.effective("zoom", 1.0) > 1.05, "zoom punch snaps in")
	# Gameplay events become cues.
	var cd: CharacterData = ContentDB.get_all("characters")[0]
	var u := Unit.new()
	u.setup(cd, Unit.Team.ENEMY, 1)
	tree.root.add_child(u)
	u.take_damage(1)
	check(str(got["id"]).begins_with("hit"), "damage fires a hit cue (%s)" % got["id"])
	u.apply_status("banished")
	check(got["id"] == "status.banished", "status cue")
	Cues.fired.disconnect(probe)
	u.queue_free()
	await tree.process_frame
	var boss_cd := CharacterData.new()
	boss_cd.apply_dict({"id": "t_boss", "is_boss": true, "boss_title": "Test Title"})
	check(boss_cd.is_boss and boss_cd.boss_title == "Test Title", "boss flag loads from data")


func _pu(g: IsometricGrid, team: int, cell: Vector2i, slots: Dictionary = {}) -> Unit:
	var cd: CharacterData = (ContentDB.get_all("characters")[0] as CharacterData).duplicate(true)
	cd.ai_controlled = false
	for k: String in slots:
		cd.set(k, slots[k])
	var u := Unit.new()
	u.setup(cd, team, 8)
	u.grid = g
	tree.root.add_child(u)
	u.place_at(cell)
	return u


func test_passives() -> void:
	check(ContentDB.get_passive("counter_hack") != null and ContentDB.get_all("passives").size() >= 18, "passives load (%d)" % ContentDB.get_all("passives").size())
	for p: PassiveResource in ContentDB.get_all("passives"):
		check(p.slot in ["reaction", "support", "movement"] and ClassLibrary.get_class_res(p.class_id) != null, "passive %s: valid slot + class" % p.id)
	var g := IsometricGrid.new()
	g.setup(10, 10)
	var keep := {}
	for id: String in ["counter_hack", "firewall", "overwatch", "reroute"]:
		keep[id] = ContentDB.get_passive(id).chance
		ContentDB.get_passive(id).chance = 1.0
	# Supports + movement.
	var mage := _pu(g, Unit.Team.PLAYER, Vector2i(1, 1), {"support_id": "overclock_cooling", "movement_id": "move_plus_2"})
	var gunner := _pu(g, Unit.Team.PLAYER, Vector2i(2, 1), {"support_id": "quickdraw"})
	var plain := _pu(g, Unit.Team.PLAYER, Vector2i(1, 3))
	var spell: Ability = null
	var heavy: Ability = null
	for a: Ability in ContentDB.get_all("abilities"):
		if spell == null and a.kind == Ability.Kind.MAGIC and a.mp_cost >= 10:
			spell = a
		if heavy == null and a.kind == Ability.Kind.ATTACK and a.ap_cost >= 2:
			heavy = a
	check(mage.mp_cost_of(spell) == roundi(spell.mp_cost * 0.7) and plain.mp_cost_of(spell) == spell.mp_cost, "Overclock Cooling: tech costs 30% less MP")
	check(gunner.ap_cost_of(heavy) == 1 and gunner.ap_cost_of(spell) == spell.ap_cost, "Quickdraw: heavy attacks cost 1 AP, nothing else changes")
	check(mage.get_stat("move") == plain.get_stat("move") + 2, "Move +2")
	var brute := _pu(g, Unit.Team.ENEMY, Vector2i(5, 5), {"support_id": "killer_instinct"})
	var tank := _pu(g, Unit.Team.PLAYER, Vector2i(5, 6), {"support_id": "hardened_chrome"})
	var hit := ContentDB.get_ability("basic_attack")
	check(is_equal_approx(Passives.damage_mult(brute, tank, hit), 1.15 * 0.85), "damage dealt / taken supports stack")
	# Firewall blocks enemy debuffs, not friendly ones.
	var fw := _pu(g, Unit.Team.PLAYER, Vector2i(8, 8), {"reaction_id": "firewall"})
	check(not fw.apply_status("slow", brute) and not fw.has_status("slow"), "Firewall rejects an enemy debuff")
	check(fw.apply_status("slow", tank), "…but not one from an ally")
	# Counter-Hack: the target strikes back.
	CombatManager.grid = g
	CombatManager.units.clear()
	CombatManager.units.append_array([mage, plain, brute, tank, fw])
	CombatManager.animate = false
	CombatManager.rng.seed = 7
	var samurai := _pu(g, Unit.Team.PLAYER, Vector2i(3, 3), {"reaction_id": "counter_hack"})
	var thug := _pu(g, Unit.Team.ENEMY, Vector2i(3, 4))
	CombatManager.units.append_array([samurai, thug])
	var hp0 := thug.current_hp
	samurai.current_hp = samurai.get_stat("max_hp")
	await CombatManager._execute(thug, hit, samurai.cell)
	check(thug.current_hp < hp0, "Counter-Hack hits back (%d → %d)" % [hp0, thug.current_hp])
	# Overwatch: shoots a mover that stops in range, once per round.
	var sniper := _pu(g, Unit.Team.PLAYER, Vector2i(0, 9), {"reaction_id": "overwatch"})
	var runner := _pu(g, Unit.Team.ENEMY, Vector2i(1, 9))
	CombatManager.units.append_array([sniper, runner])
	var rhp := runner.current_hp
	await Passives.after_move(CombatManager, runner)
	check(runner.current_hp < rhp and sniper.get_meta("overwatch_spent", false), "Overwatch fires on an enemy ending its move in range")
	rhp = runner.current_hp
	await Passives.after_move(CombatManager, runner)
	check(runner.current_hp == rhp, "…once per round")
	sniper.begin_turn()
	check(not sniper.get_meta("overwatch_spent", true), "re-arms on its own turn")
	# Phase Step: walk through a unit blocking a corridor.
	var lane := IsometricGrid.new()
	lane.setup(6, 1)
	var ghost := _pu(lane, Unit.Team.PLAYER, Vector2i(0, 0), {"movement_id": "phase_step"})
	var wall := _pu(lane, Unit.Team.ENEMY, Vector2i(1, 0))
	var walker := _pu(lane, Unit.Team.PLAYER, Vector2i(5, 0))
	check(lane.reachable_cells(ghost.cell, 4, 2, ghost.team, Passives.phases(ghost)).has(Vector2i(2, 0)), "Phase Step passes through a blocker")
	check(not lane.reachable_cells(ghost.cell, 4, 2, ghost.team, false).has(Vector2i(2, 0)), "…which normally blocks the lane")
	# Auto-Patch: once, under half HP.
	var medic := _pu(g, Unit.Team.PLAYER, Vector2i(7, 2), {"reaction_id": "auto_patch"})
	var foe := _pu(g, Unit.Team.ENEMY, Vector2i(7, 3))
	medic.current_hp = int(medic.get_stat("max_hp") * 0.3)
	var before := medic.current_hp
	var ctx := Ability.Context.new()
	await Passives.after_action(CombatManager, foe, hit, [{"unit": medic, "kind": "damage", "amount": 1, "crit": false}], ctx)
	check(medic.current_hp > before and medic.has_meta("patched"), "Auto-Patch heals under half HP")
	# Learning + equipping.
	var rookie: CharacterData = (ContentDB.get_all("characters")[0] as CharacterData).duplicate(true)
	rookie.class_levels["signal_thief"] = 1
	var chips := GameManager.microchips
	GameManager.microchips = 10
	check(ProgressionSystem.learn_passive(rookie, "move_plus_2") == "Class not unlocked.", "can't learn from a locked class")
	check(ProgressionSystem.learn_passive(rookie, "reroute") == "" and GameManager.microchips == 10 - ContentDB.get_passive("reroute").chip_cost, "learn with microchips")
	check(not ProgressionSystem.equip_passive(rookie, "support", "reroute") and ProgressionSystem.equip_passive(rookie, "reaction", "reroute") and rookie.reaction_id == "reroute", "equip only in its own slot")
	check(not ProgressionSystem.equip_passive(rookie, "movement", "move_plus_1"), "can't equip unlearned")
	GameManager.microchips = chips
	check(ContentDB.get_character("choir_enforcer").reaction_id == "firewall", "enemy templates carry passives")
	for id: String in keep:
		ContentDB.get_passive(id).chance = keep[id]
	CombatManager.units.clear()
	CombatManager.grid = null
	for u: Node in [mage, gunner, plain, brute, tank, fw, samurai, thug, sniper, runner, ghost, wall, walker, medic, foe]:
		u.queue_free()
	await tree.process_frame


func test_dev_console() -> void:
	var dc := DevConsole
	check(dc.run("1 + 2") == "3", "expressions evaluate")
	check(dc.run("Engine.time_scale") == str(Engine.time_scale), "Engine / OS / Time are in scope")
	var coins := GameManager.soul_coins
	check(dc.run("GameManager.soul_coins") == str(coins), "autoloads are in scope")
	dc.run("coins 50")
	check(GameManager.soul_coins == coins + 50, "coins command")
	dc.run("flag t_console_flag")
	check(GameManager.check_story_flag("t_console_flag"), "flag command")
	GameManager.story_flags.erase("t_console_flag")
	var item_id: String = (ContentDB.get_all("items")[0] as GameResource).id
	var before := GameManager.get_stack_count(item_id)
	dc.run("give %s 2" % item_id)
	check(GameManager.get_stack_count(item_id) >= before, "give command runs")
	check(dc.run("give not_an_item").contains("Unknown item"), "bad ids are reported, not crashed on")
	check(dc.run("nonsense_token(").contains("color=#ff4f7a"), "bad expressions are reported")
	check(dc.complete("pa") == ["passive"], "Tab completes commands")
	check(dc.complete("status petr") == ["petrified"], "Tab completes content ids")
	dc.run("set GameManager.microchips 7")
	check(GameManager.microchips == 7, "set Autoload.property")
	dc.run("watch 2 * 21")
	dc._process(0.0)
	check(dc._watch_label.text.contains("= 42"), "watches update live")
	dc.run("unwatch")
	check(dc.run("cue hit.crit").contains("hit.crit"), "cue command fires a cue")
	check(dc.history.size() >= 10, "history kept")


func _pm_strip(path: String, color: Color, frames: int = 2, rect: Rect2i = Rect2i(8, 8, 16, 16)) -> void:
	var img := Image.create(32 * frames, 32, false, Image.FORMAT_RGBA8)
	for i in frames:
		img.fill_rect(Rect2i(rect.position + Vector2i(i * 32, 0), rect.size), color)
	img.save_png(path)


func test_pixel_matrix() -> void:
	check(PixelMatrix.parse_export("PM_96_SE_walk.png") == {"res": 96, "facing": "SE", "anim": "walk", "layer": ""}, "export names parse")
	check(PixelMatrix.parse_export("PM_84_NW_idle_LeftArm.png")["layer"] == "LeftArm" and PixelMatrix.parse_export("walk.png").is_empty(), "layer names parse; others ignored")
	check(PixelMatrix.layer_order("SE", ["LeftArm", "RightArm", "", "Torso_armor", "Torso"]) == ["", "RightArm", "Torso", "Torso_armor", "LeftArm"], "SE: right arm behind, gear right above its limb")
	check(PixelMatrix.layer_order("NE", ["LeftArm", "RightArm"]) == ["LeftArm", "RightArm"], "NE flips which arm is in front")
	var root := "user://t_pm/hero"
	var gear := "user://t_pm/gear_cape"
	for d: String in [root + "/idle", root + "/attack", gear + "/idle"]:
		DirAccess.make_dir_recursive_absolute(d)
	for f: String in ["SE", "NE"]:
		_pm_strip(root + "/idle/%s_LeftArm.png" % f, Color.RED)
		_pm_strip(root + "/idle/%s_RightArm.png" % f, Color.BLUE)
	_pm_strip(root + "/attack/SE.png", Color.GREEN, 4)
	_pm_strip(gear + "/idle/SE_RightArm.png", Color.YELLOW, 2, Rect2i(10, 10, 4, 4))
	check(PixelMatrix.is_root(root) and not PixelMatrix.is_root("user://t_pm"), "character folder detected")
	var se := PixelMatrix.composite(root, "idle", "SE")
	var ne := PixelMatrix.composite(root, "idle", "NE")
	check(se.get_pixel(12, 12) == Color.RED and ne.get_pixel(12, 12) == Color.BLUE, "facing decides which limb is drawn on top")
	var geared := PixelMatrix.composite(root, "idle", "SE", [gear])
	check(geared.get_pixel(11, 11) == Color.RED and geared.get_pixel(40 + 3, 11) == Color.RED, "gear on the back arm stays behind the front arm")
	var us := PixelMatrix.unit_set(root)
	var sf: SpriteFrames = us["frames"]
	check(us["ok"] and sf.has_animation("idle_SE") and sf.has_animation("idle_NE") and sf.get_frame_count("attack_SE") == 4, "unit set: anims per facing, frames from strip width")
	check(sf.get_animation_loop("idle_SE") and not sf.get_animation_loop("attack_SE"), "idles loop, attacks play once")
	check(us["anchors"]["idle_SE"] == Vector2(16, 31), "feet at bottom-centre by default")
	var cd: CharacterData = (ContentDB.get_all("characters")[0] as CharacterData).duplicate(true)
	cd.sprite_frames_path = root
	var u := Unit.new()
	u.setup(cd, Unit.Team.PLAYER, 1)
	tree.root.add_child(u)
	await tree.process_frame
	check(u.sprite != null and str(u.sprite.animation) == "idle_SE", "a unit wears a PixelMatrix folder")
	u.facing = Vector2i(0, -1)
	check(str(u.sprite.animation) == "idle_NE", "and turns with it")
	u.queue_free()
	await tree.process_frame
	for d: String in [root + "/idle", root + "/attack", gear + "/idle"]:
		for f in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d + "/" + f)
		DirAccess.remove_absolute(d)
	for d: String in [root, gear, "user://t_pm"]:
		DirAccess.remove_absolute(d)


func test_cover() -> void:
	var g := IsometricGrid.new()
	g.setup(12, 12)
	var t := Vector2i(5, 5)
	g.get_cell(Vector2i(6, 5)).cover = IsometricGrid.COVER_FULL  # wall on the +x side
	check(is_equal_approx(g.cover_fraction(t, Vector2i(10, 5)), 1.0), "full cover head-on blocks 100%")
	check(is_equal_approx(g.cover_fraction(t, Vector2i(9, 7)), IsometricGrid.FULL_FLANK), "full cover from the side angle: 66%%  (%s)" % g.cover_fraction(t, Vector2i(9, 7)))
	check(g.cover_fraction(t, Vector2i(5, 10)) == 0.0 and g.cover_fraction(t, Vector2i(1, 5)) == 0.0, "no cover from the open sides / behind")
	g.get_cell(Vector2i(5, 4)).cover = IsometricGrid.COVER_FULL
	check(g.cover_fraction(t, Vector2i(5, 3)) == 1.0 and g.cover_fraction(t, Vector2i(4, 5)) == 0.0, "melee (adjacent) ignores cover")
	g.get_cell(Vector2i(5, 4)).cover = IsometricGrid.COVER_NONE
	g.get_cell(Vector2i(6, 5)).cover = IsometricGrid.COVER_HALF
	check(is_equal_approx(g.cover_fraction(t, Vector2i(10, 5)), IsometricGrid.HALF_FRONT) and is_equal_approx(g.cover_fraction(t, Vector2i(9, 7)), IsometricGrid.HALF_FLANK), "half cover: 50% head-on, 25% flank")
	g.get_cell(Vector2i(10, 5)).height = 4
	check(is_equal_approx(g.cover_fraction(t, Vector2i(10, 5)), IsometricGrid.HALF_FRONT * 0.5), "shooting from 3+ levels up halves cover")
	g.get_cell(Vector2i(10, 5)).height = 0
	g.get_cell(Vector2i(6, 5)).cover = IsometricGrid.COVER_FULL
	var shooter := _pu(g, Unit.Team.ENEMY, Vector2i(10, 5))
	var target := _pu(g, Unit.Team.PLAYER, t)
	var gun: Ability = null
	for a: Ability in ContentDB.get_all("abilities"):
		if a.kind == Ability.Kind.ATTACK and not DamageCalculator.is_magical(a) and not a.ignores_cover and a.range_max >= 4:
			gun = a
			break
	check(DamageCalculator.hit_chance(shooter, target, gun, g) == 0.0 and DamageCalculator.is_blocked(target, shooter, gun, g), "no line of sight through full cover head-on")
	shooter.place_at(Vector2i(9, 7))
	var flank_hit := DamageCalculator.hit_chance(shooter, target, gun, g)
	g.get_cell(Vector2i(6, 5)).cover = IsometricGrid.COVER_NONE
	var open_hit := DamageCalculator.hit_chance(shooter, target, gun, g)
	check(flank_hit > 0.0 and flank_hit < open_hit, "flanking full cover: a shot, but a worse one (%.2f vs %.2f)" % [flank_hit, open_hit])
	target.apply_status("cloaked")
	check(DamageCalculator.hit_chance(shooter, target, gun, g) == 0.0, "cloaked: can't be hit from range")
	target.apply_status("shielded")
	shooter.place_at(Vector2i(5, 6))
	check(DamageCalculator.hit_chance(shooter, target, gun, g) == 0.0, "shielded: untouchable")
	shooter.queue_free()
	target.queue_free()


class IxHost:
	var toasts: Array = []
	var units: Array = []
	var groups: Array = []
	func ix_toast(text: String, _c: Color) -> void: toasts.append(text)
	func ix_units() -> Array: return units
	func ix_group_changed(group: String, open: bool) -> void: groups.append([group, open])


func test_masks_and_anchors() -> void:
	var w := _map()
	for x in 8:
		for y in 8:
			w.set_tile(Vector2i(x, y), 0, "terrain:concrete")
	# Painter masks.
	var p := ForgeWorldPainter.new()
	p.world = w
	p.apply_mask(Vector2i(1, 1), ForgeWorldPainter.Mask.IMPASSABLE, false)
	p.apply_mask(Vector2i(2, 1), ForgeWorldPainter.Mask.FULL, false)
	p.apply_mask(Vector2i(3, 1), ForgeWorldPainter.Mask.HALF, false)
	p.apply_mask(Vector2i(4, 1), ForgeWorldPainter.Mask.SIGHT, false)
	p.mask_group = "vault"
	p.apply_mask(Vector2i(4, 4), ForgeWorldPainter.Mask.GROUP, false)
	p.apply_mask(Vector2i(4, 5), ForgeWorldPainter.Mask.GROUP, false)
	p.apply_mask(Vector2i(5, 5), ForgeWorldPainter.Mask.HALF, false)
	p.apply_mask(Vector2i(5, 5), ForgeWorldPainter.Mask.CLEAR, false)
	var g := w.to_grid()
	check(not g.is_walkable(Vector2i(1, 1)) and g.get_cell(Vector2i(2, 1)).cover == 2 and g.get_cell(Vector2i(3, 1)).cover == 1 and g.get_cell(Vector2i(4, 1)).blocks_los, "mask brushes reach the battle grid")
	check(not g.is_walkable(Vector2i(4, 4)) and w.group_cells("vault").size() == 2 and not w.gameplay.has(Vector2i(5, 5)), "door group starts sealed; CLEAR wipes a cell")
	p.free()
	# Anchors save and load.
	var term := w.add_anchor(Vector2i(2, 4), "terminal")
	term["actions"] = [{"do": "open", "arg": "vault"}]
	var loot := w.add_anchor(Vector2i(6, 6), "loot")
	loot["actions"] = [{"do": "chips", "arg": "2"}]
	var trap := w.add_anchor(Vector2i(4, 6), "trap")
	var s1 := w.add_anchor(Vector2i(0, 7), "switch")
	var s2 := w.add_anchor(Vector2i(1, 7), "switch")
	var s3 := w.add_anchor(Vector2i(2, 7), "switch")
	for i in 3:
		var sw: Dictionary = [s1, s2, s3][i]
		sw["sequence"] = "core"
		sw["step"] = i + 1
		sw["actions"] = []
	s3["actions"] = [{"do": "unshield", "arg": ""}]
	var w2 := WorldMap.from_dict(w.to_dict())
	check(w2.anchors.size() == 6 and str(w2.anchor_by_id(str(term["id"]))["kind"]) == "terminal" and w2.anchors_at(Vector2i(6, 6)).size() == 1, "anchors round-trip")
	# Runtime.
	var host := IxHost.new()
	var ix := Interactions.new().setup(w, g, host, "battle")
	var hero := _pu(g, Unit.Team.PLAYER, Vector2i(2, 3))
	var boss := _pu(g, Unit.Team.ENEMY, Vector2i(7, 0))
	var sneak := _pu(g, Unit.Team.ENEMY, Vector2i(7, 3))
	host.units = [hero, boss, sneak]
	boss.apply_status("shielded")
	sneak.apply_status("cloaked")
	check(ix.usable_from(Vector2i(2, 3), hero).has(term) and not ix.usable_from(Vector2i(0, 0), hero).has(term), "terminal usable from the next cell only")
	check(not ix.is_visible(loot) and not ix.is_visible(trap) and ix.is_visible(term), "hidden loot / traps have no marker")
	var ap0 := hero.current_ap
	ix.interact(term, hero)
	check(hero.current_ap == ap0 - 1 and g.is_walkable(Vector2i(4, 4)) and g.get_cell(Vector2i(4, 4)).cover == 0 and host.groups == [["vault", true]], "terminal opens the door group (costs 1 AP)")
	var chips0 := GameManager.microchips if "microchips" in GameManager else 0
	hero.current_ap = 2
	check(not ix.usable_from(Vector2i(6, 5), hero).has(loot) and ix.usable_from(Vector2i(6, 6), hero).has(loot), "hidden loot: stand on it to search")
	ix.interact(loot, hero)
	check(ix.is_used(loot) and ix.blocker(loot) != "", "loot is one-shot")
	if "microchips" in GameManager:
		check(GameManager.microchips == chips0 + 2, "loot pays out")
	# Switch sequence: wrong order resets, right order drops the boss shield.
	hero.current_ap = 9
	ix.interact(s2, hero)
	check(int(ix.progress.get("core", 1)) == 1 and host.toasts.has("WRONG ORDER — SEQUENCE RESET"), "out-of-order switch resets the sequence")
	ix.interact(s1, hero)
	check(ix.is_lit(s1) and not ix.is_lit(s2), "pressed switches stay lit")
	ix.interact(s2, hero)
	check(boss.has_status("shielded"), "shield holds until the last switch")
	ix.interact(s3, hero)
	check(not boss.has_status("shielded"), "sequence complete: boss shield down")
	# Traps: hurt the side they're wired against; rewire turns them around.
	var hp0 := hero.current_hp
	check(ix.on_enter(Vector2i(4, 6), sneak).is_empty(), "trap ignores the side that set it")
	ix.trap_hostile.erase(str(trap["id"]))
	var fired := ix.on_enter(Vector2i(4, 6), hero)
	check(fired.size() == 1 and hero.current_hp < hp0 and ix.is_visible(trap) == false, "stepping on a trap springs it once")
	var trap2 := w.add_anchor(Vector2i(5, 6), "trap")
	ix.revealed[str(trap2["id"])] = true
	ix.interact(trap2, hero, "rewire")
	check(ix.hostile_to(trap2) == "enemy" and ix.on_enter(Vector2i(5, 6), hero).is_empty(), "rewired trap spares the team that rewired it")
	check(ix.on_enter(Vector2i(5, 6), sneak).size() == 1, "…and goes off under the enemy")
	# Smoke device reveals cloaked units and hidden anchors nearby.
	var smoke := w.add_anchor(Vector2i(6, 3), "device")
	ix.interact(smoke, hero)
	check(not sneak.has_status("cloaked"), "smoke device strips cloaking")
	# Offline anchors and requirements.
	var gate := w.add_anchor(Vector2i(0, 0), "terminal")
	gate["enabled"] = false
	check(ix.blocker(gate) == "Offline.", "disabled anchors are offline")
	ix.run_action("enable", str(gate["id"]))
	check(ix.blocker(gate) == "", "another anchor can bring one online")
	gate["requires_item"] = "no_such_keycard"
	check(ix.blocker(gate).begins_with("Needs"), "keycard requirement")
	var st := ix.get_state()
	var ix2 := Interactions.new().setup(w, w.to_grid(), null, "explore")
	ix2.set_state(st)
	check(ix2.is_open("vault") and ix2.grid.is_walkable(Vector2i(4, 4)) and ix2.is_used(loot), "interaction state carries over")
	for u: Node in [hero, boss, sneak]:
		u.queue_free()


func test_npc_stages() -> void:
	GameManager.new_game()
	var ma := ContentDB.get_npc("ma_rivet")
	check(ma != null and NpcStages.has_stages(ma) and ma.after_talk == "fetch", "Ma Rivet: NPC with interaction stages loads")
	var coins0 := GameManager.soul_coins
	var r := NpcStages.fetch_turn_in(ma)
	check(r["delivered"].is_empty() and not r["done"] and str(r["lines"][0]).begins_with("Bring me"), "fetch: nothing carried, she says what she wants")
	GameManager.give_item("mat_scrap_wire", 2)
	r = NpcStages.fetch_turn_in(ma)
	check(int(r["delivered"].get("mat_scrap_wire", 0)) == 2 and GameManager.soul_coins == coins0 + 40 and GameManager.get_stack_count("mat_scrap_wire") == 0, "fetch: partial return pays the per-return reward")
	check(NpcStages.fetch_left(ma).size() == 2, "fetch: still wants 1 wire + 2 batteries (%s)" % str(NpcStages.fetch_left(ma)))
	GameManager.give_item("mat_scrap_wire", 5)
	GameManager.give_item("mat_dead_battery", 2)
	var chips0 := GameManager.microchips
	r = NpcStages.fetch_turn_in(ma)
	check(r["done"] and GameManager.get_stack_count("mat_scrap_wire") == 4 and GameManager.microchips == chips0 + 2 and GameManager.get_stack_count("acc_jump_boots") + GameManager.item_instances.size() > 0, "fetch: completing pays the final reward, keeps the extras")
	check(NpcStages.fetch_turn_in(ma)["done"] and NpcStages.fetch_turn_in(ma)["delivered"].is_empty(), "fetch: finished stays finished")
	# Chains gate on flags / quests / missions / items.
	var n := NPCResource.new()
	n.id = "t_chain"
	n.after_talk = "chain"
	n.chain_requires = ["t_chain_flag", "item:mat_neon_ink:2"]
	check(NpcStages.chain_missing(n).size() == 2, "chain: both requirements missing")
	GameManager.set_story_flag("t_chain_flag")
	GameManager.give_item("mat_neon_ink", 2)
	check(NpcStages.chain_ready(n), "chain: unlocked once the flag + items are in hand")
	var qid: String = ContentDB.get_ids("quests")[0]
	var lines := NpcStages.quest_step(qid)
	check(QuestManager.get_state(qid) in [QuestManager.ACTIVE, QuestManager.LOCKED] and lines.size() == 1, "quest stage offers the quest (%s)" % QuestManager.get_state(qid))
	GameManager.new_game()


func test_vault_demo() -> void:
	var m := ContentDB.get_mission("demo_vault_breach")
	var d := ContentDB.get_map("vault_breach_demo")
	check(m != null and not d.is_empty(), "Vault Breach demo mission + map load")
	if m == null or d.is_empty():
		return
	var w := WorldMap.from_dict(d)
	var g := w.to_grid()
	check(not g.is_walkable(Vector2i(9, 6)) and g.get_cell(Vector2i(9, 6)).cover == 2 and w.group_cells("vault_door").size() == 2, "vault shutter starts sealed")
	var boss_entry: Dictionary = m.enemies[0]
	check(str(boss_entry["character_id"]) == "foreman_grisk" and (boss_entry.get("statuses", []) as Array).has("shielded"), "the Foreman starts shielded")
	var host := IxHost.new()
	var ix := Interactions.new().setup(w, g, host, "battle")
	var hero := _pu(g, Unit.Team.PLAYER, Vector2i(8, 8))
	var boss := _pu(g, Unit.Team.ENEMY, Vector2i(13, 7))
	boss.data.id = "foreman_grisk"
	boss.apply_status("shielded")
	host.units = [hero, boss]
	hero.current_ap = 99
	var term: Dictionary = ix.usable_from(hero.cell, hero)[0]
	ix.interact(term, hero)
	check(g.is_walkable(Vector2i(9, 6)) and g.is_walkable(Vector2i(9, 7)), "terminal opens the shutter")
	var relays := w.anchors.filter(func(a: Dictionary) -> bool: return str(a.get("sequence", "")) == "core")
	relays.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["step"]) < int(b["step"]))
	var hp0 := hero.current_hp
	ix.interact(relays[2], hero)
	check(hero.current_hp < hp0 and boss.has_status("shielded"), "wrong relay first: feedback shock, shield holds")
	for a: Dictionary in relays:
		ix.interact(a, hero)
	check(not boss.has_status("shielded"), "relays in order drop the Foreman's shield")
	var block := WorldMap.from_dict(ContentDB.get_map("neon_block_demo"))
	check(block.anchors.size() >= 3 and str(block.anchor_by_id("anc_neon_block_demo_1").get("npc_id", "")) == "ma_rivet", "Neon Block demo: Ma Rivet + vault entrance anchors")
	hero.queue_free()
	boss.queue_free()


func test_campaign_fixes() -> void:
	# Mission levels grow the primaries, not just HP / MP.
	var cd := ContentDB.get_character("doctrine_warden")
	var lo := Unit.new()
	lo.setup(cd, Unit.Team.ENEMY, 1)
	var hi := Unit.new()
	hi.setup(cd, Unit.Team.ENEMY, 10)
	check(hi.get_stat("attack") > lo.get_stat("attack") and hi.get_stat("speed") >= lo.get_stat("speed") and hi.get_stat("level") == 10, "enemy level 10 hits harder than level 1 (%d vs %d)" % [hi.get_stat("attack"), lo.get_stat("attack")])
	check(ContentDB.get_character("doctrine_warden").get_stats().level == cd.get_stats().level, "levelling an enemy never touches its template")
	lo.free()
	hi.free()
	# Shop stock survives a save.
	VendorSystem.stock_left = {"armor_vendor": {"arm_x": 2}}
	var vs := VendorSystem.get_state_data()
	VendorSystem.reset()
	VendorSystem.load_state_data(JSON.parse_string(JSON.stringify(vs)))
	check(int(VendorSystem.stock_left.get("armor_vendor", {}).get("arm_x", -1)) == 2, "limited shop stock saves and loads")
	VendorSystem.reset()
	# Explore position + battle return survive a save, and a battle started
	# from a map hands you back to it.
	var keep_explore := CampaignManager.current_explore.duplicate()
	CampaignManager.current_explore = {"map_id": "neon_block_demo", "spawn": -1, "at": Vector2i(8, 6)}
	CampaignManager.battle_return = CampaignManager.current_explore.duplicate()
	var cdata: Dictionary = JSON.parse_string(JSON.stringify(CampaignManager.get_campaign_data()))
	CampaignManager.current_explore = {}
	CampaignManager.battle_return = {}
	CampaignManager.load_campaign_data(cdata)
	check(CampaignManager.current_explore.get("at") == Vector2i(8, 6) and str(CampaignManager.battle_return.get("map_id", "")) == "neon_block_demo", "explore cell + battle return round-trip through a save")
	CampaignManager.current_explore = keep_explore
	CampaignManager.battle_return = {}
	# Region music triggers store paths: the audio system takes them as is.
	AudioManager.play_music("res://assets/music/does_not_exist.ogg")
	check(AudioManager.current_music_id == "res://assets/music/does_not_exist.ogg", "music accepts a file path without erroring")
	AudioManager.play_music("")


func test_streaming() -> void:
	var w := WorldMap.new()
	w.id = "t_stream"
	w.width = 100
	w.depth = 100
	for x in 100:
		for y in 100:
			w.set_tile(Vector2i(x, y), (x + y) % 3, "terrain:concrete")
	w.add_object("", Vector2i(5, 5), 0, "structure")
	w.add_object("", Vector2i(90, 90), 0, "prop")
	# Lazy grid = same rules as the full grid, built on demand.
	var full := w.to_grid()
	var lazy := w.to_grid(true)
	var same := true
	for c: Vector2i in [Vector2i(5, 5), Vector2i(0, 0), Vector2i(42, 17), Vector2i(90, 90), Vector2i(99, 99)]:
		var a := full.get_cell(c)
		var b := lazy.get_cell(c)
		same = same and a.walkable == b.walkable and a.height == b.height and a.cover == b.cover and a.prop_id == b.prop_id
	check(same and lazy._cells.size() == 5 and not lazy.is_walkable(Vector2i(5, 5)), "lazy grid matches the full one, cells built on demand")
	# Streaming renderer: only chunks near the camera exist; scrolling swaps them.
	var r := WorldRenderer.new()
	r.world = w
	r.max_chunks = 4
	r.margin_chunks = 0
	var cam := Camera2D.new()
	tree.root.add_child(cam)
	cam.position = w.to_screen(Vector2(8, 8), 0)
	cam.zoom = Vector2(2, 2)
	cam.make_current()
	tree.root.add_child(r)
	for i in 4:
		await tree.process_frame
	check(r.streaming and r.loaded_chunks().has(Vector2i(0, 0)) and not r.loaded_chunks().has(Vector2i(3, 3)), "big map streams: chunk around the camera built, far chunk not (%s)" % str(r.loaded_chunks()))
	check(r.object_node(str(w.objects[0]["id"])) != null and r.object_node(str(w.objects[1]["id"])) == null, "objects build with their chunk")
	cam.position = w.to_screen(Vector2(92, 92), 0)
	for i in 6:
		await tree.process_frame
	check(r.loaded_chunks().has(Vector2i(2, 2)) and not r.loaded_chunks().has(Vector2i(0, 0)) and r.object_node(str(w.objects[1]["id"])) != null, "scrolling loads the new chunk and frees the old one (%s)" % str(r.loaded_chunks()))
	var strips_ok := true
	for k: Vector3i in r._columns:
		strips_ok = strips_ok and r.loaded_chunks().has(Vector2i(k.y, k.z))
	check(strips_ok, "no tile strips left over from freed chunks")
	r.queue_free()
	cam.queue_free()
	# Undo journal records old stacks once per column.
	w.journal = {}
	w.set_tile(Vector2i(1, 1), 5, "terrain:lava")
	w.set_tile(Vector2i(1, 1), 6, "terrain:lava")
	check((w.journal as Dictionary).size() == 1 and ((w.journal as Dictionary)[Vector2i(1, 1)] as Array).size() == 1, "undo journal keeps the column as it was before the stroke")
	w.journal = null


func test_pixellab() -> void:
	check(PixelLab.classify("attack_kick", "Roundhouse_Kick") == "attack" and PixelLab.classify("attack_kick", "Taking_Hit") == "hit"
		and PixelLab.classify("throwing_up_item_to_heal", "The_right_hand_reaches") == "cast" and PixelLab.classify("run", "Running") == "run"
		and PixelLab.classify("walking_forward", "Walking") == "walk" and PixelLab.classify("idle_breathing", "Breathing_Idle") == "idle", "PixelLab names map to game actions")
	var dir := "res://assets/units/test_enemy_001"
	if not PixelLab.is_root(dir):
		check(false, "test_enemy_001 PixelLab export present")
		return
	var us := PixelLab.unit_set(dir)
	var sf: SpriteFrames = us["frames"]
	check(us["ok"] and sf.has_animation("walk_SE") and sf.has_animation("attack_NW") and sf.has_animation("hit_SW") and sf.has_animation("idle_S"), "Bulwark Brawler: walk / attack / hit by facing, idle in all 8")
	check(sf.has_animation("roundhouse_kick_SE") and sf.has_animation("uppercut_NE"), "extra animations keep their own names for abilities")
	check(not sf.get_animation_loop("attack_SE") and sf.get_animation_loop("walk_SE"), "attacks play once, walks loop")
	var a: Vector2 = us["anchors"]["walk_SE"]
	var cell: Vector2 = us["cells"]["walk_SE"]
	check(a.x == cell.x * 0.5 and a.y > cell.y * 0.6 and a.y < cell.y, "anchor on the feet (%s in %s)" % [a, cell])
	var g := IsometricGrid.new()
	g.setup(6, 6)
	g.tile_width = 128.0
	var cd := (ContentDB.get_character("test_enemy_001") as CharacterData)
	var u := Unit.new()
	u.setup(cd, Unit.Team.ENEMY, 3)
	u.grid = g
	tree.root.add_child(u)
	u.place_at(Vector2i(2, 2))
	check(u.sprite != null and is_equal_approx(u.sprite.scale.x, 1.5), "PixelLab unit drawn at 1.5× on 128-wide tiles")
	var kick := ContentDB.get_ability("tx_roundhouse_kick")
	check(kick != null and u.anim_for(kick) == "roundhouse_kick" and u.anim_for(ContentDB.get_ability("basic_attack")) == "attack", "abilities pick their animation (kick → roundhouse_kick)")
	var gunner := Unit.new()
	gunner.setup(ContentDB.get_character("test_enemy_002"), Unit.Team.ENEMY, 3)
	gunner.grid = g
	tree.root.add_child(gunner)
	check(gunner.anim_for(ContentDB.get_ability("tx_field_patch")) == "cast" and str(PixelLab.unit_set("res://assets/units/test_enemy_002")["actions"]["walk"]).begins_with("walking_forward"), "Corp Gunner: patch plays the item animation, plain walk pinned by pixellab.json")
	u.queue_free()
	gunner.queue_free()
	var m := ContentDB.get_mission("test_pixellab_skirmish")
	check(m != null and bool(m.guests[0].get("controlled", false)) and ContentDB.get_npc("kade") != null and ContentDB.vendors.has("test_vendor"), "test skirmish, Kade and his shop are in")


func test_ui_icons() -> void:
	var miss := {}
	for bucket: String in ["classes", "status_effects", "abilities", "items", "passives"]:
		miss[bucket] = []
		for r: GameResource in ContentDB.get_all(bucket):
			var t: Texture2D = null
			match bucket:
				"classes": t = UIIcons.get_icon("class", r.id)
				"status_effects": t = UIIcons.status(r.id)
				"abilities": t = UIIcons.ability(r as Ability)
				"items": t = UIIcons.item(r as ItemResource)
				"passives": t = UIIcons.passive(r as PassiveResource)
			if t == null:
				miss[bucket].append(r.id)
	check(miss["abilities"].is_empty() and miss["items"].is_empty() and miss["passives"].is_empty(), "every ability, item and passive has an icon (missing %s)" % str(miss))
	check(miss["status_effects"].size() <= 2, "status icons (missing %s)" % str(miss["status_effects"]))
	check(miss["classes"].size() <= 12, "class icons: %d missing (enemy chassis fall back)" % miss["classes"].size())
	check(UIIcons.get_icon("cmd", "move") != null and UIIcons.get_icon("cmd", "end_turn") != null, "command icons")
	var painted := UIIcons.find("burning")
	SettingsFlags.icon_style = "framed"
	var framed := UIIcons.find("burning")
	SettingsFlags.icon_style = "painted"
	check(painted.contains("/painted/") and framed.contains("/framed/"), "style setting picks the pack")
