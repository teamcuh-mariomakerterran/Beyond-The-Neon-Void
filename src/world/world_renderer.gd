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
var _lights_root: Node2D
var _fx: FxLayer
var _ambient: CanvasModulate
## Preview the map's ambient tint + neon lights (on in game, toggleable in the editor).
var show_lighting: bool = true
## Draw editor-only markers (light bulbs) — the painter turns this on.
var editor_markers: bool = false
## cell -> {z: time placed}, for the drop-in animation.
var _pops: Dictionary = {}

const POP_TIME := 0.22
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
	for n: Node2D in [_columns_root, _details_root, _objects_root, _particles_root, _lights_root]:
		add_child(n)
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
	for cell: Vector2i in world.tiles:
		refresh_column(cell)
	rebuild_details()
	rebuild_objects()
	rebuild_particles()
	rebuild_lighting()


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


## Editor juice: the tile at (cell, z) drops in and a ring flashes.
func pop(cell: Vector2i, z: int, erase: bool = false, ring: bool = true) -> void:
	if not erase:
		if not _pops.has(cell):
			_pops[cell] = {}
		_pops[cell][z] = now()
		var cv: ColumnView = _columns.get(cell)
		if cv:
			cv.set_process(true)
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
		if not _animated and not renderer.is_popping(cell):
			set_process(false)

	func _draw() -> void:
		var w := renderer.world
		var phase := 0.0  # water frames stay in sync across the sea
		for e: Array in w.stack_at(cell):
			var z := int(e[0])
			var a := 1.0 if z <= renderer.dim_above else 0.18
			var at := w.to_screen(Vector2(cell), z)
			var t := renderer.pop_progress(cell, z)
			if t < 1.0:
				# Drop in from above with a little overshoot.
				var k := 1.0 - t
				at.y -= w.height_step * 1.4 * k * k - sin(t * PI) * 3.0
				a *= 0.35 + 0.65 * t
			WorldRenderer.draw_tile(self, w, str(e[1]), at, a, phase)


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
		# Sort by the front corner; centre the art on the whole footprint.
		var order := int(floor(cell_f.x + 0.5)) + int(floor(cell_f.y + 0.5))
		_foot = 1 if is_detail else WorldMap.footprint(data)
		if _foot > 1:
			cell_f -= Vector2(_foot - 1, _foot - 1) * 0.5
		var off: Array = data.get("offset", [0, 0])
		position = w.to_screen(cell_f, z) + Vector2(float(off[0]), float(off[1]))
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
	for o: Dictionary in world.objects:
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
		_lights_root.add_child(pl)


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
