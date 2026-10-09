extends Control
## Title screen.

const FORGE_SCENE := "res://scenes/editor/neon_forge.tscn"


func _ready() -> void:
	theme = NeonTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = NeonTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 12)
	add_child(center)
	var kicker := NeonTheme.label("A TALE OF THE BLACK DOCTRINE", 14, NeonTheme.TEXT_DIM)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(kicker)
	var title := NeonTheme.label("BEYOND", 84, Color(0.4, 2.2, 1.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)
	var sub := NeonTheme.label("THE NEON VOID", 40, Color(2.0, 0.5, 1.4))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)
	var tag := NeonTheme.label("Everything has two truths. Both are probably wrong. The bar is open.", 15, NeonTheme.TEXT_DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(tag)
	center.add_child(Control.new())
	_button(center, "NEW SHIFT", _new_game)
	var cont := _button(center, "CONTINUE", _continue)
	cont.disabled = not SaveManager.has_save_file()
	_button(center, "QUICK BATTLE — THE BREW PLAN", func() -> void: _quick_battle("m01_the_brew_plan"))
	if ContentDB.get_mission("test_pixellab_skirmish"):
		_button(center, "TEST UNITS — SKIRMISH", func() -> void: _quick_battle("test_pixellab_skirmish"))
	if ContentDB.get_character("test_hero") and not ContentDB.get_map("neon_block_demo").is_empty():
		_button(center, "TEST UNITS — WALK THE NEON BLOCK", _test_walk)
	_button(center, "TEST — HANGOVER MORNING", func() -> void:
		GameManager.new_game()
		GameManager.hungover["dizzy"] = true
		SceneManager.change_scene(HangoverMorning.SCENE))
	if ContentDB.get_mission("relay_district"):
		_button(center, "WARPED ZONE — RELAY DISTRICT (LYING HUD)", func() -> void: _quick_battle("relay_district"))
	var forge := _button(center, "NEON FORGE  ·  EDITOR  (F1)", func() -> void: SceneManager.change_scene(FORGE_SCENE))
	forge.add_theme_color_override("font_color", NeonTheme.AMBER)
	_button(center, "QUIT", func() -> void: get_tree().quit())
	var ver := NeonTheme.label("v%s  //  Godot %s" % [ProjectSettings.get_setting("application/config/version", "0.1"), Engine.get_version_info()["string"]], 11, NeonTheme.TEXT_DIM)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position -= Vector2(260, 30)
	add_child(ver)
	AudioManager.play_music("title")
	var t := create_tween().set_loops()
	t.tween_property(title, "modulate", Color(1.2, 1.2, 1.2), 1.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(title, "modulate", Color(0.85, 0.85, 0.85), 1.6).set_trans(Tween.TRANS_SINE)


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _new_game() -> void:
	GameManager.new_game()
	CampaignManager.load_campaign_data({})
	CampaignManager.return_to_hub()


func _continue() -> void:
	if SaveManager.load_game():
		CampaignManager.resume()


## New game led by the Test Runner, dropped on the Neon Block (Kade's stall,
## Ma Rivet, the vault entrance).
func _test_walk() -> void:
	GameManager.new_game()
	var hero := GameManager.add_character_to_roster(ContentDB.get_character("test_hero"))
	if hero:
		var party: Array[String] = [hero.id]
		party.append_array(GameManager.active_party.slice(0, GameManager.MAX_PARTY_SIZE - 1))
		GameManager.set_active_party(party)
	CampaignManager.explore("neon_block_demo")


func _quick_battle(mission_id: String) -> void:
	GameManager.new_game()
	CampaignManager.start_mission(mission_id)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_editor"):
		SceneManager.change_scene(FORGE_SCENE)
