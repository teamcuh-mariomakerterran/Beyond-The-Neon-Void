extends Node

enum GameState {
	WAITING_FOR_TURN,
	SELECTING_UNIT,
	SELECTING_ACTION,
	EXECUTING_ACTION,
	TURN_TRANSITION,
	PLAYER_PHASE,
	ENEMY_PHASE
}

enum TurnPhase {
	PLAYER,
	ENEMY
}

var current_phase: TurnPhase = TurnPhase.PLAYER

signal turn_started(unit)
signal action_completed(unit)
signal battle_ended(victory)

var current_state: GameState = GameState.WAITING_FOR_TURN
var is_busy: bool = false
var active_unit: Unit = null

func _ready() -> void:
	# Initialize combat systems
	setup_battle_field()

func setup_battle_field() -> void:
	# Logic to spawn units and configure the grid
	pass

func advance_turn() -> void:
	# Logic to move to the next unit in the turn order
	pass




func _ready() -> void:
	pass

func process_battle_results(won: bool, xp_gained: int, credits_gained: int) -> void:
	if won:
		for unit in get_tree().get_nodes_in_group("player_units"):
			unit.gain_xp(xp_gained)
		if CampaignManager:
			CampaignManager.total_credits += credits_gained
	else:
		pass

func conclude_battle(victory: bool, mission_resource: Resource) -> void:
	var xp = 0
	var credits = 0
	if victory and mission_resource:
		xp = mission_resource.xp_reward
		credits = mission_resource.credit_reward
	
	process_battle_results(victory, xp, credits)
	emit_signal("battle_ended", victory)
	
	if CampaignManager:
		CampaignManager.process_mission_completion(victory, mission_resource)
		CampaignManager.return_to_hub()

func end_player_turn() -> void:
	if current_state == GameState.PLAYER_PHASE:
		current_state = GameState.ENEMY_PHASE
		_start_enemy_phase()

func _start_enemy_phase() -> void:
	if UIManager:
		UIManager.set_turn_indicator("Enemy Turn")
	
	# Trigger heartbeat for all enemy units
	var enemies = get_tree().get_nodes_in_group("combatants").filter(func(u): return u is Unit and not u.is_player_controlled)
	for enemy in enemies:
		enemy.tick_status_effects()
	
	await get_tree().create_timer(2.0).timeout
	_start_player_phase()

func _start_player_phase() -> void:
	current_state = GameState.PLAYER_PHASE
	if UIManager:
		UIManager.set_turn_indicator("Your Turn")
	
	var player_units = get_tree().get_nodes_in_group("player_units")
	for unit in player_units:
		unit.tick_status_effects()

func set_active_unit(unit: Unit) -> void:
	active_unit = unit
	current_state = GameState.SELECTING_ACTION
	# Notify UI to show abilities for this unit
	if UIManager:
		UIManager.show_unit_hud(unit)

func select_ability(ability: Ability) -> void:
	selected_ability = ability
	current_state = GameState.TARGETING
	# Visual feedback that we are now selecting a target
	if UIManager:
		UIManager.set_targeting_mode(true)
	
	if IsometricGrid:
		IsometricGrid.highlight_range(active_unit.grid_position, ability.range, true)

func resolve_target_click(target_tile: Vector2i) -> void:
	if current_state != GameState.TARGETING or active_unit == null or selected_ability == null:
		return

	var target_unit = _get_unit_at_tile(target_tile)
	if target_unit:
		var success = execute_ability(active_unit, target_unit, selected_ability)
		if success:
			# Action resolved, return to action selection or end turn
			current_state = GameState.SELECTING_ACTION
	
	if IsometricGrid and selected_ability:
		IsometricGrid.highlight_range(active_unit.grid_position, selected_ability.range, false)

	if UIManager:
		UIManager.set_targeting_mode(false)
	selected_ability = null

func _get_unit_at_tile(tile: Vector2i) -> Unit:
	var units = get_tree().get_nodes_in_group("combatants")
	for u in units:
		if u is Unit and u.grid_position == tile:
			return u
	return null

func execute_ability(attacker: Unit, target: Unit, ability: Ability) -> bool:
	if is_busy:
		return false
		
	# 1. AP Validation
	if attacker.current_ap < ability.ap_cost:
		return false
	
	# 2. Range Validation
	var dist = 0
	if IsometricGrid:
dist = IsometricGrid.get_distance(attacker.grid_pos, target.grid_pos)
	if dist > ability.range:
		return false
		
	# 3. Execution
	is_busy = true
	attacker.current_ap -= ability.ap_cost
	
	# Resolve the effect (damage, heal, etc)
	var result = ability.resolve(attacker, target)
	
	# Visuals and Animations
	await animate_ability_execution(attacker, target, ability)
	
	is_busy = false
	return true


>>>


<<<END>>>

Wait, I noticed the provided file had `_start_enemy_phase` defined twice (lines 52 and 63). I will clean that up and implement the logic as requested.

func conclude_battle(victory: bool, mission_resource: Resource) -> void:
	var xp = 0
	var credits = 0
	
	if victory and mission_resource:
		xp = mission_resource.xp_reward
		credits = mission_resource.credit_reward
	
	process_battle_results(victory, xp, credits)
	emit_signal("battle_ended", victory)
	
	if CampaignManager:
		CampaignManager.process_mission_completion(victory, mission_resource)
		CampaignManager.return_to_hub()

func save_game():
	var save_data = {
		"credits": CampaignManager.total_credits,
		"party": []
	}
	var file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_game():
	if not FileAccess.file_exists("user://savegame.save"):
		return
	var file = FileAccess.open("user://savegame.save", FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		if data:
			CampaignManager.total_credits = data.get("credits", 0)

func register_unit(unit: Unit) -> void:
	add_group("combatants", unit)
	if not get_tree().current_scene.has_node("BattleSpawnSystem"):
		return
	turn_queue.append(unit)

func resolve_aoe_damage(origin_tile: Vector2i, radius: int, damage: int, ignores_cover: bool = false) -> Array[int]:
	var damage_results = []
	var affected_units = get_tree().get_nodes_in_group("combatants")
	
	for unit in affected_units:
		if unit is Unit:
			var dist = origin_tile.distance_to(unit.grid_position)
			if dist <= radius:
				var final_dmg = float(damage)
				if not ignores_cover and IsometricGrid:
var target
					var cover_bonus = IsometricGrid.get_cover_bonus(unit.grid_position, origin_tile)
					final_dmg -= cover_bonus
				
				damage_results.append(int(max(0, final_dmg)))
	return damage_results



# Helper to handle asynchronous movement before attacking
func execute_tactical_move(unit: Unit, target_tile: Vector2i) -> void:
	unit.move_to_tile(target_tile)
	# Wait for the interpolation timer in Unit.gd to finish
	await get_tree().create_timer(0.4).timeout 

func resolve_attack(attacker: Unit, target: Unit, ability: Ability) -> int:
	var attacker_stats = attacker.stats
	var target_stats = target.stats
	
	# 1. Line of Sight Check
	if IsometricGrid and not IsometricGrid.check_line_of_sight(attacker.grid_position, target.grid_position):
		_spawn_damage_text(target.global_position, "OBSTRUCTED", Color.GRAY)
		return 0

	# 2. Calculate Hit Chance with Cover Penalty
	var cover_penalty = 0.0
	if IsometricGrid:
		var target_tile_type = IsometricGrid.get_tile_type(target.grid_position)
		if target_tile_type == "Full-Cover": cover_penalty = 0.3
		elif target_tile_type == "Half-Cover": cover_penalty = 0.15

	var hit_chance = 0.75 + (attacker_stats.agility - target_stats.agility) * 0.02 - cover_penalty
	var roll = randf()
	
	if roll > hit_chance:
		_spawn_damage_text(target.global_position, "MISS", Color.YELLOW)
		return 0
		
	# 3. Damage Calculation
	var attack_power = attacker_stats.strength if ability.is_physical else attacker_stats.intelligence
	var defense_power = target_stats.vitality
	
	var base_damage = attack_power - (defense_power * 0.5)
	
	# Cover also reduces damage taken
	var damage_multiplier = 1.0
	if IsometricGrid:
		var target_tile_type = IsometricGrid.get_tile_type(target.grid_position)
		if target_tile_type == "Full-Cover": damage_multiplier = 0.6
		elif target_tile_type == "Half-Cover": damage_multiplier = 0.8

	var final_damage = max(1, int(base_damage * damage_multiplier))
	
	target.take_damage(final_damage)
	_spawn_damage_text(target.global_position, str(final_damage), Color.WHITE)
	
	return final_damage

func _spawn_damage_text(position: Vector2, text: String, color: Color):
	if DamageText:
		var dt = DamageText.instantiate()
		get_tree().current_scene.add_child(dt)
		dt.setup(position, text, color)

func resolve_attack(attacker: Unit, target: Unit, ability: Ability) -> int:
	var attacker_stats = attacker.stats
	var target_stats = target.stats
	
	# Validate class-based scaling via ClassLibrary
	if ClassLibrary and attacker.class_resource:
		attacker_stats.apply_class_multipliers(attacker.class_resource)
	
	if IsometricGrid and not IsometricGrid.check_line_of_sight(attacker.grid_position, target.grid_position):
		_spawn_damage_text(target.global_position, "OBSTRUCTED", Color.GRAY)
		return 0

	var cover_penalty = 0.0
	if IsometricGrid:
		var target_tile_type = IsometricGrid.get_tile_type(target.grid_position)
		if target_tile_type == "Full-Cover": cover_penalty = 0.3
		elif target_tile_type == "Half-Cover": cover_penalty = 0.15

	var hit_chance = 0.75 + (attacker_stats.agility - target_stats.agility) * 0.02 - cover_penalty
	if randf() > hit_chance:
		_spawn_damage_text(target.global_position, "MISS", Color.YELLOW)
		return 0
		
	var attack_power = attacker_stats.strength if ability.is_physical else attacker_stats.intelligence
	var defense_power = target_stats.vitality
	var base_damage = attack_power - (defense_power * 0.5)
	var final_damage = max(1, int(base_damage + ability.bonus_damage))
	
	target.take_damage(final_damage)
	_spawn_damage_text(target.global_position, str(final_damage), Color.WHITE)
	return final_damage


>>>
PS-ENDreturn final_damage


func _spawn_damage_text(position: Vector2, text: String, color: Color):
	if DamageText:
		var dt = DamageText.instantiate()
		get_tree().current_scene.add_child(dt)
		dt.setup(position, text, color)

func resolve_damage(attacker: Unit, target: Unit, ability_id: String) -> int:
	# Kept for backward compatibility with existing calls, maps to resolve_attack
	# This assumes the ability_id can be looked up to get the Ability resource
	var ability = attacker.abilities.get(ability_id, null)
	if ability:
		return resolve_attack(attacker, target, ability)
	return 0
>>>

func validate_action(unit: Unit, cost: int, distance: int = 0, max_range: int = 999) -> String:
	if unit.current_ap < cost:
		return "Not enough AP"
	if distance > max_range:
		return "Out of range"
	return ""

func can_perform_action(unit: Unit, cost: int) -> bool:
	return unit.current_ap >= cost

func consume_ap(unit: Unit, amount: int) -> void:
	unit.current_ap -= amount
	if UIManager:
		UIManager.update_ap_display(unit)

func end_turn() -> void:
	if current_phase == TurnPhase.PLAYER:
		transition_to_phase(TurnPhase.ENEMY)
	else:
		transition_to_phase(TurnPhase.PLAYER)

func transition_to_phase(next_phase: TurnPhase) -> void:
	current_phase = next_phase
	
	if current_phase == TurnPhase.ENEMY:
		process_enemy_turns()
	else:
		emit_signal("player_turn_started")

func process_enemy_turns() -> void:
	var enemies = get_group("combatants").filter(func(u): return not u.is_player_controlled)
	for enemy in enemies:
		await execute_enemy_ai(enemy)
	
	end_turn()

func execute_enemy_ai(unit: Unit) -> void:
	# Simple AI: Attack closest target
	var target = find_closest_target(unit)
	if target:
		await unit.perform_attack(target)
	await get_tree().create_timer(0.5).timeout

func find_closest_target(unit: Unit) -> Unit:
	var targets = get_tree().get_nodes_in_group("player_units")
	var closest = null
	var min_dist = INF
	
	for target in targets:
		if target.health > 0:
			var dist = unit.global_position.distance_to(target.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = target
	return closest