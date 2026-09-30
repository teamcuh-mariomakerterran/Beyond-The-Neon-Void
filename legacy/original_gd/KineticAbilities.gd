extends "res://Scripts/Combat/Ability.gd"
class_name KineticAbilities

# --- Vector Knight Logic ---

## Kinetic Charge: Passive
## Calculates bonus damage based on distance moved in a straight line.
func apply_kinetic_charge(unit: Unit, target: Unit, base_damage: float) -> float:
	var distance := unit.global_position.distance_to(target.global_position)
	# Convert world distance to grid tiles (assuming 64px tiles)
	var tiles_moved := round(distance / 64.0)

	if tiles_moved <= 1:
		return base_damage

	# Exponential growth: base * (1.5 ^ tiles)
	var multiplier := pow(1.5, tiles_moved)
	return base_damage * multiplier

## Gravitational Pull: Active
## Pulls units within a 3-tile straight vector 2 spaces closer.
func execute_gravitational_pull(caster: Unit, target_direction: Vector2) -> void:
	var grid = IsometricGrid.instance
	var caster_tile = grid.world_to_tile(caster.global_position)

	# Scan 3 tiles in the chosen direction
	for i in range(1, 4):
		var check_tile = caster_tile + (target_direction * i)
		var unit_at_tile = grid.get_unit_at_tile(check_tile)

		if unit_at_tile and unit_at_tile != caster:
			# Pull 2 tiles closer (capped at caster's position)
			var pull_vector = (caster_tile - check_tile).normalized()
			var new_tile = check_tile + (pull_vector * 2)

			# Ensure we don't pull them PAST the caster
			if check_tile.distance_to(new_tile) > 2:
				new_tile = check_tile + (pull_vector * 1)

			# Move unit and check for collisions
			if grid.is_tile_walkable(new_tile):
				grid.move_unit(unit_at_tile, new_tile)
				# Trigger a small shake or sound via Global events
				GameManager.emit_signal("play_sfx", "kinetic_pull")

class ElasticInertiaAbility extends KineticAbility:
	func execute(caster: Unit, target: Unit, _position: Vector2) -> void:
		# This is a passive-trigger style ability.
		# It marks the target as "unstable".
		# When the target is knocked back into a wall, double damage is dealt.
		target.apply_status_effect("unstable_inertia", 2)
		# Visual feedback: targettarget.apply_status_effect("unstable_inertia", 2)
		# Visual feedback: target flashes a warning color
		target.hit_flash(Color.YELLOW, 0.5)
		it_signal("play_sfx", "kinetic_mark")
)
)
