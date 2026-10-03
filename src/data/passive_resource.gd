class_name PassiveResource
extends GameResource
## An FFT-style passive for one of the three loadout slots:
##   reaction  fires on its own when something happens to the unit
##   support   a rule change while equipped (AP discounts, damage dealt/taken)
##   movement  how the unit gets around (Move+, Jump+, pass through units…)
## Learned from a class (class_id) and equipped on CharacterData
## reaction_id / support_id / movement_id. Engine: src/combat/passives.gd.

@export var slot: String = "reaction"  # reaction | support | movement
@export var class_id: String = ""
@export var icon_path: String = ""
## What it does. Reactions: counter, nullify_debuff, patch, step_away,
## overwatch, adrenaline. Supports: ap_discount, damage_dealt_mult,
## damage_taken_mult, range_plus. Movement: pass_through, move_heal.
@export var effect: String = ""
## Reaction trigger: on_hit, on_debuff, on_enemy_move, on_crit_taken.
@export var trigger: String = ""
## Reaction chance (0–1).
@export var chance: float = 1.0
## Effect parameters, e.g. {"amount": 1, "kinds": ["MAGIC"]} or {"pct": 0.25}.
@export var params: Dictionary = {}
## Stat changes while equipped, e.g. {"move": 1} / {"defense": 1.1}.
@export var stat_flat: Dictionary = {}
@export var stat_multipliers: Dictionary = {}
## Microchips to learn it at a terminal (needs its class unlocked).
@export var chip_cost: int = 3
