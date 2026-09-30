extends Node2D

class_name BattleMap

@export_group("Grid Settings")
@export var tile_width: float = 64.0
@export var tile_height: float = 32.0
@export var grid_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	print("BattleMap initialized successfully.")

## Returns the Manhattan distance between two grid coordinates in isometric space
func get_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

## Returns the world position of a grid cell, optionally offset by height/elevation
func grid_to_world_with_height(grid_pos: Vector2i, height: float = 0.0) -> Vector2:
	var pos = grid_to_world(grid_pos)
	pos.y -= height # In 2D iso, height usually pushes the sprite 'up' the screen
	return pos

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var relative_pos = world_pos - grid_offset
	
	# Isometric 2:1 projection inverse
	var x = (relative_pos.x / tile_width + relative_pos.y / tile_height) / 2.0
	var y = (relative_pos.y / tile_height - relative_pos.x / tile_width) / 2.0
	
	return Vector2i(round(x), round(y))

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	# Isometric 2:1 projection
	var x = (grid_pos.x - grid_pos.y) * tile_width
	var y = (grid_pos.x + grid_pos.y) * tile_height / 2.0
	
	return Vector2(x, y) + grid_offset

func get_spawn_points() -> Array[Marker2D]:
	var spawns: Array[Marker2D] = []
	for child in get_children():
		if child is Marker2D and child.name.begins_with("Spawn_"):
			spawns.append(child)
	return spawns

## Checks if a specific grid coordinate is walkable.
## Integration point for collision maps or terrain data.
func is_tile_walkable(grid_pos: Vector2i) -> bool:
	# Placeholder logic: all tiles are walkable unless logic is added here
	return true

## Synchronizes a unit's visual position based on the tile's elevation.
## Prevents 'drifting' by snapping to the calculated isometric height.
func sync_unit_height(unit: Node2D, grid_pos: Vector2i, elevation: float) -> void:
	var target_pos = grid_to_world_with_height(grid_pos, elevation)
	unit.global_position = target_pos

## Moves a unit to a target grid position smoothly using a Tween.
## Returns true if the move was initiated, false if the destination was invalid.
func move_unit(unit: Node2D, target_grid_pos: Vector2i, elevation: float = 0.0, duration: float = 0.3) -> bool:
	if not is_tile_walkable(target_grid_pos):
		return false
	
	var target_world_pos = grid_to_world_with_height(target_grid_pos, elevation)
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit, "global_position", target_world_pos, duration)
	
	return true