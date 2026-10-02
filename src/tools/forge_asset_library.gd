class_name ForgeAssetLibrary
extends HSplitContainer
## Asset library: drop files from your OS onto the window to COPY them into the
## project (originals are never moved), browse by category with thumbnails,
## rename, preview audio, register ground tiles as terrain, and drag any asset
## onto a path field in another section.

signal status(text: String, color: Color)

var category: String = "tiles"
var _grid: AssetGrid
var _cat_bar: HFlowContainer
var _detail: VBoxContainer
var _player: AudioStreamPlayer
var _selected: String = ""


class AssetGrid extends ItemList:
	var paths: Array[String] = []

	func _get_drag_data(at_position: Vector2) -> Variant:
		var idx := get_item_at_position(at_position, true)
		if idx < 0:
			return null
		var preview := Label.new()
		preview.text = "⇢ " + paths[idx].get_file()
		set_drag_preview(preview)
		return {"asset_path": paths[idx]}


func _ready() -> void:
	split_offset = 900
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	_cat_bar = HFlowContainer.new()
	_cat_bar.add_theme_constant_override("h_separation", 6)
	left.add_child(_cat_bar)
	var drop := PanelContainer.new()
	drop.add_theme_stylebox_override("panel", _dashed())
	var drop_l := NeonTheme.label("DROP FILES ANYWHERE ON THIS WINDOW  ▸  they're COPIED into assets/%s — your originals stay put" % category, 14, NeonTheme.GREEN)
	drop_l.name = "DropLabel"
	drop_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop.add_child(drop_l)
	left.add_child(drop)
	var t := create_tween().set_loops()
	t.tween_property(drop, "modulate:a", 0.65, 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(drop, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	_grid = AssetGrid.new()
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.max_columns = 0
	_grid.icon_mode = ItemList.ICON_MODE_TOP
	_grid.fixed_icon_size = Vector2i(96, 96)
	_grid.fixed_column_width = 120
	_grid.same_column_width = true
	_grid.item_selected.connect(_on_select)
	left.add_child(_grid)
	var right := PanelContainer.new()
	right.custom_minimum_size.x = 340
	add_child(right)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	right.add_child(_detail)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_build_categories()
	refresh()


func _dashed() -> StyleBoxFlat:
	var sb := NeonTheme.panel_box(Color(NeonTheme.GREEN, 0.7), Color(NeonTheme.GREEN, 0.05))
	sb.set_border_width_all(1)
	sb.set_content_margin_all(14)
	return sb


func _build_categories() -> void:
	for c in _cat_bar.get_children():
		c.queue_free()
	for cat: String in ForgeStore.ASSET_CATEGORIES:
		var b := Button.new()
		var count := ForgeStore.list_assets(cat).size()
		b.text = "%s  %d" % [ForgeStore.ASSET_CATEGORIES[cat]["label"], count]
		b.toggle_mode = true
		b.button_pressed = cat == category
		if cat == category:
			b.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.GREEN, 0.2), NeonTheme.GREEN))
		var id := cat
		b.pressed.connect(func() -> void: category = id; _build_categories(); refresh())
		_cat_bar.add_child(b)
	var links := Button.new()
	var broken := AssetRefs.broken()
	links.text = "⚕ LINKS OK" if broken.is_empty() else "⚕ %d BROKEN LINKS" % broken.size()
	links.tooltip_text = "Finds data that points at missing art (renamed or moved files) and re-links what it can."
	if not broken.is_empty():
		links.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.MAGENTA, 0.15), NeonTheme.MAGENTA))
	links.pressed.connect(func() -> void:
		var r := AssetRefs.repair_all()
		var left: Array = r["left"]
		status.emit("Re-linked %d reference(s).%s" % [r["fixed"], "" if left.is_empty() else "  Still missing: " + ", ".join(PackedStringArray(left.slice(0, 4).map(func(x: String) -> String: return x.get_file())))], NeonTheme.GREEN if left.is_empty() else NeonTheme.AMBER)
		_build_categories())
	_cat_bar.add_child(links)


func refresh() -> void:
	_grid.clear()
	_grid.paths.clear()
	var lbl := find_child("DropLabel", true, false) as Label
	if lbl:
		lbl.text = "DROP FILES ANYWHERE ON THIS WINDOW  ▸  copied into assets/%s — your originals stay put" % category
	for p in ForgeStore.list_assets(category):
		var ext := p.get_extension().to_lower()
		var icon: Texture2D = ForgeStore.load_texture(p) if ext in ForgeStore.IMAGE_EXT else null
		var label := p.get_file().get_basename()
		var sub := p.get_base_dir().trim_prefix(str(ForgeStore.ASSET_CATEGORIES[category]["dir"])).trim_prefix("/")
		if sub != "":
			label = sub + "/" + label
		if ext in ForgeStore.AUDIO_EXT:
			label = "♪ " + label
		elif ext == "tres":
			label = "⧉ " + label
		_grid.add_item(label, icon)
		_grid.paths.append(p)
	if _grid.item_count == 0:
		_grid.add_item("Nothing here yet — drop some %s in." % str(ForgeStore.ASSET_CATEGORIES[category]["label"]).to_lower())
		_grid.set_item_disabled(0, true)
		_grid.paths.append("")
	_show_detail("")


## Called by NeonForge when files are dropped on the window over this panel.
func accept_os_files(files: PackedStringArray) -> bool:
	var done := 0
	for f in files:
		var cat := category
		var ext := f.get_extension().to_lower()
		if ext in ForgeStore.AUDIO_EXT and cat not in ["music", "sfx", "voice"]:
			cat = "sfx"
		elif ext in ForgeStore.IMAGE_EXT and cat in ["music", "sfx", "voice"]:
			cat = "tiles"
		if ForgeStore.import_file(f, cat) != "":
			done += 1
	status.emit("Copied %d file(s) into the project. Originals untouched." % done, NeonTheme.GREEN)
	_build_categories()
	refresh()
	return done > 0


func _on_select(idx: int) -> void:
	_show_detail(_grid.paths[idx] if idx < _grid.paths.size() else "")


func _show_detail(path: String) -> void:
	_selected = path
	for c in _detail.get_children():
		c.queue_free()
	if path == "":
		_detail.add_child(NeonTheme.label("SELECT AN ASSET", 20, NeonTheme.TEXT_DIM))
		var tip := NeonTheme.label("Tip: drag a thumbnail onto any path field (portraits, sprites, tile textures, voice lines) in the other sections.", 14, NeonTheme.TEXT_DIM)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(tip)
		return
	var ext := path.get_extension().to_lower()
	if ext in ForgeStore.IMAGE_EXT:
		var tr := TextureRect.new()
		tr.texture = ForgeStore.load_texture(path)
		tr.custom_minimum_size = Vector2(300, 220)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_detail.add_child(tr)
		if tr.texture:
			_detail.add_child(NeonTheme.label("%d × %d px" % [tr.texture.get_width(), tr.texture.get_height()], 13, NeonTheme.TEXT_DIM))
	elif ext in ForgeStore.AUDIO_EXT:
		var play := Button.new()
		play.text = "▶  PLAY"
		play.pressed.connect(func() -> void:
			_player.stream = ForgeStore.load_audio(path)
			_player.play())
		_detail.add_child(play)
		var stop := Button.new()
		stop.text = "■  STOP"
		stop.pressed.connect(_player.stop)
		_detail.add_child(stop)
	var path_l := NeonTheme.label(path, 12, NeonTheme.CYAN)
	path_l.add_theme_font_override("font", NeonTheme.mono())
	path_l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_detail.add_child(path_l)
	_detail.add_child(NeonTheme.label("NAME", 12, NeonTheme.TEXT_DIM))
	var name_edit := LineEdit.new()
	name_edit.text = path.get_file().get_basename()
	name_edit.text_submitted.connect(func(t: String) -> void:
		var np := ForgeStore.rename_asset(path, t)
		status.emit("Renamed to %s" % np.get_file(), NeonTheme.GREEN)
		refresh())
	_detail.add_child(name_edit)
	var intake := Button.new()
	var known := not AssetIndex.find_by_path(path).is_empty()
	intake.text = "EDIT INTAKE…" if known else "RUN INTAKE…"
	intake.tooltip_text = "Re-open the intake wizard for this file: type, name, role, animation, linked content."
	intake.pressed.connect(func() -> void: _open_intake(path))
	_detail.add_child(intake)
	if category == "tiles":
		_tile_register_ui(path)
	elif category == "units" and ext in ForgeStore.IMAGE_EXT:
		var slice := Button.new()
		slice.text = "SLICE INTO ANIMATIONS…"
		slice.tooltip_text = "Turn this sheet into SpriteFrames (one animation per row)."
		slice.pressed.connect(func() -> void: _open_slicer(path))
		_detail.add_child(slice)


## Ground tiles become paintable terrain in the Map Painter.
func _tile_register_ui(path: String) -> void:
	var tid := ForgeStore.slugify(path.get_file().get_basename())
	var existing: Dictionary = ContentDB.terrain.get(tid, {})
	_detail.add_child(NeonTheme.label("TERRAIN TILE" if existing.is_empty() else "TERRAIN TILE  ✔ registered", 18, NeonTheme.VIOLET))
	var def := existing.duplicate() if not existing.is_empty() else {"name": path.get_file().get_basename().capitalize(), "texture": path, "color": "#2a2438", "side": "#1a1626", "move_cost": 1, "cover": 0, "walkable": true, "blocks_los": false}
	var form := ForgeForm.new()
	form.build_dict(def, "terrain", true)
	_detail.add_child(form)
	var save := Button.new()
	save.text = "REGISTER / UPDATE TERRAIN '%s'" % tid
	save.pressed.connect(func() -> void:
		ContentDB.terrain[tid] = form.get_data()
		var out := ForgeStore.save_dict_file("terrain", ContentDB.terrain)
		status.emit("Terrain '%s' saved ▸ %s" % [tid, out], NeonTheme.GREEN))
	_detail.add_child(save)


## Asks the hosting Neon Forge to open the intake wizard in edit mode (falls
## back to a standalone dialog when the library runs on its own).
func _open_intake(path: String) -> void:
	var host: Node = get_parent()
	while host and not host.has_method("open_intake"):
		host = host.get_parent()
	var dlg: ForgeIntake
	if host:
		dlg = host.open_intake(PackedStringArray(), path)
	else:
		dlg = ForgeIntake.new()
		dlg.status.connect(status.emit)
		get_tree().root.add_child(dlg)
		dlg.start_edit(path)
	dlg.finished.connect(func(_n: int) -> void: refresh())


func _open_slicer(path: String) -> void:
	var dlg := ForgeSpriteSlicer.new()
	dlg.sheet_path = path
	dlg.done.connect(func(frames_path: String) -> void:
		status.emit("Animations saved ▸ %s" % frames_path, NeonTheme.GREEN)
		refresh())
	get_tree().root.add_child(dlg)
	dlg.popup_centered(Vector2i(760, 620))
