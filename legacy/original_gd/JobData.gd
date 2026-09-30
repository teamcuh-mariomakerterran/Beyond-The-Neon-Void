extends Resource
class_name JobData

@export_group("Identity")
@export var job_name: String = "New Job"
@export var job_description: String = ""
@export var icon: Texture2D

@export_group("Base Stats")
@export var base_hp: int = 100
@export var base_mp: int = 20
@export var base_attack: int = 10
@export var base_defense: int = 10
@export var base_speed: int = 10
@export var base_crit_rate: float = 0.05

@export_group("Growth Rates")
@export var hp_gain: int = 10
@export var mp_gain: int = 2
@export var attack_gain: int = 2
@export var defense_gain: int = 2
@export var speed_gain: int = 1

@export_group("Job Capabilities")
@export var starting_abilities: Array[Ability] = []
@export var possible_abilities: Array[Ability] = []
@export var movement_type: String = "Walking" # e.g., Walking, Flying, Phasing
@export var base_movement_range: int = 3