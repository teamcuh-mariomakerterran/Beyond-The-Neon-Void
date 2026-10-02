class_name MapValidator
extends RefCounted
## Finds problems in a WorldMap before they bite in play: missing art, broken
## location links, spawns on holes, enemies nobody can reach, unknown loot /
## NPC / particle ids. Each issue carries a cell so the editor can fly to it.

const ERROR := "error"
const WARN := "warn"


static func _issue(level: String, text: String, cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	return {"level": level, "text": text, "cell": cell}


static func _asset_ok(path: String) -> bool:
	return path == "" or ResourceLoader.exists(path) or FileAccess.file_exists(path)


static func validate(w: WorldMap, enemies: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var g := w.to_grid()
	var tdb: Dictionary = ContentDB.get("tiles") if ContentDB.get("tiles") is Dictionary else {}
	# Tiles nobody can draw.
	var unknown := {}
	for cell: Vector2i in w.tiles:
		for e: Array in w.tiles[cell]:
			var id := str(e[1])
			if id.begins_with("terrain:"):
				if not ContentDB.terrain.has(id.substr(8)):
					unknown[id] = cell
			elif not tdb.has(id) and not FileAccess.file_exists("res://assets/tiles/%s.png" % id):
				unknown[id] = cell
	for id: String in unknown:
		out.append(_issue(WARN, "Unknown tile '%s' (draws nothing) — RESCAN tiles or repaint." % id, unknown[id]))
	# Particles.
	var presets: Dictionary = ContentDB.get("particles") if ContentDB.get("particles") is Dictionary else {}
	for cell: Vector2i in w.particles:
		for e: Array in w.particles[cell]:
			if not presets.has(str(e[1])):
				out.append(_issue(ERROR, "Unknown particle preset '%s'." % e[1], cell))
	# Spawns.
	var sp: Array = w.spawns.get("player", [])
	if w.kind == "encounter" and sp.is_empty():
		out.append(_issue(ERROR, "Encounter has no PLAYER SPAWN points (GAMEPLAY layer)."))
	var spawn_cells: Array[Vector2i] = []
	for e: Array in sp:
		var c := Vector2i(int(e[0]), int(e[1]))
		spawn_cells.append(c)
		if not g.in_bounds(c) or not g.is_walkable(c):
			out.append(_issue(ERROR, "Player spawn %d,%d stands on a hole or blocked tile." % [c.x, c.y], c))
	# Enemies: on solid ground and reachable on foot from a spawn.
	var reach := {}
	for c in spawn_cells:
		if g.is_walkable(c):
			reach.merge(g.flood(c, 9999, 3, 0, true))
	for en: Dictionary in enemies:
		var ec := Vector2i(int(en["cell"][0]), int(en["cell"][1]))
		var who := str(en.get("character_id", "?"))
		if not g.in_bounds(ec) or not g.is_walkable(ec):
			out.append(_issue(ERROR, "Enemy %s at %d,%d stands on a hole or blocked tile." % [who, ec.x, ec.y], ec))
		elif not reach.is_empty() and not reach.has(ec):
			out.append(_issue(WARN, "Enemy %s at %d,%d can't be reached on foot (jump 3) — ranged-only fight?" % [who, ec.x, ec.y], ec))
		if ContentDB.get_character(who) == null:
			out.append(_issue(ERROR, "Enemy uses unknown character '%s'." % who, ec))
	# Objects.
	for o: Dictionary in w.objects:
		var oc := Vector2i(int(o["cell"][0]), int(o["cell"][1]))
		var label := str(o.get("id", "object"))
		if not w.in_bounds(oc):
			out.append(_issue(WARN, "%s is outside the map bounds." % label, oc))
		if not _asset_ok(str(o.get("asset", ""))):
			out.append(_issue(ERROR, "%s: art file missing (%s)." % [label, o.get("asset", "")], oc))
		var loot := str(o.get("loot_item_id", ""))
		if loot != "" and ContentDB.get_item(loot) == null:
			out.append(_issue(ERROR, "%s: hidden loot '%s' is not an item." % [label, loot], oc))
		var npc := str(o.get("dialog_npc", ""))
		if npc != "" and ContentDB.get_npc(npc) == null:
			out.append(_issue(ERROR, "%s: NPC '%s' does not exist." % [label, npc], oc))
		if o.get("location") is Dictionary:
			var loc: Dictionary = o["location"]
			var name := str(loc.get("name", ""))
			var target := str(loc.get("target_map", ""))
			if name == "":
				out.append(_issue(WARN, "%s: location has no name." % label, oc))
			if target == "":
				out.append(_issue(WARN, "Location '%s' isn't linked to a map yet." % name, oc))
			elif ContentDB.get_map(target).is_empty():
				out.append(_issue(ERROR, "Location '%s' links to missing map '%s'." % [name, target], oc))
			var cut := str(loc.get("intro_cutscene", ""))
			if cut != "" and not FileAccess.file_exists(cut):
				out.append(_issue(ERROR, "Location '%s': cutscene file missing." % name, oc))
	for d: Dictionary in w.details:
		if not _asset_ok(str(d.get("asset", ""))):
			var p: Array = d.get("pos", [0, 0])
			out.append(_issue(ERROR, "Detail %s: art file missing." % d.get("id", ""), Vector2i(roundi(float(p[0])), roundi(float(p[1])))))
	for r: Dictionary in w.regions:
		var rn := str(r.get("name", "region"))
		var first := WorldMap.parse_key(str((r.get("cells", ["-1,-1"]) as Array)[0])) if not (r.get("cells", []) as Array).is_empty() else Vector2i(-1, -1)
		if (r.get("cells", []) as Array).is_empty():
			out.append(_issue(WARN, "Region '%s' has no painted cells." % rn))
		for t: Dictionary in r.get("triggers", []):
			var arg := str(t.get("arg", ""))
			match str(t.get("do", "")):
				"cutscene":
					if not FileAccess.file_exists(arg):
						out.append(_issue(ERROR, "Region '%s': cutscene '%s' not found." % [rn, arg], first))
				"battle":
					if ContentDB.get_mission(arg) == null:
						out.append(_issue(ERROR, "Region '%s': unknown mission '%s'." % [rn, arg], first))
				"teleport":
					if ContentDB.get_map(arg.split(":")[0]).is_empty():
						out.append(_issue(ERROR, "Region '%s': teleport to missing map '%s'." % [rn, arg], first))
		for m: String in (r.get("encounter", {}) as Dictionary).get("missions", []):
			if ContentDB.get_mission(m) == null:
				out.append(_issue(ERROR, "Region '%s': encounter mission '%s' does not exist." % [rn, m], first))
	if w.tiles.is_empty():
		out.append(_issue(WARN, "The map has no tiles yet."))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["level"] == ERROR and b["level"] != ERROR)
	return out
