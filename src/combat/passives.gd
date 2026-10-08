class_name Passives
extends RefCounted
## Reaction / Support / Movement engine (FFT loadout). Data: data/passives.json
## (PassiveResource). Equipped per character: reaction_id, support_id,
## movement_id. Combat calls in here at fixed points; nothing else needs to
## know which passive a unit wears.


static func equipped(unit: Node) -> Array[PassiveResource]:
	var out: Array[PassiveResource] = []
	var d: Variant = unit.get("data") if unit else null
	if d == null:
		return out
	for key: String in ["reaction_id", "support_id", "movement_id"]:
		var id := str(d.get(key)) if d.get(key) != null else ""
		if id != "":
			var p := ContentDB.get_entry("passives", id) as PassiveResource
			if p:
				out.append(p)
	return out


static func find(unit: Node, effect: String) -> PassiveResource:
	for p in equipped(unit):
		if p.effect == effect:
			return p
	return null


## Flat + multiplier stat changes from equipped passives (for refresh_stats).
static func stat_mods(unit: Node) -> Array:
	var flat := {}
	var mult := {}
	for p in equipped(unit):
		for k: Variant in p.stat_flat:
			flat[k] = int(flat.get(k, 0)) + int(p.stat_flat[k])
		for k: Variant in p.stat_multipliers:
			mult[k] = float(mult.get(k, 1.0)) * float(p.stat_multipliers[k])
	return [flat, mult]


# --- Supports ------------------------------------------------------------------

static func ap_cost(unit: Node, ability: Ability) -> int:
	var cost := ability.ap_cost
	var p := find(unit, "ap_discount")
	if p and cost > 1:
		var kinds: Array = p.params.get("kinds", [])
		if kinds.is_empty() or Ability.Kind.keys()[ability.kind] in kinds:
			cost = maxi(cost - int(p.params.get("amount", 1)), 1)
	return cost


static func mp_cost(unit: Node, ability: Ability) -> int:
	var cost := ability.mp_cost
	var p := find(unit, "mp_discount")
	if p and cost > 0:
		var kinds: Array = p.params.get("kinds", [])
		if kinds.is_empty() or Ability.Kind.keys()[ability.kind] in kinds:
			cost = maxi(roundi(cost * (1.0 - float(p.params.get("pct", 0.3)))), 1)
	return cost


static func damage_mult(attacker: Node, target: Node, ability: Ability) -> float:
	var m := 1.0
	var magical := DamageCalculator.is_magical(ability)
	for p in equipped(attacker):
		if p.effect == "damage_dealt_mult":
			if (p.params.get("physical", false) and magical) or (p.params.get("magical", false) and not magical):
				continue
			m *= float(p.params.get("mult", 1.0))
	var t := find(target, "damage_taken_mult")
	if t:
		m *= float(t.params.get("mult", 1.0))
	return m


static func range_plus(caster: Node) -> int:
	var p := find(caster, "range_plus")
	return int(p.params.get("amount", 1)) if p else 0


static func phases(unit: Node) -> bool:
	return find(unit, "pass_through") != null


# --- Reactions -----------------------------------------------------------------

static func _roll(battle: Node, p: PassiveResource) -> bool:
	var rng: RandomNumberGenerator = battle.get("rng") if battle and battle.get("rng") else CombatManager.rng
	return rng.randf() < p.chance


static func _reaction(unit: Node, trigger: String) -> PassiveResource:
	for p in equipped(unit):
		if p.slot == "reaction" and p.trigger == trigger:
			return p
	return null


## Firewall: true if `unit` shrugs off this debuff from `source`.
static func blocks_debuff(unit: Node, source: Node, battle: Node = null) -> bool:
	if source == null or not is_instance_valid(source) or int(source.get("team")) == int(unit.get("team")):
		return false
	var p := _reaction(unit, "on_debuff")
	if p and p.effect == "nullify_debuff" and _roll(battle, p):
		_announce(unit, p)
		return true
	return false


## After an action resolves: each enemy it hurt may react.
static func after_action(battle: Node, attacker: Node, ability: Ability, results: Array, ctx: Ability.Context) -> void:
	if ctx.is_reaction:
		return
	for r: Dictionary in results:
		var target: Node = r["unit"]
		if str(r["kind"]) != "damage" or not is_instance_valid(target) or target == attacker or not target.is_alive():
			continue
		if int(target.get("team")) == int(attacker.get("team")) or target.is_disabled():
			continue
		if bool(r.get("crit", false)):
			var a := _reaction(target, "on_crit_taken")
			if a and a.effect == "adrenaline" and _roll(battle, a):
				target.apply_status(str(a.params.get("status", "haste")), target)
				_announce(target, a)
		var p := _reaction(target, "on_hit")
		if p == null:
			continue
		match p.effect:
			"counter":
				if _roll(battle, p):
					await strike(battle, target, attacker, p)
			"patch":
				var below := float(p.params.get("below", 0.5))
				if not target.has_meta("patched") and float(target.current_hp) / maxf(float(target.get_stat("max_hp")), 1.0) < below:
					target.set_meta("patched", true)
					target.heal(roundi(target.get_stat("max_hp") * float(p.params.get("pct", 0.25))))
					_announce(target, p)
			"step_away":
				if _roll(battle, p):
					step_away(battle, target, attacker, p)


## Counter / overwatch shot: a free basic attack if the foe is in reach.
static func strike(battle: Node, reactor: Node, foe: Node, p: PassiveResource) -> bool:
	if not is_instance_valid(foe) or not foe.is_alive() or not reactor.is_alive():
		return false
	var basic := ContentDB.get_ability("basic_attack")
	var grid: IsometricGrid = battle.get("grid")
	if basic == null or grid == null or not basic.get_targetable_cells(grid, reactor.cell, reactor).has(foe.cell):
		return false
	var ctx := Ability.Context.new()
	ctx.caster = reactor
	ctx.target_cell = foe.cell
	ctx.grid = grid
	ctx.battle = battle
	ctx.rng = battle.get("rng")
	ctx.is_reaction = true
	reactor.face_towards(foe.cell)
	_announce(reactor, p)
	var map: Variant = battle.get("map_node")
	if bool(battle.get("animate")) and map and is_instance_valid(map) and map.has_method("play_ability_fx"):
		await map.play_ability_fx(reactor, basic, foe.cell)
	var res: Array[Dictionary] = reactor.job_handler.execute_ability(basic, ctx)
	for r in res:
		if str(r["kind"]) == "damage":
			EventBus.log_message.emit("%s %s → %s: %d" % [reactor.display_name(), p.display_name, foe.display_name(), r["amount"]])
	return true


## Reroute: slip to the free neighbour farthest from the attacker.
static func step_away(battle: Node, unit: Node, attacker: Node, p: PassiveResource) -> bool:
	var grid: IsometricGrid = battle.get("grid")
	if grid == null:
		return false
	var best: Vector2i = unit.cell
	var best_d := -1
	for n: Vector2i in grid.neighbors(unit.cell):
		if not grid.is_walkable(n) or grid.get_occupant(n) != null:
			continue
		if absi(grid.get_height(n) - grid.get_height(unit.cell)) > unit.get_stat("jump"):
			continue
		var d := absi(n.x - attacker.cell.x) + absi(n.y - attacker.cell.y)
		if d > best_d:
			best_d = d
			best = n
	if best == unit.cell:
		return false
	unit.force_move(best, bool(battle.get("animate")))
	_announce(unit, p)
	return true


## Overwatch + Nanite Stride, after any unit finishes moving.
static func after_move(battle: Node, mover: Node) -> void:
	var heal := find(mover, "move_heal")
	if heal and mover.is_alive():
		mover.heal(maxi(roundi(mover.get_stat("max_hp") * float(heal.params.get("pct", 0.06))), 1))
	for u: Node in battle.get("units"):
		if not is_instance_valid(u) or u == mover or not u.is_alive() or u.is_disabled():
			continue
		if int(u.get("team")) == int(mover.get("team")) or u.get_meta("overwatch_spent", false):
			continue
		var p := _reaction(u, "on_enemy_move")
		if p and p.effect == "overwatch" and _roll(battle, p):
			if await strike(battle, u, mover, p):
				u.set_meta("overwatch_spent", true)  # once per round: reset on its own turn


static func _announce(unit: Node, p: PassiveResource) -> void:
	Cues.fire("reaction." + p.id, {"unit": unit})
	if unit is Node2D and unit.get_parent() and unit.has_method("display_name"):
		EventBus.log_message.emit("%s: %s!" % [unit.display_name(), p.display_name])
