class_name Ability
extends GameResource
## Data-driven ability definition.
##
## Most abilities are fully described by data (range, AoE, power, statuses).
## Exotic mechanics set `special` and use a subclass (KineticAbility,
## TimeAbility, TerrainAbility, CardResource) that overrides _resolve_special().

enum Kind { ATTACK, MAGIC, HEAL, BUFF, DEBUFF, UTILITY, SPECIAL }
enum Target { ENEMY, ALLY, SELF, ANY_UNIT, TILE }
enum Shape { SINGLE, DIAMOND, LINE, CROSS }

@export var icon_path: String = ""
@export var class_id: String = ""
@export var kind: Kind = Kind.ATTACK
@export var target: Target = Target.ENEMY

@export_group("Costs")
@export var ap_cost: int = 1
@export var mp_cost: int = 0
## Percent of the caster's max HP paid to use this (Void Knight darkness).
@export var hp_cost_pct: float = 0.0
## Microchips needed to unlock this ability at a terminal.
@export var chip_cost: int = 0
## Delayed casting (FFT-style): number of clock ticks before it resolves. 0 = instant.
@export var charge_ticks: int = 0
## Class level (in `class_id`) needed before this can be learned at a terminal. 0 = any.
@export var required_class_level: int = 0
## Key item (e.g. a Daemon Caller data disk) that must be in the inventory to learn this.
@export var requires_item_id: String = ""

@export_group("Targeting")
@export var range_min: int = 1
@export var range_max: int = 1
## Basic attacks: use the equipped weapon's range instead of range_max.
@export var uses_weapon_range: bool = false
## Max height difference between caster and target cell.
@export var vertical_tolerance: int = 3
@export var requires_los: bool = false
@export var shape: Shape = Shape.SINGLE
@export var aoe_radius: int = 0
@export var friendly_fire: bool = false

@export_group("Effect")
## Base power; multiplied into the damage / heal formula.
@export var power: float = 1.0
## Derived stat that drives the effect: "attack", "magic", "agility_power".
@export var scaling_stat: String = "attack"
## "physical", "tech", "void", "kinetic", "essence"
@export var damage_type: String = "physical"
@export var accuracy_bonus: float = 0.0
@export var ignores_cover: bool = false
@export var crit_bonus: float = 0.0
@export var status_ids: Array[String] = []
@export var status_chance: float = 1.0
## Key for subclass logic, e.g. "kinetic.gravitational_pull".
@export var special: String = ""
## A Bluescreen Mage hit by this ability learns it.
@export var blue_learnable: bool = false
## Sync Blade "Additions" (Legend of Dragoon-style timed chains). Empty = normal.
## {"beats": [seconds from the first press], "window": 0.13, "per_hit": 0.3,
##  "finisher": 0.8}. Each beat pressed on time adds a strike; a miss ends it.
@export var addition: Dictionary = {}
## Can only be learned by absorbing it (blue magic) — not sold at terminals.
@export var absorb_only: bool = false
## Free-form numbers the special logic can read (pull distance, height delta...).
@export var params: Dictionary = {}

@export_group("Presentation")
@export var vfx_id: String = ""
## Optional PARALLAX close-up played when this ability is used (vars: ATTACKER,
## TARGET, ABILITY, DAMAGE; slot ATTACKER is bound to the caster's name).
@export var cutscene: String = ""
@export var sfx_id: String = ""
@export var flavor_text: String = ""


## Everything an ability needs to resolve, bundled so subclasses stay decoupled.
class Context extends RefCounted:
	var caster: Node
	var target_cell: Vector2i
	var extra_cells: Array[Vector2i] = []
	var grid: IsometricGrid
	var battle: Node  # CombatManager
	var rng: RandomNumberGenerator
	var results: Array[Dictionary] = []
	## Damage multiplier from an Addition chain (1.0 = untouched).
	var power_mult: float = 1.0
	## Additions always connect; the chain decides how hard.
	var force_hit: bool = false

	func log_result(unit: Node, kind: String, amount: int = 0, crit: bool = false) -> void:
		results.append({"unit": unit, "kind": kind, "amount": amount, "crit": crit})


func is_offensive() -> bool:
	return kind in [Kind.ATTACK, Kind.MAGIC, Kind.DEBUFF] or target == Target.ENEMY


func is_healing() -> bool:
	return kind == Kind.HEAL


func _valid_corpse(grid: IsometricGrid, cell: Vector2i, caster: Node) -> bool:
	var corpse := grid.get_corpse(cell)
	if corpse == null or grid.get_occupant(cell) != null:
		return false
	if caster == null:
		return true
	# Revive = fallen allies; Reanimate = anyone fallen (echoes of enemies hit hardest).
	return corpse.team == caster.team if special == "revive" else true


func effective_range_max(caster: Node = null) -> int:
	if uses_weapon_range and caster != null:
		return maxi(caster.equipment.weapon_range(), range_max)
	return range_max


## Cells the caster may click as the ability's target.
func get_targetable_cells(grid: IsometricGrid, caster_cell: Vector2i, caster: Node = null) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if target == Target.SELF:
		out.append(caster_cell)
		return out
	var caster_h := grid.get_height(caster_cell)
	var max_r := effective_range_max(caster)
	var needs_los := requires_los or (uses_weapon_range and max_r > 1)
	for cell in grid.cells_in_range(caster_cell, range_min, max_r):
		if absi(grid.get_height(cell) - caster_h) > vertical_tolerance:
			continue
		if needs_los and not grid.has_line_of_sight(caster_cell, cell):
			continue
		if target == Target.TILE and special in ["blink", "summon", "summon_droid"] and (grid.get_occupant(cell) != null or not grid.is_walkable(cell)):
			continue
		if special in ["reanimate", "revive"] and not _valid_corpse(grid, cell, caster):
			continue
		out.append(cell)
	return out


## Cells hit when targeting `target_cell` (AoE footprint).
func get_affected_cells(grid: IsometricGrid, caster_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match shape:
		Shape.SINGLE:
			out.append(target_cell)
		Shape.DIAMOND:
			out = grid.cells_in_range(target_cell, 0, aoe_radius)
		Shape.CROSS:
			out.append(target_cell)
			for dir: Vector2i in IsometricGrid.DIRECTIONS:
				for i in range(1, aoe_radius + 1):
					var c: Vector2i = target_cell + dir * i
					if grid.in_bounds(c):
						out.append(c)
		Shape.LINE:
			var dir := IsometricGrid.cardinal_direction(caster_cell, target_cell)
			var length := maxi(aoe_radius, 1)
			for i in range(1, length + 1):
				var c: Vector2i = caster_cell + dir * i
				if grid.in_bounds(c):
					out.append(c)
	return out


## Whether `unit` should be affected when caught in this ability.
func affects_unit(caster: Node, unit: Node) -> bool:
	if unit == null or not unit.is_alive():
		return false
	match target:
		Target.SELF:
			return unit == caster
		Target.ALLY:
			return unit.team == caster.team
		Target.ENEMY:
			return unit.team != caster.team or friendly_fire
		Target.ANY_UNIT, Target.TILE:
			return friendly_fire or is_healing() == (unit.team == caster.team) or not is_offensive()
	return false


## Main entry point. Applies the default data-driven effect, then any special logic.
func resolve(ctx: Context) -> Array[Dictionary]:
	var caster := ctx.caster
	var cells := get_affected_cells(ctx.grid, caster.cell, ctx.target_cell)
	for cell in cells:
		var unit: Node = ctx.grid.get_occupant(cell)
		if not affects_unit(caster, unit):
			continue
		_apply_to_unit(ctx, unit)
	_resolve_special(ctx)
	return ctx.results


func _apply_to_unit(ctx: Context, unit: Node) -> void:
	var caster := ctx.caster
	if is_healing():
		var amount := DamageCalculator.heal_amount(caster, self)
		unit.heal(amount)
		ctx.log_result(unit, "heal", amount)
	elif kind in [Kind.ATTACK, Kind.MAGIC]:
		var chance := DamageCalculator.hit_chance(caster, unit, self, ctx.grid)
		if not ctx.force_hit and ctx.rng.randf() > chance:
			ctx.log_result(unit, "miss")
			EventBus.unit_missed.emit(unit)
			return
		var crit := ctx.rng.randf() < DamageCalculator.crit_chance(caster, self)
		var dmg := int(round(DamageCalculator.damage(caster, unit, self, ctx.grid, crit) * ctx.power_mult))
		var dealt: int = unit.take_damage(dmg, crit)
		ctx.log_result(unit, "damage", dealt, crit)
	if not status_ids.is_empty():
		for status_id in status_ids:
			if ctx.rng.randf() <= status_chance:
				if unit.apply_status(status_id, caster):
					ctx.log_result(unit, "status:" + status_id)


## Generic specials shared by many classes. Subclasses override for their kits.
##  cleanse      remove debuffs from affected allies
##  restore_mp   restore params.mp MP to affected allies
##  blink        teleport the caster to the target cell (Shadow Step, High-Ground Leap)
##  summon       spawn params.character_id on the target cell for the caster's team
##  steal_coins  pocket params.coins soul coins if the target is an enemy (player only)
func _resolve_special(ctx: Context) -> void:
	match special:
		"cleanse", "restore_mp":
			for cell in get_affected_cells(ctx.grid, ctx.caster.cell, ctx.target_cell):
				var u: Node = ctx.grid.get_occupant(cell)
				if u == null or u.team != ctx.caster.team:
					continue
				if special == "cleanse":
					var bad: Array[String] = []
					for inst in u.statuses:
						if inst.effect.type == StatusEffect.EffectType.DEBUFF:
							bad.append(inst.effect.id)
					u.cleanse(bad)
					ctx.log_result(u, "cleansed", bad.size())
				else:
					u.restore_mp(int(params.get("mp", 20)))
					ctx.log_result(u, "mp", int(params.get("mp", 20)))
		"blink":
			if ctx.grid.get_occupant(ctx.target_cell) == null and ctx.grid.is_walkable(ctx.target_cell):
				ctx.caster.force_move(ctx.target_cell, ctx.battle.animate)
				ctx.log_result(ctx.caster, "blink")
		"summon":
			_summon(ctx, str(params.get("character_id", "")), int(params.get("max_active", 3)))
		"summon_droid":
			_summon(ctx, str(params.get("character_id", "")), int(params.get("max_active", 2)))
		"revive":
			var fallen: Node = ctx.grid.get_corpse(ctx.target_cell)
			if fallen and fallen.team == ctx.caster.team:
				fallen.revive(roundi(fallen.get_stat("max_hp") * float(params.get("hp_pct", 0.3))))
				ctx.battle.readd_unit(fallen)
				ctx.log_result(fallen, "revived")
		"reanimate":
			var body: Node = ctx.grid.get_corpse(ctx.target_cell)
			if body and body.data:
				ctx.grid.remove_corpse(ctx.target_cell)
				var echo: Node = ctx.battle.spawn_unit(body.data.id, ctx.target_cell, ctx.caster.team, body.get_stat("level"), true)
				if echo:
					echo.current_hp = maxi(roundi(echo.get_stat("max_hp") * float(params.get("hp_pct", 0.5))), 1)
					echo.summoner = ctx.caster
					echo.is_echo = true
					echo.apply_status("fading", ctx.caster)
					echo.refresh_stats()
					ctx.log_result(echo, "reanimated")
		"echo":
			var last: Dictionary = ctx.battle.last_action_for(ctx.caster)
			if not last.is_empty():
				var copied: Ability = last["ability"]
				var sub := Context.new()
				sub.caster = ctx.caster
				sub.target_cell = last["cell"]
				sub.grid = ctx.grid
				sub.battle = ctx.battle
				sub.rng = ctx.rng
				copied.resolve(sub)
				ctx.results.append_array(sub.results)
				ctx.log_result(ctx.caster, "echoed:" + copied.id)
		"steal_chip":
			var mark: Node = ctx.grid.get_occupant(ctx.target_cell)
			if mark and mark.team != ctx.caster.team and ctx.caster.team == 0 and ctx.rng.randf() < float(params.get("chance", 0.5)):
				GameManager.add_microchips(1)
				ctx.log_result(mark, "chip_stolen", 1)
		"steal_coins":
			var victim: Node = ctx.grid.get_occupant(ctx.target_cell)
			if victim and victim.team != ctx.caster.team and ctx.caster.team == 0:
				var coins := int(params.get("coins", 40))
				GameManager.add_soul_coins(coins)
				ctx.log_result(victim, "stolen", coins)


func _summon(ctx: Context, character_id: String, max_active: int) -> void:
	if ctx.grid.get_occupant(ctx.target_cell) != null:
		return
	var mine := 0
	for u: Node in ctx.battle.get_units():
		if u.summoner == ctx.caster and not u.is_echo:
			mine += 1
	if mine >= max_active:
		EventBus.log_message.emit("Too many active builds.")
		return
	var spawned: Node = ctx.battle.spawn_unit(character_id, ctx.target_cell, ctx.caster.team, ctx.caster.get_stat("level"), true)
	if spawned:
		spawned.summoner = ctx.caster
		ctx.log_result(spawned, "summoned")


## Situational power scaling (e.g. Kinetic Charge). Read by DamageCalculator,
## so forecasts and AI see the same number that will land.
func power_multiplier(_caster: Node) -> float:
	return 1.0
