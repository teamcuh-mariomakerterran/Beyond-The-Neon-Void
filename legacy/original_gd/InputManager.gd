extends Node2D

## InputManager handles the translation of screen-space mouse clicks
## into isometric grid coordinates and manages unit selection.

@export var grid_manager: Node2D # Reference to the BattleMap/Grid logic
@export var combat_manager: Node # Reference to the CombatManager state machine

var selected_unit: Node2D = null
var is_waiting_for_target: bool = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("mouse_left"):
		handle_click()

func handle_click() -> void:
	var mouse_pos = get_global_mouse_position()
	var grid_pos = grid_manager.world_to_grid(mouse_pos)
	
	if is_waiting_for_target:
		# We are in the process of selecting a destination or target
		execute_action_on_tile(grid_pos)
	else:
		# We are trying to select a unit
		var unit = grid_manager.get_unit_at_grid(grid_pos)
		if unit and combat_manager.can_select_unit(unit):
			select_unit(unit)

func select_unit(unit: Node2D) -> void:
	selected_unit = unit
	is_waiting_for_target = true
	
	# Tell the combat manager to highlight valid moves for this unit
	combat_manager.highlight_unit_options(unit)

func execute_action_on_tile(grid_pos: Vector2i) -> void:
	if not selected_unit:
		return
	
	# Pass the intent to the combat manager to validate and execute
	var success = combat_manager.attempt_action_on_tile(selected_unit, grid_pos)
	
	if success:
		# Action completed, deselect unit
		deselect_unit()
	else:
		# Action failed (e.g. out of range), keep unit selected
		pass

func deselect_unit() -> void:
	selected_unit = null
	is_waiting_for_target = false
	grid_manager.clear_highlights()