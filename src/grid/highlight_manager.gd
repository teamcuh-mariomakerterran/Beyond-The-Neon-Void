class_name HighlightManager
extends RefCounted
## Tile highlight layers (move range, attack range, AoE footprint, threat).
## Colors are applied onto TileViews so units correctly occlude them.

const MOVE := Color(0.25, 1.0, 0.62, 0.28)
const MOVE_EDGE := Color(0.25, 1.6, 0.9, 0.9)
const TARGET := Color(1.0, 0.18, 0.5, 0.22)
const TARGET_EDGE := Color(1.8, 0.3, 0.8, 0.9)
const AOE := Color(1.0, 0.75, 0.2, 0.45)
const AOE_EDGE := Color(2.0, 1.4, 0.3, 1.0)
const THREAT := Color(1.0, 0.1, 0.1, 0.16)
const PATH := Color(0.4, 1.6, 2.0, 0.55)
## Charged casts waiting to land: where the spell will hit, by the caster's side.
const CAST_FOE := Color(0.75, 0.2, 1.0, 0.24)
const CAST_FOE_EDGE := Color(1.7, 0.45, 2.0, 0.85)
const CAST_ALLY := Color(0.2, 0.8, 1.0, 0.18)
const CAST_ALLY_EDGE := Color(0.4, 1.6, 2.0, 0.75)
## Layers that survive clear_highlights() (they track battle state, not the cursor).
const STICKY := ["cast_foe", "cast_ally"]

var tiles: Dictionary = {}  # Vector2i -> TileView
var _layers: Dictionary = {}  # layer name -> {cell: [fill, edge]}
const ORDER := ["threat", "cast_ally", "cast_foe", "range", "path", "aoe"]


func set_layer(layer: String, cells: Array, fill: Color, edge: Color = Color.TRANSPARENT) -> void:
	var d := {}
	for c: Vector2i in cells:
		d[c] = [fill, edge]
	_layers[layer] = d
	_apply()


func clear_layer(layer: String) -> void:
	_layers.erase(layer)
	_apply()


func clear_highlights() -> void:
	for k: String in _layers.keys():
		if not k in STICKY:
			_layers.erase(k)
	_apply()


## Marks every pending charged cast's footprint (call when casts change).
func show_casts(grid: IsometricGrid, casts: Array, player_team: int = 0) -> void:
	var foe: Array = []
	var ally: Array = []
	for c: Dictionary in casts:
		var caster: Node = c.get("caster")
		if caster == null or not is_instance_valid(caster) or not caster.is_alive():
			continue
		var cells: Array = (c["ability"] as Ability).get_affected_cells(grid, caster.cell, c["cell"])
		(ally if int(caster.team) == player_team else foe).append_array(cells)
	_layers["cast_foe"] = {}
	_layers["cast_ally"] = {}
	for cell: Vector2i in foe:
		_layers["cast_foe"][cell] = [CAST_FOE, CAST_FOE_EDGE]
	for cell: Vector2i in ally:
		_layers["cast_ally"][cell] = [CAST_ALLY, CAST_ALLY_EDGE]
	_apply()


func highlight_range(cells: Array, is_move: bool) -> void:
	if is_move:
		set_layer("range", cells, MOVE, MOVE_EDGE)
	else:
		set_layer("range", cells, TARGET, TARGET_EDGE)


func highlight_target(cells: Array) -> void:
	set_layer("aoe", cells, AOE, AOE_EDGE)


func highlight_danger_zone(cells: Array) -> void:
	set_layer("threat", cells, THREAT)


func _apply() -> void:
	for c: Vector2i in tiles:
		var fill := Color.TRANSPARENT
		var edge := Color.TRANSPARENT
		for layer: String in ORDER:
			var d: Dictionary = _layers.get(layer, {})
			if d.has(c):
				fill = d[c][0]
				if d[c][1].a > 0.0:
					edge = d[c][1]
		# A pending cast's outline stays visible under the move / target range;
		# only the aim footprint (aoe) draws over it.
		if not (_layers.get("aoe", {}) as Dictionary).has(c):
			for warn: String in ["cast_ally", "cast_foe"]:
				if (_layers.get(warn, {}) as Dictionary).has(c):
					edge = _layers[warn][c][1]
		var tv: TileView = tiles[c]
		if tv.highlight != fill or tv.outline != edge:
			tv.set_highlight(fill, edge)
