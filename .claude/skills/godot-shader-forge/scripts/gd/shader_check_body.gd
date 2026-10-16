extends RefCounted

var tree: SceneTree


func run(p_tree: SceneTree, args: PackedStringArray) -> int:
	tree = p_tree
	var only := ""
	for a in args:
		if a.begins_with("--only="):
			only = a.substr(7)
	if DisplayServer.get_name() == "headless":
		print("@@FATAL headless display: shaders are not compiled. Run with a display (xvfb-run on Linux) and --rendering-method gl_compatibility.")
		return 3
	print("@@RENDERER %s %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	var items: Array = []  # [{id, code}]
	for f in _files("res://", ".gdshader"):
		items.append({"id": f, "code": FileAccess.get_file_as_string(f)})
	for f in _files("res://src", ".gd"):
		var src := FileAccess.get_file_as_string(f)
		var re := RegEx.create_from_string("(?s)const\\s+([A-Z_0-9]+)\\s*(?::=|=|:\\s*String\\s*=)\\s*\"\"\"(.*?)\"\"\"")
		for m in re.search_all(src):
			if m.get_string(2).contains("shader_type"):
				items.append({"id": "%s:%s" % [f, m.get_string(1)], "code": m.get_string(2)})
		# sh.code = """...""" assignments (e.g. battle_map backdrop)
		var re2 := RegEx.create_from_string("(?s)\\.code\\s*=\\s*\"\"\"(.*?)\"\"\"")
		var n := 0
		for m in re2.search_all(src):
			if m.get_string(1).contains("shader_type"):
				n += 1
				items.append({"id": "%s:code#%d" % [f, n], "code": m.get_string(1)})
	var host := Node2D.new()
	tree.root.add_child(host)
	var tex := _checker()
	var count := 0
	for it: Dictionary in items:
		if only != "" and not str(it["id"]).contains(only):
			continue
		var code := str(it["code"]).replace("render_mode %s;", "render_mode blend_mix;")
		print("@@BEGIN %s" % it["id"])
		var sh := Shader.new()
		sh.code = code
		var mat := ShaderMaterial.new()
		mat.shader = sh
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.material = mat
		host.add_child(spr)
		await tree.process_frame
		await tree.process_frame
		spr.queue_free()
		await tree.process_frame
		print("@@END %s" % it["id"])
		count += 1
	print("@@DONE %d shader(s)" % count)
	return 0


func _checker() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, Color(1, 0.2, 0.7) if ((x / 8 + y / 8) % 2) == 0 else Color(0.1, 0.9, 1.0))
	return ImageTexture.create_from_image(img)


func _files(dir: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with(".") or sub in ["legacy", "addons", "build", "export"]:
			continue
		if FileAccess.file_exists(dir.path_join(sub).path_join(".gdignore")):
			continue
		out.append_array(_files(dir.path_join(sub), ext))
	return out
