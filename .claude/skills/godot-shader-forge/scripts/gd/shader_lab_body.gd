extends RefCounted

var tree: SceneTree


func run(p_tree: SceneTree, args: PackedStringArray) -> int:
	tree = p_tree
	var o := {}
	for a in args:
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			o[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if DisplayServer.get_name() == "headless":
		printerr("shader_lab: needs a display (xvfb-run -a on Linux) — headless never renders.")
		return 3
	var code := _load_code(o)
	if code == "":
		printerr("shader_lab: give --shader=, --inline=FILE:CONST or --file=")
		return 2
	code = code.replace("render_mode %s;", "render_mode blend_mix;")
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var params := {}
	if o.has("status"):
		var look: Dictionary = StatusLook.combine(str(o["status"]).split(",", false))
		for k: String in StatusLook.NUMS:
			params["sink_px" if k == "sink" else k] = float(look[k]) * (StatusLook.SINK_PX if k == "sink" else 1.0)
		params["tint"] = look["tint"]
	if o.has("params"):
		var extra: Variant = JSON.parse_string(str(o["params"]))
		if extra is Dictionary:
			params.merge(extra, true)
		else:
			printerr("shader_lab: --params is not a JSON object")
			return 2
	for k: String in params:
		var v: Variant = params[k]
		if v is String and str(v).begins_with("#"):
			v = Color(str(v))
		elif v is Array and (v as Array).size() in [3, 4]:
			v = Color(v[0], v[1], v[2], v[3] if (v as Array).size() == 4 else 1.0)
		mat.set_shader_parameter(k, v)
	var size := tree.root.get_visible_rect().size
	var bg := ColorRect.new()
	bg.color = Color(str(o.get("bg", "#0a0614")))
	bg.size = size
	tree.root.add_child(bg)
	var scale := float(o.get("scale", "6"))
	var crop := Rect2i()
	if o.has("screen"):
		_test_scene(size)
		var rect := ColorRect.new()
		rect.size = size
		rect.material = mat
		tree.root.add_child(rect)
	else:
		var spr := Sprite2D.new()
		spr.texture = _texture(str(o.get("tex", "")))
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2(scale, scale)
		spr.centered = false
		# StatusLook coords: feet at local y = 0 → offset the sprite up by its height.
		spr.offset = -Vector2(spr.texture.get_width() * 0.5, spr.texture.get_height())
		spr.position = Vector2(size.x * 0.5, size.y * 0.8)
		spr.material = mat
		tree.root.add_child(spr)
		# Crop each frame to the sprite (plus room for heat/sink/glow) in window pixels.
		var r := Rect2(spr.offset, spr.texture.get_size())
		r = r.grow_individual(8, 8, 8, 8 + StatusLook.SINK_PX / scale)
		var xf := tree.root.get_final_transform() * spr.get_global_transform_with_canvas()
		var a := xf * r.position
		var b := xf * r.end
		crop = Rect2i(Vector2i(a.floor()), Vector2i((b - a).ceil()))
	var frames := int(o.get("frames", "4"))
	var interval := float(o.get("interval", "0.25"))
	var shots: Array[Image] = []
	for i in frames:
		await tree.create_timer(interval if i > 0 else 0.1).timeout
		await RenderingServer.frame_post_draw
		var img := tree.root.get_texture().get_image()
		if crop.size.x > 0:
			img = img.get_region(crop.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		shots.append(img)
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var strip := Image.create(w * frames, h, false, shots[0].get_format())
	for i in frames:
		strip.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	var out := str(o.get("out", "user://shader_lab.png"))
	var err := strip.save_png(out)
	print("shader_lab: %s (%d×%d, %d frame(s), params %s)" % [out if err == OK else "SAVE FAILED " + error_string(err), strip.get_width(), h, frames, JSON.stringify(params)])
	return 0 if err == OK else 1


func _load_code(o: Dictionary) -> String:
	if o.has("shader"):
		return FileAccess.get_file_as_string(str(o["shader"]))
	if o.has("file"):
		return FileAccess.get_file_as_string(str(o["file"]))
	if o.has("inline"):
		var parts := str(o["inline"]).rsplit(":", true, 1)
		var src := FileAccess.get_file_as_string(parts[0])
		var re := RegEx.create_from_string("(?s)const\\s+" + parts[1] + "\\s*(?::=|=|:\\s*String\\s*=)\\s*\"\"\"(.*?)\"\"\"")
		var m := re.search(src)
		return m.get_string(1) if m else ""
	return ""


func _texture(path: String) -> Texture2D:
	if path != "":
		var img := Image.load_from_file(path if not path.begins_with("res://") else ProjectSettings.globalize_path(path))
		if img:
			return ImageTexture.create_from_image(img)
		printerr("shader_lab: could not load %s, using the stand-in figure" % path)
	# Stand-in 32×48 figure: helmet, visor, torso, legs. Enough to read tints, cracks, dissolve, sink.
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	var body := Color(0.32, 0.36, 0.52)
	var trim := Color(1.0, 0.18, 0.55)
	for y in 48:
		for x in 32:
			var c := Color(0, 0, 0, 0)
			var dx := x - 16
			if y < 12 and dx * dx + (y - 7) * (y - 7) < 36:
				c = body.lightened(0.15)
				if y >= 6 and y <= 8 and absi(dx) < 5:
					c = Color(0.2, 1.0, 1.0)
			elif y >= 12 and y < 30 and absi(dx) < 8 - (y - 12) / 6:
				c = body
				if absi(dx) == 7 - (y - 12) / 6 or y == 21:
					c = trim
			elif y >= 30 and y < 47 and (absi(dx - 4) < 3 or absi(dx + 4) < 3):
				c = body.darkened(0.2)
				if y == 46:
					c = trim
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _test_scene(size: Vector2) -> void:
	# Neon test card: HDR stripes (glow > 1.0), a checker floor, text-ish bars.
	var img := Image.create(64, 36, false, Image.FORMAT_RGBA8)
	for y in 36:
		for x in 64:
			var c := Color(0.06, 0.03, 0.12)
			if y > 22:
				c = Color(0.12, 0.1, 0.2) if ((x / 4 + y / 4) % 2) == 0 else Color(0.08, 0.06, 0.14)
			img.set_pixel(x, y, c)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.size = size
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tree.root.add_child(tr)
	var cols := [Color(3.0, 0.4, 1.6), Color(0.4, 2.6, 3.0), Color(3.0, 2.2, 0.3)]
	for i in 3:
		var bar := ColorRect.new()
		bar.color = cols[i]
		bar.position = Vector2(size.x * (0.2 + 0.25 * i), size.y * 0.25)
		bar.size = Vector2(size.x * 0.06, size.y * 0.35)
		tree.root.add_child(bar)
