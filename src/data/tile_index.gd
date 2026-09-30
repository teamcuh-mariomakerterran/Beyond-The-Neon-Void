class_name TileIndex
extends RefCounted
## Tile index (data/tiles.json, see docs/design/WORLD_FORMAT.md "Tile index").
##
## scan() walks assets/tiles/** and builds one entry per tile; numbered frame
## files (ocean_1…4, river_a_f1…f4, water-anim-01…04) collapse into a single
## animated entry. Numbered *variants* (grass_01…grass_10 — different art) stay
## separate: a sequence only counts as animation when its name says so
## (water, lava, anim, flow, ...) or it is exactly 4 same-size images that
## barely differ frame to frame.
##
## Also home of the auto-fit helper the renderer uses: fit_rect() is the opaque
## bounding box of an image, so slightly-off art snaps to the world angle.

const ROOT := "res://assets/tiles"
const DATA_FILE := "tiles.json"
const IMAGE_EXT := ["png", "webp", "jpg", "jpeg"]
const DEFAULT_FPS := 6
const MIN_FRAMES := 2
const MAX_FRAMES := 8
## Base names containing one of these are animations whenever numbered.
const ANIM_WORDS := ["water", "ocean", "sea", "river", "lava", "waterfall", "anim", "flow", "wave", "acid", "toxic_pool"]
## Share of opaque pixels allowed to change between frames of an unnamed 4-frame loop.
const SIMILAR_RATIO := 0.2
## Fields the scanner owns; everything else in an entry is user data and kept.
const GENERATED_KEYS := ["texture", "frames", "group"]

## Name keyword -> terrain id, checked in order (file name first, then folders).
const TERRAIN_RULES := [
	["lava", ["lava", "magma"]],
	["toxic", ["toxic", "acid", "sludge", "slime"]],
	["swamp", ["swamp", "bog", "marsh"]],
	["water", ["water", "ocean", "sea", "river", "lake", "wave", "shore"]],
	["snow", ["snow", "ice", "frost"]],
	["rock", ["mountain", "cliff", "rock", "boulder", "crag"]],
	["forest", ["forest", "tree", "jungle", "bush", "wood"]],
	["grass", ["grass", "meadow", "moss", "field"]],
	["sand", ["sand", "desert", "beach", "dune"]],
	["mud", ["mud", "dirt", "soil"]],
	["metal_grate", ["metal", "steel", "grate", "iron"]],
	["glass", ["glass"]],
	["rubble", ["rubble", "debris", "ruin"]],
	["concrete", ["stone", "concrete", "pavement", "asphalt", "road", "floor", "brick", "tile"]],
]
const FALLBACK_TERRAIN := "concrete"

## Gameplay defaults for terrain ids the scanner may assign (added to
## data/terrain.json only when missing; existing keys are never touched).
const TERRAIN_DEFAULTS := {
	"water": {"name": "Deep Water", "color": "#123a5c", "side": "#0a2238", "walkable": false, "glow": "#3fd2ff"},
	"lava": {"name": "Magma Flow", "color": "#8a2a0c", "side": "#4a1406", "move_cost": 3, "hazard": "neon_fire", "glow": "#ff6a1f"},
	"forest": {"name": "Overgrowth", "color": "#1f4a2c", "side": "#122c1a", "move_cost": 2, "cover": 1},
	"rock": {"name": "Rock Face", "color": "#4a4440", "side": "#2c2826", "move_cost": 2, "cover": 1},
	"grass": {"name": "Grass", "color": "#2f5a2a", "side": "#1c3818", "move_cost": 1},
	"sand": {"name": "Sand", "color": "#8a7448", "side": "#54462a", "move_cost": 2},
	"mud": {"name": "Mud", "color": "#4a3624", "side": "#2c2014", "move_cost": 3},
	"snow": {"name": "Snow", "color": "#c8d4e4", "side": "#7a8698", "move_cost": 2},
	"swamp": {"name": "Swamp", "color": "#2c3a24", "side": "#1a2414", "move_cost": 3},
	"toxic": {"name": "Toxic Sludge", "color": "#3a5a12", "side": "#22360a", "move_cost": 3, "hazard": "essence_leak", "glow": "#7dff3f"},
}

static var _fit_cache: Dictionary = {}
static var _frames_cache: Dictionary = {}


# --- Scanning ----------------------------------------------------------------

## Scans `root` recursively and returns the index {id: entry}. `previous` is the
## index to merge into (user-edited terrain/fps/fit/... survive); null reads the
## saved data/tiles.json when scanning the default root.
static func scan(root := ROOT, previous: Variant = null) -> Dictionary:
	var prev: Dictionary = {}
	if previous is Dictionary:
		prev = previous
	elif root == ROOT:
		prev = _read_saved()
	var by_dir: Dictionary = {}
	_collect(root, by_dir)
	var index: Dictionary = {}
	var dirs := by_dir.keys()
	dirs.sort()
	for dir: String in dirs:
		var paths: Array[String] = []
		paths.assign(by_dir[dir])
		for seq: Dictionary in collapse_sequences(paths):
			var frames: Array = seq["frames"]
			var id := _rel(root, str(seq["id"]))
			var entry := {
				"texture": frames[0],
				"frames": frames if frames.size() > 1 else [],
				"fps": DEFAULT_FPS,
				"group": _rel(root, dir),
				"terrain": guess_terrain(id),
				"fit": {"top": 0, "width": 0},
			}
			index[id] = _merge_entry(entry, prev.get(id))
	# Hand-made entries (textures outside the scan root) are kept as long as
	# their files still exist.
	for id: String in prev:
		var e: Variant = prev[id]
		if index.has(id) or not e is Dictionary:
			continue
		var tex := str(e.get("texture", ""))
		if tex != "" and not tex.begins_with(root.path_join("")) and FileAccess.file_exists(tex):
			index[id] = e
	return index


static func _merge_entry(fresh: Dictionary, old: Variant) -> Dictionary:
	if not old is Dictionary:
		return fresh
	var out: Dictionary = old.duplicate(true)
	for k: String in GENERATED_KEYS:
		out[k] = fresh[k]
	for k: String in fresh:
		if not out.has(k):
			out[k] = fresh[k]
	# A frames list the user edited (locked, or pointing at files the scan
	# didn't pair up) is an override; a stale subset of the scan is refreshed.
	var old_frames: Array = old.get("frames", [])
	if not old_frames.is_empty() and _all_exist(old_frames):
		var fresh_frames: Array = fresh["frames"]
		var subset := old_frames.all(func(f: Variant) -> bool: return fresh_frames.has(f))
		if bool(old.get("frames_locked", false)) or not subset:
			out["frames"] = old_frames
			out["texture"] = old.get("texture", old_frames[0])
	return out


static func _all_exist(paths: Array) -> bool:
	for p: Variant in paths:
		if not FileAccess.file_exists(str(p)) and not ResourceLoader.exists(str(p)):
			return false
	return true


static func _collect(dir: String, out: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() in IMAGE_EXT:
			if not out.has(dir):
				out[dir] = []
			out[dir].append(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with("."):
			_collect(dir.path_join(sub), out)


static func _rel(root: String, path: String) -> String:
	var r := root.trim_suffix("/")
	if path == r:
		return ""
	return path.trim_prefix(r + "/")


static func _read_saved() -> Dictionary:
	var out: Dictionary = {}
	for dir in ["res://data", "user://content"]:
		var path: String = dir.path_join(DATA_FILE)
		if FileAccess.file_exists(path):
			var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if v is Dictionary:
				out.merge(v, true)
	return out


## Writes the index to data/tiles.json (user://content in exported builds),
## refreshes ContentDB.tiles and adds any missing terrain ids it uses.
static func save(index: Dictionary) -> String:
	var keys := index.keys()
	keys.sort()
	var sorted: Dictionary = {}
	for k: String in keys:
		sorted[k] = index[k]
	var path := ForgeStore.save_dict_file(DATA_FILE.get_basename(), sorted)
	ContentDB.tiles = sorted
	_frames_cache.clear()
	var used: Array[String] = []
	for e: Variant in sorted.values():
		if e is Dictionary and not used.has(str(e.get("terrain", ""))):
			used.append(str(e.get("terrain", "")))
	ensure_terrain_keys(used)
	return path


## Adds TERRAIN_DEFAULTS entries for any of `ids` missing from ContentDB.terrain
## (all defaults when `ids` is empty) and saves terrain.json only if something
## was added. Returns the added ids.
static func ensure_terrain_keys(ids: Array = []) -> Array[String]:
	var added: Array[String] = []
	if ids.is_empty():
		ids = TERRAIN_DEFAULTS.keys()
	for id: Variant in ids:
		var k := str(id)
		if TERRAIN_DEFAULTS.has(k) and not ContentDB.terrain.has(k):
			ContentDB.terrain[k] = TERRAIN_DEFAULTS[k].duplicate(true)
			added.append(k)
	if not added.is_empty():
		ForgeStore.save_dict_file("terrain", ContentDB.terrain)
	return added


## Terrain id guessed from a tile id/path ("god_tiles/water/ocean_anim" -> water).
static func guess_terrain(tile_id: String) -> String:
	var parts := tile_id.to_lower().split("/")
	parts.reverse()  # file name first, then its folders from nearest outwards
	for part in parts:
		var tokens := part.replace("-", "_").replace(" ", "_").split("_", false)
		for rule: Array in TERRAIN_RULES:
			for word: String in rule[1]:
				if _matches(part, tokens, word):
					return str(rule[0])
	return FALLBACK_TERRAIN


static func _matches(part: String, tokens: PackedStringArray, word: String) -> bool:
	if word.length() >= 4:
		return part.contains(word)
	for t in tokens:  # short words ("sea", "mud", "ice") must start a token
		if t.begins_with(word):
			return true
	return false


# --- Sequence collapse (tiles and details) -----------------------------------

## Splits "ocean_03" -> ["ocean", 3]; "river_a_f2" -> ["river_a", 2];
## "tile (2)" -> ["tile", 2]; "water-anim-01" -> ["water-anim", 1].
## Returns [] when the name has no trailing number.
static func split_number(basename: String) -> Array:
	for pattern in ["^(.+?)[ _\\-]+(?:frame|fr|f)(\\d+)$", "^(.+?)\\s*\\((\\d+)\\)$", "^(.+?)[ _\\-]*(\\d+)$"]:
		var re := RegEx.create_from_string(pattern)
		var m := re.search(basename)
		if m:
			var base := m.get_string(1).strip_edges()
			if base != "":
				return [base, int(m.get_string(2))]
	return []


## Groups files whose names differ only by a trailing number into animations
## (see the class doc for the heuristic). Returns [{id, frames:[paths]}] where
## id is the path without extension (the stripped base for animations) and
## frames are sorted numerically; unanimated files come back one per entry.
static func collapse_sequences(paths: Array[String]) -> Array[Dictionary]:
	var groups: Dictionary = {}  # key -> {base_path, items:[[num, path]]}
	var singles: Array[String] = []
	for p in paths:
		var sp := split_number(p.get_file().get_basename())
		if sp.is_empty():
			singles.append(p)
			continue
		var key := "%s|%s|%s" % [p.get_base_dir(), str(sp[0]).to_lower(), p.get_extension().to_lower()]
		if not groups.has(key):
			groups[key] = {"base": p.get_base_dir().path_join(str(sp[0])), "items": []}
		groups[key]["items"].append([int(sp[1]), p])
	var out: Array[Dictionary] = []
	var taken: Dictionary = {}
	for p in singles:
		taken[p.get_basename()] = true
	for key: String in groups:
		var g: Dictionary = groups[key]
		var items: Array = g["items"]
		items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and str(a[1]) < str(b[1])))
		var frames: Array[String] = []
		for it: Array in items:
			frames.append(str(it[1]))
		if is_animation(str(g["base"]).get_file(), frames):
			var id := str(g["base"])
			if taken.has(id):
				id += "_anim"
			taken[id] = true
			out.append({"id": id, "frames": frames})
		else:
			for f in frames:
				out.append({"id": f.get_basename(), "frames": [f]})
	for p in singles:
		out.append({"id": p.get_basename(), "frames": [p]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	return out


## True when a numbered sequence is animation frames rather than variants.
static func is_animation(base_name: String, frames: Array[String]) -> bool:
	if frames.size() < MIN_FRAMES or frames.size() > MAX_FRAMES:
		return false
	var lower := base_name.to_lower()
	for w: String in ANIM_WORDS:
		if lower.contains(w):
			return true
	return frames.size() == 4 and frames_similar(frames)


## Same-size images whose consecutive frames change < SIMILAR_RATIO of opaque px.
static func frames_similar(frames: Array[String]) -> bool:
	var imgs: Array[Image] = []
	for f in frames:
		var img := _load_image(f)
		if img == null:
			return false
		if not imgs.is_empty() and img.get_size() != imgs[0].get_size():
			return false
		imgs.append(img)
	for i in range(1, imgs.size()):
		if _diff_ratio(imgs[i - 1], imgs[i]) >= SIMILAR_RATIO:
			return false
	return true


static func _diff_ratio(a: Image, b: Image) -> float:
	var sa := _small(a)
	var sb := _small(b)
	var opaque := 0
	var differ := 0
	for y in sa.get_height():
		for x in sa.get_width():
			var ca := sa.get_pixel(x, y)
			var cb := sb.get_pixel(x, y)
			if ca.a < 0.1 and cb.a < 0.1:
				continue
			opaque += 1
			var d := maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), maxf(absf(ca.b - cb.b), absf(ca.a - cb.a)))
			if d > 0.12:
				differ += 1
	return float(differ) / float(opaque) if opaque > 0 else 0.0


## RGBA8 copy at most 64 px wide (keeps the diff cheap on big tiles).
static func _small(img: Image) -> Image:
	var c := img.duplicate() as Image
	if c.is_compressed():
		c.decompress()
	c.convert(Image.FORMAT_RGBA8)
	if c.get_width() > 64:
		c.resize(64, maxi(1, int(64.0 * c.get_height() / c.get_width())), Image.INTERPOLATE_NEAREST)
	return c


static func _load_image(path: String) -> Image:
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			return img
	var tex := ForgeStore.load_texture(path)
	return tex.get_image() if tex else null


# --- Renderer helpers ----------------------------------------------------------

## Opaque bounding box of the texture in source px (cached per texture).
## Renderer: scale = tile_width / used.size.x, and used.position.y is pinned
## to the diamond's north point.
static func fit_rect(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	var key: Variant = tex.resource_path if tex.resource_path != "" else tex.get_instance_id()
	if _fit_cache.has(key):
		return _fit_cache[key]
	var r := Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img:
		if img.is_compressed():
			img = img.duplicate() as Image
			img.decompress()
		var used := img.get_used_rect()
		if used.has_area():
			r = Rect2(used)
	_fit_cache[key] = r
	return r


## fit_rect() of a tile's first frame with the entry's "fit" overrides
## ({"top", "width"}; 0 = auto) applied.
static func fit_for(tile_id: String) -> Rect2:
	var frames := frames_for(tile_id)
	if frames.is_empty():
		return Rect2()
	var r := fit_rect(frames[0])
	var fit: Variant = ContentDB.tiles.get(tile_id, {}).get("fit", {})
	if fit is Dictionary:
		if float(fit.get("top", 0)) > 0.0:
			r.position.y = float(fit["top"])
		if float(fit.get("width", 0)) > 0.0:
			r.size.x = float(fit["width"])
	return r


## Frame textures of a tile (one entry for static tiles), loaded through
## ForgeStore.load_texture so freshly dropped files work before import.
static func frames_for(tile_id: String) -> Array[Texture2D]:
	if _frames_cache.has(tile_id):
		return _frames_cache[tile_id]
	var out: Array[Texture2D] = []
	var e: Variant = ContentDB.tiles.get(tile_id)
	if e is Dictionary:
		var paths: Array = e.get("frames", [])
		if paths.is_empty():
			paths = [e.get("texture", "")]
		for p: Variant in paths:
			var t := ForgeStore.load_texture(str(p))
			if t:
				out.append(t)
	_frames_cache[tile_id] = out
	return out


## Drops cached fits/frames (after a rescan or when art files changed).
static func clear_cache() -> void:
	_fit_cache.clear()
	_frames_cache.clear()
