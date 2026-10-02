class_name WorldMap
extends RefCounted
## Format-2 map: sparse stacks of tiles per column (any number of layers, gaps
## allowed, negative layers dig below ground), free-placed detail decals,
## painted particle volumes, objects (props, structures, characters, location
## links) and gameplay overrides. See docs/design/WORLD_FORMAT.md.
##
## Pure data — the Forge painter, WorldRenderer, exploration and battles all
## share it. `to_grid()` flattens it into the IsometricGrid battles run on.

const KINDS: Array[String] = ["world", "city", "hub", "interior", "encounter", "event"]
const MIN_Z := -16
const MAX_Z := 48

var id: String = "new_map"
var name: String = "New Map"
var kind: String = "encounter"
var width: int = 24
var depth: int = 24
var tile_width: float = 128.0
var tile_height: float = 64.0
var height_step: float = 32.0
var music: String = ""
## Ambient tint for the whole map (CanvasModulate), e.g. "#4a4f86" for night.
var ambient: String = ""
## HD-2D post look: "" / "off" / an HD2DPost preset id, or {"preset": ..., overrides}.
var post: Variant = ""
## Vector2i -> Array of [z:int, tile_id:String], sorted by z ascending.
var tiles: Dictionary = {}
## Vector2i -> Array of [z:int, preset_id:String].
var particles: Dictionary = {}
var details: Array = []
var objects: Array = []
var spawns: Dictionary = {"player": [], "enemy": []}
## Vector2i -> {walkable, cover, blocks_los, cost}
var gameplay: Dictionary = {}
## Legacy v1 hidden-loot props, kept so old maps round-trip.
var legacy_props: Array = []
var _uid: int = 0


# --- Projection ------------------------------------------------------------

## Screen position of the centre of the top face of (cell, z).
func to_screen(cell: Vector2, z: float) -> Vector2:
	return Vector2((cell.x - cell.y) * tile_width * 0.5, (cell.x + cell.y) * tile_height * 0.5 - z * height_step)


## Inverse projection onto the horizontal plane at layer z (fractional cell).
func from_screen(p: Vector2, z: float) -> Vector2:
	var py := p.y + z * height_step
	var a := p.x / (tile_width * 0.5)
	var b := py / (tile_height * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


func pick_plane(p: Vector2, z: float) -> Vector2i:
	var f := from_screen(p, z)
	return Vector2i(roundi(f.x), roundi(f.y))


## Front-most column whose top face contains p. Returns [cell, z] or [].
func pick_top(p: Vector2) -> Array:
	var best: Array = []
	var best_key := -INF
	# Only columns whose projected x band contains p can match; scan them all
	# (maps are at most ~128² columns, and this runs once per mouse move).
	for cell: Vector2i in tiles:
		var stack: Array = tiles[cell]
		var z: int = stack[stack.size() - 1][0]
		var d := p - to_screen(Vector2(cell), z)
		if absf(d.x) / (tile_width * 0.5) + absf(d.y) / (tile_height * 0.5) <= 1.0:
			var key := float(cell.x + cell.y) * 1000.0 + z
			if key > best_key:
				best_key = key
				best = [cell, z]
	return best


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < depth


static func key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func parse_key(k: String) -> Vector2i:
	var parts := k.split(",")
	return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else Vector2i.ZERO


# --- Tiles -----------------------------------------------------------------

func stack_at(cell: Vector2i) -> Array:
	return tiles.get(cell, [])


func tile_at(cell: Vector2i, z: int) -> String:
	for e: Array in stack_at(cell):
		if int(e[0]) == z:
			return str(e[1])
	return ""


func tile_opts(cell: Vector2i, z: int) -> Dictionary:
	for e: Array in stack_at(cell):
		if int(e[0]) == z:
			return e[2] if e.size() > 2 and e[2] is Dictionary else {}
	return {}


func top_z(cell: Vector2i, fallback: int = 0) -> int:
	var s := stack_at(cell)
	return int(s[s.size() - 1][0]) if not s.is_empty() else fallback


func top_tile(cell: Vector2i) -> String:
	var s := stack_at(cell)
	return str(s[s.size() - 1][1]) if not s.is_empty() else ""


## `opts` (optional, stored as the 3rd entry): {"flip": bool, "tint": "#rrggbb",
## "ramp": "x+"|"x-"|"y+"|"y-" (slopes up toward that grid direction),
## "stairs": bool (draw the ramp as steps)}.
func set_tile(cell: Vector2i, z: int, tile_id: String, opts: Dictionary = {}) -> void:
	if not in_bounds(cell):
		return
	z = clampi(z, MIN_Z, MAX_Z)
	var s: Array = tiles.get(cell, [])
	for e: Array in s:
		if int(e[0]) == z:
			e[1] = tile_id
			if e.size() > 2:
				e.resize(2)
			if not opts.is_empty():
				e.append(opts)
			return
	s.append([z, tile_id] if opts.is_empty() else [z, tile_id, opts])
	s.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	tiles[cell] = s


func remove_tile(cell: Vector2i, z: int) -> bool:
	var s: Array = tiles.get(cell, [])
	for i in s.size():
		if int(s[i][0]) == z:
			s.remove_at(i)
			if s.is_empty():
				tiles.erase(cell)
			return true
	return false


# --- Particles ---------------------------------------------------------------

func set_particle(cell: Vector2i, z: int, preset: String) -> void:
	if not in_bounds(cell):
		return
	var s: Array = particles.get(cell, [])
	for e: Array in s:
		if int(e[0]) == z:
			e[1] = preset
			return
	s.append([z, preset])
	particles[cell] = s


func remove_particle(cell: Vector2i, z: int) -> bool:
	var s: Array = particles.get(cell, [])
	for i in s.size():
		if int(s[i][0]) == z:
			s.remove_at(i)
			if s.is_empty():
				particles.erase(cell)
			return true
	return false


## Groups painted particle cells by (preset, z) → {"preset|z": [cells]}.
func particle_groups() -> Dictionary:
	var out := {}
	for cell: Vector2i in particles:
		for e: Array in particles[cell]:
			var k := "%s|%d" % [e[1], int(e[0])]
			if not out.has(k):
				out[k] = []
			out[k].append(cell)
	return out


# --- Objects & details -------------------------------------------------------

func next_id(prefix: String) -> String:
	var taken := {}
	for o: Dictionary in objects + details:
		taken[str(o.get("id", ""))] = true
	while true:
		_uid += 1
		var candidate := "%s_%s_%d" % [prefix, id, _uid]
		if not taken.has(candidate):
			return candidate
	return ""


func add_object(asset: String, cell: Vector2i, z: int, kind_name: String = "prop") -> Dictionary:
	var o := {"id": next_id("obj"), "asset": asset, "cell": [cell.x, cell.y], "z": z, "offset": [0, 0],
		"scale": 1.0, "flip": false, "layer": 0, "kind": kind_name, "anim": null,
		"loot_item_id": "", "found_text": "", "empty_text": "", "dialog_npc": "", "location": null}
	objects.append(o)
	return o


func add_detail(asset: String, pos: Vector2, z: int) -> Dictionary:
	var d := {"id": next_id("dtl"), "asset": asset, "pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01)], "z": z,
		"scale": 1.0, "rot": 0.0, "flip": false, "tint": "#ffffff", "anim": null}
	details.append(d)
	return d


## Side length (cells) of the square an object stands on. Its `cell` is the
## FRONT corner; the footprint extends back (-x, -y). Structures and locations
## with art default to 2, everything else to 1.
static func footprint(o: Dictionary) -> int:
	if o.has("footprint"):
		return clampi(int(o["footprint"]), 1, 8)
	return 2 if str(o.get("kind", "")) in ["structure", "location"] and str(o.get("asset", "")) != "" else 1


static func footprint_cells(o: Dictionary) -> Array[Vector2i]:
	var a := Vector2i(int(o["cell"][0]), int(o["cell"][1]))
	var n := footprint(o)
	var out: Array[Vector2i] = []
	for i in n:
		for j in n:
			out.append(a - Vector2i(i, j))
	return out


## Distance (cells) from `cell` to the nearest tile of an object's footprint.
static func distance_to(o: Dictionary, cell: Vector2i) -> float:
	var best := INF
	for c in footprint_cells(o):
		best = minf(best, Vector2(c - cell).length())
	return best


func objects_at(cell: Vector2i) -> Array:
	return objects.filter(func(o: Dictionary) -> bool: return footprint_cells(o).has(cell))


func locations() -> Array:
	return objects.filter(func(o: Dictionary) -> bool: return o.get("location") is Dictionary)


# --- Serialisation -----------------------------------------------------------

func load_dict(d: Dictionary) -> void:
	id = str(d.get("id", id))
	name = str(d.get("name", id))
	kind = str(d.get("kind", "encounter"))
	width = int(d.get("width", 24))
	depth = int(d.get("depth", 24))
	music = str(d.get("music", ""))
	ambient = str(d.get("ambient", ""))
	post = d.get("post", "")
	spawns = d.get("spawns", {"player": [], "enemy": []}).duplicate(true)
	if not spawns.has("player"):
		spawns["player"] = []
	legacy_props = d.get("props", []).duplicate(true)
	tiles.clear()
	particles.clear()
	gameplay.clear()
	if int(d.get("format", 1)) >= 2:
		tile_width = float(d.get("tile_width", 128))
		tile_height = float(d.get("tile_height", tile_width * 0.5))
		height_step = float(d.get("height_step", tile_width * 0.25))
		var t: Dictionary = d.get("tiles", {})
		for k: String in t:
			var s: Array = []
			for e: Array in t[k]:
				if e.size() > 2 and e[2] is Dictionary and not (e[2] as Dictionary).is_empty():
					s.append([int(e[0]), str(e[1]), (e[2] as Dictionary).duplicate()])
				else:
					s.append([int(e[0]), str(e[1])])
			s.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
			tiles[parse_key(k)] = s
		var p: Dictionary = d.get("particles", {})
		for k: String in p:
			var s2: Array = []
			for e: Array in p[k]:
				s2.append([int(e[0]), str(e[1])])
			particles[parse_key(k)] = s2
		var g: Dictionary = d.get("gameplay", {})
		for k: String in g:
			gameplay[parse_key(k)] = g[k].duplicate()
		details = d.get("details", []).duplicate(true)
		objects = d.get("objects", []).duplicate(true)
	else:
		# v1: one terrain cell per column, height h. Terrain ids become tile ids
		# ("terrain:<id>") that the renderer draws from data/terrain.json.
		tile_width = float(d.get("tile_width", 64))
		tile_height = float(d.get("tile_height", 32))
		height_step = float(d.get("height_step", 16))
		for c: Dictionary in d.get("cells", []):
			var cell := Vector2i(int(c.get("x", 0)), int(c.get("y", 0)))
			var h := int(c.get("h", 0))
			var tid := "terrain:" + str(c.get("tile", "")) if str(c.get("tile", "")) != "" else "terrain:" + str(c.get("t", "concrete"))
			tiles[cell] = [[h, tid]]
			var over := {}
			for f in ["walkable", "cover", "blocks_los", "hazard"]:
				if c.has(f):
					over[f] = c[f]
			if c.has("cost"):
				over["cost"] = c["cost"]
			if not over.is_empty():
				gameplay[cell] = over
		details = []
		objects = []


func to_dict() -> Dictionary:
	var t := {}
	var cells: Array = tiles.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		t[key(cell)] = tiles[cell]
	var p := {}
	for cell: Vector2i in particles:
		p[key(cell)] = particles[cell]
	var g := {}
	for cell: Vector2i in gameplay:
		g[key(cell)] = gameplay[cell]
	var out := {"format": 2, "id": id, "name": name, "kind": kind, "width": width, "depth": depth,
		"tile_width": tile_width, "tile_height": tile_height, "height_step": height_step,
		"tiles": t, "details": details, "particles": p, "objects": objects,
		"spawns": spawns, "gameplay": g}
	if music != "":
		out["music"] = music
	if ambient != "":
		out["ambient"] = ambient
	if not (post is String and str(post) == ""):
		out["post"] = post
	if not legacy_props.is_empty():
		out["props"] = legacy_props
	return out


# --- Gameplay ----------------------------------------------------------------

## Terrain id (data/terrain.json) that governs a tile's gameplay rules.
static func terrain_of(tile_id: String) -> String:
	if tile_id.begins_with("terrain:"):
		return tile_id.substr(8)
	var tiles_db: Dictionary = ContentDB.get("tiles") if ContentDB.get("tiles") is Dictionary else {}
	return str(tiles_db.get(tile_id, {}).get("terrain", "concrete"))


## Flattens the top of every column into the battle grid. Empty columns are
## holes (not walkable).
func to_grid() -> IsometricGrid:
	var g := IsometricGrid.new()
	g.setup(width, depth)
	g.tile_width = tile_width
	g.tile_height = tile_height
	g.height_step = height_step
	for cell in g.all_cells():
		var c := g.get_cell(cell)
		if not tiles.has(cell):
			c.walkable = false
			c.terrain = "void"
			continue
		var top := top_tile(cell)
		c.height = clampi(top_z(cell), IsometricGrid.MIN_HEIGHT, IsometricGrid.MAX_HEIGHT)
		c.terrain = terrain_of(top)
		IsometricGrid.apply_terrain_defaults(c, ContentDB.terrain)
		if top.begins_with("terrain:"):
			c.tile_id = ""
		var over: Dictionary = gameplay.get(cell, {})
		if over.has("walkable"): c.walkable = bool(over["walkable"])
		if over.has("cover"): c.cover = int(over["cover"])
		if over.has("blocks_los"): c.blocks_los = bool(over["blocks_los"])
		if over.has("cost"): c.move_cost = int(over["cost"])
		if over.has("hazard"): c.hazard = str(over["hazard"])
	for o: Dictionary in objects:
		var kind_o := str(o.get("kind", ""))
		for oc in footprint_cells(o):
			var cell_o := g.get_cell(oc)
			if cell_o == null:
				continue
			if kind_o in ["structure", "location"]:
				cell_o.walkable = false
				cell_o.blocks_los = true
				cell_o.cover = IsometricGrid.COVER_FULL
			elif kind_o in ["prop", "loot"]:
				cell_o.prop_id = str(o["id"])
	return g


static func from_dict(d: Dictionary) -> WorldMap:
	var w := WorldMap.new()
	w.load_dict(d)
	return w
