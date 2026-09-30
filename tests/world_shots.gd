extends SceneTree
## Docs screenshots of the World Painter and exploration.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1920x1080 -s res://tests/world_shots.gd -- <map_id> <out_prefix>
## Writes <out_prefix>_painter.png and <out_prefix>_explore.png.


func _initialize() -> void:
	await process_frame
	var body: RefCounted = load("res://tests/world_shots_body.gd").new()
	await body.run(self)
	quit()
