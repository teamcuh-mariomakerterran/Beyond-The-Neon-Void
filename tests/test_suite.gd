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
	test_summoner()
	test_asset_intake()
	test_vfx_and_tiles()
	await test_cutscenes()
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
	check(ClassLibrary.get_all_classes().size() == 37, "37 playable classes (got %d)" % ClassLibrary.get_all_classes().size())
	var secret := ClassLibrary.get_all_classes().filter(func(c: ClassResource) -> bool: return c.is_hidden)
	check(secret.size() == 7, "7 secret classes (incl. Sync Blade)")
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


# --- Daemon Caller: summons, class-level + data-disk gates ------------------

func test_summoner() -> void:
	var dc := ContentDB.get_class_res("daemon_caller")
	check(dc != null and dc.playable and dc.innate_ability_ids.size() == 2, "Daemon Caller is a playable class with 2 innate calls")
	var calls: Array[String] = dc.innate_ability_ids + dc.learnable_ability_ids
	check(calls.size() == 8, "Daemon Caller has 8 summons (got %d)" % calls.size())
	var disks := 0
	for aid in calls:
		var a := ContentDB.get_ability(aid)
		check(a != null and a.class_id == "daemon_caller" and a.mp_cost >= 20, "summon %s costs real MP" % aid)
		if a and a.requires_item_id != "":
			disks += 1
			var disk := ContentDB.get_item(a.requires_item_id)
			check(disk != null and disk.category == ItemResource.Category.KEY and disk.teaches_ability_id == aid, "data disk %s is a key item teaching %s" % [a.requires_item_id, aid])
	check(disks == 3, "3 summons are data-disk gated")
	var hidden := 0
	for m: Dictionary in ContentDB.maps.values():
		for p: Variant in m.get("props", []):
			if p is Dictionary and str(p.get("loot_item_id", "")).begins_with("dsk_"):
				hidden += 1
	check(hidden >= 2, "2+ data disks hidden in map props (%d)" % hidden)
	# "Every enemy" calls cover the whole map from the caster's own tile.
	var g := IsometricGrid.new()
	g.setup(14, 14)
	var ember := ContentDB.get_ability("call_ember_exe")
	check(ember.get_affected_cells(g, Vector2i(0, 0), Vector2i(0, 0)).size() == 14 * 14, "EMBER.EXE reaches every cell")
	var nurse := ContentDB.get_ability("call_nurse_bak")
	check(nurse.is_healing() and nurse.special == "cleanse", "NURSE.BAK heals and cleanses")
	var lullaby := ContentDB.get_ability("call_lullaby_scr")
	check(Array(lullaby.status_ids) == ["asleep", "blinded", "poisoned"] and ContentDB.get_status("asleep").prevents_action, "LULLABY.SCR inflicts sleep / blind / poison")
	# Learning gates.
	GameManager.new_game()
	var c := GameManager.get_character("rook")
	GameManager.microchips = 20
	check(ProgressionSystem.learn_ability(c, "call_nurse_bak") == "Class not unlocked.", "class must be unlocked")
	c.class_levels["daemon_caller"] = 1
	check(ProgressionSystem.learn_ability(c, "call_goodboy_dll").begins_with("Needs Daemon Caller level 3"), "class-level gate")
	c.class_levels["daemon_caller"] = 3
	check(ProgressionSystem.learn_ability(c, "call_goodboy_dll") == "" and c.learned_ability_ids.has("call_goodboy_dll"), "learn at class level 3")
	check(ProgressionSystem.learn_ability(c, "call_leviathan_null").contains("LEVIATHAN_NULL"), "data-disk gate names the disk")
	GameManager.give_item("dsk_leviathan_null")
	check(GameManager.get_stack_count("dsk_leviathan_null") == 1, "data disk stacks as a key item")
	check(ProgressionSystem.learn_ability(c, "call_leviathan_null") == "", "disk unlocks the summon")
	GameManager.new_game()


# --- Forge asset intake wizard -------------------------------------------------

const INTAKE_FIXTURE := "user://intake_fixture"
const INTAKE_INDEX := "user://test_asset_index.json"


func test_asset_intake() -> void:
	AssetIndex.path_override = INTAKE_INDEX
	if FileAccess.file_exists(INTAKE_INDEX):
		DirAccess.remove_absolute(INTAKE_INDEX)
	# Ids and sequence names.
	check(AssetIndex.sequence_key("ocean_anim_3") == ["ocean_anim", 3], "sequence key _3")
	check(AssetIndex.sequence_key("river_a_f4") == ["river_a", 4] and AssetIndex.sequence_key("leaf5") == ["leaf", 5], "sequence key _f4 / bare")
	check(AssetIndex.sequence_key("sign").is_empty(), "no number, no sequence")
	check(AssetIndex.unique_id("Neon Crate!") == "neon_crate", "unique_id slugifies")
	check(AssetIndex.unique_id("Chrome Warrior", "classes") == "chrome_warrior_2", "unique_id avoids ContentDB ids")
	check(AssetIndex.unique_id("Rook", "characters") == "rook_2", "unique_id avoids character ids")
	check(AssetIndex.add("neon_crate", {"path": "res://x/neon_crate.png", "type": "prop"}), "index add")
	check(AssetIndex.unique_id("Neon Crate") == "neon_crate_2", "unique_id avoids index ids")
	check(AssetIndex.find_by_path("res://x/neon_crate.png").get("id") == "neon_crate", "find_by_path")
	AssetIndex.add("neon_crate", {"placement": "indoor"})
	check(AssetIndex.get_entry("neon_crate").get("type") == "prop" and AssetIndex.get_entry("neon_crate").get("placement") == "indoor", "index add merges")
	# Fixture files standing in for the user's desktop.
	DirAccess.make_dir_recursive_absolute(INTAKE_FIXTURE)
	var names := ["barrel.png", "spark_1.png", "spark_2.png"]
	var os_files := PackedStringArray()
	for n: String in names:
		var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.2, 1, 0.6, 1))
		img.save_png(INTAKE_FIXTURE.path_join(n))
		os_files.append(ProjectSettings.globalize_path(INTAKE_FIXTURE.path_join(n)))
	var q := ForgeIntake.build_queue(os_files)
	check(q.size() == 2 and not q[0]["sequence"] and q[1]["sequence"] and (q[1]["files"] as Array).size() == 2, "numbered files group into one sequence")
	var intake := ForgeIntake.new()
	var f := ForgeIntake.default_fields(q[0])
	check(intake.commit(q[0], f).has("error"), "type is required")
	f["type"] = "prop"
	f["name"] = "  "
	check(intake.commit(q[0], f).has("error"), "name is required")
	f["name"] = "Zz Intake Test Barrel"
	f["placement"] = "outdoor"
	f["animated"] = true
	f["hframes"] = 2
	f["fps"] = 6
	f["mode"] = "pingpong"
	var rec := intake.commit(q[0], f)
	var barrel := "res://assets/props/outdoor/zz_intake_test_barrel.png"
	check(str(rec.get("path", "")) == barrel and FileAccess.file_exists(barrel), "prop copied into assets/props/outdoor (%s)" % rec.get("path", rec.get("error")))
	check(FileAccess.file_exists(os_files[0]), "original file left in place")
	var entry := AssetIndex.get_entry("zz_intake_test_barrel")
	check(entry.get("type") == "prop" and entry.get("placement") == "outdoor" and entry["anim"]["hframes"] == 2 and entry["anim"]["mode"] == "pingpong", "index entry with placement + anim")
	var f2 := ForgeIntake.default_fields(q[1])
	check(f2["name"] == "Spark" and f2["animated"], "sequence defaults: stem name, animated")
	f2["type"] = "detail"
	f2["name"] = "Zz Intake Test Spark"
	var rec2 := intake.commit(q[1], f2)
	var frames: Array = rec2.get("anim", {}).get("frames", [])
	check(frames.size() == 2 and str(frames[1]) == "res://assets/details/zz_intake_test_spark_2.png" and FileAccess.file_exists(str(frames[1])), "sequence combined into one animated detail")
	var again := ForgeIntake.default_fields(q[0])
	again["type"] = "prop"
	again["placement"] = "outdoor"
	again["name"] = "Zz Intake Test Barrel"
	var rec3 := intake.commit(q[0], again)
	check(str(rec3.get("id", "")) == "zz_intake_test_barrel_2", "second import gets a unique id")
	var bad := ForgeIntake.default_fields(q[0])
	bad["type"] = "character"
	bad["name"] = "Nobody"
	bad["role"] = "playable"
	check(str(intake.commit(q[0], bad).get("error", "")).contains("CLASS"), "playable character needs a class")
	check(ForgeIntake.class_stats("daemon_caller")["intelligence"] == 15, "class stats seed the character sheet")
	check(ForgeIntake.items_for_slot("weapon", "daemon_caller").all(func(i: String) -> bool: return ContentDB.get_item(i).equip_type in ["rod", "codex"]), "loadout weapons filtered by class")
	intake.free()
	# Cleanup: only the files this test made.
	for p: String in [barrel, "res://assets/props/outdoor/zz_intake_test_barrel_2.png", "res://assets/details/zz_intake_test_spark_1.png", "res://assets/details/zz_intake_test_spark_2.png"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	for d in ["res://assets/props/outdoor", "res://assets/details"]:
		if DirAccess.dir_exists_absolute(d) and DirAccess.get_files_at(d).is_empty() and DirAccess.get_directories_at(d).is_empty():
			DirAccess.remove_absolute(d)
	for n: String in names:
		DirAccess.remove_absolute(INTAKE_FIXTURE.path_join(n))
	DirAccess.remove_absolute(INTAKE_FIXTURE)
	DirAccess.remove_absolute(INTAKE_INDEX)
	AssetIndex.path_override = ""


## PARALLAX cutscene player: loading, timing, hit-stops, keys, branches, render.
func test_cutscenes() -> void:
	var doc := CutsceneDoc.load_file("res://data/cutscenes/demo_supply_works.parallax.json")
	check(doc != null and doc.shots.size() == 3, "demo cutscene loads with 3 shots")
	check(doc.warnings.is_empty(), "demo cutscene has no warnings")
	check(doc.textures.size() == 6, "embedded data-URL images decode")
	check(is_equal_approx(doc.total_time(), 4.0 + 2.4 + 0.25 + 3.0), "total time includes hit-stops")
	var impact: Dictionary = doc.shots[1]
	check(is_equal_approx(CutsceneDoc.warp(impact, 1.1), 1.0), "hit-stop freezes content time")
	check(is_equal_approx(CutsceneDoc.warp(impact, 1.5), 1.25), "content time resumes after stop")
	var title: Dictionary = doc.shots[0]["layers"][0]
	check(is_equal_approx(CutsceneDoc.pvf(title, "y", 1.0), 40.0 + (34.0 - 40.0) * CutsceneDoc.ease_fn(0.5, "out")), "keyframe easing matches builder")
	check(doc.subst("{PLACE}") == "VANTABLACK MORROW", "variables substitute")
	# Branching: shot 0 jumps to "Line" when MOOD == grim.
	var bdoc := CutsceneDoc.new()
	bdoc.load_dict({"project": {"name": "b", "w": 320, "h": 180, "vars": {"MOOD": "grim"}, "shots": [
		{"name": "A", "dur": 1, "branch": [{"cond": "MOOD == grim", "to": "C"}], "layers": []},
		{"name": "B", "dur": 1, "layers": []}, {"name": "C", "dur": 1, "layers": []}]}, "assets": []})
	check(Array(bdoc.play_order()) == [0, 2], "branch follows variables")
	bdoc.vars["MOOD"] = "ok"
	check(Array(bdoc.play_order()) == [0, 1, 2], "branch falls through")
	# Engine recipe format (.cutscene.json) normalizes the same way.
	var edoc := CutsceneDoc.new()
	edoc.load_dict({"format": "parallax-cutscene", "name": "e", "width": 240, "height": 160, "fps": 30, "assets": [], "variables": ["SPEAKER"],
		"shots": [{"name": "S", "duration": 1.5, "background": "#000000", "transition_in": {"type": "fade", "dur": 0.2},
			"audio": [{"t": 0.1, "sound": "boom", "volume": 0.5}], "layers": [{"kind": "text", "text": "{SPEAKER}"}]}]})
	check(edoc.w == 240 and is_equal_approx(edoc.total_time(), 1.5), "engine recipe loads")
	check(str(edoc.shots[0]["audio"][0]["key"]) == "boom", "engine audio cues normalize")
	# Headless render smoke test: every frame of the demo renders without errors.
	var cs := CutscenePlayer.new()
	root.add_child(cs)
	cs.start(doc)
	cs.playing = false
	var fired: Array[String] = []
	cs.event_fired.connect(func(n: String, _d: Variant) -> void: fired.append(n))
	var t := 0.0
	while t < doc.total_time():
		cs.render(t)
		t += 1.0 / 30.0
	check(Array(fired) == ["impact"], "shot events fire exactly once")
	cs.queue_free()
	await process_frame


# --- VFX: particle presets, sheet sprites, tile index ------------------------

const TILE_FIXTURE := "user://test_tile_fixture"


func test_vfx_and_tiles() -> void:
	# Shared animation clock.
	var loop := range(6).map(func(i: int) -> int: return SheetSprite.frame_at(i / 4.0 + 0.01, 4, 4.0, "loop"))
	check(Array(loop) == [0, 1, 2, 3, 0, 1], "frame_at loop wraps (%s)" % [loop])
	var pp := range(8).map(func(i: int) -> int: return SheetSprite.frame_at(i / 4.0 + 0.01, 4, 4.0, "pingpong"))
	check(Array(pp) == [0, 1, 2, 3, 2, 1, 0, 1], "frame_at pingpong bounces (%s)" % [pp])
	var once := range(6).map(func(i: int) -> int: return SheetSprite.frame_at(i / 4.0 + 0.01, 4, 4.0, "once"))
	check(Array(once) == [0, 1, 2, 3, 3, 3], "frame_at once holds last frame (%s)" % [once])
	check(SheetSprite.frame_at(0.01, 4, 4.0, "loop", 0.5) == 2, "frame_at phase offsets the clock")
	check(SheetSprite.frame_at(9.0, 1, 4.0, "loop") == 0, "single frame never advances")
	# SheetSprite: frame list and sheet modes.
	var texs: Array[Texture2D] = []
	for i in 4:
		var im := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		im.fill(Color(i / 4.0, 0, 0, 1))
		texs.append(ImageTexture.create_from_image(im))
	var ss := SheetSprite.from_anim(texs, {"fps": 6, "mode": "random_start"})
	check(ss.frame_count() == 4 and ss.frame_texture(2) == texs[2] and ss.mode == "random_start", "SheetSprite from frame list")
	ss.free()
	var sheet := ImageTexture.create_from_image(Image.create(64, 32, false, Image.FORMAT_RGBA8))
	var sh := SheetSprite.from_anim(sheet, {"hframes": 4, "vframes": 2, "fps": 8})
	var at := sh.frame_texture(5) as AtlasTexture
	check(sh.frame_count() == 8 and at != null and at.region == Rect2(16, 16, 16, 16), "SheetSprite sheet frame regions")
	sh.free()
	# Sequence names.
	check(TileIndex.split_number("river_a_f2") == ["river_a", 2], "split _f2 frame suffix")
	check(TileIndex.split_number("water-anim-01") == ["water-anim", 1], "split -01 suffix")
	check(TileIndex.split_number("tile (3)") == ["tile", 3], "split (3) suffix")
	check(TileIndex.split_number("leaf1") == ["leaf", 1], "split bare number")
	check(TileIndex.split_number("frame_7").size() == 2 and TileIndex.split_number("sign").is_empty(), "split edge cases")
	var seq_paths: Array[String] = ["res://x/ocean_2.png", "res://x/ocean_10.png", "res://x/ocean_1.png", "res://x/sign.png"]
	var seqs := TileIndex.collapse_sequences(seq_paths)
	check(seqs.size() == 2 and str(seqs[0]["id"]) == "res://x/ocean" and Array(seqs[0]["frames"]) == ["res://x/ocean_1.png", "res://x/ocean_2.png", "res://x/ocean_10.png"], "collapse sorts frames numerically")
	check(TileIndex.guess_terrain("god_tiles/water/ocean_anim") == "water" and TileIndex.guess_terrain("set/mountain_03") == "rock"
		and TileIndex.guess_terrain("set/grass/grass_01") == "grass" and TileIndex.guess_terrain("misc/lava_flow") == "lava"
		and TileIndex.guess_terrain("x/stone_02") == "concrete", "terrain guessed from names")
	# Fixture tiles on disk.
	_make_tile_fixture()
	var prev := {"water/ocean": {"texture": "stale", "terrain": "lava", "fps": 12, "fit": {"top": 3, "width": 0}}}
	var idx := TileIndex.scan(TILE_FIXTURE, prev)
	var ocean: Dictionary = idx.get("water/ocean", {})
	check(ocean.get("frames", []).size() == 4 and str(ocean["frames"][0]).ends_with("ocean_1.png") and str(ocean["frames"][3]).ends_with("ocean_4.png"), "ocean_1..4 collapse into one animated tile")
	check(ocean.get("group") == "water" and str(ocean.get("texture", "")).ends_with("ocean_1.png"), "animated tile group + texture")
	check(ocean.get("terrain") == "lava" and int(ocean.get("fps", 0)) == 12 and int(ocean["fit"]["top"]) == 3, "rescan keeps user-edited terrain/fps/fit")
	check(idx.has("grass/grass_01") and idx.has("grass/grass_02") and idx.has("grass/grass_03") and not idx.has("grass/grass"), "numbered grass variants stay separate")
	check(idx.get("grass/grass_02", {}).get("frames", [1]).is_empty() and idx["grass/grass_02"]["terrain"] == "grass", "variant entry is static with grass terrain")
	check(idx.get("misc/blink", {}).get("frames", []).size() == 4, "unnamed 4-frame loop with tiny changes is animated")
	check(idx.has("misc/crate_1") and idx.has("misc/crate_4") and not idx.has("misc/crate"), "4 very different images stay variants")
	check(idx.has("misc/sign") and idx.size() == 1 + 3 + 1 + 4 + 1, "scan finds every tile (%d)" % idx.size())
	# Auto-fit.
	var fit_tex := ForgeStore.load_texture(TILE_FIXTURE.path_join("misc/sign.png"))
	check(TileIndex.fit_rect(fit_tex) == Rect2(10, 20, 100, 90), "fit_rect is the opaque bounding box (%s)" % TileIndex.fit_rect(fit_tex))
	# Particles.
	var ids := ParticleFactory.presets().keys()
	check(ids.size() >= 14 and ContentDB.particles.has("fog"), "particle presets load via ContentDB (%d)" % ids.size())
	var diamonds: Array[PackedVector2Array] = []
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var ctr := Vector2((c.x - c.y) * 64, (c.x + c.y) * 32)
		diamonds.append(PackedVector2Array([ctr + Vector2(0, -32), ctr + Vector2(64, 0), ctr + Vector2(0, 32), ctr + Vector2(-64, 0)]))
	for id: String in ids:
		var node := ParticleFactory.make_for_cells(id, diamonds)
		var em := node.get_node_or_null("Emitter") as CPUParticles2D
		check(em != null and em.amount > 0 and em.emission_points.size() > 0 and em.texture != null, "preset %s builds an emitter" % id)
		check(ParticleFactory.preview_icon(id).get_size() == Vector2(32, 32), "preset %s has a palette icon" % id)
		node.free()
	var storm := ParticleFactory.make_for_cells("storm_clouds", diamonds)
	check(storm.get_node_or_null("Lightning") != null, "storm clouds carry a lightning flasher")
	storm.free()
	var big := ParticleFactory.make("rain", Rect2(0, 0, 2000, 1000), 500, 128.0)
	check((big.get_node("Emitter") as CPUParticles2D).amount == ParticleFactory.MAX_AMOUNT, "particle amount capped")
	big.free()


func _make_tile_fixture() -> void:
	_wipe_dir(TILE_FIXTURE)
	for sub in ["water", "grass", "misc"]:
		DirAccess.make_dir_recursive_absolute(TILE_FIXTURE.path_join(sub))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 4:  # ocean: a moving stripe (named, so animated regardless)
		var im := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		im.fill(Color(0.1, 0.3, 0.8, 1))
		im.fill_rect(Rect2i(i * 4, 0, 2, 16), Color(0.8, 0.9, 1, 1))
		im.save_png(TILE_FIXTURE.path_join("water/ocean_%d.png" % (i + 1)))
	for i in 3:  # grass variants: different noise each
		_noise_image(rng, 16).save_png(TILE_FIXTURE.path_join("grass/grass_%02d.png" % (i + 1)))
	for i in 4:  # blink: same art, one pixel changes
		var im := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		im.fill(Color(0.3, 0.3, 0.35, 1))
		im.set_pixel(i, 0, Color(1, 0.2, 0.6, 1))
		im.save_png(TILE_FIXTURE.path_join("misc/blink_%d.png" % (i + 1)))
	for i in 4:  # crates: unrelated art
		_noise_image(rng, 16).save_png(TILE_FIXTURE.path_join("misc/crate_%d.png" % (i + 1)))
	var sign := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	sign.fill_rect(Rect2i(10, 20, 100, 90), Color(1, 0.2, 0.6, 1))
	sign.save_png(TILE_FIXTURE.path_join("misc/sign.png"))


func _noise_image(rng: RandomNumberGenerator, n: int) -> Image:
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			im.set_pixel(x, y, Color(rng.randf(), rng.randf(), rng.randf(), 1))
	return im


func _wipe_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		_wipe_dir(dir.path_join(sub))
		DirAccess.remove_absolute(dir.path_join(sub))
