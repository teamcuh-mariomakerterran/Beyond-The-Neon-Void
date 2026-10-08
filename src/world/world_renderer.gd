class_name WorldRenderer
extends Node2D
## Draws a WorldMap: one StripView per 32 columns of an iso diagonal (their tile stacks),
## detail decals, objects (static or animated) and painted particle volumes.
## Used by the Neon Forge World Painter (live), exploration and battles, so what
## you paint is exactly what plays.
##
## Draw order follows the battle convention: column = draw_order*2, anything
## standing on a column (details, objects, units) = draw_order*2 + 1.
##
## Big maps stream: past STREAM_MIN_CELLS columns the map is cut into
## CHUNK×CHUNK chunks and only the ones around the camera are built (tile
## strips, objects, details, particles, lights), nearest first, a few per frame;
## chunks the camera leaves are freed. A one-pixel-per-column overview
## (LodLayer) sits underneath, so a zoomed-out view never shows holes.
##
## Tile art is auto-fitted: the opaque bounding box of each image is scaled to
## the map's tile width and its top pinned to the diamond's north point, so
## slightly-off tiles still snap to the world angle.

signal object_clicked(obj: Dictionary)

var world: WorldMap
var show_particles: bool = true
var show_objects: bool = true
var show_details: bool = true
var dim_above: int = 999  # layers above this are drawn faded (painter focus)

var _columns: Dictionary = {}  # strip key (order, chunk x, chunk y) -> StripView
var _obj_nodes: Dictionary = {}  # id -> WorldSprite
var _detail_nodes: Dictionary = {}
var _particle_nodes: Dictionary = {}  # "preset|z" -> Node2D
var _columns_root: Node2D
var _details_root: Node2D
var _objects_root: Node2D
var _particles_root: Node2D
var _lights_root: Node2D
var _fx: FxLayer
var cables: CableNet
var signage: Signage
var _ambient: CanvasModulate
## Preview the map's ambient tint + neon lights (on in game, toggleable in the editor).
var show_lighting: bool = true
## Draw editor-only markers (light bulbs) — the painter turns this on.
var editor_markers: bool = false
## cell -> {z: time placed}, for the drop-in animation.
var _pops: Dictionary = {}

const POP_TIME := 0.22

# --- Streaming ---
const CHUNK := 32
## Maps with at least this many columns stream (smaller ones build at once).
const STREAM_MIN_CELLS := 96 * 96
## On for big maps (set in rebuild); force_streaming turns it on for any size.
var streaming: bool = false
var force_streaming: bool = false
## Chunks built per frame (each is up to 1024 columns plus its objects).
var chunks_per_frame: int = 2
## Most chunks kept at once (zoomed far out the overview fills the rest).
var max_chunks: int = 80
## Extra ring of chunks around the view, built before they scroll in.
var margin_chunks: int = 1
## chunk -> {objs: [ids], dets: [ids], fx: Node2D (particles), lights: Node2D}
var _chunks: Dictionary = {}
var _lod: LodLayer
## While a chunk loads, strips collect here and refresh once at the end.
var _batch: Dictionary = {}
var _batching: bool = false
const LIGHT_PRESETS := {
	"neon_pink": {"color": "#ff3fb4", "energy": 1.4, "radius": 3.0, "flicker": 0.1},
	"neon_cyan": {"color": "#3ff6ff", "energy": 1.3, "radius": 3.0, "flicker": 0.05},
	"sodium_lamp": {"color": "#ffb347", "energy": 1.1, "radius": 4.0, "flicker": 0.0},
	"toxic_glow": {"color": "#8dff3f", "energy": 1.2, "radius": 2.5, "flicker": 0.15},
	"fire": {"color": "#ff7a2f", "energy": 1.6, "radius": 2.5, "flicker": 0.45},
	"broken_tube": {"color": "#d9e8ff", "energy": 1.0, "radius": 2.0, "flicker": 0.9},
	"moonlight": {"color": "#8ea6ff", "energy": 0.7, "radius": 8.0, "flicker": 0.0},
}
## Ambient presets for the whole map (CanvasModulate tint).
const AMBIENT_PRESETS := {
	"day": "#ffffff", "dusk": "#e0a8c8", "neon_noir": "#7a6aa8", "night": "#4a4f86",
	"toxic_haze": "#9fb88a", "blackout": "#2a2840", "blood_moon": "#a8586a",
}

static var _fit_cache: Dictionary = {}
static var _light_tex: Texture2D


func _ready() -> void:
	_columns_root = Node2D.new()
	_details_root = Node2D.new()
	_objects_root = Node2D.new()
	_particles_root = Node2D.new()
	_lights_root = Node2D.new()
	_lod = LodLayer.new()
	_lod.renderer = self
	_lod.z_as_relative = false
	_lod.z_index = -4090
	add_child(_lod)
	for n: Node2D in [_columns_root, _details_root, _objects_root, _particles_root, _lights_root]:
		add_child(n)
	cables = CableNet.new()
	cables.renderer = self
	add_child(cables)
	signage = Signage.new()
	add_child(signage)
	_fx = FxLayer.new()
	_fx.renderer = self
	_fx.z_as_relative = false
	_fx.z_index = 4085
	add_child(_fx)
	_ambient = CanvasModulate.new()
	add_child(_ambient)
	if world:
		rebuild()


## Shared animation clock so every water tile / prop loops in step.
static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func set_world(w: WorldMap) -> void:
	world = w
	if is_inside_tree():
		rebuild()


func rebuild() -> void:
	if _columns_root == null:
		return
	for root: Node2D in [_columns_root, _details_root, _objects_root, _particles_root, _lights_root]:
		for c in root.get_children():
			c.queue_free()
	_columns.clear()
	_obj_nodes.clear()
	_detail_nodes.clear()
	_particle_nodes.clear()
	_chunks.clear()
	streaming = force_streaming or world.tiles.size() >= STREAM_MIN_CELLS
	_lod.visible = streaming
	set_process(streaming)
	if streaming:
		_lod.rebuild()
		rebuild_lighting()  # ambient only; lights come with their chunks
		update_stream(8)  # what's on screen right away
		return
	for cell: Vector2i in world.tiles:
		refresh_column(cell)
	rebuild_details()
	rebuild_objects()
	rebuild_particles()
	rebuild_lighting()


## Columns are drawn in strips: every column on the same iso diagonal (x + y)
## shares a draw order, so a strip of STRIP_LEN of them is one node. That keeps
## sorting against units/objects correct and cuts node count ~32× (huge maps).
const STRIP_LEN := 32


## Strips never cross a chunk, so a chunk frees exactly its own strips.
static func strip_key(cell: Vector2i) -> Vector3i:
	return Vector3i(cell.x + cell.y, floori(float(cell.x) / CHUNK), floori(float(cell.y) / CHUNK))


static func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK), floori(float(cell.y) / CHUNK))


func refresh_column(cell: Vector2i) -> void:
	if streaming:
		if not _batching:
			_lod.mark(cell)
		if not _chunks.has(chunk_of(cell)):
			return  # built when its chunk streams in
	var key := strip_key(cell)
	var sv: StripView = _columns.get(key)
	if sv == null:
		if not world.tiles.has(cell):
			return
		sv = StripView.new()
		sv.renderer = self
		sv.key = key
		_columns[key] = sv
		_columns_root.add_child(sv)
	if world.tiles.has(cell):
		sv.cells[cell] = true
	else:
		sv.cells.erase(cell)
	if sv.cells.is_empty():
		sv.queue_free()
		_columns.erase(key)
		return
	if _batching:
		_batch[sv] = true
	else:
		sv.refresh()


func refresh_columns(cells: Array) -> void:
	for c: Vector2i in cells:
		refresh_column(c)


## Editor juice: the tile at (cell, z) drops in and a ring flashes.
func pop(cell: Vector2i, z: int, erase: bool = false, ring: bool = true) -> void:
	if not erase:
		if not _pops.has(cell):
			_pops[cell] = {}
		_pops[cell][z] = now()
		var sv: StripView = _columns.get(strip_key(cell))
		if sv:
			sv.set_process(true)
	if _fx and ring:
		_fx.add_ring(world.to_screen(Vector2(cell), z), Color(2.2, 0.35, 0.5) if erase else Color(0.3, 2.0, 1.2))


func is_popping(cell: Vector2i) -> bool:
	var d: Dictionary = _pops.get(cell, {})
	for z: int in d.keys():
		if now() - float(d[z]) >= POP_TIME:
			d.erase(z)
	if d.is_empty():
		_pops.erase(cell)
		return false
	return true


func pop_progress(cell: Vector2i, z: int) -> float:
	var d: Dictionary = _pops.get(cell, {})
	if not d.has(z):
		return 1.0
	return clampf((now() - float(d[z])) / POP_TIME, 0.0, 1.0)


func flash_text(at: Vector2, text: String, color: Color) -> void:
	if _fx:
		_fx.add_text(at, text, color)


func redraw_all_columns() -> void:
	for sv: StripView in _columns.values():
		sv.queue_redraw()


## X-ray cutaway: tiles and objects in front of `focus` (screen point of the
## player / cursor) that would hide it are drawn see-through. order/z describe
## the focus column; pass Vector2.INF to turn it off.
var cutaway_focus: Vector2 = Vector2.INF
var cutaway_order: int = 0
var cutaway_z: int = 0
const CUTAWAY_RADIUS := 1.6  # in tile widths


func set_cutaway(focus: Vector2, order: int, z: int) -> void:
	if focus == cutaway_focus and order == cutaway_order:
		return
	var old := cutaway_order
	cutaway_focus = focus
	cutaway_order = order
	cutaway_z = z
	for key: Vector3i in _columns:
		if (key.x > old and key.x <= old + 12) or (key.x > order and key.x <= order + 12):
			(_columns[key] as StripView).queue_redraw()
	for n: WorldSprite in _obj_nodes.values():
		n.apply_cutaway()


## 0.3 when the thing at (screen pos, order, top z) hides the focus, else 1.
func cutaway_alpha(at: Vector2, order: int, z: int) -> float:
	if cutaway_focus == Vector2.INF or order <= cutaway_order or z < cutaway_z:
		return 1.0
	# The column spans from its top face down to the focus's level: it hides
	# the focus if the focus point falls inside that span (horizontally close).
	var top_y := at.y - world.tile_height * 0.5
	var base_y := at.y + (z - cutaway_z) * world.height_step + world.tile_height
	if absf(at.x - cutaway_focus.x) > world.tile_width * CUTAWAY_RADIUS * 0.6:
		return 1.0
	if cutaway_focus.y < top_y or cutaway_focus.y > base_y:
		return 1.0
	return 0.3


# --- Tiles -----------------------------------------------------------------

## Textures for a tile id (1 = static, >1 = animated frames) and its fps.
static func tile_frames(tile_id: String) -> Array:
	if tile_id.begins_with("terrain:"):
		return []
	var tdb: Dictionary = ContentDB.get("tiles") if ContentDB.get("tiles") is Dictionary else {}
	var def: Dictionary = tdb.get(tile_id, {})
	var paths: Array = def.get("frames", [])
	if paths.is_empty():
		var p := str(def.get("texture", ""))
		if p == "":
			p = "res://assets/tiles/%s.png" % tile_id
		paths = [p]
	var out: Array = []
	for p2: String in paths:
		var t := ForgeStore.load_texture(p2)
		if t:
			out.append(t)
	return out


static func tile_fps(tile_id: String) -> float:
	var tdb: Dictionary = ContentDB.get("tiles") if ContentDB.get("tiles") is Dictionary else {}
	return float(tdb.get(tile_id, {}).get("fps", 6.0))


## Opaque bounds of a texture in source pixels (cached).
static func fit_rect(tex: Texture2D) -> Rect2:
	var k := tex.get_instance_id()
	if _fit_cache.has(k):
		return _fit_cache[k]
	var r := Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img:
		if img.is_compressed():
			img = img.duplicate()
			img.decompress()
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			r = Rect2(used)
	_fit_cache[k] = r
	return r


## Scale that makes a freshly placed object a sensible size for this map:
## structures span ~2 tiles, everything else ~1 (source art is often 1000px+).
static func default_scale(w: WorldMap, asset: String, kind: String) -> float:
	if asset.ends_with(".json") and LatticeClip.is_clip(asset):
		var clip := LatticeClip.load_clip(asset)
		if clip.get("ok", false):
			var bb: Array = clip["bbox"]
			var bw := maxf(float(bb[2]) - float(bb[0]), 1.0)
			# Lattice footprints are in tiles and the base spans them exactly.
			var goal := w.tile_width * float(clip["footprint"])
			return snappedf(goal / bw, 0.001) if bw > goal * 1.25 else 1.0
	var tex := ForgeStore.load_texture(asset)
	if tex == null:
		return 1.0
	var used := fit_rect(tex)
	var span := 2.2 if kind in ["structure", "location"] else 0.9
	var target := w.tile_width * span
	return snappedf(target / used.size.x, 0.001) if used.size.x > target * 1.25 else 1.0


## Draws one tile whose top-face centre is `center`. `alpha` for ghosts/fading.
static func draw_tile(ci: CanvasItem, w: WorldMap, tile_id: String, center: Vector2, alpha: float = 1.0, phase: float = 0.0, opts: Dictionary = {}) -> void:
	var frames := tile_frames(tile_id)
	var col := Color(str(opts.get("tint", "#ffffff")))
	col.a = alpha
	if opts.has("ramp"):
		_draw_ramp(ci, w, tile_id, frames, center, col, str(opts["ramp"]), bool(opts.get("stairs", false)), phase)
		return
	if frames.is_empty():
		_draw_color_block(ci, w, tile_id, center, alpha)
		return
	var tex: Texture2D = frames[0]
	if frames.size() > 1:
		tex = frames[SheetSprite.frame_at(now(), frames.size(), tile_fps(tile_id), "loop", phase)]
	var used := fit_rect(tex)
	var s := w.tile_width / used.size.x
	var north := center + Vector2(-w.tile_width * 0.5, -w.tile_height * 0.5)
	if bool(opts.get("flip", false)):
		# Mirror around the tile's vertical axis (variation without new art).
		ci.draw_set_transform(Vector2(center.x * 2.0, 0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(tex, Rect2(north, used.size * s), used, col)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect_region(tex, Rect2(north, used.size * s), used, col)


## Grid corners of a cell's top face in draw order N, E, S, W, as (dx, dy) signs.
const _CORNERS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]


## A slope from this layer up one height_step toward `dir`, texture-mapped from
## the tile's own top face (any ground tile can become a ramp), with shaded
## side faces; `stairs` adds step treads.
static func _draw_ramp(ci: CanvasItem, w: WorldMap, tile_id: String, frames: Array, center: Vector2, col: Color, dir: String, stairs: bool, phase: float) -> void:
	var hw := w.tile_width * 0.5
	var hh := w.tile_height * 0.5
	var base := PackedVector2Array([center + Vector2(0, -hh), center + Vector2(hw, 0), center + Vector2(0, hh), center + Vector2(-hw, 0)])
	var up := PackedVector2Array(base)
	var axis := 0 if dir.begins_with("x") else 1
	var sign := 1 if dir.ends_with("+") else -1
	for i in 4:
		var c: Vector2i = _CORNERS[i]
		if (c.x if axis == 0 else c.y) == sign:
			up[i] = base[i] + Vector2(0, -w.height_step)
	var side := tile_avg_color(tile_id, frames).darkened(0.35)
	side.a = col.a
	# Visible side faces are the front-left (W→S) and front-right (S→E) edges.
	for edge: Array in [[3, 2], [2, 1]]:
		var a: int = edge[0]
		var b: int = edge[1]
		if up[a] != base[a] or up[b] != base[b]:
			var shade := side if edge[0] == 3 else side.darkened(0.2)
			ci.draw_colored_polygon(PackedVector2Array([up[a], up[b], base[b], base[a]]), shade)
	if frames.is_empty():
		var def: Dictionary = ContentDB.terrain.get(WorldMap.terrain_of(tile_id), {})
		var top := Color(str(def.get("color", "#2a2438"))) * col
		ci.draw_colored_polygon(up, top)
	else:
		var tex: Texture2D = frames[0]
		if frames.size() > 1:
			tex = frames[SheetSprite.frame_at(now(), frames.size(), tile_fps(tile_id), "loop", phase)]
		var u := fit_rect(tex)
		var ts := tex.get_size()
		var uvs := PackedVector2Array([
			Vector2(u.position.x + u.size.x * 0.5, u.position.y) / ts,
			Vector2(u.end.x, u.position.y + u.size.x * 0.25) / ts,
			Vector2(u.position.x + u.size.x * 0.5, u.position.y + u.size.x * 0.5) / ts,
			Vector2(u.position.x, u.position.y + u.size.x * 0.25) / ts])
		ci.draw_colored_polygon(up, col, uvs, tex)
	if stairs:
		# Step treads: lines across the slope, darker below each nose.
		# Each low corner climbs to its adjacent high corner; treads join them.
		var lo: Array = [0, 1, 2, 3].filter(func(i: int) -> bool: return up[i] == base[i])
		var hi: Array = [0, 1, 2, 3].filter(func(i: int) -> bool: return up[i] != base[i])
		if lo.size() == 2 and hi.size() == 2:
			var pair := func(l: int) -> int: return (l + 1) % 4 if hi.has((l + 1) % 4) else (l + 3) % 4
			for k in range(1, 4):
				var t := k / 4.0
				var p1: Vector2 = up[lo[0]].lerp(up[pair.call(lo[0])], t)
				var p2: Vector2 = up[lo[1]].lerp(up[pair.call(lo[1])], t)
				ci.draw_line(p1, p2, Color(0, 0, 0, 0.45 * col.a), 2.0)
				ci.draw_line(p1 + Vector2(0, -1.5), p2 + Vector2(0, -1.5), Color(1, 1, 1, 0.12 * col.a), 1.0)
	var outline := PackedVector2Array(up)
	outline.append(up[0])
	ci.draw_polyline(outline, Color(0, 0, 0, 0.25 * col.a), 1.0)


static var _avg_colors: Dictionary = {}


## Average colour of a tile's top face (ramp sides, minimap).
static func tile_avg_color(tile_id: String, frames: Array = []) -> Color:
	if _avg_colors.has(tile_id):
		return _avg_colors[tile_id]
	var c := Color(str(ContentDB.terrain.get(WorldMap.terrain_of(tile_id), {}).get("side", "#1a1626")))
	if frames.is_empty():
		frames = tile_frames(tile_id)
	if not frames.is_empty():
		var img: Image = (frames[0] as Texture2D).get_image()
		if img:
			if img.is_compressed():
				img = img.duplicate()
				img.decompress()
			var r := fit_rect(frames[0])
			var acc := Color(0, 0, 0, 0)
			var n := 0
			for fx in [0.3, 0.5, 0.7]:
				for fy in [0.15, 0.25, 0.35]:
					var px := Vector2i(int(r.position.x + r.size.x * fx), int(r.position.y + r.size.x * fy))
					px = px.clamp(Vector2i.ZERO, img.get_size() - Vector2i.ONE)
					var p := img.get_pixelv(px)
					if p.a > 0.3:
						acc += p
						n += 1
			if n > 0:
				c = Color(acc.r / n, acc.g / n, acc.b / n)
	_avg_colors[tile_id] = c
	return c


static func _draw_color_block(ci: CanvasItem, w: WorldMap, tile_id: String, center: Vector2, alpha: float) -> void:
	var terr := WorldMap.terrain_of(tile_id)
	var def: Dictionary = ContentDB.terrain.get(terr, {})
	var top_col := Color(str(def.get("color", "#2a2438")))
	var side_col := Color(str(def.get("side", "#1a1626")))
	top_col.a = alpha
	side_col.a = alpha
	var hw := w.tile_width * 0.5
	var hh := w.tile_height * 0.5
	var n := center + Vector2(0, -hh)
	var e := center + Vector2(hw, 0)
	var s := center + Vector2(0, hh)
	var wv := center + Vector2(-hw, 0)
	var base := Vector2(0, w.height_step)
	ci.draw_colored_polygon(PackedVector2Array([wv, s, s + base, wv + base]), side_col)
	ci.draw_colored_polygon(PackedVector2Array([s, e, e + base, s + base]), side_col.darkened(0.25))
	ci.draw_colored_polygon(PackedVector2Array([n, e, s, wv]), top_col)
	ci.draw_polyline(PackedVector2Array([n, e, s, wv, n]), Color(0.35, 0.25, 0.55, 0.9 * alpha), 1.0)


static func diamond(w: WorldMap, cell: Vector2, z: float) -> PackedVector2Array:
	var c := w.to_screen(cell, z)
	var hw := w.tile_width * 0.5
	var hh := w.tile_height * 0.5
	return PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])


# --- Details / objects -----------------------------------------------------

func rebuild_details() -> void:
	for c in _details_root.get_children():
		c.queue_free()
	_detail_nodes.clear()
	for d: Dictionary in world.details:
		refresh_detail(d)  # streaming: only loaded chunks build nodes


static func _cell_of(d: Dictionary, detail: bool) -> Vector2i:
	var a: Array = d.get("pos" if detail else "cell", [0, 0])
	return Vector2i(floori(float(a[0]) + 0.5), floori(float(a[1]) + 0.5))


func refresh_detail(d: Dictionary) -> void:
	var node: WorldSprite = _detail_nodes.get(str(d["id"]))
	if streaming and not _chunks.has(chunk_of(_cell_of(d, true))):
		if node:
			remove_detail(d)
		return
	if node == null:
		node = WorldSprite.new()
		node.renderer = self
		node.is_detail = true
		_details_root.add_child(node)
		_detail_nodes[str(d["id"])] = node
	node.data = d
	node.visible = show_details
	node.refresh()


func remove_detail(d: Dictionary) -> void:
	var node: Node = _detail_nodes.get(str(d["id"]))
	if node:
		node.queue_free()
		_detail_nodes.erase(str(d["id"]))


func rebuild_objects() -> void:
	for c in _objects_root.get_children():
		c.queue_free()
	_obj_nodes.clear()
	for o: Dictionary in world.objects:
		refresh_object(o)
	if cables:
		cables.mark_dirty()


func refresh_object(o: Dictionary) -> void:
	var node: WorldSprite = _obj_nodes.get(str(o["id"]))
	if streaming and not _chunks.has(chunk_of(_cell_of(o, false))):
		if node:
			remove_object(o)
		return
	if node == null:
		node = WorldSprite.new()
		node.renderer = self
		_objects_root.add_child(node)
		_obj_nodes[str(o["id"])] = node
	node.data = o
	node.visible = show_objects and not bool(o.get("hidden", false))
	node.refresh()
	if cables:
		cables.mark_dirty()


func remove_object(o: Dictionary) -> void:
	var node: Node = _obj_nodes.get(str(o["id"]))
	if node:
		node.queue_free()
		_obj_nodes.erase(str(o["id"]))
	if cables:
		cables.mark_dirty()


func object_node(obj_id: String) -> WorldSprite:
	return _obj_nodes.get(obj_id)


## Topmost object/detail whose sprite covers screen point p (for selecting).
func pick_sprite(p: Vector2, details_too: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var best_z := -INF
	var pools: Array = [_obj_nodes]
	if details_too:
		pools.append(_detail_nodes)
	for pool: Dictionary in pools:
		for n: WorldSprite in pool.values():
			if n.visible and n.hit(p):
				var z := float(n.z_index) + (0.5 if pool == _obj_nodes else 0.0)
				if z > best_z:
					best_z = z
					best = n.data
	return best


# --- Particles -------------------------------------------------------------

func rebuild_particles() -> void:
	for c in _particles_root.get_children():
		c.queue_free()
	_particle_nodes.clear()
	if not show_particles:
		return
	if streaming:
		for ch: Vector2i in _chunks:
			_build_chunk_particles(ch)
		return
	_add_particles(world.particle_groups(), _particles_root)


## Particle volumes for one chunk (streaming), under the chunk's own node.
func _build_chunk_particles(ch: Vector2i) -> void:
	var info: Dictionary = _chunks[ch]
	if info.get("fx") is Node:
		(info["fx"] as Node).queue_free()
	var fx := Node2D.new()
	_particles_root.add_child(fx)
	info["fx"] = fx
	if not show_particles:
		return
	var groups := {}
	for x in range(ch.x * CHUNK, ch.x * CHUNK + CHUNK):
		for y in range(ch.y * CHUNK, ch.y * CHUNK + CHUNK):
			var c := Vector2i(x, y)
			if world.particles.has(c):
				for e: Array in world.particles[c]:
					var k := "%s|%d" % [e[1], int(e[0])]
					if not groups.has(k):
						groups[k] = []
					groups[k].append(c)
	_add_particles(groups, fx)


func _add_particles(groups: Dictionary, parent: Node) -> void:
	for k: String in groups:
		var parts := k.split("|")
		var preset := parts[0]
		var z := int(parts[1])
		var diamonds: Array[PackedVector2Array] = []
		var max_order := 0
		for cell: Vector2i in groups[k]:
			diamonds.append(diamond(world, Vector2(cell), z))
			max_order = maxi(max_order, cell.x + cell.y)
		var node: Node2D = ParticleFactory.make_for_cells(preset, diamonds)
		if node == null:
			continue
		# Low particles (fog in a valley) sort with the terrain; high ones
		# (clouds, rain) float over everything.
		node.z_index = max_order * 2 + 1 if z <= 4 else 4000
		parent.add_child(node)
		if parent == _particles_root:
			_particle_nodes[k] = node


# --- Streaming -----------------------------------------------------------------

func _process(_d: float) -> void:
	if streaming and world:
		update_stream(chunks_per_frame)


## Chunks the camera can see (plus the margin), nearest to the view centre first.
func wanted_chunks() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if world == null or not is_inside_tree():
		return out
	var vp := get_viewport()
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var r := vp.get_visible_rect()
	# Tall stacks and buildings below the bottom edge still reach into view.
	var reach := world.height_step * 8.0 + world.tile_height * 6.0
	var pts := [to_local * r.position, to_local * Vector2(r.end.x, r.position.y), to_local * r.end, to_local * Vector2(r.position.x, r.end.y)]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for pt: Vector2 in pts:
		for dy: float in [-world.height_step * 4.0, reach]:
			var f := world.from_screen(pt + Vector2(0, dy), 0)
			lo = lo.min(f)
			hi = hi.max(f)
	var c0 := chunk_of(Vector2i(floori(lo.x), floori(lo.y))) - Vector2i(margin_chunks, margin_chunks)
	var c1 := chunk_of(Vector2i(ceili(hi.x), ceili(hi.y))) + Vector2i(margin_chunks, margin_chunks)
	var last := chunk_of(Vector2i(world.width - 1, world.depth - 1))
	c0 = c0.clamp(Vector2i.ZERO, last)
	c1 = c1.clamp(Vector2i.ZERO, last)
	var mid_f := world.from_screen(to_local * r.get_center(), 0)
	var mid := Vector2(mid_f.x / CHUNK - 0.5, mid_f.y / CHUNK - 0.5)
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			out.append(Vector2i(cx, cy))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_squared_to(mid) < Vector2(b).distance_squared_to(mid))
	if out.size() > max_chunks:
		out.resize(max_chunks)
	return out


## Builds up to `budget` missing chunks and frees the ones out of view.
func update_stream(budget: int) -> void:
	var want := wanted_chunks()
	var keep := {}
	for ch: Vector2i in want:
		keep[ch] = true
	for ch: Vector2i in _chunks.keys():
		if not keep.has(ch):
			unload_chunk(ch)
	var built := 0
	for ch: Vector2i in want:
		if built >= budget:
			break
		if not _chunks.has(ch):
			load_chunk(ch)
			built += 1


func load_chunk(ch: Vector2i) -> void:
	if _chunks.has(ch):
		return
	var info := {"objs": [], "dets": [], "fx": null, "lights": null}
	_chunks[ch] = info
	_batching = true
	for x in range(ch.x * CHUNK, ch.x * CHUNK + CHUNK):
		for y in range(ch.y * CHUNK, ch.y * CHUNK + CHUNK):
			var c := Vector2i(x, y)
			if world.tiles.has(c):
				refresh_column(c)
	_batching = false
	for sv: StripView in _batch:
		sv.refresh()
	_batch.clear()
	if show_objects:
		for o: Dictionary in world.objects:
			if chunk_of(_cell_of(o, false)) == ch:
				refresh_object(o)
				info["objs"].append(str(o["id"]))
	if show_details:
		for d: Dictionary in world.details:
			if chunk_of(_cell_of(d, true)) == ch:
				refresh_detail(d)
				info["dets"].append(str(d["id"]))
	_build_chunk_particles(ch)
	_build_chunk_lights(ch)
	if cables:
		cables.mark_dirty()


func unload_chunk(ch: Vector2i) -> void:
	var info: Dictionary = _chunks.get(ch, {})
	if info.is_empty():
		return
	_chunks.erase(ch)
	for key: Vector3i in _columns.keys():
		if key.y == ch.x and key.z == ch.y:
			(_columns[key] as Node).queue_free()
			_columns.erase(key)
	for id: String in info["objs"]:
		var n: WorldSprite = _obj_nodes.get(id)
		if n and not _chunks.has(chunk_of(_cell_of(n.data, false))):
			n.queue_free()
			_obj_nodes.erase(id)
	for id: String in info["dets"]:
		var n2: WorldSprite = _detail_nodes.get(id)
		if n2 and not _chunks.has(chunk_of(_cell_of(n2.data, true))):
			n2.queue_free()
			_detail_nodes.erase(id)
	for k: String in ["fx", "lights"]:
		if info[k] is Node:
			(info[k] as Node).queue_free()
	if cables:
		cables.mark_dirty()


func loaded_chunks() -> Array:
	return _chunks.keys()


## Top-tile colour of a tile id (minimap + streaming overview).
static var _tile_colors: Dictionary = {}


static func tile_color(tile_id: String) -> Color:
	if _tile_colors.has(tile_id):
		return _tile_colors[tile_id]
	var col := Color(str(ContentDB.terrain.get(WorldMap.terrain_of(tile_id), {}).get("color", "#444455")))
	var frames := tile_frames(tile_id)
	if not frames.is_empty():
		var img: Image = (frames[0] as Texture2D).get_image()
		if img:
			if img.is_compressed():
				img = img.duplicate()
				img.decompress()
			# Average a few points across the top face.
			var r := fit_rect(frames[0])
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


## One pixel per column, skewed onto the ground plane: the whole map at a
## glance under the streamed chunks (heights shade lighter / darker).
class LodLayer extends Node2D:
	var renderer: WorldRenderer
	var _img: Image
	var _tex: ImageTexture
	var _dirty: Dictionary = {}

	func rebuild() -> void:
		var w := renderer.world
		_img = Image.create(maxi(w.width, 1), maxi(w.depth, 1), false, Image.FORMAT_RGBA8)
		_img.fill(Color(0, 0, 0, 0))
		for cell: Vector2i in w.tiles:
			_paint(cell)
		_tex = ImageTexture.create_from_image(_img)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Pixel (x, y) → the diamond of cell (x, y) on layer 0.
		transform = Transform2D(Vector2(w.tile_width * 0.5, w.tile_height * 0.5), Vector2(-w.tile_width * 0.5, w.tile_height * 0.5), w.to_screen(Vector2(-0.5, -0.5), 0))
		_dirty.clear()
		set_process(false)
		queue_redraw()

	func _paint(cell: Vector2i) -> void:
		var w := renderer.world
		if not w.in_bounds(cell):
			return
		if not w.tiles.has(cell):
			_img.set_pixelv(cell, Color(0, 0, 0, 0))
			return
		var c := WorldRenderer.tile_color(w.top_tile(cell))
		var h := w.top_z(cell)
		c = c.lightened(clampf(h * 0.04, 0.0, 0.5)) if h >= 0 else c.darkened(clampf(-h * 0.08, 0.0, 0.6))
		_img.set_pixelv(cell, c.darkened(0.25))

	## An edited column: repainted on the next frame (batched).
	func mark(cell: Vector2i) -> void:
		if _img == null:
			return
		_dirty[cell] = true
		set_process(true)

	func _ready() -> void:
		set_process(false)

	func _process(_d: float) -> void:
		if _tex == null:
			set_process(false)
			return
		for c: Vector2i in _dirty:
			_paint(c)
		_dirty.clear()
		_tex.update(_img)
		set_process(false)
		queue_redraw()

	func _draw() -> void:
		if _tex:
			draw_texture(_tex, Vector2.ZERO)


class StripView extends Node2D:
	var renderer: WorldRenderer
	var key: Vector3i
	var cells: Dictionary = {}  # Vector2i -> true
	var _animated: bool = false

	func refresh() -> void:
		var w := renderer.world
		z_index = key.x * 2
		_animated = false
		for c: Vector2i in cells:
			for e: Array in w.stack_at(c):
				if WorldRenderer.tile_frames(str(e[1])).size() > 1:
					_animated = true
					break
			if _animated:
				break
		set_process(_animated)
		queue_redraw()

	func _process(_d: float) -> void:
		queue_redraw()
		if _animated:
			return
		for c: Vector2i in cells:
			if renderer.is_popping(c):
				return
		set_process(false)

	func _draw() -> void:
		var w := renderer.world
		var phase := 0.0  # water frames stay in sync across the sea
		for cell: Vector2i in cells:
			var stack := w.stack_at(cell)
			if stack.is_empty():
				continue
			var top_z := int(stack[stack.size() - 1][0])
			var cut := renderer.cutaway_alpha(w.to_screen(Vector2(cell), top_z), key.x, top_z)
			for e: Array in stack:
				var z := int(e[0])
				var opts: Dictionary = e[2] if e.size() > 2 and e[2] is Dictionary else {}
				var a := (1.0 if z <= renderer.dim_above else 0.18) * (cut if z >= renderer.cutaway_z else 1.0)
				var at := w.to_screen(Vector2(cell), z)
				var t := renderer.pop_progress(cell, z)
				if t < 1.0:
					# Drop in from above with a little overshoot.
					var k := 1.0 - t
					at.y -= w.height_step * 1.4 * k * k - sin(t * PI) * 3.0
					a *= 0.35 + 0.65 * t
				WorldRenderer.draw_tile(self, w, str(e[1]), at, a, phase, opts)


## A detail decal or an object sprite (static, sheet-animated or frame list).
class WorldSprite extends Node2D:
	var renderer: WorldRenderer
	var data: Dictionary
	var is_detail: bool = false
	var selected: bool = false
	var _frames: Array = []  # Texture2D or AtlasTexture
	var _anim: Dictionary = {}
	var _rect: Rect2
	var _foot: int = 1
	var _clip: Dictionary = {}  # LatticeClip (Grok building/prop animation), if the asset is one
	var _overlay: Dictionary = {}
	var _screen: Signage.ScreenQuad
	var _screen_light: NeonLight

	func refresh() -> void:
		var w := renderer.world
		_frames.clear()
		_clip = {}
		_overlay = {}
		var asset := str(data.get("asset", ""))
		if asset.ends_with(".json") and LatticeClip.is_clip(asset):
			_clip = LatticeClip.load_clip(asset)
			if _clip.get("ok", false) and str(_clip["overlay"]) != "":
				_overlay = LatticeClip.load_clip(str(_clip["overlay"]))
		_anim = data.get("anim") if data.get("anim") is Dictionary else {}
		var frame_paths: Array = _anim.get("frames", [])
		if frame_paths.size() > 1:
			for p: String in frame_paths:
				var t := ForgeStore.load_texture(p)
				if t:
					_frames.append(t)
		elif not _clip.get("ok", false):
			var tex := ForgeStore.load_texture(str(data.get("asset", "")))
			if tex:
				var hf := maxi(int(_anim.get("hframes", 1)), 1)
				var vf := maxi(int(_anim.get("vframes", 1)), 1)
				if hf * vf > 1:
					var fw := tex.get_width() / hf
					var fh := tex.get_height() / vf
					for i in hf * vf:
						var at := AtlasTexture.new()
						at.atlas = tex
						at.region = Rect2((i % hf) * fw, (i / hf) * fh, fw, fh)
						_frames.append(at)
				else:
					_frames.append(tex)
		var z := float(data.get("z", 0))
		var cell_f: Vector2
		if is_detail:
			var p: Array = data.get("pos", [0, 0])
			cell_f = Vector2(float(p[0]), float(p[1]))
		else:
			var c: Array = data.get("cell", [0, 0])
			cell_f = Vector2(float(c[0]), float(c[1]))
		# Sort by the front corner; centre the art on the whole footprint.
		var order := int(floor(cell_f.x + 0.5)) + int(floor(cell_f.y + 0.5))
		_foot = 1 if is_detail else WorldMap.footprint(data)
		if _foot > 1:
			cell_f -= Vector2(_foot - 1, _foot - 1) * 0.5
		var off: Array = data.get("offset", [0, 0])
		position = w.to_screen(cell_f, z) + Vector2(float(off[0]), float(off[1]))
		z_index = order * 2 + 1
		set_process(_frames.size() > 1 or bool(_clip.get("ok", false)))
		_refresh_screen()
		queue_redraw()

	## Living signage: a screen quad (and its glow) if the object has one.
	func _refresh_screen() -> void:
		var scr: Variant = data.get("screen")
		if not (scr is Dictionary) or renderer.signage == null:
			if _screen:
				_screen.queue_free()
				_screen = null
			if _screen_light:
				_screen_light.queue_free()
				_screen_light = null
			return
		if _screen == null:
			_screen = Signage.ScreenQuad.new()
			add_child(_screen)
			_screen_light = NeonLight.new()
			_screen_light.texture = WorldRenderer.light_texture()
			_screen_light.blend_mode = Light2D.BLEND_MODE_ADD
			_screen_light.flicker = 0.05
			add_child(_screen_light)
		var feed := str(scr.get("feed", "news"))
		_screen.setup(scr, float(absi(hash(str(data.get("id", "")))) % 100) / 10.0)
		_screen.tex = renderer.signage.channel(feed, str(scr.get("text", ""))).get_texture()
		_screen_light.color = Signage.FEED_COLORS.get(feed, Color.WHITE)
		_screen_light.base_energy = 0.55 * float(scr.get("bright", 1.6)) / 1.6
		_screen_light.energy = _screen_light.base_energy
		_screen_light.texture_scale = 0.7 * renderer.world.tile_width / 128.0

	## Corners follow the sprite's visible box (set while drawing).
	func _place_screen() -> void:
		if _screen == null or _rect.size.x <= 1.0:
			return
		var corners: Array = data["screen"].get("corners", Signage.DEFAULT_CORNERS)
		var pts := PackedVector2Array()
		var flip := bool(data.get("flip", false))
		for c: Variant in corners:
			var p := _rect.position + Vector2(float(c[0]), float(c[1])) * _rect.size
			pts.append(Vector2(-p.x, p.y) if flip else p)
		if pts != _screen.points:
			_screen.points = pts
			_screen.queue_redraw()
			var mid := Vector2.ZERO
			for p in pts:
				mid += p
			_screen_light.position = mid / maxf(pts.size(), 1.0) + Vector2(0, renderer.world.tile_height * 0.4)
		_screen_light.visible = renderer.show_lighting

	## Per-instance clock offset: the clip's own seed plus this object's id.
	func _clip_phase() -> float:
		return float(_clip.get("phase", 0.0)) + float(absi(hash(str(data.get("id", "")))) % 997) / 97.0

	func _draw_clip() -> void:
		var w := renderer.world
		var sc := float(data.get("scale", 1.0))
		var anchor: Vector2 = _clip["anchor"]
		var cell: Vector2 = _clip["cell"]
		var tint := Color(str(data.get("tint", "#ffffff")))
		var base := Vector2(0, w.tile_height * 0.5 * _foot)  # anchor = front vertex of the footprint (Lattice convention)
		_rect = Rect2(base - anchor * sc, cell * sc)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if bool(data.get("flip", false)) else 1, 1))
		var t := WorldRenderer.now()
		var i := LatticeClip.frame_at(_clip, t, _clip_phase())
		draw_texture_rect_region(_clip["tex"], _rect, (_clip["rects"] as Array)[i], tint)
		if _overlay.get("ok", false):
			var j := LatticeClip.frame_at(_overlay, t, _clip_phase())
			draw_texture_rect_region(_overlay["tex"], _rect, (_overlay["rects"] as Array)[j], tint)
		draw_set_transform(Vector2.ZERO)
		var bb: Array = _clip.get("bbox", [0, 0, cell.x, cell.y])
		_rect = Rect2(base - anchor * sc + Vector2(float(bb[0]), float(bb[1])) * sc, Vector2(float(bb[2]) - float(bb[0]), float(bb[3]) - float(bb[1])) * sc)
		_place_screen()
		if selected:
			draw_rect(_rect.grow(3), Color(0.3, 2.0, 1.0), false, 2.0)

	func _process(_d: float) -> void:
		queue_redraw()

	func _current() -> Texture2D:
		if _frames.is_empty():
			return null
		if _frames.size() == 1:
			return _frames[0]
		# Every instance runs on its own clock (phase + ±12% speed) so a street of
		# animated buildings never blinks in lockstep. "sync": true opts out.
		var fps := float(_anim.get("fps", 8))
		var phase := 0.0
		var mode := str(_anim.get("mode", "loop"))
		if not bool(_anim.get("sync", false)) and mode != "once":
			var h := absi(hash(str(data.get("id", ""))))
			fps *= 1.0 + (float(h % 241) / 240.0 - 0.5) * 0.24 * float(_anim.get("speed_jitter", 1.0))
			phase = float(h % 997) / 997.0 * float(_frames.size()) / maxf(fps, 0.01)
			if mode == "random_start":
				mode = "loop"
		return _frames[SheetSprite.frame_at(WorldRenderer.now(), _frames.size(), fps, mode, phase)]

	## X-ray: fade when this sprite stands in front of the cutaway focus.
	func apply_cutaway() -> void:
		var a := 1.0
		if renderer.cutaway_focus != Vector2.INF and (z_index - 1) / 2 > renderer.cutaway_order:
			if Rect2(position + _rect.position, _rect.size).grow(6).has_point(renderer.cutaway_focus):
				a = 0.3
		modulate.a = a

	func _draw() -> void:
		if _clip.get("ok", false):
			_draw_clip()
			return
		var tex := _current()
		var w := renderer.world
		var sc := float(data.get("scale", 1.0))
		var flip := bool(data.get("flip", false))
		var tint := Color(str(data.get("tint", "#ffffff")))
		if tex == null and data.get("light") is Dictionary and not renderer.editor_markers:
			_rect = Rect2()
			return
		if tex == null and data.get("light") is Dictionary:
			# Lights have no art: a glowing bulb in their colour (editor marker).
			var lc := Color(str(data["light"].get("color", "#ffffff")))
			var lift := Vector2(0, -w.height_step * float(data["light"].get("height", 1.0)))
			_rect = Rect2(lift - Vector2(14, 14), Vector2(28, 28))
			draw_line(Vector2.ZERO, lift, Color(lc, 0.5), 1.5)
			draw_circle(lift, 11, Color(lc.r * 2.0, lc.g * 2.0, lc.b * 2.0, 0.35))
			draw_circle(lift, 6, Color(lc.r * 2.5, lc.g * 2.5, lc.b * 2.5))
			if selected:
				draw_rect(_rect.grow(3), Color(0.3, 2.0, 1.0), false, 2.0)
			return
		if tex == null and str(data.get("asset", "")) == "":
			# No art on purpose: hidden loot / triggers. Invisible in game, a
			# dashed marker in the editor so you can find (and move) it.
			_rect = Rect2(-14, -30, 28, 30)
			if renderer.editor_markers:
				draw_rect(_rect, Color(2.0, 1.6, 0.3, 0.8), false, 1.5)
				draw_string(NeonTheme.mono(), Vector2(-5, -10), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(2.0, 1.6, 0.3))
				if selected:
					draw_rect(_rect.grow(3), Color(0.3, 2.0, 1.0), false, 2.0)
			return
		if tex == null:
			# Missing art: a readable placeholder instead of nothing.
			_rect = Rect2(-16, -40, 32, 40)
			draw_rect(_rect, Color(1.6, 0.4, 1.2, 0.5))
			draw_rect(_rect, Color(1.6, 0.4, 1.2), false, 2.0)
			return
		var size := tex.get_size() * sc
		if is_detail:
			# Decals lie on the tile: fitted to the tile width, centred on the face.
			var fit := size * (w.tile_width / maxf(tex.get_width(), 1.0))
			_rect = Rect2(-fit * 0.5, fit)
			draw_set_transform(Vector2.ZERO, deg_to_rad(float(data.get("rot", 0.0))), Vector2(-1 if flip else 1, 1))
			draw_texture_rect(tex, _rect, false, tint)
			draw_set_transform(Vector2.ZERO)
		else:
			# Objects stand on the tile: the bottom-centre of their visible
			# pixels (transparent margins ignored) sits on the tile centre.
			var used := WorldRenderer.fit_rect(tex)
			var vis := used.size * sc
			_rect = Rect2(Vector2(-vis.x * 0.5, -vis.y + w.tile_height * (0.5 * _foot - 0.25)), vis)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if flip else 1, 1))
			draw_texture_rect_region(tex, _rect, used, tint)
			draw_set_transform(Vector2.ZERO)
			_place_screen()
		if selected:
			draw_rect(_rect.grow(3), Color(0.3, 2.0, 1.0), false, 2.0)

	func hit(p: Vector2) -> bool:
		return _rect.has_point(p - position)


# --- Lighting ------------------------------------------------------------------

static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 256
		gt.height = 256
		_light_tex = gt
	return _light_tex


func rebuild_lighting() -> void:
	if _lights_root == null:
		return
	for c in _lights_root.get_children():
		_lights_root.remove_child(c)
		c.queue_free()
	var amb := Color(world.ambient) if world.ambient != "" else Color.WHITE
	_ambient.color = amb if show_lighting else Color.WHITE
	_ambient.visible = show_lighting
	if not show_lighting:
		return
	if streaming:
		for ch: Vector2i in _chunks:
			_chunks[ch]["lights"] = null
			_build_chunk_lights(ch)
		return
	_add_lights(world.objects, _lights_root)


func _build_chunk_lights(ch: Vector2i) -> void:
	var info: Dictionary = _chunks[ch]
	if info.get("lights") is Node:
		(info["lights"] as Node).queue_free()
	var root := Node2D.new()
	_lights_root.add_child(root)
	info["lights"] = root
	if not show_lighting:
		return
	var objs: Array = []
	for id: String in info["objs"]:
		var n: WorldSprite = _obj_nodes.get(id)
		if n:
			objs.append(n.data)
	_add_lights(objs, root)


func _add_lights(objects: Array, parent: Node) -> void:
	# Animated buildings light their surroundings from their own beacons/windows.
	for o2: Dictionary in objects:
		var node: WorldSprite = _obj_nodes.get(str(o2.get("id", "")))
		if node == null or not node._clip.get("ok", false) or not bool(o2.get("clip_lights", true)):
			continue
		var sc := float(o2.get("scale", 1.0))
		var flip := -1.0 if bool(o2.get("flip", false)) else 1.0
		var base := Vector2(0, world.tile_height * 0.5 * node._foot)
		for lp: Dictionary in LatticeClip.light_points(node._clip, int(o2.get("clip_light_count", 5))):
			var rel: Vector2 = (lp["pos"] - node._clip["anchor"]) * sc
			var cl := NeonLight.new()
			cl.texture = light_texture()
			cl.color = lp["color"]
			cl.base_energy = 0.75
			cl.energy = 0.75
			cl.flicker = 0.06
			cl.texture_scale = 0.8 * world.tile_width / 128.0
			cl.blend_mode = Light2D.BLEND_MODE_ADD
			cl.position = node.position + base + Vector2(rel.x * flip, rel.y)
			cl.seed_phase = float(hash(str(o2.get("id", "")) + str(lp["pos"])) % 1000) / 100.0
			parent.add_child(cl)
	for o: Dictionary in objects:
		if not (o.get("light") is Dictionary):
			continue
		var l: Dictionary = o["light"]
		var pl := NeonLight.new()
		pl.texture = light_texture()
		pl.color = Color(str(l.get("color", "#ff3fb4")))
		pl.base_energy = float(l.get("energy", 1.2))
		pl.energy = pl.base_energy
		pl.flicker = float(l.get("flicker", 0.0))
		# A 256px texture: scale so its radius covers `radius` tiles on screen.
		pl.texture_scale = float(l.get("radius", 3.0)) * world.tile_width / 128.0
		pl.blend_mode = Light2D.BLEND_MODE_ADD
		var c: Array = o.get("cell", [0, 0])
		var off: Array = o.get("offset", [0, 0])
		pl.position = world.to_screen(Vector2(float(c[0]), float(c[1])), float(o.get("z", 0)) + float(l.get("height", 1.0))) + Vector2(float(off[0]), float(off[1]))
		pl.seed_phase = float(hash(str(o.get("id", ""))) % 1000) / 100.0
		parent.add_child(pl)


## Point light with optional neon flicker (buzzing tubes, fires).
class NeonLight extends PointLight2D:
	var base_energy: float = 1.2
	var flicker: float = 0.0
	var seed_phase: float = 0.0

	func _ready() -> void:
		set_process(flicker > 0.0)

	func _process(_d: float) -> void:
		var t := WorldRenderer.now() + seed_phase
		var wobble := sin(t * 13.0) * 0.5 + sin(t * 31.0) * 0.3 + sin(t * 3.0) * 0.2
		var dropout := 1.0
		if flicker > 0.6 and fmod(t * 1.7, 2.3) < flicker * 0.25:
			dropout = 0.15  # a dying tube cuts out now and then
		energy = maxf(base_energy * (1.0 + wobble * flicker * 0.35) * dropout, 0.0)


## Short-lived editor feedback: rings when tiles land or vanish, floating text.
class FxLayer extends Node2D:
	var renderer: WorldRenderer
	var _items: Array = []  # {kind, at, color, t0, text}

	func add_ring(at: Vector2, color: Color) -> void:
		_items.append({"kind": "ring", "at": at, "color": color, "t0": WorldRenderer.now()})
		if _items.size() > 160:
			_items.pop_front()
		set_process(true)

	func add_text(at: Vector2, text: String, color: Color) -> void:
		_items.append({"kind": "text", "at": at, "color": color, "t0": WorldRenderer.now(), "text": text})
		set_process(true)

	func _process(_d: float) -> void:
		var now := WorldRenderer.now()
		_items = _items.filter(func(i: Dictionary) -> bool: return now - float(i["t0"]) < (0.9 if i["kind"] == "text" else 0.35))
		queue_redraw()
		if _items.is_empty():
			set_process(false)

	func _draw() -> void:
		var w := renderer.world
		var now := WorldRenderer.now()
		for i: Dictionary in _items:
			var t := (now - float(i["t0"]))
			var col: Color = i["color"]
			if i["kind"] == "ring":
				var k := t / 0.35
				var r := 0.55 + k * 0.6
				var at: Vector2 = i["at"]
				var hw := w.tile_width * 0.5 * r
				var hh := w.tile_height * 0.5 * r
				var pts := PackedVector2Array([at + Vector2(0, -hh), at + Vector2(hw, 0), at + Vector2(0, hh), at + Vector2(-hw, 0), at + Vector2(0, -hh)])
				draw_polyline(pts, Color(col, 1.0 - k), 2.5 * (1.0 - k) + 0.5)
			else:
				var k2 := t / 0.9
				draw_string(NeonTheme.mono(), (i["at"] as Vector2) + Vector2(0, -30 * k2), str(i["text"]), HORIZONTAL_ALIGNMENT_CENTER, 220, 18, Color(col, 1.0 - k2 * k2))
