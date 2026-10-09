extends Node
## ContentDB — loads every piece of game content from JSON into typed Resources.
##
## Sources, in order (later ones override earlier ones by id):
##   1. res://data/*.json          shipped content (in git)
##   2. user://content/*.json      content injected by the Neon Forge editor at runtime
##
## JSON keeps content diff-friendly and editable by tools; Resources keep the
## game code typed. Every Resource has apply_dict()/to_dict() (see GameResource).

signal content_reloaded

const DATA_DIR := "res://data"
const USER_DIR := "user://content"

## JSON file name (bucket) -> Resource script used for its entries.
var CATALOG := {
	"classes": ClassResource,
	"abilities": Ability,
	"cards": CardResource,
	"status_effects": StatusEffect,
	"items": ItemResource,
	"characters": CharacterData,
	"missions": MissionResource,
	"loot_tables": LootTable,
	"dispatch_missions": DispatchMission,
	"quests": QuestResource,
	"npcs": NPCResource,
	"passives": PassiveResource,
}

var ABILITY_SCRIPTS := {
	"kinetic": KineticAbility,
	"time": TimeAbility,
	"terrain": TerrainAbility,
}

var _db: Dictionary = {}  # bucket -> {id: Resource}
## Plain-dictionary content that doesn't need a Resource class (yet).
var terrain: Dictionary = {}
var vendors: Dictionary = {}
## Battle barks by character / class / team (data/barks.json; see Barks).
var barks: Dictionary = {}
## Evidence against the Doctrine (data/evidence.json; see Evidence).
var evidence: Dictionary = {}
var rumors: Dictionary = {}
var recipes: Dictionary = {}
var maps: Dictionary = {}
## Particle presets painted onto map cells (data/particles.json, see ParticleFactory).
var particles: Dictionary = {}
## Tile index built by TileIndex.scan() (data/tiles.json); may be empty.
var tiles: Dictionary = {}
var load_errors: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	_db.clear()
	load_errors.clear()
	for bucket: String in CATALOG:
		_db[bucket] = {}
	for dir in [DATA_DIR, USER_DIR]:
		for bucket: String in CATALOG:
			_load_bucket(dir, bucket)
		terrain.merge(_read_dict(dir.path_join("terrain.json")), true)
		vendors.merge(_read_dict(dir.path_join("vendors.json")), true)
		barks.merge(_read_dict(dir.path_join("barks.json")), true)
		evidence.merge(_read_dict(dir.path_join("evidence.json")), true)
		rumors.merge(_read_dict(dir.path_join("rumors.json")), true)
		recipes.merge(_read_dict(dir.path_join("recipes.json")), true)
		particles.merge(_read_dict(dir.path_join("particles.json")), true)
		tiles.merge(_read_dict(dir.path_join("tiles.json")), true)
		_load_maps(dir.path_join("maps"))
	for e in load_errors:
		push_warning("ContentDB: " + e)
	content_reloaded.emit()


func _load_bucket(dir: String, bucket: String) -> void:
	var path := dir.path_join(bucket + ".json")
	var parsed: Variant = _read_json(path)
	if parsed == null:
		return
	var entries: Array = parsed if parsed is Array else parsed.get("entries", [])
	for entry: Variant in entries:
		if not entry is Dictionary or not entry.has("id"):
			load_errors.append("%s: entry without id" % path)
			continue
		var res := _instantiate(bucket, entry)
		res.apply_dict(entry)
		_db[bucket][res.id] = res


func _instantiate(bucket: String, entry: Dictionary) -> GameResource:
	if bucket == "abilities" and ABILITY_SCRIPTS.has(entry.get("script", "")):
		return ABILITY_SCRIPTS[entry["script"]].new()
	return CATALOG[bucket].new()


## Map files bigger than this load the first time they're asked for (a 512²
## world is ~2 s to parse); until then `maps` holds a small stub
## {id, name, kind, format, _path, _stub: true}.
const LAZY_MAP_BYTES := 4 * 1024 * 1024
## Most big maps kept parsed at once (oldest fall back to a stub).
const MAX_BIG_MAPS := 2
var _big_loaded: Array[String] = []


func _load_maps(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			var path := dir.path_join(f)
			var fa := FileAccess.open(path, FileAccess.READ)
			if fa and fa.get_length() > LAZY_MAP_BYTES:
				var id := f.get_basename()
				maps[id] = _stub(id, path, fa)
				continue
			var d := _read_dict(path)
			if not d.is_empty():
				maps[str(d.get("id", f.get_basename()))] = d


## Name / kind / format from the first few KB (keys before "tiles"), so lists
## and pickers work without parsing the whole map.
func _stub(id: String, path: String, fa: FileAccess) -> Dictionary:
	var head := fa.get_buffer(4096).get_string_from_utf8()
	var st := {"id": id, "name": id, "kind": "world", "format": 2, "_path": path, "_stub": true}
	for k: String in ["name", "kind"]:
		var m := RegEx.create_from_string('"%s"\\s*:\\s*"([^"]*)"' % k).search(head)
		if m:
			st[k] = m.get_string(1)
	for k2: String in ["format", "width", "depth"]:
		var m2 := RegEx.create_from_string('"%s"\\s*:\\s*(\\d+)' % k2).search(head)
		if m2:
			st[k2] = int(m2.get_string(1))
	return st


func is_map_stub(id: String) -> bool:
	return bool((maps.get(id, {}) as Dictionary).get("_stub", false))


## Every map fully parsed (link graph, validators). Slow with big maps.
func full_maps() -> Dictionary:
	var out := {}
	for id: String in maps.keys():
		out[id] = get_map(id)
	return out


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		load_errors.append("%s:%d %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _read_dict(path: String) -> Dictionary:
	var v: Variant = _read_json(path)
	return v if v is Dictionary else {}


# --- Typed accessors -------------------------------------------------------

func get_entry(bucket: String, id: String) -> GameResource:
	return _db.get(bucket, {}).get(id)


func get_all(bucket: String) -> Array:
	return _db.get(bucket, {}).values()


func get_ids(bucket: String) -> Array:
	return _db.get(bucket, {}).keys()


func get_class_res(id: String) -> ClassResource:
	return get_entry("classes", id) as ClassResource


func get_ability(id: String) -> Ability:
	var a := get_entry("abilities", id) as Ability
	return a if a else get_entry("cards", id) as Ability


func get_card(id: String) -> CardResource:
	return get_entry("cards", id) as CardResource


func get_passive(id: String) -> PassiveResource:
	return get_entry("passives", id) as PassiveResource


func get_status(id: String) -> StatusEffect:
	return get_entry("status_effects", id) as StatusEffect


func get_item(id: String) -> ItemResource:
	return get_entry("items", id) as ItemResource


func get_character(id: String) -> CharacterData:
	return get_entry("characters", id) as CharacterData


func get_mission(id: String) -> MissionResource:
	return get_entry("missions", id) as MissionResource


func get_loot_table(id: String) -> LootTable:
	return get_entry("loot_tables", id) as LootTable


func get_dispatch_mission(id: String) -> DispatchMission:
	return get_entry("dispatch_missions", id) as DispatchMission


func get_quest(id: String) -> QuestResource:
	return get_entry("quests", id) as QuestResource


func get_npc(id: String) -> NPCResource:
	return get_entry("npcs", id) as NPCResource


func get_map(id: String) -> Dictionary:
	var d: Dictionary = maps.get(id, {})
	if not bool(d.get("_stub", false)):
		return d
	var full := _read_dict(str(d["_path"]))
	if full.is_empty():
		return {}
	full["_path"] = d["_path"]
	maps[id] = full
	_big_loaded.erase(id)
	_big_loaded.append(id)
	while _big_loaded.size() > MAX_BIG_MAPS:
		var old: String = _big_loaded.pop_front()
		var od: Dictionary = maps.get(old, {})
		if od.has("_path"):
			var fa := FileAccess.open(str(od["_path"]), FileAccess.READ)
			if fa:
				maps[old] = _stub(old, str(od["_path"]), fa)
	return full


# --- Editor injection ------------------------------------------------------

## Adds or replaces one entry at runtime and persists it to user://content.
## This is the hook the Neon Forge editor (and AssetInjectionEditor) use.
func inject(bucket: String, entry: Dictionary, persist: bool = true) -> GameResource:
	if not CATALOG.has(bucket) or not entry.has("id"):
		push_error("ContentDB.inject: bad bucket or missing id")
		return null
	var res := _instantiate(bucket, entry)
	res.apply_dict(entry)
	_db[bucket][res.id] = res
	if persist:
		_persist_user_entry(bucket, res.to_dict())
	return res


func _persist_user_entry(bucket: String, entry: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var path := USER_DIR.path_join(bucket + ".json")
	var existing: Variant = _read_json(path)
	var arr: Array = existing if existing is Array else []
	var replaced := false
	for i in arr.size():
		if arr[i] is Dictionary and arr[i].get("id") == entry["id"]:
			arr[i] = entry
			replaced = true
	if not replaced:
		arr.append(entry)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null or not f.store_string(JSON.stringify(arr, "\t")):
		push_error("ContentDB: failed to write " + path)


## Cross-reference check used by tests and the editor's "validate" button.
func validate() -> Array[String]:
	var problems: Array[String] = []
	for cls: ClassResource in get_all("classes"):
		for aid in cls.innate_ability_ids + cls.learnable_ability_ids:
			if get_ability(aid) == null:
				problems.append("class %s -> missing ability %s" % [cls.id, aid])
		for req: String in cls.unlock_requirements:
			if get_class_res(req) == null:
				problems.append("class %s -> unknown prerequisite class %s" % [cls.id, req])
	for a: Ability in get_all("abilities"):
		if a.class_id != "" and get_class_res(a.class_id) == null:
			problems.append("ability %s -> unknown class %s" % [a.id, a.class_id])
		for sid in a.status_ids:
			if get_status(sid) == null:
				problems.append("ability %s -> missing status %s" % [a.id, sid])
		if a.class_id != "":
			var owner := get_class_res(a.class_id)
			if owner and not (owner.innate_ability_ids.has(a.id) or owner.learnable_ability_ids.has(a.id)):
				problems.append("ability %s says class %s but that class doesn't list it" % [a.id, a.class_id])
	for c: CharacterData in get_all("characters"):
		if get_class_res(c.class_id) == null:
			problems.append("character %s -> unknown class %s" % [c.id, c.class_id])
		for aid in c.learned_ability_ids:
			if get_ability(aid) == null:
				problems.append("character %s -> unknown ability %s" % [c.id, aid])
	for m: MissionResource in get_all("missions"):
		if m.map_id != "" and get_map(m.map_id).is_empty():
			problems.append("mission %s -> missing map %s" % [m.id, m.map_id])
		for e: Dictionary in m.enemies:
			if get_character(str(e.get("character_id", ""))) == null:
				problems.append("mission %s -> unknown enemy %s" % [m.id, e.get("character_id")])
		if m.loot_table_id != "" and get_loot_table(m.loot_table_id) == null:
			problems.append("mission %s -> missing loot table %s" % [m.id, m.loot_table_id])
	for lt: LootTable in get_all("loot_tables"):
		for e: Dictionary in lt.entries:
			if get_item(str(e.get("item_id", ""))) == null and get_card(str(e.get("item_id", ""))) == null:
				problems.append("loot table %s -> unknown item %s" % [lt.id, e.get("item_id")])
	for dm: DispatchMission in get_all("dispatch_missions"):
		if dm.loot_table_id != "" and get_loot_table(dm.loot_table_id) == null:
			problems.append("dispatch %s -> missing loot table %s" % [dm.id, dm.loot_table_id])
	for item: ItemResource in get_all("items"):
		for evo in item.evolves_into:
			if get_item(evo) == null:
				problems.append("item %s -> evolves into unknown %s" % [item.id, evo])
	for vid: String in vendors:
		for entry: Dictionary in vendors[vid].get("stock", []):
			var sid := str(entry.get("id", ""))
			if get_item(sid) == null and get_card(sid) == null:
				problems.append("vendor %s -> unknown stock %s" % [vid, sid])
	_validate_quests(problems)
	_validate_npcs(problems)
	return problems


func _validate_quests(problems: Array[String]) -> void:
	for q: QuestResource in get_all("quests"):
		if q.giver_npc_id != "" and get_npc(q.giver_npc_id) == null:
			problems.append("quest %s -> unknown giver %s" % [q.id, q.giver_npc_id])
		for pid in q.prerequisite_quest_ids:
			if get_quest(pid) == null:
				problems.append("quest %s -> unknown prerequisite quest %s" % [q.id, pid])
		for iid: String in q.reward_items:
			if get_item(iid) == null and get_card(iid) == null:
				problems.append("quest %s -> unknown reward item %s" % [q.id, iid])
		if q.next_quest_id != "" and get_quest(q.next_quest_id) == null:
			problems.append("quest %s -> unknown next quest %s" % [q.id, q.next_quest_id])
		for mid in q.unlocks_mission_ids:
			if get_mission(mid) == null:
				problems.append("quest %s -> unlocks unknown mission %s" % [q.id, mid])
		for o: Dictionary in q.objectives:
			var type := str(o.get("type", ""))
			var target := str(o.get("target", ""))
			if not QuestResource.OBJECTIVE_TYPES.has(type):
				problems.append("quest %s -> unknown objective type '%s'" % [q.id, type])
			elif type == "complete_mission" and get_mission(target) == null:
				problems.append("quest %s -> objective mission %s missing" % [q.id, target])
			elif type == "collect_item" and get_item(target) == null and get_card(target) == null:
				problems.append("quest %s -> objective item %s missing" % [q.id, target])
			elif type == "talk_to" and get_npc(target) == null:
				problems.append("quest %s -> objective npc %s missing" % [q.id, target])
			elif type == "defeat_character" and get_character(target) == null:
				problems.append("quest %s -> objective character %s missing" % [q.id, target])
			elif type == "find_loot" and not _map_prop_exists(target):
				problems.append("quest %s -> objective loot spot %s not on any map" % [q.id, target])


func _validate_npcs(problems: Array[String]) -> void:
	for n: NPCResource in get_all("npcs"):
		if n.vendor_id != "" and not vendors.has(n.vendor_id):
			problems.append("npc %s -> unknown vendor %s" % [n.id, n.vendor_id])
		if n.is_vendor and n.vendor_id == "":
			problems.append("npc %s -> is_vendor but no vendor_id" % n.id)
		if n.character_id != "" and get_character(n.character_id) == null:
			problems.append("npc %s -> unknown character %s" % [n.id, n.character_id])
		if n.fight_mission_id != "" and get_mission(n.fight_mission_id) == null:
			problems.append("npc %s -> unknown fight mission %s" % [n.id, n.fight_mission_id])
		for qid in n.quest_ids:
			if get_quest(qid) == null:
				problems.append("npc %s -> unknown quest %s" % [n.id, qid])
		var node_ids := {}
		for node: Dictionary in n.dialog:
			node_ids[str(node.get("id", ""))] = true
		for node: Dictionary in n.dialog:
			var nxt := str(node.get("next", ""))
			if nxt != "" and not node_ids.has(nxt):
				problems.append("npc %s dialog %s -> missing next %s" % [n.id, node.get("id"), nxt])
			for ch: Dictionary in node.get("choices", []):
				var cn := str(ch.get("next", ""))
				if cn != "" and not node_ids.has(cn):
					problems.append("npc %s dialog %s -> choice to missing %s" % [n.id, node.get("id"), cn])


## find_loot targets are InteractionTrigger ids, i.e. prop ids in data/maps.
func _map_prop_exists(prop_id: String) -> bool:
	for m: Dictionary in maps.values():
		if bool(m.get("_stub", false)):
			continue  # big world maps use objects / anchors, not legacy props
		for p: Variant in m.get("props", []):
			if p is Dictionary and str(p.get("id", "")) == prop_id:
				return true
	return false
