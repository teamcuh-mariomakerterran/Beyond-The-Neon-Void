extends Node
# ProgressionSystem.gd
# Handles the logic for XP accumulation, leveling up, and stat growth.
# This is typically called by the CampaignManager after a battle.

class_name ProgressionSystem

@export var xp_to_level_base: int = 100
@export var xp_multiplier: float = 1.5 # Increase cost per level
@export var stats_gain_per_level: int = 2 # Amount of stat points given to spend

# Tracks the global currency and experience for the party
var total_credits: int = 0
var party_xp: int = 0
var party_level: int = 1
var unspent_stat_points: int = 0

func _ready() -> void:
	# Initialize state from a save file or CampaignManager if necessary
	pass

## Adds XP to the party and checks for level ups
func add_xp(amount: int) -> int:
	party_xp += amount
	var levels_gained = 0
	
	while party_xp >= get_xp_required_for_next_level():
		party_xp -= get_xp_required_for_next_level()
		party_level += 1
		levels_gained += 1
		unspent_stat_points += stats_gain_per_level
		
	return levels_gained

## Calculates the XP required to reach the next level
## Calculates the XP required to reach the next level
func get_xp_required_for_next_level() -> int:
	return ceil(xp_to_level_base * pow(xp_multiplier, party_level - 1))

## Handles the logic for awarding items and currency from missions
func award_mission_rewards(rewards: Dictionary) -> void:
	if rewards.has("credits"):
		total_credits += rewards["credits"]
	if rewards.has("items"):
		# Items would be added to a global inventory or specific units
		pass