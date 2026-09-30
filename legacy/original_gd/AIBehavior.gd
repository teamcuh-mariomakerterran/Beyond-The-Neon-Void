extends Resource
class_name AIBehavior

## Base class for enemy AI archetypes.
## Subclasses implement the specific logic for how an enemy decides to move and attack.

enum AIState { IDLE, MOVING, ATTACKING }

## Called by the Unit to determine the next action based on the current game state.
## Returns a dictionary containing the action type and target data.
func decide_action(unit: Node2D, target_candidates: Array[Node2D]) -> Dictionary:
	# Default behavior: do nothing
	# In subclasses, this will now prioritize targets with low cover if AoE is available
	return {"action": "IDLE", "target": null}

## Logic to determine the ideal position relative to a target.
## Useful for Snipers (stay away) or Brutes (get close).
func get_preferred_distance(target: Node2D) -> float:
	return 1.0 # Default to adjacent

## Returns true if the behavior should prioritize seeking cover.
func prefers_cover() -> bool:
	return false

## Evaluates a potential move tile and returns a score based on the cover value.
## Higher score means the AI is more likely to move there.
func evaluate_cover_value(tile_coords: Vector2, cover_value: float) -> float:
	# AI considers hazards as negative cover value
	var hazard_penalty = 0.0
	if IsometricGrid.is_tile_hazard(tile_coords):
		hazard_penalty = 10.0 # Increased deterrent to avoid hazard tiles
	return cover_value - hazard_penalty

func get_best_tile_for_cover(unit_pos: Vector2, search_radius: int) -> Vector2:
	var best_tile = unit_pos
	var max_score = -100.0
	
	for x in range(-search_radius, search_radius + 1):
		for y in range(-search_radius, search_radius + 1):
			var check_coords = unit_pos + Vector2(x, y)
			var score = evaluate_cover_value(check_coords, IsometricGrid.get_tile_cover(check_coords))
			if score > max_score:
				max_score = score
				best_tile = check_coords
				
	return best_tile

