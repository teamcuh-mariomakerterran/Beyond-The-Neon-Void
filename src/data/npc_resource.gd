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
