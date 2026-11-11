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

var menu: NvMainMenu
var _overlay: Control


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
	var vp := SubViewport.new()
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.handle_input_locally = true
	frame.add_child(vp)
	menu = (load(MENU_SCENE) as PackedScene).instantiate() as NvMainMenu
	menu.has_save = SaveManager.has_save_file()
	menu.quit_on_quit = true
	vp.add_child(menu)
	menu.selection_changed.connect(func(_i: int) -> void: AudioManager.play_ui("menu_move"))
	menu.continue_pressed.connect(_continue)
	menu.new_game_pressed.connect(_new_game)
	menu.load_pressed.connect(_show_load)
	menu.options_pressed.connect(func() -> void: _show_note("OPTIONS", "The options menu is coming soon. Settings live in the hub under SAVE / QUIT for now."))
	menu.credits_pressed.connect(func() -> void: _show_note("CREDITS", "Credits are coming soon."))
	menu.quit_pressed.connect(func() -> void: AudioManager.play_ui("confirm"))
	AudioManager.play_music("title")
	AudioManager.play_ambience("")


func _continue() -> void:
	AudioManager.play_ui("confirm")
	if SaveManager.load_game():
		CampaignManager.resume()


func _new_game() -> void:
	if not AudioManager.play_ui("start_game"):
		AudioManager.play_ui("confirm")
	GameManager.new_game()
	CampaignManager.load_campaign_data({})
	CampaignManager.return_to_hub()


## Load: the three save slots (the full load screen comes with the options work).
func _show_load() -> void:
	AudioManager.play_ui("confirm")
	var v := _open_overlay("LOAD GAME")
	var any := false
	for slot in [SaveManager.QUICK_SLOT, 1, 2, 3]:
		var has := SaveManager.has_save_file(slot)
		any = any or has
		var b := Button.new()
		b.text = "QUICK SAVE" if slot == SaveManager.QUICK_SLOT else "SLOT %d" % slot
		b.disabled = not has
		b.pressed.connect(func() -> void:
			if SaveManager.load_game(slot):
				CampaignManager.resume())
		v.add_child(b)
	if not any:
		AudioManager.play_ui("no_save")
		v.add_child(NeonTheme.label("No saved game yet.", 15, NeonTheme.TEXT_DIM))
	_back_last(v)


## Puts the BACK button last again after a screen adds its own rows.
func _back_last(v: VBoxContainer) -> void:
	for c in v.get_children():
		if c is Button and (c as Button).text.begins_with("BACK"):
			v.move_child(c, v.get_child_count() - 1)


func _show_note(title: String, text: String) -> void:
	AudioManager.play_ui("confirm")
	var v := _open_overlay(title)
	var l := NeonTheme.label(text, 15, NeonTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 420
	v.add_child(l)
	_back_last(v)


func _open_overlay(title: String) -> VBoxContainer:
	close_overlay()
	# A dimmer over the whole screen (keeps clicks off the menu), panel centred.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.theme = NeonTheme.get_theme()
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(NeonTheme.label(title, 24, NeonTheme.CYAN))
	var back := Button.new()
	back.text = "BACK  (Esc)"
	back.pressed.connect(close_overlay)
	v.add_child(back)
	_overlay = dim
	menu.set_process_unhandled_input(false)
	return v


func close_overlay() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	if menu:
		menu.set_process_unhandled_input(true)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_ESCAPE and _overlay:
		close_overlay()
		get_viewport().set_input_as_handled()
	elif k == KEY_F2:
		SceneManager.change_scene(DEV_MENU)
	elif event.is_action_pressed("toggle_editor"):
		SceneManager.change_scene(FORGE_SCENE)
