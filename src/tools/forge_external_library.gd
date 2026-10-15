class_name ForgeExternalLibrary
extends HSplitContainer
## EXTERNAL LIBRARY tab: browse asset folders outside the project (indexed by
## their own .json files, see ExternalLibrary), search them, and bring what
## you use into the project. Importing copies (originals untouched); dragging
## a thumbnail onto any path field imports it first, then drops the res:// path.

signal status(text: String, color: Color)

const THUMB := 96
const THUMBS_PER_FRAME := 8
const PAGE := 400

var entries: Array = []  # current folder's scan
var shown: Array = []  # after search / category filter
var folder := ""
var category := ""
var query := ""
var _folder_pick: OptionButton
var _search: LineEdit
var _cats: HFlowContainer
var _grid: ThumbGrid
var _count: Label
var _detail: VBoxContainer
var _selected: Dictionary = {}
var _thumb_queue: Array[int] = []
var _thumbs: Dictionary = {}  # abs path -> Texture2D
var _dialog: FileDialog


class ThumbGrid extends ItemList:
	var owner_lib: ForgeExternalLibrary

	func _get_drag_data(at_position: Vector2) -> Variant:
		var idx := get_item_at_position(at_position, true)
		if idx < 0 or idx >= owner_lib.shown.size():
			return null
		var e: Dictionary = owner_lib.shown[idx]
		var res := ExternalLibrary.imported_path(e)
		if res == "":
			res = owner_lib.import_one(e)
		if res == "":
			return null
		var l := Label.new()
		l.text = "⇢ " + res.get_file()
		set_drag_preview(l)
		return {"asset_path": res}


func _ready() -> void:
	split_offset = 0
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	add_child(left)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	left.add_child(bar)
	bar.add_child(NeonTheme.label("FOLDER", 12, NeonTheme.TEXT_DIM))
	_folder_pick = OptionButton.new()
	_folder_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_folder_pick.clip_text = true  # long paths must not push the detail panel off-screen
	_folder_pick.fit_to_longest_item = false
	_folder_pick.custom_minimum_size.x = 160
	_folder_pick.item_selected.connect(func(i: int) -> void: open_folder(_folder_pick.get_item_text(i)))
	bar.add_child(_folder_pick)
	for b: Array in [["+ ADD FOLDER", _add_folder], ["RESCAN", func() -> void: open_folder(folder)], ["REMOVE", _remove_folder]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.pressed.connect(b[1])
		bar.add_child(btn)
	_search = LineEdit.new()
	_search.placeholder_text = "Search names, tags, folders, prompts…  (e.g. neon sign, rusty crate)"
	_search.text_changed.connect(func(t: String) -> void: query = t; _filter())
	left.add_child(_search)
	_cats = HFlowContainer.new()
	_cats.add_theme_constant_override("h_separation", 6)
	left.add_child(_cats)
	_grid = ThumbGrid.new()
	_grid.owner_lib = self
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.icon_mode = ItemList.ICON_MODE_TOP
	_grid.max_columns = 0
	_grid.fixed_icon_size = Vector2i(THUMB, THUMB)
	_grid.fixed_column_width = THUMB + 24
	_grid.same_column_width = true
	_grid.max_text_lines = 2
	_grid.select_mode = ItemList.SELECT_MULTI
	_grid.item_selected.connect(func(i: int) -> void: _show_detail(i))
	_grid.multi_selected.connect(func(i: int, _s: bool) -> void: _show_detail(i))
	left.add_child(_grid)
	_count = NeonTheme.label("", 12, NeonTheme.TEXT_DIM)
	left.add_child(_count)
	var right := ScrollContainer.new()
	right.custom_minimum_size.x = 380
	add_child(right)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	right.add_child(_detail)
	_refresh_folders()
	var fs := ExternalLibrary.folders()
	if not fs.is_empty():
		open_folder(fs[0])
	else:
		_empty_help()


func _process(_d: float) -> void:
	var n := 0
	while not _thumb_queue.is_empty() and n < THUMBS_PER_FRAME:
		var i: int = _thumb_queue.pop_front()
		if i < shown.size() and i < _grid.item_count:
			_grid.set_item_icon(i, thumb(str(shown[i]["path"])))
		n += 1


# --- Folders -----------------------------------------------------------------------

func _refresh_folders() -> void:
	_folder_pick.clear()
	for f in ExternalLibrary.folders():
		_folder_pick.add_item(f)
		if f == folder:
			_folder_pick.select(_folder_pick.item_count - 1)


func _add_folder() -> void:
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.title = "Pick an asset folder (it stays where it is; nothing is moved)"
		_dialog.size = Vector2i(900, 600)
		_dialog.dir_selected.connect(add_folder)
		add_child(_dialog)
	_dialog.popup_centered()


func add_folder(path: String) -> void:
	path = path.replace("\\", "/").trim_suffix("/")
	var fs := ExternalLibrary.folders()
	if not fs.has(path):
		fs.append(path)
		ExternalLibrary.set_folders(fs)
	open_folder(path)


func _remove_folder() -> void:
	var fs := ExternalLibrary.folders()
	fs.erase(folder)  # only forgets it here; the folder itself is untouched
	ExternalLibrary.set_folders(fs)
	folder = ""
	entries.clear()
	_refresh_folders()
	if not fs.is_empty():
		open_folder(fs[0])
	else:
		_filter()
		_empty_help()


func open_folder(path: String) -> void:
	if path == "" or not DirAccess.dir_exists_absolute(path):
		status.emit("Folder not found: " + path, NeonTheme.MAGENTA)
		return
	folder = path
	var t := Time.get_ticks_msec()
	entries = ExternalLibrary.scan(path)
	_refresh_folders()
	_build_cats()
	_filter()
	status.emit("%d assets in %s (%d ms)" % [entries.size(), ExternalLibrary.pack_name(path), Time.get_ticks_msec() - t], NeonTheme.CYAN)


func _build_cats() -> void:
	for c in _cats.get_children():
		c.queue_free()
	var counts := {}
	for e: Dictionary in entries:
		counts[e["category"]] = int(counts.get(e["category"], 0)) + 1
	var all := Button.new()
	all.text = "ALL %d" % entries.size()
	all.toggle_mode = true
	all.button_pressed = category == ""
	all.pressed.connect(func() -> void: category = ""; _build_cats(); _filter())
	_cats.add_child(all)
	for k: String in counts:
		var b := Button.new()
		b.text = "%s %d" % [str(ForgeStore.ASSET_CATEGORIES.get(k, {}).get("label", k.to_upper())), counts[k]]
		b.toggle_mode = true
		b.button_pressed = category == k
		var kk := k
		b.pressed.connect(func() -> void: category = kk; _build_cats(); _filter())
		_cats.add_child(b)


func _filter() -> void:
	shown = entries.filter(func(e: Dictionary) -> bool: return ExternalLibrary.matches(e, query, category))
	_grid.clear()
	_thumb_queue.clear()
	var imported := 0
	for i in mini(shown.size(), PAGE):
		var e: Dictionary = shown[i]
		var done := ExternalLibrary.imported_path(e) != ""
		if done:
			imported += 1
		_grid.add_item(("✔ " if done else "") + str(e["name"]))
		_grid.set_item_tooltip(i, "%s\n%s%s" % [e["rel"], ", ".join(e["tags"]), ("\n" + str(e["text"]).left(200)) if str(e["text"]) != "" else ""])
		_thumb_queue.append(i)
	_count.text = "%d shown%s · %d already in the project · drag a thumbnail onto any path field, or IMPORT" % [shown.size(), (" (first %d)" % PAGE) if shown.size() > PAGE else "", imported]


func thumb(path: String) -> Texture2D:
	if _thumbs.has(path):
		return _thumbs[path]
	var img := Image.load_from_file(path)
	var tex: Texture2D = null
	if img:
		var s := float(THUMB) / maxf(img.get_width(), img.get_height())
		if s < 1.0:
			img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_NEAREST)
		tex = ImageTexture.create_from_image(img)
	_thumbs[path] = tex
	return tex


# --- Detail + import ------------------------------------------------------------

func _empty_help() -> void:
	for c in _detail.get_children():
		c.queue_free()
	_detail.add_child(NeonTheme.label("EXTERNAL LIBRARY", 20, NeonTheme.CYAN))
	var p := NeonTheme.label("Point this at any folder of assets on your machine (a generator's output, a shared drive). Its .json index files are read for names, categories, tags and prompts; loose images show up too.\n\nNothing is moved. When you use an asset it's COPIED into assets/<category>/library/<pack>/, so maps work in builds and on every machine.\n\nClick + ADD FOLDER to start.", 14, NeonTheme.TEXT)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(p)


func _show_detail(i: int) -> void:
	if i < 0 or i >= shown.size():
		return
	_selected = shown[i]
	var e := _selected
	for c in _detail.get_children():
		c.queue_free()
	var big := TextureRect.new()
	big.texture = ImageTexture.create_from_image(Image.load_from_file(str(e["path"]))) if FileAccess.file_exists(str(e["path"])) else null
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	big.custom_minimum_size = Vector2(360, 300)
	_detail.add_child(big)
	_detail.add_child(NeonTheme.label(str(e["name"]).to_upper(), 18, NeonTheme.CYAN))
	var info := "%s\n%s" % [e["rel"], ("index: " + str(e["index"])) if str(e["index"]) != "" else "no index entry (loose image)"]
	if big.texture:
		info += "\n%d × %d px" % [big.texture.get_width(), big.texture.get_height()]
	if not (e["tags"] as PackedStringArray).is_empty():
		info += "\ntags: " + ", ".join(e["tags"])
	var il := NeonTheme.label(info, 12, NeonTheme.TEXT_DIM)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(il)
	if str(e["text"]) != "":
		var tl := NeonTheme.label(str(e["text"]), 13, NeonTheme.TEXT)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(tl)
	var row := HBoxContainer.new()
	_detail.add_child(row)
	row.add_child(NeonTheme.label("Import as", 13, NeonTheme.TEXT_DIM))
	var cats: Array = ForgeStore.ASSET_CATEGORIES.keys().filter(func(k: String) -> bool: return not k in ["music", "sfx", "voice", "incoming"])
	var pick := ForgeForm._option(cats, str(e["category"]), func(k: String) -> void: e["category"] = k)
	row.add_child(pick)
	var clean := CheckBox.new()
	clean.text = "Key out the flat background (Art Cutter)"
	clean.button_pressed = ExternalLibrary.has_flat_background(str(e["path"]))
	_detail.add_child(clean)
	var have := ExternalLibrary.imported_path(e)
	if have != "":
		var hl := NeonTheme.label("✔ In the project: " + have + ("\n⚠ The original changed since; re-import to update." if ExternalLibrary.is_stale(e) else ""), 13, NeonTheme.GREEN)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(hl)
	var imp := Button.new()
	imp.text = "RE-IMPORT (update the copy)" if have != "" else "IMPORT INTO PROJECT"
	imp.pressed.connect(func() -> void:
		var res := import_one(e, clean.button_pressed)
		if res != "":
			_filter()
			_show_detail(shown.find(e)))
	_detail.add_child(imp)
	var sel := _grid.get_selected_items()
	if sel.size() > 1:
		var many := Button.new()
		many.text = "IMPORT ALL %d SELECTED" % sel.size()
		many.pressed.connect(func() -> void: import_many(Array(sel).map(func(k: int) -> Dictionary: return shown[k])))
		_detail.add_child(many)


func import_one(e: Dictionary, clean: Variant = null) -> String:
	var do_clean: bool = clean if clean != null else ExternalLibrary.has_flat_background(str(e["path"]))
	var res := ExternalLibrary.import_entry(e, str(e["category"]), do_clean)
	if res == "":
		status.emit("Couldn't read " + str(e["path"]), NeonTheme.MAGENTA)
	else:
		status.emit("Imported → " + res + "  (your original is untouched)", NeonTheme.GREEN)
	return res


func import_many(list: Array) -> void:
	var n := 0
	for e: Dictionary in list:
		if import_one(e) != "":
			n += 1
	_filter()
	status.emit("Imported %d assets into the project." % n, NeonTheme.GREEN)
