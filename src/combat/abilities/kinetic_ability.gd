class_name KineticAbility
extends Ability
## Vector Knight kit: momentum, pulls and knockback.
##
##  kinetic.charge        Bonus damage per tile moved in a straight line this turn.
##                        (Original used 1.5^tiles — unbounded. Now linear & capped.)
##  kinetic.pull          Gravitational Pull: drags every unit in a line toward the caster.
##  kinetic.repulse       Shoves the target away; slamming into walls/units hurts,
##                        double if the target is "unstable" (Elastic Inertia).
##  kinetic.inertia_mark  Elastic Inertia: marks the target unstable (status via data).

const CHARGE_BONUS_PER_TILE := 0.2
const CHARGE_BONUS_MAX := 1.0  # at most x2 total


func power_multiplier(caster: Node) -> float:
	if special == "kinetic.charge":
		var tiles: int = caster.move_streak
		if tiles <= 1:
			return 1.0
		return 1.0 + minf((tiles - 1) * CHARGE_BONUS_PER_TILE, CHARGE_BONUS_MAX)
	return 1.0


func _resolve_special(ctx: Context) -> void:
	match special:
		"kinetic.pull":
			_gravitational_pull(ctx)
		"kinetic.repulse":
			_repulse(ctx)


func _gravitational_pull(ctx: Context) -> void:
	var caster := ctx.caster
	var dir := IsometricGrid.cardinal_direction(caster.cell, ctx.target_cell)
	var reach := int(params.get("reach", 3))
	var pull := int(params.get("pull", 2))
	for i in range(1, reach + 1):
		var c: Vector2i = caster.cell + dir * i
		var u: Node = ctx.grid.get_occupant(c)
		if u == null or u == caster or not u.is_alive():
			continue
		var dest := c
		for _step in pull:
			var next := dest - dir
			if next == caster.cell or not ctx.grid.is_walkable(next) or ctx.grid.get_occupant(next) != null:
				break
			dest = next
		if dest != c:
			u.force_move(dest, ctx.battle.animate)
			ctx.log_result(u, "pulled")
	EventBus.play_sfx.emit("kinetic_pull")
	EventBus.camera_shake.emit(3.0, 0.2)


func _repulse(ctx: Context) -> void:
	var target: Node = ctx.grid.get_occupant(ctx.target_cell)
	if target == null or not target.is_alive():
		return
	var dir := IsometricGrid.cardinal_direction(ctx.caster.cell, target.cell)
	if bool(params.get("random_dir", false)):
		# A drunk shove: anywhere but back into the shover.
		var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		dirs.erase(-dir)
		var r: RandomNumberGenerator = ctx.rng if ctx.rng else RandomNumberGenerator.new()
		dir = dirs[r.randi() % dirs.size()]
	var distance := int(params.get("distance", 2))
	var dest: Vector2i = target.cell
	var slammed := false
	for _i in distance:
		var next := dest + dir
		var blocked := not ctx.grid.in_bounds(next) or not ctx.grid.is_walkable(next) \
			or ctx.grid.get_occupant(next) != null \
			or ctx.grid.get_height(next) - ctx.grid.get_height(dest) > 1
		if blocked:
			slammed = true
			break
		dest = next
	if dest != target.cell:
		target.force_move(dest, ctx.battle.animate)
	if slammed and target.is_alive():
		var impact := int(params.get("impact", 12))
		if target.has_status("unstable"):
			impact *= 2
			target.remove_status("unstable")
		var dealt: int = target.take_damage(impact)
		ctx.log_result(target, "slam", dealt)
		EventBus.camera_shake.emit(6.0, 0.25)
