extends RefCounted
## Body for replay_check.gd (see header there). Mirrors BattleMap._spawn_units:
## party on spawns.player, enemies with level + statuses, guests as AI allies.

const SUITE_ROSTERS := [
	["chrome_warrior", "laser_archer", "blackcode_mage", "chrome_warrior", "whitelight_medic"],
	["droid_master", "digimancer", "chrono_stitcher", "cartographer", "vector_knight"],
	["bluescreen_mage", "echo_mime", "deck_stacker", "holo_summoner", "stim_chemist"],
	["neon_ninja", "void_knight", "timeslip_mage", "grid_geomancer", "synth_bard"],
	["redline_mage", "scrap_tinker", "jumpjet_dragoon", "holo_dancer", "plasma_vanguard"],
	["ghost_assassin", "cyber_sniper", "static_oracle", "void_technician", "stim_berserker"],
]

var tree: SceneTree
var _trace: PackedStringArray = []


func run(p_tree: SceneTree, args: PackedStringArray) -> int:
	tree = p_tree
	var opt := _parse(args)
	var missions: Array = []
	if opt.has("missions"):
		missions = str(opt["missions"]).split(",", false)
	else:
		for m: MissionResource in ContentDB.get_all("missions"):
			missions.append(m.id)
	var seeds := int(opt.get("seeds", "3"))
	var level := int(opt.get("level", "6"))
	var twice := not opt.has("no-twice")
	var rosters: Array = SUITE_ROSTERS if str(opt.get("rosters", "default")) == "suite" else [[]]
	_connect_trace()
	var report := {"runs": [], "nondeterministic": [], "capped": [], "missions": {}}
	var bad := 0
	for mid: String in missions:
		var mission := ContentDB.get_mission(mid)
		if mission == null or ContentDB.get_map(mission.map_id).is_empty():
			printerr("SKIP %s: unknown mission or map" % mid)
			bad += 1
			continue
		var wins := 0
		var total := 0
		var turns_sum := 0
		for r in rosters.size():
			for s in seeds:
				var seed_value := 101 + r * 10 + s
				var a := await _battle(mission, rosters[r], level, seed_value)
				var line := "%s roster %d seed %d: %s in %d turns, hash %s" % [mid, r, seed_value, "WIN " if a["victory"] else "loss", a["turns"], a["hash"].substr(0, 12)]
				if twice:
					var b := await _battle(mission, rosters[r], level, seed_value)
					if b["hash"] != a["hash"] or b["victory"] != a["victory"] or b["turns"] != a["turns"]:
						line += "  <-- REPLAY MISMATCH (second run %s, %d turns, first diff at event %d)" % [b["hash"].substr(0, 12), b["turns"], _first_diff(a["trace"], b["trace"])]
						report["nondeterministic"].append({"mission": mid, "roster": r, "seed": seed_value})
						bad += 1
				if not a["ended"] or a["turns"] >= CombatManager.MAX_TURNS:
					line += "  <-- HIT TURN CAP (stalemate: shielded/unreachable target? AI ignores anchors)"
					report["capped"].append({"mission": mid, "roster": r, "seed": seed_value})
				print("  " + line)
				total += 1
				turns_sum += int(a["turns"])
				wins += 1 if a["victory"] else 0
				report["runs"].append({"mission": mid, "roster": r, "seed": seed_value, "victory": a["victory"], "turns": a["turns"], "hash": a["hash"]})
		report["missions"][mid] = {"wins": wins, "total": total, "avg_turns": float(turns_sum) / maxf(total, 1)}
		print("%s: player side won %d / %d, avg %.0f turns" % [mid, wins, total, float(turns_sum) / maxf(total, 1)])
	if opt.has("json"):
		var f := FileAccess.open(str(opt["json"]), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(report, "  "))
	print("replay_check: %d mismatch(es), %d capped run(s)" % [report["nondeterministic"].size(), report["capped"].size()])
	print("REPLAY " + ("OK" if bad == 0 else "FAIL"))
	return 0 if bad == 0 else 1


func _battle(mission: MissionResource, classes: Array, level: int, seed_value: int) -> Dictionary:
	GameManager.new_game()
	var map := ContentDB.get_map(mission.map_id)
	var g := _battle_grid(map)
	var units: Array[Node] = []
	var spawns: Array = map.get("spawns", {}).get("player", [])
	var i := 0
	for c: CharacterData in GameManager.get_party_members().slice(0, mission.max_party_size):
		if i >= spawns.size():
			break
		if i < classes.size():
			c.class_id = classes[i]
		units.append(_spawn(g, c, Unit.Team.PLAYER, Vector2i(spawns[i][0], spawns[i][1]), level))
		i += 1
	for e: Dictionary in mission.enemies:
		var d := ContentDB.get_character(str(e["character_id"]))
		if d:
			var u := _spawn(g, d, Unit.Team.ENEMY, Vector2i(e["cell"][0], e["cell"][1]), int(e.get("level", 1)))
			for sid: Variant in e.get("statuses", []):
				u.apply_status(str(sid))
			units.append(u)
	for gd: Dictionary in mission.guests:
		var d2 := ContentDB.get_character(str(gd["character_id"]))
		if d2:
			var gu := _spawn(g, d2, Unit.Team.PLAYER, Vector2i(gd["cell"][0], gd["cell"][1]), int(gd.get("level", 1)))
			gu.is_player_controlled = false
			units.append(gu)
	_trace = []
	CombatManager.animate = false
	CombatManager.autobattle = true
	CombatManager.start_battle(g, units, mission, null, seed_value)
	var trace := _trace.duplicate()
	var res := {"victory": CombatManager.victory, "turns": CombatManager.turn_number,
		"ended": CombatManager.state == CombatManager.State.ENDED,
		"hash": "\n".join(trace).sha256_text(), "trace": trace}
	for u in CombatManager.units:
		if is_instance_valid(u):
			u.queue_free()
	CombatManager.stop_battle()
	await tree.process_frame
	return res


func _spawn(g: IsometricGrid, data: CharacterData, team: int, cell: Vector2i, level: int) -> Unit:
	var u := Unit.new()
	u.setup(data, team, level)
	u.grid = g
	u.facing = Vector2i(-1, 0) if team == Unit.Team.ENEMY else Vector2i(1, 0)
	u.place_at(cell)
	tree.root.add_child(u)
	return u


func _uid(u: Node) -> String:
	if not is_instance_valid(u):
		return "?"
	var d: Variant = u.get("data")
	return "%s/%s@%s" % [d.id if d else u.name, str(u.get("team")), str(u.get("cell"))]


func _connect_trace() -> void:
	EventBus.turn_started.connect(func(u: Node) -> void: _trace.append("T " + _uid(u)))
	EventBus.unit_moved.connect(func(u: Node, a: Vector2i, b: Vector2i) -> void: _trace.append("M %s %s>%s" % [_uid(u), a, b]))
	EventBus.unit_damaged.connect(func(u: Node, n: int, crit: bool) -> void: _trace.append("D %s %d %s" % [_uid(u), n, crit]))
	EventBus.unit_healed.connect(func(u: Node, n: int) -> void: _trace.append("H %s %d" % [_uid(u), n]))
	EventBus.unit_missed.connect(func(u: Node) -> void: _trace.append("X " + _uid(u)))
	EventBus.unit_died.connect(func(u: Node) -> void: _trace.append("K " + _uid(u)))
	EventBus.unit_status_applied.connect(func(u: Node, s: String) -> void: _trace.append("S %s %s" % [_uid(u), s]))
	EventBus.ability_used.connect(func(u: Node, a: Resource, c: Vector2i) -> void: _trace.append("A %s %s %s" % [_uid(u), a.get("id") if a else "?", c]))


func _first_diff(a: PackedStringArray, b: PackedStringArray) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return i
	return mini(a.size(), b.size())


func _parse(args: PackedStringArray) -> Dictionary:
	var o := {}
	for a in args:
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			o[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return o


## Build the grid exactly like BattleMap._build_grid: format-2 (World Painter) maps
## must go through WorldMap.to_grid(), or walls/heights/cover are silently lost.
static func _battle_grid(map: Dictionary) -> IsometricGrid:
	var g := IsometricGrid.new()
	if int(map.get("format", 1)) >= 2:
		# Mirror BattleMap._build_grid: copy_from once iso-tactics-grid's fix is applied, else the round trip.
		if g.has_method("copy_from"):
			g.call("copy_from", WorldMap.from_dict(map).to_grid())
		else:
			g.load_dict(WorldMap.from_dict(map).to_grid().to_dict(), ContentDB.terrain)
	else:
		g.load_dict(map, ContentDB.terrain)
	return g
