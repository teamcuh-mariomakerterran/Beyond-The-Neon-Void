extends Node2D
## TEMPLATE (proposal for known-gaps #36): FFT-style ground telegraph for pending charged casts.
## Add one under BattleMap.world (same space as tiles), e.g. in BattleMap._ready():
##     var tg := preload("res://src/grid/charge_telegraph.gd").new(); tg.grid = grid; world.add_child(tg)
## Reads CombatManager.turn_queue.pending_casts every frame (no state of its own), so it can
## never disagree with the rules. Presentation only: never touches gameplay state.
## Colours come from the same element palette as BattleMap._fx_color (HDR > 1 blooms).

var grid: IsometricGrid
var ticks_label := true
var _t := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = 1  # above floor tiles, below units (tune against IsometricGrid.draw_order)
	EventBus.ability_charging.connect(func(_u: Node, _a: Resource, _c: Vector2i, _ticks: int) -> void: queue_redraw())


func _process(delta: float) -> void:
	_t += delta
	if CombatManager.turn_queue and not CombatManager.turn_queue.pending_casts.is_empty():
		queue_redraw()


func _draw() -> void:
	if grid == null or CombatManager.turn_queue == null:
		return
	for cast: Dictionary in CombatManager.turn_queue.pending_casts:
		var caster: Node = cast["caster"]
		var ability: Ability = cast["ability"]
		if not is_instance_valid(caster) or ability == null:
			continue
		var col := _element_color(ability)
		var hostile_to_player: bool = int(caster.get("team")) != 0
		var ticks := int(cast["ticks_left"])
		# Faster pulse as the cast gets closer (stepped, not smooth: angular read).
		var rate := 2.0 + 6.0 / maxf(float(ticks), 1.0)
		var on := fmod(_t * rate, 1.0) < 0.6
		for c: Vector2i in ability.get_affected_cells(grid, caster.cell, cast["cell"]):
			var p := grid.grid_to_world(c)
			var hw := grid.tile_width * 0.5
			var hh := grid.tile_height * 0.5
			var dia := PackedVector2Array([p + Vector2(0, -hh), p + Vector2(hw, 0), p + Vector2(0, hh), p + Vector2(-hw, 0)])
			draw_colored_polygon(dia, Color(col.r, col.g, col.b, 0.18 if on else 0.08))
			var inner := PackedVector2Array()
			for v in dia:
				inner.append(p + (v - p) * 0.78)
			inner.append(inner[0])
			draw_polyline(inner, Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 0.9 if on else 0.45), 2.0 if hostile_to_player else 1.0)
		if ticks_label:
			var at := grid.grid_to_world(cast["cell"]) + Vector2(-4, -grid.tile_height * 0.9)
			draw_string(ThemeDB.fallback_font, at, str(ticks), HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(col.r * 1.8, col.g * 1.8, col.b * 1.8))


static func _element_color(ability: Ability) -> Color:
	# Mirror of BattleMap._fx_color (keep in sync, or make that function public and call it).
	match ability.damage_type:
		"plasma": return Color(2.2, 0.6, 1.2)
		"cryo": return Color(0.6, 1.6, 2.4)
		"electric": return Color(1.6, 1.6, 2.6)
		"void", "essence": return Color(1.4, 0.5, 2.4)
		"tech": return Color(0.5, 2.2, 1.4)
		"kinetic": return Color(1.0, 1.1, 2.4)
	return Color(2.0, 1.6, 0.8)
