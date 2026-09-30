extends Node
class_name IsometricGrid

# The ratio of width to height for the isometric projection (2:1)
const ISO_RATIO = 2.0

# Tile size in pixels (width of the diamond)
@export var tile_width: float = 64.0
# Calculated height based on the 2:1 ratio
var tile_height: float

func _ready() -> void:
	tile_height = tile_width / ISO_RATIO

# Converts grid coordinates (column, row) to world 2D position
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var x = (grid_pos.x - grid_pos.y) * (tile_width / 2.0)
	var y = (grid_pos.x + grid_pos.y) * (tile_height / 2.0)
	return Vector2(x, y)

func world_from_grid(grid_pos: Vector2) -> Vector2:
	return grid_to_world(Vector2i(round(grid_pos.x), round(grid_pos.y)))

# Converts world 2D position back to grid coordinates (column, row)
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var gx = (world_pos.x / (tile_width / 2.0) + world_pos.y / (tile_height / 2.0)) / 2.0
	var gy = (world_pos.y / (tile_height / 2.0) - world_pos.x / (tile_width / 2.0)) / 2.0
	return Vector2i(round(gx), round(gy))

func grid_from_world(world_pos: Vector2) -> Vector2:
	return Vector2(world_to_grid(world_pos))

# Returns the center point of a specific tile
func get_tile_center(grid_pos: Vector2) -> Vector2:
	return world_from_grid(grid_pos)

# Helper to get the distance between two tiles in terms of grid steps (Manhattan distance)
func get_grid_distance(pos_a: Vector2i, pos_b: Vector2i) -> int:
	return abs(pos_a.x - pos_b.x) + abs(pos_a.y - pos_b.y)

# Checks if there is a clear line of sight between two tiles.
# Assumes a global or accessible 'Map' system that provides tile properties.
func check_line_of_sight(start_tile: Vector2i, end_tile: Vector2i) -> bool:
	var x0 = start_tile.x
	var y0 = start_tile.y
	var x1 = end_tile.x
	var y1 = end_tile.y

	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
var sy = 1 if y0 < y1 else -1
	var err = dx - dy

	var curr_x = x0
	var curr_y = y0

	while curr_x != x1 or curr_y != y1:
		if curr_x == x1 and curr_y == y1:
			break

		# Check if the current tile blocks vision (excluding start/end)
		if (curr_x != x0 or curr_y != y0) and (curr_x != x1 or curr_y != y1):
			if is_tile_blocking_vision(Vector2i(curr_x, curr_y)):
				return false

		var e2 = 2 * err
		if e2 > -dx:
			err -= dy
			curr_x += sx
		if e2 < dy:
			err += dx
			curr_y += sy

	return true

# Simulated tile data: {Vector2i: type}
var tile_data_override = {}

# Stores current hazard state for tiles: {Vector2i: {type: String, timer: float}}
var tile_hazards = {}

func get_tile_type(coords: Vector2i) -> String:
	if tile_data_override.has(coords):
		return tile_data_override[coords]
	# Default to "Open"
	return "Open"

func set_tile_hazard(coords: Vector2i, hazard_type: String, duration: float) -> void:
	tile_hazards[coords] = {"type": hazard_type, "timer": duration}

func get_tile_hazard(coords: Vector2i) -> String:
	if tile_hazards.has(coords):
		return tile_hazards[coords].type
	return "None"

func update_hazards(delta: float) -> void:
	var to_remove = []
	for coords in tile_hazards:
		tile_hazards[coords].timer -= delta
		if tile_hazards[coords].timer <= 0:
			to_remove.append(coords)
	for coords in to_remove:
		tile_hazards.erase(coords)

func get_cover_value(coords: Vector2i) -> float:
	match get_tile_type(coords):
		"Light-Cover": return 0.2 # 20% reduction
		"Heavy-Cover": return 0.5 # 50% reduction
		"Full-Cover": return 0.8  # 80% reduction
		_: return 0.0

func is_tile_blocking_vision(coords: Vector2i) -> bool:
	# A tile blocks vision if it is "Full-Cover"
	return get_tile_type(coords) == "Full-Cover"

func highlight_tile(grid_pos: Vector2i, active: bool) -> void:
	# Implementation would typically involve toggling a shader parameter or a sprite visibility
	# For now, this acts as the hook for the CombatManager and InputBridge
	pass

func highlight_range(center_pos: Vector2i, range_val: int, active: bool) -> void:
	# Implementation: Iterate through a bounding box and check get_grid_distance
	# Visuals are updated via the tile_data_override or a dedicated highlight layer
	pass

# Returns the current mouse position as a grid coordinate for the highlight system
func get_mouse_grid_pos() -> Vector2i:
	var mouse_pos = get_viewport().get_mouse_position()
	return world_to_grid(mouse_pos)
)
)
)
)
)
)
)
)
)
