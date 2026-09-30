extends RefCounted


func run(tree: SceneTree, args: PackedStringArray) -> void:
	var doc := CutsceneDoc.load_file(args[0])
	var cs := CutscenePlayer.new()
	tree.root.add_child(cs)
	cs.start(doc)
	cs.playing = false
	var probe := args.size() > 2 and args[2] == "--probe"
	var start := 3 if probe else 2
	for i in range(start, args.size()):
		var t := float(args[i])
		cs.render(t)
		for _f in 4:
			await tree.process_frame
		var img: Image = cs._final_vp.get_texture().get_image()
		if probe:
			var inner: Image = cs._cur_stage["inner"].get_texture().get_image()
			var out: Image = cs._cur_stage["out"].get_texture().get_image()
			print("t=", t, " inner ", inner.get_pixel(10, 10) * 255, " bg ", inner.get_pixel(200, 150) * 255, " out ", out.get_pixel(10, 10) * 255, " final ", img.get_pixel(10, 10) * 255)
		else:
			img.save_png("%s_%s.png" % [args[1], args[i]])
	print("godot frames done; warnings: ", doc.warnings)
