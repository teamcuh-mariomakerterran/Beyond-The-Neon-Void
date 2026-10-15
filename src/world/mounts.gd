class_name Mounts
extends RefCounted
## Overworld mounts (data/mounts.json): vehicles you ride on world maps.
## Land mounts are faster and see fewer ambushes; water mounts (the sub) can
## only travel on water, boarding and leaving from the shore. ExploreScene
## does the riding; this holds the rules.

const PATH := "res://data/mounts.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary:
			for k: String in d:
				if not k.begins_with("_") and d[k] is Dictionary:
					_data[k] = d[k]
	return _data


static func get_mount(id: String) -> Dictionary:
	return data().get(id, {})


static func flag(id: String) -> String:
	return "mount:" + id


static func owned() -> Array[String]:
	var out: Array[String] = []
	for id: String in data():
		if bool(data()[id].get("starter", false)) or GameManager.check_story_flag(flag(id)):
			out.append(id)
	out.sort()
	return out


static func give(id: String) -> void:
	if data().has(id):
		GameManager.set_story_flag(flag(id))


## Can `id` be ridden on this map (by its kind, or the map's own "mounts": true)?
static func allowed_on(id: String, map_kind: String, map_flag: bool = false) -> bool:
	var m := get_mount(id)
	return not m.is_empty() and (map_flag or map_kind in Array(m.get("maps", ["world"])))


static func terrain(id: String) -> String:
	return str(get_mount(id).get("terrain", "land"))


static func speed(id: String) -> float:
	return float(get_mount(id).get("speed", 1.0)) if id != "" else 1.0


static func climb(id: String, on_foot: int) -> int:
	return int(get_mount(id).get("climb", on_foot)) if id != "" else on_foot


static func encounter_mult(id: String) -> float:
	return float(get_mount(id).get("encounters", 1.0)) if id != "" else 1.0


static func is_water_cell(grid: IsometricGrid, c: Vector2i) -> bool:
	var cell := grid.get_cell(c) if grid.in_bounds(c) else null
	return cell != null and cell.terrain.contains("water")
