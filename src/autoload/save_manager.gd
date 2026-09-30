extends Node
## SaveManager — JSON save slots in user://saves.
##
## JSON (not .tres) on purpose: loading a Resource from user:// can execute
## embedded scripts, so a shared save file could run code. JSON can't.

signal game_saved(slot: int)
signal game_loaded(slot: int)

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1
const QUICK_SLOT := 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		save_game(QUICK_SLOT)
	elif event.is_action_pressed("quick_load"):
		if has_save_file(QUICK_SLOT):
			load_game(QUICK_SLOT)
			SceneManager.load_game_state()


func slot_path(slot: int) -> String:
	return SAVE_DIR.path_join("slot_%d.json" % slot)


func has_save_file(slot: int = QUICK_SLOT) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_game(slot: int = QUICK_SLOT) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"game": GameManager.get_state_data(),
		"campaign": CampaignManager.get_campaign_data(),
		"dispatch": DispatchManager.get_state_data(),
		"quests": QuestManager.get_state_data(),
		"scene": SceneManager.current_scene_path,
	}
	var tmp_path := slot_path(slot) + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot open %s (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	var ok := f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if not ok:
		push_error("SaveManager: write failed for slot %d" % slot)
		return false
	# Write-then-rename so a crash mid-save never corrupts the existing slot.
	DirAccess.rename_absolute(tmp_path, slot_path(slot))
	game_saved.emit(slot)
	EventBus.log_message.emit("Game saved.")
	return true


func load_game(slot: int = QUICK_SLOT) -> bool:
	var data := read_slot(slot)
	if data.is_empty():
		return false
	GameManager.load_state_data(data.get("game", {}))
	CampaignManager.load_campaign_data(data.get("campaign", {}))
	DispatchManager.load_state_data(data.get("dispatch", {}))
	QuestManager.load_state_data(data.get("quests", {}))  # older saves: no key -> fresh quest log
	SceneManager.current_scene_path = str(data.get("scene", ""))
	game_loaded.emit(slot)
	return true


func read_slot(slot: int) -> Dictionary:
	if not has_save_file(slot):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(slot_path(slot))) != OK or not json.data is Dictionary:
		push_error("SaveManager: slot %d is corrupt" % slot)
		return {}
	return json.data


func get_saved_scene_path(slot: int = QUICK_SLOT) -> String:
	return str(read_slot(slot).get("scene", ""))


func delete_slot(slot: int) -> void:
	if has_save_file(slot):
		DirAccess.remove_absolute(slot_path(slot))
