extends Node

## InputBridge.gd
## Translates raw mouse input into meaningful game commands.

@onready var grid = get_tree().current_scene.get_node_or_null("IsometricGrid")

func _input(event: InputEvent) -> void:
	if not CombatManager:
		return
		
	if CombatManager.current_state not in ["PLAYER_TURN", "TARGETING_ENEMY"]:
		return
		
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Only process clicks if the manager is not currently resolving an action
			if not (CombatManager and CombatManager.is_resolving_action):
				handle_grid_click(event.position)
	
	if event is InputEventMouseMotion:
		handle_mouse_hover(event.position)

func handle_mouse_hover(mouse_pos: Vector2) -> void:
	if not grid:
		return
	var grid_pos = grid.world_to_grid(mouse_pos)
	# Notify managers to draw highlights/ghost paths for the hovered tile
	if HighlightManager:
		HighlightManager.update_hover_tile(grid_pos)
	if CombatManager and CombatManager.current_state == "PLAYER_TURN":
		CombatManager.update_hover_target(grid_pos)

func handle_grid_click(screen_pos: Vector2) -> void:
	if not grid:
		return

	var grid_pos = grid.world_to_grid(screen_pos)
	if not grid.is_position_valid(grid_pos):
		return
	
	if not CombatManager:
		return

	var target_unit = CombatManager.get_unit_at_grid_pos(grid_pos)
	
	if CombatManager.current_state == "TARGETING_ENEMY":
		if target_unit:
			CombatManager.resolve_ability_target(target_unit)
		else:
			# If they click the ground while targeting, we cancel the ability
			CombatManager.cancel_targeting()
	elif CombatManager.current_state == "PLAYER_TURN":
		# Standard unit selection flow
		if target_unit:
			CombatManager.select_unit(target_unit)
		else:
			CombatManager.deselect_all()



func get_grid_coords_at_mouse() -> Vector2i:
	if not grid:
		return Vector2i.ZERO
	return grid.world_to_grid(get_viewport().get_mouse_position())