extends RefCounted

var tree: SceneTree
var st := {}            # team -> stats dict
var _turn_unit: Node = null
var _turn_t0 := 0
var _turn_actions := 0
var _turn_moves := 0


func run(p_tree: SceneTree, args: PackedStringArray) -> int:
	tree = p_tree
	var o := {}
	for a in args:
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			o[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var missions: Array = str(o["missions"]).split(",", false) if o.has("missions") else []
	if missions.is_empty():
		for m: MissionResource in ContentDB.get_all("missions"):
			missions.append(m.id)
	var seeds := int(o.get("seeds", "3"))
	var level := int(o.get("level", "6"))
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.ability_used.connect(func(u: Node, ab: Resource, _c: Vector2i) -> void:
		if u == _turn_unit:
			_turn_actions += 1
		var s := _team(u)
		s["abilities"][ab.get("id")] = int(s["abilities"].get(ab.get("id"), 0)) + 1)
	# Charged casts: the turn's action is the charge start; ability_used fires later, at resolution.
	EventBus.ability_charging.connect(func(u: Node, _ab: Resource, _c: Vector2i, _t: int) -> void:
		if u == _turn_unit:
			_turn_actions += 1
			_team(u)["charges"] += 1)
	EventBus.unit_moved.connect(func(u: Node, _a: Vector2i, _b: Vector2i) -> void:
		if u == _turn_unit:
			_turn_moves += 1)
	EventBus.unit_healed.connect(func(u: Node, n: int) -> void: _team(u)["healed"] += n)
	var report := {}
	for mid: String in missions:
		var mission := ContentDB.get_mission(mid)
		if mission == null:
			continue
		st = {}
		var wins := 0
		var capped := 0
		for s in seeds:
			var res := await _battle(mission, level, 201 + s)
			wins += 1 if res["victory"] else 0
			capped += 1 if res["capped"] else 0
		print("\n== %s  (player side won %d/%d, %d stalemate(s))" % [mid, wins, seeds, capped])
		var rep := {"wins": wins, "runs": seeds, "capped": capped, "teams": {}}
		for team: int in st:
			var s: Dictionary = st[team]
			var turns := maxi(int(s["turns"]), 1)
			var top: Array = s["abilities"].keys()
			top.sort_custom(func(a, b) -> bool: return s["abilities"][a] > s["abilities"][b])
			var line := {"turns": s["turns"], "actions_per_turn": float(s["actions"]) / turns,
				"ap_unused_per_turn": float(s["ap_left"]) / turns, "idle_pct": 100.0 * s["idle"] / turns,
				"moves_per_turn": float(s["moves"]) / turns, "ms_per_turn": float(s["usec"]) / turns / 1000.0,
				"max_ms": float(s["max_usec"]) / 1000.0, "healed": s["healed"], "charges": s["charges"],
				"top": top.slice(0, 6).map(func(k) -> String: return "%s×%d" % [k, s["abilities"][k]])}
			rep["teams"]["player" if team == 0 else "enemy"] = line
			print("  %-6s turns %4d | actions/turn %.2f | AP unused/turn %.2f | idle %4.1f%% | moves/turn %.2f | %.1f ms/turn (max %.0f) | healed %d | charges %d" % [
				"player" if team == 0 else "enemy", line["turns"], line["actions_per_turn"], line["ap_unused_per_turn"], line["idle_pct"],
				line["moves_per_turn"], line["ms_per_turn"], line["max_ms"], line["healed"], line["charges"]])
			print("         top: %s" % ", ".join(line["top"]))
		report[mid] = rep
	if o.has("json"):
		var f := FileAccess.open(str(o["json"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
	return 0


func _team(u: Node) -> Dictionary:
	var t := int(u.get("team")) if is_instance_valid(u) else 9
	if not st.has(t):
		st[t] = {"turns": 0, "actions": 0, "ap_left": 0, "idle": 0, "moves": 0, "usec": 0, "max_usec": 0, "healed": 0, "charges": 0, "abilities": {}}
	return st[t]


func _on_turn_started(u: Node) -> void:
	_turn_unit = u
	_turn_t0 = Time.get_ticks_usec()
	_turn_actions = 0
	_turn_moves = 0


func _on_turn_ended(u: Node) -> void:
	if u != _turn_unit or not is_instance_valid(u):
		return
	var s := _team(u)
	var dt := Time.get_ticks_usec() - _turn_t0
	s["turns"] += 1
	s["actions"] += _turn_actions
	s["moves"] += _turn_moves
	s["usec"] += dt
	s["max_usec"] = maxi(int(s["max_usec"]), dt)
	if u.is_alive() and not u.is_disabled():
		s["ap_left"] += int(u.current_ap)
		if _turn_actions == 0:
			s["idle"] += 1
	_turn_unit = null


func _battle(mission: MissionResource, level: int, seed_value: int) -> Dictionary:
	GameManager.new_game()
	var map := ContentDB.get_map(mission.map_id)
	var g := _battle_grid(map)
	var units: Array[Node] = []
	var spawns: Array = map.get("spawns", {}).get("player", [])
	var i := 0
	for c: CharacterData in GameManager.get_party_members().slice(0, mission.max_party_size):
		if i >= spawns.size():
			break
		units.append(_spawn(g, c, 0, Vector2i(spawns[i][0], spawns[i][1]), level))
		i += 1
	for e: Dictionary in mission.enemies:
		var d := ContentDB.get_character(str(e["character_id"]))
		if d:
			var u := _spawn(g, d, 1, Vector2i(e["cell"][0], e["cell"][1]), int(e.get("level", 1)))
			for sid: Variant in e.get("statuses", []):
				u.apply_status(str(sid))
			units.append(u)
	CombatManager.animate = false
	CombatManager.autobattle = true
	CombatManager.start_battle(g, units, mission, null, seed_value)
	var res := {"victory": CombatManager.victory, "capped": CombatManager.turn_number >= CombatManager.MAX_TURNS}
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
	u.facing = Vector2i(-1, 0) if team == 1 else Vector2i(1, 0)
	u.place_at(cell)
	tree.root.add_child(u)
	return u


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
