extends RefCounted
## Test suite body. Loaded by run_tests.gd after autoloads exist (a -s script
## compiles before autoload names are registered, so it can't reference them).
## Validates content cross-references, stat math, grid, progression, forge,
## dispatch, save round-trip, and runs full AI-vs-AI battles.

var _fails := 0
var _passes := 0
var tree: SceneTree
var root: Window
var process_frame: Signal


func run(p_tree: SceneTree) -> int:
	tree = p_tree
	root = tree.root
	process_frame = tree.process_frame
	test_content()
	test_stats()
	test_grid()
	test_progression_and_forge()
	test_dispatch()
	test_save_roundtrip()
	await test_battles()
	print("\n=== %d passed, %d failed ===" % [_passes, _fails])
	return _fails


func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("FAIL: ", msg)


func test_content() -> void:
	var problems := ContentDB.validate()
	for p in problems:
		printerr("  content: ", p)
	check(problems.is_empty(), "content cross-references valid (%d problems)" % problems.size())
	check(ContentDB.load_errors.is_empty(), "no JSON load errors")
	check(ClassLibrary.get_all_classes().size() == 35, "35 playable classes (got %d)" % ClassLibrary.get_all_classes().size())
	var secret := ClassLibrary.get_all_classes().filter(func(c: ClassResource) -> bool: return c.is_hidden)
	check(secret.size() == 6, "6 secret classes")
	for c in ClassLibrary.get_all_classes():
		check(not c.innate_ability_ids.is_empty(), "class %s has innate abilities" % c.id)
	# JSON round trip keeps enums as names.
	var a := ContentDB.get_ability("plasma_bolt")
	check(a.to_dict()["kind"] == "MAGIC", "enum serializes by name")
	check(ContentDB.get_ability("warp_coordinates") is TerrainAbility, "script-typed ability instantiates subclass")


func test_stats() -> void:
	var s := UnitStats.new()
	s.strength = 999; s.agility = 999; s.intelligence = 999; s.vitality = 999; s.level = 99
	var cls := ClassLibrary.get_class_res("plasma_vanguard")
	var r := s.calculate(cls, {"attack": 5000, "max_hp": 50000}, {"attack": 10.0, "defense": 10.0})
	check(r["attack"] <= UnitStats.STAT_MAX and r["max_hp"] <= UnitStats.HP_MAX, "stats clamp (no overflow)")
	var s2 := UnitStats.new()
	var r2 := s2.calculate(cls, {}, {"speed": 0.0})
	check(r2["speed"] >= 1 and r2["max_hp"] >= 1, "stats floor at 1")
	check(ProgressionSystem.xp_to_next(99) > 0 and ProgressionSystem.xp_to_next(99) < 100000, "xp curve bounded")


func test_grid() -> void:
	var g := IsometricGrid.new()
	g.setup(8, 8)
	g.set_height(Vector2i(3, 3), 5)
	for c in g.all_cells():
		check(g.world_to_grid_flat(g.grid_to_world(c, false)) == c, "iso projection round-trips %s" % c) if c.x == c.y else null
	check(g.pick_cell(g.grid_to_world(Vector2i(3, 3))) == Vector2i(3, 3), "pick_cell respects height")
	var reach := g.reachable_cells(Vector2i(2, 3), 3, 2, 0)
	check(not reach.has(Vector2i(3, 3)), "can't climb 5 levels with jump 2")
	check(not g.has_line_of_sight(Vector2i(1, 3), Vector2i(5, 3)), "tall cell blocks line of sight")
	check(g.has_line_of_sight(Vector2i(1, 1), Vector2i(5, 1)), "open line has sight")


func test_progression_and_forge() -> void:
	GameManager.new_game()
	var rook := GameManager.get_character("rook")
	check(rook != null, "starting roster built")
	var lv0 := rook.get_stats().level
	ProgressionSystem.add_xp(rook, 5000)
	check(rook.get_stats().level > lv0, "xp levels up")
	ProgressionSystem.add_class_xp(rook, 800)
	check(rook.get_class_level("chrome_warrior") >= 3, "class levels up")
	check(rook.get_class_level("iron_monk") >= 1, "iron monk auto-unlocked by warrior 2")
	check(rook.get_class_level("digital_knight") >= 1, "digital knight unlocked by warrior 3")
	check(not ClassLibrary.is_unlocked_for("digimancer", rook), "digimancer stays secret")
	GameManager.microchips = 5
	check(ProgressionSystem.learn_ability(rook, "brace") == "", "learn ability with chips")
	check(ProgressionSystem.learn_ability(rook, "bl_arc_lash") != "", "blue magic can't be bought")
	# Forge: evolve at 10 vs 30 -> later evolution has higher potential.
	check(ForgeManager.evolved_potential(1.0, 30) > ForgeManager.evolved_potential(1.0, 10), "waiting to evolve raises potential")
	var uid: String = rook.equipment["weapon"]
	ForgeManager.add_item_xp(uid, 999999)
	check(int(GameManager.get_item_instance(uid)["level"]) == 50, "gear caps at 50")
	GameManager.add_stack_item("mat_memory_core", 3)
	GameManager.add_stack_item("mat_archive_fragment", 1)
	GameManager.add_soul_coins(1000)
	var evo := ForgeManager.get_evolutions(uid)
	check(evo.size() == 1, "evolution recipe found")
	var res := ForgeManager.evolve(uid, evo[0])
	check(res.get("item_id") == "wpn_sword_2" and float(res["potential"]) > 1.7, "evolve keeps uid, boosts potential")


func test_dispatch() -> void:
	GameManager.new_game()
	DispatchManager.debug_now = 1000.0
	var a := DispatchManager.start_dispatch("dsp_salvage_belt", "brannoc")
	check(not a.is_empty(), "dispatch starts")
	check(GameManager.get_character("brannoc").is_dispatched, "dispatched character unavailable")
	check(not GameManager.get_party_members().any(func(c: CharacterData) -> bool: return c.id == "brannoc"), "dispatched not in party")
	DispatchManager.debug_now = 1000.0 + 60 * 60
	var coins := GameManager.soul_coins
	DispatchManager.check_completed()
	check(not GameManager.get_character("brannoc").is_dispatched, "dispatch returns")
	check(DispatchManager.completed_log.size() >= 1, "dispatch logged")
	DispatchManager.debug_now = -1.0
	check(GameManager.soul_coins >= coins, "dispatch never loses coins")


func test_save_roundtrip() -> void:
	GameManager.new_game()
	GameManager.add_soul_coins(1234)
	GameManager.set_story_flag("m01_done")
	var before := GameManager.soul_coins
	check(SaveManager.save_game(7), "save writes")
	GameManager.new_game()
	check(SaveManager.load_game(7), "save loads")
	check(GameManager.soul_coins == before and GameManager.check_story_flag("m01_done"), "state restored")
	check(GameManager.get_character("rook").equipment.has("weapon"), "equipment restored")
	SaveManager.delete_slot(7)


func _spawn(g: IsometricGrid, data: CharacterData, team: int, cell: Vector2i, level: int, units: Array[Node]) -> Unit:
	var u := Unit.new()
	u.setup(data, team, level)
	u.grid = g
	u.place_at(cell)
	root.add_child(u)
	units.append(u)
	return u


func _run_battle(mission_id: String, party_classes: Array, seed_value: int) -> Dictionary:
	GameManager.new_game()
	var mission := ContentDB.get_mission(mission_id)
	var g := IsometricGrid.new()
	var map := ContentDB.get_map(mission.map_id)
	g.load_dict(map, ContentDB.terrain)
	var units: Array[Node] = []
	var spawns: Array = map["spawns"]["player"]
	var i := 0
	for c: CharacterData in GameManager.get_party_members():
		if i < party_classes.size():
			c.class_id = party_classes[i]
		_spawn(g, c, Unit.Team.PLAYER, Vector2i(spawns[i][0], spawns[i][1]), 6, units)
		i += 1
	for e: Dictionary in mission.enemies:
		_spawn(g, ContentDB.get_character(e["character_id"]), Unit.Team.ENEMY, Vector2i(e["cell"][0], e["cell"][1]), int(e.get("level", 1)), units)
	CombatManager.animate = false
	CombatManager.autobattle = true
	CombatManager.start_battle(g, units, mission, null, seed_value)
	var result := {"victory": CombatManager.victory, "turns": CombatManager.turn_number, "ended": CombatManager.state == CombatManager.State.ENDED, "units": CombatManager.units.size()}
	for u in CombatManager.units:
		if is_instance_valid(u):
			u.queue_free()
	CombatManager.stop_battle()
	await process_frame
	return result


func test_battles() -> void:
	var rosters := [
		["chrome_warrior", "laser_archer", "blackcode_mage", "chrome_warrior", "whitelight_medic"],
		["droid_master", "digimancer", "chrono_stitcher", "cartographer", "vector_knight"],
		["bluescreen_mage", "echo_mime", "deck_stacker", "holo_summoner", "stim_chemist"],
		["neon_ninja", "void_knight", "timeslip_mage", "grid_geomancer", "synth_bard"],
		["redline_mage", "scrap_tinker", "jumpjet_dragoon", "holo_dancer", "plasma_vanguard"],
		["ghost_assassin", "cyber_sniper", "static_oracle", "void_technician", "stim_berserker"],
	]
	var wins := 0
	var total := 0
	for m in ["m01_the_brew_plan", "m02_shift_change"]:
		for r in rosters.size():
			for s in 3:
				var res := await _run_battle(m, rosters[r], 100 + r * 10 + s)
				total += 1
				check(res["ended"], "%s roster %d seed %d ended (turns %d)" % [m, r, s, res["turns"]])
				check(res["turns"] < CombatManager.MAX_TURNS, "%s roster %d finished before turn cap" % [m, r])
				if res["victory"]:
					wins += 1
				print("  %s roster %d seed %d: %s in %d turns" % [m, r, s, "WIN " if res["victory"] else "loss", res["turns"]])
	print("AI-vs-AI battles: player side won %d / %d" % [wins, total])
