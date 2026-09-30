class_name SupportBehavior
extends AIBehavior
## The Medic: stays with the pack, heals first, pokes when nobody is hurt.


func _init() -> void:
	aggression = 0.6
	heal_weight = 2.5
	status_value = 10.0
	self_preservation = 1.0
	cover_weight = 6.0
	preferred_distance = 3
	distance_weight = 1.0
	ally_cohesion = 1.2
	hit_and_run = true
