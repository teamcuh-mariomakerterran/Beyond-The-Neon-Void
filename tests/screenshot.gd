extends SceneTree
## Renders a scene and saves a PNG (visual smoke test / docs).
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tests/screenshot.gd -- <scene> <out.png> [frames] [mission]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: String = args[0] if args.size() > 0 else "res://scenes/main.tscn"
	var out: String = args[1] if args.size() > 1 else "user://shot.png"
	var frames: int = int(args[2]) if args.size() > 2 else 120
	await process_frame
	if args.size() > 3:
		root.get_node("CampaignManager").current_mission_id = args[3]
	change_scene_to_file(scene)
	for i in frames:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
