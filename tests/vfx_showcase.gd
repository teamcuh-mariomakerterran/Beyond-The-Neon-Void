extends SceneTree
## Renders every VFX effect at its best moment on a dark iso floor (4×6) and a
## 3-frame plasma_explosion sequence:
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1920x1080 -s res://tests/vfx_showcase.gd [-- <out.png> <sequence.png>]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	await process_frame  # autoloads finish _ready
	var body: RefCounted = load("res://tests/vfx_showcase_body.gd").new()
	await body.run(self, args)
	quit()
