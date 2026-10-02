extends Node
## CombatManager — orchestrates one battle at a time.
##
## Owns the TurnQueue (CT clock), validates and executes moves/abilities, runs
## AI turns, evaluates win/lose conditions and hands results to CampaignManager.
## Presentation (BattleMap, BattleHUD) only listens to EventBus and calls the
## request_* API — so the same loop runs headless in tests at full speed.

signal player_input_needed(unit: Node)
signal battle_finished(victory: bool)

enum State { IDLE, ADVANCING, PLAYER_INPUT, EXECUTING, AI_TURN, ENDED }

const MAX_TURNS := 600

var state: State = State.IDLE
var grid: IsometricGrid
var map_node: Node2D  # BattleMap (optional; null when headless)
var units: Array[Node] = []
var turn_queue: TurnQueue
var active_unit: Node = null
var mission: MissionResource
var rng := RandomNumberGenerator.new()
## False in headless simulations: no tweens, no delays.
var animate: bool = true
## If true, player-team units are driven by the AI too (autobattle / tests).
var autobattle: bool = false
var turn_number: int = 0
var victory: bool = false
var _player_done: bool = false


# --- Setup -----------------------------------------------------------------

func start_battle(p_grid: IsometricGrid, p_units: Array[Node], p_mission: MissionResource, p_map: Node2D = null, seed_value: int = -1) -> void:
	grid = p_grid
	map_node = p_map
	mission = p_mission
	units = p_units.duplicate()
	turn_queue = TurnQueue.new()
	turn_number = 0
	victory = false
	active_unit = null
	state = State.IDLE
	_player_done = false
	_last_hazard_round = 0
	_last_team_action.clear()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for u in units:
		u.grid = grid
		u.ct = rng.randi_range(0, 30) + u.get_stat("speed")
		turn_queue.add_unit(u)
		if not u.died.is_connected(_on_unit_died.bind(u)):
			u.died.connect(_on_unit_died.bind(u))
	EventBus.battle_started.emit(mission.id if mission else "")
	_battle_loop()


func stop_battle() -> void:
	state = State.ENDED
	units.clear()
	grid = null
	map_node = null


# --- Queries ---------------------------------------------------------------

func get_units() -> Array[Node]:
	return units.filter(func(u: Node) -> bool: return is_instance_valid(u) and u.is_alive())


func get_allies(unit: Node) -> Array[Node]:
	return get_units().filter(func(u: Node) -> bool: return u.team == unit.team)


func get_opponents(unit: Node) -> Array[Node]:
	return get_units().filter(func(u: Node) -> bool: return u.team != unit.team and u.team != Unit.Team.NEUTRAL)


func get_unit_at(cell: Vector2i) -> Node:
	return grid.get_occupant(cell) if grid else null


func move_cells_for(unit: Node) -> Array[Vector2i]:
	if unit == null or not unit.can_move():
		return []
	return grid.reachable_cells(unit.cell, unit.get_stat("move"), unit.get_stat("jump"), unit.team)


func target_cells_for(unit: Node, ability: Ability) -> Array[Vector2i]:
	return ability.get_targetable_cells(grid, unit.cell, unit)


func turn_forecast(count: int = 10) -> Array[Dictionary]:
	if turn_queue == null:
		return []
	var moved: bool = active_unit.has_moved if active_unit else true
	var acted: bool = active_unit.has_acted if active_unit else true
	return turn_queue.forecast(count, active_unit, moved, acted)


func is_player_turn() -> bool:
	return state == State.PLAYER_INPUT


## Spawns a unit mid-battle (summons, reinforcements). Returns the Unit or null.
func spawn_unit(character_id: String, cell: Vector2i, team: int, level: int = 1, ai_driven: bool = false) -> Node:
	var template := ContentDB.get_character(character_id)
	if template == null or grid == null or grid.get_occupant(cell) != null:
		return null
	var u := Unit.new()
	u.setup(template, team, level)
	if ai_driven:
		u.is_player_controlled = false
	u.grid = grid
	if map_node and map_node.has_method("add_unit_node"):
		map_node.add_unit_node(u)
	u.place_at(cell)
	u.ct = 0
	units.append(u)
	turn_queue.add_unit(u)
	u.died.connect(_on_unit_died.bind(u))
	EventBus.turn_order_changed.emit(turn_forecast())
	return u


## Puts a revived unit back on the clock.
func readd_unit(u: Node) -> void:
	if not units.has(u):
		units.append(u)
	turn_queue.add_unit(u)
	EventBus.turn_order_changed.emit(turn_forecast())


## Last ability an ally of `unit` used (Echo Mime copies it). {} if none.
var _last_team_action: Dictionary = {}  # team -> {"ability", "cell", "caster"}


func last_action_for(unit: Node) -> Dictionary:
	var a: Dictionary = _last_team_action.get(unit.team, {})
	if a.is_empty() or a["caster"] == unit or a["ability"].special == "echo":
		return {}
	return a


# --- Main loop -------------------------------------------------------------

func _battle_loop() -> void:
	while state != State.ENDED and turn_number < MAX_TURNS:
		state = State.ADVANCING
		var ev := turn_queue.advance()
		match ev["type"]:
			"none":
				break
			"cast":
				await _resolve_charged_cast(ev["cast"])
			"unit":
				await _run_unit_turn(ev["unit"])
		if _check_battle_end():
			break
		if animate and is_inside_tree():
			await get_tree().process_frame
	if state != State.ENDED:
		_finish(false)


func _run_unit_turn(unit: Node) -> void:
	turn_number += 1
	active_unit = unit
	var stitched: StatusEffect.StatusInstance = unit.get_status("stitched")
	if stitched:
		var ally: Node = stitched.payload.get("linked_ally")
		if is_instance_valid(ally) and ally.is_alive():
			ally.ct += int(stitched.payload.get("ct_gain", 50))
	var start: Dictionary = unit.begin_turn()
	if unit.hud:
		unit.hud.is_active_turn = true
	EventBus.turn_started.emit(unit)
	EventBus.turn_order_changed.emit(turn_forecast())
	if _tick_round_hazards_if_needed():
		pass
	if not start["skip"] and unit.is_alive():
		if unit.is_player_controlled and not autobattle:
			await _player_turn(unit)
		else:
			await _ai_turn(unit)
	if unit.hud and is_instance_valid(unit):
		unit.hud.is_active_turn = false
	if is_instance_valid(unit):
		turn_queue.end_turn(unit, unit.has_moved, unit.has_acted)
		_apply_hazard_on(unit)
	EventBus.turn_ended.emit(unit)
	active_unit = null


var _last_hazard_round: int = 0


## Hazards tick once per "round" (every 10 clock ticks).
func _tick_round_hazards_if_needed() -> bool:
	var round_now := turn_queue.tick_count / 10
	if round_now > _last_hazard_round:
		_last_hazard_round = round_now
		var cleared := grid.tick_hazards()
		if not cleared.is_empty():
			EventBus.grid_changed.emit(cleared)
		EventBus.round_advanced.emit(round_now)
		return true
	return false


func current_round() -> int:
	return turn_queue.tick_count / 10 if turn_queue else 0


func _apply_hazard_on(unit: Node) -> void:
	if not unit.is_alive():
		return
	match grid.get_hazard(unit.cell):
		"neon_fire":
			unit.take_damage(maxi(roundi(unit.get_stat("max_hp") * 0.08), 1))
		"static":
			unit.apply_status("slow")
		"essence_leak":
			unit.take_damage(maxi(roundi(unit.get_stat("max_hp") * 0.05), 1))
			unit.restore_mp(5)


# --- Player turn -----------------------------------------------------------

func _player_turn(unit: Node) -> void:
	state = State.PLAYER_INPUT
	_player_done = false
	player_input_needed.emit(unit)
	while not _player_done and state != State.ENDED:
		await get_tree().process_frame


## Player command: move the active unit. Awaitable; returns success.
func request_move(unit: Node, cell: Vector2i) -> bool:
	if unit != active_unit or state != State.PLAYER_INPUT and state != State.AI_TURN:
		return false
	if not unit.can_move():
		return false
	var flooded := grid.flood(unit.cell, unit.get_stat("move"), unit.get_stat("jump"), unit.team)
	if not flooded.has(cell) or (grid.get_occupant(cell) != null and cell != unit.cell):
		return false
	var path := IsometricGrid.path_from_flood(flooded, unit.cell, cell)
	var prev := state
	state = State.EXECUTING
	await unit.move_along(path, animate)
	if state == State.EXECUTING:
		state = prev
	_check_battle_end()
	return true


## Player/AI command: use an ability on a cell. Awaitable; returns success.
func request_ability(unit: Node, ability: Ability, cell: Vector2i, extra_cells: Array[Vector2i] = []) -> bool:
	if unit != active_unit or state == State.ENDED:
		return false
	var err := validate_ability(unit, ability, cell)
	if err != "":
		EventBus.log_message.emit(err)
		return false
	var prev := state
	state = State.EXECUTING
	unit.face_towards(cell)
	unit.spend_for(ability)
	if ability.charge_ticks > 0:
		turn_queue.queue_cast(unit, ability, cell)
		unit.apply_status("charging", unit)
		EventBus.ability_charging.emit(unit, ability, cell, ability.charge_ticks)
		EventBus.log_message.emit("%s begins charging %s." % [unit.display_name(), ability.display_name])
	else:
		await _execute(unit, ability, cell, extra_cells)
	if state == State.EXECUTING:
		state = prev
	_check_battle_end()
	return true


func validate_ability(unit: Node, ability: Ability, cell: Vector2i) -> String:
	if not unit.can_act():
		return "No actions left."
	if not unit.can_afford(ability):
		return "Not enough AP/MP."
	if ability is CardResource and unit.job_handler.deck and not unit.job_handler.deck.playable_cards().has(ability.id):
		return "That card is spent."
	if not ability.get_targetable_cells(grid, unit.cell, unit).has(cell):
		return "Out of range."
	return ""


func _execute(unit: Node, ability: Ability, cell: Vector2i, extra_cells: Array[Vector2i] = []) -> void:
	var ctx := Ability.Context.new()
	ctx.caster = unit
	ctx.target_cell = cell
	ctx.extra_cells = extra_cells
	ctx.grid = grid
	ctx.battle = self
	ctx.rng = rng
	EventBus.ability_used.emit(unit, ability, cell)
	if not ability.addition.is_empty():
		var hits := await _run_addition(unit, ability)
		ctx.power_mult = Additions.multiplier(ability, hits, Additions.mastery(unit.data, ability.id))
		ctx.force_hit = true
		Additions.record_use(unit.data, ability.id)
		EventBus.log_message.emit("%s: %d/%d beats" % [ability.display_name, hits, Additions.beats(ability).size()])
	elif animate and map_node and map_node.has_method("play_ability_fx"):
		await map_node.play_ability_fx(unit, ability, cell)
	var results: Array[Dictionary] = unit.job_handler.execute_ability(ability, ctx)
	if ability.special != "echo":
		_last_team_action[unit.team] = {"ability": ability, "cell": cell, "caster": unit}
	for r in results:
		var target: Node = r["unit"]
		if ability.blue_learnable and target != unit and target.is_alive():
			_try_blue_learn(target, ability)
		match r["kind"]:
			"damage":
				EventBus.log_message.emit("%s -> %s: %d%s" % [ability.display_name, target.display_name(), r["amount"], " CRIT" if r["crit"] else ""])
				if not target.is_alive() and target.team != unit.team:
					unit.kills += 1
			"heal":
				EventBus.log_message.emit("%s restores %d HP to %s" % [ability.display_name, r["amount"], target.display_name()])
			"miss":
				EventBus.log_message.emit("%s misses %s" % [ability.display_name, target.display_name()])
	if animate and is_inside_tree():
		await get_tree().create_timer(0.25).timeout


## Sync Blade Addition: the player times it; AI, headless runs and "auto"
## mode land a fixed ~70% of the beats.
func _run_addition(unit: Node, ability: Ability) -> int:
	var interactive: bool = animate and is_inside_tree() and unit.is_player_controlled and not SettingsFlags.auto_additions and DisplayServer.get_name() != "headless"
	if not interactive:
		return Additions.auto_hits(ability)
	var w := AdditionWidget.new()
	get_tree().root.add_child(w)
	return await w.run(ability, Additions.mastery(unit.data, ability.id))


## Bluescreen Mage: getting hit by blue-learnable tech teaches it (FFT Blue Mage).
func _try_blue_learn(target: Node, ability: Ability) -> void:
	var job: ClassResource = target.class_res()
	if job == null or not job.learnable_ability_ids.has(ability.id):
		return
	if target.job_handler.learned_ability_ids.has(ability.id):
		return
	target.job_handler.learned_ability_ids.append(ability.id)
	if target.data:
		var roster_entry := GameManager.get_character(target.data.id)
		if roster_entry and not roster_entry.learned_ability_ids.has(ability.id):
			roster_entry.learned_ability_ids.append(ability.id)
	EventBus.ability_unlocked.emit(target.data.id if target.data else "", ability.id)
	EventBus.log_message.emit("%s absorbed %s!" % [target.display_name(), ability.display_name])


func _resolve_charged_cast(cast: Dictionary) -> void:
	var caster: Node = cast["caster"]
	if not is_instance_valid(caster) or not caster.is_alive():
		return
	caster.remove_status("charging")
	active_unit = caster
	await _execute(caster, cast["ability"], cast["cell"])
	active_unit = null


## Player command: finish the active unit's turn, optionally facing a direction.
func end_active_turn(face: Vector2i = Vector2i.ZERO) -> void:
	if active_unit == null:
		return
	if face != Vector2i.ZERO:
		active_unit.facing = face
		active_unit.queue_redraw()
	_player_done = true


# --- AI turn ---------------------------------------------------------------

func _ai_turn(unit: Node) -> void:
	state = State.AI_TURN
	if unit.behavior == null:
		unit.behavior = AIBehavior.create("tactical")
	var plan: Dictionary = unit.behavior.plan_turn(unit, self)
	var ability: Ability = plan.get("ability")
	if animate and is_inside_tree():
		await get_tree().create_timer(0.3).timeout
	if plan["act_first"] and ability:
		await request_ability(unit, ability, plan["target_cell"])
		if unit.is_alive() and plan["move_to"] != unit.cell:
			await request_move(unit, plan["move_to"])
	else:
		if plan["move_to"] != unit.cell:
			await request_move(unit, plan["move_to"])
		if ability and unit.is_alive() and state != State.ENDED:
			# Re-validate: the move may have been shorter than planned.
			if validate_ability(unit, ability, plan["target_cell"]) == "":
				await request_ability(unit, ability, plan["target_cell"])
	if unit.is_alive() and plan.has("face"):
		unit.facing = plan["face"]
		unit.queue_redraw()


# --- Deaths & end conditions -----------------------------------------------

func _on_unit_died(unit: Node) -> void:
	turn_queue.remove_unit(unit)
	EventBus.log_message.emit("%s is down." % unit.display_name())


func _team_alive(team: int) -> bool:
	for u in get_units():
		if u.team == team:
			return true
	return false


func _find_by_character(character_id: String) -> Node:
	for u in units:
		if is_instance_valid(u) and u.data and u.data.id == character_id:
			return u
	return null


## Returns true (and finishes the battle) if a win or lose condition is met.
func _check_battle_end() -> bool:
	if state == State.ENDED:
		return true
	# Lose conditions first: a simultaneous wipe is a loss.
	if not _team_alive(Unit.Team.PLAYER):
		_finish(false)
		return true
	var lose := mission.lose_condition if mission else "party_wiped"
	var lose_param := mission.lose_param if mission else ""
	match lose:
		"leader_down", "protect":
			var leader := _find_by_character(lose_param)
			if leader and not leader.is_alive():
				_finish(false)
				return true
		"time_limit":
			if current_round() > int(lose_param):
				_finish(false)
				return true
	var win := mission.win_condition if mission else "defeat_all"
	var param := mission.win_param if mission else ""
	var won := false
	match win:
		"defeat_all":
			won = not _team_alive(Unit.Team.ENEMY)
		"defeat_target":
			var boss := _find_by_character(param)
			won = (boss != null and not boss.is_alive()) or not _team_alive(Unit.Team.ENEMY)
		"survive":
			won = current_round() >= int(param) or not _team_alive(Unit.Team.ENEMY)
		"reach_cell":
			var parts := param.split(",")
			if parts.size() == 2:
				var goal := Vector2i(int(parts[0]), int(parts[1]))
				var occ := grid.get_occupant(goal)
				won = occ != null and occ.team == Unit.Team.PLAYER
			won = won or not _team_alive(Unit.Team.ENEMY)
		_:
			won = not _team_alive(Unit.Team.ENEMY)
	if won:
		_finish(true)
		return true
	return false


func _finish(p_victory: bool) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	victory = p_victory
	_player_done = true
	EventBus.battle_ended.emit(p_victory, mission.id if mission else "")
	battle_finished.emit(p_victory)


## Pays out through CampaignManager. Called by the battle scene after the
## results screen, not automatically (tests and skirmishes may skip it).
func conclude_battle() -> Dictionary:
	var survivors: Array[String] = []
	for u in units:
		if is_instance_valid(u) and u.team == Unit.Team.PLAYER and u.data and GameManager.get_character(u.data.id):
			survivors.append(u.data.id)
			# Persist per-unit progress: kills feed weapon XP.
			var weapon: Dictionary = u.equipment.slots.get("weapon", {})
			if not weapon.is_empty() and u.kills > 0:
				ForgeManager.add_item_xp(str(weapon.get("uid", "")), u.kills * 25)
	return CampaignManager.process_mission_completion(victory, mission, survivors)
