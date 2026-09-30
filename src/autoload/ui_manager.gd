extends Node
## UIManager — thin router between gameplay code and whichever HUD is active.
## Scenes register their HUD; gameplay calls UIManager without caring which
## screen is up (battle HUD, hub HUD, editor).

var active_hud: Node = null
## Fallback dialogue panel for screens whose HUD has no show_dialog().
var _dialogue_box: DialogueBox = null


func register_hud(hud: Node) -> void:
	active_hud = hud


func unregister_hud(hud: Node) -> void:
	if active_hud == hud:
		active_hud = null


func _call(method: String, args: Array = []) -> void:
	if active_hud and is_instance_valid(active_hud) and active_hud.has_method(method):
		active_hud.callv(method, args)


func show_notification(text: String) -> void:
	_call("show_notification", [text])


func show_interaction_prompt(text: String) -> void:
	_call("show_interaction_prompt", [text])


func hide_interaction_prompt() -> void:
	_call("hide_interaction_prompt")


func show_dialog(speaker: String, text: String) -> void:
	if active_hud and is_instance_valid(active_hud) and active_hud.has_method("show_dialog"):
		active_hud.show_dialog(speaker, text)
	else:
		get_dialogue_box().say(speaker, text)
	EventBus.dialog_requested.emit(speaker, text)


## Returns the open DialogueBox, spawning one on the current scene if needed.
func get_dialogue_box() -> DialogueBox:
	if _dialogue_box and is_instance_valid(_dialogue_box) and not _dialogue_box.is_queued_for_deletion():
		return _dialogue_box
	_dialogue_box = DialogueBox.new()
	var host: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	host.add_child(_dialogue_box)
	return _dialogue_box


## Runs an NPC conversation in the shared DialogueBox.
func play_npc_dialog(npc: NPCResource, start_id: String = "") -> DialogueBox:
	var box := get_dialogue_box()
	box.play_npc(npc, start_id)
	return box


func open_vendor_menu(vendor_id: String) -> void:
	_call("open_vendor_menu", [vendor_id])


func set_turn_indicator(text: String) -> void:
	_call("set_turn_indicator", [text])
