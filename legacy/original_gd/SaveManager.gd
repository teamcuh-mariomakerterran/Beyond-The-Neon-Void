extends Node

## SaveManager: Handles persisting and loading game state via SaveGame resources.
## Singleton access to current game
var current_save: SaveGame = null

func save_game():
	if not current_save:
		current_save = SaveGame.new()
	
	# Logic to gather data from GameManager and CampaignManager
	var data = GameManager.get_instance().get_state_data()
	current_save.game_data = data
	
	var result = ResourceSaver.save(current_save, "user://savegame.tres")
	if result == OK:
		print("Game Saved Successfully")

func load_game():
	if ResourceLoader.exists("user://savegame.tres"):
		current_save = ResourceLoader.load("user://savegame.tres")
		GameManager.get_instance().load_state_data(current_save.game_data)
		print("Game Loaded Successfully")
	else:
		print("No save file found")

