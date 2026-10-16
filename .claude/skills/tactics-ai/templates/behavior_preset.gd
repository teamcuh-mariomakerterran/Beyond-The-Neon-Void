class_name ZealotBehavior  # TEMPLATE: rename (file: src/combat/ai/<name>_behavior.gd)
extends AIBehavior
## The Zealot: one line on who this is and how it should feel to fight.
## Presets only change weights (see references/ai-architecture.md). Override
## score_position / score_action only when a weight can't express the idea, and
## always call super().
## Register it: add a `"zealot": return ZealotBehavior.new()` line to AIBehavior.create(),
## and add "zealot" to forge_form.gd ENUMS "ai_behavior" and "ai" so Forge offers it.
## After adding a class_name file, run `godot --headless --import` once before headless tests.

## Extra knobs are fine; export them so they show in the inspector.
@export var min_distance: int = 0


func _init() -> void:
	aggression = 1.2
	kill_bonus = 50.0
	heal_weight = 1.2
	status_value = 8.0
	self_preservation = 0.4
	cover_weight = 4.0
	height_weight = 2.0
	preferred_distance = 1
	distance_weight = 1.0
	ally_cohesion = 0.0
	hazard_penalty = 15.0
	flank_weight = 4.0
	focus_fire = 0.2
	approach_weight = 3.0
	hit_and_run = false


func score_position(unit: Node, c: Vector2i, grid: IsometricGrid, foes: Array[Node], friends: Array[Node], threat: Dictionary) -> float:
	var s := super(unit, c, grid, foes, friends, threat)
	if min_distance > 0 and not foes.is_empty() and _nearest_dist(c, foes) < min_distance:
		s -= 20.0
	return s
