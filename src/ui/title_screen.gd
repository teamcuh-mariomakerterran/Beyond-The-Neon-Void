class_name TitleScreen
extends Control
## The title screen: Grok's 640x360 pixel menu (NvMainMenu) drawn at an exact
## 3x in a 1920x1080 frame, centred on black, nearest filtering. This script
## only hooks it up: buttons to the game, Brian's menu sounds and song.
##   F1  Neon Forge        F2  dev menu (quick battles, test units, gallery)

const MENU_SCENE := "res://scenes/ui/nv_main_menu/nv_main_menu.tscn"
const DEV_MENU := "res://scenes/dev_menu.tscn"
const FORGE_SCENE := "res://scenes/editor/neon_forge.tscn"
const SCALE := 3
const CREDITS := "res://data/credits.json"

var menu: NvMainMenu
## The open Options / Load / Credits screen, if any.
var screen: PixelScreen
var _vp: SubViewport


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Fixed 1920x1080 frame, centred, so the menu is always a clean 3x.
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.stretch_shrink = SCALE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.custom_minimum_size = Vector2(NvMainMenu.W * SCALE, NvMainMenu.H * SCALE)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	center.add_child(frame)
	_vp = SubViewport.new()
	_vp.disable_3d = true
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vp.handle_input_locally = true
	frame.add_child(_vp)
	menu = (load(MENU_SCENE) as PackedScene).instantiate() as NvMainMenu
	menu.has_save = SaveManager.latest_slot() >= 0
	menu.quit_on_quit = true
	_vp.add_child(menu)
	menu.selection_changed.connect(func(_i: int) -> void: AudioManager.play_ui("menu_move"))
	menu.continue_pressed.connect(_continue)
	menu.new_game_pressed.connect(_new_game)
	menu.load_pressed.connect(show_load)
	menu.options_pressed.connect(show_options)
	menu.credits_pressed.connect(show_credits)
	menu.quit_pressed.connect(func() -> void: AudioManager.play_ui("confirm"))
	AudioManager.play_music("title")
	AudioManager.play_ambience("")


func _continue() -> void:
	AudioManager.play_ui("confirm")
	_load(SaveManager.latest_slot())


func _load(slot: int) -> void:
	if slot >= 0 and SaveManager.load_game(slot):
		AudioManager.play_ui("save_loaded")
		CampaignManager.resume()
	else:
		AudioManager.play_ui("no_save")


func _new_game() -> void:
	if not AudioManager.play_ui("start_game"):
		AudioManager.play_ui("confirm")
	GameManager.new_game()
	CampaignManager.load_campaign_data({})
	CampaignManager.return_to_hub()


## Opens a sub-screen over the menu (the menu keeps animating behind it).
func _open(title: String) -> PixelScreen:
	close_screen()
	AudioManager.play_ui("confirm")
	screen = PixelScreen.new()
	screen.title = title
	screen.closed.connect(func() -> void:
		screen = null
		menu.set_process_unhandled_input(true)
		menu.grab_focus())
	menu.set_process_unhandled_input(false)
	return screen


func close_screen() -> void:
	if screen and is_instance_valid(screen):
		screen.close()


func show_options() -> void:
	var s := _open("OPTIONS")
	var onoff := func(key: String) -> Callable: return func() -> String: return "ON" if bool(SettingsFlags.value_of(key)) else "OFF"
	var flip := func(key: String) -> Callable: return func() -> void:
		SettingsFlags.set_value(key, not bool(SettingsFlags.value_of(key)))
		SettingsFlags.save()
	s.add_row("FULLSCREEN", flip.call("fullscreen"), onoff.call("fullscreen"))
	_volume_row(s, "MUSIC", "music_db", func() -> void: AudioManager.apply_music_volume())
	_volume_row(s, "SOUND FX", "sfx_db", func() -> void: AudioManager.play_ui("menu_move"))
	s.add_row("BATTLE SPEED", flip.call("fast_battles"), func() -> String: return "FAST" if SettingsFlags.fast_battles else "NORMAL")
	s.add_row("FREE MOVEMENT", flip.call("free_move"), onoff.call("free_move"))
	s.add_row("REDUCE MOTION", flip.call("reduce_motion"), onoff.call("reduce_motion"))
	s.add_row("BATTLE BARKS", flip.call("barks"), onoff.call("barks"))
	s.add_row("AUTO ADDITIONS", flip.call("auto_additions"), onoff.call("auto_additions"))
	s.add_row("BACK", s.close)
	_vp.add_child(s)


## A 0–10 volume row: left / right step it, the bar shows the level.
func _volume_row(s: PixelScreen, label: String, key: String, after: Callable) -> void:
	var level := func() -> int:
		if key == "sfx_db" and not SettingsFlags.sfx:
			return 0
		return SettingsFlags.db_level(float(SettingsFlags.value_of(key)))
	var step := func(d: int) -> void:
		var lv := clampi(int(level.call()) + d, 0, SettingsFlags.VOLUME_STEPS)
		if key == "sfx_db":
			SettingsFlags.sfx = lv > 0
		SettingsFlags.set_value(key, SettingsFlags.level_db(maxi(lv, 1)) if key == "sfx_db" else SettingsFlags.level_db(lv))
		SettingsFlags.save()
		after.call()
	var r := s.add_row(label, Callable(), Callable(), func() -> void: step.call(-1), func() -> void: step.call(1))
	r["level"] = level
	r["steps"] = SettingsFlags.VOLUME_STEPS


func show_load() -> void:
	var s := _open("LOAD GAME")
	for slot: int in SaveManager.SLOTS:
		var sum := SaveManager.slot_summary(slot)
		var r := s.add_row("QUICK SAVE" if slot == SaveManager.QUICK_SLOT else "SLOT %d" % slot, func() -> void: _load(slot))
		r["enabled"] = func() -> bool: return not sum.is_empty()
		r["detail"] = func() -> String: return _slot_line(sum)
	s.add_row("BACK", s.close)
	if SaveManager.latest_slot() < 0:
		AudioManager.play_ui("no_save")
	_vp.add_child(s)


## "ROOK DANNICK  CH 1  11-10 14:22" (or EMPTY).
static func _slot_line(sum: Dictionary) -> String:
	if sum.is_empty():
		return "EMPTY"
	var at := str(sum.get("saved_at", ""))
	var when := "%s %s" % [at.substr(5, 5), at.substr(11, 5)] if at.length() >= 16 else at
	var who := str(sum.get("leader", "")).to_upper()
	return "%s  CH %d  %s" % [who, int(sum.get("chapter", 1)), when]


func show_credits() -> void:
	var s := _open("CREDITS")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CREDITS)) if FileAccess.file_exists(CREDITS) else null
	for l: Variant in (data.get("lines", []) if data is Dictionary else []):
		s.lines.append(str(l))
	if s.lines.is_empty():
		s.lines.append("# BEYOND: THE NEON VOID")
	_vp.add_child(s)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_F2:
		SceneManager.change_scene(DEV_MENU)
	elif event.is_action_pressed("toggle_editor"):
		SceneManager.change_scene(FORGE_SCENE)
