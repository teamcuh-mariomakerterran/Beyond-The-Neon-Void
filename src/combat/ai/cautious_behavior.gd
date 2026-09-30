class_name CautiousBehavior
extends AIBehavior
## The Sniper: keeps its distance, hugs cover and high ground, shoots then falls back.

## Ideal distance from the nearest foe.
@export var ideal_distance: int = 4
## Never willingly end closer than this.
@export var min_distance: int = 2


func _init() -> void:
	aggression = 1.0
	self_preservation = 1.2
	cover_weight = 10.0
	height_weight = 3.0
	preferred_distance = ideal_distance
	distance_weight = 2.0
	hit_and_run = true


func score_position(unit: Node, c: Vector2i, grid: IsometricGrid, foes: Array[Node], friends: Array[Node], threat: Dictionary) -> float:
	preferred_distance = ideal_distance
	var s := super(unit, c, grid, foes, friends, threat)
	if not foes.is_empty() and _nearest_dist(c, foes) < min_distance:
		s -= 20.0
	return s
