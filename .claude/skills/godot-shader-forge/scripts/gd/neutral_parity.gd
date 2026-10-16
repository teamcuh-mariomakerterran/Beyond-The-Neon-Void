extends SceneTree
## Neutral-parity test: a canvas_item shader at its DEFAULT uniforms must not change a sprite
## (a unit with no statuses must look exactly like its art). Draws a mid-grey, half-alpha,
## modulated sprite with no material and with each shader, and compares pixels.
##   godot --path <repo> --rendering-method gl_compatibility -s <abs>/neutral_parity.gd -- \
##     --shader=res://src/vfx/status_look.gdshader[,res://other.gdshader] [--tol=0.01]
## Needs a display (xvfb-run -a on Linux). Exit 1 if any shader drifts more than tol.
## Self-contained (no autoload class names), so no runner/body split is needed.
func _initialize() -> void:
	await process_frame
	var opts := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if DisplayServer.get_name() == "headless":
		printerr("neutral_parity: needs a display (xvfb-run -a on Linux)")
		quit(3)
		return
	var paths: PackedStringArray = str(opts.get("shader", "res://src/vfx/status_look.gdshader")).split(",", false)
	var tol := float(opts.get("tol", "0.01"))
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 0.5))
	var tex := ImageTexture.create_from_image(img)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(4096, 4096)
	root.add_child(bg)
	var sprites: Array[Sprite2D] = []
	for i in paths.size() + 1:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.modulate = Color(1.0, 0.6, 0.8, 1.0)
		s.position = Vector2(20 + i * 40, 20)
		if i > 0:
			var sh := Shader.new()
			sh.code = FileAccess.get_file_as_string(paths[i - 1])
			var m := ShaderMaterial.new()
			m.shader = sh
			s.material = m
		root.add_child(s)
		sprites.append(s)
	await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	var xf := root.get_final_transform()
	var ref := shot.get_pixelv(Vector2i(xf * (sprites[0].position + Vector2(8, 8))))
	var bad := 0
	for i in paths.size():
		var c := shot.get_pixelv(Vector2i(xf * (sprites[i + 1].position + Vector2(8, 8))))
		var d := maxf(maxf(absf(c.r - ref.r), absf(c.g - ref.g)), absf(c.b - ref.b))
		var ok := d <= tol
		bad += 0 if ok else 1
		print("%s %s  ref %s  got %s  (max delta %.3f)" % ["PASS" if ok else "FAIL", paths[i], ref, c, d])
	quit(1 if bad > 0 else 0)
