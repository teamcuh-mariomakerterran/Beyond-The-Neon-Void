extends Node

# SceneManager handles the transition between game states/scenes
# It coordinates with the TransitionLayer singleton for visual fades

var current_scene_path: String = ""

func change_scene(target_scene_path: String, transition_time: float = 1.0) -> void:
	current_scene_path = target_scene_path

	# 1. Trigger Fade Out
	if TransitionLayer.has_method("fade_out"):
		TransitionLayer.fade_out(transition_time / 2.0)

	# Wait for the fade to complete
	await get_tree().create_timer(transition_time / 2.0).timeout

	# 2. Change the actual scene
	get_tree().change_scene_to_file(target_scene_path)

	# Wait for the new scene to be instantiated and ready
	await get_tree().process_frame

	# 3. Trigger Fade In
	if TransitionLayer.has_method("fade_in"):
		TransitionLayer.fade_in(transition_time / 2.0)

func warm_boot_scene(scene_path: String) -> void:
	# Handles transition to a scene while preserving previous state in CampaignManager
	change_scene(scene_path)

func load_game_state() -> void:
	var saved_scene = SaveManager.get_saved_scene_path()
	if saved_scene != "":
		change_scene(saved_scene)
	else:
		change_scene("res://scenes/main_menu.tscn")
)
)
)
