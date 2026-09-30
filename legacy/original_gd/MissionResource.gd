extends Resource
class_name MissionResource

@export_group("Mission Identity")
@export var mission_name: String = "New Mission"
@export_multiline var description: String = "A brief description of the objective."

@export_group("Combat Parameters")
@export var enemy_types: Array[PackedScene] = []
@export var enemy_count_per_wave: int = 3
@export var wave_count: int = 1
@export var difficulty_modifier: float = 1.0

@export_group("Rewards")
@export var credit_reward: int = 100
@export var xp_reward: int = 250
@export var loot_table_id: String = "basic_loot"

func get_total_reward_text() -> String:
	return "Rewards: %d Credits, %d XP" % [credit_reward, xp_reward]