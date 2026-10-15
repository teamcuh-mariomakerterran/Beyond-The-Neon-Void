class_name ExternalLibrary
extends RefCounted
## Asset folders that live OUTSIDE the project (a generator's output folder,
## a shared drive), indexed by their own .json files. The Forge's EXTERNAL
## LIBRARY tab browses them; using an asset COPIES it into the project
## (assets/<category>/library/<pack>/...) so maps only ever point at res://
## paths that work in builds and on every machine. Originals are never touched.
##
## Index files are read leniently, whatever their shape:
##   [ {...}, ... ]                         a list of entries
##   {"assets"|"items"|"sprites"|"tiles"|"props"|"entries"|"files"|"images": [...]}
##   {"some_id": {...}, ...}                entries keyed by id
##   tile_01.json next to tile_01.png       a sidecar for that one image
## An entry needs an image: path / file / filename / image / src / sprite /
## texture / png (relative to the .json, or to the folder root). Optional:
## name / id / title, category / type / kind, tags, description / prompt,
## width / height or size, anchor / pivot. Every other field is kept as-is.
## Images no index mentions still show up (category from their folder).

const CONFIG := "user://external_library.cfg"
## Imported assets: "<pack>/<path in pack>" -> {res, mtime} (committed, shared).
const LEDGER := "res://data/external_imports.json"
## Tests point these elsewhere so they never write into the project.
static var ledger_path := LEDGER
static var assets_root := ""  # "" = each category's own folder
const IMAGE_EXT := ["png", "webp", "jpg", "jpeg"]
const LIST_KEYS := ["assets", "items", "sprites", "tiles", "props", "entries", "files", "images", "objects", "library"]
const IMAGE_KEYS := ["path", "file", "filename", "image", "src", "sprite", "texture", "png", "image_path", "file_path"]
const NAME_KEYS := ["name", "id", "title", "label"]
const CAT_KEYS := ["category", "type", "kind", "group", "asset_type"]
const TEXT_KEYS := ["description", "prompt", "notes", "caption"]
const MAX_DEPTH := 8
## Words in a category / tag / folder name -> our asset category.
const CATEGORY_WORDS := [
	["vfx", ["vfx", "fx", "effect", "particle", "spell", "explosion", "smoke", "magic"]],
	["tiles", ["tile", "floor", "ground", "terrain", "road", "street", "pavement"]],
	["structures", ["structure", "building", "wall", "room", "interior", "house", "tower", "shop"]],
	["portraits", ["portrait", "face", "bust", "avatar"]],
	["units", ["character", "unit", "npc", "enemy", "hero", "sprite_sheet", "spritesheet", "creature", "mob"]],
	["items", ["item", "weapon", "gear", "loot", "pickup", "consumable", "armor", "armour"]],
	["ui", ["ui", "icon", "button", "hud", "frame", "cursor"]],
	["backgrounds", ["background", "backdrop", "sky", "skybox", "parallax"]],
	["details", ["decal", "detail", "graffiti", "puddle", "crack", "stain"]],
	["props", ["prop", "furniture", "object", "decor", "crate", "barrel", "sign", "machine"]],
]


# --- Folders (per machine) ---------------------------------------------------

static func folders() -> PackedStringArray:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG) != OK:
		return PackedStringArray()
	return PackedStringArray(cfg.get_value("library", "folders", []))


static func set_folders(list: PackedStringArray) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG)
	cfg.set_value("library", "folders", Array(list))
	cfg.save(CONFIG)


static func pack_name(folder: String) -> String:
	return ForgeStore.slugify(folder.trim_suffix("/").trim_suffix("\\").get_file())


# --- Scanning ------------------------------------------------------------------

## Every asset under `root`: [{path (absolute), rel, pack, name, category,
## tags: PackedStringArray, text, size: Vector2i, anchor, meta: Dictionary, index}]
static func scan(root: String) -> Array:
	root = root.replace("\\", "/").trim_suffix("/")
	var jsons: Array[String] = []
	var images: Array[String] = []
	_walk(root, 0, jsons, images)
	var pack := pack_name(root)
	var by_path := {}
	for j in jsons:
		for e: Dictionary in _read_index(j, root):
			var p: String = e["path"]
			if FileAccess.file_exists(p) and not by_path.has(p):
				e["pack"] = pack
				e["rel"] = p.trim_prefix(root + "/")
				e["index"] = j.trim_prefix(root + "/")
				by_path[p] = e
	for p in images:
		if not by_path.has(p):
			var rel := p.trim_prefix(root + "/")
			by_path[p] = {"path": p, "rel": rel, "pack": pack, "name": p.get_file().get_basename(),
				"category": guess_category([rel.get_base_dir()]), "tags": PackedStringArray(rel.get_base_dir().split("/", false)),
				"text": "", "size": Vector2i.ZERO, "anchor": null, "meta": {}, "index": ""}
	var out: Array = by_path.values()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["rel"]) < str(b["rel"]))
	return out


static func _walk(dir: String, depth: int, jsons: Array[String], images: Array[String]) -> void:
	if depth > MAX_DEPTH:
		return
	for f in DirAccess.get_files_at(dir):
		var ext := f.get_extension().to_lower()
		if ext == "json":
			jsons.append(dir.path_join(f))
		elif ext in IMAGE_EXT:
			images.append(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with(".") and not sub.begins_with("__"):
			_walk(dir.path_join(sub), depth + 1, jsons, images)


static func _read_index(json_path: String, root: String) -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	var raw: Array = []
	if d is Array:
		raw = d
	elif d is Dictionary:
		var dd := d as Dictionary
		var listed := false
		for k: String in LIST_KEYS:
			if dd.get(k) is Array:
				raw.append_array(dd[k])
				listed = true
		if not listed:
			if _image_of(dd) != "":
				raw = [dd]  # one entry, or a sidecar that names its image
			else:
				var sidecar := _sibling_image(json_path)
				var keyed := dd.keys().filter(func(k: Variant) -> bool: return dd[k] is Dictionary and _image_of(dd[k]) != "")
				if not keyed.is_empty():
					for k: Variant in keyed:
						var e: Dictionary = (dd[k] as Dictionary).duplicate()
						if _first(e, NAME_KEYS) == "":
							e["name"] = str(k)
						raw.append(e)
				elif sidecar != "":
					var e2 := dd.duplicate()
					e2["path"] = sidecar
					raw = [e2]
	var out: Array = []
	for r: Variant in raw:
		if r is Dictionary:
			var e := _entry(r, json_path.get_base_dir(), root)
			if not e.is_empty():
				out.append(e)
	return out


static func _entry(r: Dictionary, base: String, root: String) -> Dictionary:
	var img := _image_of(r)
	if img == "" or img.begins_with("http"):
		return {}
	img = img.replace("\\", "/")
	var path := img if (img.is_absolute_path() or img.contains(":/")) else base.path_join(img).simplify_path()
	if not FileAccess.file_exists(path):
		path = root.path_join(img).simplify_path()
	var tags := PackedStringArray()
	var t: Variant = r.get("tags", r.get("keywords", []))
	if t is Array:
		for x: Variant in t:
			tags.append(str(x))
	elif t is String:
		for x in str(t).split(",", false):
			tags.append(x.strip_edges())
	var size := Vector2i.ZERO
	if r.has("width") and r.has("height"):
		size = Vector2i(int(r["width"]), int(r["height"]))
	elif r.get("size") is Array and (r["size"] as Array).size() >= 2:
		size = Vector2i(int(r["size"][0]), int(r["size"][1]))
	var cat_text := _first(r, CAT_KEYS)
	var name := _first(r, NAME_KEYS)
	return {"path": path, "name": name if name != "" else img.get_file().get_basename(),
		"category": guess_category([cat_text] + Array(tags) + [img.get_base_dir()]),
		"source_category": cat_text, "tags": tags, "text": _first(r, TEXT_KEYS), "size": size,
		"anchor": r.get("anchor", r.get("pivot")), "meta": r}


static func _image_of(r: Dictionary) -> String:
	for k: String in IMAGE_KEYS:
		var v: Variant = r.get(k)
		if v is String and str(v).get_extension().to_lower() in IMAGE_EXT:
			return str(v)
	return ""


static func _first(r: Dictionary, keys: Array) -> String:
	for k: String in keys:
		if r.get(k) is String and str(r[k]).strip_edges() != "":
			return str(r[k]).strip_edges()
	return ""


static func _sibling_image(json_path: String) -> String:
	for ext: String in IMAGE_EXT:
		var p := json_path.get_basename() + "." + ext
		if FileAccess.file_exists(p):
			return p
	return ""


## Our asset category for a set of hints (category field, tags, folders).
static func guess_category(hints: Array) -> String:
	# Whole words (or their plural / -ing forms): "buildings" is a building,
	# but "building" is not "ui".
	var words: Array[String] = []
	for h: Variant in hints:
		var cur := ""
		for ch in str(h).to_lower() + " ":
			if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
				cur += ch
			elif cur != "":
				words.append(cur)
				cur = ""
	for pair: Array in CATEGORY_WORDS:
		for w: String in pair[1]:
			var key := w.replace("_", "")
			for word in words:
				if word == key or (word.begins_with(key) and word.length() - key.length() <= 3):
					return pair[0]
	return "props"


static func matches(e: Dictionary, query: String, category: String = "") -> bool:
	if category != "" and e["category"] != category:
		return false
	if query.strip_edges() == "":
		return true
	var hay := ("%s %s %s %s" % [e["name"], e["rel"], " ".join(e["tags"]), e["text"]]).to_lower()
	for w in query.to_lower().split(" ", false):
		if not hay.contains(w):
			return false
	return true


# --- Importing -------------------------------------------------------------------

static func ledger() -> Dictionary:
	if not FileAccess.file_exists(ledger_path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ledger_path))
	return d if d is Dictionary else {}


static func ledger_key(e: Dictionary) -> String:
	return "%s/%s" % [e["pack"], e["rel"]]


## The project copy of an entry ("" if not imported yet, or the file is gone).
static func imported_path(e: Dictionary) -> String:
	var rec: Variant = ledger().get(ledger_key(e))
	if rec is Dictionary and FileAccess.file_exists(str(rec.get("res", ""))):
		return str(rec["res"])
	return ""


## True when the original changed after it was imported.
static func is_stale(e: Dictionary) -> bool:
	var rec: Variant = ledger().get(ledger_key(e))
	return rec is Dictionary and int(FileAccess.get_modified_time(e["path"])) > int(rec.get("mtime", 0))


## Copies an entry into the project and returns its res:// path. `clean` keys
## out a flat / magenta background first (ArtCutter). Re-importing a changed
## original refreshes the copy in place. Writes <name>.meta.json beside it
## (the original index entry: prompt, tags...) and records it in the ledger.
static func import_entry(e: Dictionary, category: String = "", clean: bool = false) -> String:
	if category == "":
		category = str(e["category"])
	var cat: Dictionary = ForgeStore.ASSET_CATEGORIES.get(category, ForgeStore.ASSET_CATEGORIES["props"])
	var dest := imported_path(e)
	if dest == "":
		var cat_dir := str(cat["dir"]) if assets_root == "" else assets_root.path_join(category)
		var dir := cat_dir.path_join("library").path_join(str(e["pack"]))
		var sub := str(e["rel"]).get_base_dir()
		if sub != "":
			dir = dir.path_join(ForgeStore.slugify(sub.replace("/", "_")))
		var base := ForgeStore.slugify(str(e["name"]))
		dest = dir.path_join(base + ".png")
		var n := 2
		while FileAccess.file_exists(dest):
			dest = dir.path_join("%s_%d.png" % [base, n])
			n += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest.get_base_dir()))
	var img := Image.load_from_file(str(e["path"]))
	if img == null:
		return ""
	if clean:
		img = ArtCutter.key(img)
	img.save_png(ProjectSettings.globalize_path(dest))
	var meta := {"source": ledger_key(e), "name": e["name"], "tags": Array(e["tags"]), "text": e["text"],
		"source_category": e.get("source_category", ""), "entry": e["meta"]}
	var mf := FileAccess.open(dest.get_basename() + ".meta.json", FileAccess.WRITE)
	if mf:
		mf.store_string(JSON.stringify(meta, "\t") + "\n")
	var l := ledger()
	l[ledger_key(e)] = {"res": dest, "mtime": int(FileAccess.get_modified_time(e["path"]))}
	var lf := FileAccess.open(ledger_path, FileAccess.WRITE)
	if lf:
		lf.store_string(JSON.stringify(l, "\t", true) + "\n")
	ForgeStore._tex_cache.erase(dest)
	return dest


## True if the image's corners are one opaque colour (a backdrop to key out).
static func has_flat_background(path: String) -> bool:
	var img := Image.load_from_file(path)
	if img == null or img.get_width() < 4:
		return false
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width() - 1
	var h := img.get_height() - 1
	var c0 := img.get_pixel(0, 0)
	if c0.a < 0.95:
		return false
	for c: Color in [img.get_pixel(w, 0), img.get_pixel(0, h), img.get_pixel(w, h)]:
		if c.a < 0.95 or Vector3(c.r - c0.r, c.g - c0.g, c.b - c0.b).length() > 0.06:
			return false
	return true
