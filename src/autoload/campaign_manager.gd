extends Node
## CampaignManager — mission flow: what's unlocked, what's done, what's next,
## and the bridge from a finished battle back to the hub.

signal mission_unlocked(mission_id: String)
signal mission_completed(mission_id: String, victory: bool)

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const EXPLORE_SCENE := "res://scenes/world/explore.tscn"
const FORGE_SCENE := "res://scenes/editor/neon_forge.tscn"

var unlocked_missions: Array[String] = ["m01_the_brew_plan"]
var completed_missions: Array[String] = []
var current_mission_id: String = ""
## In-world hours passed (drives dispatch flavour, vendor restocks, news cycle).
var world_clock: int = 0
var last_battle_report: Dictionary = {}
## Where exploration drops the party: {map_id, spawn, at, from_forge}.
var current_explore: Dictionary = {}


func current_mission() -> MissionResource:
	return ContentDB.get_mission(current_mission_id)


func unlock_mission(mission_id: String) -> void:
	if not unlocked_missions.has(mission_id):
		unlocked_missions.append(mission_id)
		mission_unlocked.emit(mission_id)


func is_completed(mission_id: String) -> bool:
	return completed_missions.has(mission_id)


func start_mission(mission_id: String) -> void:
	if ContentDB.get_mission(mission_id) == null:
		push_error("CampaignManager: unknown mission " + mission_id)
		return
	current_mission_id = mission_id
	SceneManager.change_scene(BATTLE_SCENE)


## Walk a world / city / hub / interior map. `spawn` indexes the map's player
## spawns (-1 = first); `at` overrides with an exact cell (Forge "play here").
func explore(map_id: String, spawn: int = -1, at: Vector2i = Vector2i(-1, -1), from_forge: bool = false) -> void:
	if ContentDB.get_map(map_id).is_empty():
		push_error("CampaignManager: unknown map " + map_id)
		return
	current_explore = {"map_id": map_id, "spawn": spawn, "at": at, "from_forge": from_forge or bool(current_explore.get("from_forge", false))}
	SceneManager.change_scene(EXPLORE_SCENE)


func advance_clock(hours: int = 1) -> void:
	world_clock += hours


## Called by CombatManager when a battle ends. Pays out and records progress.
func process_mission_completion(victory: bool, mission: MissionResource, survivors: Array[String]) -> Dictionary:
	var report := {"victory": victory, "mission_id": mission.id if mission else "", "soul_coins": 0, "xp": 0, "items": {}, "microchips": 0, "level_ups": {}}
	if mission and victory:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		report["soul_coins"] = mission.soul_coin_reward
		report["xp"] = mission.xp_reward
		report["microchips"] = mission.microchip_reward
		GameManager.add_soul_coins(mission.soul_coin_reward)
		GameManager.add_microchips(mission.microchip_reward)
		var table := ContentDB.get_loot_table(mission.loot_table_id)
		if table:
			var loot := table.roll(rng)
			report["items"] = loot["items"]
			report["soul_coins"] += int(loot["soul_coins"])
			GameManager.add_soul_coins(int(loot["soul_coins"]))
			for item_id: String in loot["items"]:
				GameManager.give_item(item_id, int(loot["items"][item_id]))
		for id in survivors:
			var c := GameManager.get_character(id)
			if c:
				var lv := ProgressionSystem.add_xp(c, mission.xp_reward)
				ProgressionSystem.add_class_xp(c, roundi(mission.xp_reward * 0.8))
				if lv > 0:
					report["level_ups"][id] = lv
		for flag in mission.story_flags_on_win:
			GameManager.set_story_flag(flag)
		for mid in mission.unlocks_mission_ids:
			unlock_mission(mid)
		if not completed_missions.has(mission.id):
			completed_missions.append(mission.id)
	advance_clock(6)
	last_battle_report = report
	mission_completed.emit(report["mission_id"], victory)
	return report


func return_to_hub() -> void:
	SceneManager.change_scene(HUB_SCENE)


func get_campaign_data() -> Dictionary:
	return {
		"unlocked_missions": unlocked_missions.duplicate(),
		"completed_missions": completed_missions.duplicate(),
		"current_mission_id": current_mission_id,
		"world_clock": world_clock,
	}


func load_campaign_data(data: Dictionary) -> void:
	unlocked_missions.assign(data.get("unlocked_missions", ["m01_the_brew_plan"]))
	completed_missions.assign(data.get("completed_missions", []))
	current_mission_id = str(data.get("current_mission_id", ""))
	world_clock = int(data.get("world_clock", 0))
