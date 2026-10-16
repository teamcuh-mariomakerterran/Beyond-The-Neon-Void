extends RefCounted

const PANEL := Vector2(360, 300)
const TILE := Vector2(96, 48)

var tree: SceneTree


class Floor extends Node2D:
	var grounds: Array = []
	func _draw() -> void:
		for g: Vector2 in grounds:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c := g + Vector2((dx - dy) * TILE.x * 0.5, (dx + dy) * TILE.y * 0.5)
					var pts := PackedVector2Array([c + Vector2(0, -TILE.y * 0.5), c + Vector2(TILE.x * 0.5, 0), c + Vector2(0, TILE.y * 0.5), c + Vector2(-TILE.x * 0.5, 0)])
					draw_colored_polygon(pts, Color(0.09, 0.07, 0.15) if (dx + dy) % 2 == 0 else Color(0.07, 0.05, 0.12))
					draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.25, 0.15, 0.4, 0.6), 1.0)


class Dummy extends Node2D:
	var col := Color.WHITE
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(7, -30), Vector2(-7, -30)]), col.darkened(0.5))
		draw_circle(Vector2(0, -37), 7.0, col.darkened(0.4))
		draw_rect(Rect2(-5, -39, 10, 3), col)


func run(p_tree: SceneTree, args: PackedStringArray) -> int:
	tree = p_tree
	var o := {}
	for a in args:
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			o[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if DisplayServer.get_name() == "headless":
		printerr("vfx_shot: needs a display (xvfb-run -a on Linux)")
		return 3
	if o.has("def"):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(o["def"])))
		if not v is Dictionary:
			printerr("vfx_shot: --def is not JSON")
			return 2
		var effs: Dictionary
		if v.has("parts"):
			effs = {str(o.get("effect", "candidate")): v}  # bare def
		elif v.has("effects"):
			effs = v["effects"]
		else:
			effs = v  # {id: def, ...}
		for k: String in effs:
			VFX.data()["effects"][k] = effs[k]
			if not o.has("effect"):
				o["effect"] = k
	var ids: Array[String] = []
	if o.has("ability"):
		var ab: Ability = ContentDB.get_ability(str(o["ability"])) if ContentDB.has_method("get_ability") else null
		if ab == null:
			printerr("vfx_shot: unknown ability %s" % o["ability"])
			return 2
		var plan := VFX.plan_for_ability(ab, true)
		print("vfx_shot: plan for %s = %s" % [o["ability"], plan])
		for k in ["cast", "travel", "impact"]:
			if str(plan[k]) != "":
				ids.append(str(plan[k]))
	else:
		ids.append(str(o.get("effect", "impact_kinetic")))
	for id in ids:
		if not VFX.has_effect(id):
			printerr("vfx_shot: unknown effect %s (known: %s)" % [id, ", ".join(VFX.effect_ids())])
			return 2
	var times: Array = []
	for t in str(o.get("times", "0.05,0.12,0.25,0.5")).split(",", false):
		times.append(float(t))
	var scale := float(o.get("scale", "1.2"))
	var to := _v2(str(o.get("to", "120,-36")))
	var targets: Array = []
	if o.has("targets"):
		for s in str(o["targets"]).split(";", false):
			targets.append(_v2(s))
	VFX.paused = true
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.06)
	bg.size = Vector2(PANEL.x * times.size(), PANEL.y * ids.size())
	tree.root.add_child(bg)
	var stage := Node2D.new()
	tree.root.add_child(stage)
	var flo := Floor.new()
	stage.add_child(flo)
	for row in ids.size():
		for col in times.size():
			var g := Vector2(PANEL.x * (col + 0.38), PANEL.y * (row + 0.62))
			flo.grounds.append(g)
			_dummy(stage, g, Color(0.25, 0.85, 1.0))
			var params := {"scale": scale, "seed": int(o.get("seed", "7")), "shake": false, "hit_stop": false}
			if o.has("color"):
				params["color"] = VFX.parse_color(str(o["color"]))
			params["to"] = g + to * scale
			_dummy(stage, g + to * scale, Color(1.0, 0.25, 0.55))
			if not targets.is_empty():
				var tl: Array = []
				for t: Vector2 in targets:
					tl.append(g + t * scale)
					_dummy(stage, g + t * scale, Color(1.0, 0.25, 0.55))
				params["targets"] = tl
			var fx := VFX.spawn(stage, ids[row], g, params) as VFXEffect
			fx.advance_to(float(times[col]))
	flo.queue_redraw()
	# Window may be larger than the strip (window override); keep the strip size.
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var img := tree.root.get_texture().get_image()
	var xf := tree.root.get_final_transform()
	var end := xf * bg.size
	img = img.get_region(Rect2i(Vector2i.ZERO, Vector2i(mini(int(end.x), img.get_width()), mini(int(end.y), img.get_height()))))
	var out := str(o.get("out", "user://vfx_shot.png"))
	var err := img.save_png(out)
	VFX.paused = false
	print("vfx_shot: %s %s at t=%s (%dx%d)" % [out if err == OK else "SAVE FAILED", ids, times, img.get_width(), img.get_height()])
	return 0 if err == OK else 1


func _dummy(stage: Node2D, at: Vector2, c: Color) -> void:
	var d := Dummy.new()
	d.col = c
	d.position = at
	d.z_index = 10
	stage.add_child(d)


func _v2(s: String) -> Vector2:
	var p := s.split(",")
	return Vector2(float(p[0]), float(p[1])) if p.size() >= 2 else Vector2.ZERO
