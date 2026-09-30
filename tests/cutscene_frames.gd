extends SceneTree
## Renders cutscene frames to PNG (visual regression vs. the builder):
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tests/cutscene_frames.gd -- <file> <out_prefix> t1 t2 ...


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	await process_frame
	var body: RefCounted = load("res://tests/cutscene_frames_body.gd").new()
	await body.run(self, args)
	quit()
