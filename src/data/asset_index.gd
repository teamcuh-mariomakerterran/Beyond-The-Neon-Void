class_name AssetIndex
extends RefCounted
## data/asset_index.json: every asset that went through the Neon Forge intake
## wizard, keyed by a unique slug id.
##
##   id -> {"path", "type", "name", "role", "placement", "anim", "created", ...}
##
## `anim` uses the same dict shape as details/objects in WORLD_FORMAT.md:
##   {"frames": [], "hframes": 1, "vframes": 1, "fps": 8, "mode": "loop"}
## `links` points at content records the wizard created for the asset
## (e.g. {"character": "vex_morrow"} or {"ability": "call_goodboy"}).

const FILE_NAME := "asset_index.json"

## Tests point this somewhere disposable; empty = <ForgeStore.data_dir()>/asset_index.json.
static var path_override: String = ""


static func index_path() -> String:
	if path_override != "":
		return path_override
	return ForgeStore.data_dir().path_join(FILE_NAME)


## The whole index (empty when the file doesn't exist yet). Reads the project
## copy first, then the user:// override layer in exported builds.
static func load() -> Dictionary:
	var out := _read(index_path())
	if path_override == "" and not ForgeStore.writable_res():
		var base := _read("res://data".path_join(FILE_NAME))
		base.merge(out, true)
		out = base
	return out


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func save(index: Dictionary) -> bool:
	var path := index_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("AssetIndex: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	var keys := index.keys()
	keys.sort()
	var sorted := {}
	for k: String in keys:
		sorted[k] = index[k]
	var ok := f.store_string(JSON.stringify(sorted, "\t") + "\n")
	f.close()
	return ok


## Adds or merges `record` under `id` (existing keys not in `record` are kept).
static func add(id: String, record: Dictionary) -> bool:
	var index := AssetIndex.load()
	var merged: Dictionary = index.get(id, {}).duplicate(true)
	merged.merge(record, true)
	index[id] = merged
	return AssetIndex.save(index)


static func remove(id: String) -> bool:
	var index := AssetIndex.load()
	if not index.erase(id):
		return false
	return AssetIndex.save(index)


static func get_entry(id: String) -> Dictionary:
	return AssetIndex.load().get(id, {})


## The record whose path (or one of its anim frames) is `path`, with its id
## under "id"; {} when the file never went through the intake.
static func find_by_path(path: String) -> Dictionary:
	var index := AssetIndex.load()
	for id: String in index:
		var rec: Variant = index[id]
		if not rec is Dictionary:
			continue
		var anim: Variant = rec.get("anim")
		if str(rec.get("path", "")) == path or (anim is Dictionary and (anim.get("frames", []) as Array).has(path)):
			var out: Dictionary = rec.duplicate(true)
			out["id"] = id
			return out
	return {}


## Slug of `base` that is free in the index, as a ContentDB `bucket` id (when
## given) and as a file / sub folder name inside `dir` (when given):
## "Crater" -> "crater", then "crater_2", "crater_3"...
static func unique_id(base: String, bucket: String = "", dir: String = "", index: Dictionary = {}) -> String:
	var id := ForgeStore.slugify(base)
	if id == "":
		id = "asset"
	var idx: Dictionary = index if not index.is_empty() else AssetIndex.load()
	var taken_files := _names_in(dir)
	var candidate := id
	var n := 1
	while _taken(candidate, bucket, taken_files, idx):
		n += 1
		candidate = "%s_%d" % [id, n]
	return candidate


static func _taken(id: String, bucket: String, taken_files: Dictionary, index: Dictionary) -> bool:
	if index.has(id) or taken_files.has(id):
		return true
	if bucket != "":
		if bucket == "vendors":
			return ContentDB.vendors.has(id)
		if ContentDB.get_entry(bucket, id) != null:
			return true
	return false


## Base names of the files (and sub folders) in `dir`. A numbered frame
## ("crater_3.png") also reserves its stem ("crater") so sequences never mix.
static func _names_in(dir: String) -> Dictionary:
	var out := {}
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		var stem := f.get_basename()
		out[stem] = true
		var seq := sequence_key(stem)
		if not seq.is_empty():
			out[seq[0]] = true
	for d in DirAccess.get_directories_at(dir):
		out[d] = true
	return out


## "ocean_anim_3" -> ["ocean_anim", 3]; "river_a_f4" -> ["river_a", 4];
## "water-anim-01" -> ["water-anim", 1]; no trailing number -> [].
static func sequence_key(stem: String) -> Array:
	var re := RegEx.create_from_string("^(.*?)(?:[ _\\-]f(?:rame)?|[ _\\-]|frame)?(\\d+)$")
	var m := re.search(stem)
	if m == null or m.get_string(1) == "":
		return []
	return [m.get_string(1), int(m.get_string(2))]
