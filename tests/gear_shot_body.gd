extends RefCounted
## Body of tests/gear_shot.gd (loaded after autoloads exist).

const FACES := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]


func run(tree: SceneTree) -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "closeup"
	var out: String = args[1] if args.size() > 1 else "user://gear.png"
	var art: String = args[2] if args.size() > 2 else "res://assets/gear/weapons/pilot_blade"
	if art != "-":
		ContentDB.inject("items", {"id": "shot_blade", "display_name": "Pilot Blade", "category": "WEAPON",
			"equip_type": "sword", "wear_path": art}, false)
	if mode == "battle":
		await _battle(tree, art != "-")
	else:
		var bodies: Array = args.slice(3) if args.size() > 3 else ["res://assets/units/test_enemy_001", "res://assets/units/test_character_001"]
		await _closeup(tree, bodies, art != "-")
	for i in 30:
		await tree.process_frame
	var img := tree.root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())


func _closeup(tree: SceneTree, bodies: Array, armed: bool) -> void:
	var root := Node2D.new()
	tree.root.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.08)
	bg.size = Vector2(1600, 900)
	root.add_child(bg)
	var grid := IsometricGrid.new()
	grid.setup(4, 4)
	for r in bodies.size():
		var cd: CharacterData = (ContentDB.get_all("characters")[0] as CharacterData).duplicate(true)
		cd.sprite_frames_path = bodies[r]
		cd.equipment = {}
		for c in FACES.size():
			var u := Unit.new()
			u.grid = grid
			u.setup(cd, Unit.Team.PLAYER, 1)
			u.position = Vector2(220 + c * 360, 360 + r * 380)
			u.scale = Vector2(2.5, 2.5)
			root.add_child(u)
			u.facing = FACES[c]
			if u.hud:
				u.hud.visible = false
			if armed:
				u.equipment.equip_instance({"uid": "s%d%d" % [r, c], "item_id": "shot_blade", "level": 1})
			var lbl := Label.new()
			lbl.text = LatticeClip.facing_of(FACES[c])
			lbl.position = u.position + Vector2(-12, 20)
			root.add_child(lbl)
		await tree.process_frame


func _battle(tree: SceneTree, armed: bool) -> void:
	CampaignManager.current_mission_id = "test_pixellab_skirmish"
	tree.change_scene_to_file("res://scenes/battle/battle.tscn")
	for i in 20:
		await tree.process_frame
	if armed:
		for u: Node in CombatManager.get_units():
			if u is Unit and (u as Unit).data and (u as Unit).data.id == "test_enemy_001":
				(u as Unit).equipment.equip_instance({"uid": "shot", "item_id": "shot_blade", "level": 1})
	for i in 90:
		await tree.process_frame
