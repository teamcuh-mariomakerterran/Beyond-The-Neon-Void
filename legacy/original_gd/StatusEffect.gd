extends Resource
class_name StatusEffect

@export var effect_name: String = "Unknown Effect"
@export var description: String = ""
@export var icon_path: String = ""

enum EffectType {
	BUFF,
	DEBUFF,
	NEUTRAL
}

@export var type: EffectType = EffectType.NEUTRAL

@export_group("Timing")
@export var duration_turns: int = 1
@export var tick_interval: float = 1.0 # For DoT effects
@export var is_permanent: bool = false

@export_group("Modifiers")
@export var stat_affected: String = "" # e.g., "attack", "defense", "ap"
@export var modifier_value: float = 0.0 # Additive or Multiplicative
@export var is_percentage: bool = false

@export_group("Combat Logic")
@export var damage_per_tick: float = 0.0
@export var chance_to_stack: float = 1.0
@export var max_stacks: int = 1

func apply_effect(unit):
	# Logic for initial application of the effect
	pass

func on_tick(unit, delta):
	# Logic for periodic effects (like poison or burn)
	pass

func remove_effect(unit):
	# Logic for cleaning up the effect
	pass