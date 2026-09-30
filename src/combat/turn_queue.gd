class_name TurnQueue
extends RefCounted
## FFT-style Charge Time (CT) clock.
##
## Every clock tick each living unit gains CT equal to its speed. A unit at
## CT >= 100 takes a turn. Charged abilities (charge_ticks > 0) count down on the
## same clock and resolve before units that become ready on the same tick.
## After a turn, CT is reduced by 100 (moved + acted), 80 (one of them) or 60
## (neither), then capped at 60 — so waiting gets you back sooner.

const CT_READY := 100
const CT_CARRY_CAP := 60
const MAX_TICKS_PER_ADVANCE := 10000

var units: Array[Node] = []
var pending_casts: Array[Dictionary] = []  # {caster, ability, cell, ticks_left}
var tick_count: int = 0


func add_unit(unit: Node) -> void:
	if not units.has(unit):
		units.append(unit)


func remove_unit(unit: Node) -> void:
	units.erase(unit)
	for i in range(pending_casts.size() - 1, -1, -1):
		if pending_casts[i]["caster"] == unit:
			pending_casts.remove_at(i)


func queue_cast(caster: Node, ability: Ability, cell: Vector2i) -> void:
	pending_casts.append({"caster": caster, "ability": ability, "cell": cell, "ticks_left": ability.charge_ticks})


func cancel_casts_for(unit: Node) -> void:
	for i in range(pending_casts.size() - 1, -1, -1):
		if pending_casts[i]["caster"] == unit:
			pending_casts.remove_at(i)


## Advances the clock to the next event. Returns
## {"type": "cast", "cast": Dictionary} or {"type": "unit", "unit": Node} or {"type": "none"}.
func advance() -> Dictionary:
	for _guard in MAX_TICKS_PER_ADVANCE:
		for i in pending_casts.size():
			if pending_casts[i]["ticks_left"] <= 0:
				var cast: Dictionary = pending_casts[i]
				pending_casts.remove_at(i)
				return {"type": "cast", "cast": cast}
		var ready := _ready_units()
		if not ready.is_empty():
			return {"type": "unit", "unit": ready[0]}
		if _living_units().is_empty():
			return {"type": "none"}
		_tick()
	return {"type": "none"}


func _living_units() -> Array[Node]:
	var out: Array[Node] = []
	for u in units:
		if is_instance_valid(u) and u.is_alive():
			out.append(u)
	return out


func _ready_units() -> Array[Node]:
	var ready: Array[Node] = []
	for u in _living_units():
		if u.ct >= CT_READY:
			ready.append(u)
	ready.sort_custom(_sort_ready)
	return ready


static func _sort_ready(a: Node, b: Node) -> bool:
	if a.ct != b.ct:
		return a.ct > b.ct
	if a.get_stat("speed") != b.get_stat("speed"):
		return a.get_stat("speed") > b.get_stat("speed")
	return a.team < b.team  # player side wins ties


func _tick() -> void:
	tick_count += 1
	for u in _living_units():
		u.ct += maxi(u.get_stat("speed"), 1)
	for cast in pending_casts:
		cast["ticks_left"] -= 1


static func ct_cost(moved: bool, acted: bool) -> int:
	if moved and acted:
		return 100
	if moved or acted:
		return 80
	return 60


func end_turn(unit: Node, moved: bool, acted: bool) -> void:
	unit.ct = mini(unit.ct - ct_cost(moved, acted), CT_CARRY_CAP)


## Predicts the next `count` turn events without mutating state.
## Returns [{"unit": Node} or {"cast": Dictionary}, ...] for the turn-order strip.
func forecast(count: int, active: Node = null, active_moved: bool = true, active_acted: bool = true) -> Array[Dictionary]:
	var sim_ct := {}
	for u in _living_units():
		sim_ct[u] = u.ct
	if active and sim_ct.has(active):
		sim_ct[active] = mini(sim_ct[active] - ct_cost(active_moved, active_acted), CT_CARRY_CAP)
	var sim_casts := []
	for c in pending_casts:
		sim_casts.append({"cast": c, "ticks_left": c["ticks_left"]})
	var out: Array[Dictionary] = []
	var guard := 0
	while out.size() < count and guard < MAX_TICKS_PER_ADVANCE and not sim_ct.is_empty():
		guard += 1
		var resolved := false
		for sc in sim_casts:
			if sc["ticks_left"] <= 0 and not sc.has("done"):
				sc["done"] = true
				out.append({"cast": sc["cast"]})
				resolved = true
				break
		if resolved:
			continue
		var ready: Array[Node] = []
		for u: Node in sim_ct:
			if sim_ct[u] >= CT_READY:
				ready.append(u)
		if not ready.is_empty():
			ready.sort_custom(func(a: Node, b: Node) -> bool: return sim_ct[a] > sim_ct[b] if sim_ct[a] != sim_ct[b] else a.get_stat("speed") > b.get_stat("speed"))
			var u: Node = ready[0]
			out.append({"unit": u})
			sim_ct[u] = mini(sim_ct[u] - 100, CT_CARRY_CAP)
			continue
		for u: Node in sim_ct:
			sim_ct[u] += maxi(u.get_stat("speed"), 1)
		for sc in sim_casts:
			sc["ticks_left"] -= 1
	return out
