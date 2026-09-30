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
	test_quests()
	test_quest_save_roundtrip()
	test_dialog_graph()
	test_dialogue_box()
	test_editor()
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


# --- Quests / NPCs / dialogue ------------------------------------------------

func test_quests() -> void:
	check(ContentDB.validate().is_empty(), "validate() clean with quests + npcs")
	check(ContentDB.get_all("npcs").size() >= 6 and ContentDB.get_all("quests").size() >= 4, "npcs and quests loaded")
	for npc: NPCResource in ContentDB.get_all("npcs"):
		check(npc.dialog.size() >= 3 and npc.eavesdrop_lines.size() >= 3, "npc %s has 3+ dialog nodes and eavesdrops" % npc.id)
	GameManager.new_game()
	var saved_done := CampaignManager.completed_missions.duplicate()
	CampaignManager.completed_missions.clear()
	# Chain: A Friendly Game -> Stack the Deck.
	check(QuestManager.get_state("q_sly_stack_the_deck") == "locked", "chain part 2 starts locked")
	check(QuestManager.available_quests_for("sly").size() == 1, "sly offers one quest at first")
	check(QuestManager.accept("q_sly_friendly_game") == "", "accept quest")
	check(QuestManager.accept("q_sly_friendly_game") != "", "can't accept twice")
	check(not QuestManager.try_complete("q_sly_friendly_game"), "can't turn in unfinished quest")
	QuestManager.notify_talk("drunken_oracle")
	check(QuestManager.is_objective_done("q_sly_friendly_game", 0), "talk_to objective tracked")
	var coins := GameManager.soul_coins
	check(QuestManager.try_complete("q_sly_friendly_game"), "turn in quest")
	check(GameManager.soul_coins == coins + 60 and int(GameManager.cards.get("card_ace_of_sparks", 0)) == 1, "coin + card rewards paid")
	check(QuestManager.get_state("q_sly_friendly_game") == "complete", "quest marked complete")
	check(QuestManager.is_available("q_sly_stack_the_deck"), "next_quest_id becomes available")
	check(QuestManager.accept("q_sly_stack_the_deck") == "", "accept chain part 2")
	var warden := Unit.new()
	warden.data = CharacterData.new()
	warden.data.id = "doctrine_warden"
	EventBus.unit_died.emit(warden)
	EventBus.unit_died.emit(warden)
	warden.free()
	QuestManager.notify_talk("sly")
	check(QuestManager.get_progress("q_sly_stack_the_deck") == [2, 1], "defeat_character + talk_to tracked")
	var rook := GameManager.get_character("rook")
	var before := [rook.get_stats().level, rook.experience]
	check(QuestManager.try_complete("q_sly_stack_the_deck"), "turn in chain part 2")
	check(GameManager.check_story_flag("secret_deck_stacker") and GameManager.cards.has("card_joker_static"), "chain rewards flag + joker")
	check([rook.get_stats().level, rook.experience] != before, "quest XP reaches the party")
	# collect_item consumes on turn-in.
	check(QuestManager.accept("q_hic_spare_parts") == "", "accept collect quest")
	GameManager.give_item("mat_scrap_wire", 3)
	check(not QuestManager.is_ready_to_complete("q_hic_spare_parts"), "partial collection not ready")
	GameManager.give_item("mat_dead_battery", 2)
	check(QuestManager.get_progress("q_hic_spare_parts") == [3, 1], "collect progress follows inventory")
	var chips := GameManager.microchips
	check(QuestManager.try_complete("q_hic_spare_parts"), "turn in collect quest")
	check(GameManager.get_stack_count("mat_scrap_wire") == 0 and GameManager.get_stack_count("mat_dead_battery") == 1, "collect quest consumes exactly what it asked for")
	check(GameManager.microchips == chips + 1, "microchip reward")
	# complete_mission + find_loot.
	QuestManager.accept("q_otto_the_tab")
	EventBus.battle_ended.emit(false, "m01_the_brew_plan")
	check(not QuestManager.is_objective_done("q_otto_the_tab", 0), "lost battle doesn't count")
	EventBus.battle_ended.emit(true, "m01_the_brew_plan")
	check(QuestManager.is_objective_done("q_otto_the_tab", 0), "won mission counts")
	QuestManager.accept("q_benno_grisks_stash")
	EventBus.loot_discovered.emit("prop_crate_z", "chip_microchip", "")
	check(not QuestManager.is_objective_done("q_benno_grisks_stash", 0), "other loot spot doesn't count")
	EventBus.loot_discovered.emit("prop_crate_b", "chip_microchip", "")
	check(QuestManager.try_complete("q_benno_grisks_stash") and GameManager.check_story_flag("benno_trusts_crew"), "find_loot quest completes")
	CampaignManager.completed_missions.assign(saved_done)
	GameManager.new_game()
	check(QuestManager.get_state("q_sly_friendly_game") == "available", "new_game resets quests")


func test_quest_save_roundtrip() -> void:
	GameManager.new_game()
	QuestManager.accept("q_sly_friendly_game")
	QuestManager.notify_talk("drunken_oracle")
	QuestManager.try_complete("q_sly_friendly_game")
	QuestManager.accept("q_hic_spare_parts")
	GameManager.give_item("mat_scrap_wire", 2)
	check(SaveManager.save_game(7), "save with quests")
	GameManager.new_game()
	check(QuestManager.get_state("q_hic_spare_parts") == "available", "state cleared before load")
	check(SaveManager.load_game(7), "load with quests")
	check(QuestManager.get_state("q_sly_friendly_game") == "complete", "complete quest restored")
	check(QuestManager.get_state("q_hic_spare_parts") == "active" and QuestManager.get_progress("q_hic_spare_parts") == [2, 0], "active quest + progress restored")
	check(QuestManager.is_available("q_sly_stack_the_deck"), "chain unlock restored")
	SaveManager.delete_slot(7)
	QuestManager.load_state_data({})
	check(QuestManager.active_quests().is_empty(), "old saves without quests load clean")
	GameManager.new_game()


func test_dialog_graph() -> void:
	GameManager.new_game()
	var otto := ContentDB.get_npc("otto")
	var g := DialogGraph.new(otto.dialog)
	g.start()
	while not g.has_choices() and not g.is_finished():
		g.advance()
	check(g.current.get("id") == "choice" and not g.visited.has("after_m01"), "requires_flag node skipped")
	GameManager.set_story_flag("m01_done")
	g.start()
	g.advance(); g.advance()
	check(g.current.get("id") == "after_m01", "requires_flag node shown once flag set")
	g.advance()
	g.choose(1)
	check(g.current.get("id") == "water", "choice follows next")
	g.advance()
	check(g.is_finished(), "empty next ends conversation")
	# The Oracle: five right answers in a row unlock her.
	var oracle := ContentDB.get_npc("drunken_oracle")
	var wrong := DialogGraph.new(oracle.dialog)
	wrong.start(); wrong.advance(); wrong.choose(0)
	wrong.choose(1)  # wrong answer to q1
	check(wrong.current.get("id") == "wrong" and GameManager.correct_dialog_streak == 0, "wrong answer ends quiz, resets streak")
	var q := DialogGraph.new(oracle.dialog)
	q.start(); q.advance(); q.choose(0)
	for _i in 5:
		var right := -1
		for ci in q.get_choices().size():
			if q.get_choices()[ci].get("correct", false):
				right = ci
		q.choose(right)
	check(q.current.get("id") == "passed" and GameManager.check_story_flag("oracle_quiz_passed"), "five correct answers reach the end, sets_flag applied")
	check(GameManager.secret_characters_unlocked.has("drunken_oracle") and GameManager.roster.has("drunken_oracle"), "Oracle unlocked via record_hub_visit streak")
	GameManager.new_game()


func test_dialogue_box() -> void:
	GameManager.new_game()
	var box := DialogueBox.new()
	box.free_on_finish = false
	root.add_child(box)
	var ended := [0]
	box.finished.connect(func() -> void: ended[0] += 1)
	box.play_npc(ContentDB.get_npc("vesk"))
	for _i in 20:
		box.advance()  # first press skips typing, second advances
		box.choose(0)
		if ended[0] > 0:
			break
	check(ended[0] == 1 and not box.is_open(), "DialogueBox walks an NPC graph to the end")
	box.say("Otto", "Last call.")
	box.say("Otto", "I lied. It's never last call.")
	for _i in 4:
		box.advance()
	check(ended[0] == 2, "say() queues one-off lines")
	check(DialogueBox.load_texture("res://nope.png") == null and DialogueBox.load_audio("res://nope.ogg") == null, "missing portrait / voice skipped silently")
	box.free()


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


## Neon Forge: every content type must produce a form, and helpers behave.
func test_editor() -> void:
	for bucket: String in ContentDB.CATALOG:
		for res: GameResource in ContentDB.get_all(bucket).slice(0, 3):
			var form := ForgeForm.new()
			form.build_resource(res)
			check(form.get_child_count() > 0, "forge form builds for %s/%s" % [bucket, res.id])
			# Round-trip: form data applied back must not change the resource.
			var before := JSON.stringify(res.to_dict())
			res.apply_dict(form.get_data())
			check(JSON.stringify(res.to_dict()) == before, "form round-trip is lossless for %s/%s" % [bucket, res.id])
			form.free()
	for file in ["vendors", "terrain", "recipes", "rumors"]:
		var d: Dictionary = ContentDB.get(file)
		var key: String = d.keys()[0]
		var f := ForgeForm.new()
		f.build_dict(d[key].duplicate(true), file)
		check(f.get_child_count() > 0, "forge dict form builds for %s" % file)
		f.free()
	check(ForgeStore.slugify("Essence Factory — Floor 2!") == "essence_factory_floor_2", "slugify")
	check(ForgeStore.unique_id("classes", "chrome_warrior") == "chrome_warrior_2", "unique id avoids collisions")
	check(not ForgeStore._clean({"id": "x", "a": "", "b": [], "c": 0}).has("a"), "clean drops empty strings")
