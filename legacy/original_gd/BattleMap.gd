extends Node2D

## BattleMap handles the 2:1 isometric grid, elevation data, and movement constraints.
## It converts between grid coordinates (q, r) and world space.

@export_group("Grid Settings")
@export var grid_width: int = 20
@export var grid_height: int = 20
@export var tile_width: float = 64.0
@export var tile_height: float = 32.0 # 2:1 Ratio
@export var elevation_step: float = 8.0 # Visual offset per elevation level

var elevation_map: Dictionary = {} # Key: Vector2i(q, r), Value: int(height)

func _ready() -> void:
	# Initialize map with 0 elevation by default
	for x in range(grid_width):
		for y in range(grid_height):
			elevation_map[Vector2i(x, y)] = 0
	
	# Trigger party spawning on map load
	var spawn_points = get_spawn_points()
	if not spawn_points.is_empty():
		start_battle_encounter(spawn_points)

## Converts grid coordinates (q, r) to 2D world position
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var world_x = (grid_pos.x - grid_pos.y) * (tile_width / 2.0)
	var world_y = (grid_pos.x + grid_pos.y) * (tile_height / 2.0)
	
	# Apply elevation offset to the Y position (higher tiles are shifted up)
	var height = get_elevation(grid_pos)
	world_y -= height * elevation_step
	
	return Vector2(world_x, world_y)

## Converts world position back to the nearest grid coordinate
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var x_offset = world_pos.x / (tile_width / 2.0)
	var y_offset = world_pos.y / (tile_height / 2.0)
	
	var q = (x_offset + y_offset) / 2.0
	var r = (y_offset - x_offset) / 2.0
	
	return Vector2i(round(q), round(r))

## Returns the elevation level of a specific tile
func get_elevation(grid_pos: Vector2i) -> int:
	return elevation_map.get(grid_pos, 0)

## Sets the elevation of a specific tile
func set_elevation(grid_pos: Vector2i, height: int) -> void:
	elevation_map[grid_pos] = height

## Checks if a unit can move from tile A to tile B based on elevation rules
func can_traverse(from_pos: Vector2i, to_pos: Vector2i, has_grapple: bool) -> bool:
	if not is_within_bounds(to_pos):
		return false
		
	var height_diff = get_elevation(to_pos) - get_elevation(from_pos)
	
	# Natural movement: up to 2 tiles height difference
	# If it's more than 2, they need a grapple hook or special ability
	if abs(height_diff) <= 2:
		return true
	elif has_grapple:
		return true
	
	return false

func is_within_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_width and grid_pos.y >= 0 and grid_pos.y < grid_height

## Returns a list of all designated spawn point markers in the scene
func get_spawn_points() -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	# Assumes spawn points are children of the map and named "Spawn_"
	for child in get_children():
		if child is Marker2D and "Spawn_" in child.name:
			points.append(world_to_grid(child.global_position))
	return points

# Helper for the Map Editor to save/load layouts
func get_map_data() -> Dictionary:
	return {
		"width": grid_width,
		"height": grid_height,
		"elevation": elevation_map
	}

func load_map_data(data: Dictionary) -> void:
	grid_width = data["width"]
	grid_height = data["height"]
	elevation_map = data["elevation"]

## Triggered by the CampaignManager to start the battle
func start_battle_encounter(spawn_points: Array[Vector2i]) -> void:
	var spawn_system: Node = null
	# Search for the spawn system in the current scene
	for child in get_tree().root.find_children("*BattleSpawnSystem*", "Node", true):
		if child.has_method("spawn_party"):
			spawn_system = child
			break

	if not spawn_system:
		push_error("BattleMap: BattleSpawnSystem not found in scene tree.")
		return
	
	if spawn_points.is_empty():
		push_warning("BattleMap: No spawn points provided to start_battle_encounter.")
		return

	spawn_system.spawn_party(spawn_points)