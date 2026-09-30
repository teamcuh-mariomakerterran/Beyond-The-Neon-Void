class_name ForgeStore
extends RefCounted
## Neon Forge persistence: writes content back to JSON and manages asset files.
##
## When run from the Godot editor (your normal workflow) it writes straight into
## res://data and res://assets, so every edit is a git diff. In an exported build
## res:// is read-only, so it falls back to user://content (ContentDB loads that
## as an override layer).

const ASSET_CATEGORIES := {
	"tiles": {"dir": "res://assets/tiles", "label": "GROUND TILES", "ext": ["png", "webp", "jpg", "jpeg"]},
	"structures": {"dir": "res://assets/structures", "label": "STRUCTURES", "ext": ["png", "webp", "jpg", "jpeg"]},
	"props": {"dir": "res://assets/props", "label": "PROPS", "ext": ["png", "webp", "jpg", "jpeg"]},
	"units": {"dir": "res://assets/units", "label": "UNIT SHEETS", "ext": ["png", "webp", "jpg", "jpeg", "tres"]},
	"portraits": {"dir": "res://assets/portraits", "label": "PORTRAITS", "ext": ["png", "webp", "jpg", "jpeg"]},
	"ui": {"dir": "res://assets/ui", "label": "UI", "ext": ["png", "webp", "jpg", "jpeg", "svg"]},
	"vfx": {"dir": "res://assets/vfx", "label": "VFX", "ext": ["png", "webp", "tscn", "tres"]},
	"music": {"dir": "res://assets/music", "label": "MUSIC", "ext": ["ogg", "mp3", "wav"]},
	"sfx": {"dir": "res://assets/sfx", "label": "SFX", "ext": ["ogg", "mp3", "wav"]},
	"voice": {"dir": "res://assets/voice", "label": "VOICE LINES", "ext": ["ogg", "mp3", "wav"]},
}
const IMAGE_EXT := ["png", "webp", "jpg", "jpeg", "svg"]
const AUDIO_EXT := ["ogg", "mp3", "wav"]

static var _tex_cache: Dictionary = {}


static func writable_res() -> bool:
	return OS.has_feature("editor")


static func data_dir() -> String:
	return "res://data" if writable_res() else ContentDB.USER_DIR


static func _write_json(path: String, value: Variant) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("ForgeStore: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	var ok := f.store_string(JSON.stringify(value, "\t") + "\n")
	f.close()
	return ok


## Writes every entry of a Resource bucket (classes, abilities, ...) to its file.
static func save_bucket(bucket: String) -> String:
	var arr := []
	for r: GameResource in ContentDB.get_all(bucket):
		arr.append(_clean(r.to_dict()))
	var path := data_dir().path_join(bucket + ".json")
	return path if _write_json(path, arr) else ""


## Writes a dictionary-style file (terrain, vendors, recipes, rumors).
static func save_dict_file(name: String, data: Dictionary) -> String:
	var path := data_dir().path_join(name + ".json")
	return path if _write_json(path, data) else ""


static func save_map(map: Dictionary) -> String:
	var path := data_dir().path_join("maps").path_join(str(map["id"]) + ".json")
	ContentDB.maps[str(map["id"])] = map
	return path if _write_json(path, map) else ""


## Drops default-valued noise so JSON diffs stay small and readable.
static func _clean(d: Dictionary) -> Dictionary:
	var out := {}
	for k: String in d:
		var v: Variant = d[k]
		if k in ["id", "display_name"]:
			out[k] = v
		elif v is String and v == "":
			continue
		elif (v is Array or v is Dictionary) and v.is_empty():
			continue
		else:
			out[k] = v
	return out


static func put_entry(bucket: String, res: GameResource) -> void:
	var db: Dictionary = ContentDB.get("_db")
	if not db.has(bucket):
		db[bucket] = {}
	db[bucket][res.id] = res


static func remove_entry(bucket: String, id: String) -> void:
	var db: Dictionary = ContentDB.get("_db")
	if db.has(bucket):
		db[bucket].erase(id)


static func rename_entry(bucket: String, old_id: String, res: GameResource) -> void:
	var db: Dictionary = ContentDB.get("_db")
	var rebuilt := {}
	for k: String in db[bucket]:
		if k == old_id:
			rebuilt[res.id] = res
		else:
			rebuilt[k] = db[bucket][k]
	db[bucket] = rebuilt


static func unique_id(bucket: String, base: String) -> String:
	var id := slugify(base)
	if id == "":
		id = "new"
	var n := 1
	var candidate := id
	while ContentDB.get_entry(bucket, candidate) != null:
		n += 1
		candidate = "%s_%d" % [id, n]
	return candidate


static func slugify(text: String) -> String:
	var out := ""
	for ch in text.to_lower().strip_edges():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif out != "" and not out.ends_with("_"):
			out += "_"
	return out.trim_suffix("_")


# --- Assets ----------------------------------------------------------------

static func category_for_file(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext in AUDIO_EXT:
		return "sfx"
	return "tiles" if ext in IMAGE_EXT else ""


## Copies an OS file into the project. The original is never moved or changed
## (important for the shared Black Doctrine asset folders). Returns res:// path.
static func import_file(os_path: String, category: String, new_name: String = "") -> String:
	var cat: Dictionary = ASSET_CATEGORIES.get(category, {})
	if cat.is_empty():
		return ""
	var dir: String = cat["dir"]
	DirAccess.make_dir_recursive_absolute(dir)
	var ext := os_path.get_extension().to_lower()
	var base := slugify(new_name if new_name != "" else os_path.get_file().get_basename())
	var dest := dir.path_join(base + "." + ext)
	var n := 2
	while FileAccess.file_exists(dest):
		dest = dir.path_join("%s_%d.%s" % [base, n, ext])
		n += 1
	var err := DirAccess.copy_absolute(os_path, ProjectSettings.globalize_path(dest))
	if err != OK:
		push_error("ForgeStore: copy failed %s -> %s (%s)" % [os_path, dest, error_string(err)])
		return ""
	return dest


const CUTSCENE_DIR := "res://data/cutscenes"


static func list_cutscenes() -> Array[String]:
	var out: Array[String] = []
	if DirAccess.dir_exists_absolute(CUTSCENE_DIR):
		for f in DirAccess.get_files_at(CUTSCENE_DIR):
			if f.ends_with(".parallax.json") or f.ends_with(".cutscene.json"):
				out.append(CUTSCENE_DIR.path_join(f))
	out.sort()
	return out


static func list_assets(category: String) -> Array[String]:
	var out: Array[String] = []
	var cat: Dictionary = ASSET_CATEGORIES.get(category, {})
	if cat.is_empty() or not DirAccess.dir_exists_absolute(cat["dir"]):
		return out
	for f in DirAccess.get_files_at(cat["dir"]):
		if f.get_extension().to_lower() in cat["ext"]:
			out.append(str(cat["dir"]).path_join(f))
	out.sort()
	return out


static func rename_asset(path: String, new_base: String) -> String:
	var dest := path.get_base_dir().path_join(slugify(new_base) + "." + path.get_extension())
	if dest == path or FileAccess.file_exists(dest):
		return path
	if DirAccess.rename_absolute(path, dest) != OK:
		return path
	var import_file_path := path + ".import"
	if FileAccess.file_exists(import_file_path):
		DirAccess.remove_absolute(import_file_path)
	return dest


## Texture from an imported resource OR a raw image file (freshly dropped files
## aren't imported until the Godot editor rescans).
static func load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null and FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			tex = ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex


static func load_audio(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
		"wav":
			return AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
		"mp3":
			var mp3 := AudioStreamMP3.new()
			mp3.data = FileAccess.get_file_as_bytes(path)
			return mp3
	return null


## Slices a sprite sheet into SpriteFrames: one animation per row.
## `rows` e.g. ["idle", "walk", "attack", "hurt", "death"]. Saves a .tres next
## to the sheet and returns its path.
static func slice_sheet(sheet_path: String, frame_size: Vector2i, rows: Array[String], fps: float, out_name: String) -> String:
	var tex := load_texture(sheet_path)
	if tex == null or frame_size.x <= 0 or frame_size.y <= 0:
		return ""
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var cols := int(tex.get_width() / frame_size.x)
	var row_count := mini(rows.size(), int(tex.get_height() / frame_size.y))
	var persistent_tex: Texture2D = load(sheet_path) if ResourceLoader.exists(sheet_path) else tex
	for r in row_count:
		var anim := rows[r]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, fps)
		frames.set_animation_loop(anim, anim in ["idle", "walk", "charge"])
		for c in cols:
			var at := AtlasTexture.new()
			at.atlas = persistent_tex
			at.region = Rect2(c * frame_size.x, r * frame_size.y, frame_size.x, frame_size.y)
			if _region_empty(tex, at.region):
				continue
			frames.add_frame(anim, at)
	var out := sheet_path.get_base_dir().path_join(slugify(out_name) + "_frames.tres")
	var err := ResourceSaver.save(frames, out)
	return out if err == OK else ""


static func _region_empty(tex: Texture2D, region: Rect2) -> bool:
	var img := tex.get_image()
	if img == null:
		return false
	var step := maxi(int(region.size.x / 6), 1)
	for x in range(int(region.position.x), int(region.end.x), step):
		for y in range(int(region.position.y), int(region.end.y), step):
			if img.get_pixel(x, y).a > 0.05:
				return false
	return true
