extends Node
## DispatchManager — send a party member on an off-screen errand (FFTA2-style).
##
## Real-time timers (unix time), so errands keep running while the game is
## closed. Success is rolled when the timer completes:
##   score  = sum(stat * weight) / sum(weights) + level * 2 + class affinity
##   chance = clamp(0.5 + (score - difficulty) / 100, 0.1, 0.95)
## A failed dispatch still returns the character (with a funny story) and a
## consolation loot roll; success pays soul coins, XP and a full loot roll.

signal assignment_started(assignment: Dictionary)
signal assignment_resolved(assignment: Dictionary, success: bool, rewards: Dictionary)

## {assignment_id: {"mission_id", "character_id", "start": float, "end": float}}
var active: Dictionary = {}
var completed_log: Array[Dictionary] = []
var _check_timer: Timer
var _counter: int = 0
## Test hook: overrides "now" when >= 0.
var debug_now: float = -1.0


func _ready() -> void:
	_check_timer = Timer.new()
	_check_timer.wait_time = 5.0
	_check_timer.autostart = true
	_check_timer.timeout.connect(check_completed)
	add_child(_check_timer)


func now() -> float:
	return debug_now if debug_now >= 0.0 else Time.get_unix_time_from_system()


func success_chance(mission: DispatchMission, character: CharacterData) -> float:
	var stats := character.get_stats()
	var cls := ContentDB.get_class_res(character.class_id)
	stats.calculate(cls)
	var total := 0.0
	var weights := 0.0
	for stat: String in mission.stat_weights:
		var w := float(mission.stat_weights[stat])
		total += stats.get_stat(stat) * w
		weights += w
	var score := (total / weights if weights > 0.0 else 0.0) + stats.level * 2.0
	score += float(mission.class_affinity.get(character.class_id, 0))
	# Last Call's bill: a hangover rides into the next dispatch.
	return clampf(0.5 + (score - mission.difficulty) / 100.0 - Bonds.dispatch_penalty(character.id), 0.1, 0.95)


func can_dispatch(mission_id: String, character_id: String) -> String:
	var m := ContentDB.get_dispatch_mission(mission_id)
	var c := GameManager.get_character(character_id)
	if m == null or c == null:
		return "Unknown mission or character."
	if c.is_dispatched:
		return "%s is already out." % c.display_name
	if c.get_stats().level < m.min_level:
		return "Requires level %d." % m.min_level
	if m.required_flag != "" and not GameManager.check_story_flag(m.required_flag):
		return "Not available yet."
	return ""


func start_dispatch(mission_id: String, character_id: String) -> Dictionary:
	if can_dispatch(mission_id, character_id) != "":
		return {}
	var m := ContentDB.get_dispatch_mission(mission_id)
	var c := GameManager.get_character(character_id)
	_counter += 1
	var a := {
		"id": "d%04d" % _counter,
		"mission_id": mission_id,
		"character_id": character_id,
		"start": now(),
		"end": now() + m.duration_minutes * 60.0,
	}
	active[a["id"]] = a
	c.is_dispatched = true
	GameManager.party_changed.emit()
	assignment_started.emit(a)
	EventBus.dispatch_started.emit(a)
	return a


func time_left(assignment_id: String) -> float:
	var a: Dictionary = active.get(assignment_id, {})
	return maxf(float(a.get("end", 0.0)) - now(), 0.0) if not a.is_empty() else 0.0


func check_completed() -> void:
	for id: String in active.keys():
		if float(active[id]["end"]) <= now():
			resolve(id)


## Rolls the outcome and pays rewards. Returns the rewards dictionary.
func resolve(assignment_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var a: Dictionary = active.get(assignment_id, {})
	if a.is_empty():
		return {}
	active.erase(assignment_id)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var m := ContentDB.get_dispatch_mission(a["mission_id"])
	var c := GameManager.get_character(a["character_id"])
	if c:
		c.is_dispatched = false
	if m == null or c == null:
		return {}
	var success := rng.randf() < success_chance(m, c)
	GameManager.hungover.erase(c.id)  # the dispatch sweats it out
	var rewards := {"soul_coins": 0, "items": {}, "xp": 0, "text": m.success_text if success else m.failure_text, "rumor": ""}
	var table := ContentDB.get_loot_table(m.loot_table_id)
	if success:
		rewards["soul_coins"] = m.soul_coin_reward
		rewards["xp"] = m.xp_reward
		if table:
			var loot := table.roll(rng, 0.2)
			rewards["items"] = loot["items"]
			rewards["soul_coins"] += int(loot["soul_coins"])
	elif table:
		rewards["items"] = table.roll(rng, 0.0, -maxi(table.rolls - 1, 0))["items"]
	GameManager.add_soul_coins(int(rewards["soul_coins"]))
	for item_id: String in rewards["items"]:
		GameManager.give_item(item_id, int(rewards["items"][item_id]))
	if int(rewards["xp"]) > 0:
		ProgressionSystem.add_xp(c, int(rewards["xp"]))
	if not m.rumor_ids.is_empty():
		var rid: String = m.rumor_ids[rng.randi() % m.rumor_ids.size()]
		rewards["rumor"] = str(ContentDB.rumors.get(rid, {}).get("text", ""))
		if rewards["rumor"] != "":
			EventBus.broadcast_line.emit("rumor", rewards["rumor"])
	var record := a.duplicate()
	record["success"] = success
	record["rewards"] = rewards
	completed_log.append(record)
	GameManager.party_changed.emit()
	assignment_resolved.emit(a, success, rewards)
	EventBus.dispatch_resolved.emit(a, success, rewards)
	return rewards


func get_state_data() -> Dictionary:
	return {"active": active.duplicate(true), "counter": _counter}


func load_state_data(d: Dictionary) -> void:
	active = d.get("active", {})
	_counter = int(d.get("counter", 0))
