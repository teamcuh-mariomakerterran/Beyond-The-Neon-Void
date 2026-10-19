class_name ForgeDialog
extends HSplitContainer
## Neon Forge ▸ DIALOG: every NPC's conversation as a node graph. Drag from a
## node's right port to another node to set where it goes; drag into empty
## space to make the next line there. Choice nodes get one port per answer.
## Edits go straight into the NPC's `dialog` (data/npcs.json, the same data
## NPCS & DIALOG shows as a form), so Ctrl+S / SAVE writes them.
##
## Voice: each node shows the file it plays (DialogTools.voice_path) with a
## dot that lights up once the recording exists. Drop an audio file on a node
## to make it that node's line; VOICE SCRIPT writes the recording list.

signal status(text: String, color: Color)
## A bucket was edited (Neon Forge marks it dirty for Ctrl+S).
signal edited(bucket: String)
## SAVE pressed inside Neon Forge (it saves everything dirty, like Ctrl+S).
signal save_requested

const LINE_COLOR := Color(0.25, 0.95, 1.0)
const CHOICE_COLOR := Color(1.0, 0.78, 0.34)

var npc: NPCResource
var graph: GraphEdit
var _list: ItemList
var _ids: Array[String] = []
var _problems: Label
var _player: AudioStreamPlayer
var _selected_node: String = ""


func _ready() -> void:
	split_offset = 300
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 260
	left.add_theme_constant_override("separation", 8)
	add_child(left)
	left.add_child(NeonTheme.label("DIALOG", 22, NeonTheme.GREEN))
	var hint := NeonTheme.label("Drag a port to a node to link it, into empty space for a new line. Del removes selected nodes. Drop audio on a node to voice it.", 12, NeonTheme.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)
	var studio := Button.new()
	studio.text = "OPEN CHIRP STUDIO ↗"
	studio.tooltip_text = "Voice lines for ElevenLabs (tools/chirp_studio). Run chirp_bridge.py sync first to load the latest lines."
	studio.pressed.connect(_open_studio)
	left.add_child(studio)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i: int) -> void: open_npc(_ids[i]))
	left.add_child(_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	right.add_child(bar)
	for spec: Array in [["+ LINE", func() -> void: add_node(false)], ["+ CHOICE", func() -> void: add_node(true)],
			["★ MAKE START", _make_start], ["⟲ LAYOUT", _layout], ["▶ PLAY", func() -> void: play("")],
			["▶ FROM SELECTED", func() -> void: play(_selected_node)], ["🎙 VOICE SCRIPT", export_script], ["SAVE", save]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		bar.add_child(b)
	_problems = NeonTheme.label("", 13, NeonTheme.MAGENTA)
	_problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_problems)
	graph = GraphEdit.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.right_disconnects = true
	graph.show_arrange_button = false
	graph.connection_request.connect(_on_connect)
	graph.disconnection_request.connect(_on_disconnect)
	graph.connection_to_empty.connect(_on_connect_empty)
	graph.delete_nodes_request.connect(_on_delete)
	graph.node_selected.connect(func(n: Node) -> void: _selected_node = _id_of(n.name))
	graph.end_node_move.connect(_store_positions)
	right.add_child(graph)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	refresh()


func refresh() -> void:
	_list.clear()
	_ids.clear()
	for r: GameResource in ContentDB.get_all("npcs"):
		var n := r as NPCResource
		_list.add_item("%s   ·  %d" % [n.display_name, n.dialog.size()])
		_ids.append(n.id)
	if npc == null and not _ids.is_empty():
		_list.select(0)
		open_npc(_ids[0])


func open_npc(npc_id: String) -> void:
	npc = ContentDB.get_entry("npcs", npc_id) as NPCResource
	_selected_node = ""
	if npc and npc.dialog.any(func(d: Dictionary) -> bool: return not d.has("pos")):
		DialogTools.auto_layout(npc.dialog)
	rebuild()
	_frame_start.call_deferred()


## Puts the start node near the top left of the view.
func _frame_start() -> void:
	if npc and not npc.dialog.is_empty():
		var pos: Array = npc.dialog[0].get("pos", [0, 0])
		graph.scroll_offset = Vector2(float(pos[0]), float(pos[1])) * graph.zoom - Vector2(40, 40)


# --- edits (public so tests drive the same paths as the mouse) -------------

## Adds a node (linked from `from_id` if given). Returns its id.
func add_node(choice: bool, from_id: String = "", from_port: int = 0, at: Vector2 = Vector2.INF) -> String:
	if npc == null:
		return ""
	var id := DialogTools.new_id(npc.dialog, "choice" if choice else "line")
	var d := {"id": id, "text": ""}
	if choice:
		d["choices"] = [{"text": ""}, {"text": ""}]
	if at == Vector2.INF:
		at = (graph.scroll_offset + graph.size * 0.4) / graph.zoom
	d["pos"] = [at.x, at.y]
	npc.dialog.append(d)
	if from_id != "":
		link(from_id, from_port, id)
	_changed(true)
	return id


## Points output `port` of `from_id` at `to_id` ("" ends the conversation there).
func link(from_id: String, port: int, to_id: String) -> void:
	var n := npc.get_dialog_node(from_id)
	if n.is_empty():
		return
	var choices: Array = n.get("choices", [])
	if choices.is_empty():
		if to_id == "":
			n.erase("next")
		else:
			n["next"] = to_id
	elif port >= 0 and port < choices.size():
		if to_id == "":
			(choices[port] as Dictionary).erase("next")
		else:
			choices[port]["next"] = to_id
	_changed(true)


func remove_node(node_id: String) -> void:
	DialogTools.remove(npc.dialog, node_id)
	_changed(true)


func save() -> void:
	if save_requested.get_connections().size() > 0:
		save_requested.emit()
		return
	var path := ForgeStore.save_bucket("npcs")
	if path != "":
		status.emit("Saved " + path, NeonTheme.GREEN)
	else:
		status.emit("Couldn't write npcs.json (is res:// writable?)", NeonTheme.MAGENTA)


## Writes the recording script next to the voice files. Returns its path.
func export_script() -> String:
	if npc == null:
		return ""
	DirAccess.make_dir_recursive_absolute(DialogTools.VOICE_DIR)
	var path := DialogTools.VOICE_DIR.path_join("%s_script.txt" % npc.id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null or not f.store_string(DialogTools.voice_script(npc)):
		status.emit("Couldn't write " + path, NeonTheme.MAGENTA)
		return ""
	f.close()
	status.emit("Voice script: " + ProjectSettings.globalize_path(path), NeonTheme.GREEN)
	return path


func play(start_id: String) -> void:
	if npc == null or npc.dialog.is_empty():
		return
	var box := DialogueBox.new()
	get_tree().root.add_child(box)
	box.play_npc(npc, start_id)


## Audio dropped on a node is copied in as that node's voice line; anywhere
## else it's copied into assets/voice/dialog under its own name.
func accept_os_files(files: PackedStringArray) -> bool:
	if npc == null:
		return false
	var target := ""
	for c in graph.get_children():
		if c is GraphNode and (c as GraphNode).get_global_rect().has_point(get_global_mouse_position()):
			target = _id_of(c.name)
	DirAccess.make_dir_recursive_absolute(DialogTools.VOICE_DIR)
	var n := 0
	for f in files:
		var ext := f.get_extension().to_lower()
		if not ext in ForgeStore.AUDIO_EXT:
			continue
		var base := DialogTools.voice_path(npc.id, target).get_basename() if target != "" and n == 0 else DialogTools.VOICE_DIR.path_join(f.get_file().get_basename())
		if DirAccess.copy_absolute(f, ProjectSettings.globalize_path(base + "." + ext)) == OK:
			n += 1
	if n > 0:
		status.emit("Voiced '%s'" % target if target != "" else "Copied %d file(s) to assets/voice/dialog" % n, NeonTheme.GREEN)
		rebuild()
	return n > 0


# --- graph -----------------------------------------------------------------

func rebuild() -> void:
	graph.clear_connections()
	for c in graph.get_children():
		if c is GraphNode:
			graph.remove_child(c)
			c.queue_free()
	if npc == null:
		_problems.text = ""
		return
	for i in npc.dialog.size():
		graph.add_child(_make_node(i, npc.dialog[i]))
	var all := DialogTools.ids(npc.dialog)
	for i in npc.dialog.size():
		var d: Dictionary = npc.dialog[i]
		var choices: Array = d.get("choices", [])
		if choices.is_empty():
			var t := all.find(str(d.get("next", "")))
			if t >= 0:
				graph.connect_node("n%d" % i, 0, "n%d" % t, 0)
		else:
			for p in choices.size():
				var t2 := all.find(str((choices[p] as Dictionary).get("next", "")))
				if t2 >= 0:
					graph.connect_node("n%d" % i, p, "n%d" % t2, 0)
	_show_problems()


func _make_node(i: int, d: Dictionary) -> GraphNode:
	var choice := not (d.get("choices", []) as Array).is_empty()
	var g := GraphNode.new()
	g.name = "n%d" % i
	g.set_meta("d", d)  # positions / ids follow the dict, not the index
	g.title = ("★ START  ·  " if i == 0 else "") + str(d.get("id", ""))
	g.custom_minimum_size.x = 340
	var pos: Array = d.get("pos", [i * 380, 0])
	g.position_offset = Vector2(float(pos[0]), float(pos[1]))
	var col := CHOICE_COLOR if choice else LINE_COLOR
	g.self_modulate = col.lerp(Color.WHITE, 0.55)
	# Row 0: id + speaker (the input port; plain lines also output "next" here).
	var top := HBoxContainer.new()
	var id_edit := _edit(str(d.get("id", "")), "id", 110)
	id_edit.text_submitted.connect(func(t: String) -> void: _rename(str(d.get("id", "")), t, id_edit))
	id_edit.focus_exited.connect(func() -> void: _rename(str(d.get("id", "")), id_edit.text, id_edit))
	top.add_child(id_edit)
	var sp := _edit(str(d.get("speaker", "")), npc.display_name, 0)
	sp.tooltip_text = "Speaker (empty = the NPC)"
	sp.text_changed.connect(func(t: String) -> void: _put(d, "speaker", t))
	top.add_child(sp)
	g.add_child(top)
	var text := TextEdit.new()
	text.text = str(d.get("text", ""))
	text.placeholder_text = "What they say…"
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.custom_minimum_size = Vector2(320, 76)
	text.text_changed.connect(func() -> void: _put(d, "text", text.text))
	g.add_child(text)
	# Voice: own path or the conventional file; the dot lights once it exists.
	var vrow := HBoxContainer.new()
	var found := DialogTools.voice_for(npc.id, d)
	var dot := NeonTheme.label("●", 14, NeonTheme.GREEN if found != "" else NeonTheme.TEXT_DIM)
	dot.tooltip_text = ("Plays " + found) if found != "" else "No recording yet"
	vrow.add_child(dot)
	var vp := _edit(str(d.get("voice_path", "")), DialogTools.voice_path(npc.id, str(d.get("id", ""))).get_file(), 0)
	vp.tooltip_text = "Voice file (empty = the name shown, in assets/voice/dialog)"
	vp.text_changed.connect(func(t: String) -> void: _put(d, "voice_path", t))
	vrow.add_child(vp)
	var hear := Button.new()
	hear.text = "▶"
	hear.disabled = found == ""
	hear.pressed.connect(func() -> void: _hear(found))
	vrow.add_child(hear)
	g.add_child(vrow)
	var frow := HBoxContainer.new()
	var req := _edit(str(d.get("requires_flag", "")), "needs flag", 0)
	req.tooltip_text = "Skipped (follows next) until this story flag is set"
	req.text_changed.connect(func(t: String) -> void: _put(d, "requires_flag", t))
	frow.add_child(req)
	var sets := _edit(str(d.get("sets_flag", "")), "sets flag", 0)
	sets.text_changed.connect(func(t: String) -> void: _put(d, "sets_flag", t))
	frow.add_child(sets)
	g.add_child(frow)
	g.set_slot(0, true, 0, LINE_COLOR, not choice, 0, LINE_COLOR)
	if choice:
		var choices: Array = d["choices"]
		for p in choices.size():
			var ch: Dictionary = choices[p]
			var row := HBoxContainer.new()
			var ct := _edit(str(ch.get("text", "")), "answer %d" % (p + 1), 0)
			ct.text_changed.connect(func(t: String) -> void: _put(ch, "text", t))
			row.add_child(ct)
			var cf := _edit(str(ch.get("sets_flag", "")), "sets flag", 90)
			cf.size_flags_horizontal = Control.SIZE_FILL
			cf.text_changed.connect(func(t: String) -> void: _put(ch, "sets_flag", t))
			row.add_child(cf)
			var x := Button.new()
			x.text = "✕"
			x.pressed.connect(func() -> void:
				choices.remove_at(p)
				if choices.is_empty():
					d.erase("choices")
				_changed(true))
			row.add_child(x)
			g.add_child(row)
			g.set_slot(g.get_child_count() - 1, false, 0, col, true, 0, col)
		var more := Button.new()
		more.text = "+ answer"
		more.pressed.connect(func() -> void:
			choices.append({"text": ""})
			_changed(true))
		g.add_child(more)
	return g


func _edit(value: String, hint: String, min_w: int) -> LineEdit:
	var e := LineEdit.new()
	e.text = value
	e.placeholder_text = hint
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if min_w > 0:
		e.custom_minimum_size.x = min_w
		e.size_flags_horizontal = Control.SIZE_FILL
	return e


## Sets (or clears, when empty) a field without rebuilding the graph.
func _put(d: Dictionary, key: String, value: String) -> void:
	if value == "" and key != "text":
		d.erase(key)
	else:
		d[key] = value
	_changed(false)


func _rename(old_id: String, new_name: String, field: LineEdit) -> void:
	new_name = ForgeStore.slugify(new_name)
	if new_name == old_id:
		return
	if DialogTools.rename(npc.dialog, old_id, new_name):
		_changed(true)
	else:
		field.text = old_id
		status.emit("'%s' is taken (or empty)" % new_name, NeonTheme.MAGENTA)


func _changed(structure: bool) -> void:
	edited.emit("npcs")
	if structure:
		_store_positions()
		rebuild.call_deferred()
	else:
		_show_problems()


func _show_problems() -> void:
	var p := DialogTools.problems(npc.dialog) if npc else []
	_problems.text = "" if p.is_empty() else "⚠ " + "   ⚠ ".join(p)


func _id_of(node_name: StringName) -> String:
	var g := graph.get_node_or_null(NodePath(str(node_name)))
	return str((g.get_meta("d") as Dictionary).get("id", "")) if g and g.has_meta("d") else ""


func _store_positions() -> void:
	if npc == null:
		return
	for c in graph.get_children():
		if c is GraphNode and c.has_meta("d") and not c.is_queued_for_deletion():
			var o := (c as GraphNode).position_offset
			(c.get_meta("d") as Dictionary)["pos"] = [roundf(o.x), roundf(o.y)]
	edited.emit("npcs")


func _on_connect(from: StringName, port: int, to: StringName, _to_port: int) -> void:
	link(_id_of(from), port, _id_of(to))


func _on_disconnect(from: StringName, port: int, _to: StringName, _to_port: int) -> void:
	link(_id_of(from), port, "")


func _on_connect_empty(from: StringName, port: int, release: Vector2) -> void:
	add_node(false, _id_of(from), port, (release + graph.scroll_offset) / graph.zoom)


func _on_delete(names: Array[StringName]) -> void:
	var gone: Array[String] = []
	for n in names:
		gone.append(_id_of(n))
	for id in gone:
		DialogTools.remove(npc.dialog, id)
	_changed(true)


func _make_start() -> void:
	if npc == null or _selected_node == "":
		return
	for i in npc.dialog.size():
		if str(npc.dialog[i].get("id", "")) == _selected_node:
			var d: Dictionary = npc.dialog[i]
			npc.dialog.remove_at(i)
			npc.dialog.insert(0, d)
			break
	_changed(true)


func _layout() -> void:
	if npc:
		DialogTools.auto_layout(npc.dialog)
		edited.emit("npcs")
		rebuild()


func _open_studio() -> void:
	var p := ProjectSettings.globalize_path("res://tools/chirp_studio/black_doctrine_chirp_studio.html")
	if FileAccess.file_exists(p):
		OS.shell_open(p)
	else:
		status.emit("Chirp Studio not found at tools/chirp_studio/.", NeonTheme.MAGENTA)


func _hear(path: String) -> void:
	var s := DialogueBox.load_audio(path)
	if s:
		_player.stream = s
		_player.play()
