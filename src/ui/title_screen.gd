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


## Opens a sub-screen (GameMenus) over the menu; the menu keeps animating behind.
func _open(s: PixelScreen) -> PixelScreen:
	close_screen()
	AudioManager.play_ui("confirm")
	screen = s
	s.closed.connect(func() -> void:
		screen = null
		menu.set_process_unhandled_input(true)
		menu.grab_focus())
	menu.set_process_unhandled_input(false)
	_vp.add_child(s)
	return s


func close_screen() -> void:
	if screen and is_instance_valid(screen):
		screen.close()


func show_options() -> void:
	_open(GameMenus.options())


func show_load() -> void:
	_open(GameMenus.load_game(_load))


func show_credits() -> void:
	_open(GameMenus.credits(CREDITS))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_F2:
		SceneManager.change_scene(DEV_MENU)
	elif event.is_action_pressed("toggle_editor"):
		SceneManager.change_scene(FORGE_SCENE)
