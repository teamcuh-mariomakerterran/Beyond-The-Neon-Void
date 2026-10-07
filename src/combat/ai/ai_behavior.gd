class_name AIBehavior
extends Resource
## Utility-scoring AI with tactical positioning on the IsometricGrid.
##
## For every reachable cell the AI scores the *position* (threat, cover, height,
## preferred range, hazards) and every *action* it could take from there
## (expected damage, kills, healing, statuses). Two plan shapes are compared:
##   A) move -> act   (close in and strike)
##   B) act  -> move  (shoot, then fall back to the safest cell)
## Subclasses only change weights — the brain is shared.

@export_group("Weights")
@export var aggression: float = 1.0
@export var kill_bonus: float = 40.0
@export var heal_weight: float = 1.2
@export var status_value: float = 8.0
@export var self_preservation: float = 0.5
@export var cover_weight: float = 6.0
@export var height_weight: float = 2.0
@export var preferred_distance: int = 1
@export var distance_weight: float = 1.0
@export var ally_cohesion: float = 0.0
@export var hazard_penalty: float = 15.0
## Standing where foes sit behind full cover head-on (no shot at them)
## costs up to this much: units work around walls instead of camping.
@export var flank_weight: float = 4.0
## Bonus per % of the target's HP missing — focus fire on the wounded.
@export var focus_fire: float = 0.15
## How hard to close distance when nothing is in reach this turn.
@export var approach_weight: float = 3.0
## Plan B (act, then move) is allowed.
@export var hit_and_run: bool = true

const MAX_CANDIDATE_CELLS := 80


static func create(kind: String) -> AIBehavior:
	match kind:
		"aggressive": return AggressiveBehavior.new()
		"cautious": return CautiousBehavior.new()
		"tactical": return TacticalBehavior.new()
		"support": return SupportBehavior.new()
	return TacticalBehavior.new()


## Returns {"move_to": Vector2i, "ability": Ability|null, "target_cell": Vector2i,
##          "act_first": bool, "face": Vector2i, "score": float}.
func plan_turn(unit: Node, battle: Node) -> Dictionary:
	var grid: IsometricGrid = battle.grid
	var foes: Array[Node] = battle.get_opponents(unit)
	var friends: Array[Node] = battle.get_allies(unit)
	var threat := build_threat_map(grid, foes)
	var origin: Vector2i = unit.cell

	var moves: Array[Vector2i] = [origin]
	if unit.can_move():
		moves = grid.reachable_cells(origin, unit.get_stat("move"), unit.get_stat("jump"), unit.team, Passives.phases(unit))
		if moves.size() > MAX_CANDIDATE_CELLS:
			moves.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _nearest_dist(a, foes) < _nearest_dist(b, foes))
			moves = moves.slice(0, MAX_CANDIDATE_CELLS)
			if not moves.has(origin):
				moves.append(origin)

	var abilities: Array[Ability] = []
	if unit.can_act():
		for a in unit.get_abilities():
			if unit.can_afford(a) and a.charge_ticks <= 12:
				abilities.append(a)

	var pos_scores := {}
	for c in moves:
		pos_scores[c] = score_position(unit, c, grid, foes, friends, threat)

	var best := {"move_to": origin, "ability": null, "target_cell": origin, "act_first": false, "score": -INF}

	# Plan A: move, then act.
	var acts := {}
	var any_action := false
	for c in moves:
		acts[c] = _best_action_from(unit, c, abilities, grid)
		if acts[c]["ability"] != null and acts[c]["score"] > 1.0 and (acts[c]["ability"] as Ability).is_offensive():
			any_action = true
	# No attack in reach anywhere (buffing friends doesn't count): march toward
	# the enemy instead of idling in cover.
	if not any_action and not foes.is_empty():
		for c in moves:
			pos_scores[c] -= approach_weight * _nearest_dist(c, foes)
	for c in moves:
		var act: Dictionary = acts[c]
		var total: float = pos_scores[c] + act["score"]
		if total > best["score"]:
			best = {"move_to": c, "ability": act["ability"], "target_cell": act["cell"], "act_first": false, "score": total}

	# Plan B: act from here, then retreat to the best position.
	if hit_and_run and unit.can_move() and not abilities.is_empty():
		var act_here := _best_action_from(unit, origin, abilities, grid)
		if act_here["ability"] != null:
			var best_pos := origin
			for c in moves:
				if pos_scores[c] > pos_scores[best_pos]:
					best_pos = c
			var total_b: float = act_here["score"] + pos_scores[best_pos]
			if total_b > best["score"] + 0.01:
				best = {"move_to": best_pos, "ability": act_here["ability"], "target_cell": act_here["cell"], "act_first": true, "score": total_b}

	var face_from: Vector2i = best["move_to"]
	var nearest := _nearest_unit(face_from, foes)
	best["face"] = IsometricGrid.cardinal_direction(face_from, nearest.cell) if nearest else unit.facing
	return best


## Evaluates the best ability + target cell if the unit stood on `from_cell`.
func _best_action_from(unit: Node, from_cell: Vector2i, abilities: Array[Ability], grid: IsometricGrid) -> Dictionary:
	var best := {"ability": null, "cell": from_cell, "score": 0.0}
	if abilities.is_empty():
		return best
	var real_cell: Vector2i = unit.cell
	unit.cell = from_cell  # temporary: forecasts read attacker.cell
	var living: Array[Node] = []
	for u: Node in grid_units(grid):
		if u.is_alive():
			living.append(u)
	for a in abilities:
		for t in a.get_targetable_cells(grid, from_cell, unit):
			if not _any_unit_near(t, a.aoe_radius, living):
				continue
			var s := score_action(unit, a, from_cell, t, grid)
			if s > best["score"]:
				best = {"ability": a, "cell": t, "score": s}
	unit.cell = real_cell
	return best


func score_action(unit: Node, ability: Ability, from_cell: Vector2i, target_cell: Vector2i, grid: IsometricGrid) -> float:
	var score := 0.0
	for c in ability.get_affected_cells(grid, from_cell, target_cell):
		var u: Node = grid.get_occupant(c)
		if c == from_cell and u == null:
			u = unit  # the unit is "virtually" standing here
		if u == null or not u.is_alive():
			continue
		var same_team: bool = u.team == unit.team
		if ability.is_healing():
			if same_team:
				var missing: int = u.get_stat("max_hp") - u.current_hp
				score += minf(DamageCalculator.heal_amount(unit, ability), missing) * heal_weight
			continue
		if not ability.affects_unit(unit, u):
			continue
		var damaging := ability.kind in [Ability.Kind.ATTACK, Ability.Kind.MAGIC]
		if not damaging:
			# Buffs on friends / debuffs on foes are good; the reverse is bad.
			var helpful := same_team != ability.is_offensive()
			var sv := status_value * ability.status_chance * maxi(ability.status_ids.size(), 1)
			if ability.special != "":
				sv += status_value
			if same_team and not ability.status_ids.is_empty() and _already_has_all(u, ability.status_ids):
				sv = 0.0  # don't re-buff
			score += sv if helpful else -sv
			continue
		var f := DamageCalculator.forecast(unit, u, ability, grid)
		var value := float(f["hit"]) * float(f["damage"]) * aggression
		if f["kill"]:
			value += kill_bonus * float(f["hit"])
		var missing_pct := 1.0 - float(u.current_hp) / maxf(u.get_stat("max_hp"), 1)
		value += missing_pct * 100.0 * focus_fire * float(f["hit"])
		if not ability.status_ids.is_empty():
			value += status_value * ability.status_chance * float(f["hit"]) * ability.status_ids.size()
		score += -value * 1.5 if same_team else value
	if ability.special in ["summon", "summon_droid", "reanimate", "revive"]:
		score += status_value * 2.5  # extra bodies on the field are worth a lot
	# Cheap actions are preferred when values tie.
	score -= ability.mp_cost * 0.05 + ability.charge_ticks * 0.3
	return score


func score_position(unit: Node, c: Vector2i, grid: IsometricGrid, foes: Array[Node], friends: Array[Node], threat: Dictionary) -> float:
	var s := 0.0
	var hp := maxf(unit.current_hp, 1)
	s -= self_preservation * float(threat.get(c, 0.0)) / hp * 10.0
	if not foes.is_empty():
		var cover_sum := 0.0
		var h_sum := 0.0
		var walled := 0
		for f in foes:
			cover_sum += grid.cover_against(c, f.cell)
			h_sum += grid.get_height(c) - grid.get_height(f.cell)
			if grid.cover_fraction(f.cell, c) >= 0.999:
				walled += 1
		s += cover_weight * cover_sum / foes.size() * 0.5
		s -= flank_weight * aggression * float(walled) / foes.size()
		s += height_weight * clampf(h_sum / foes.size(), -3.0, 3.0)
		var nd := _nearest_dist(c, foes)
		s -= distance_weight * absi(nd - preferred_distance)
	if ally_cohesion > 0.0 and friends.size() > 1:
		var total := 0
		for f in friends:
			if f != unit:
				total += IsometricGrid.distance(c, f.cell)
		s -= ally_cohesion * float(total) / (friends.size() - 1)
	if grid.get_hazard(c) != "":
		s -= hazard_penalty
	return s


## {cell: summed attack power of foes that could hit that cell next turn}.
func build_threat_map(grid: IsometricGrid, foes: Array[Node]) -> Dictionary:
	var threat := {}
	for f in foes:
		var reach := [f.cell] as Array[Vector2i]
		if f.get_stat("move") > 0:
			reach = grid.reachable_cells(f.cell, f.get_stat("move"), f.get_stat("jump"), f.team)
		var atk_range := maxi(f.equipment.weapon_range(), 1)
		for a: Ability in f.get_abilities():
			if a.kind in [Ability.Kind.ATTACK, Ability.Kind.MAGIC]:
				atk_range = maxi(atk_range, a.effective_range_max(f))
		var power := float(maxi(f.get_stat("attack"), f.get_stat("magic")))
		var marked := {}
		for r in reach:
			for c in grid.cells_in_range(r, 0, atk_range):
				marked[c] = true
		for c: Vector2i in marked:
			threat[c] = float(threat.get(c, 0.0)) + power
	return threat


func grid_units(grid: IsometricGrid) -> Array[Node]:
	var out: Array[Node] = []
	for c in grid.all_cells():
		var u := grid.get_occupant(c)
		if u:
			out.append(u)
	return out


static func _already_has_all(u: Node, ids: Array[String]) -> bool:
	for id in ids:
		if not u.has_status(id):
			return false
	return true


static func _any_unit_near(cell: Vector2i, radius: int, units: Array[Node]) -> bool:
	for u in units:
		if IsometricGrid.distance(cell, u.cell) <= radius:
			return true
	return false


static func _nearest_dist(c: Vector2i, units: Array[Node]) -> int:
	var best := 9999
	for u in units:
		best = mini(best, IsometricGrid.distance(c, u.cell))
	return best


static func _nearest_unit(c: Vector2i, units: Array[Node]) -> Node:
	var best: Node = null
	var best_d := 9999
	for u in units:
		var d := IsometricGrid.distance(c, u.cell)
		if d < best_d:
			best_d = d
			best = u
	return best
