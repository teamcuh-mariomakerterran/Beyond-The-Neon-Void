extends "res://Scripts/Combat/Ability.gd"

## Logic for the Cartographer: Terrain Manipulation

# -------------------------------------------------------------------
# ABILITY: Draw Fault Line
# Selects two tiles. A linear wall erupts between them.
# -------------------------------------------------------------------
class DrawFaultLine extends Ability:
	func execute(caster: Unit, targets: Array[Vector2i]) -> void:
		if targets.size() < 2: return
		
		var start = targets[0]
		var end = targets[1]
		var line = get_line_between(start, end)
		
		for tile in line:
			IsometricGrid.singleton.set_tile_passable(tile, false)
			IsometricGrid.singleton.spawn_visual_obstacle("rock_wall", tile)
			
	func get_line_between(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
		var points: Array[Vector2i] = []
		var current = a
		while current != b:
			points.append(current)
			current += (b - current).normalized()
		points.append(b)
		return points

# -------------------------------------------------------------------
# ABILITY: Isolate Elevation
# Raises or lowers a single tile's height property.
# -------------------------------------------------------------------
class IsolateElevation extends Ability:
	@export var height_delta: int = 5
	
	func execute(caster: Unit, targets: Array[Vector2i]) -> void:
		if targets.size() < 1: return
		var target_tile = targets[0]
		
		# Modify the grid height data
		var current_height = IsometricGrid.singleton.get_tile_height(target_tile)
		# Logic to determine if we raise or lower based on caster's target prompt
		var new_height = current_height + height_delta 
		
		IsometricGrid.singleton.update_tile_height(target_tile, new_height)
		
		# If a unit is on the tile, they move with the elevation change
		var occupant = IsometricGrid.singleton.get_unit_at(target_tile)
		if occupant:
			occupant.update_position_visuals()

# -------------------------------------------------------------------
# ABILITY: Warp Coordinates
# Swaps two target tiles and their contents.
# -------------------------------------------------------------------
class WarpCoordinates extends Ability:
	func execute(caster: Unit, targets: Array[Vector2i]) -> void:
		if targets.size() < 2: return
		
		var tile_a = targets[0]
		var tile_b = targets[1]
		
# Swap hazards/metadata in the grid
		var data_a = IsometricGrid.singleton.get_tile_data(tile_a)
		var data_b = IsometricGrid.singleton.get_tile_data(tile_b)
		
		IsometricGrid.singleton.set_tile_data(tile_a, data_b)
		IsometricGrid.singleton.set_tile_data(tile_b, data_a)
		
		# Swap units physically
		var unit_a = IsometricGrid.singleton.get_unit_at(tile_a)
		var unit_b = IsometricGrid.singleton.get_unit_at(tile_b)		
		if unit_a:
			unit_a.move_to_tile(tile_b)
		if unit_b:
			unit_b.move_to_tile(tile_a)
			
		# Visual feedback
		CameraManager.shake(0.2, 10.0)
		Visuals.spawn_particle_effect("warp_vfx", tile_a)
		Visuals.spawn_particle_effect("warp_vfx", tile_b)