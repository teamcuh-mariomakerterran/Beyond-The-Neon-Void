class_name ChunkStore
extends RefCounted
## Streams format-3 map chunks into a WorldMap (PROPOSED format, see
## docs/research/WORLD_MAP_FF8_FF9.md §2.2 / §3 and the open-world-tactics skill).
##
## Pure data, no nodes: load_into()/unload_from() edit WorldMap.tiles/particles/
## details, and return the cells that changed so WorldRenderer.refresh_columns()
## (or a future ChunkView) can redraw just those. Nothing here renders.
##
## Manifest = a normal format-2 map dict with "format": 3 and
##   "streaming": {"chunk_size": 32, "dir": "data/maps/<id>/chunks", "default_tile": "..."}
##   "chunks": {"cx,cy": {"variants": [{"flag": "story_flag", "file": "cx_cy_alt.json"}]}}
## Chunk file  = {"chunk": [cx, cy], "tiles": {"lx,ly": [[z, tile_id, opts?]]},
##                "particles": {"lx,ly": [[z, preset]]}, "details": [...]}
## A missing chunk file = all default_tile (ocean): leave the cells empty (holes are
## unwalkable in WorldMap.to_grid) and draw the ocean as one shader quad.
##
## Threading: read_chunk() only touches FileAccess + JSON, so it is safe to call from
## WorkerThreadPool; call load_into() (which mutates the WorldMap) on the main thread.

var chunk_size: int = 32
var dir: String = ""
var default_tile: String = ""
var width: int = 0
var depth: int = 0
## "cx,cy" -> manifest entry (variants)
var chunk_meta: Dictionary = {}
## Vector2i chunk -> Array[Vector2i] cells this chunk added
var loaded: Dictionary = {}
## Story-flag check used for chunk variants (defaults to GameManager).
var flag_check: Callable = func(flag: String) -> bool: return GameManager.check_story_flag(flag)


static func from_manifest(m: Dictionary) -> ChunkStore:
	var s := ChunkStore.new()
	var st: Dictionary = m.get("streaming", {})
	s.chunk_size = maxi(1, int(st.get("chunk_size", 32)))
	s.dir = _resolve_dir(str(st.get("dir", "")))
	s.default_tile = str(st.get("default_tile", ""))
	s.width = int(m.get("width", 0))
	s.depth = int(m.get("depth", 0))
	s.chunk_meta = (m.get("chunks", {}) as Dictionary).duplicate(true) if m.get("chunks") is Dictionary else {}
	return s


static func is_streamed(m: Dictionary) -> bool:
	return int(m.get("format", 1)) >= 3 and m.get("streaming") is Dictionary


static func _resolve_dir(d: String) -> String:
	if d.begins_with("res://") or d.begins_with("user://") or d.begins_with("/") or (d.length() > 1 and d[1] == ":"):
		return d
	return "res://" + d


func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / chunk_size), floori(float(cell.y) / chunk_size))


func chunk_count() -> Vector2i:
	return Vector2i(ceili(float(width) / chunk_size), ceili(float(depth) / chunk_size))


func in_range(c: Vector2i) -> bool:
	var n := chunk_count()
	return c.x >= 0 and c.y >= 0 and c.x < n.x and c.y < n.y


## File for a chunk, honouring story variants (first variant whose flag is set wins).
func chunk_path(c: Vector2i) -> String:
	var meta: Dictionary = chunk_meta.get("%d,%d" % [c.x, c.y], {})
	for v: Dictionary in meta.get("variants", []):
		if flag_check.call(str(v.get("flag", ""))):
			return dir.path_join(str(v.get("file", "")))
	return dir.path_join("%d_%d.json" % [c.x, c.y])


## Parsed chunk dict, or {} when the file is absent (default-tile chunk). Thread-safe.
func read_chunk(c: Vector2i) -> Dictionary:
	var p := chunk_path(c)
	if not FileAccess.file_exists(p):
		return {}
	var txt := FileAccess.get_file_as_string(p)
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


## Merges a chunk into the world. Returns the world cells that changed.
func load_into(world: WorldMap, c: Vector2i, data: Dictionary = {}) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	if loaded.has(c) or not in_range(c):
		return changed
	var d := data if not data.is_empty() else read_chunk(c)
	var origin := c * chunk_size
	var tiles: Dictionary = d.get("tiles", {})
	for k: String in tiles:
		var cell := origin + WorldMap.parse_key(k)
		var stack: Array = []
		for e: Array in tiles[k]:
			if e.size() > 2 and e[2] is Dictionary and not (e[2] as Dictionary).is_empty():
				stack.append([int(e[0]), str(e[1]), (e[2] as Dictionary).duplicate()])
			else:
				stack.append([int(e[0]), str(e[1])])
		stack.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
		world.tiles[cell] = stack
		changed.append(cell)
	var parts: Dictionary = d.get("particles", {})
	for k2: String in parts:
		var pc := origin + WorldMap.parse_key(k2)
		var ps: Array = []
		for e2: Array in parts[k2]:
			ps.append([int(e2[0]), str(e2[1])])
		world.particles[pc] = ps
	for det: Dictionary in d.get("details", []):
		var dd := det.duplicate(true)
		dd["_chunk"] = [c.x, c.y]
		world.details.append(dd)
	loaded[c] = changed
	return changed


## Removes a chunk's cells from the world. Returns the cells that changed.
func unload_from(world: WorldMap, c: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not loaded.has(c):
		return cells
	cells.assign(loaded[c])
	for cell in cells:
		world.tiles.erase(cell)
		world.particles.erase(cell)
	var tag := [c.x, c.y]
	world.details = world.details.filter(func(dd: Dictionary) -> bool: return dd.get("_chunk", []) != tag)
	loaded.erase(c)
	return cells


## Chunks within `radius` (Chebyshev) of the chunk holding `cell`.
func around(cell: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cc := chunk_of(cell)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c := cc + Vector2i(dx, dy)
			if in_range(c):
				out.append(c)
	return out


## Keeps `live` radius loaded and frees chunks beyond `keep` radius.
## Returns {"added": Array[Vector2i] cells, "removed": Array[Vector2i] cells}.
func update(world: WorldMap, center: Vector2i, live: int = 1, keep: int = 3) -> Dictionary:
	var added: Array[Vector2i] = []
	var removed: Array[Vector2i] = []
	for c in around(center, live):
		added.append_array(load_into(world, c))
	var cc := chunk_of(center)
	for c2: Vector2i in loaded.keys():
		if maxi(absi(c2.x - cc.x), absi(c2.y - cc.y)) > keep:
			removed.append_array(unload_from(world, c2))
	return {"added": added, "removed": removed}
