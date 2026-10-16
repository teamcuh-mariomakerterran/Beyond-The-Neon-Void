extends SceneTree
## Compiles EVERY shader in the project on a real renderer and reports errors per shader.
## Headless (dummy renderer) never compiles shaders, so this needs a display:
##   Windows:  godot --path <repo> --rendering-method gl_compatibility -s <abs>/shader_check.gd -- [--forward] [--only=substr]
##   Linux CI: xvfb-run -a godot --path <repo> --rendering-method gl_compatibility -s <abs>/shader_check.gd
## Covers: *.gdshader files AND inline shaders kept as GDScript string constants
## ("""...shader_type canvas_item;...""", the BTNV convention). `render_mode %s;`
## templates are filled with blend_mix. Each shader is drawn for 2 frames between
## "@@BEGIN <id>" / "@@END <id>" markers; the wrapper (shader_check.py / .ps1) maps
## any "SHADER ERROR" lines between markers to that shader. Exit code is always 0
## here; the wrapper decides pass/fail.
func _initialize() -> void:
	await process_frame
	var body: GDScript = load(get_script().resource_path.get_base_dir().path_join("shader_check_body.gd"))
	if body == null or not body.can_instantiate():
		printerr("shader_check: body does not compile")
		quit(2)
		return
	quit(await body.new().run(self, OS.get_cmdline_user_args()))
