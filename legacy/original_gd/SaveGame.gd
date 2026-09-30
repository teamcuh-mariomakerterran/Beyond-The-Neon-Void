extends Resource
class_name SaveGame

@export var player_name: String = "Unnamed Hero"
@export var current_level: int = 1
@export var total_experience: int = 0
@export var currency: int = 0

@export var unlocked_missions: Array[String] = []
@export var completed_missions: Array[String] = []
@export var current_hub_location: String = "central_plaza"

@export var inventory_items: Array[String] = []
@export var active_deck_ids: Array[String] = []
@export var equipped_items: Dictionary = {} # unit_id: item_id

func reset():
	player_name = "Unnamed Hero"
	current_level = 1
	total_experience = 0
	currency = 0
	unlocked_missions = ["mission_1"]
	completed_missions = []
	current_hub_location = "central_plaza"
	inventory_items = []
	active_deck_ids = []