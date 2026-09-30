extends Control
## NEON FORGE — the in-game asset & campaign editor.
##
## Everything the game loads from data/*.json is editable here: classes,
## abilities, cards, statuses, items, characters, NPCs, quests, missions
## (encounters + win conditions), loot, dispatch errands, vendors, recipes,
## terrain, rumors — plus an asset library (drop files from your desktop) and a
## map painter. Saves go straight into res://data so every edit is a git diff.
##
## Shortcuts: Ctrl+S save all · Ctrl+N new · Ctrl+D duplicate · Ctrl+F search ·
## Ctrl+Enter playtest · F1 back to the game.

const SECTIONS := [
	# [id, label, kind, bucket/file]
	["assets", "ASSETS", "assets", ""],
	["maps", "MAPS & ENCOUNTERS", "maps", ""],
	["cutscenes", "CUTSCENES", "cutscenes", ""],
	["characters", "CHARACTERS", "bucket", "characters"],
	["npcs", "NPCS & DIALOG", "bucket", "npcs"],
	["quests", "QUESTS", "bucket", "quests"],
	["missions", "MISSIONS", "bucket", "missions"],
	["classes", "CLASSES", "bucket", "classes"],
	["abilities", "ABILITIES", "bucket", "abilities"],
	["cards", "CARDS", "bucket", "cards"],
	["items", "ITEMS & GEAR", "bucket", "items"],
	["status_effects", "STATUS EFFECTS", "bucket", "status_effects"],
	["loot_tables", "LOOT TABLES", "bucket", "loot_tables"],
	["dispatch_missions", "DISPATCH", "bucket", "dispatch_missions"],
	["vendors", "VENDORS", "dict", "vendors"],
	["recipes", "FORGE RECIPES", "dict", "recipes"],
	["terrain", "TERRAIN", "dict", "terrain"],
	["rumors", "RUMORS & NEWS", "dict", "rumors"],
]
const DICT_TEMPLATES := {
	"vendors": {"name": "New Vendor", "greeting": "", "price_mult": 1.0, "character_id": "", "stock": []},
	"recipes": {"from": "", "to": "", "min_level": 10, "soul_coins": 300, "materials": {}},
	"terrain": {"name": "New Terrain", "texture": "", "color": "#2a2438", "side": "#1a1626", "move_cost": 1, "cover": 0, "walkable": true, "blocks_los": false},
	"rumors": {"channel": "gossip", "text": ""},
}

var _section: String = ""
var _rail: VBoxContainer
var _rail_buttons: Dictionary = {}
var _body: Control
var _status: Label
var _validate_btn: Button
var _dirty: Dictionary = {}  # bucket/file -> true

# list+inspector state
var _list: ItemList
var _list_ids: Array = []
var _search: LineEdit
var _inspector: VBoxContainer
var _selected_id: String = ""
var _painter: ForgeMapPainter
var _assets: ForgeAssetLibrary


func _ready() -> void:
	theme = NeonTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.012, 0.045)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_build_topbar())
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	root.add_child(mid)
	mid.add_child(_build_rail())
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + s, 14)
	mid.add_child(pad)
	_body = MarginContainer.new()
	pad.add_child(_body)
	root.add_child(_build_statusbar())
	get_window().files_dropped.connect(_on_files_dropped)
	_refresh_validation()
	show_section("characters")
	flash("NEON FORGE online. Drop files anywhere. Ctrl+S saves. Edits land in %s." % ForgeStore.data_dir(), NeonTheme.CYAN)


# --- Frame -----------------------------------------------------------------

func _build_topbar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", NeonTheme.panel_box(Color(NeonTheme.GREEN, 0.8), Color(0.03, 0.015, 0.06, 1.0)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	bar.add_child(h)
	var logo := NeonTheme.label("NEON FORGE", 26, Color(0.5, 2.2, 1.3))
	h.add_child(logo)
	var sub := NeonTheme.label("//  asset & campaign editor  //  Beyond: The Neon Void", 13, NeonTheme.TEXT_DIM)
	sub.add_theme_font_override("font", NeonTheme.mono())
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sub)
	_validate_btn = Button.new()
	_validate_btn.tooltip_text = "Cross-reference check across all content."
	_validate_btn.pressed.connect(_show_problems)
	h.add_child(_validate_btn)
	var save := Button.new()
	save.text = "SAVE ALL  ⌃S"
	save.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.GREEN, 0.15), NeonTheme.GREEN))
	save.pressed.connect(save_all)
	h.add_child(save)
	var back := Button.new()
	back.text = "◂ GAME  F1"
	back.pressed.connect(_leave)
	h.add_child(back)
	return bar


func _build_rail() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", NeonTheme.panel_box(Color(NeonTheme.VIOLET, 0.3), Color(0.035, 0.02, 0.065, 1.0)))
	panel.custom_minimum_size.x = 230
	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", 2)
	panel.add_child(_rail)
	for s: Array in SECTIONS:
		if s[2] == "bucket" and not ContentDB.CATALOG.has(s[3]):
			continue
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		b.focus_mode = Control.FOCUS_NONE
		var id: String = s[0]
		b.pressed.connect(func() -> void: show_section(id))
		_rail.add_child(b)
		_rail_buttons[id] = b
	_refresh_rail()
	return panel


func _count_for(s: Array) -> int:
	match s[2]:
		"bucket": return ContentDB.get_ids(s[3]).size()
		"dict": return (ContentDB.get(s[3]) as Dictionary).size()
		"maps": return ContentDB.maps.size()
		"cutscenes": return ForgeStore.list_cutscenes().size()
		"assets":
			var n := 0
			for cat: String in ForgeStore.ASSET_CATEGORIES:
				n += ForgeStore.list_assets(cat).size()
			return n
	return 0


func _refresh_rail() -> void:
	for s: Array in SECTIONS:
		var b: Button = _rail_buttons.get(s[0])
		if b == null:
			continue
		var dirty_mark := " •" if _dirty.has(s[3]) or (s[0] == "maps" and _painter and _painter.dirty) else ""
		b.text = "%s%s   %d" % [s[1], dirty_mark, _count_for(s)]
		var active: bool = s[0] == _section
		b.add_theme_stylebox_override("normal", NeonTheme.select_box() if active else NeonTheme.button_box(Color.TRANSPARENT, Color.TRANSPARENT))
		b.add_theme_color_override("font_color", Color.WHITE if active else (NeonTheme.AMBER if dirty_mark != "" else NeonTheme.TEXT_DIM))


func _build_statusbar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", NeonTheme.panel_box(Color(NeonTheme.VIOLET, 0.3), Color(0.02, 0.01, 0.04, 1.0)))
	_status = NeonTheme.label("", 13, NeonTheme.TEXT_DIM)
	_status.add_theme_font_override("font", NeonTheme.mono())
	bar.add_child(_status)
	return bar


func flash(text: String, color: Color = NeonTheme.GREEN) -> void:
	_status.text = "▸ " + text
	_status.add_theme_color_override("font_color", Color(color.r * 1.6, color.g * 1.6, color.b * 1.6))
	var t := create_tween()
	t.tween_property(_status, "theme_override_colors/font_color", color, 0.6)


# --- Sections --------------------------------------------------------------

func _section_def(id: String) -> Array:
	for s: Array in SECTIONS:
		if s[0] == id:
			return s
	return []


func show_section(id: String) -> void:
	_section = id
	_selected_id = ""
	for c in _body.get_children():
		c.queue_free()
	_painter = null
	_assets = null
	var def := _section_def(id)
	match def[2]:
		"assets":
			_assets = ForgeAssetLibrary.new()
			_assets.status.connect(flash)
			_body.add_child(_assets)
		"cutscenes":
			var cs := ForgeCutscenes.new()
			cs.status.connect(flash)
			_body.add_child(cs)
		"maps":
			_painter = ForgeMapPainter.new()
			_painter.status.connect(func(t: String, c: Color) -> void: flash(t, c); _refresh_rail())
			_body.add_child(_painter)
		_:
			_build_list_inspector(def)
	_refresh_rail()


func _build_list_inspector(def: Array) -> void:
	var split := HSplitContainer.new()
	split.split_offset = 320
	_body.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)
	var head := NeonTheme.label(def[1], 22, NeonTheme.GREEN)
	left.add_child(head)
	_search = LineEdit.new()
	_search.placeholder_text = "search  ⌃F"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: _fill_list())
	left.add_child(_search)
	var actions := HBoxContainer.new()
	for spec in [["+ NEW", _new_entry], ["⧉ DUP", _duplicate_entry], ["✕ DEL", _delete_entry]]:
		var b := Button.new()
		b.text = spec[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		actions.add_child(b)
	left.add_child(actions)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i: int) -> void: _select(str(_list_ids[i])))
	left.add_child(_list)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_inspector = VBoxContainer.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector.add_theme_constant_override("separation", 10)
	scroll.add_child(_inspector)
	_fill_list()
	if not _list_ids.is_empty():
		_list.select(0)
		_select(str(_list_ids[0]))


func _kind() -> String:
	return _section_def(_section)[2]


func _file() -> String:
	return _section_def(_section)[3]


func _entries() -> Dictionary:
	# id -> display label
	var out := {}
	if _kind() == "bucket":
		for r: GameResource in ContentDB.get_all(_file()):
			out[r.id] = r.display_name
	else:
		var d: Dictionary = ContentDB.get(_file())
		for k: String in d:
			var rec: Variant = d[k]
			out[k] = str(rec.get("name", rec.get("text", ""))) if rec is Dictionary else ""
	return out


func _fill_list() -> void:
	_list.clear()
	_list_ids.clear()
	var q := _search.text.to_lower() if _search else ""
	var problems_by_id := _problem_ids()
	var entries := _entries()
	for id: String in entries:
		var label: String = entries[id]
		if q != "" and not (id.to_lower().contains(q) or label.to_lower().contains(q)):
			continue
		var text := "%s   ·  %s" % [label, id] if label != "" and label != id else id
		var idx := _list.add_item(text)
		if problems_by_id.has(id):
			_list.set_item_custom_fg_color(idx, NeonTheme.MAGENTA)
			_list.set_item_tooltip(idx, "\n".join(problems_by_id[id]))
		_list_ids.append(id)
		if id == _selected_id:
			_list.select(idx)


func _select(id: String) -> void:
	_selected_id = id
	for c in _inspector.get_children():
		c.queue_free()
	if _kind() == "bucket":
		var res := ContentDB.get_entry(_file(), id)
		if res:
			_inspect_resource(res)
	else:
		var d: Dictionary = ContentDB.get(_file())
		if d.has(id):
			_inspect_dict(id, d[id])


func _inspect_header(title: String, id: String) -> void:
	var h := HBoxContainer.new()
	var t := NeonTheme.label(title if title != "" else id, 30, NeonTheme.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	h.add_child(t)
	var idl := NeonTheme.label(id, 13, NeonTheme.GREEN)
	idl.add_theme_font_override("font", NeonTheme.mono())
	h.add_child(idl)
	_inspector.add_child(h)
	var probs: Array = _problem_ids().get(id, [])
	for p: String in probs:
		_inspector.add_child(NeonTheme.label("⚠ " + p, 13, NeonTheme.MAGENTA))


func _inspect_resource(res: GameResource) -> void:
	_inspect_header(res.display_name, res.id)
	if res is CharacterData:
		_character_tools(res as CharacterData)
	var form := ForgeForm.new()
	form.build_resource(res)
	var bucket := _file()
	form.changed.connect(func(key: String) -> void:
		var old_id := res.id
		res.apply_dict(form.get_data())
		if key == "id" and res.id != old_id and res.id != "":
			ForgeStore.rename_entry(bucket, old_id, res)
			_selected_id = res.id
		_mark_dirty(bucket)
		if key in ["id", "display_name"]:
			_fill_list())
	_inspector.add_child(form)


func _inspect_dict(key: String, rec: Variant) -> void:
	var file := _file()
	_inspect_header(str(rec.get("name", "")) if rec is Dictionary else "", key)
	if not rec is Dictionary:
		return
	var form := ForgeForm.new()
	form.build_dict(rec, file)
	form.changed.connect(func(_k: String) -> void:
		(ContentDB.get(file) as Dictionary)[key] = form.get_data()
		_mark_dirty(file))
	_inspector.add_child(form)


## Characters get a big drop zone for portraits / animation sheets + playtest.
func _character_tools(c: CharacterData) -> void:
	var zone := PanelContainer.new()
	zone.add_theme_stylebox_override("panel", NeonTheme.panel_box(Color(NeonTheme.AMBER, 0.7), Color(NeonTheme.AMBER, 0.05)))
	zone.set_meta("character_drop", c.id)
	var h := HBoxContainer.new()
	zone.add_child(h)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = ForgeStore.load_texture(c.portrait_path)
	portrait.visible = portrait.texture != null
	h.add_child(portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(NeonTheme.label("DROP A CHARACTER SHEET OR ANIMATION SHEET ON THIS BOX", 15, NeonTheme.AMBER))
	var sub := NeonTheme.label("Portraits are copied to assets/portraits. Animation sheets go to assets/units and open the slicer (rows → idle, walk, attack…).", 13, NeonTheme.TEXT_DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var row := HBoxContainer.new()
	v.add_child(row)
	var play := Button.new()
	play.text = "▶ PLAYTEST IN PARTY"
	play.tooltip_text = "Save, then fight 'The Brew Plan' with this character in the crew."
	play.pressed.connect(func() -> void: _playtest_character(c))
	row.add_child(play)
	if c.sprite_sheet_path != "":
		var reslice := Button.new()
		reslice.text = "RE-SLICE SHEET"
		reslice.pressed.connect(func() -> void: _open_slicer(c, c.sprite_sheet_path))
		row.add_child(reslice)
	_inspector.add_child(zone)


func _handle_character_drop(char_id: String, files: PackedStringArray) -> void:
	var c := ContentDB.get_character(char_id)
	if c == null or files.is_empty():
		return
	var src := files[0]
	var img := Image.load_from_file(src)
	if img == null:
		flash("That doesn't look like an image.", NeonTheme.MAGENTA)
		return
	# Wide or tall multi-frame images are animation sheets; near-square single images are portraits.
	var ratio := float(img.get_width()) / maxf(img.get_height(), 1)
	var is_sheet := ratio > 1.6 or ratio < 0.6 or img.get_width() >= 512
	var dlg := ConfirmationDialog.new()
	dlg.title = "WHAT IS THIS?"
	dlg.dialog_text = "%s  (%d×%d)\nLooks like %s." % [src.get_file(), img.get_width(), img.get_height(), "an animation sheet" if is_sheet else "a portrait"]
	dlg.ok_button_text = "ANIMATION SHEET"
	dlg.cancel_button_text = "PORTRAIT"
	dlg.confirmed.connect(func() -> void:
		var dest := ForgeStore.import_file(src, "units", char_id + "_sheet")
		c.sprite_sheet_path = dest
		_mark_dirty("characters")
		_open_slicer(c, dest))
	dlg.canceled.connect(func() -> void:
		c.portrait_path = ForgeStore.import_file(src, "portraits", char_id)
		_mark_dirty("characters")
		_select(char_id))
	add_child(dlg)
	dlg.popup_centered()


func _open_slicer(c: CharacterData, sheet: String) -> void:
	var s := ForgeSpriteSlicer.new()
	s.sheet_path = sheet
	s.character_id = c.id
	s.done.connect(func(frames_path: String) -> void:
		c.sprite_frames_path = frames_path
		_mark_dirty("characters")
		flash("Animations saved ▸ %s  (assigned to %s)" % [frames_path, c.display_name], NeonTheme.GREEN)
		_select(c.id))
	add_child(s)
	s.popup_centered(Vector2i(780, 620))


func _playtest_character(c: CharacterData) -> void:
	save_all()
	GameManager.new_game()
	var copy := GameManager.add_character_to_roster(c)
	var party: Array[String] = [copy.id]
	for id in GameManager.STARTING_ROSTER:
		if party.size() < GameManager.MAX_PARTY_SIZE and id != copy.id:
			party.append(id)
	GameManager.set_active_party(party)
	CampaignManager.start_mission("m01_the_brew_plan")


# --- CRUD ------------------------------------------------------------------

func _new_entry() -> void:
	if _kind() == "bucket":
		var bucket := _file()
		var res: GameResource = ContentDB.CATALOG[bucket].new()
		res.id = ForgeStore.unique_id(bucket, "new_" + bucket.trim_suffix("s"))
		res.display_name = "New " + bucket.trim_suffix("s").replace("_", " ").capitalize()
		ForgeStore.put_entry(bucket, res)
		_mark_dirty(bucket)
		_selected_id = res.id
	else:
		var d: Dictionary = ContentDB.get(_file())
		var key := "new_entry"
		var n := 2
		while d.has(key):
			key = "new_entry_%d" % n
			n += 1
		d[key] = DICT_TEMPLATES.get(_file(), {}).duplicate(true)
		_mark_dirty(_file())
		_selected_id = key
	_fill_list()
	_select(_selected_id)
	flash("Created %s — rename its id in the inspector." % _selected_id, NeonTheme.CYAN)


func _duplicate_entry() -> void:
	if _selected_id == "":
		return
	if _kind() == "bucket":
		var bucket := _file()
		var src := ContentDB.get_entry(bucket, _selected_id)
		var res: GameResource = src.get_script().new()
		res.apply_dict(src.to_dict())
		res.id = ForgeStore.unique_id(bucket, src.id + "_copy")
		res.display_name = src.display_name + " (copy)"
		ForgeStore.put_entry(bucket, res)
		_selected_id = res.id
		_mark_dirty(bucket)
	else:
		var d: Dictionary = ContentDB.get(_file())
		var key := _selected_id + "_copy"
		d[key] = d[_selected_id].duplicate(true)
		_selected_id = key
		_mark_dirty(_file())
	_fill_list()
	_select(_selected_id)


func _delete_entry() -> void:
	if _selected_id == "":
		return
	var dlg := ConfirmationDialog.new()
	dlg.title = "DELETE"
	dlg.dialog_text = "Delete '%s'? (Saved on next SAVE ALL — git has your back.)" % _selected_id
	var id := _selected_id
	dlg.confirmed.connect(func() -> void:
		if _kind() == "bucket":
			ForgeStore.remove_entry(_file(), id)
		else:
			(ContentDB.get(_file()) as Dictionary).erase(id)
		_mark_dirty(_file())
		_selected_id = ""
		_fill_list()
		for c in _inspector.get_children():
			c.queue_free()
		dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


func _mark_dirty(file: String) -> void:
	_dirty[file] = true
	_refresh_rail()


func save_all() -> void:
	var written: Array[String] = []
	for file: String in _dirty.keys():
		var kind := "bucket" if ContentDB.CATALOG.has(file) else "dict"
		var path := ForgeStore.save_bucket(file) if kind == "bucket" else ForgeStore.save_dict_file(file, ContentDB.get(file))
		if path != "":
			written.append(path.get_file())
	_dirty.clear()
	if _painter and _painter.dirty:
		_painter.save_map()
		written.append("map")
	ClassLibrary._rebuild()
	_refresh_validation()
	_refresh_rail()
	if _list:
		_fill_list()
	flash("COMMITTED ▸ " + (", ".join(written) if not written.is_empty() else "nothing to save"), NeonTheme.GREEN)


# --- Validation ------------------------------------------------------------

var _problems: Array[String] = []


func _refresh_validation() -> void:
	_problems = ContentDB.validate()
	_validate_btn.text = "✔ ALL LINKS VALID" if _problems.is_empty() else "⚠ %d PROBLEMS" % _problems.size()
	_validate_btn.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.GREEN, 0.08), Color(NeonTheme.GREEN, 0.5)) if _problems.is_empty() else NeonTheme.button_box(Color(NeonTheme.MAGENTA, 0.15), NeonTheme.MAGENTA))


## Maps "class foo -> missing ability bar" style messages onto the ids they mention.
func _problem_ids() -> Dictionary:
	var out := {}
	for p in _problems:
		var parts := p.split(" ")
		if parts.size() >= 2:
			var id := parts[1]
			if not out.has(id):
				out[id] = []
			out[id].append(p)
	return out


func _show_problems() -> void:
	_refresh_validation()
	var dlg := AcceptDialog.new()
	dlg.title = "CROSS-REFERENCE CHECK"
	dlg.dialog_text = "Everything links up. Ship it." if _problems.is_empty() else "\n".join(_problems.slice(0, 40))
	add_child(dlg)
	dlg.popup_centered()


# --- Input & drops ---------------------------------------------------------

func _on_files_dropped(files: PackedStringArray) -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	var node: Node = hovered
	while node and node != self:
		if node.has_meta("character_drop"):
			_handle_character_drop(str(node.get_meta("character_drop")), files)
			return
		if node.has_method("accept_os_files"):
			if node.accept_os_files(files):
				flash("Imported %s" % files[0].get_file(), NeonTheme.GREEN)
				return
		node = node.get_parent()
	# Anywhere else: into the asset library.
	if _section != "assets":
		show_section("assets")
	_assets.accept_os_files(files)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F1:
		_leave()
	elif k.ctrl_pressed and k.keycode == KEY_S:
		save_all()
	elif k.ctrl_pressed and k.keycode == KEY_N and _list:
		_new_entry()
	elif k.ctrl_pressed and k.keycode == KEY_D and _list:
		_duplicate_entry()
	elif k.ctrl_pressed and k.keycode == KEY_F and _search:
		_search.grab_focus()
	elif k.ctrl_pressed and k.keycode == KEY_ENTER:
		if _painter:
			_painter.playtest()
		elif _section == "characters" and _selected_id != "":
			_playtest_character(ContentDB.get_character(_selected_id))
	else:
		return
	get_viewport().set_input_as_handled()


func _leave() -> void:
	if not _dirty.is_empty():
		save_all()
	SceneManager.change_scene(SceneManager.MAIN_MENU)
