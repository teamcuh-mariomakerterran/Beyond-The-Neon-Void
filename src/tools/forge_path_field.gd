class_name ForgePathField
extends HBoxContainer
## Asset path field: preview (image thumb or ▶ for audio), path, browse button.
## Accepts drags from the Asset Library and OS files dropped onto it.

signal path_changed(path: String)

var key: String = ""
var _edit: LineEdit
var _thumb: TextureRect
var _play: Button
var _player: AudioStreamPlayer


static func create(value: String, p_key: String, cb: Callable) -> ForgePathField:
	var f := ForgePathField.new()
	f.key = p_key
	f.path_changed.connect(cb)
	f._build(value)
	return f


func _build(value: String) -> void:
	add_theme_constant_override("separation", 6)
	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = Vector2(44, 44)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_thumb)
	_play = Button.new()
	_play.text = "▶"
	_play.tooltip_text = "Preview audio"
	_play.pressed.connect(_preview_audio)
	add_child(_play)
	_edit = LineEdit.new()
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.placeholder_text = "drop a file here, drag from Assets, or browse"
	_edit.text = value
	_edit.text_submitted.connect(func(t: String) -> void: set_path(t))
	_edit.focus_exited.connect(func() -> void: if _edit.text != value: set_path(_edit.text))
	add_child(_edit)
	var browse := Button.new()
	browse.text = "…"
	browse.tooltip_text = "Browse"
	browse.pressed.connect(_browse)
	add_child(browse)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_refresh_preview()


func set_path(p: String) -> void:
	_edit.text = p
	_refresh_preview()
	path_changed.emit(p)


func _refresh_preview() -> void:
	var p := _edit.text
	var is_audio := p.get_extension().to_lower() in ForgeStore.AUDIO_EXT
	_play.visible = is_audio
	_thumb.visible = not is_audio
	_thumb.texture = ForgeStore.load_texture(p) if p.get_extension().to_lower() in ForgeStore.IMAGE_EXT else null


func _preview_audio() -> void:
	var s := ForgeStore.load_audio(_edit.text)
	if s:
		_player.stream = s
		_player.play()


func _browse() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_RESOURCES
	fd.current_dir = "res://assets"
	fd.file_selected.connect(func(p: String) -> void: set_path(p); fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	get_tree().root.add_child(fd)
	fd.popup_centered_ratio(0.6)


## Drag from ForgeAssetLibrary.
func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("asset_path")


func _drop_data(_pos: Vector2, data: Variant) -> void:
	set_path(str(data["asset_path"]))


## Called by NeonForge when OS files are dropped over this field.
func accept_os_files(files: PackedStringArray) -> bool:
	if files.is_empty():
		return false
	var src := files[0]
	var ext := src.get_extension().to_lower()
	var cat := "voice" if key == "voice_path" else ("portraits" if key == "portrait_path" else ("units" if key.begins_with("sprite") else ForgeStore.category_for_file(src)))
	if ext in ForgeStore.AUDIO_EXT and cat not in ["voice", "music", "sfx"]:
		cat = "sfx"
	var dest := ForgeStore.import_file(src, cat)
	if dest != "":
		set_path(dest)
		return true
	return false
