class_name ForgeMapPainter
extends HSplitContainer
## Map & encounter painter.
##
## Tools: terrain brush · raise · lower · cover · sight-blocker · player spawn ·
## enemy (writes into the selected mission's encounter) · prop (hidden loot +
## found/empty popup text) · erase. Drag to paint, middle/right-drag to pan,
## wheel to zoom, Ctrl+Z to undo. SAVE writes data/maps/<id>.json (and the
## missions file when you placed enemies). PLAYTEST drops you into the fight.

signal status(text: String, color: Color)

enum Tool { TERRAIN, RAISE, LOWER, COVER, SIGHT, SPAWN, ENEMY, PROP, ERASE }

const TOOL_INFO := [
	["TERRAIN", "Paint the selected terrain."],
	["RAISE", "Raise height +1 (drag to sculpt)."],
	["LOWER", "Lower height -1."],
	["COVER", "Cycle cover: none → half → full."],
	["SIGHT", "Toggle 'blocks line of sight'."],
	["SPAWN", "Toggle a player spawn point (order = deploy order)."],
	["ENEMY", "Place the chosen enemy into the selected mission's encounter."],
	["PROP", "Place / select a prop. Give it hidden loot and popup text."],
	["ERASE", "Remove spawn, enemy or prop on a tile."],
]

var map: Dictionary = {}
var grid := IsometricGrid.new()
var tool: Tool = Tool.TERRAIN
var terrain_brush: String = "concrete"
var mission_id: String = ""
var enemy_id: String = "doctrine_warden"
var enemy_level: int = 2
var dirty: bool = false
var dirty_missions: bool = false

var _vp: SubViewport
var _vpc: SubViewportContainer
var _world: Node2D
var _cam: Camera2D
var _markers: MarkerLayer
var _tiles: Dictionary = {}
var _tool_buttons: Array[Button] = []
var _map_pick: OptionButton
var _mission_pick: OptionButton
var _inspector: VBoxContainer
var _painting: bool = false
var _panning: bool = false
var _last_cell: Vector2i = Vector2i(-99, -99)
var _undo: Array[Dictionary] = []
var _hover: Vector2i = Vector2i(-1, -1)


class MarkerLayer extends Node2D:
	var painter: ForgeMapPainter

	func _draw() -> void:
		if painter == null or painter.grid.width == 0:
			return
		var font := NeonTheme.mono()
		var spawns: Array = painter.map.get("spawns", {}).get("player", [])
		for i in spawns.size():
			var c := Vector2i(int(spawns[i][0]), int(spawns[i][1]))
			var p := painter.grid.grid_to_world(c)
			draw_circle(p, 10, Color(0.2, 1.6, 0.9, 0.85))
			draw_string(font, p + Vector2(-4, 5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, NeonTheme.BG)
		for e: Dictionary in painter.mission_enemies():
			var c2 := Vector2i(int(e["cell"][0]), int(e["cell"][1]))
			var p2 := painter.grid.grid_to_world(c2)
			draw_circle(p2, 11, Color(2.0, 0.3, 0.8, 0.9))
			var ch := ContentDB.get_character(str(e.get("character_id", "")))
			var tag := (ch.display_name if ch else str(e.get("character_id", "?"))).left(2).to_upper()
			draw_string(font, p2 + Vector2(-8, 5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
			draw_string(font, p2 + Vector2(-10, 24), "L%d" % int(e.get("level", 1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, NeonTheme.MAGENTA)
		for prop: Dictionary in painter.map.get("props", []):
			var c3 := Vector2i(int(prop["cell"][0]), int(prop["cell"][1]))
			var p3 := painter.grid.grid_to_world(c3) + Vector2(0, -8)
			var tex := ForgeStore.load_texture(str(prop.get("asset", "")))
			if tex:
				var s := minf(56.0 / tex.get_width(), 72.0 / tex.get_height())
				draw_texture_rect(tex, Rect2(p3 - Vector2(tex.get_width() * s * 0.5, tex.get_height() * s), Vector2(tex.get_width(), tex.get_height()) * s), false)
			var loot := str(prop.get("loot_item_id", "")) != ""
			var diamond := PackedVector2Array([p3 + Vector2(0, -9), p3 + Vector2(8, 0), p3 + Vector2(0, 9), p3 + Vector2(-8, 0)])
			draw_colored_polygon(diamond, Color(2.0, 1.6, 0.3) if loot else Color(0.6, 1.4, 2.0))
		if painter.grid.in_bounds(painter._hover):
			var hp := painter.grid.grid_to_world(painter._hover)
			draw_string(font, hp + Vector2(18, -18), "%d,%d  h%d" % [painter._hover.x, painter._hover.y, painter.grid.get_height(painter._hover)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, NeonTheme.CYAN)


func _ready() -> void:
	split_offset = 260
	add_child(_build_tools())
	var mid_right := HSplitContainer.new()
	mid_right.split_offset = -360
	add_child(mid_right)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_right.add_child(center)
	center.add_child(_build_topbar())
	_vpc = SubViewportContainer.new()
	_vpc.stretch = true
	_vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vpc.gui_input.connect(_on_view_input)
	_vpc.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_vpc)
	_vp = SubViewport.new()
	_vp.handle_input_locally = false
	_vpc.add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-4000, -4000)
	_vp.add_child(bg)
	_world = Node2D.new()
	_vp.add_child(_world)
	_markers = MarkerLayer.new()
	_markers.painter = self
	_markers.z_as_relative = false
	_markers.z_index = 4095
	_vp.add_child(_markers)
	_cam = Camera2D.new()
	_vp.add_child(_cam)
	_cam.make_current()
	var insp_panel := PanelContainer.new()
	insp_panel.custom_minimum_size.x = 340
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	insp_panel.add_child(scroll)
	_inspector = VBoxContainer.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inspector)
	mid_right.add_child(insp_panel)
	var first: String = ContentDB.maps.keys()[0] if not ContentDB.maps.is_empty() else ""
	if first != "":
		load_map(first)
	else:
		new_map("new_map", 12, 12)


# --- UI construction -------------------------------------------------------

func _build_tools() -> Control:
	var panel := PanelContainer.new()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)
	v.add_child(_section("TOOLS"))
	for i in TOOL_INFO.size():
		var b := Button.new()
		b.text = "%d  %s" % [i + 1, TOOL_INFO[i][0]]
		b.tooltip_text = TOOL_INFO[i][1]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		var idx := i
		b.pressed.connect(func() -> void: set_tool(idx))
		_tool_buttons.append(b)
		v.add_child(b)
	v.add_child(_section("TERRAIN BRUSH"))
	var tlist := ItemList.new()
	tlist.custom_minimum_size.y = 260
	tlist.fixed_icon_size = Vector2i(28, 28)
	var keys: Array = ContentDB.terrain.keys()
	for k: String in keys:
		var def: Dictionary = ContentDB.terrain[k]
		var icon := ForgeStore.load_texture(str(def.get("texture", "")))
		if icon == null:
			var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
			img.fill(Color(str(def.get("color", "#333333"))))
			icon = ImageTexture.create_from_image(img)
		tlist.add_item(str(def.get("name", k)), icon)
	tlist.item_selected.connect(func(i: int) -> void:
		terrain_brush = keys[i]
		set_tool(Tool.TERRAIN))
	v.add_child(tlist)
	v.add_child(_section("ENCOUNTER"))
	v.add_child(NeonTheme.label("Mission", 12, NeonTheme.TEXT_DIM))
	var mids: Array = ContentDB.get_ids("missions")
	_mission_pick = ForgeForm._option([""] + mids, "", func(m: String) -> void:
		mission_id = m
		_markers.queue_redraw())
	v.add_child(_mission_pick)
	v.add_child(NeonTheme.label("Enemy to place", 12, NeonTheme.TEXT_DIM))
	var chars := ContentDB.get_ids("characters")
	v.add_child(ForgeForm._ref_picker("characters", enemy_id, func(c: String) -> void: enemy_id = c; set_tool(Tool.ENEMY)))
	v.add_child(NeonTheme.label("Level", 12, NeonTheme.TEXT_DIM))
	v.add_child(ForgeForm._spin(enemy_level, true, func(n: float) -> void: enemy_level = int(n)))
	return panel


func _section(text: String) -> Label:
	var l := NeonTheme.label(text, 12, NeonTheme.VIOLET)
	l.add_theme_font_override("font", NeonTheme.mono())
	return l


func _build_topbar() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(NeonTheme.label("MAP", 12, NeonTheme.TEXT_DIM))
	_map_pick = OptionButton.new()
	_map_pick.custom_minimum_size.x = 260
	_map_pick.item_selected.connect(func(i: int) -> void: load_map(_map_pick.get_item_text(i)))
	h.add_child(_map_pick)
	var nw := Button.new()
	nw.text = "+ NEW"
	nw.pressed.connect(_new_map_dialog)
	h.add_child(nw)
	var resize := Button.new()
	resize.text = "RESIZE"
	resize.pressed.connect(_resize_dialog)
	h.add_child(resize)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	var undo := Button.new()
	undo.text = "↶ UNDO"
	undo.tooltip_text = "Ctrl+Z"
	undo.pressed.connect(undo_last)
	h.add_child(undo)
	var play := Button.new()
	play.text = "▶ PLAYTEST"
	play.tooltip_text = "Save and fight on this map (uses the selected mission, or a test encounter)."
	play.pressed.connect(playtest)
	h.add_child(play)
	var save := Button.new()
	save.text = "SAVE MAP"
	save.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.GREEN, 0.15), NeonTheme.GREEN))
	save.pressed.connect(save_map)
	h.add_child(save)
	_refresh_map_pick()
	return h


func _refresh_map_pick() -> void:
	_map_pick.clear()
	var ids: Array = ContentDB.maps.keys()
	if not map.is_empty() and not ids.has(map.get("id")):
		ids.append(map["id"])
	for i in ids.size():
		_map_pick.add_item(str(ids[i]))
		if ids[i] == map.get("id", ""):
			_map_pick.selected = i


func set_tool(t: int) -> void:
	tool = t as Tool
	for i in _tool_buttons.size():
		_tool_buttons[i].button_pressed = i == t
		_tool_buttons[i].add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.GREEN, 0.2), NeonTheme.GREEN) if i == t else NeonTheme.button_box(Color(0.1, 0.06, 0.17, 0.95), Color(NeonTheme.VIOLET, 0.55)))
	status.emit("Tool: %s — %s" % TOOL_INFO[t], NeonTheme.CYAN)


# --- Map lifecycle ---------------------------------------------------------

func load_map(id: String) -> void:
	var src: Dictionary = ContentDB.get_map(id)
	if src.is_empty():
		return
	map = src.duplicate(true)
	if not map.has("spawns"):
		map["spawns"] = {"player": [], "enemy": []}
	if not map.has("props"):
		map["props"] = []
	grid = IsometricGrid.new()
	grid.load_dict(map, ContentDB.terrain)
	_undo.clear()
	dirty = false
	# Auto-select the first mission that uses this map.
	for m: MissionResource in ContentDB.get_all("missions"):
		if m.map_id == id:
			mission_id = m.id
			var idx := ContentDB.get_ids("missions").find(m.id)
			if _mission_pick:
				_mission_pick.selected = idx + 1
			break
	_rebuild_tiles()
	_refresh_map_pick()
	_show_cell_inspector(Vector2i(-1, -1))


func new_map(id: String, w: int, d: int) -> void:
	grid = IsometricGrid.new()
	grid.setup(w, d)
	map = {"id": ForgeStore.slugify(id), "name": id.capitalize(), "width": w, "depth": d, "default_terrain": "concrete", "tile_width": 64, "tile_height": 32, "height_step": 16, "spawns": {"player": [], "enemy": []}, "props": []}
	dirty = true
	_undo.clear()
	_rebuild_tiles()
	_refresh_map_pick()


func _rebuild_tiles() -> void:
	for c in _world.get_children():
		c.queue_free()
	_tiles.clear()
	for c in grid.all_cells():
		var tv := TileView.new()
		tv.setup(grid, c)
		_world.add_child(tv)
		_tiles[c] = tv
	_cam.position = grid.grid_to_world(Vector2i(grid.width / 2, grid.depth / 2), false)
	_markers.queue_redraw()


func to_map_dict() -> Dictionary:
	var out := grid.to_dict()
	for k in ["id", "name", "default_terrain", "spawns", "props"]:
		out[k] = map.get(k)
	return out


func save_map() -> void:
	var path := ForgeStore.save_map(to_map_dict())
	var msg := "COMMITTED ▸ %s" % path
	if dirty_missions:
		var mp := ForgeStore.save_bucket("missions")
		msg += "  +  %s" % mp
		dirty_missions = false
	dirty = false
	status.emit(msg, NeonTheme.GREEN)
	_refresh_map_pick()


func playtest() -> void:
	save_map()
	var mission := ContentDB.get_mission(mission_id)
	if mission == null or mission.map_id != map["id"]:
		var test := MissionResource.new()
		test.apply_dict({"id": "__playtest", "display_name": "Playtest: " + str(map.get("name", map["id"])), "map_id": map["id"],
			"briefing": "Neon Forge playtest.", "enemies": [{"character_id": "doctrine_warden", "cell": [grid.width - 2, 1], "level": 2}]})
		ForgeStore.put_entry("missions", test)
		mission = test
	GameManager.new_game()
	CampaignManager.start_mission(mission.id)


func _new_map_dialog() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "NEW MAP"
	var v := VBoxContainer.new()
	v.theme = NeonTheme.get_theme()
	var name_e := LineEdit.new()
	name_e.placeholder_text = "map id, e.g. essence_factory_floor"
	v.add_child(name_e)
	var h := HBoxContainer.new()
	var w := ForgeForm._spin(12, true, func(_n: float) -> void: pass)
	var d := ForgeForm._spin(12, true, func(_n: float) -> void: pass)
	h.add_child(NeonTheme.label("W", 12))
	h.add_child(w)
	h.add_child(NeonTheme.label("D", 12))
	h.add_child(d)
	v.add_child(h)
	dlg.add_child(v)
	dlg.confirmed.connect(func() -> void:
		new_map(name_e.text if name_e.text != "" else "new_map", clampi(int(w.value), 3, 40), clampi(int(d.value), 3, 40))
		dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered(Vector2i(420, 160))


func _resize_dialog() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "RESIZE MAP"
	var h := HBoxContainer.new()
	h.theme = NeonTheme.get_theme()
	var w := ForgeForm._spin(grid.width, true, func(_n: float) -> void: pass)
	var d := ForgeForm._spin(grid.depth, true, func(_n: float) -> void: pass)
	h.add_child(w)
	h.add_child(d)
	dlg.add_child(h)
	dlg.confirmed.connect(func() -> void:
		_push_undo()
		var data := to_map_dict()
		data["width"] = clampi(int(w.value), 3, 40)
		data["depth"] = clampi(int(d.value), 3, 40)
		map = data
		grid = IsometricGrid.new()
		grid.load_dict(map, ContentDB.terrain)
		_rebuild_tiles()
		dirty = true
		dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered(Vector2i(320, 120))


# --- Undo ------------------------------------------------------------------

func _push_undo() -> void:
	_undo.append(to_map_dict().duplicate(true))
	if _undo.size() > 60:
		_undo.pop_front()


func undo_last() -> void:
	if _undo.is_empty():
		return
	map = _undo.pop_back()
	grid = IsometricGrid.new()
	grid.load_dict(map, ContentDB.terrain)
	_rebuild_tiles()
	status.emit("Undone.", NeonTheme.AMBER)


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		if k.ctrl_pressed and k.keycode == KEY_Z:
			undo_last()
		elif k.ctrl_pressed and k.keycode == KEY_S:
			save_map()
		elif k.keycode >= KEY_1 and k.keycode <= KEY_9 and not k.ctrl_pressed:
			set_tool(k.keycode - KEY_1)


# --- Painting --------------------------------------------------------------

func _view_to_world(local: Vector2) -> Vector2:
	return _vp.get_canvas_transform().affine_inverse() * local


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_cam.zoom = (_cam.zoom * 1.1).clamp(Vector2(0.3, 0.3), Vector2(4, 4))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_cam.zoom = (_cam.zoom / 1.1).clamp(Vector2(0.3, 0.3), Vector2(4, 4))
		elif mb.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_painting = mb.pressed
			_last_cell = Vector2i(-99, -99)
			if mb.pressed:
				_push_undo()
				_apply_at(grid.pick_cell(_view_to_world(mb.position)), true)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			_cam.position -= mm.relative / _cam.zoom.x
		var cell := grid.pick_cell(_view_to_world(mm.position))
		if cell != _hover:
			if _tiles.has(_hover):
				_tiles[_hover].hovered = false
				_tiles[_hover].queue_redraw()
			_hover = cell
			if _tiles.has(cell):
				_tiles[cell].hovered = true
				_tiles[cell].queue_redraw()
			_markers.queue_redraw()
		if _painting and tool in [Tool.TERRAIN, Tool.RAISE, Tool.LOWER, Tool.ERASE]:
			_apply_at(cell, false)


func _apply_at(cell: Vector2i, first: bool) -> void:
	if not grid.in_bounds(cell) or (cell == _last_cell and not first):
		return
	_last_cell = cell
	var c := grid.get_cell(cell)
	match tool:
		Tool.TERRAIN:
			c.terrain = terrain_brush
			c.tile_id = ""
			IsometricGrid.apply_terrain_defaults(c, ContentDB.terrain)
		Tool.RAISE:
			grid.set_height(cell, c.height + 1)
		Tool.LOWER:
			grid.set_height(cell, c.height - 1)
		Tool.COVER:
			c.cover = (c.cover + 1) % 3
		Tool.SIGHT:
			c.blocks_los = not c.blocks_los
		Tool.SPAWN:
			var sp: Array = map["spawns"]["player"]
			var idx := _index_of_cell(sp, cell)
			if idx >= 0:
				sp.remove_at(idx)
			else:
				sp.append([cell.x, cell.y])
		Tool.ENEMY:
			_place_enemy(cell)
		Tool.PROP:
			var props: Array = map["props"]
			var found := _prop_at(cell)
			if found.is_empty():
				found = {"id": "prop_%s_%d_%d" % [map["id"], cell.x, cell.y], "cell": [cell.x, cell.y], "asset": "", "loot_item_id": "", "found_text": "", "empty_text": "Nothing but dust and old receipts."}
				props.append(found)
			_show_prop_inspector(found)
		Tool.ERASE:
			_erase_at(cell)
	_tiles[cell].refresh()
	for n in grid.neighbors(cell):
		_tiles[n].queue_redraw()
	_markers.queue_redraw()
	dirty = true
	if tool != Tool.PROP:
		_show_cell_inspector(cell)


func _index_of_cell(list: Array, cell: Vector2i) -> int:
	for i in list.size():
		var e: Variant = list[i]
		var cc: Array = e["cell"] if e is Dictionary else e
		if int(cc[0]) == cell.x and int(cc[1]) == cell.y:
			return i
	return -1


func _prop_at(cell: Vector2i) -> Dictionary:
	var idx := _index_of_cell(map["props"], cell)
	return map["props"][idx] if idx >= 0 else {}


func mission_enemies() -> Array:
	var m := ContentDB.get_mission(mission_id)
	if m == null or m.map_id != map.get("id", ""):
		return []
	return m.enemies


func _place_enemy(cell: Vector2i) -> void:
	var m := ContentDB.get_mission(mission_id)
	if m == null:
		status.emit("Pick a mission in the ENCOUNTER box first (or create one in MISSIONS).", NeonTheme.MAGENTA)
		return
	if m.map_id != map["id"]:
		m.map_id = map["id"]
	var idx := _index_of_cell(m.enemies, cell)
	if idx >= 0:
		m.enemies.remove_at(idx)
	m.enemies.append({"character_id": enemy_id, "cell": [cell.x, cell.y], "level": enemy_level})
	dirty_missions = true


func _erase_at(cell: Vector2i) -> void:
	var sp: Array = map["spawns"]["player"]
	var i := _index_of_cell(sp, cell)
	if i >= 0:
		sp.remove_at(i)
	var pi := _index_of_cell(map["props"], cell)
	if pi >= 0:
		map["props"].remove_at(pi)
	var m := ContentDB.get_mission(mission_id)
	if m:
		var ei := _index_of_cell(m.enemies, cell)
		if ei >= 0:
			m.enemies.remove_at(ei)
			dirty_missions = true


# --- Inspector -------------------------------------------------------------

func _clear_inspector() -> void:
	for c in _inspector.get_children():
		c.queue_free()


func _show_cell_inspector(cell: Vector2i) -> void:
	_clear_inspector()
	_inspector.add_child(NeonTheme.label(str(map.get("name", map.get("id", ""))).to_upper(), 20, NeonTheme.GREEN))
	var meta := ForgeForm.new()
	meta.build_dict({"id": map.get("id", ""), "name": map.get("name", "")}, "map", true)
	meta.changed.connect(func(_k: String) -> void:
		var d := meta.get_data()
		map["id"] = ForgeStore.slugify(str(d["id"]))
		map["name"] = d["name"]
		dirty = true)
	_inspector.add_child(meta)
	var stats := "%d × %d tiles   ·   %d spawns   ·   %d props   ·   %d enemies" % [grid.width, grid.depth, map["spawns"]["player"].size(), map["props"].size(), mission_enemies().size()]
	_inspector.add_child(NeonTheme.label(stats, 12, NeonTheme.TEXT_DIM))
	if not grid.in_bounds(cell):
		var tip := NeonTheme.label("Keys 1–9 switch tools · drag to paint · middle/right-drag pans · wheel zooms · Ctrl+Z undo · Ctrl+S save", 13, NeonTheme.TEXT_DIM)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_inspector.add_child(tip)
		return
	var c := grid.get_cell(cell)
	_inspector.add_child(NeonTheme.label("TILE %d,%d" % [cell.x, cell.y], 16, NeonTheme.CYAN))
	var form := ForgeForm.new()
	form.build_dict({"terrain": c.terrain, "height": c.height, "cover": c.cover, "walkable": c.walkable, "blocks_los": c.blocks_los, "move_cost": c.move_cost}, "cell", true)
	form.changed.connect(func(k: String) -> void:
		var d := form.get_data()
		match k:
			"terrain":
				c.terrain = str(d["terrain"])
				IsometricGrid.apply_terrain_defaults(c, ContentDB.terrain)
			"height": grid.set_height(cell, int(d["height"]))
			"cover": c.cover = clampi(int(d["cover"]), 0, 2)
			"walkable": c.walkable = bool(d["walkable"])
			"blocks_los": c.blocks_los = bool(d["blocks_los"])
			"move_cost": c.move_cost = maxi(int(d["move_cost"]), 1)
		_tiles[cell].refresh()
		dirty = true)
	_inspector.add_child(form)


func _show_prop_inspector(prop: Dictionary) -> void:
	_clear_inspector()
	_inspector.add_child(NeonTheme.label("PROP", 20, NeonTheme.AMBER))
	var tip := NeonTheme.label("Hidden loot works like FF8/FF9: nothing marks it in-game. A unit standing next to it clicks it to search. Found = once per save.", 13, NeonTheme.TEXT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector.add_child(tip)
	var form := ForgeForm.new()
	form.build_dict(prop, "props", true)
	form.changed.connect(func(_k: String) -> void:
		prop.merge(form.get_data(), true)
		dirty = true
		_markers.queue_redraw())
	_inspector.add_child(form)
	var del := Button.new()
	del.text = "DELETE PROP"
	del.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.MAGENTA, 0.15), NeonTheme.MAGENTA))
	del.pressed.connect(func() -> void:
		map["props"].erase(prop)
		_markers.queue_redraw()
		_show_cell_inspector(Vector2i(-1, -1)))
	_inspector.add_child(del)
