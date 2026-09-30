class_name StatusEffect
extends GameResource
## Definition of a buff / debuff / damage-over-time effect.
## Runtime state (remaining turns, stacks) lives in a StatusInstance on the Unit.

enum EffectType { BUFF, DEBUFF, NEUTRAL }

@export var icon_path: String = ""
@export var type: EffectType = EffectType.NEUTRAL

@export_group("Timing")
## Number of the afflicted unit's own turns the effect lasts.
@export var duration_turns: int = 2
@export var is_permanent: bool = false

@export_group("Modifiers")
## Stat multipliers applied while active, e.g. {"defense": 1.25, "speed": 0.8}.
@export var stat_multipliers: Dictionary = {}
## Flat stat changes applied while active, e.g. {"move": -1}.
@export var stat_flat: Dictionary = {}

@export_group("Per-turn")
## Damage applied at the start of the unit's turn (negative heals).
@export var damage_per_turn: int = 0
## Percent of max HP applied per turn (0.05 = 5%).
@export var damage_per_turn_pct: float = 0.0

@export_group("Stacking & control")
@export var max_stacks: int = 1
## If true the unit skips its action (stun, knockdown).
@export var prevents_action: bool = false
## If true the unit cannot move (root, EMP-locked servos).
@export var prevents_move: bool = false
## Damage held and applied when the effect expires (Delay Thread).
@export var deferred_damage_key: String = ""
@export var tags: Array[String] = []


## Mutable per-unit state for an applied StatusEffect.
class StatusInstance extends RefCounted:
	var effect: StatusEffect
	var turns_left: int
	var stacks: int = 1
	var source: Node = null
	## Free-form payload (e.g. deferred damage amount, linked unit).
	var payload: Dictionary = {}

	func _init(p_effect: StatusEffect, p_source: Node = null) -> void:
		effect = p_effect
		turns_left = p_effect.duration_turns
		source = p_source

	func is_expired() -> bool:
		return not effect.is_permanent and turns_left <= 0
