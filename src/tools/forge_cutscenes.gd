class_name ForgeCutscenes
extends HSplitContainer
## Neon Forge ▸ CUTSCENES: every PARALLAX scene in data/cutscenes, with a
## breakdown (shots, timing, variables, events, missing art) and an in-game
## preview. Author scenes in tools/cutscene_builder/cutscene-builder.html,
## save the .parallax.json (or export .cutscene.json + art) and drop it here.

signal status(text: String, color: Color)

var _list: ItemList
var _paths: Array[String] = []
var _detail: VBoxContainer
var _selected: String = ""


func _ready() -> void:
	split_offset = 360
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 330
	left.add_theme_constant_override("separation", 8)
	add_child(left)
	left.add_child(NeonTheme.label("CUTSCENES", 22, NeonTheme.GREEN))
	var hint := NeonTheme.label("Drop .parallax.json / .cutscene.json files on the window to add them. Art for .cutscene.json goes in assets/cutscenes/.", 13, NeonTheme.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)
	var builder := Button.new()
	builder.text = "OPEN CUTSCENE BUILDER ↗"
	builder.tooltip_text = "Opens tools/cutscene_builder/cutscene-builder.html in your browser."
	builder.pressed.connect(_open_builder)
	left.add_child(builder)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i: int) -> void: _show(_paths[i]))
	left.add_child(_list)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	scroll.add_child(_detail)
	refresh()


func refresh() -> void:
	_list.clear()
	_paths = ForgeStore.list_cutscenes()
	for p in _paths:
		_list.add_item(p.get_file().trim_suffix(".json"))
	if not _paths.is_empty():
		_list.select(0)
		_show(_paths[0])
	else:
		_show("")


func _show(path: String) -> void:
	_selected = path
	for c in _detail.get_children():
		c.queue_free()
	if path == "":
		_detail.add_child(NeonTheme.label("No cutscenes yet — build one in the Cutscene Builder and drop it here.", 16, NeonTheme.TEXT_DIM))
		return
	var doc := CutsceneDoc.load_file(path)
	if doc == null:
		_detail.add_child(NeonTheme.label("Couldn't read this file.", 16, NeonTheme.MAGENTA))
		return
	_detail.add_child(NeonTheme.label(doc.name, 28, NeonTheme.TEXT))
	var meta := NeonTheme.label("%d×%d @ %d fps   ·   %d shots   ·   %.1fs   ·   %s" % [doc.w, doc.h, doc.fps, doc.shots.size(), doc.total_time(), path], 13, NeonTheme.TEXT_DIM)
	meta.add_theme_font_override("font", NeonTheme.mono())
	_detail.add_child(meta)
	var play := Button.new()
	play.text = "▶ PREVIEW IN GAME"
	play.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.GREEN, 0.15), NeonTheme.GREEN))
	play.pressed.connect(func() -> void: CutscenePlayer.play(get_tree().root, doc))
	_detail.add_child(play)
	for w in doc.warnings:
		_detail.add_child(NeonTheme.label("⚠ " + w, 13, NeonTheme.MAGENTA))
	if not doc.vars.is_empty():
		_detail.add_child(NeonTheme.label("VARIABLES  (the game fills these in)", 12, NeonTheme.VIOLET))
		_detail.add_child(NeonTheme.label(", ".join(doc.vars.keys().map(func(k: String) -> String: return "{%s}" % k)), 14, NeonTheme.CYAN))
	_detail.add_child(NeonTheme.label("SHOTS", 12, NeonTheme.VIOLET))
	for i in doc.shots.size():
		var S: Dictionary = doc.shots[i]
		var evs: Array = S["events"].map(func(e: Dictionary) -> String: return "%s@%.2fs" % [e.get("name", ""), float(e.get("t", 0))])
		var line := "%d. %s — %.2fs  ·  %s in  ·  %d layers%s" % [i + 1, S.get("name", "Shot"), CutsceneDoc.shot_real(S), S["tin"]["type"], S["layers"].size(), ("  ·  events: " + ", ".join(evs)) if not evs.is_empty() else ""]
		var l := NeonTheme.label(line, 14, NeonTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(l)
	var used := []
	for m: MissionResource in ContentDB.get_all("missions"):
		if path in [m.intro_cutscene, m.outro_cutscene]:
			used.append("mission " + m.display_name)
	for a: Ability in ContentDB.get_all("abilities"):
		if a.cutscene == path:
			used.append("ability " + a.display_name)
	_detail.add_child(NeonTheme.label("USED BY", 12, NeonTheme.VIOLET))
	_detail.add_child(NeonTheme.label(", ".join(used) if not used.is_empty() else "nothing yet — set intro_cutscene / outro_cutscene on a mission, or cutscene on an ability", 14, NeonTheme.TEXT_DIM))


func accept_os_files(files: PackedStringArray) -> bool:
	var n := 0
	for f in files:
		if f.ends_with(".json"):
			DirAccess.make_dir_recursive_absolute(ForgeStore.CUTSCENE_DIR)
			var dest := ForgeStore.CUTSCENE_DIR.path_join(f.get_file())
			if DirAccess.copy_absolute(f, ProjectSettings.globalize_path(dest)) == OK:
				n += 1
		elif f.get_extension().to_lower() in ForgeStore.IMAGE_EXT + ForgeStore.AUDIO_EXT:
			DirAccess.make_dir_recursive_absolute("res://assets/cutscenes")
			if DirAccess.copy_absolute(f, ProjectSettings.globalize_path("res://assets/cutscenes".path_join(f.get_file()))) == OK:
				n += 1
	CutsceneDoc.reset_index()
	status.emit("Added %d file(s) to cutscenes." % n, NeonTheme.GREEN)
	refresh()
	return n > 0


func _open_builder() -> void:
	var p := ProjectSettings.globalize_path("res://tools/cutscene_builder/cutscene-builder.html")
	if FileAccess.file_exists(p):
		OS.shell_open(p)
	else:
		status.emit("Builder not found at tools/cutscene_builder/.", NeonTheme.MAGENTA)
