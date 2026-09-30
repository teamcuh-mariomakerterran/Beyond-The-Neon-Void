extends SceneTree
## Rescans assets/tiles and writes data/tiles.json (see TileIndex):
## godot --headless --path . -s res://tests/scan_tiles.gd [-- <root>]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	await process_frame  # autoloads finish _ready
	var body: RefCounted = load("res://tests/scan_tiles_body.gd").new()
	body.run(args)
	quit()
