extends SceneTree
## Renders every particle preset over little iso patches and saves a PNG:
## xvfb-run -a godot --path . --rendering-method gl_compatibility -s res://tests/particle_preview.gd [-- <out.png> [--no-flash]]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	await process_frame  # autoloads finish _ready
	var body: RefCounted = load("res://tests/particle_preview_body.gd").new()
	await body.run(self, args)
	quit()
