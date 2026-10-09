class_name NPCResource
extends GameResource
## A regular at the Neon Gutter (or elsewhere): talks, gossips, gives quests,
## maybe sells things, maybe fights you late game.
##
## Dialog is a small graph of dictionaries (see DialogGraph for the walk):
##   {"id", "text", "speaker"?, "voice_path"?, "requires_flag"?, "sets_flag"?,
##    "next"?, "choices"?: [{"text", "next", "correct"?, "sets_flag"?}]}
## A node whose requires_flag isn't set is skipped (its "next" is followed).

## Optional CharacterData id for battle stats (fight the shopkeeper, recruitable).
@export var character_id: String = ""
@export var portrait_path: String = ""
@export var sprite_path: String = ""
@export var location_id: String = "neon_gutter"

@export_group("Vendor")
@export var is_vendor: bool = false
## Key into data/vendors.json.
@export var vendor_id: String = ""
## Late-game "fight the shopkeeper" mission (may be empty).
@export var fight_mission_id: String = ""

@export_group("Talk")
@export var dialog: Array[Dictionary] = []
## Overheard lines: {"text", "voice_path"?, "requires_flag"?}
@export var eavesdrop_lines: Array[Dictionary] = []
@export var quest_ids: Array[String] = []
## The NPC only shows up once this story flag is set (empty = always).
@export var required_flag: String = ""

@export_group("Interaction stages")
## What happens when an interaction anchor (or E in explore) hooks this NPC.
## Runtime: src/world/npc_stages.gd. First talk: intro → gift → after_talk →
## closing. Later talks: after_talk again, or the repeat lines once nothing
## else is left to do.
## First meeting (empty = the dialog graph above).
@export var intro_lines: Array[String] = []
## Said on later visits when nothing else is attached / left (cycles).
@export var repeat_lines: Array[String] = []
## Handed over once, right after the first talk.
@export var give_item_id: String = ""
@export var give_item_qty: int = 1
## After the first talk: none | shop | quest | chain | fetch | battle | cutscene.
@export var after_talk: String = "none"
## quest: offered, then turned in here when it's done.
@export var offer_quest_id: String = ""
## chain: the next quest of a chain, offered once every requirement holds.
## Requirements: "flag_name", "quest:<id>" (completed), "mission:<id>"
## (cleared), "item:<id>" or "item:<id>:<qty>" (carried).
@export var chain_quest_id: String = ""
@export var chain_requires: Array[String] = []
## Said while the chain requirements aren't met yet.
@export var chain_locked_lines: Array[String] = []
## fetch: items wanted {item_id: qty}. Hand some in on any visit; each return
## pays the "each" reward, the last one pays the "done" reward.
@export var fetch_items: Dictionary = {}
@export var fetch_reward_coins_each: int = 0
@export var fetch_reward_items_each: Dictionary = {}
@export var fetch_reward_coins_done: int = 0
@export var fetch_reward_chips_done: int = 0
@export var fetch_reward_items_done: Dictionary = {}
## cutscene: played after the talk (res://data/cutscenes/….json).
@export var stage_cutscene: String = ""
## Last words before the box closes (and before a fight / cutscene starts).
@export var closing_lines: Array[String] = []
## Propaganda cracks: new talk once you've found enough evidence (Evidence).
## [{"needs": 2, "evidence": ["id"], "lines": ["..."], "sets_flag": "",
##   "give_item_id": "", "quest_id": ""}]
@export var evidence_talk: Array[Dictionary] = []


func is_present() -> bool:
	return required_flag == "" or GameManager.check_story_flag(required_flag)


func get_dialog_node(node_id: String) -> Dictionary:
	for n: Dictionary in dialog:
		if str(n.get("id", "")) == node_id:
			return n
	return {}


## Eavesdrop lines whose flag gate is met.
func eligible_eavesdrops() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l: Dictionary in eavesdrop_lines:
		var f := str(l.get("requires_flag", ""))
		if f == "" or GameManager.check_story_flag(f):
			out.append(l)
	return out
