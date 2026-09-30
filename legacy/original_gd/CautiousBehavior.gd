extends AIBehavior

@export var preferred_distance: int = 3
@export var min_distance: int = 2

func decide_action(unit: Unit, target: Unit, grid: IsometricGrid) -> Dictionary:
	var current_dist = grid.get_distance(unit.grid_position, target.grid_position)
	
	# If target is too close, retreat to maintain distance
	if current_dist < min_distance:
		var retreat_tile = grid.get_best_tile_away_from(unit.grid_position, target.grid_position, preferred_distance)
		if retreat_tile:
			return {"action": "move", "target_tile": retreat_tile}
	
	# If in ideal range, attack
	if current_dist <= preferred_distance:
		return {"action": "attack", "target_unit": target}
	
	# Otherwise, close in slightly but not too close
	var approach_tile = grid.get_best_tile_towards(unit.grid_position, target.grid_position, preferred_distance)
	if approach_tile:
		return {"action": "move", "target_tile": approach_tile}
		
	return {"action": "wait"}