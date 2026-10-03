class_name DamageCalculator
extends RefCounted
## All combat math in one place, as pure static functions so the HUD forecast,
## the AI and the actual resolution always agree.
##
## Design: hit chance is random, damage is deterministic (no variance roll).
## Players see exactly what a hit will do; the gamble is only whether it lands.

const CRIT_MULT := 1.5
const HEIGHT_BONUS_PER_LEVEL := 0.10
const HEIGHT_BONUS_MAX := 0.30
const HEIGHT_PENALTY_PER_LEVEL := 0.05
const HEIGHT_PENALTY_MAX := 0.15
const BACK_HIT_BONUS := 0.20
const SIDE_HIT_BONUS := 0.10
const COVER_HIT_PENALTY := [0.0, 0.15, 0.30]
const COVER_DMG_MULT := [1.0, 0.8, 0.6]
const MAGICAL_TYPES := ["tech", "void", "essence", "electric", "plasma", "cryo"]


static func is_magical(ability: Ability) -> bool:
	return ability.damage_type in MAGICAL_TYPES


## "front", "side" or "back" — where the attacker stands relative to the target's facing.
static func attack_angle(attacker_cell: Vector2i, target_cell: Vector2i, target_facing: Vector2i) -> String:
	var rel := attacker_cell - target_cell
	var dot := rel.x * target_facing.x + rel.y * target_facing.y
	if dot > 0:
		return "front"
	if dot < 0:
		return "back"
	return "side"


static func _cover(target: Node, attacker: Node, ability: Ability, grid: IsometricGrid) -> int:
	if grid == null or ability.ignores_cover or is_magical(ability):
		return IsometricGrid.COVER_NONE
	return grid.cover_against(target.cell, attacker.cell)


## Petrified units crack under hits.
const STONE_SHATTER_MULT := 1.5


static func hit_chance(attacker: Node, target: Node, ability: Ability, grid: IsometricGrid) -> float:
	if target.has_method("has_status_tag") and target.has_status_tag("untouchable"):
		return 0.0  # banished: not in this reality right now
	if ability.is_healing() or ability.target in [Ability.Target.ALLY, Ability.Target.SELF]:
		return 1.0
	var chance: float = (attacker.get_stat("accuracy") - target.get_stat("evasion")) / 100.0
	chance += ability.accuracy_bonus
	match attack_angle(attacker.cell, target.cell, target.facing):
		"back": chance += BACK_HIT_BONUS
		"side": chance += SIDE_HIT_BONUS
	chance -= COVER_HIT_PENALTY[_cover(target, attacker, ability, grid)]
	if grid:
		var dh := grid.get_height(attacker.cell) - grid.get_height(target.cell)
		chance += clampf(dh * 0.03, -0.09, 0.09)
	if target.has_method("is_disabled") and target.is_disabled():
		chance = 1.0
	return clampf(chance, 0.05, 0.99)


static func crit_chance(attacker: Node, ability: Ability) -> float:
	return clampf(attacker.get_stat("crit") / 100.0 + ability.crit_bonus, 0.0, 0.75)


static func damage(attacker: Node, target: Node, ability: Ability, grid: IsometricGrid, crit: bool = false) -> int:
	var power_stat := float(attacker.get_stat(ability.scaling_stat))
	var defense := float(target.get_stat("resistance" if is_magical(ability) else "defense"))
	var raw := power_stat * ability.power * ability.power_multiplier(attacker) * 100.0 / (100.0 + defense * 2.0)
	if grid:
		var dh := grid.get_height(attacker.cell) - grid.get_height(target.cell)
		if dh > 0:
			raw *= 1.0 + minf(dh * HEIGHT_BONUS_PER_LEVEL, HEIGHT_BONUS_MAX)
		elif dh < 0:
			raw *= 1.0 - minf(-dh * HEIGHT_PENALTY_PER_LEVEL, HEIGHT_PENALTY_MAX)
	if attack_angle(attacker.cell, target.cell, target.facing) == "back":
		raw *= 1.15
	raw *= COVER_DMG_MULT[_cover(target, attacker, ability, grid)]
	if target.has_method("element_mult"):
		raw *= target.element_mult(ability.damage_type)
	if target.has_method("has_status_tag") and target.has_status_tag("stone"):
		raw *= STONE_SHATTER_MULT
	if crit:
		raw *= CRIT_MULT
	return clampi(roundi(raw), 1, UnitStats.HP_MAX)


static func heal_amount(caster: Node, ability: Ability) -> int:
	var stat := float(caster.get_stat(ability.scaling_stat if ability.scaling_stat != "attack" else "magic"))
	return clampi(roundi(stat * ability.power * 1.2), 1, UnitStats.HP_MAX)


## Preview for the HUD / AI: {"hit": float, "damage": int, "crit": float, "kill": bool}.
static func forecast(attacker: Node, target: Node, ability: Ability, grid: IsometricGrid) -> Dictionary:
	if ability.is_healing():
		return {"hit": 1.0, "damage": -heal_amount(attacker, ability), "crit": 0.0, "kill": false}
	if not ability.kind in [Ability.Kind.ATTACK, Ability.Kind.MAGIC]:
		return {"hit": hit_chance(attacker, target, ability, grid), "damage": 0, "crit": 0.0, "kill": false}
	var dmg := damage(attacker, target, ability, grid)
	return {
		"hit": hit_chance(attacker, target, ability, grid),
		"damage": dmg,
		"crit": crit_chance(attacker, ability),
		"kill": dmg >= target.current_hp,
	}
