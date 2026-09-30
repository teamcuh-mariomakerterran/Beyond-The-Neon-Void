class_name TacticalBehavior
extends AIBehavior
## The Operative: balanced, focuses the wounded, values flanks, cover and height.


func _init() -> void:
	aggression = 1.1
	kill_bonus = 50.0
	self_preservation = 0.6
	cover_weight = 7.0
	height_weight = 2.5
	preferred_distance = 2
	distance_weight = 0.8
	focus_fire = 0.3
	ally_cohesion = 0.3
	hit_and_run = true
