class_name AggressiveBehavior
extends AIBehavior
## The Brute: closes distance, ignores danger, loves a kill.


func _init() -> void:
	aggression = 1.4
	kill_bonus = 60.0
	self_preservation = 0.1
	cover_weight = 2.0
	height_weight = 1.0
	preferred_distance = 1
	distance_weight = 1.5
	hit_and_run = false
