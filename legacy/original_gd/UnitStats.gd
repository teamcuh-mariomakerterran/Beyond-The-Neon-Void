extends Resource
class_name UnitStats

# Primary Attributes
@export_group("Primary Attributes")
@export var strength: int = 10
@export var agility: int = 10
@export var intelligence: int = 10
@export var vitality: int = 10

@export var current_class: ClassResource

# Bridge to ClassLibrary for stat scaling
var class_res: ClassResource:
	get:
		return current_class if current_class else ClassLibrary.get_default_class()
	set(value):
		current_class = value

# Base values for scaling
var base_attack: int = 10
var base_defense: int = 5

# Derived Stats
@export_group("Derived Stats")
@export var max_hp: int = 100
@export var max_mp: int = 20

# Helper functions to calculate effective combat values
func get_attack_power() -> int:
	return int(base_attack * (class_res.attack_multiplier if class_res else 1.0))

func get_defense_power() -> int:
	return int(base_defense * (class_res.defense_multiplier if class_res else 1.0))

func update_stats_from_class(new_class: ClassResource):
	class_res = new_class
	# Trigger signal or update UI
	emit_signal("stats_updated")



func get_defense_power() -> int:
	# Example: Defense is primarily tied to Vitality
	return vitality

func get_accuracy() -> float:
	# Base accuracy + agility bonus
	return 0.9 + (agility * 0.01)

func get_evasion() -> float:
	# Agility determines the chance to dodge
	return 0.05 + (agility * 0.005)

# Method to easily clone stats for individual units to avoid shared Resource mutation
func duplicate_stats() -> UnitStats:
	var new_stats = UnitStats.new()
	new_stats.strength = strength
	new_stats.agility = agility
	new_stats.intelligence = intelligence
	new_stats.vitality = vitality
	new_stats.max_hp = max_hp
	new_stats.max_mp = max_mp
	return new_stats
