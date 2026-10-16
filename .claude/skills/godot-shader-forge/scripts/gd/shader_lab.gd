extends SceneTree
## Shader lab: render one shader with chosen uniforms to a PNG contact strip (N time samples),
## so you can SEE a look while iterating. Needs a display (xvfb-run on Linux).
##   godot --path <repo> --rendering-method gl_compatibility --resolution 1280x720 -s <abs>/shader_lab.gd -- \
##     (--shader=res://src/vfx/status_look.gdshader | --inline=res://src/vfx/hd2d_post.gd:SHADER | --file=C:/x/y.gdshader)
##     [--params='{"glitch":0.8,"tint":"#ff2e88"}'] [--status=burning,shocked] [--tex=res://...png | C:/...png]
##     [--screen] [--frames=4] [--interval=0.25] [--scale=6] [--bg=#0a0614] --out=C:/temp/lab.png
## --status  fills status_look uniforms from data/status_looks.json via StatusLook.combine (real blend rules).
## --screen  for hint_screen_texture shaders (post, shockwave, glitch): draws a neon test scene, then the
##           shader on a full-screen ColorRect above it.
func _initialize() -> void:
	await process_frame
	var body: GDScript = load(get_script().resource_path.get_base_dir().path_join("shader_lab_body.gd"))
	if body == null or not body.can_instantiate():
		printerr("shader_lab: body does not compile")
		quit(2)
		return
	quit(await body.new().run(self, OS.get_cmdline_user_args()))
