class_name ForgeWorldPainter
extends HSplitContainer
## WORLD PAINTER — the live, stacked-tile level builder.
##
## What you see here is the game renderer (WorldRenderer), so the map looks
## exactly like it will in play. Maps are sorted by kind (world / city / hub /
## interior / encounter / event) with tabs along the top.
##
## Layers you paint on:
##   TILES      stacked tiles; brush, rectangle, fill, eyedropper, erase.
##              Stack layer can go negative (below ground). Brush height
##              paints several layers at once. Shift-click tiles in the
##              palette to cycle through a set as you paint.
##   DETAILS    decals laid ON tiles (craters, debris, rivers) — free placed,
##              drag to move.
##   PARTICLES  rain, fog, storm clouds... painted per cell at any layer.
##   OBJECTS    structures, props, characters, loot and location links
##              (double-click an object to make it a city / point of interest).
##   GAMEPLAY   player spawns, enemies, walkability, cover, line of sight.
##
## Keys: B brush · R rectangle · G fill · I eyedropper · V select/move · H pan ·
## E erase · [ ] brush size · PgUp/PgDn stack layer · Ctrl+click stack on top ·
## Ctrl+Z / Ctrl+Y undo/redo · Ctrl+S save · Del delete selection · Ctrl+D
## duplicate selection · F5 play here.

signal status(text: String, color: Color)

enum Mode { TILES, DETAILS, PARTICLES, OBJECTS, GAMEPLAY, REGIONS }
enum Tool { BRUSH, RECT, FILL, PICK, SELECT, PAN, ERASE, COPY, STAMP, SCULPT, RAMP }
enum Play { SPAWN, ENEMY, BLOCK, COVER, SIGHT }

const MODE_NAMES := ["TILES", "DETAILS", "PARTICLES", "OBJECTS", "GAMEPLAY", "REGIONS"]
const TRIGGER_ON := ["enter", "exit", "interact"]
const TRIGGER_DO := ["toast", "dialog", "cutscene", "battle", "flag", "music", "teleport"]
const TRIGGER_HINT := {"toast": "text to show", "dialog": "NPC id", "cutscene": "res://data/cutscenes/….json",
	"battle": "mission id", "flag": "story flag to set", "music": "res://assets/music/….ogg", "teleport": "map_id or map_id:spawn#"}
const TOOL_INFO := [
	["✎", "Brush [B]", "Left-click / drag to paint."],
	["▭", "Rectangle [R]", "Drag a rectangle; it fills when you let go."],
	["◈", "Fill [G]", "Flood-fill the matching area on this layer."],
	["⌖", "Eyedropper [I]", "Pick the tile (and its layer) under the cursor."],
	["➚", "Select / move [V]", "Click an object or detail to edit it; drag to move. Double-click an object to set up a location."],
	["✋", "Pan [H]", "Drag to move the view (middle / right mouse always pans)."],
	["⌫", "Erase [E]", "Remove what this layer holds under the brush."],
	["⧉", "Copy area [C]", "Drag over an area to copy all of its layers (tiles + particles)."],
	["⎘", "Stamp [T]", "Click to paste the copied area; its lowest layer lands on the stack layer."],
	["⛰", "Sculpt [U]", "Raise / lower / flatten / smooth the ground under the brush (pick the mode below)."],
	["◢", "Ramp / stairs [Q]", "Slope any ground tile up to the next level. Points uphill automatically; Shift+R turns it."],
]
const TOOL_KEYS := {KEY_B: Tool.BRUSH, KEY_R: Tool.RECT, KEY_G: Tool.FILL, KEY_I: Tool.PICK, KEY_V: Tool.SELECT, KEY_H: Tool.PAN, KEY_E: Tool.ERASE, KEY_C: Tool.COPY, KEY_T: Tool.STAMP, KEY_U: Tool.SCULPT, KEY_Q: Tool.RAMP}
const SCULPT_MODES := ["raise", "lower", "flatten", "smooth"]
const RAMP_DIRS := ["x+", "y+", "x-", "y-"]
const PLAY_NAMES := ["PLAYER SPAWN", "ENEMY", "BLOCK WALK", "COVER", "SIGHT"]
const OBJECT_SOURCES := ["structures", "props", "units", "items", "vfx", "portraits", "incoming"]
const GHOST := Color(0.25, 1.9, 0.75)

var world: WorldMap = WorldMap.new()
var mode: Mode = Mode.TILES
var tool: Tool = Tool.BRUSH
var play_tool: Play = Play.SPAWN
var layer: int = 0
var brush_size: int = 1
## Off: tiles land only on the stack layer. On: the column below is filled
## too (down to the next tile or the ground) for solid cliffs and towers.
var solid_column: bool = false
var dim_above: bool = false
var kind_filter: String = "all"
var dirty: bool = false
var dirty_missions: bool = false

## Palette selections (several = cycle while painting).
var sel_tiles: Array[String] = []
var sel_detail: String = ""
var sel_particle: String = "fog"
var sel_object: String = ""
var object_source: String = "structures"
var mission_id: String = ""
var enemy_id: String = "doctrine_warden"
var enemy_level: int = 2

var selected: Dictionary = {}
var sel_region: Dictionary = {}
## Scatter: pick randomly from the selected tiles instead of cycling, and only
## paint `density`% of the cells the brush touches (forests, rubble, flowers).
var paint_random: bool = false
## Per-tile variation on placement: random mirror + slight colour jitter.
var vary_tiles: bool = false
var sculpt_mode: String = "raise"
var ramp_dir: String = "x+"
var ramp_stairs: bool = false
var mirror_x: bool = false
var mirror_y: bool = false
## Last 9 tiles used — number keys 1–9 pick them.
var recent_tiles: Array[String] = []
## Survives the trip into play-test and back (same map → same view and tools).
static var _session: Dictionary = {}
var density: int = 100
## Copied area: {"tiles": [[dx, dy, z, id]], "particles": [[dx, dy, z, preset]], "base_z": int}.
var clipboard: Dictionary = {}
const AUTOSAVE_DIR := "user://forge_autosave"
var _cam_goal: Vector2 = Vector2.ZERO
var _zoom_goal: float = 1.0
var _minimap: Minimap
var _rng := RandomNumberGenerator.new()
## Tactics view: battle-grid read-out (blocked, cover, move range from the cursor).
var tactics_view: bool = false
var xray: bool = false
var tactics_move: int = 4
var tactics_jump: int = 2
var _tgrid: IsometricGrid
var _tgrid_stamp: int = -1
var _edit_count: int = 0
var _check_btn: Button
var _cycle: int = 0
var _renderer: WorldRenderer
var _ghost: GhostLayer
var _vp: SubViewport
var _vpc: SubViewportContainer
var _cam: Camera2D
var _map_pick: OptionButton
var _kind_tabs: HFlowContainer
var _mode_buttons: Array[Button] = []
var _tool_buttons: Array[Button] = []
var _layer_spin: SpinBox
var _size_slider: HSlider
var _solid_check: CheckBox
var _palette: VBoxContainer
var _inspector: VBoxContainer
var _objects_list: VBoxContainer
var _hint: Label
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []

# pointer state
var _down: bool = false
var _panning: bool = false
var _space: bool = false
var _drag_start: Vector2i = Vector2i(-9999, -9999)
var _hover_cell: Vector2i = Vector2i(-9999, -9999)
var _hover_z: int = 0
var _hover_world: Vector2 = Vector2.ZERO
var _last_applied: Dictionary = {}
var _moving: Dictionary = {}
var _move_grab: Vector2 = Vector2.ZERO


## Draws the green ghost preview, hover read-out and gameplay markers.
class GhostLayer extends Node2D:
	var p: ForgeWorldPainter

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if p == null:
			return
		var w := p.world
		var font := NeonTheme.mono()
		# Map bounds.
		var corners := PackedVector2Array([w.to_screen(Vector2(-0.5, -0.5), 0), w.to_screen(Vector2(w.width - 0.5, -0.5), 0),
			w.to_screen(Vector2(w.width - 0.5, w.depth - 0.5), 0), w.to_screen(Vector2(-0.5, w.depth - 0.5), 0)])
		corners.append(corners[0])
		draw_polyline(corners, Color(0.55, 0.35, 0.9, 0.45), 2.0)
		if p.tactics_view:
			_draw_tactics(font)
		if p.mode == Mode.REGIONS:
			_draw_regions(font)
		if p.mode == Mode.GAMEPLAY or p.mode == Mode.OBJECTS:
			_draw_gameplay(font)
		if not w.in_bounds(p._hover_cell) and p.tool != Tool.SELECT:
			return
		var cells := p.target_cells()
		var erase := p.tool == Tool.ERASE
		var col := Color(2.0, 0.3, 0.4) if erase else GHOST
		if p.tool == Tool.COPY:
			for cell: Vector2i in cells:
				_prism(w, cell, w.top_z(cell, p.layer), Color(0.4, 1.2, 2.2))
			_hover_info(font, w)
			return
		if p.tool == Tool.STAMP and not p.clipboard.is_empty():
			var shift := p.layer - int(p.clipboard["base_z"])
			for t: Array in p.clipboard["tiles"]:
				var c2 := p._hover_cell + Vector2i(int(t[0]), int(t[1]))
				WorldRenderer.draw_tile(self, w, str(t[3]), w.to_screen(Vector2(c2), int(t[2]) + shift), 0.5)
			_hover_info(font, w)
			return
		match p.mode:
			Mode.TILES when p.tool == Tool.SCULPT:
				for cell: Vector2i in cells:
					var tzs := w.top_z(cell, p.layer)
					var goal := tzs + 1 if p.sculpt_mode == "raise" else (tzs - 1 if p.sculpt_mode == "lower" else (p.layer if p.sculpt_mode == "flatten" else tzs))
					_prism(w, cell, goal, Color(1.9, 1.4, 0.3) if p.sculpt_mode != "lower" else Color(2.0, 0.4, 0.4))
			Mode.TILES when p.tool == Tool.RAMP:
				for cell: Vector2i in cells:
					if not p.sel_tiles.is_empty():
						WorldRenderer.draw_tile(self, w, p.sel_tiles[0], w.to_screen(Vector2(cell), p._hover_z), 0.6, 0.0, {"ramp": p.ramp_for(cell, p._hover_z), "stairs": p.ramp_stairs})
					_prism(w, cell, p._hover_z, GHOST)
			Mode.TILES:
				var tz := p.target_layer()
				var n := 0
				for cell: Vector2i in cells:
					for z: int in p.layers_for(cell, tz):
						var c := w.to_screen(Vector2(cell), z)
						if not erase and not p.sel_tiles.is_empty():
							WorldRenderer.draw_tile(self, w, p.sel_tiles[(p._cycle + n) % p.sel_tiles.size()], c, 0.55)
							n += 1
						_prism(w, cell, z, col)
			Mode.PARTICLES:
				for cell: Vector2i in cells:
					var d := WorldRenderer.diamond(w, Vector2(cell), p.layer)
					draw_colored_polygon(d, Color(col, 0.18))
					d.append(d[0])
					draw_polyline(d, col, 1.5)
			Mode.OBJECTS, Mode.DETAILS:
				if p.tool in [Tool.BRUSH, Tool.RECT]:
					var asset := p.sel_object if p.mode == Mode.OBJECTS else p.sel_detail
					var tex := ForgeStore.load_texture(asset)
					if tex == null and asset.ends_with(".json") and LatticeClip.is_clip(asset):
						var clip := LatticeClip.load_clip(asset)
						if clip.get("ok", false):
							tex = LatticeClip.frame_texture(clip, 0)
					var at := p._placement_point()
					if tex:
						if p.mode == Mode.DETAILS:
							var fit := tex.get_size() * (w.tile_width / maxf(tex.get_width(), 1.0))
							draw_texture_rect(tex, Rect2(at - fit * 0.5, fit), false, Color(1, 1, 1, 0.6))
						else:
							var kind := "structure" if p.sel_object.contains("/structures/") else "prop"
							var used := WorldRenderer.fit_rect(tex)
							var sz := used.size * WorldRenderer.default_scale(w, p.sel_object, kind)
							draw_texture_rect_region(tex, Rect2(at + Vector2(-sz.x * 0.5, -sz.y + w.tile_height * 0.25), sz), used, Color(1, 1, 1, 0.6))
				for cell: Vector2i in cells:
					_prism(w, cell, p._hover_z, Color(col, 0.7))
			Mode.GAMEPLAY, Mode.REGIONS:
				for cell: Vector2i in cells:
					_prism(w, cell, w.top_z(cell, p.layer), col)
		_hover_info(font, w)

	func _hover_info(font: Font, w: WorldMap) -> void:
		var hc := w.to_screen(Vector2(p._hover_cell), p._hover_z)
		var info := "%d,%d  ·  layer %d" % [p._hover_cell.x, p._hover_cell.y, p._hover_z]
		if p.tool in [Tool.RECT, Tool.COPY] and p._down:
			var r := p._rect_cells()
			info += "  ·  %d×%d" % [absi(p._hover_cell.x - p._drag_start.x) + 1, absi(p._hover_cell.y - p._drag_start.y) + 1] if not r.is_empty() else ""
		var top := w.top_tile(p._hover_cell)
		if top != "":
			info += "  ·  " + top.get_file()
		# Scale the read-out so it stays legible at any zoom.
		var s := 1.0 / maxf(p._cam.zoom.x, 0.05)
		draw_set_transform(hc + Vector2(w.tile_width * 0.45, -w.tile_height * 0.6), 0.0, Vector2(s, s))
		draw_string(font, Vector2(1, 1), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2.ZERO, info, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, NeonTheme.CYAN)
		draw_set_transform(Vector2.ZERO)

	func _prism(w: WorldMap, cell: Vector2i, z: int, col: Color) -> void:
		var d := WorldRenderer.diamond(w, Vector2(cell), z)
		var drop := Vector2(0, w.height_step)
		draw_colored_polygon(d, Color(col.r * 0.2, col.g * 0.25, col.b * 0.2, 0.22))
		draw_colored_polygon(PackedVector2Array([d[3], d[2], d[2] + drop, d[3] + drop]), Color(col.r * 0.1, col.g * 0.2, col.b * 0.12, 0.35))
		draw_colored_polygon(PackedVector2Array([d[2], d[1], d[1] + drop, d[2] + drop]), Color(col.r * 0.08, col.g * 0.15, col.b * 0.1, 0.35))
		var outline := d.duplicate()
		outline.append(d[0])
		draw_polyline(outline, col, 1.6)
		draw_line(d[3], d[3] + drop, col, 1.6)
		draw_line(d[2], d[2] + drop, col, 1.6)
		draw_line(d[1], d[1] + drop, col, 1.6)
		draw_polyline(PackedVector2Array([d[3] + drop, d[2] + drop, d[1] + drop]), col, 1.6)

	func _draw_regions(font: Font) -> void:
		var w := p.world
		for r: Dictionary in w.regions:
			var col := Color(str(r.get("color", "#ff3fb4")))
			var strong := r == p.sel_region
			var sum := Vector2.ZERO
			var n := 0
			for k: String in r.get("cells", []):
				var c := WorldMap.parse_key(k)
				var d := WorldRenderer.diamond(w, Vector2(c), w.top_z(c))
				draw_colored_polygon(d, Color(col, 0.35 if strong else 0.15))
				sum += w.to_screen(Vector2(c), w.top_z(c))
				n += 1
			if n > 0:
				var label := "%s  ·  %d trigger(s)" % [r.get("name", "?"), (r.get("triggers", []) as Array).size()]
				draw_string(font, sum / n - Vector2(label.length() * 4, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col.lightened(0.3))

	func _draw_tactics(font: Font) -> void:
		var w := p.world
		var g := p.tactics_grid()
		for cell: Vector2i in w.tiles:
			if not g.in_bounds(cell):
				continue
			var c := g.get_cell(cell)
			var d := WorldRenderer.diamond(w, Vector2(cell), w.top_z(cell))
			if not c.walkable:
				draw_colored_polygon(d, Color(2.0, 0.2, 0.35, 0.28))
			elif c.cover > 0:
				var at := w.to_screen(Vector2(cell), w.top_z(cell))
				draw_string(font, at + Vector2(-6, 6), "◐" if c.cover == 1 else "●", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, NeonTheme.AMBER)
		var from := p._hover_cell
		if g.in_bounds(from) and g.is_walkable(from):
			var flood := g.flood(from, p.tactics_move, p.tactics_jump, 0, true)
			for cell2: Vector2i in flood:
				var d2 := WorldRenderer.diamond(w, Vector2(cell2), w.top_z(cell2))
				draw_colored_polygon(d2, Color(0.2, 1.4, 2.2, 0.22))
				d2.append(d2[0])
				draw_polyline(d2, Color(0.3, 1.6, 2.2, 0.8), 1.2)
			# Height steps around the cursor (what blocks a jump).
			for n in g.neighbors(from):
				var dh := g.get_height(n) - g.get_height(from)
				if dh != 0 and g.is_walkable(n):
					var at2 := w.to_screen(Vector2(n), w.top_z(n))
					draw_string(font, at2 + Vector2(-10, 5), "%+d" % dh, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(2.0, 0.4, 0.5) if absi(dh) > p.tactics_jump else Color(1.6, 1.6, 1.6))

	func _draw_gameplay(font: Font) -> void:
		var w := p.world
		var sp: Array = w.spawns.get("player", [])
		for i in sp.size():
			var c := Vector2i(int(sp[i][0]), int(sp[i][1]))
			var at := w.to_screen(Vector2(c), w.top_z(c))
			draw_circle(at, 12, Color(0.2, 1.6, 0.9, 0.85))
			draw_string(font, at + Vector2(-4, 5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, NeonTheme.BG)
		for e: Dictionary in p.mission_enemies():
			var c2 := Vector2i(int(e["cell"][0]), int(e["cell"][1]))
			var at2 := w.to_screen(Vector2(c2), w.top_z(c2))
			draw_circle(at2, 13, Color(2.0, 0.3, 0.8, 0.9))
			draw_string(font, at2 + Vector2(-10, 5), str(e.get("character_id", "?")).left(2).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		for cell: Vector2i in w.gameplay:
			var g: Dictionary = w.gameplay[cell]
			var at3 := w.to_screen(Vector2(cell), w.top_z(cell))
			var tag := ""
			if g.has("walkable") and not bool(g["walkable"]): tag += "✕"
			if int(g.get("cover", 0)) > 0: tag += "◐" if int(g["cover"]) == 1 else "●"
			if bool(g.get("blocks_los", false)): tag += "◉"
			if tag != "":
				draw_string(font, at3 + Vector2(-10, 5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, NeonTheme.AMBER)
		for o: Dictionary in w.locations():
			var loc: Dictionary = o["location"]
			var c3 := Vector2i(int(o["cell"][0]), int(o["cell"][1]))
			var at4 := w.to_screen(Vector2(c3), float(o.get("z", 0))) + Vector2(0, -90)
			var label := str(loc.get("name", "?")) + ("" if str(loc.get("target_map", "")) != "" else "  (no link)")
			draw_string(font, at4 - Vector2(label.length() * 3.5, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, NeonTheme.GREEN)


# --- Build UI --------------------------------------------------------------

func _ready() -> void:
	split_offset = 300
	add_child(_build_left())
	var mid_right := HBoxContainer.new()
	mid_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(mid_right)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_right.add_child(center)
	center.add_child(_build_topbar())
	_vpc = SubViewportContainer.new()
	_vpc.stretch = true
	_vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vpc.mouse_filter = Control.MOUSE_FILTER_STOP
	_vpc.gui_input.connect(_on_view_input)
	var view_stack := Control.new()
	view_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_stack.clip_contents = true
	center.add_child(view_stack)
	_vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_stack.add_child(_vpc)
	_minimap = Minimap.new()
	_minimap.p = self
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_minimap.custom_minimum_size = Vector2(240, 150)
	_minimap.offset_left = -252
	_minimap.offset_top = -162
	_minimap.offset_right = -12
	_minimap.offset_bottom = -12
	view_stack.add_child(_minimap)
	_vp = SubViewport.new()
	_vp.handle_input_locally = false
	_vp.use_hdr_2d = true
	_vpc.add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05)
	bg.size = Vector2(40000, 40000)
	bg.position = Vector2(-20000, -20000)
	bg.z_index = -4096
	_vp.add_child(bg)
	_renderer = WorldRenderer.new()
	_renderer.editor_markers = true
	_vp.add_child(_renderer)
	_ghost = GhostLayer.new()
	_ghost.p = self
	_ghost.z_as_relative = false
	_ghost.z_index = 4090
	_vp.add_child(_ghost)
	_cam = Camera2D.new()
	_vp.add_child(_cam)
	_cam.make_current()
	_hint = NeonTheme.label("", 12, NeonTheme.TEXT_DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 100
	center.add_child(_hint)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 380
	mid_right.add_child(right)
	var insp := _scroll_panel(func(v: VBoxContainer) -> void: _inspector = v)
	insp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	insp.size_flags_stretch_ratio = 1.6
	right.add_child(insp)
	var objs := _scroll_panel(func(v: VBoxContainer) -> void: _objects_list = v)
	objs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(objs)
	var first := ""
	for id: String in ContentDB.maps:
		if int(ContentDB.maps[id].get("format", 1)) >= 2:
			first = id
			break
	if first != "":
		load_map(first)
	else:
		new_map("new_world", "world", 24, 24)
	set_mode(Mode.TILES)
	set_tool(Tool.BRUSH)
	_restore_session()
	_rng.randomize()
	var autosave := Timer.new()
	autosave.wait_time = 90.0
	autosave.autostart = true
	autosave.timeout.connect(_autosave)
	add_child(autosave)


func _scroll_panel(assign: Callable) -> Control:
	var panel := PanelContainer.new()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)
	assign.call(v)
	return panel


func _section(text: String, color: Color = NeonTheme.VIOLET) -> Label:
	var l := NeonTheme.label("●  " + text, 12, color)
	l.add_theme_font_override("font", NeonTheme.mono())
	return l


func _build_left() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 300
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	v.add_child(_section("LAYER"))
	var modes := GridContainer.new()
	modes.columns = 3
	for i in MODE_NAMES.size():
		var b := Button.new()
		b.text = MODE_NAMES[i]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.pressed.connect(func() -> void: set_mode(idx))
		_mode_buttons.append(b)
		modes.add_child(b)
	v.add_child(modes)
	# Tool card, like the reference: icon row + stack layer + brush sliders.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", NeonTheme.panel_box(Color(NeonTheme.CYAN, 0.5)))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	var tools := HBoxContainer.new()
	for i in TOOL_INFO.size():
		var tb := Button.new()
		tb.text = TOOL_INFO[i][0]
		tb.tooltip_text = "%s\n%s" % [TOOL_INFO[i][1], TOOL_INFO[i][2]]
		tb.custom_minimum_size = Vector2(34, 34)
		tb.toggle_mode = true
		var ti := i
		tb.pressed.connect(func() -> void: set_tool(ti))
		_tool_buttons.append(tb)
		tools.add_child(tb)
	cv.add_child(tools)
	var lh := HBoxContainer.new()
	lh.add_child(NeonTheme.label("Stack layer", 14))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(sp)
	var minus := Button.new()
	minus.text = "−"
	minus.pressed.connect(func() -> void: set_layer(layer - 1))
	lh.add_child(minus)
	_layer_spin = SpinBox.new()
	_layer_spin.min_value = WorldMap.MIN_Z
	_layer_spin.max_value = WorldMap.MAX_Z
	_layer_spin.value = 0
	_layer_spin.value_changed.connect(func(n: float) -> void: set_layer(int(n)))
	lh.add_child(_layer_spin)
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(func() -> void: set_layer(layer + 1))
	lh.add_child(plus)
	cv.add_child(lh)
	var tip := NeonTheme.label("Ctrl + click: stack on the tile under the cursor. Negative layers dig below ground.", 11, NeonTheme.TEXT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(tip)
	_size_slider = _slider(cv, "Brush Size", 1, 12, 1, func(n: int) -> void: brush_size = n)
	_solid_check = CheckBox.new()
	_solid_check.text = "Solid column (also fill the layers below)"
	_solid_check.tooltip_text = "Off: paint only on the stack layer.\nOn: fill down to the next tile or the ground — quick cliffs and towers."
	_solid_check.toggled.connect(func(on: bool) -> void: solid_column = on)
	cv.add_child(_solid_check)
	var rnd := CheckBox.new()
	rnd.text = "Scatter: random pick from selected tiles"
	rnd.tooltip_text = "Off: cycle through the selected tiles in order. On: random — great for forests, rubble, flowers."
	rnd.toggled.connect(func(on: bool) -> void: paint_random = on)
	cv.add_child(rnd)
	_slider(cv, "Density %", 5, 100, 100, func(n: int) -> void: density = n)
	var vary := CheckBox.new()
	vary.text = "Variation: random flip + colour jitter"
	vary.tooltip_text = "Each placed tile is randomly mirrored and slightly tinted, so big areas don't look stamped."
	vary.toggled.connect(func(on: bool) -> void: vary_tiles = on)
	cv.add_child(vary)
	var mir := HBoxContainer.new()
	mir.add_child(NeonTheme.label("Mirror", 13))
	for axis: String in ["X", "Y"]:
		var mb := CheckBox.new()
		mb.text = axis
		mb.tooltip_text = "Paint mirrored across the map's %s centre line." % ("left-right" if axis == "X" else "top-bottom")
		var ax := axis
		mb.toggled.connect(func(on: bool) -> void:
			if ax == "X": mirror_x = on
			else: mirror_y = on)
		mir.add_child(mb)
	cv.add_child(mir)
	var sc := HBoxContainer.new()
	sc.add_child(NeonTheme.label("Sculpt", 13))
	sc.add_child(ForgeForm._option(SCULPT_MODES, sculpt_mode, func(m: String) -> void:
		sculpt_mode = m
		set_tool(Tool.SCULPT)))
	var st := CheckBox.new()
	st.text = "Stairs"
	st.tooltip_text = "Ramp tool draws steps instead of a smooth slope."
	st.toggled.connect(func(on: bool) -> void: ramp_stairs = on)
	sc.add_child(st)
	cv.add_child(sc)
	var dim := CheckBox.new()
	dim.text = "Fade layers above the stack layer"
	dim.toggled.connect(func(on: bool) -> void:
		dim_above = on
		_renderer.dim_above = layer if on else 999
		_renderer.redraw_all_columns())
	cv.add_child(dim)
	v.add_child(card)
	_palette = VBoxContainer.new()
	_palette.add_theme_constant_override("separation", 6)
	v.add_child(_palette)
	return panel


func _slider(parent: Control, text: String, lo: int, hi: int, value: int, cb: Callable) -> HSlider:
	var h := HBoxContainer.new()
	h.add_child(NeonTheme.label(text, 14))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var num := NeonTheme.label(str(value), 14, NeonTheme.CYAN)
	h.add_child(num)
	parent.add_child(h)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = value
	s.value_changed.connect(func(n: float) -> void:
		num.text = str(int(n))
		cb.call(int(n)))
	parent.add_child(s)
	return s


func _build_topbar() -> Control:
	var v := VBoxContainer.new()
	_kind_tabs = HFlowContainer.new()
	for k: String in ["all"] + WorldMap.KINDS:
		var b := Button.new()
		b.text = k.to_upper()
		b.toggle_mode = true
		b.button_pressed = k == kind_filter
		var kk := k
		b.pressed.connect(func() -> void:
			kind_filter = kk
			for c: Button in _kind_tabs.get_children():
				c.button_pressed = c.text == kk.to_upper()
			_refresh_map_pick())
		_kind_tabs.add_child(b)
	v.add_child(_kind_tabs)
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 6)
	_map_pick = OptionButton.new()
	_map_pick.custom_minimum_size.x = 220
	_map_pick.clip_text = true
	_map_pick.item_selected.connect(func(i: int) -> void: load_map(str(_map_pick.get_item_metadata(i))))
	h.add_child(_map_pick)
	var nw := Button.new()
	nw.text = "+ NEW"
	nw.pressed.connect(_new_map_dialog)
	h.add_child(nw)
	for pair: Array in [["↶", "Undo (Ctrl+Z)", undo_last], ["↷", "Redo (Ctrl+Y)", redo_last],
			["⊕", "Zoom in", func() -> void: _zoom(1.25)], ["⊖", "Zoom out", func() -> void: _zoom(0.8)], ["⌂", "Frame the map", frame_map]]:
		var b2 := Button.new()
		b2.text = pair[0]
		b2.tooltip_text = pair[1]
		b2.pressed.connect(pair[2])
		h.add_child(b2)
	var tac := Button.new()
	tac.text = "◇ TACTICS"
	tac.toggle_mode = true
	tac.tooltip_text = "Tactics view: red = blocked, cover marks, and the move range (move %d / jump %d) from the cursor." % [tactics_move, tactics_jump]
	tac.toggled.connect(func(on: bool) -> void:
		tactics_view = on
		_style_toggle(tac, on))
	h.add_child(tac)
	var xr := Button.new()
	xr.text = "◎ X-RAY"
	xr.toggle_mode = true
	xr.tooltip_text = "See-through cutaway: tiles and objects in front of the cursor fade (what the game does for the player)."
	xr.toggled.connect(func(on: bool) -> void:
		xray = on
		_style_toggle(xr, on)
		if not on:
			_renderer.set_cutaway(Vector2.INF, 0, 0))
	h.add_child(xr)
	var links := Button.new()
	links.text = "⛬ LINKS"
	links.tooltip_text = "Location graph: every map and the doors / teleports between them. Click a map to open it."
	links.pressed.connect(show_links)
	h.add_child(links)
	_check_btn = Button.new()
	_check_btn.text = "⚠ CHECK"
	_check_btn.tooltip_text = "Find broken links, missing art, bad spawns and unreachable enemies."
	_check_btn.pressed.connect(show_issues)
	h.add_child(_check_btn)
	var play := Button.new()
	play.text = "▶ PLAY HERE"
	play.tooltip_text = "F5 — save, then walk this map (world/city/hub/interior) or fight on it (encounter)."
	play.pressed.connect(play_here)
	h.add_child(play)
	var save := Button.new()
	save.text = "SAVE"
	save.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.GREEN, 0.15), NeonTheme.GREEN))
	save.pressed.connect(save_map)
	h.add_child(save)
	v.add_child(h)
	return v


func _refresh_map_pick() -> void:
	_map_pick.clear()
	var ids: Array = ContentDB.maps.keys()
	if not ids.has(world.id):
		ids.append(world.id)
	ids.sort()
	for id: String in ids:
		var d: Dictionary = ContentDB.maps.get(id, {})
		var k := world.kind if id == world.id else str(d.get("kind", "encounter"))
		if kind_filter != "all" and k != kind_filter and id != world.id:
			continue
		var fmt := 2 if id == world.id else int(d.get("format", 1))
		_map_pick.add_item("%s   [%s%s]" % [id, k, "" if fmt >= 2 else " · classic"])
		_map_pick.set_item_metadata(_map_pick.item_count - 1, id)
		if id == world.id:
			_map_pick.selected = _map_pick.item_count - 1


# --- Mode / tool ------------------------------------------------------------

func _style_toggle(b: Button, on: bool) -> void:
	b.button_pressed = on
	b.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.CYAN, 0.28), NeonTheme.CYAN) if on else NeonTheme.button_box(Color(0.1, 0.06, 0.17, 0.95), Color(NeonTheme.VIOLET, 0.55)))


func set_mode(m: int) -> void:
	mode = m as Mode
	for i in _mode_buttons.size():
		_style_toggle(_mode_buttons[i], i == m)
	_build_palette()
	_hint_text()


func set_tool(t: int) -> void:
	tool = t as Tool
	for i in _tool_buttons.size():
		_style_toggle(_tool_buttons[i], i == t)
	_hint_text()


func set_layer(z: int) -> void:
	layer = clampi(z, WorldMap.MIN_Z, WorldMap.MAX_Z)
	if _layer_spin and int(_layer_spin.value) != layer:
		_layer_spin.set_value_no_signal(layer)
	if dim_above:
		_renderer.dim_above = layer
		_renderer.redraw_all_columns()


func _hint_text() -> void:
	if _hint:
		_hint.text = "  %s · %s — %s    [wheel zoom · middle/right drag pan · Ctrl+click stack on top · Shift+click palette to cycle]" % [MODE_NAMES[mode], TOOL_INFO[tool][1], TOOL_INFO[tool][2]]


# --- Palette ---------------------------------------------------------------

func _build_palette() -> void:
	if _palette == null:
		return
	for c in _palette.get_children():
		c.queue_free()
	match mode:
		Mode.TILES: _palette_tiles()
		Mode.DETAILS: _palette_assets("details", func(p: String) -> void: sel_detail = p, func() -> String: return sel_detail)
		Mode.PARTICLES: _palette_particles()
		Mode.OBJECTS: _palette_objects()
		Mode.GAMEPLAY: _palette_gameplay()
		Mode.REGIONS: _palette_regions()


func _tile_groups() -> Dictionary:
	var groups := {}
	var tdb: Dictionary = ContentDB.get("tiles") if ContentDB.get("tiles") is Dictionary else {}
	for id: String in tdb:
		var g := str(tdb[id].get("group", id.get_base_dir()))
		if not groups.has(g):
			groups[g] = []
		groups[g].append(id)
	var terr: Array = []
	for t: String in ContentDB.terrain:
		terr.append("terrain:" + t)
	groups["~ flat colour terrain"] = terr
	return groups


func _palette_stamps() -> void:
	var stamps := list_stamps()
	_palette.add_child(_section("STAMPS (%d)" % stamps.size(), NeonTheme.CYAN))
	var row := HFlowContainer.new()
	for path: String in stamps:
		var b := Button.new()
		b.text = "⎘ " + path.get_file().get_basename().replace("_", " ")
		b.tooltip_text = "Load this stamp, then click the map to place it."
		var pp := path
		b.pressed.connect(func() -> void: load_stamp(pp))
		row.add_child(b)
	var save := Button.new()
	save.text = "＋ SAVE STAMP"
	save.tooltip_text = "Save what you copied (C) as a reusable stamp."
	save.disabled = clipboard.is_empty()
	save.pressed.connect(func() -> void:
		var dlg := ConfirmationDialog.new()
		dlg.title = "SAVE STAMP"
		var e := LineEdit.new()
		e.placeholder_text = "e.g. neon bar front, ruined car, stair run"
		e.custom_minimum_size.x = 360
		dlg.add_child(e)
		dlg.confirmed.connect(func() -> void:
			save_stamp(e.text if e.text != "" else "stamp")
			_build_palette()
			dlg.queue_free())
		add_child(dlg)
		dlg.popup_centered())
	row.add_child(save)
	_palette.add_child(row)


func _remember_tile(tid: String) -> void:
	recent_tiles.erase(tid)
	recent_tiles.push_front(tid)
	if recent_tiles.size() > 9:
		recent_tiles.resize(9)


func pick_recent(i: int) -> void:
	if i < recent_tiles.size():
		sel_tiles = [recent_tiles[i]]
		if tool not in [Tool.BRUSH, Tool.RECT, Tool.FILL, Tool.RAMP, Tool.SCULPT]:
			set_tool(Tool.BRUSH)
		if mode != Mode.TILES:
			set_mode(Mode.TILES)
		else:
			_build_palette()
		status.emit("Tile %d: %s" % [i + 1, sel_tiles[0].get_file()], NeonTheme.CYAN)


func _palette_tiles() -> void:
	if not recent_tiles.is_empty():
		_palette.add_child(_section("RECENT  (keys 1–9)", NeonTheme.CYAN))
		var rr := HFlowContainer.new()
		for i in recent_tiles.size():
			var b := Button.new()
			b.custom_minimum_size = Vector2(44, 44)
			var fr := WorldRenderer.tile_frames(recent_tiles[i])
			if not fr.is_empty():
				b.icon = fr[0]
				b.expand_icon = true
			b.text = str(i + 1)
			b.tooltip_text = recent_tiles[i]
			_style_toggle(b, sel_tiles.has(recent_tiles[i]))
			var ii := i
			b.pressed.connect(func() -> void: pick_recent(ii))
			rr.add_child(b)
		_palette.add_child(rr)
	_palette_stamps()
	var top := HBoxContainer.new()
	var info := NeonTheme.label(_sel_text(), 12, NeonTheme.CYAN)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(info)
	var rescan := Button.new()
	rescan.text = "⟳ RESCAN"
	rescan.tooltip_text = "Re-index assets/tiles (new files, animated water/river sets)."
	var gen := Button.new()
	gen.text = "⛰ GENERATE"
	gen.tooltip_text = "Sculpt terrain from noise. Select tiles low → high first (e.g. water, sand, grass, forest, rock, snow)."
	gen.pressed.connect(_generate_dialog)
	top.add_child(gen)
	rescan.pressed.connect(func() -> void:
		var idx: Dictionary = TileIndex.scan()
		TileIndex.save(idx)
		ContentDB.set("tiles", idx)
		_build_palette()
		status.emit("Tile index rebuilt: %d tiles." % idx.size(), NeonTheme.GREEN))
	top.add_child(rescan)
	_palette.add_child(top)
	var groups := _tile_groups()
	var names: Array = groups.keys()
	names.sort()
	for g: String in names:
		var ids: Array = groups[g]
		ids.sort()
		_palette.add_child(_section("%s (%d)" % [g.to_upper() if g != "" else "TILES", ids.size()], NeonTheme.TEXT_DIM))
		var grid := GridContainer.new()
		grid.columns = 5
		for id: String in ids:
			var b := Button.new()
			b.custom_minimum_size = Vector2(50, 50)
			b.tooltip_text = "%s\nclick: select · shift+click: add to cycle" % id
			var frames := WorldRenderer.tile_frames(id)
			if frames.is_empty():
				var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
				img.fill(Color(str(ContentDB.terrain.get(WorldMap.terrain_of(id), {}).get("color", "#333333"))))
				b.icon = ImageTexture.create_from_image(img)
			else:
				b.icon = frames[0]
				if frames.size() > 1:
					b.text = "≈"
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_style_toggle(b, sel_tiles.has(id))
			var tid := id
			b.pressed.connect(func() -> void:
				if Input.is_key_pressed(KEY_SHIFT):
					if sel_tiles.has(tid):
						sel_tiles.erase(tid)
					else:
						sel_tiles.append(tid)
				else:
					sel_tiles = [tid]
				_remember_tile(tid)
				_cycle = 0
				if tool in [Tool.PICK, Tool.SELECT, Tool.PAN, Tool.ERASE]:
					set_tool(Tool.BRUSH)
				_build_palette())
			grid.add_child(b)
		_palette.add_child(grid)
	if ContentDB.get("tiles") == null or (ContentDB.get("tiles") as Dictionary).is_empty():
		var t := NeonTheme.label("No tile art indexed yet. Drop tiles into assets/tiles (the sync bot does this) and press RESCAN. Flat colour terrain works meanwhile.", 12, NeonTheme.AMBER)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_palette.add_child(t)


func _sel_text() -> String:
	if sel_tiles.is_empty():
		return "Pick a tile. Shift+click more to cycle them."
	if sel_tiles.size() == 1:
		return "Painting: " + sel_tiles[0]
	return "Cycling %d tiles as you paint" % sel_tiles.size()


## Clip JSONs (Grok animations) under a folder, recursively.
static func _clips_under(dir: String, out: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json") and LatticeClip.is_clip(dir.path_join(f)) and not LatticeClip.is_overlay(dir.path_join(f)):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_clips_under(dir.path_join(d), out)


func _asset_paths(category: String) -> Array[String]:
	if ForgeStore.ASSET_CATEGORIES.has(category):
		# Animated clips replace their own strip PNGs in the palette.
		var clips: Array[String] = []
		_clips_under(str(ForgeStore.ASSET_CATEGORIES[category]["dir"]), clips)
		var out: Array[String] = []
		out.append_array(clips)
		for p in ForgeStore.list_assets(category):
			if LatticeClip.find_for_png(p) == "":
				out.append(p)
		return out
	var out: Array[String] = []
	var dir := "res://assets/" + category
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			if f.get_extension().to_lower() in ForgeStore.IMAGE_EXT:
				out.append(dir.path_join(f))
	return out


func _palette_assets(category: String, pick: Callable, current: Callable) -> void:
	var paths := _asset_paths(category)
	var filter := LineEdit.new()
	filter.placeholder_text = "filter %d %s…" % [paths.size(), category]
	_palette.add_child(filter)
	var grid := GridContainer.new()
	grid.columns = 4
	_palette.add_child(grid)
	var fill := func(q: String) -> void:
		for c in grid.get_children():
			c.queue_free()
		for p: String in paths:
			if q != "" and not p.to_lower().contains(q.to_lower()):
				continue
			var b := Button.new()
			b.custom_minimum_size = Vector2(62, 62)
			if p.ends_with(".json"):
				var clip := LatticeClip.load_clip(p)
				b.icon = LatticeClip.frame_texture(clip, 0) if clip.get("ok", false) else null
				b.text = "▶"
			else:
				b.icon = ForgeStore.load_texture(p)
			b.expand_icon = true
			b.tooltip_text = p.trim_prefix("res://assets/")
			_style_toggle(b, current.call() == p)
			var pp := p
			b.pressed.connect(func() -> void:
				pick.call(pp)
				if tool in [Tool.PICK, Tool.PAN, Tool.ERASE, Tool.FILL]:
					set_tool(Tool.BRUSH)
				for c2: Button in grid.get_children():
					_style_toggle(c2, c2.tooltip_text == pp.trim_prefix("res://assets/")))
			grid.add_child(b)
	filter.text_changed.connect(fill)
	fill.call("")
	if paths.is_empty():
		var t := NeonTheme.label("Nothing in assets/%s yet — drop files onto the Forge window to add some." % category, 12, NeonTheme.AMBER)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_palette.add_child(t)


func _palette_particles() -> void:
	var presets: Dictionary = ParticleFactory.presets()
	var tip := NeonTheme.label("Paint weather and atmosphere on any stack layer: fog on 1–3 hugs mountain tops, storm clouds on 15 roll over everything.", 12, NeonTheme.TEXT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_palette.add_child(tip)
	var grid := GridContainer.new()
	grid.columns = 2
	for id: String in presets:
		var b := Button.new()
		b.text = str(presets[id].get("name", id))
		b.icon = ParticleFactory.preview_icon(id)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_toggle(b, sel_particle == id)
		var pid := id
		b.pressed.connect(func() -> void:
			sel_particle = pid
			if tool in [Tool.PICK, Tool.SELECT, Tool.PAN]:
				set_tool(Tool.BRUSH)
			_build_palette())
		grid.add_child(b)
	_palette.add_child(grid)
	var show := CheckBox.new()
	show.text = "Show particles in the editor"
	show.button_pressed = _renderer.show_particles
	show.toggled.connect(func(on: bool) -> void:
		_renderer.show_particles = on
		_renderer.rebuild_particles())
	_palette.add_child(show)


func _palette_objects() -> void:
	var src := ForgeForm._option(OBJECT_SOURCES, object_source, func(s: String) -> void:
		object_source = s
		_build_palette())
	_palette.add_child(src)
	_palette.add_child(_section("NEON LIGHTS", NeonTheme.MAGENTA))
	var lights := HFlowContainer.new()
	for preset: String in WorldRenderer.LIGHT_PRESETS:
		var b := Button.new()
		b.text = preset.replace("_", " ")
		var col := Color(str(WorldRenderer.LIGHT_PRESETS[preset]["color"]))
		b.add_theme_color_override("font_color", col.lightened(0.2))
		_style_toggle(b, sel_object == "light:" + preset)
		var pr := preset
		b.pressed.connect(func() -> void:
			sel_object = "light:" + pr
			set_tool(Tool.BRUSH)
			_build_palette()
			status.emit("Click a tile to hang a %s light. Toggle the lighting preview in the map panel." % pr.replace("_", " "), col))
		lights.add_child(b)
	_palette.add_child(lights)
	_palette.add_child(_section("ASSETS"))
	_palette_assets(object_source, func(p: String) -> void: sel_object = p, func() -> String: return sel_object)


func _palette_regions() -> void:
	var tip := NeonTheme.label("Paint an area with the brush or rectangle, then give it triggers: walk in / out / press E → toast, dialogue, cutscene, battle, flag, music, teleport. Add random encounters too.", 12, NeonTheme.TEXT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_palette.add_child(tip)
	var row := HBoxContainer.new()
	var name_e := LineEdit.new()
	name_e.placeholder_text = "new region name…"
	name_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_e)
	var add := Button.new()
	add.text = "＋ REGION"
	add.pressed.connect(func() -> void:
		_push_undo()
		sel_region = world.add_region(name_e.text if name_e.text != "" else "Region %d" % (world.regions.size() + 1))
		set_tool(Tool.BRUSH)
		_build_palette())
	row.add_child(add)
	_palette.add_child(row)
	for r: Dictionary in world.regions:
		var b := Button.new()
		b.text = "■ %s  (%d cells, %d triggers)" % [r.get("name", "?"), (r.get("cells", []) as Array).size(), (r.get("triggers", []) as Array).size()]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", Color(str(r.get("color", "#ffffff"))))
		_style_toggle(b, r == sel_region)
		var rr := r
		b.pressed.connect(func() -> void:
			sel_region = rr
			_build_palette())
		_palette.add_child(b)
	if not sel_region.is_empty() and world.regions.has(sel_region):
		_palette.add_child(_region_editor(sel_region))


func _region_editor(r: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_child(_section("REGION: " + str(r.get("name", "")).to_upper(), Color(str(r.get("color", "#ffffff")))))
	var nm := LineEdit.new()
	nm.text = str(r.get("name", ""))
	nm.text_changed.connect(func(t: String) -> void:
		r["name"] = t
		dirty = true)
	box.add_child(nm)
	var trigs: Array = r.get("triggers", [])
	r["triggers"] = trigs
	for i in trigs.size():
		var t: Dictionary = trigs[i]
		var tb := VBoxContainer.new()
		var line := HBoxContainer.new()
		line.add_child(ForgeForm._option(TRIGGER_ON, str(t.get("on", "enter")), func(v: String) -> void:
			t["on"] = v
			dirty = true))
		line.add_child(NeonTheme.label("→", 13))
		line.add_child(ForgeForm._option(TRIGGER_DO, str(t.get("do", "toast")), func(v: String) -> void:
			t["do"] = v
			dirty = true
			_build_palette()))
		var once := CheckBox.new()
		once.text = "once"
		once.button_pressed = bool(t.get("once", false))
		once.toggled.connect(func(on: bool) -> void:
			t["once"] = on
			dirty = true)
		line.add_child(once)
		var del := Button.new()
		del.text = "✕"
		var ii := i
		del.pressed.connect(func() -> void:
			trigs.remove_at(ii)
			dirty = true
			_build_palette())
		line.add_child(del)
		tb.add_child(line)
		var arg := LineEdit.new()
		arg.text = str(t.get("arg", ""))
		arg.placeholder_text = str(TRIGGER_HINT.get(str(t.get("do", "toast")), ""))
		arg.text_changed.connect(func(v: String) -> void:
			t["arg"] = v
			dirty = true)
		tb.add_child(arg)
		var req := LineEdit.new()
		req.text = str(t.get("requires_flag", ""))
		req.placeholder_text = "only if story flag is set (optional)"
		req.text_changed.connect(func(v: String) -> void:
			t["requires_flag"] = v
			dirty = true)
		tb.add_child(req)
		box.add_child(tb)
	var addt := Button.new()
	addt.text = "＋ TRIGGER"
	addt.pressed.connect(func() -> void:
		trigs.append({"on": "enter", "do": "toast", "arg": "", "once": true})
		dirty = true
		_build_palette())
	box.add_child(addt)
	var enc: Dictionary = r.get("encounter", {})
	box.add_child(_section("RANDOM ENCOUNTERS"))
	var er := HBoxContainer.new()
	er.add_child(NeonTheme.label("Chance / step %", 12, NeonTheme.TEXT_DIM))
	er.add_child(ForgeForm._spin(float(enc.get("rate", 0.0)) * 100.0, false, func(n: float) -> void:
		enc["rate"] = clampf(n / 100.0, 0.0, 1.0)
		r["encounter"] = enc
		dirty = true))
	box.add_child(er)
	var ms := LineEdit.new()
	ms.text = ", ".join(PackedStringArray(enc.get("missions", [])))
	ms.placeholder_text = "mission ids, comma separated"
	ms.text_changed.connect(func(v: String) -> void:
		enc["missions"] = Array(v.split(",", false)).map(func(x: String) -> String: return x.strip_edges())
		r["encounter"] = enc
		dirty = true)
	box.add_child(ms)
	var delr := Button.new()
	delr.text = "DELETE REGION"
	delr.pressed.connect(func() -> void:
		_push_undo()
		world.regions.erase(r)
		sel_region = {}
		_build_palette())
	box.add_child(delr)
	return box


func _palette_gameplay() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	for i in PLAY_NAMES.size():
		var b := Button.new()
		b.text = PLAY_NAMES[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_toggle(b, play_tool == i)
		var pi := i
		b.pressed.connect(func() -> void:
			play_tool = pi as Play
			set_tool(Tool.BRUSH)
			_build_palette())
		grid.add_child(b)
	_palette.add_child(grid)
	_palette.add_child(_section("ENCOUNTER"))
	_palette.add_child(NeonTheme.label("Mission (enemies are saved into it)", 12, NeonTheme.TEXT_DIM))
	var mids: Array = ContentDB.get_ids("missions")
	_palette.add_child(ForgeForm._option([""] + mids, mission_id, func(m: String) -> void: mission_id = m))
	_palette.add_child(NeonTheme.label("Enemy", 12, NeonTheme.TEXT_DIM))
	_palette.add_child(ForgeForm._ref_picker("characters", enemy_id, func(c: String) -> void:
		enemy_id = c
		play_tool = Play.ENEMY))
	_palette.add_child(NeonTheme.label("Level", 12, NeonTheme.TEXT_DIM))
	_palette.add_child(ForgeForm._spin(enemy_level, true, func(n: float) -> void: enemy_level = int(n)))
	_palette.add_child(_section("TACTICS VIEW (◇ in the top bar)"))
	var mj := HBoxContainer.new()
	mj.add_child(NeonTheme.label("Move", 12, NeonTheme.TEXT_DIM))
	mj.add_child(ForgeForm._spin(tactics_move, true, func(n: float) -> void: tactics_move = clampi(int(n), 1, 12)))
	mj.add_child(NeonTheme.label("Jump", 12, NeonTheme.TEXT_DIM))
	mj.add_child(ForgeForm._spin(tactics_jump, true, func(n: float) -> void: tactics_jump = clampi(int(n), 0, 8)))
	_palette.add_child(mj)
	var t := NeonTheme.label("Spawns and enemies stand on top of each column. BLOCK / COVER / SIGHT override the tile's terrain rules.", 12, NeonTheme.TEXT_DIM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_palette.add_child(t)


# --- Map lifecycle ---------------------------------------------------------

func load_map(id: String) -> void:
	var src: Dictionary = ContentDB.get_map(id)
	if src.is_empty():
		return
	world = WorldMap.from_dict(src)
	if int(src.get("format", 1)) < 2:
		status.emit("Opened a classic map — it is converted to stacks and saved as format 2.", NeonTheme.AMBER)
	_after_load()
	for m: MissionResource in ContentDB.get_all("missions"):
		if m.map_id == id:
			mission_id = m.id
			break


func new_map(id: String, kind: String, w: int, d: int) -> void:
	world = WorldMap.new()
	world.id = ForgeStore.slugify(id)
	world.name = id.capitalize()
	world.kind = kind
	world.width = w
	world.depth = d
	if kind == "world":
		world.tile_width = 128
	dirty = true
	_after_load()


func _after_load() -> void:
	_undo.clear()
	_redo.clear()
	selected = {}
	_renderer.set_world(world)
	_refresh_post()
	if _minimap:
		_minimap.mark_dirty()
	frame_map()
	# The viewport has no size until layout runs; frame again once it does.
	get_tree().process_frame.connect(frame_map, CONNECT_ONE_SHOT)
	_refresh_map_pick()
	_show_inspector()
	_refresh_objects_list()


func frame_map() -> void:
	var span := (world.width + world.depth) * world.tile_width * 0.5
	var vw := maxf(_vpc.size.x, 800.0)
	_snap_cam(world.to_screen(Vector2(world.width, world.depth) * 0.5, 0), clampf(vw / maxf(span, 1.0) * 0.9, 0.08, 2.0))


var _post: HD2DPost


## Live HD-2D preview inside the editor viewport (focus follows the cursor).
func _refresh_post() -> void:
	if _post:
		_post.queue_free()
		_post = null
	_post = HD2DPost.for_map(world.post)
	if _post:
		_post.layer = 3
		_vp.add_child(_post)


## Back from a play-test: same map, camera, layer, tool and palette picks.
func _restore_session() -> void:
	if _session.is_empty():
		return
	if ContentDB.maps.has(str(_session["map"])) and str(_session["map"]) != world.id:
		load_map(str(_session["map"]))
	if str(_session["map"]) != world.id:
		return
	sel_tiles.assign(_session.get("sel", []))
	recent_tiles.assign(_session.get("recent", []))
	set_layer(int(_session.get("layer", 0)))
	set_mode(int(_session.get("mode", Mode.TILES)))
	set_tool(int(_session.get("tool", Tool.BRUSH)))
	var cam: Vector2 = _session.get("cam", Vector2.ZERO)
	var zoom := float(_session.get("zoom", 1.0))
	get_tree().process_frame.connect(func() -> void: _snap_cam(cam, zoom), CONNECT_ONE_SHOT)
	status.emit("Welcome back — right where you left off.", NeonTheme.GREEN)


func _snap_cam(pos: Vector2, zoom: float) -> void:
	_cam_goal = pos
	_zoom_goal = zoom
	_cam.position = pos
	_cam.zoom = Vector2(zoom, zoom)


## Smooth glide to a point (minimap clicks, objects list).
func focus(pos: Vector2) -> void:
	_cam_goal = pos


func _zoom(f: float) -> void:
	_zoom_goal = clampf(_zoom_goal * f, 0.05, 6.0)


func _process(delta: float) -> void:
	if _cam == null:
		return
	if _post and _vpc.size.y > 0:
		var sy := (_vp.get_canvas_transform() * world.to_screen(Vector2(_hover_cell), _hover_z)).y / _vpc.size.y
		_post.set_focus(sy if world.in_bounds(_hover_cell) else 0.5)
	if xray and world.in_bounds(_hover_cell):
		_renderer.set_cutaway(world.to_screen(Vector2(_hover_cell), _hover_z), _hover_cell.x + _hover_cell.y, _hover_z)
	var k := 1.0 - exp(-delta * 14.0)
	_cam.position = _cam.position.lerp(_cam_goal, k)
	var z := lerpf(_cam.zoom.x, _zoom_goal, k)
	_cam.zoom = Vector2(z, z)


func _autosave_path() -> String:
	return AUTOSAVE_DIR.path_join(world.id + ".json")


func _autosave() -> void:
	if not dirty or not is_visible_in_tree():
		return
	DirAccess.make_dir_recursive_absolute(AUTOSAVE_DIR)
	var f := FileAccess.open(_autosave_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(world.to_dict()))
		f.close()
		status.emit("Autosaved %s (unsaved work is safe)." % world.id, NeonTheme.TEXT_DIM)


func save_map() -> void:
	if FileAccess.file_exists(_autosave_path()):
		DirAccess.remove_absolute(_autosave_path())
	var path := ForgeStore.save_map(world.to_dict())
	var msg := "SAVED ▸ %s" % path
	var issues := MapValidator.validate(world, mission_enemies())
	var errors := issues.filter(func(i: Dictionary) -> bool: return i["level"] == MapValidator.ERROR).size()
	if _check_btn:
		_check_btn.text = "⚠ CHECK (%d)" % issues.size() if not issues.is_empty() else "✔ CHECK"
	if errors > 0:
		msg += "   ·   ⚠ %d problem(s) — press CHECK" % errors
	if dirty_missions:
		msg += "  +  " + ForgeStore.save_bucket("missions")
		dirty_missions = false
	dirty = false
	status.emit(msg, NeonTheme.GREEN)
	_refresh_map_pick()


func play_here() -> void:
	save_map()
	_session = {"map": world.id, "cam": _cam.position, "zoom": _cam.zoom.x, "mode": mode, "tool": tool,
		"layer": layer, "sel": sel_tiles.duplicate(), "recent": recent_tiles.duplicate()}
	if world.kind == "encounter":
		var mission := ContentDB.get_mission(mission_id)
		if mission == null or mission.map_id != world.id:
			var test := MissionResource.new()
			var sp: Array = world.spawns.get("player", [])
			var foe_cell := [world.width - 2, 1]
			test.apply_dict({"id": "__playtest", "display_name": "Playtest: " + world.name, "map_id": world.id,
				"briefing": "Neon Forge playtest.", "enemies": [{"character_id": "doctrine_warden", "cell": foe_cell, "level": 2}]})
			ForgeStore.put_entry("missions", test)
			mission = test
			if sp.is_empty():
				status.emit("Tip: add PLAYER SPAWN points in the GAMEPLAY layer.", NeonTheme.AMBER)
		GameManager.new_game()
		CampaignManager.start_mission(mission.id)
	else:
		var at := _hover_cell if world.in_bounds(_hover_cell) and world.tiles.has(_hover_cell) else Vector2i(-1, -1)
		CampaignManager.explore(world.id, -1, at, true)


func _new_map_dialog() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "NEW MAP"
	var v := VBoxContainer.new()
	v.theme = NeonTheme.get_theme()
	var name_e := LineEdit.new()
	name_e.placeholder_text = "map id, e.g. neo_kowloon_hub"
	v.add_child(name_e)
	var st := {"kind": kind_filter if kind_filter != "all" else "encounter"}
	var kind_pick := ForgeForm._option(WorldMap.KINDS, st["kind"], func(k: String) -> void: st["kind"] = k)
	v.add_child(kind_pick)
	var h := HBoxContainer.new()
	var ww := ForgeForm._spin(24, true, func(_n: float) -> void: pass)
	var dd := ForgeForm._spin(24, true, func(_n: float) -> void: pass)
	h.add_child(NeonTheme.label("W", 12))
	h.add_child(ww)
	h.add_child(NeonTheme.label("D", 12))
	h.add_child(dd)
	v.add_child(h)
	dlg.add_child(v)
	dlg.confirmed.connect(func() -> void:
		var id := name_e.text if name_e.text != "" else "new_" + str(st["kind"])
		if ContentDB.maps.has(ForgeStore.slugify(id)):
			id += "_2"
		new_map(id, str(st["kind"]), clampi(int(ww.value), 3, 160), clampi(int(dd.value), 3, 160))
		dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered(Vector2i(440, 200))


# --- Undo --------------------------------------------------------------------

func _push_undo() -> void:
	_undo.append(world.to_dict())
	if _undo.size() > 40:
		_undo.pop_front()
	_redo.clear()
	dirty = true


func _restore(d: Dictionary) -> void:
	var cam := _cam.position
	var zoom := _cam.zoom
	world.load_dict(d)
	_edit_count += 1
	selected = {}
	sel_region = {}
	_renderer.rebuild()
	_minimap.mark_dirty()
	_snap_cam(cam, zoom.x)
	_show_inspector()
	_refresh_objects_list()


func undo_last() -> void:
	if _undo.is_empty():
		return
	_redo.append(world.to_dict())
	_restore(_undo.pop_back())
	status.emit("Undone.", NeonTheme.AMBER)


func redo_last() -> void:
	if _redo.is_empty():
		return
	_undo.append(world.to_dict())
	_restore(_redo.pop_back())
	status.emit("Redone.", NeonTheme.AMBER)


# --- Input -------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var k := event as InputEventKey
	if k == null:
		return
	if k.keycode == KEY_SPACE:
		_space = k.pressed
		return
	if not k.pressed or k.echo:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or focus is SpinBox:
		return
	var handled := true
	if k.ctrl_pressed and k.keycode == KEY_Z:
		if k.shift_pressed: redo_last()
		else: undo_last()
	elif k.ctrl_pressed and k.keycode == KEY_Y:
		redo_last()
	elif k.ctrl_pressed and k.keycode == KEY_S:
		save_map()
	elif k.ctrl_pressed and k.keycode == KEY_D:
		duplicate_selected()
	elif k.keycode == KEY_F5:
		play_here()
	elif k.shift_pressed and k.keycode == KEY_R and tool == Tool.STAMP:
		transform_clipboard(true)
	elif k.shift_pressed and k.keycode == KEY_R and tool == Tool.RAMP:
		ramp_dir = RAMP_DIRS[(RAMP_DIRS.find(ramp_dir) + 1) % 4]
		status.emit("Ramp faces %s (used when no neighbour is one step higher)." % ramp_dir, NeonTheme.CYAN)
	elif k.keycode >= KEY_1 and k.keycode <= KEY_9 and not k.alt_pressed and not k.ctrl_pressed:
		pick_recent(k.keycode - KEY_1)
	elif k.shift_pressed and k.keycode == KEY_F and tool == Tool.STAMP:
		transform_clipboard(false)
	elif k.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		delete_selected()
	elif k.keycode == KEY_BRACKETLEFT:
		_size_slider.value = brush_size - 1
	elif k.keycode == KEY_BRACKETRIGHT:
		_size_slider.value = brush_size + 1
	elif k.keycode == KEY_PAGEUP:
		set_layer(layer + 1)
	elif k.keycode == KEY_PAGEDOWN:
		set_layer(layer - 1)
	elif TOOL_KEYS.has(k.keycode) and not k.ctrl_pressed:
		set_tool(TOOL_KEYS[k.keycode])
	elif k.keycode >= KEY_1 and k.keycode <= KEY_6 and k.alt_pressed:
		set_mode(k.keycode - KEY_1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _view_to_world(local: Vector2) -> Vector2:
	return _vp.get_canvas_transform().affine_inverse() * local


func _update_hover(local: Vector2) -> void:
	_hover_world = _view_to_world(local)
	if Input.is_key_pressed(KEY_CTRL):
		var hit := world.pick_top(_hover_world)
		if not hit.is_empty():
			_hover_cell = hit[0]
			_hover_z = int(hit[1]) + (1 if mode == Mode.TILES else 0)
			return
	if mode in [Mode.OBJECTS, Mode.DETAILS, Mode.GAMEPLAY]:
		var hit2 := world.pick_top(_hover_world)
		if not hit2.is_empty():
			_hover_cell = hit2[0]
			_hover_z = int(hit2[1])
			return
	_hover_cell = world.pick_plane(_hover_world, layer)
	_hover_z = layer


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			if mb.shift_pressed: set_layer(layer + 1)
			else: _zoom_at(mb.position, 1.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			if mb.shift_pressed: set_layer(layer - 1)
			else: _zoom_at(mb.position, 1.0 / 1.1)
		elif mb.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_update_hover(mb.position)
			if tool == Tool.PAN or _space:
				_panning = mb.pressed
				return
			if mb.pressed:
				if mb.double_click and mode == Mode.OBJECTS:
					var o := _renderer.pick_sprite(_hover_world)
					if not o.is_empty():
						_select(o)
						_location_dialog(o)
					return
				_down = true
				_drag_start = _hover_cell
				_last_applied.clear()
				_press()
			else:
				if _down:
					_release()
				_down = false
				_moving = {}
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			_cam_goal -= mm.relative / _cam.zoom.x
			_cam.position -= mm.relative / _cam.zoom.x
			return
		var prev := _hover_cell
		_update_hover(mm.position)
		if _down:
			_drag()
		elif prev != _hover_cell:
			pass


func _zoom_at(local: Vector2, f: float) -> void:
	# Keep the point under the cursor fixed while the zoom glides.
	var half := _vpc.size * 0.5
	var before := _cam_goal + (local - half) / _zoom_goal
	_zoom(f)
	_cam_goal = before - (local - half) / _zoom_goal


# --- Targets -------------------------------------------------------------------

## Cells the current tool would affect (brush footprint, or the rectangle).
func target_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if tool in [Tool.RECT, Tool.COPY] and _down:
		return _rect_cells()
	var single := mode == Mode.GAMEPLAY and play_tool in [Play.SPAWN, Play.ENEMY]
	if single or tool in [Tool.PICK, Tool.SELECT, Tool.PAN, Tool.FILL, Tool.STAMP] or mode in [Mode.OBJECTS, Mode.DETAILS] and tool != Tool.ERASE:
		if world.in_bounds(_hover_cell):
			out.append(_hover_cell)
		return out
	var r := brush_size - 1
	var lo := -(r / 2)
	for dx in range(lo, lo + brush_size):
		for dy in range(lo, lo + brush_size):
			var c := _hover_cell + Vector2i(dx, dy)
			if world.in_bounds(c):
				out.append(c)
	return out


func _rect_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not world.in_bounds(_drag_start) and not world.in_bounds(_hover_cell):
		return out
	var a := Vector2i(clampi(_drag_start.x, 0, world.width - 1), clampi(_drag_start.y, 0, world.depth - 1))
	var b := Vector2i(clampi(_hover_cell.x, 0, world.width - 1), clampi(_hover_cell.y, 0, world.depth - 1))
	for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			out.append(Vector2i(x, y))
	return out


## The layer the tile brush paints on (the rectangle always uses the stack layer).
func target_layer() -> int:
	return _hover_z if tool != Tool.RECT or not _down else layer


## Layers to fill in one column: just `z`, or with "solid column" on, everything
## from just above the next tile below (or the ground) up to `z`.
func layers_for(cell: Vector2i, z: int) -> Array[int]:
	var out: Array[int] = [z]
	if not solid_column or tool == Tool.ERASE:
		return out
	var floor_z := 0 if z > 0 else z
	for e: Array in world.stack_at(cell):
		if int(e[0]) < z:
			floor_z = int(e[0]) + 1  # stack is sorted: the last hit is the nearest below
	out.clear()
	for i in range(floor_z, z + 1):
		out.append(i)
	return out


func _placement_point() -> Vector2:
	if mode == Mode.DETAILS:
		var f := world.from_screen(_hover_world, _hover_z)
		if Input.is_key_pressed(KEY_SHIFT):
			f = f.round()
		return world.to_screen(f, _hover_z)
	return world.to_screen(Vector2(_hover_cell), _hover_z)


# --- Applying ------------------------------------------------------------------

func _press() -> void:
	match tool:
		Tool.PICK:
			_eyedrop()
		Tool.SELECT:
			var o := _renderer.pick_sprite(_hover_world, true)
			_select(o)
			if not o.is_empty():
				_push_undo()
				_moving = o
				_move_grab = _hover_world
		Tool.FILL:
			_push_undo()
			_flood_fill()
		Tool.RECT, Tool.COPY:
			pass
		Tool.STAMP:
			_push_undo()
			_stamp(_hover_cell)
		Tool.SCULPT:
			_push_undo()
			sculpt(target_cells())
		Tool.RAMP:
			_push_undo()
			place_ramps(target_cells())
		_:
			_push_undo()
			_apply(target_cells())


func _drag() -> void:
	if tool == Tool.SELECT and not _moving.is_empty():
		_move_selected()
	elif tool == Tool.SCULPT:
		sculpt(target_cells())
	elif tool == Tool.RAMP:
		place_ramps(target_cells())
	elif tool in [Tool.BRUSH, Tool.ERASE] and mode in [Mode.TILES, Mode.PARTICLES, Mode.GAMEPLAY, Mode.REGIONS] and not (mode == Mode.GAMEPLAY and play_tool in [Play.SPAWN, Play.ENEMY]):
		_apply(target_cells())


func _release() -> void:
	if tool == Tool.RECT:
		_push_undo()
		_apply(_rect_cells())
	elif tool == Tool.COPY:
		_copy_area(_rect_cells())


## Copies every tile + particle layer of the rectangle, relative to its corner.
func _copy_area(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var origin := cells[0]
	for c in cells:
		origin = Vector2i(mini(origin.x, c.x), mini(origin.y, c.y))
	var tiles: Array = []
	var parts: Array = []
	var base := 1 << 20
	for c in cells:
		for e: Array in world.stack_at(c):
			tiles.append([c.x - origin.x, c.y - origin.y, int(e[0]), str(e[1])])
			base = mini(base, int(e[0]))
		for e2: Array in world.particles.get(c, []):
			parts.append([c.x - origin.x, c.y - origin.y, int(e2[0]), str(e2[1])])
	# Objects whose anchor cell is inside the area come along (lights, props...).
	var objs: Array = []
	for o: Dictionary in world.objects:
		var oc := Vector2i(int(o["cell"][0]), int(o["cell"][1]))
		if cells.has(oc):
			var copy: Dictionary = o.duplicate(true)
			copy["cell"] = [oc.x - origin.x, oc.y - origin.y]
			objs.append(copy)
	if tiles.is_empty() and parts.is_empty() and objs.is_empty():
		status.emit("Nothing to copy there.", NeonTheme.AMBER)
		return
	clipboard = {"tiles": tiles, "particles": parts, "objects": objs, "base_z": base if base != 1 << 20 else 0}
	set_tool(Tool.STAMP)
	status.emit("Copied %d tiles, %d objects — click to stamp (T). Shift+R rotates, Shift+F flips; SAVE STAMP in the TILES palette keeps it." % [tiles.size(), objs.size()], NeonTheme.CYAN)


## Rotates the clipboard 90° (iso quarter turn) or mirrors it; re-anchors at 0,0.
func transform_clipboard(rotate: bool) -> void:
	if clipboard.is_empty():
		return
	var xf := func(x: int, y: int) -> Vector2i: return Vector2i(y, -x) if rotate else Vector2i(-x, y)
	var lo := Vector2i(1 << 20, 1 << 20)
	for key: String in ["tiles", "particles"]:
		for e: Array in clipboard.get(key, []):
			var v: Vector2i = xf.call(int(e[0]), int(e[1]))
			e[0] = v.x
			e[1] = v.y
			lo = Vector2i(mini(lo.x, v.x), mini(lo.y, v.y))
	for o: Dictionary in clipboard.get("objects", []):
		var v2: Vector2i = xf.call(int(o["cell"][0]), int(o["cell"][1]))
		o["cell"] = [v2.x, v2.y]
		lo = Vector2i(mini(lo.x, v2.x), mini(lo.y, v2.y))
		if not rotate:
			o["flip"] = not bool(o.get("flip", false))
	for key2: String in ["tiles", "particles"]:
		for e2: Array in clipboard.get(key2, []):
			e2[0] = int(e2[0]) - lo.x
			e2[1] = int(e2[1]) - lo.y
	for o2: Dictionary in clipboard.get("objects", []):
		o2["cell"] = [int(o2["cell"][0]) - lo.x, int(o2["cell"][1]) - lo.y]
	status.emit("Stamp %s." % ("rotated" if rotate else "flipped"), NeonTheme.CYAN)


const STAMP_DIR := "res://data/stamps"


func save_stamp(stamp_name: String) -> String:
	if clipboard.is_empty():
		return ""
	var id := ForgeStore.slugify(stamp_name)
	if id == "":
		id = "stamp"
	var dir := STAMP_DIR if ForgeStore.writable_res() else "user://content/stamps"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(id + ".json")
	var data: Dictionary = clipboard.duplicate(true)
	data["name"] = stamp_name
	ForgeStore._write_json(path, data)
	status.emit("Stamp saved ▸ %s" % path, NeonTheme.GREEN)
	return path


static func list_stamps() -> Array[String]:
	var out: Array[String] = []
	for dir: String in [STAMP_DIR, "user://content/stamps"]:
		if DirAccess.dir_exists_absolute(dir):
			for f in DirAccess.get_files_at(dir):
				if f.ends_with(".json"):
					out.append(dir.path_join(f))
	out.sort()
	return out


func load_stamp(path: String) -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary:
		clipboard = d
		if not clipboard.has("objects"):
			clipboard["objects"] = []
		set_tool(Tool.STAMP)
		status.emit("Stamp '%s' ready — click to place (Shift+R rotate, Shift+F flip)." % d.get("name", path.get_file()), NeonTheme.CYAN)


func _stamp(at: Vector2i) -> void:
	if clipboard.is_empty():
		status.emit("Copy an area first (C, then drag).", NeonTheme.MAGENTA)
		return
	var shift := layer - int(clipboard["base_z"])
	var changed: Array = []
	for t: Array in clipboard["tiles"]:
		var c := at + Vector2i(int(t[0]), int(t[1]))
		if world.in_bounds(c):
			world.set_tile(c, int(t[2]) + shift, str(t[3]))
			_renderer.pop(c, int(t[2]) + shift, false, changed.size() < 60)
			changed.append(c)
	for pt: Array in clipboard["particles"]:
		world.set_particle(at + Vector2i(int(pt[0]), int(pt[1])), int(pt[2]) + shift, str(pt[3]))
	for src: Dictionary in clipboard.get("objects", []):
		var o: Dictionary = src.duplicate(true)
		var oc := at + Vector2i(int(o["cell"][0]), int(o["cell"][1]))
		if not world.in_bounds(oc):
			continue
		o["cell"] = [oc.x, oc.y]
		o["z"] = int(o.get("z", 0)) + shift
		o["id"] = world.next_id("obj")
		world.objects.append(o)
		_renderer.refresh_object(o)
	if not (clipboard.get("objects", []) as Array).is_empty():
		_renderer.rebuild_lighting()
		_refresh_objects_list()
	_renderer.refresh_columns(changed)
	if not (clipboard["particles"] as Array).is_empty():
		_renderer.rebuild_particles()
	_minimap.mark_dirty()
	dirty = true


## Adds the mirror images of `cells` across the map centre (X and/or Y).
func with_mirrors(cells: Array[Vector2i]) -> Array[Vector2i]:
	if not mirror_x and not mirror_y:
		return cells
	var out: Array[Vector2i] = []
	var seen := {}
	for c in cells:
		var group: Array[Vector2i] = [c]
		if mirror_x:
			group.append(Vector2i(world.width - 1 - c.x, c.y))
		if mirror_y:
			group.append(Vector2i(c.x, world.depth - 1 - c.y))
		if mirror_x and mirror_y:
			group.append(Vector2i(world.width - 1 - c.x, world.depth - 1 - c.y))
		for g in group:
			if not seen.has(g):
				seen[g] = true
				out.append(g)
	return out


## Random flip + subtle hue/brightness jitter (only when Variation is on).
func _variation() -> Dictionary:
	if not vary_tiles:
		return {}
	var o := {}
	if _rng.randf() < 0.5:
		o["flip"] = true
	var c := Color.from_hsv(_rng.randf(), _rng.randf_range(0.0, 0.07), _rng.randf_range(0.9, 1.0))
	o["tint"] = "#" + c.to_html(false)
	return o


## Uphill direction for a ramp at (cell, z): toward a neighbour whose top is
## exactly one step higher; otherwise the manual ramp_dir (Shift+R).
func ramp_for(cell: Vector2i, z: int) -> String:
	for i in 4:
		var d: String = RAMP_DIRS[i]
		var off := Vector2i(1 if d == "x+" else (-1 if d == "x-" else 0), 1 if d == "y+" else (-1 if d == "y-" else 0))
		var n := cell + off
		if world.tiles.has(n) and world.top_z(n) == z + 1:
			return d
	return ramp_dir


func place_ramps(cells: Array[Vector2i]) -> void:
	if sel_tiles.is_empty():
		status.emit("Pick the ground tile to turn into a ramp first.", NeonTheme.MAGENTA)
		return
	var changed: Array = []
	for c in with_mirrors(cells):
		var k := "r%d,%d" % [c.x, c.y]
		if _last_applied.has(k) or not world.in_bounds(c):
			continue
		_last_applied[k] = true
		var z := _hover_z
		world.set_tile(c, z, sel_tiles[0], {"ramp": ramp_for(c, z), "stairs": ramp_stairs})
		_renderer.pop(c, z)
		changed.append(c)
	_renderer.refresh_columns(changed)
	_minimap.mark_dirty()
	_edit_count += 1
	dirty = true


## Height sculpting on column tops: raise, lower, flatten (to the stack
## layer) or smooth (toward the neighbours' average). Once per cell per stroke.
func sculpt(cells: Array[Vector2i]) -> void:
	var changed: Array = []
	var snapshot := {}
	if sculpt_mode == "smooth":
		for c in cells:
			snapshot[c] = world.top_z(c, 0)
	for c in with_mirrors(cells):
		var k := "s%d,%d" % [c.x, c.y]
		if _last_applied.has(k) or not world.in_bounds(c):
			continue
		_last_applied[k] = true
		var has := world.tiles.has(c)
		var top := world.top_z(c, layer)
		var tid := world.top_tile(c) if has else (sel_tiles[0] if not sel_tiles.is_empty() else "")
		if tid == "":
			continue
		var goal := top
		match sculpt_mode:
			"raise": goal = top + 1 if has else layer
			"lower": goal = top - 1
			"flatten": goal = layer
			"smooth":
				var sum := float(top)
				var n := 1.0
				for d in IsometricGrid.DIRECTIONS:
					if world.tiles.has(c + d):
						sum += float(snapshot.get(c + d, world.top_z(c + d)))
						n += 1.0
				goal = roundi(sum / n)
		if has and goal == top:
			continue
		if sculpt_mode == "lower" and has:
			world.remove_tile(c, top)
			_renderer.pop(c, top, true, changed.size() < 40)
		elif not has:
			world.set_tile(c, goal, tid)
		elif goal > top:
			for z in range(top + 1, goal + 1):
				world.set_tile(c, z, tid)
			_renderer.pop(c, goal, false, changed.size() < 40)
		else:
			for e: Array in world.stack_at(c).duplicate():
				if int(e[0]) > goal:
					world.remove_tile(c, int(e[0]))
			if world.tile_at(c, goal) == "":
				world.set_tile(c, goal, tid)
		changed.append(c)
	_renderer.refresh_columns(changed)
	_minimap.mark_dirty()
	_edit_count += 1
	dirty = true


func _next_tile() -> String:
	if sel_tiles.is_empty():
		return ""
	if paint_random:
		return sel_tiles[_rng.randi() % sel_tiles.size()]
	var t := sel_tiles[_cycle % sel_tiles.size()]
	_cycle += 1
	return t


## Scatter density: brush / rectangle strokes skip some cells.
func _skip_for_density() -> bool:
	return density < 100 and tool in [Tool.BRUSH, Tool.RECT] and _rng.randi() % 100 >= density


func _apply(cells: Array[Vector2i]) -> void:
	_edit_count += 1
	var erase := tool == Tool.ERASE
	var changed: Array = []
	match mode:
		Mode.TILES:
			if not erase and sel_tiles.is_empty():
				status.emit("Pick a tile in the palette first.", NeonTheme.MAGENTA)
				return
			var tz := target_layer()
			var rings := 0
			cells = with_mirrors(cells)
			for c: Vector2i in cells:
				var ck := "%d,%d" % [c.x, c.y]
				if _last_applied.has(ck):
					continue
				_last_applied[ck] = true
				if not erase and _skip_for_density():
					continue
				for z: int in layers_for(c, tz):
					if erase:
						if world.remove_tile(c, z):
							_renderer.pop(c, z, true, rings < 40)
							rings += 1
					else:
						var tid := _next_tile()
						world.set_tile(c, z, tid, _variation())
						_renderer.pop(c, z, false, rings < 40)
						rings += 1
				changed.append(c)
			_renderer.refresh_columns(changed)
			_minimap.mark_dirty()
		Mode.PARTICLES:
			for c: Vector2i in with_mirrors(cells):
				if not erase and _skip_for_density():
					continue
				if erase:
					world.remove_particle(c, layer)
				else:
					world.set_particle(c, layer, sel_particle)
			_renderer.rebuild_particles()
		Mode.DETAILS:
			if erase:
				var d := _renderer.pick_sprite(_hover_world, true)
				if not d.is_empty() and world.details.has(d):
					world.details.erase(d)
					_renderer.remove_detail(d)
			elif sel_detail != "":
				var f := world.from_screen(_hover_world, _hover_z)
				if Input.is_key_pressed(KEY_SHIFT):
					f = f.round()
				var nd := world.add_detail(sel_detail, f, _hover_z)
				_apply_default_anim(nd, sel_detail)
				_renderer.refresh_detail(nd)
				_select(nd)
			else:
				status.emit("Pick a detail in the palette first.", NeonTheme.MAGENTA)
		Mode.OBJECTS:
			if erase:
				for c: Vector2i in cells:
					for o: Dictionary in world.objects_at(c):
						world.objects.erase(o)
						_renderer.remove_object(o)
				_refresh_objects_list()
			elif sel_object.begins_with("light:") and world.in_bounds(_hover_cell):
				var preset := sel_object.substr(6)
				var lo := world.add_object("", _hover_cell, world.top_z(_hover_cell, layer), "light")
				lo["light"] = (WorldRenderer.LIGHT_PRESETS.get(preset, WorldRenderer.LIGHT_PRESETS["neon_pink"]) as Dictionary).duplicate()
				lo["light"]["preset"] = preset
				lo["light"]["height"] = 1.0
				_renderer.refresh_object(lo)
				_renderer.rebuild_lighting()
				_renderer.pop(_hover_cell, world.top_z(_hover_cell, layer))
				_select(lo)
				_refresh_objects_list()
			elif sel_object != "" and world.in_bounds(_hover_cell):
				var kind := "structure" if sel_object.contains("/structures/") else ("character" if sel_object.contains("/units/") else ("loot" if sel_object.contains("/items/") else "prop"))
				var no := world.add_object(sel_object, _hover_cell, world.top_z(_hover_cell, layer), kind)
				no["scale"] = WorldRenderer.default_scale(world, sel_object, kind)
				_apply_default_anim(no, sel_object)
				_renderer.refresh_object(no)
				_select(no)
				_refresh_objects_list()
			else:
				status.emit("Pick an asset in the palette first.", NeonTheme.MAGENTA)
		Mode.REGIONS:
			if sel_region.is_empty():
				status.emit("Create or pick a region first (left panel).", NeonTheme.MAGENTA)
				return
			var rc: Array = sel_region["cells"]
			for c: Vector2i in with_mirrors(cells):
				var rk := WorldMap.key(c)
				if erase:
					rc.erase(rk)
				elif not rc.has(rk) and world.in_bounds(c):
					rc.append(rk)
		Mode.GAMEPLAY:
			for c: Vector2i in cells:
				var k2 := "%d,%d" % [c.x, c.y]
				if _last_applied.has(k2):
					continue
				_last_applied[k2] = true
				_apply_gameplay(c, erase)
	dirty = true


func _apply_default_anim(entry: Dictionary, asset: String) -> void:
	var idx_entry: Dictionary = AssetIndex.find_by_path(asset)
	if idx_entry.get("anim") is Dictionary:
		entry["anim"] = idx_entry["anim"].duplicate(true)


func _apply_gameplay(c: Vector2i, erase: bool) -> void:
	var g: Dictionary = world.gameplay.get(c, {})
	match play_tool:
		Play.SPAWN:
			var sp: Array = world.spawns["player"]
			var idx := _index_of_cell(sp, c)
			if idx >= 0:
				sp.remove_at(idx)
			elif not erase:
				sp.append([c.x, c.y])
		Play.ENEMY:
			var m := ContentDB.get_mission(mission_id)
			if m == null:
				status.emit("Pick a mission under ENCOUNTER first (or create one in MISSIONS).", NeonTheme.MAGENTA)
				return
			m.map_id = world.id
			var ei := _index_of_cell(m.enemies, c)
			if ei >= 0:
				m.enemies.remove_at(ei)
			if not erase:
				m.enemies.append({"character_id": enemy_id, "cell": [c.x, c.y], "level": enemy_level})
			dirty_missions = true
		Play.BLOCK:
			if erase: g.erase("walkable")
			else: g["walkable"] = false
		Play.COVER:
			if erase: g.erase("cover")
			else: g["cover"] = (int(g.get("cover", 0)) + 1) % 3
		Play.SIGHT:
			if erase: g.erase("blocks_los")
			else: g["blocks_los"] = not bool(g.get("blocks_los", false))
	if g.is_empty():
		world.gameplay.erase(c)
	else:
		world.gameplay[c] = g


func _index_of_cell(list: Array, cell: Vector2i) -> int:
	for i in list.size():
		var e: Variant = list[i]
		var cc: Array = e["cell"] if e is Dictionary else e
		if int(cc[0]) == cell.x and int(cc[1]) == cell.y:
			return i
	return -1


func mission_enemies() -> Array:
	var m := ContentDB.get_mission(mission_id)
	if m == null or m.map_id != world.id:
		return []
	return m.enemies


func _eyedrop() -> void:
	var hit := world.pick_top(_hover_world)
	if hit.is_empty():
		return
	var c: Vector2i = hit[0]
	match mode:
		Mode.TILES:
			sel_tiles = [world.top_tile(c)]
			set_layer(int(hit[1]))
			set_tool(Tool.BRUSH)
			_build_palette()
			status.emit("Picked %s at layer %d" % [sel_tiles[0], layer], NeonTheme.CYAN)
		Mode.PARTICLES:
			for e: Array in world.particles.get(c, []):
				sel_particle = str(e[1])
				set_layer(int(e[0]))
			set_tool(Tool.BRUSH)
			_build_palette()


func _flood_fill() -> void:
	if mode not in [Mode.TILES, Mode.PARTICLES]:
		return
	var start := _hover_cell
	if not world.in_bounds(start):
		return
	var match_id := world.tile_at(start, layer) if mode == Mode.TILES else _particle_at(start, layer)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var cells: Array[Vector2i] = []
	while not queue.is_empty() and cells.size() < 25000:
		var c: Vector2i = queue.pop_back()
		cells.append(c)
		for d in IsometricGrid.DIRECTIONS:
			var n: Vector2i = c + d
			if world.in_bounds(n) and not seen.has(n):
				seen[n] = true
				var here := world.tile_at(n, layer) if mode == Mode.TILES else _particle_at(n, layer)
				if here == match_id:
					queue.append(n)
	var keep_solid := solid_column
	solid_column = false
	var keep_z := _hover_z
	_hover_z = layer
	_apply(cells)
	solid_column = keep_solid
	_hover_z = keep_z
	status.emit("Filled %d cells." % cells.size(), NeonTheme.GREEN)


func _particle_at(c: Vector2i, z: int) -> String:
	for e: Array in world.particles.get(c, []):
		if int(e[0]) == z:
			return str(e[1])
	return ""


# --- Selection -------------------------------------------------------------------

func _select(o: Dictionary) -> void:
	for n in _renderer.get_children():
		for s in n.get_children():
			if s is WorldRenderer.WorldSprite:
				var ws := s as WorldRenderer.WorldSprite
				if ws.selected:
					ws.selected = false
					ws.queue_redraw()
	selected = o
	if not o.is_empty():
		for n in _renderer.get_children():
			for s in n.get_children():
				if s is WorldRenderer.WorldSprite and (s as WorldRenderer.WorldSprite).data == o:
					(s as WorldRenderer.WorldSprite).selected = true
					s.queue_redraw()
	_show_inspector()


func _is_detail(o: Dictionary) -> bool:
	return o.has("pos")


func _move_selected() -> void:
	if _is_detail(_moving):
		var f := world.from_screen(_hover_world, float(_moving.get("z", 0)))
		if Input.is_key_pressed(KEY_SHIFT):
			f = f.round()
		_moving["pos"] = [snappedf(f.x, 0.01), snappedf(f.y, 0.01)]
		_renderer.refresh_detail(_moving)
	else:
		var hit := world.pick_top(_hover_world)
		if hit.is_empty():
			return
		var c: Vector2i = hit[0]
		_moving["cell"] = [c.x, c.y]
		_moving["z"] = int(hit[1])
		_renderer.refresh_object(_moving)
		if _moving.get("light") is Dictionary:
			_renderer.rebuild_lighting()
	dirty = true


func delete_selected() -> void:
	if selected.is_empty():
		return
	_push_undo()
	if _is_detail(selected):
		world.details.erase(selected)
		_renderer.remove_detail(selected)
	else:
		world.objects.erase(selected)
		_renderer.remove_object(selected)
		if selected.get("light") is Dictionary:
			_renderer.rebuild_lighting()
	selected = {}
	_show_inspector()
	_refresh_objects_list()


func duplicate_selected() -> void:
	if selected.is_empty():
		return
	_push_undo()
	var copy: Dictionary = selected.duplicate(true)
	if _is_detail(copy):
		copy["id"] = world.next_id("dtl")
		copy["pos"] = [float(copy["pos"][0]) + 1.0, float(copy["pos"][1])]
		world.details.append(copy)
		_renderer.refresh_detail(copy)
	else:
		copy["id"] = world.next_id("obj")
		copy["cell"] = [mini(int(copy["cell"][0]) + 1, world.width - 1), int(copy["cell"][1])]
		world.objects.append(copy)
		_renderer.refresh_object(copy)
		if copy.get("light") is Dictionary:
			_renderer.rebuild_lighting()
	_select(copy)
	_refresh_objects_list()


# --- Inspector --------------------------------------------------------------------

## Lists every problem MapValidator finds; click one to fly to it.
func show_issues() -> void:
	var issues := MapValidator.validate(world, mission_enemies())
	_check_btn.text = "⚠ CHECK (%d)" % issues.size() if not issues.is_empty() else "✔ CHECK"
	_clear(_inspector)
	_inspector.add_child(NeonTheme.label("MAP CHECK", 20, NeonTheme.AMBER if not issues.is_empty() else NeonTheme.GREEN))
	if issues.is_empty():
		_inspector.add_child(NeonTheme.label("No problems found. Ship it.", 14, NeonTheme.GREEN))
	for i: Dictionary in issues:
		var b := Button.new()
		var err: bool = i["level"] == MapValidator.ERROR
		b.text = ("✖ " if err else "△ ") + str(i["text"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_color_override("font_color", NeonTheme.MAGENTA if err else NeonTheme.AMBER)
		var c: Vector2i = i["cell"]
		if world.in_bounds(c):
			b.tooltip_text = "Fly to %d,%d" % [c.x, c.y]
			b.pressed.connect(func() -> void:
				focus(world.to_screen(Vector2(c), world.top_z(c)))
				_hover_cell = c
				_hover_z = world.top_z(c))
		_inspector.add_child(b)
	var back := Button.new()
	back.text = "← MAP SETTINGS"
	back.pressed.connect(_show_inspector)
	_inspector.add_child(back)


## Location graph window (world → hub → interior), unsaved links included.
func show_links() -> AcceptDialog:
	var dlg := AcceptDialog.new()
	dlg.title = "LOCATION LINKS"
	dlg.ok_button_text = "CLOSE"
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1080, 620)
	var g := LocationGraph.new()
	g.theme = NeonTheme.get_theme()
	g.current = world.id
	g.build(ContentDB.maps, world.to_dict())
	g.map_chosen.connect(func(id: String) -> void:
		dlg.queue_free()
		if id != world.id:
			load_map(id))
	sc.add_child(g)
	dlg.add_child(sc)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()
	return dlg


## Battle grid for the tactics view, rebuilt only after edits.
func tactics_grid() -> IsometricGrid:
	if _tgrid == null or _tgrid_stamp != _edit_count:
		_tgrid = world.to_grid()
		_tgrid_stamp = _edit_count
	return _tgrid


func _clear(box: Control) -> void:
	for c in box.get_children():
		c.queue_free()


func _show_inspector() -> void:
	if _inspector == null:
		return
	_clear(_inspector)
	if selected.is_empty():
		_map_inspector()
	elif _is_detail(selected):
		_sprite_inspector(selected, true)
	else:
		_sprite_inspector(selected, false)


func _map_inspector() -> void:
	_inspector.add_child(NeonTheme.label(world.name.to_upper(), 20, NeonTheme.GREEN))
	var form := ForgeForm.new()
	form.build_dict({"id": world.id, "name": world.name, "kind": world.kind, "width": world.width, "depth": world.depth,
		"tile_width": world.tile_width, "height_step": world.height_step, "music": world.music}, "world_map", true)
	form.changed.connect(func(k: String) -> void:
		var d := form.get_data()
		match k:
			"id": world.id = ForgeStore.slugify(str(d["id"]))
			"name": world.name = str(d["name"])
			"kind":
				if str(d["kind"]) in WorldMap.KINDS:
					world.kind = str(d["kind"])
			"width": world.width = clampi(int(d["width"]), 3, 160)
			"depth": world.depth = clampi(int(d["depth"]), 3, 160)
			"tile_width":
				world.tile_width = clampf(float(d["tile_width"]), 16, 512)
				world.tile_height = world.tile_width * 0.5
				_renderer.rebuild()
			"height_step":
				world.height_step = clampf(float(d["height_step"]), 2, 256)
				_renderer.rebuild()
			"music": world.music = str(d["music"])
		dirty = true)
	_inspector.add_child(form)
	var stats := "%d columns · %d details · %d objects · %d particle cells · %d spawns" % [world.tiles.size(), world.details.size(), world.objects.size(), world.particles.size(), world.spawns.get("player", []).size()]
	var sl := NeonTheme.label(stats, 12, NeonTheme.TEXT_DIM)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector.add_child(sl)
	_inspector.add_child(_section("LIGHTING", NeonTheme.MAGENTA))
	var lit := CheckBox.new()
	lit.text = "Preview lighting (ambient tint + neon lights)"
	lit.button_pressed = _renderer.show_lighting
	lit.toggled.connect(func(on: bool) -> void:
		_renderer.show_lighting = on
		_renderer.rebuild_lighting())
	_inspector.add_child(lit)
	var presets: Array = ["(none)"] + WorldRenderer.AMBIENT_PRESETS.keys() + ["(custom)"]
	var cur := "(none)" if world.ambient == "" else "(custom)"
	for k2: String in WorldRenderer.AMBIENT_PRESETS:
		if WorldRenderer.AMBIENT_PRESETS[k2] == world.ambient:
			cur = k2
	var amb_row := HBoxContainer.new()
	amb_row.add_child(NeonTheme.label("Ambient", 12, NeonTheme.TEXT_DIM))
	var amb_pick := ForgeForm._option(presets, cur, func(k3: String) -> void:
		if k3 == "(custom)":
			return
		world.ambient = "" if k3 == "(none)" else str(WorldRenderer.AMBIENT_PRESETS[k3])
		_renderer.rebuild_lighting()
		dirty = true)
	amb_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amb_row.add_child(amb_pick)
	var amb_col := ColorPickerButton.new()
	amb_col.color = Color(world.ambient) if world.ambient != "" else Color.WHITE
	amb_col.custom_minimum_size = Vector2(44, 28)
	amb_col.color_changed.connect(func(c: Color) -> void:
		world.ambient = "#" + c.to_html(false)
		_renderer.rebuild_lighting()
		dirty = true)
	amb_row.add_child(amb_col)
	_inspector.add_child(amb_row)
	var post_row := HBoxContainer.new()
	post_row.add_child(NeonTheme.label("HD-2D look", 12, NeonTheme.TEXT_DIM))
	var cur_post := str(world.post.get("preset", "")) if world.post is Dictionary else str(world.post)
	var post_pick := ForgeForm._option(["off"] + HD2DPost.PRESETS.keys().filter(func(k: String) -> bool: return k != "off"), cur_post if cur_post != "" else "off", func(k: String) -> void:
		world.post = "" if k == "off" else k
		_refresh_post()
		dirty = true)
	post_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	post_row.add_child(post_pick)
	_inspector.add_child(post_row)
	var ptip := NeonTheme.label("Tilt-shift depth of field, bloom, haze, light shafts and grading — the Octopath 'living diorama' look. Previewed live here; the game focuses it on the player.", 11, NeonTheme.TEXT_DIM)
	ptip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector.add_child(ptip)
	var auto := _autosave_path()
	if FileAccess.file_exists(auto):
		var restore := Button.new()
		var when := Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(auto), true)
		restore.text = "↺ RESTORE AUTOSAVE (%s)" % when
		restore.tooltip_text = "The Forge autosaves unsaved work every 90 s. This loads that copy (undo works)."
		restore.pressed.connect(func() -> void:
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(auto))
			if d is Dictionary:
				_push_undo()
				_restore(d)
				status.emit("Autosave restored — SAVE to keep it.", NeonTheme.AMBER))
		_inspector.add_child(restore)
	var kinds := NeonTheme.label("Travel order: WORLD (cities, points of interest) → HUB (districts) → INTERIOR (buildings) / EVENT sets. ENCOUNTER maps are battles. Double-click an object to link it as a location.", 12, NeonTheme.TEXT_DIM)
	kinds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector.add_child(kinds)


func _sprite_inspector(o: Dictionary, detail: bool) -> void:
	var title := "DETAIL" if detail else str(o.get("kind", "object")).to_upper()
	_inspector.add_child(NeonTheme.label(title + "  ·  " + str(o.get("id", "")), 16, NeonTheme.AMBER))
	var prev := TextureRect.new()
	prev.texture = ForgeStore.load_texture(str(o.get("asset", "")))
	prev.custom_minimum_size = Vector2(0, 120)
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_inspector.add_child(prev)
	var fields := {}
	var keys: Array = ["asset", "z", "scale", "flip"]
	if not detail:
		o["footprint"] = WorldMap.footprint(o)
	keys += ["pos", "rot", "tint"] if detail else ["cell", "footprint", "offset", "layer", "kind", "loot_item_id", "found_text", "empty_text", "dialog_npc", "character_id"]
	for k: String in keys:
		if o.has(k) or k in ["character_id"]:
			fields[k] = o.get(k, "")
	var form := ForgeForm.new()
	form.build_dict(fields, "details" if detail else "world_object", true)
	form.changed.connect(func(_k: String) -> void:
		var d := form.get_data()
		for k2: String in d:
			o[k2] = d[k2]
		if detail: _renderer.refresh_detail(o)
		else: _renderer.refresh_object(o)
		_refresh_objects_list()
		dirty = true)
	_inspector.add_child(form)
	if o.get("light") is Dictionary:
		_inspector.add_child(_light_editor(o))
	else:
		_inspector.add_child(_anim_editor(o, detail))
	if not detail:
		var loc := Button.new()
		loc.text = "⌖ LOCATION LINK…" if not (o.get("location") is Dictionary) else "⌖ EDIT LOCATION: " + str(o["location"].get("name", ""))
		loc.tooltip_text = "Make this a city / point of interest / door that leads to another map."
		loc.pressed.connect(func() -> void: _location_dialog(o))
		_inspector.add_child(loc)
	var row := HBoxContainer.new()
	for pair: Array in [["DUPLICATE", duplicate_selected], ["DELETE", delete_selected], ["DESELECT", func() -> void: _select({})]]:
		var b := Button.new()
		b.text = pair[0]
		b.pressed.connect(pair[1])
		row.add_child(b)
	_inspector.add_child(row)


## Colour / strength / reach / flicker for a neon light object.
func _light_editor(o: Dictionary) -> Control:
	var l: Dictionary = o["light"]
	var box := VBoxContainer.new()
	box.add_child(_section("LIGHT", NeonTheme.MAGENTA))
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	var apply := func() -> void:
		_renderer.refresh_object(o)
		_renderer.rebuild_lighting()
		dirty = true
	var add := func(label: String, ctl: Control) -> void:
		grid.add_child(NeonTheme.label(label, 12, NeonTheme.TEXT_DIM))
		ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(ctl)
	var col := ColorPickerButton.new()
	col.color = Color(str(l.get("color", "#ff3fb4")))
	col.custom_minimum_size.y = 28
	col.color_changed.connect(func(c: Color) -> void:
		l["color"] = "#" + c.to_html(false)
		apply.call())
	add.call("Colour", col)
	add.call("Strength", ForgeForm._spin(float(l.get("energy", 1.2)), false, func(n: float) -> void:
		l["energy"] = clampf(n, 0.0, 8.0)
		apply.call()))
	add.call("Reach (tiles)", ForgeForm._spin(float(l.get("radius", 3.0)), false, func(n: float) -> void:
		l["radius"] = clampf(n, 0.5, 30.0)
		apply.call()))
	add.call("Flicker 0–1", ForgeForm._spin(float(l.get("flicker", 0.0)), false, func(n: float) -> void:
		l["flicker"] = clampf(n, 0.0, 1.0)
		apply.call()))
	add.call("Height (layers)", ForgeForm._spin(float(l.get("height", 1.0)), false, func(n: float) -> void:
		l["height"] = clampf(n, 0.0, 40.0)
		apply.call()))
	var tip := NeonTheme.label("Flicker above 0.6 makes a dying tube that cuts out now and then.", 11, NeonTheme.TEXT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)
	return box


## Speed / loop mode / sheet layout for animated props, items and decals.
func _anim_editor(o: Dictionary, detail: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_child(_section("ANIMATION", NeonTheme.CYAN))
	var anim: Dictionary = o.get("anim") if o.get("anim") is Dictionary else {}
	var on := CheckBox.new()
	on.text = "Animated"
	on.button_pressed = not anim.is_empty()
	box.add_child(on)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.visible = on.button_pressed
	box.add_child(grid)
	var refresh := func() -> void:
		if detail: _renderer.refresh_detail(o)
		else: _renderer.refresh_object(o)
		dirty = true
	on.toggled.connect(func(v: bool) -> void:
		grid.visible = v
		if v:
			o["anim"] = {"hframes": 4, "vframes": 1, "fps": 8, "mode": "loop", "frames": _numbered_siblings(str(o.get("asset", "")))}
			if not (o["anim"]["frames"] as Array).is_empty():
				o["anim"]["hframes"] = 1
		else:
			o["anim"] = null
		refresh.call()
		_show_inspector())
	if anim.is_empty():
		return box
	var add := func(label: String, ctl: Control) -> void:
		grid.add_child(NeonTheme.label(label, 12, NeonTheme.TEXT_DIM))
		ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(ctl)
	add.call("Columns (hframes)", ForgeForm._spin(float(anim.get("hframes", 1)), true, func(n: float) -> void:
		anim["hframes"] = maxi(int(n), 1)
		refresh.call()))
	add.call("Rows (vframes)", ForgeForm._spin(float(anim.get("vframes", 1)), true, func(n: float) -> void:
		anim["vframes"] = maxi(int(n), 1)
		refresh.call()))
	add.call("Speed (fps)", ForgeForm._spin(float(anim.get("fps", 8)), false, func(n: float) -> void:
		anim["fps"] = clampf(n, 0.1, 60.0)
		refresh.call()))
	add.call("Mode", ForgeForm._option(["loop", "pingpong", "once", "random_start"], str(anim.get("mode", "loop")), func(m: String) -> void:
		anim["mode"] = m
		refresh.call()))
	var frames: Array = anim.get("frames", [])
	var fl := NeonTheme.label("%d separate frame files" % frames.size() if frames.size() > 1 else "Uses the sheet: columns × rows", 11, NeonTheme.TEXT_DIM)
	box.add_child(fl)
	return box


## asset_1.png → [asset_1.png, asset_2.png, …] when numbered siblings exist.
func _numbered_siblings(path: String) -> Array:
	var base := path.get_basename()
	var rx := RegEx.create_from_string("^(.*?)([_\\- ]?(?:f|frame)?)(\\d+)$")
	var m := rx.search(base.get_file())
	if m == null:
		return []
	var stem := m.get_string(1) + m.get_string(2)
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		return []
	var found := {}
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() != path.get_extension():
			continue
		var m2 := rx.search(f.get_basename())
		if m2 and m2.get_string(1) + m2.get_string(2) == stem:
			found[int(m2.get_string(3))] = dir.path_join(f)
	if found.size() < 2:
		return []
	var nums: Array = found.keys()
	nums.sort()
	return nums.map(func(n: int) -> String: return found[n])


# --- Location links ------------------------------------------------------------------

func _location_dialog(o: Dictionary) -> void:
	var loc: Dictionary = o.get("location") if o.get("location") is Dictionary else {}
	var dlg := ConfirmationDialog.new()
	dlg.title = "LOCATION LINK"
	dlg.ok_button_text = "SAVE LINK"
	var v := VBoxContainer.new()
	v.theme = NeonTheme.get_theme()
	v.custom_minimum_size = Vector2(460, 0)
	var is_loc := CheckBox.new()
	is_loc.text = "This object is an enterable location"
	is_loc.button_pressed = not loc.is_empty() or world.kind == "world"
	v.add_child(is_loc)
	var types := ["city", "poi", "hub", "building", "event"] if world.kind == "world" else ["hub", "building", "poi", "event", "city"]
	# Lambdas capture locals by value, so dialog state lives in a dictionary.
	var st := {"type": str(loc.get("type", types[0])), "target": str(loc.get("target_map", "")), "cut": str(loc.get("intro_cutscene", ""))}
	v.add_child(NeonTheme.label("Type", 12, NeonTheme.TEXT_DIM))
	v.add_child(ForgeForm._option(types, st["type"], func(t: String) -> void: st["type"] = t))
	v.add_child(NeonTheme.label("Name shown above it in-game", 12, NeonTheme.TEXT_DIM))
	var name_e := LineEdit.new()
	name_e.text = str(loc.get("name", ""))
	name_e.placeholder_text = "e.g. Neo Kowloon Sprawl"
	v.add_child(name_e)
	v.add_child(NeonTheme.label("Connects to map (its inner hub / interior)", 12, NeonTheme.TEXT_DIM))
	var targets: Array = [""]
	for id: String in ContentDB.maps:
		if id != world.id:
			targets.append(id)
	targets.sort()
	var labels: Array = targets.map(func(id: String) -> String:
		return "(none yet)" if id == "" else "%s  [%s]" % [id, ContentDB.maps[id].get("kind", "encounter")])
	var tpick := OptionButton.new()
	for i in targets.size():
		tpick.add_item(labels[i])
		if targets[i] == st["target"]:
			tpick.selected = i
	tpick.item_selected.connect(func(i: int) -> void: st["target"] = targets[i])
	v.add_child(tpick)
	var mk := Button.new()
	mk.text = "+ CREATE THAT MAP NOW"
	mk.tooltip_text = "Makes an empty map of the next kind down (world → hub → interior) and links it."
	v.add_child(mk)
	v.add_child(NeonTheme.label("Arrive at spawn #", 12, NeonTheme.TEXT_DIM))
	var spawn := ForgeForm._spin(float(loc.get("target_spawn", 0)), true, func(_n: float) -> void: pass)
	v.add_child(spawn)
	v.add_child(NeonTheme.label("First-visit cutscene" + (" (always plays for world-map places)" if world.kind == "world" else " (optional — major places only)"), 12, NeonTheme.TEXT_DIM))
	v.add_child(ForgeForm._option([""] + ForgeStore.list_cutscenes(), st["cut"], func(c: String) -> void: st["cut"] = c))
	var disc := CheckBox.new()
	disc.text = "Known from the start (otherwise shows ? until first visit)"
	disc.button_pressed = bool(loc.get("discovered", false))
	v.add_child(disc)
	v.add_child(NeonTheme.label("Interact radius (cells)", 12, NeonTheme.TEXT_DIM))
	var radius := ForgeForm._spin(float(loc.get("radius", 1.5)), false, func(_n: float) -> void: pass)
	v.add_child(radius)
	mk.pressed.connect(func() -> void:
		var child_kind: String = {"world": "hub", "city": "hub", "hub": "interior", "interior": "interior", "event": "event", "encounter": "interior"}.get(world.kind, "hub")
		var base := ForgeStore.slugify(name_e.text if name_e.text != "" else "new_" + child_kind)
		var nid := base + ("_hub" if child_kind == "hub" and not base.ends_with("_hub") else "")
		var n := 2
		while ContentDB.maps.has(nid):
			nid = "%s_%d" % [base, n]
			n += 1
		var nm := WorldMap.new()
		nm.id = nid
		nm.name = name_e.text if name_e.text != "" else nid.capitalize()
		nm.kind = child_kind
		nm.width = 24
		nm.depth = 24
		nm.tile_width = world.tile_width
		nm.tile_height = world.tile_height
		nm.height_step = world.height_step
		ForgeStore.save_map(nm.to_dict())
		st["target"] = nid
		tpick.add_item("%s  [%s]" % [nid, child_kind])
		targets.append(nid)
		tpick.selected = tpick.item_count - 1
		status.emit("Created %s — open it from the map list to build it." % nid, NeonTheme.GREEN))
	dlg.add_child(v)
	dlg.confirmed.connect(func() -> void:
		_push_undo()
		if is_loc.button_pressed:
			o["kind"] = "location"
			o["location"] = {"type": st["type"], "name": name_e.text, "target_map": st["target"], "target_spawn": int(spawn.value),
				"intro_cutscene": st["cut"], "discovered": disc.button_pressed, "radius": radius.value}
		else:
			o["location"] = null
			if str(o.get("kind", "")) == "location":
				o["kind"] = "structure"
		_renderer.refresh_object(o)
		_show_inspector()
		_refresh_objects_list()
		dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


# --- Objects manager -------------------------------------------------------------------

func _refresh_objects_list() -> void:
	if _objects_list == null:
		return
	_clear(_objects_list)
	_objects_list.add_child(NeonTheme.label("OBJECTS MANAGER  ·  %d" % world.objects.size(), 14, NeonTheme.CYAN))
	for o: Dictionary in world.objects:
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = ForgeStore.load_texture(str(o.get("asset", "")))
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var name_s := str(o.get("asset", "")).get_file().get_basename()
		if o.get("light") is Dictionary:
			name_s = "✸ " + str(o["light"].get("preset", "light")).replace("_", " ")
		if o.get("location") is Dictionary:
			name_s = "⌖ " + str(o["location"].get("name", name_s))
		var b := Button.new()
		b.custom_minimum_size.x = 60
		b.text = "%s  ·  %s  L%d" % [name_s, str(o.get("kind", "")), int(o.get("z", 0))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var oo := o
		b.pressed.connect(func() -> void:
			_select(oo)
			focus(world.to_screen(Vector2(int(oo["cell"][0]), int(oo["cell"][1])), float(oo.get("z", 0)))))
		row.add_child(b)
		var eye := Button.new()
		eye.text = "◌" if bool(o.get("hidden", false)) else "◉"
		eye.tooltip_text = "Hide / show in the editor"
		eye.pressed.connect(func() -> void:
			oo["hidden"] = not bool(oo.get("hidden", false))
			if not oo["hidden"]:
				oo.erase("hidden")
			_renderer.refresh_object(oo)
			_refresh_objects_list())
		row.add_child(eye)
		var del := Button.new()
		del.text = "🗑"
		del.pressed.connect(func() -> void:
			_select(oo)
			delete_selected())
		row.add_child(del)
		_objects_list.add_child(row)



## Bottom-right overview: the whole map in miniature (top tile colours, height
## shading), the camera's view as a box. Click or drag to fly there.
class Minimap extends Control:
	var p: ForgeWorldPainter
	var _tex: ImageTexture
	var _dirty: bool = true
	var _last_build: float = 0.0
	static var _tile_colors: Dictionary = {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		tooltip_text = "Minimap — click or drag to fly there"

	func mark_dirty() -> void:
		_dirty = true

	static func tile_color(tile_id: String) -> Color:
		if _tile_colors.has(tile_id):
			return _tile_colors[tile_id]
		var col := Color(str(ContentDB.terrain.get(WorldMap.terrain_of(tile_id), {}).get("color", "#444455")))
		var frames := WorldRenderer.tile_frames(tile_id)
		if not frames.is_empty():
			var img: Image = (frames[0] as Texture2D).get_image()
			if img:
				if img.is_compressed():
					img = img.duplicate()
					img.decompress()
				# Average a few points across the top face.
				var r := WorldRenderer.fit_rect(frames[0])
				var acc := Color(0, 0, 0, 0)
				var n := 0
				for pt: Vector2 in [Vector2(0.5, 0.25), Vector2(0.3, 0.25), Vector2(0.7, 0.25), Vector2(0.5, 0.12), Vector2(0.5, 0.38)]:
					var px := Vector2i(int(r.position.x + r.size.x * pt.x), int(r.position.y + r.size.x * 0.5 * pt.y * 2.0))
					px = px.clamp(Vector2i.ZERO, img.get_size() - Vector2i.ONE)
					var c := img.get_pixelv(px)
					if c.a > 0.3:
						acc += c
						n += 1
				if n > 0:
					col = Color(acc.r / n, acc.g / n, acc.b / n)
		_tile_colors[tile_id] = col
		return col

	func _rebuild() -> void:
		var w := p.world
		var img := Image.create(maxi(w.width, 1), maxi(w.depth, 1), false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for cell: Vector2i in w.tiles:
			if not w.in_bounds(cell):
				continue
			var c := tile_color(w.top_tile(cell))
			var h := w.top_z(cell)
			c = c.lightened(clampf(h * 0.04, 0.0, 0.5)) if h >= 0 else c.darkened(clampf(-h * 0.08, 0.0, 0.6))
			img.set_pixel(cell.x, cell.y, c)
		_tex = ImageTexture.create_from_image(img)
		_dirty = false
		_last_build = WorldRenderer.now()

	func _process(_d: float) -> void:
		if _dirty and WorldRenderer.now() - _last_build > 0.25:
			_rebuild()
		queue_redraw()

	## Iso transform: map cell (x, y) → minimap pixels.
	func _xf() -> Transform2D:
		var w := p.world
		var s := minf(size.x / float(w.width + w.depth), size.y * 2.0 / float(w.width + w.depth)) * 0.95
		var origin := Vector2(size.x * 0.5 - (w.width - w.depth) * s * 0.5, (size.y - (w.width + w.depth) * s * 0.5) * 0.5)
		return Transform2D(Vector2(s, s * 0.5), Vector2(-s, s * 0.5), origin)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.01, 0.07, 0.85))
		draw_rect(Rect2(Vector2.ZERO, size), Color(NeonTheme.CYAN, 0.6), false, 1.5)
		if p == null or _tex == null:
			return
		var xf := _xf()
		draw_set_transform_matrix(xf)
		draw_texture(_tex, Vector2.ZERO)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# Camera view box (ground plane).
		var vp_size := p._vpc.size / p._cam.zoom.x
		var corners := [p._cam.position + Vector2(-vp_size.x, -vp_size.y) * 0.5, p._cam.position + Vector2(vp_size.x, -vp_size.y) * 0.5,
			p._cam.position + Vector2(vp_size.x, vp_size.y) * 0.5, p._cam.position + Vector2(-vp_size.x, vp_size.y) * 0.5]
		var pts := PackedVector2Array()
		for c: Vector2 in corners:
			pts.append(xf * (p.world.from_screen(c, 0) + Vector2(0.5, 0.5)))
		pts.append(pts[0])
		draw_polyline(pts, Color(1.8, 1.8, 1.8, 0.9), 1.5)
		var hov := xf * (Vector2(p._hover_cell) + Vector2(0.5, 0.5))
		draw_circle(hov, 2.5, NeonTheme.MAGENTA)

	func _gui_input(event: InputEvent) -> void:
		var go := false
		var at := Vector2.ZERO
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			go = true
			at = (event as InputEventMouseButton).position
		elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT):
			go = true
			at = (event as InputEventMouseMotion).position
		if go:
			var cell := _xf().affine_inverse() * at - Vector2(0.5, 0.5)
			p.focus(p.world.to_screen(cell, 0))
			accept_event()



# --- Terrain generator -------------------------------------------------------------

## Noise heightfield painted with the selected tiles as height bands (first =
## lowest, e.g. water; last = peaks). `region` empty = whole map. Columns are
## solid (filled from the ground up) so cliffs read as real terrain.
func generate_terrain(region: Rect2i, max_height: int, roughness: float, water: float, seed_value: int, replace: bool = true) -> int:
	if sel_tiles.is_empty():
		status.emit("Select tiles in the palette first: lowest band first (shift+click to add more).", NeonTheme.MAGENTA)
		return 0
	if region.size == Vector2i.ZERO:
		region = Rect2i(0, 0, world.width, world.depth)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 4
	noise.frequency = clampf(roughness, 0.005, 0.5)
	var changed: Array = []
	var bands := sel_tiles.size()
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var c := Vector2i(x, y)
			if not world.in_bounds(c):
				continue
			var v := (noise.get_noise_2d(x, y) + 1.0) * 0.5  # 0..1
			if replace:
				world.tiles.erase(c)
			if v < water:
				world.set_tile(c, 0, sel_tiles[0])
			else:
				var t := (v - water) / maxf(1.0 - water, 0.001)
				var h := int(round(t * max_height))
				var band := clampi(1 + int(t * (bands - 1)), 1, bands - 1) if bands > 1 else 0
				var top_tile := sel_tiles[band]
				var under := sel_tiles[maxi(band - 1, 0)] if band > 0 else top_tile
				for z in range(0, h):
					world.set_tile(c, z, under)
				world.set_tile(c, h, top_tile)
			changed.append(c)
	_renderer.refresh_columns(changed)
	_minimap.mark_dirty()
	_edit_count += 1
	dirty = true
	return changed.size()


func _generate_dialog() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "GENERATE TERRAIN"
	dlg.ok_button_text = "GENERATE"
	var v := VBoxContainer.new()
	v.theme = NeonTheme.get_theme()
	v.custom_minimum_size = Vector2(420, 0)
	var info := NeonTheme.label("Uses your selected tiles as bands, low → high:\n%s" % (" → ".join(PackedStringArray(sel_tiles.map(func(t: String) -> String: return t.get_file()))) if not sel_tiles.is_empty() else "(nothing selected — shift+click tiles first)"), 12, NeonTheme.CYAN)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var st := {"h": 6, "rough": 0.06, "water": 0.3, "seed": randi() % 99999, "area": "whole map"}
	var grid := GridContainer.new()
	grid.columns = 2
	v.add_child(grid)
	var add := func(label: String, ctl: Control) -> void:
		grid.add_child(NeonTheme.label(label, 12, NeonTheme.TEXT_DIM))
		ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(ctl)
	add.call("Max height (layers)", ForgeForm._spin(6, true, func(n: float) -> void: st["h"] = clampi(int(n), 0, 40)))
	add.call("Roughness", ForgeForm._spin(0.06, false, func(n: float) -> void: st["rough"] = n))
	add.call("Water / lowest band 0–1", ForgeForm._spin(0.3, false, func(n: float) -> void: st["water"] = clampf(n, 0.0, 0.95)))
	add.call("Seed", ForgeForm._spin(st["seed"], true, func(n: float) -> void: st["seed"] = int(n)))
	add.call("Area", ForgeForm._option(["whole map", "around the cursor (16×16)"], "whole map", func(a: String) -> void: st["area"] = a))
	var tip := NeonTheme.label("Low roughness = rolling hills, high = jagged peaks. Undo (Ctrl+Z) if you don't like it, change the seed and go again.", 11, NeonTheme.TEXT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	dlg.add_child(v)
	var anchor := _hover_cell
	dlg.confirmed.connect(func() -> void:
		_push_undo()
		var region := Rect2i()
		if str(st["area"]) != "whole map" and world.in_bounds(anchor):
			region = Rect2i(anchor - Vector2i(8, 8), Vector2i(16, 16))
		var n := generate_terrain(region, int(st["h"]), float(st["rough"]), float(st["water"]), int(st["seed"]))
		status.emit("Generated %d columns. Ctrl+Z to undo, or tweak the seed and go again." % n, NeonTheme.GREEN)
		dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()
