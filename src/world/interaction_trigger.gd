class_name InteractionTrigger
extends Node2D
## A searchable / talkable spot: props with hidden loot (FF8/FF9-style — nothing
## marks them, so players learn to check everything), NPC talk points, doors.
##
## Loot is one-shot per save: a story flag "found_<trigger_id>" remembers it.
## Works in battle (an adjacent unit searches it) and in the hub (walk up + E).

signal interacted(trigger_id: String)

@export var trigger_id: String = "default"
@export var interaction_text: String = "Search"
@export var loot_item_id: String = ""
@export var loot_qty: int = 1
## Popup when the loot is found.
@export_multiline var found_text: String = ""
## Popup when there's nothing (or it was already taken).
@export_multiline var empty_text: String = ""
## Optional dialog line for NPC / talk triggers.
@export var speaker: String = ""
@export_multiline var dialog_text: String = ""
## Story flag required before this does anything.
@export var required_flag: String = ""
## Grid cell (battle maps).
var cell: Vector2i = Vector2i(-1, -1)
## Hub: interact radius in pixels.
@export var radius: float = 56.0


func flag_name() -> String:
	return "found_" + trigger_id


func is_looted() -> bool:
	return GameManager.check_story_flag(flag_name())


## Performs the interaction. Returns the text that should pop up.
func interact() -> String:
	interacted.emit(trigger_id)
	if required_flag != "" and not GameManager.check_story_flag(required_flag):
		return empty_text
	if dialog_text != "":
		UIManager.show_dialog(speaker, dialog_text)
	if loot_item_id == "" or is_looted():
		return empty_text if empty_text != "" else "Nothing here."
	GameManager.give_item(loot_item_id, loot_qty)
	GameManager.set_story_flag(flag_name())
	var item := ContentDB.get_item(loot_item_id)
	var name := item.display_name if item else loot_item_id
	var msg := found_text if found_text != "" else "Found %s!" % name
	EventBus.loot_discovered.emit(trigger_id, loot_item_id, msg)
	EventBus.play_sfx.emit("loot_found")
	return "%s\n[ %s x%d ]" % [msg, name, loot_qty]
