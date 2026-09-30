class_name ForgeSpriteSlicer
extends AcceptDialog
## Turns a character animation sheet into SpriteFrames: set the frame size,
## name each row (idle / walk / attack / hurt / death / cast ...), pick FPS,
## watch the live preview, save. Optionally assigns it to a character.

signal done(frames_path: String)

var sheet_path: String = ""
var character_id: String = ""
var _w: SpinBox
var _h: SpinBox
var _fps: SpinBox
var _rows: LineEdit
var _sheet_view: TextureRect
var _grid_overlay: Control
var _preview: AnimatedSprite2D
var _preview_holder: SubViewportContainer
var _tex: Texture2D


func _ready() -> void:
	title = "SLICE ANIMATION SHEET"
	ok_button_text = "SAVE ANIMATIONS"
	var root := HBoxContainer.new()
	root.theme = NeonTheme.get_theme()
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	_tex = ForgeStore.load_texture(sheet_path)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	_sheet_view = TextureRect.new()
	_sheet_view.texture = _tex
	_sheet_view.custom_minimum_size = Vector2(440, 440)
	_sheet_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sheet_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_sheet_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left.add_child(_sheet_view)
	_grid_overlay = Control.new()
	_grid_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_overlay.draw.connect(_draw_grid)
	_sheet_view.add_child(_grid_overlay)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 250
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)
	var guess := _guess_frame()
	right.add_child(NeonTheme.label("FRAME WIDTH / HEIGHT (px)", 12, NeonTheme.TEXT_DIM))
	var wh := HBoxContainer.new()
	_w = ForgeForm._spin(guess.x, true, func(_v: float) -> void: _refresh())
	_h = ForgeForm._spin(guess.y, true, func(_v: float) -> void: _refresh())
	wh.add_child(_w)
	wh.add_child(_h)
	right.add_child(wh)
	right.add_child(NeonTheme.label("ROW NAMES (top → bottom)", 12, NeonTheme.TEXT_DIM))
	_rows = LineEdit.new()
	_rows.text = "idle, walk, attack, hurt, death"
	_rows.text_changed.connect(func(_t: String) -> void: _refresh())
	right.add_child(_rows)
	right.add_child(NeonTheme.label("FPS", 12, NeonTheme.TEXT_DIM))
	_fps = ForgeForm._spin(8, true, func(_v: float) -> void: _refresh())
	right.add_child(_fps)
	right.add_child(NeonTheme.label("LIVE PREVIEW (row 1)", 12, NeonTheme.TEXT_DIM))
	_preview_holder = SubViewportContainer.new()
	_preview_holder.custom_minimum_size = Vector2(200, 200)
	_preview_holder.stretch = true
	var vp := SubViewport.new()
	vp.transparent_bg = true
	_preview_holder.add_child(vp)
	_preview = AnimatedSprite2D.new()
	_preview.position = Vector2(100, 100)
	_preview.scale = Vector2(2, 2)
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vp.add_child(_preview)
	right.add_child(_preview_holder)
	confirmed.connect(_save)
	canceled.connect(queue_free)
	_refresh()


## Most sheets are square frames in a grid: guess from the shorter side.
func _guess_frame() -> Vector2i:
	if _tex == null:
		return Vector2i(64, 64)
	var h := _tex.get_height()
	for rows in [5, 4, 6, 8, 3, 2, 1]:
		if h % rows == 0 and _tex.get_width() % (h / rows) == 0:
			return Vector2i(h / rows, h / rows)
	return Vector2i(64, 64)


func _row_names() -> Array[String]:
	var out: Array[String] = []
	for n in _rows.text.split(","):
		if n.strip_edges() != "":
			out.append(ForgeStore.slugify(n))
	return out


func _refresh() -> void:
	_grid_overlay.queue_redraw()
	if _tex == null:
		return
	var frames := SpriteFrames.new()
	var fw := int(_w.value)
	var fh := int(_h.value)
	if fw <= 0 or fh <= 0:
		return
	var cols := int(_tex.get_width() / fw)
	frames.set_animation_speed("default", _fps.value)
	for c in cols:
		var at := AtlasTexture.new()
		at.atlas = _tex
		at.region = Rect2(c * fw, 0, fw, fh)
		frames.add_frame("default", at)
	_preview.sprite_frames = frames
	_preview.play("default")


func _draw_grid() -> void:
	if _tex == null:
		return
	var view := _sheet_view.size
	var s := minf(view.x / _tex.get_width(), view.y / _tex.get_height())
	var off := (view - Vector2(_tex.get_width(), _tex.get_height()) * s) * 0.5
	var fw := _w.value * s
	var fh := _h.value * s
	if fw < 2 or fh < 2:
		return
	var names := _row_names()
	var y := 0.0
	var r := 0
	while y <= _tex.get_height() * s + 0.5:
		_grid_overlay.draw_line(off + Vector2(0, y), off + Vector2(_tex.get_width() * s, y), Color(NeonTheme.GREEN, 0.6), 1.0)
		if r < names.size() and y + fh <= _tex.get_height() * s + 0.5:
			_grid_overlay.draw_string(NeonTheme.mono(), off + Vector2(4, y + 14), names[r], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, NeonTheme.AMBER)
		y += fh
		r += 1
	var x := 0.0
	while x <= _tex.get_width() * s + 0.5:
		_grid_overlay.draw_line(off + Vector2(x, 0), off + Vector2(x, _tex.get_height() * s), Color(NeonTheme.GREEN, 0.6), 1.0)
		x += fw


func _save() -> void:
	var out_name := character_id if character_id != "" else sheet_path.get_file().get_basename()
	var out := ForgeStore.slice_sheet(sheet_path, Vector2i(int(_w.value), int(_h.value)), _row_names(), _fps.value, out_name)
	if out != "":
		done.emit(out)
	queue_free()
