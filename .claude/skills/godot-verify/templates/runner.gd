extends SceneTree
## Template -s runner. Copy next to body.gd. Never name autoloads in this file.
##   godot --headless --path <repo> -s <abs>/runner.gd -- --any=args
func _initialize() -> void:
	await process_frame
	var body: GDScript = load(get_script().resource_path.get_base_dir().path_join("body.gd"))
	if body == null or not body.can_instantiate():
		printerr("runner: body.gd does not compile")
		quit(2)
		return
	var code: int = await body.new().run(self, OS.get_cmdline_user_args())
	quit(code)
