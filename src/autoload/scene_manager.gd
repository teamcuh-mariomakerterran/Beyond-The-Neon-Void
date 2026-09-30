extends Node
## SceneManager — scene changes wrapped in TransitionLayer fades.

signal scene_changed(path: String)

const MAIN_MENU := "res://scenes/main.tscn"

var current_scene_path: String = ""
var _busy: bool = false


func change_scene(target_scene_path: String, transition_time: float = 0.6) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(target_scene_path):
		push_error("SceneManager: scene not found " + target_scene_path)
		return
	_busy = true
	current_scene_path = target_scene_path
	await TransitionLayer.fade_out(transition_time * 0.5)
	get_tree().change_scene_to_file(target_scene_path)
	await get_tree().scene_changed
	await TransitionLayer.fade_in(transition_time * 0.5)
	_busy = false
	scene_changed.emit(target_scene_path)


## Kept from the original API: transition while preserving campaign state.
func warm_boot_scene(scene_path: String) -> void:
	change_scene(scene_path)


func load_game_state() -> void:
	var saved := SaveManager.get_saved_scene_path()
	change_scene(saved if saved != "" and ResourceLoader.exists(saved) else MAIN_MENU)
