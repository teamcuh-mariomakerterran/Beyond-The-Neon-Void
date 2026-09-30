extends Node

# Data structure for units within the campaign
class_name CampaignUnit
@export var unit_name: String = "Unknown"
@export var level: int = 1
@export var current_hp: int = 10
@export var max_hp: int = 10

# Global Campaign State
var party: Array[CampaignUnit] = []
var total_gold: int = 0
var unlocked_missions: Array[String] = ["Starting_Area"]
var world_clock: int = 0

func _ready() -> void:
	# Initialize with some starting data if empty
	if party.is_empty():
		setup_initial_party()

func setup_initial_party() -> void:
	var starter = CampaignUnit.new()
	starter.unit_name = "Recruit"
	party.append(starter)

func add_gold(amount: int) -> void:
	total_gold += amount
	print("CampaignManager: Gained ", amount, " gold. Total: ", total_gold)

func unlock_mission(mission_id: String) -> void:
	if not unlocked_missions.has(mission_id):
		unlocked_missions.append(mission_id)

func advance_clock(hours: int = 1) -> void:
	world_clock += hours

# Save/Load Hooks (Implementation details for SaveManager)
func get_campaign_data() -> Dictionary:
	return {
		"gold": total_gold,
		"clock": world_clock,
		"missions": unlocked_missions
	}

func load_campaign_data(data: Dictionary) -> void:
	total_gold = data.get("gold", 0)
	world_clock = data.get("clock", 0)
	unlocked_missions = data.get("missions", ["Starting_Area"])