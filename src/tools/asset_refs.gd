class_name AssetRefs
extends RefCounted
## Keeps every res://assets/... link in data/ pointing at a real file.
##   broken()      — links whose file is gone (renamed, moved, deleted)
##   suggest(path) — best guess for where it went (same file name elsewhere,
##                   or the same name after slug-style renaming)
##   repair_all()  — applies every confident guess
##   rename(a, b)  — moves a file AND rewrites every link to it
## Works on the JSON text directly, so it covers maps, items, characters,
## cutscenes, stamps, the asset index — anything under data/.

const DATA_DIR := "res://data"
const ASSET_ROOT := "res://assets"
const _RX := "res://assets/[^\"\\\\]+"


static func _json_files(dir: String = DATA_DIR) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_json_files(dir.path_join(d)))
	return out


static func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)


## [{file, path}] for every link whose target is missing.
static func broken() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rx := RegEx.create_from_string(_RX)
	var seen := {}
	for f in _json_files():
		var text := FileAccess.get_file_as_string(f)
		for m in rx.search_all(text):
			var p := m.get_string()
			var key := f + "|" + p
			if not seen.has(key) and not _exists(p):
				seen[key] = true
				out.append({"file": f, "path": p})
	return out


static var _index: Dictionary = {}


static func _all_assets(dir: String = ASSET_ROOT, out: Array[String] = []) -> Array[String]:
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".import") and not f.ends_with(".uid"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_all_assets(dir.path_join(d), out)
	return out


## Rebuilds the name → paths lookup (call after files change on disk).
static func reindex() -> void:
	_index.clear()
	for p in _all_assets():
		for key in [p.get_file().to_lower(), ForgeStore.slugify(p.get_file().get_basename()) + "." + p.get_extension().to_lower()]:
			if not _index.has(key):
				_index[key] = []
			if not (_index[key] as Array).has(p):
				_index[key].append(p)


## Where a missing file most likely went, or "" if unsure (0 or 2+ candidates).
static func suggest(path: String) -> String:
	if _index.is_empty():
		reindex()
	for key in [path.get_file().to_lower(), ForgeStore.slugify(path.get_file().get_basename()) + "." + path.get_extension().to_lower()]:
		var hits: Array = _index.get(key, [])
		if hits.size() == 1:
			return hits[0]
	return ""


static func _rewrite(old_path: String, new_path: String) -> int:
	var count := 0
	for f in _json_files():
		var text := FileAccess.get_file_as_string(f)
		if not text.contains(old_path):
			continue
		var n := text.count('"' + old_path + '"')
		if n == 0:
			continue
		text = text.replace('"' + old_path + '"', '"' + new_path + '"')
		var fa := FileAccess.open(f, FileAccess.WRITE)
		if fa:
			fa.store_string(text)
			fa.close()
			count += n
	return count


## Fixes every broken link that has exactly one candidate. Returns
## {"fixed": n, "left": [paths still broken]}.
static func repair_all(reload: bool = true) -> Dictionary:
	reindex()
	var fixed := 0
	var left: Array = []
	var done := {}
	for b: Dictionary in broken():
		var p: String = b["path"]
		if done.has(p):
			continue
		done[p] = true
		var s := suggest(p)
		if s != "":
			fixed += _rewrite(p, s)
		else:
			left.append(p)
	if reload and fixed > 0:
		ContentDB.reload()
	return {"fixed": fixed, "left": left}


## Moves an asset (never across into the Black Doctrine folders — only inside
## res://assets) and rewrites every link to it. Returns links updated, or -1.
static func rename(old_path: String, new_path: String, reload: bool = true) -> int:
	if not old_path.begins_with(ASSET_ROOT) or not new_path.begins_with(ASSET_ROOT):
		return -1
	if not FileAccess.file_exists(old_path) or FileAccess.file_exists(new_path):
		return -1
	DirAccess.make_dir_recursive_absolute(new_path.get_base_dir())
	if DirAccess.rename_absolute(old_path, new_path) != OK:
		return -1
	for ext in [".import"]:
		if FileAccess.file_exists(old_path + ext):
			DirAccess.remove_absolute(old_path + ext)
	var n := _rewrite(old_path, new_path)
	reindex()
	if reload and n > 0:
		ContentDB.reload()
	return n
