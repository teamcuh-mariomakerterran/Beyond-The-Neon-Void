extends AIBehavior

# The Brute: Moves to the closest enemy and attacks if in range.
func decide_action(unit: Unit, possible_actions: Array) -> Dictionary:
	var target = _find_closest_target(unit)
	if not target:
		return {}

	# If we can attack the target, do it.
	if unit.can_attack(target):
		return {"type": "attack", "target": target}

	# Otherwise, move as close as possible to the target.
	var move_target = _get_best_move_towards(unit, target)
	if move_target:
		return {"type": "move", "target_tile": move_target}

	return {}

func _find_closest_target(unit: Unit) -> Unit:
	var closest_unit = null
	var min_dist = 9999.0
	
	# Assume GameManager tracks all active units
	for other in GameManager.get_all_units():
		if other.team != unit.team and not other.is_dead():
			var dist = unit.global_position.distance_to(other.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_unit = other
				
	return closest_unit

func _get_best_move_towards(unit: Unit, target: Unit) -> Vector2i:
	var reachable = unit.get_reachable_tiles()
	var best_tile = unit.grid_position
	var min_dist = unit.global_position.distance_to(target.global_position)
	
	for tile in reachable:
		var world_pos = IsometricGrid.world_to_screen(tile) # Approximation of distance
		var dist = world_pos.distance_to(target.global_position)
		if dist < min_dist:
			min_dist = dist
			best_tile = tile
			
	return best_tile