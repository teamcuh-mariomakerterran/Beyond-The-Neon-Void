extends Node2D

# MapEditor.gd - A tool for creating and saving isometric tactical maps.
# Handles tile placement, elevation heights, and JSON export for the CampaignManager.

@export var tile_width: int = 64
@export var tile_height: int = 32
@export var default_map_size: Vector2i = Vector2i(20, 20)

var current_map_size: Vector2i = Vector2i(20, 20)
var grid_data: Dictionary = {} # Key: "x,y", Value: {height: int, type: String}
var is_painting: bool = false
var current_brush_height: int = 0
var current_brush_type: String = "concrete"

@onready var grid_container: Node2D = Node2D.new()

func _ready():
	add_child(grid_container)
	grid_container.name = "GridContainer"
	setup_initial_grid()

func setup_initial_grid():
	grid_data.clear()
	for x in range(current_map_size.x):
		for y in range(current_map_size.y):
			grid_data[str(x) + "," + str(y)] = {"height": 0, "type": "concrete"}
	redraw_grid()

func _process(_delta):
	if Input.is_action_just_pressed("mouse_left"):
		is_painting = true
	if Input.is_action_just_released("mouse_left"):
		is_painting = false

	if is_painting:
		var mouse_pos = get_global_mouse_position()
		var grid_pos = world_to_grid(mouse_pos)
		if is_within_bounds(grid_pos):
			paint_tile(grid_pos)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	# Standard 2:1 Isometric projection inverse
	var x_iso = (world_pos.x / (tile_width / 2))
	var y_iso = (world_pos.y / (tile_height / 2))

	var grid_x = (x_iso + y_iso) / 2
	var grid_y = (y_iso - x_iso) / 2

	return Vector2i(round_to_int(grid_x), round_to_int(grid_y))

func round_to_int(val: float) -> int:
	return int(round(val))

func is_within_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < current_map_size.x and pos.y >= 0 and pos.y < current_map_size.y

func paint_tile(pos: Vector2i):
	var key = str(pos.x) + "," + str(pos.y)
	grid_data[key]["height"] = current_brush_height
	grid_data[key]["type"] = current_brush_type
	update_tile_visual(pos)

func update_tile_visual(pos: Vector2i):
	redraw_grid()

func redraw_grid():
	# Clear previous visuals
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()

	for key in grid_data.keys():
		var parts = key.split(",")
		var x = int(parts[0])
		var y = int(parts[1])
		var data = grid_data[key]

		var tile = ColorRect.new()
		tile.custom_minimum_size = Vector2(tile_width, tile_height)
		tile.color = get_color_for_height(data.height)

		# Isometric position calculation
		var world_x = (x - y) * (tile_width / 2)
		var world_y = (x + y) * (tile_height / 2)
		tile.position = Vector2(world_x, world_y)
		grid_container.add_child(tile)

func get_color_for_height(h: int) -> Color:
	if h <= 0: return Color.DARK_GRAY
	if h == 1: return Color.GRAY
	ifif h == 1: return Color.GRAY
	if h >= 2: return Color.SLATE_GRAY
	return Color.BLACK

func save_map_to_json(path: String):
	var map_data = []
	for tile in grid_container.get_children():
		var data = {
			"x": tile.grid_pos.x,
			"y": tile.grid_pos.y,
			"height": tile.height
		}
		map_data.append(data)

	var json_string = JSON.stringify(map_data)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

func load_map_from_json(path: String):
	if not FileAccess.file_exists(path):
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		return

	var map_data = json.get_data_from_string() # This is simplified; usually get_data()
	# Logic to clear existing grid and rebuild based on loaded data
	for entry in map_data:
		create_tile(entry.x, entry.y, entry.height)

# --- UI HANDLERS ---

func _on_height_up_pressed():
	current_brush_height = min(current_brush_height + 1, 5)
	update_brush_indicator()

func _on_height_down_pressed():
	current_brush_height = max(current_brush_height - 1, 0)
	update_brush_indicator()

func update_brush_indicator():
	$UI/BrushLabel.text = "Height: " + str(current_brush_height)
)
)
)
)
)
)
