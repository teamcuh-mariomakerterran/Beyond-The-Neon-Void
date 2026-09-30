extends Node
## UIManager — thin router between gameplay code and whichever HUD is active.
## Scenes register their HUD; gameplay calls UIManager without caring which
## screen is up (battle HUD, hub HUD, editor).

var active_hud: Node = null


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
	_call("show_dialog", [speaker, text])
	EventBus.dialog_requested.emit(speaker, text)


func open_vendor_menu(vendor_id: String) -> void:
	_call("open_vendor_menu", [vendor_id])


func set_turn_indicator(text: String) -> void:
	_call("set_turn_indicator", [text])
