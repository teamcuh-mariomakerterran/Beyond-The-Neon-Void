class_name AnchorMarks
extends Node2D
## Floating pins over interaction anchors (battle and explore). Hidden loot
## and unfound traps draw nothing; pins bob, pulse when the active unit /
## player is in reach, and pressed sequence switches stay lit with their step.

var ix: Interactions
## cell -> world position of the cell's top surface.
var to_pos: Callable
## Cell of whoever could use an anchor right now ((-999, -999) = nobody).
var actor_cell: Callable
var lift: float = 36.0
## Pin size multiplier (tile_width / 64 keeps pins readable on big tiles).
var size: float = 1.0


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if ix == null or ix.world == null or not to_pos.is_valid():
		return
	var t := Time.get_ticks_msec() / 1000.0
	var font := NeonTheme.mono()
	var who: Vector2i = actor_cell.call() if actor_cell.is_valid() else Vector2i(-999, -999)
	for a: Dictionary in ix.world.anchors:
		if not ix.is_visible(a):
			continue
		var c := Interactions.cell_of(a)
		var info := Interactions.kind_info(str(a.get("kind", "")))
		var col: Color = info["color"]
		var base: Vector2 = to_pos.call(c)
		var at := base + Vector2(0, -lift + sin(t * 2.6 + c.x * 0.7 + c.y) * 3.0)
		var lit := ix.is_lit(a)
		var near := ix.in_reach(a, who)
		var glow := 1.6 if lit else (1.3 + 0.3 * sin(t * 5.0) if near else 1.0)
		draw_line(base + Vector2(0, -4), at, Color(col, 0.45), 1.5 * size)
		draw_set_transform(at, 0.0, Vector2(size, size))
		draw_circle(Vector2.ZERO, 11.0 + (2.0 if near else 0.0), Color(col.r * glow, col.g * glow, col.b * glow, 0.92))
		draw_arc(Vector2.ZERO, 14.0, 0, TAU, 24, Color(col, 0.6), 1.5)
		draw_string(font, Vector2(-6, 6), str(info["glyph"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, NeonTheme.BG)
		if lit:
			draw_string(font, Vector2(12, -8), str(int(a.get("step", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		if near:
			var label := "%s %s" % [info["verb"], Interactions.title(a).to_upper()]
			draw_string(font, Vector2(-label.length() * 3.6, -20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		draw_set_transform(Vector2.ZERO)
