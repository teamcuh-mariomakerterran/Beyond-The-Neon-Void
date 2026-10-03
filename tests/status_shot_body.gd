extends RefCounted

const SHOW := ["", "petrified", "banished", "stop", "poisoned", "burning", "short_circuit", "fading", "hidden", "berserk", "asleep", "identity_loss"]


class Dummy extends Node2D:
	var statuses: Array = []
	var sprite: AnimatedSprite2D


func run(tree: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var tex: Texture2D = ForgeStore.load_texture(args[0])
	var root := Node2D.new()
	tree.root.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.1)
	bg.size = Vector2(1600, 900)
	root.add_child(bg)
	var sf := SpriteFrames.new()
	sf.add_frame("default", tex)
	for i in SHOW.size():
		var d := Dummy.new()
		d.position = Vector2(130 + (i % 6) * 260, 360 + (i / 6) * 400)
		var s := AnimatedSprite2D.new()
		s.sprite_frames = sf
		s.centered = false
		s.offset = -Vector2(tex.get_width() * 0.5, tex.get_height() * 0.9)
		d.sprite = s
		d.add_child(s)
		var floor_line := Line2D.new()
		floor_line.points = PackedVector2Array([Vector2(-90, 0), Vector2(90, 0)])
		floor_line.width = 2
		floor_line.default_color = Color(0.4, 0.3, 0.7)
		d.add_child(floor_line)
		var lbl := Label.new()
		lbl.text = SHOW[i] if SHOW[i] != "" else "(none)"
		lbl.position = Vector2(-60, 12)
		d.add_child(lbl)
		root.add_child(d)
		if SHOW[i] != "":
			d.statuses.append(StatusEffect.StatusInstance.new(ContentDB.get_status(SHOW[i]), null))
		StatusLook.update(d, false)
		s.use_parent_material = true
	for i in 30:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(args[1])
