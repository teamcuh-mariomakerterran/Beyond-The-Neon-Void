class_name WorldRenderer
extends Node2D
## Draws a WorldMap: one ColumnView per occupied column (its whole tile stack),
## detail decals, objects (static or animated) and painted particle volumes.
## Used by the Neon Forge World Painter (live), exploration and battles, so what
## you paint is exactly what plays.
##
## Draw order follows the battle convention: column = draw_order*2, anything
## standing on a column (details, objects, units) = draw_order*2 + 1.
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

var _columns: Dictionary = {}  # Vector2i -> ColumnView
var _obj_nodes: Dictionary = {}  # id -> WorldSprite
var _detail_nodes: Dictionary = {}
var _particle_nodes: Dictionary = {}  # "preset|z" -> Node2D
var _columns_root: Node2D
var _details_root: Node2D
var _objects_root: Node2D
var _particles_root: Node2D

static var _fit_cache: Dictionary = {}


func _ready() -> void:
	_columns_root = Node2D.new()
	_details_root = Node2D.new()
	_objects_root = Node2D.new()
	_particles_root = Node2D.new()
	for n: Node2D in [_columns_root, _details_root, _objects_root, _particles_root]:
		add_child(n)
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
	for root: Node2D in [_columns_root, _details_root, _objects_root, _particles_root]:
		for c in root.get_children():
			c.queue_free()
	_columns.clear()
	_obj_nodes.clear()
	_detail_nodes.clear()
	_particle_nodes.clear()
	for cell: Vector2i in world.tiles:
		refresh_column(cell)
	rebuild_details()
	rebuild_objects()
	rebuild_particles()


func refresh_column(cell: Vector2i) -> void:
	var cv: ColumnView = _columns.get(cell)
	if not world.tiles.has(cell):
		if cv:
			cv.queue_free()
			_columns.erase(cell)
		return
	if cv == null:
		cv = ColumnView.new()
		cv.renderer = self
		cv.cell = cell
		_columns[cell] = cv
		_columns_root.add_child(cv)
	cv.refresh()


func refresh_columns(cells: Array) -> void:
	for c: Vector2i in cells:
		refresh_column(c)


func redraw_all_columns() -> void:
	for cv: ColumnView in _columns.values():
		cv.queue_redraw()


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
	var tex := ForgeStore.load_texture(asset)
	if tex == null:
		return 1.0
	var used := fit_rect(tex)
	var span := 2.2 if kind in ["structure", "location"] else 0.9
	var target := w.tile_width * span
	return snappedf(target / used.size.x, 0.001) if used.size.x > target * 1.25 else 1.0


## Draws one tile whose top-face centre is `center`. `alpha` for ghosts/fading.
static func draw_tile(ci: CanvasItem, w: WorldMap, tile_id: String, center: Vector2, alpha: float = 1.0, phase: float = 0.0) -> void:
	var frames := tile_frames(tile_id)
	if frames.is_empty():
		_draw_color_block(ci, w, tile_id, center, alpha)
		return
	var tex: Texture2D = frames[0]
	if frames.size() > 1:
		tex = frames[SheetSprite.frame_at(now(), frames.size(), tile_fps(tile_id), "loop", phase)]
	var used := fit_rect(tex)
	var s := w.tile_width / used.size.x
	var north := center + Vector2(-w.tile_width * 0.5, -w.tile_height * 0.5)
	ci.draw_texture_rect_region(tex, Rect2(north, used.size * s), used, Color(1, 1, 1, alpha))


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
		refresh_detail(d)


func refresh_detail(d: Dictionary) -> void:
	var node: WorldSprite = _detail_nodes.get(str(d["id"]))
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


func refresh_object(o: Dictionary) -> void:
	var node: WorldSprite = _obj_nodes.get(str(o["id"]))
	if node == null:
		node = WorldSprite.new()
		node.renderer = self
		_objects_root.add_child(node)
		_obj_nodes[str(o["id"])] = node
	node.data = o
	node.visible = show_objects and not bool(o.get("hidden", false))
	node.refresh()


func remove_object(o: Dictionary) -> void:
	var node: Node = _obj_nodes.get(str(o["id"]))
	if node:
		node.queue_free()
		_obj_nodes.erase(str(o["id"]))


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
	var groups := world.particle_groups()
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
		_particles_root.add_child(node)
		_particle_nodes[k] = node


class ColumnView extends Node2D:
	var renderer: WorldRenderer
	var cell: Vector2i
	var _animated: bool = false

	func refresh() -> void:
		var w := renderer.world
		position = Vector2.ZERO
		z_index = (cell.x + cell.y) * 2
		_animated = false
		for e: Array in w.stack_at(cell):
			if WorldRenderer.tile_frames(str(e[1])).size() > 1:
				_animated = true
		set_process(_animated)
		queue_redraw()

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := renderer.world
		var phase := 0.0  # water frames stay in sync across the sea
		for e: Array in w.stack_at(cell):
			var z := int(e[0])
			var a := 1.0 if z <= renderer.dim_above else 0.18
			WorldRenderer.draw_tile(self, w, str(e[1]), w.to_screen(Vector2(cell), z), a, phase)


## A detail decal or an object sprite (static, sheet-animated or frame list).
class WorldSprite extends Node2D:
	var renderer: WorldRenderer
	var data: Dictionary
	var is_detail: bool = false
	var selected: bool = false
	var _frames: Array = []  # Texture2D or AtlasTexture
	var _anim: Dictionary = {}
	var _rect: Rect2

	func refresh() -> void:
		var w := renderer.world
		_frames.clear()
		_anim = data.get("anim") if data.get("anim") is Dictionary else {}
		var frame_paths: Array = _anim.get("frames", [])
		if frame_paths.size() > 1:
			for p: String in frame_paths:
				var t := ForgeStore.load_texture(p)
				if t:
					_frames.append(t)
		else:
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
		var off: Array = data.get("offset", [0, 0])
		position = w.to_screen(cell_f, z) + Vector2(float(off[0]), float(off[1]))
		var order := int(floor(cell_f.x + 0.5)) + int(floor(cell_f.y + 0.5))
		z_index = order * 2 + 1
		set_process(_frames.size() > 1)
		queue_redraw()

	func _process(_d: float) -> void:
		queue_redraw()

	func _current() -> Texture2D:
		if _frames.is_empty():
			return null
		if _frames.size() == 1:
			return _frames[0]
		var phase := float(hash(str(data.get("id", ""))) % 100) / 100.0 if str(_anim.get("mode", "loop")) == "random_start" else 0.0
		return _frames[SheetSprite.frame_at(WorldRenderer.now(), _frames.size(), float(_anim.get("fps", 8)), str(_anim.get("mode", "loop")), phase)]

	func _draw() -> void:
		var tex := _current()
		var w := renderer.world
		var sc := float(data.get("scale", 1.0))
		var flip := bool(data.get("flip", false))
		var tint := Color(str(data.get("tint", "#ffffff")))
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
			_rect = Rect2(Vector2(-vis.x * 0.5, -vis.y + w.tile_height * 0.25), vis)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if flip else 1, 1))
			draw_texture_rect_region(tex, _rect, used, tint)
			draw_set_transform(Vector2.ZERO)
		if selected:
			draw_rect(_rect.grow(3), Color(0.3, 2.0, 1.0), false, 2.0)

	func hit(p: Vector2) -> bool:
		return _rect.has_point(p - position)
