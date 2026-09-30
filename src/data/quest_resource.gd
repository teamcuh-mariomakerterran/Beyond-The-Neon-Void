class_name QuestResource
extends GameResource
## A side job handed out by a regular at the Neon Gutter.
##
## Objectives are plain dictionaries so the Neon Forge editor can build forms
## for them; QuestManager tracks progress by listening to EventBus.

## Objective types understood by QuestManager.
const OBJECTIVE_TYPES: Array[String] = ["complete_mission", "collect_item", "talk_to", "find_loot", "flag", "defeat_character"]

@export_group("Giver & gating")
@export var giver_npc_id: String = ""
## Quests sharing a chain_id are one storyline (display / grouping only).
@export var chain_id: String = ""
@export var prerequisite_quest_ids: Array[String] = []
@export var prerequisite_flags: Array[String] = []
@export var min_chapter: int = 1

@export_group("Objectives")
## [{"type": "collect_item", "target": "mat_scrap_wire", "count": 3, "text": "Bring Hic 3 scrap wire"}, ...]
@export var objectives: Array[Dictionary] = []

@export_group("Rewards")
@export var reward_soul_coins: int = 0
## Given to every active party member.
@export var reward_xp: int = 0
@export var reward_microchips: int = 0
## {item_or_card_id: qty}
@export var reward_items: Dictionary = {}
@export var reward_flags: Array[String] = []
@export var unlocks_mission_ids: Array[String] = []
## Becomes available as soon as this one is turned in.
@export var next_quest_id: String = ""

@export_group("Text")
@export_multiline var accept_text: String = ""
@export_multiline var progress_text: String = ""
@export_multiline var complete_text: String = ""
@export var repeatable: bool = false


func objective_count(index: int) -> int:
	if index < 0 or index >= objectives.size():
		return 0
	return maxi(int(objectives[index].get("count", 1)), 1)


func get_reward_text() -> String:
	var bits: Array[String] = []
	if reward_soul_coins > 0:
		bits.append("◈%d" % reward_soul_coins)
	if reward_xp > 0:
		bits.append("%d XP" % reward_xp)
	if reward_microchips > 0:
		bits.append("⌗%d" % reward_microchips)
	for iid: String in reward_items:
		var item := ContentDB.get_item(iid)
		var card := ContentDB.get_card(iid)
		bits.append("%s x%d" % [item.display_name if item else (card.display_name if card else iid), int(reward_items[iid])])
	return "Rewards: " + (", ".join(bits) if not bits.is_empty() else "gratitude, allegedly")
