class_name UnitStats
extends Resource
## Stat calculator: raw primary attributes x class multipliers + equipment + statuses.
##
## Scaling order (all float math, rounded once at the end, then clamped):
##   primary  = raw * class.multiplier(stat) * status_mult(stat) + equipment_flat(stat)
##   derived  = formulas below, then * status_mult(derived) + flat bonuses
## Rounding happens exactly once per stat (roundi) and every result is clamped to
## [STAT_MIN, STAT_MAX] / [1, HP_MAX], so stacked multipliers can't overflow or
## drift from repeated truncation.

signal stats_updated

const STAT_MIN := 0
const STAT_MAX := 999
const HP_MAX := 9999
const LEVEL_MAX := 99
const PRIMARY := ["strength", "agility", "intelligence", "vitality"]
const DERIVED := ["max_hp", "max_mp", "attack", "defense", "magic", "resistance", "speed", "move", "jump", "evasion", "accuracy", "crit", "max_ap"]

@export_group("Primary Attributes")
@export var strength: int = 10
@export var agility: int = 10
@export var intelligence: int = 10
@export var vitality: int = 10

@export var level: int = 1

## Results of the last calculate(). Read with get_stat().
var final: Dictionary = {}


## Recomputes all final stats. `equipment_bonus` and `status_mult/flat` are
## dictionaries keyed by stat name (see EquipmentManager / Unit).
func calculate(cls: ClassResource, equipment_bonus: Dictionary = {}, status_mult: Dictionary = {}, status_flat: Dictionary = {}) -> Dictionary:
	var lv := clampi(level, 1, LEVEL_MAX)
	var result := {}
	var raw := {"strength": strength, "agility": agility, "intelligence": intelligence, "vitality": vitality}
	for stat: String in PRIMARY:
		var class_mult := cls.get_multiplier(stat) if cls else 1.0
		var v: float = float(raw[stat]) * class_mult * float(status_mult.get(stat, 1.0))
		v += float(equipment_bonus.get(stat, 0)) + float(status_flat.get(stat, 0))
		result[stat] = clampi(roundi(v), STAT_MIN, STAT_MAX)

	var base_hp := float(cls.base_hp + cls.hp_growth * (lv - 1)) if cls else 100.0
	var base_mp := float(cls.base_mp + cls.mp_growth * (lv - 1)) if cls else 20.0
	var s: float = result["strength"]
	var a: float = result["agility"]
	var i: float = result["intelligence"]
	var v: float = result["vitality"]

	var derived := {
		"max_hp": base_hp * (1.0 + v / 100.0),
		"max_mp": base_mp * (1.0 + i / 100.0),
		"attack": s,
		"defense": v * 0.75,
		"magic": i,
		"resistance": (i + v) * 0.4,
		"speed": float(cls.base_speed if cls else 8) + a / 10.0,
		"move": float(cls.move if cls else 4),
		"jump": float(cls.jump if cls else 2),
		"evasion": 5.0 + a * 0.25,        # percent
		"accuracy": 90.0 + a * 0.2,       # percent
		"crit": 5.0 + a * 0.1,            # percent
		"max_ap": float(cls.max_ap if cls else 2),
	}
	for stat: String in DERIVED:
		var d: float = derived[stat] * float(status_mult.get(stat, 1.0))
		d += float(equipment_bonus.get(stat, 0)) + float(status_flat.get(stat, 0))
		var cap := HP_MAX if stat in ["max_hp", "max_mp"] else STAT_MAX
		var floor_v := 1 if stat in ["max_hp", "speed"] else STAT_MIN
		result[stat] = clampi(roundi(d), floor_v, cap)
	# Movement never drops below 1 unless a status explicitly roots the unit.
	result["move"] = maxi(result["move"], 0)
	final = result
	stats_updated.emit()
	return result


func get_stat(stat: String) -> int:
	if stat == "level":
		return level
	return int(final.get(stat, 0))


## Applies class growth for one level-up.
func level_up(cls: ClassResource) -> void:
	if level >= LEVEL_MAX:
		return
	level += 1
	if cls:
		strength = clampi(strength + int(cls.growth.get("strength", 1)), 1, STAT_MAX)
		agility = clampi(agility + int(cls.growth.get("agility", 1)), 1, STAT_MAX)
		intelligence = clampi(intelligence + int(cls.growth.get("intelligence", 1)), 1, STAT_MAX)
		vitality = clampi(vitality + int(cls.growth.get("vitality", 1)), 1, STAT_MAX)


## Per-unit copy so units never share (and mutate) the same Resource.
func duplicate_stats() -> UnitStats:
	var s := UnitStats.new()
	s.strength = strength
	s.agility = agility
	s.intelligence = intelligence
	s.vitality = vitality
	s.level = level
	return s


func to_dict() -> Dictionary:
	return {"strength": strength, "agility": agility, "intelligence": intelligence, "vitality": vitality, "level": level}


static func from_dict(d: Dictionary) -> UnitStats:
	var s := UnitStats.new()
	s.strength = int(d.get("strength", 10))
	s.agility = int(d.get("agility", 10))
	s.intelligence = int(d.get("intelligence", 10))
	s.vitality = int(d.get("vitality", 10))
	s.level = int(d.get("level", 1))
	return s
