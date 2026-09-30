class_name TileView
extends Node2D
## Draws one grid cell as an isometric column (top face + two side faces).
## Uses the terrain's texture when one is assigned (see data/terrain.json
## "texture"), otherwise a flat neon-noir palette. Highlights are drawn on the
## tile itself so units standing in front correctly occlude them.

const HAZARD_COLORS := {
	"neon_fire": Color(2.2, 0.35, 0.9, 0.55),
	"static": Color(0.5, 1.6, 2.2, 0.45),
	"essence_leak": Color(1.2, 0.4, 2.2, 0.5),
}

var grid: IsometricGrid
var cell: Vector2i
var terrain_def: Dictionary = {}
var highlight: Color = Color.TRANSPARENT
var outline: Color = Color.TRANSPARENT
var hovered: bool = false
## Format-2 maps: WorldRenderer draws the tiles; this only draws highlights.
var overlay_only: bool = false
var _texture: Texture2D
var _time: float = 0.0


func setup(p_grid: IsometricGrid, p_cell: Vector2i) -> void:
	grid = p_grid
	cell = p_cell
	refresh()


func refresh() -> void:
	var c := grid.get_cell(cell)
	terrain_def = ContentDB.terrain.get(c.terrain, {})
	position = grid.grid_to_world(cell, false)
	z_index = IsometricGrid.draw_order(cell) * 2
	_texture = null
	var tex_path := str(terrain_def.get("texture", ""))
	if c.tile_id != "":
		tex_path = str(ContentDB.terrain.get(c.tile_id, {}).get("texture", tex_path))
	if tex_path != "":
		_texture = ForgeStore.load_texture(tex_path)  # works before the editor imports new files
	set_process(c.hazard != "" or terrain_def.has("glow"))
	queue_redraw()


func set_highlight(color: Color, border: Color = Color.TRANSPARENT) -> void:
	highlight = color
	outline = border
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var c := grid.get_cell(cell)
	var hw := grid.tile_width * 0.5
	var hh := grid.tile_height * 0.5
	var lift := c.height * grid.height_step
	var top := Vector2(0, -lift)
	var n := top + Vector2(0, -hh)
	var e := top + Vector2(hw, 0)
	var s := top + Vector2(0, hh)
	var w := top + Vector2(-hw, 0)
	var top_col := Color(str(terrain_def.get("color", "#2a2438")))
	var side_col := Color(str(terrain_def.get("side", "#1a1626")))
	if overlay_only:
		_draw_overlays(c, PackedVector2Array([n, e, s, w]), top, n, e, s, w)
		return
	# Side faces (always drawn down to ground level, plus a small base lip).
	var base := lift + 6.0
	draw_colored_polygon(PackedVector2Array([w, s, s + Vector2(0, base), w + Vector2(0, base)]), side_col)
	draw_colored_polygon(PackedVector2Array([s, e, e + Vector2(0, base), s + Vector2(0, base)]), side_col.darkened(0.25))
	# Top face.
	var diamond := PackedVector2Array([n, e, s, w])
	if _texture:
		var uvs := PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)])
		draw_colored_polygon(diamond, Color.WHITE, uvs, _texture)
	else:
		draw_colored_polygon(diamond, top_col)
	# Neon edge lines give the grid its look; tall blockers get a brighter rim.
	var rim := Color(0.35, 0.25, 0.55, 0.9)
	if terrain_def.has("glow"):
		var g := Color(str(terrain_def["glow"]))
		rim = Color(g.r * 1.8, g.g * 1.8, g.b * 1.8, 0.7 + 0.3 * sin(_time * 3.0 + cell.x))
	draw_polyline(PackedVector2Array([n, e, s, w, n]), rim, 1.0)
	_draw_overlays(c, diamond, top, n, e, s, w)


func _draw_overlays(c: IsometricGrid.Cell, diamond: PackedVector2Array, top: Vector2, n: Vector2, e: Vector2, s: Vector2, w: Vector2) -> void:
	if c.hazard != "":
		var hz: Color = HAZARD_COLORS.get(c.hazard, Color(1, 1, 1, 0.3))
		hz.a *= 0.7 + 0.3 * sin(_time * 5.0 + cell.y)
		draw_colored_polygon(diamond, hz)
	if highlight.a > 0.0:
		draw_colored_polygon(diamond, highlight)
	if outline.a > 0.0:
		draw_polyline(PackedVector2Array([n, e, s, w, n]), outline, 2.0)
	if hovered:
		draw_polyline(PackedVector2Array([n, e, s, w, n]), Color(1.8, 1.8, 1.8, 1.0), 2.5)
	if grid.get_corpse(cell) != null:
		# Faint essence wisp marks a body that can be revived or raised.
		var wisp := Color(1.4, 0.6, 2.0, 0.55 + 0.25 * sin(_time * 2.0))
		draw_circle(top + Vector2(0, -4), 5.0, wisp)
