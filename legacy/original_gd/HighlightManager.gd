extends Node2D
class_name HighlightManager

@export var highlight_color: Color = Color(0.2, 1.0, 0.5, 0.4) # Movement Blue
@export var selection_color: Color = Color(1.0, 1.0, 1.0, 0.6) # Selection White
@export var target_color: Color = Color(1.0, 0.2, 0.2, 0.5)    # Combat Red
@export var hover_color: Color = Color(1.0, 1.0, 1.0, 0.3)    # Hover White
@export var cover_color: Color = Color(0.4, 0.7, 1.0, 0.6)     # Cover Blue/Cyan

var _highlight_sprite: ColorRect
var _current_tile: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	_setup_highlight_sprite()

func _setup_highlight_sprite() -> void:
	_highlight_sprite = ColorRect.new()
	_highlight_sprite.color = highlight_color
	_highlight_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_sprite.visible = false
	add_child(_highlight_sprite)

func update_highlight(tile_pos: Vector2i, world_pos: Vector2, size: Vector2) -> void:
	if tile_pos == _current_tile:
		return

	_current_tile = tile_pos

	if tile_pos == Vector2i(-1, -1):
		_highlight_sprite.visible = false
		return

	_highlight_sprite.visible = true
	_highlight_sprite.position = world_pos - (size / 2.0)
	_highlight_sprite.size = size

func set_highlight_color(color: Color) -> void:
	_highlight_sprite.color = color

func clear_highlight() -> void:
	_current_tile = Vector2i(-1, -1)
	_highlight_sprite.visible = false

func animate_to_tile(tile_pos: Vector2i, world_pos: Vector2, size: Vector2) -> void:
	_current_tile = tile_pos
	_highlight_sprite.visible = true
	_highlight_sprite.size = size

	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_highlight_sprite, "position", world_pos - (size / 2.0), 0.1)

func set_selection(is_selected: bool) -> void:
	_highlight_sprite.color = selection_color if is_selected else highlight_color

func highlight_range(tiles: Array[Vector2i], world_pos_offset: Vector2, size: Vector2) -> void:
	for tile in tiles:
		var marker = ColorRect.new()
		marker.color = highlight_color
		marker.size = size
		marker.position = world_pos_offset + (Vector2(tile.x, -tile.y) * size)
		add_child(marker)
		get_tree().create_timer(1.0).timeout.connect(marker.queue_free)

func highlight_target(tile: Vector2i, world_pos_offset: Vector2, size: Vector2) -> void:
	var marker = ColorRect.new()
	marker.color = target_color
	marker.size = size
	marker.position = world_pos_offset + (Vector2(tile.x, -tile.y) * size)
	add_child(marker)
	get_tree().create_timer(0.5).timeout.connect(marker.queue_free)

func highlight_cover(tile: Vector2i, world_pos_offset: Vector2, size: Vector2) -> void:
	var marker = ColorRect.new()
	marker.color = cover_color
	marker.size = size
	marker.position = world_pos_offset + (Vector2(tile.x, -tile.y) * size)
	add_child(marker)
	get_tree().create_timer(0.5).timeout.connect(marker.queue_free)

func highlight_danger_zone(tiles: Array[Vector2i], world_pos_offset: Vector2, size: Vector2) -> void:
	for tile in tiles:
		var marker = ColorRect.new()
		marker.color = Color.RED
		marker.size = size
		marker.position = world_pos_offset + (Vector2(tile.x, -tile.y) * size)
		add_child(marker)
		get_tree().create_timer(0.8).timeout.connect(marker.queue_free)

func highlight_ability_range(tiles: Array[Vector2i], world_pos_offset: Vector2, size: Vector2) -> void:
	for tile in tiles:
		var marker = ColorRect.new()
		marker.color = highlight_color
		marker.size = size
		marker.position = world_pos_offset + (Vector2(tile.x, -tile.y) * size)
		add_child(marker)
		# Ability range highlights persist until the action is cancelled or executed
***



func clear_highlights() -> void:
	for child in get_children():
		if child is ColorRect:
			child.queue_free()
)
)
)
