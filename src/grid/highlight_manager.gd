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

var tiles: Dictionary = {}  # Vector2i -> TileView
var _layers: Dictionary = {}  # layer name -> {cell: [fill, edge]}
const ORDER := ["threat", "range", "path", "aoe"]


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
	_layers.clear()
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
		var tv: TileView = tiles[c]
		if tv.highlight != fill or tv.outline != edge:
			tv.set_highlight(fill, edge)
