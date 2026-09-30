class_name DialogueBox
extends CanvasLayer
## Bottom-of-screen neon dialogue panel: speaker, portrait, typewriter text,
## choices and optional voice lines. Click / E / Enter skips the typewriter,
## then advances. Frees itself when the conversation ends (after `finished`).
##
##   var box := DialogueBox.new(); add_child(box); box.play_npc(npc)
##   box.say("Otto", "We're closed. We're never closed.")

signal finished

const CHARS_PER_SEC := 48.0
const PORTRAIT_SIZE := Vector2(150, 150)

var free_on_finish: bool = true

var _panel: PanelContainer
var _portrait: TextureRect
var _speaker: Label
var _body: Label
var _choices: VBoxContainer
var _hint: Label
var _voice: AudioStreamPlayer
var _graph: DialogGraph
var _npc: NPCResource
var _queue: Array[Dictionary] = []  # one-off lines: {"speaker", "text", "voice_path"}
var _typing: bool = false
var _shown_chars: float = 0.0


func _init() -> void:
	layer = 60
	_build()


func _build() -> void:
	var shield := Control.new()  # eats clicks so the hub behind doesn't react
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	shield.theme = NeonTheme.get_theme()
	shield.gui_input.connect(_on_gui_input)
	add_child(shield)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", NeonTheme.panel_box(NeonTheme.CYAN, Color(0.04, 0.02, 0.08, 0.96)))
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 90
	_panel.offset_right = -90
	_panel.offset_bottom = -44
	_panel.offset_top = -250
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.gui_input.connect(_on_gui_input)
	shield.add_child(_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	_panel.add_child(h)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = PORTRAIT_SIZE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.visible = false
	h.add_child(_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	h.add_child(v)
	_speaker = NeonTheme.label("", 22, NeonTheme.GREEN)
	v.add_child(_speaker)
	_body = NeonTheme.label("", 19, NeonTheme.TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	v.add_child(_body)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	v.add_child(_choices)
	_hint = NeonTheme.label("▸ click / E", 13, NeonTheme.TEXT_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)


# --- API -------------------------------------------------------------------

## Runs an NPC's dialog graph from start_id (or its first node).
func play_npc(npc: NPCResource, start_id: String = "") -> void:
	_npc = npc
	_graph = DialogGraph.new(npc.dialog)
	_set_portrait(npc.portrait_path)
	_show_node(_graph.start(start_id))


## One-off line. Queues behind whatever is already on screen.
func say(speaker: String, text: String, voice_path: String = "") -> void:
	var line := {"speaker": speaker, "text": text, "voice_path": voice_path}
	if _is_idle():
		_show_line(line)
	else:
		_queue.append(line)


## Skip the typewriter, or move on. Public so tests / cutscenes can drive it.
func advance() -> void:
	if _typing:
		_finish_typing()
		return
	if _graph and not _graph.is_finished():
		if _graph.has_choices():
			return
		_show_node(_graph.advance())
		return
	if not _queue.is_empty():
		_show_line(_queue.pop_front())
		return
	_close()


func choose(index: int) -> void:
	if _graph == null or not _graph.has_choices():
		return
	_show_node(_graph.choose(index))


func is_open() -> bool:
	return visible


# --- Internals -------------------------------------------------------------

func _is_idle() -> bool:
	return _speaker.text == "" and _body.text == "" and (_graph == null or _graph.is_finished())


func _show_node(node: Dictionary) -> void:
	if node.is_empty():
		_graph = null
		if _queue.is_empty():
			_close()
		else:
			advance()
		return
	var speaker := str(node.get("speaker", ""))
	if speaker == "" and _npc:
		speaker = _npc.display_name
	_show_line({"speaker": speaker, "text": str(node.get("text", "")), "voice_path": str(node.get("voice_path", ""))}, node.get("choices", []))


func _show_line(line: Dictionary, choices: Array = []) -> void:
	visible = true
	_speaker.text = str(line.get("speaker", "")).to_upper()
	_speaker.visible = _speaker.text != ""
	_body.text = str(line.get("text", ""))
	_body.visible_characters = 0
	_shown_chars = 0.0
	_typing = true
	for c in _choices.get_children():
		c.queue_free()
	for i in choices.size():
		var b := Button.new()
		b.text = "▸ " + str((choices[i] as Dictionary).get("text", "..."))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.visible = false
		var idx := i
		b.pressed.connect(func() -> void: choose(idx))
		_choices.add_child(b)
	_hint.visible = choices.is_empty()
	_play_voice(str(line.get("voice_path", "")))


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown_chars += CHARS_PER_SEC * delta
	_body.visible_characters = int(_shown_chars)
	if _shown_chars >= _body.text.length():
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_body.visible_characters = -1
	for c in _choices.get_children():
		c.visible = true
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus.call_deferred()


func _close() -> void:
	_typing = false
	_voice.stop()
	_speaker.text = ""
	_body.text = ""
	visible = false
	finished.emit()
	if free_on_finish:
		queue_free()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if _typing or not (_graph and _graph.has_choices()):
			advance()
			get_viewport().set_input_as_handled()


func _set_portrait(path: String) -> void:
	var tex := load_texture(path)
	_portrait.texture = tex
	_portrait.visible = tex != null


func _play_voice(path: String) -> void:
	_voice.stop()
	var stream := load_audio(path)
	if stream:
		_voice.stream = stream
		_voice.play()


## res:// import first, then a raw file on disk (user:// or editor-injected).
static func load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null


static func load_audio(path: String) -> AudioStream:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"mp3":
			var mp3 := AudioStreamMP3.new()
			mp3.data = FileAccess.get_file_as_bytes(path)
			return mp3
	return null
