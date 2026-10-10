class_name TerrainAbility
extends Ability
## Cartographer kit: rewrites the battlefield.
##
##  terrain.fault_line     A wall erupts along a line from the caster (shape LINE):
##                         empty cells become impassable, sight-blocking rock.
##  terrain.elevate        Raises/lowers the target cell by params.height_delta;
##                         its occupant rides along.
##  terrain.warp           Warp Coordinates: swaps the target cell with the caster's
##                         cell — terrain AND occupants trade places.
##  terrain.hazard         Seeds params.hazard ("neon_fire", "static", ...) on the AoE.


func _resolve_special(ctx: Context) -> void:
	var changed: Array[Vector2i] = []
	match special:
		"terrain.fault_line":
			changed = _fault_line(ctx)
		"terrain.elevate":
			changed = _elevate(ctx)
		"terrain.warp":
			changed = _warp(ctx)
		"terrain.hazard":
			changed = _hazard(ctx)
		"terrain.geomancy":
			_geomancy(ctx)
	if not changed.is_empty():
		EventBus.grid_changed.emit(changed)
		EventBus.camera_shake.emit(4.0, 0.25)


func _fault_line(ctx: Context) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in get_affected_cells(ctx.grid, ctx.caster.cell, ctx.target_cell):
		if ctx.grid.get_occupant(c) != null:
			continue
		var cell := ctx.grid.get_cell(c)
		cell.terrain = "rock_wall"
		cell.walkable = false
		cell.blocks_los = true
		cell.cover = IsometricGrid.COVER_FULL
		cell.height = mini(cell.height + int(params.get("rise", 2)), IsometricGrid.MAX_HEIGHT)
		out.append(c)
	return out


func _elevate(ctx: Context) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var delta := int(params.get("height_delta", 2))
	var c := ctx.target_cell
	ctx.grid.set_height(c, ctx.grid.get_height(c) + delta)
	var occ: Node = ctx.grid.get_occupant(c)
	if occ:
		occ.force_move(c, ctx.battle.animate)
	out.append(c)
	return out


func _warp(ctx: Context) -> Array[Vector2i]:
	var a: Vector2i = ctx.caster.cell
	var b := ctx.extra_cells[0] if not ctx.extra_cells.is_empty() else ctx.target_cell
	if a == b:
		return []
	var ua: Node = ctx.grid.get_occupant(a)
	var ub: Node = ctx.grid.get_occupant(b)
	ctx.grid.swap_cell_data(a, b)
	ctx.grid.clear_occupant(a)
	ctx.grid.clear_occupant(b)
	if ua:
		ua.force_move(b, ctx.battle.animate)
	if ub:
		ub.force_move(a, ctx.battle.animate)
	EventBus.play_sfx.emit("magic")
	return [a, b] as Array[Vector2i]


## Grid Geomancer: the ground under the TARGET decides the extra effect.
const GEOMANCY := {
	"metal_grate": ["electric", "shocked"],
	"coolant": ["cryo", "slow"],
	"neon_sign": ["plasma", "burning"],
	"essence_pool": ["essence", "essence_bleed"],
	"rubble": ["kinetic", "knockdown"],
	"glass": ["plasma", "blinded"],
}


func _geomancy(ctx: Context) -> void:
	var cell := ctx.grid.get_cell(ctx.target_cell)
	var target: Node = ctx.grid.get_occupant(ctx.target_cell)
	if cell == null or target == null or not target.is_alive():
		return
	var entry: Array = GEOMANCY.get(cell.terrain, ["kinetic", ""])
	var dmg := roundi(ctx.caster.get_stat("magic") * power * 0.6 * target.element_mult(entry[0]))
	var dealt: int = target.take_damage(maxi(dmg, 1))
	ctx.log_result(target, "damage", dealt)
	if entry[1] != "" and ctx.rng.randf() < 0.4:
		target.apply_status(entry[1], ctx.caster)


func _hazard(ctx: Context) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var hz := str(params.get("hazard", "neon_fire"))
	var turns := int(params.get("turns", 3))
	for c in get_affected_cells(ctx.grid, ctx.caster.cell, ctx.target_cell):
		if ctx.grid.is_walkable(c):
			ctx.grid.set_hazard(c, hz, turns)
			out.append(c)
	return out
