class_name ForgeIntake
extends AcceptDialog
## Drag-and-drop ASSET INTAKE wizard. Files dropped on the Neon Forge window
## (anywhere that isn't a character drop zone or a path field) open this popup
## instead of being copied silently. For each file (or numbered sequence) it asks:
##
##   1. TYPE  — tile, detail, structure, prop, character, item, portrait, UI,
##              VFX, music, SFX, voice, background (required)
##   2. NAME  — slugified into a unique id (files on disk, data/asset_index.json
##              and the matching ContentDB bucket are all checked)
##   3. ROLE  — type-specific extras: placement, tile set + terrain rule,
##              character role (playable / NPC / vendor / enemy / story / spell),
##              starting class + stats + loadout, item type, sheet layout...
##   4. SAVE  — COPIES the file (originals are never moved or touched) into the
##              right assets/ folder, writes the record to data/asset_index.json
##              and creates stub content (CharacterData, NPC, vendor, item, droid
##              chassis + build ability, Daemon Caller summon) where it applies.
##
## Numbered files (crater_1..crater_4) are detected and offered as ONE animated
## asset. "Apply to all remaining" reuses the answers for the rest of the queue.
## `start_edit(path)` re-opens the wizard for a file already in the project.
##
## The logic (build_queue / validate / commit) is UI-free so tests can drive it.

signal status(text: String, color: Color)
signal imported(record: Dictionary)
signal finished(count: int)

## [key, label]
const TYPES := [
	["tile", "Tile"], ["detail", "Detail / Decal (craters, debris, river overlays)"],
	["structure", "Structure / Building"], ["prop", "Prop"], ["character", "Character"],
	["item", "Item"], ["portrait", "Portrait"], ["ui", "UI"], ["vfx", "VFX sprite"],
	["music", "Music"], ["sfx", "SFX"], ["voice", "Voice"], ["background", "Background"],
]
const AUDIO_TYPES := ["music", "sfx", "voice"]
const ANIMATABLE := ["tile", "detail", "structure", "prop", "character", "item", "vfx"]
## Types that always land in one flat folder.
const TYPE_DIRS := {
	"detail": "res://assets/details", "item": "res://assets/items", "ui": "res://assets/ui",
	"vfx": "res://assets/vfx", "music": "res://assets/music", "sfx": "res://assets/sfx",
	"voice": "res://assets/voice", "background": "res://assets/backgrounds",
}
const TILES_DIR := "res://assets/tiles"
const PLACEMENTS := [["outdoor", "Outdoor"], ["indoor", "Indoor"], ["both", "Both"]]
const CHARACTER_ROLES := [
	["playable", "Playable"], ["npc", "NPC"], ["vendor", "Vendor"], ["enemy", "Enemy"],
	["story", "Story character"], ["spell", "Spell (droid / summon)"], ["other", "Other"],
]
const SPELL_KINDS := [["droid", "Droid (Droid Master builds it)"], ["summon", "Summon (Daemon Caller calls it)"]]
const ITEM_TYPES := [
	["", "Decide later"], ["status_remover", "Status remover"], ["booster", "Booster"],
	["crafting_material", "Crafting material"], ["weapon", "Weapon"], ["gear", "Gear"],
	["key_item", "Key item (quest)"],
]
const ITEM_CATEGORY := {
	"": "MATERIAL", "status_remover": "CONSUMABLE", "booster": "CONSUMABLE",
	"crafting_material": "MATERIAL", "weapon": "WEAPON", "gear": "ARMOR", "key_item": "KEY",
}
const ANIM_MODES := ["loop", "pingpong", "once"]
const STAT_KEYS := ["strength", "agility", "intelligence", "vitality", "level"]
const LOADOUT_SLOTS := {"weapon": ["WEAPON"], "armor": ["ARMOR"], "accessory": ["ACCESSORY", "TRINKET"]}
const SUMMONER_CLASS := "daemon_caller"
const DROID_CLASS := "droid_master"
const DROID_TEMPLATE_CLASS := "droid_assault_chassis"

## Pending assets: {"files": Array[String], "sequence": bool}.
var queue: Array[Dictionary] = []
var current: int = 0
## The answers for queue[current] (see default_fields()).
var fields: Dictionary = {}
## Editing a file already inside res:// (no copy).
var edit_path: String = ""
var saved_count: int = 0

var _edit_id: String = ""
var _edit_record: Dictionary = {}
var _header: Label
var _preview: TextureRect
var _preview_info: Label
var _audio_box: HBoxContainer
var _player: AudioStreamPlayer
var _form: VBoxContainer
var _error: Label
var _apply_all: CheckBox
var _anim_timer: Timer
var _anim_frame: int = 0
var _built: bool = false
var _done: bool = false


# --- Public API ------------------------------------------------------------

## Opens the wizard for OS files (absolute paths) dropped on the window.
func start(files: PackedStringArray) -> void:
	edit_path = ""
	_edit_id = ""
	_edit_record = {}
	queue = build_queue(files)
	current = 0
	_show_current()
	popup_centered(Vector2i(1060, 700))


## Re-opens the intake for a file already in the project (Assets inspector).
func start_edit(res_path: String) -> void:
	edit_path = res_path
	queue = [{"files": [res_path], "sequence": false}]
	current = 0
	_edit_record = AssetIndex.find_by_path(res_path)
	_edit_id = str(_edit_record.get("id", ""))
	_edit_record.erase("id")
	_show_current()
	popup_centered(Vector2i(1060, 700))


## Groups files into queue items; numbered runs with the same stem, folder and
## extension (ocean_1..ocean_4) become one "sequence" item, sorted by number.
static func build_queue(files: PackedStringArray) -> Array[Dictionary]:
	var groups := {}
	var order: Array[String] = []
	for f in files:
		var seq := AssetIndex.sequence_key(f.get_file().get_basename())
		var key := f if seq.is_empty() else "%s|%s|%s" % [f.get_base_dir(), str(seq[0]).to_lower(), f.get_extension().to_lower()]
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append(f)
	var out: Array[Dictionary] = []
	for key in order:
		var list: Array = groups[key]
		if list.size() > 1:
			list.sort_custom(func(a: String, b: String) -> bool:
				return int(AssetIndex.sequence_key(a.get_file().get_basename())[1]) < int(AssetIndex.sequence_key(b.get_file().get_basename())[1]))
			var seq_files: Array[String] = []
			seq_files.assign(list)
			out.append({"files": seq_files, "sequence": true})
		else:
			var single: Array[String] = [str(list[0])]
			out.append({"files": single, "sequence": false})
	return out


## Starting answers for a queue item: name from the file (or sequence stem),
## audio pre-set to SFX, sequences pre-set to animated + combined.
static func default_fields(item: Dictionary) -> Dictionary:
	var first: String = item["files"][0]
	var stem := first.get_file().get_basename()
	if item.get("sequence", false):
		stem = str(AssetIndex.sequence_key(stem)[0])
	var is_audio := first.get_extension().to_lower() in ForgeStore.AUDIO_EXT
	return {
		"type": "sfx" if is_audio else "",
		"name": stem.replace("_", " ").replace("-", " ").strip_edges().capitalize(),
		"placement": "outdoor", "animated": bool(item.get("sequence", false)), "combine": true,
		"tile_set": "", "new_set": "", "terrain": "",
		"role": "", "sub_role": "", "class_id": "", "stats": {},
		"loadout": {"weapon": "", "armor": "", "accessory": ""},
		"item_type": "", "portrait_of": "",
		"hframes": 1, "vframes": 1, "fps": 8, "mode": "loop",
	}


## "" when the answers can be saved, otherwise what's missing.
func validate(item: Dictionary, f: Dictionary) -> String:
	var type := str(f.get("type", ""))
	if type == "":
		return "Pick an asset TYPE first."
	if str(f.get("name", "")).strip_edges() == "" or ForgeStore.slugify(str(f.get("name", ""))) == "":
		return "Give it a NAME (letters or numbers)."
	var is_audio := str(item["files"][0]).get_extension().to_lower() in ForgeStore.AUDIO_EXT
	if is_audio and type not in AUDIO_TYPES:
		return "That's an audio file — pick Music, SFX or Voice."
	if not is_audio and type in AUDIO_TYPES:
		return "That's an image — audio types need an audio file."
	match type:
		"tile":
			if _tile_set(f) == "":
				return "Pick a tile SET (or type a new one)."
		"character":
			var role := str(f.get("role", ""))
			if role == "":
				return "Pick the character's ROLE."
			if role == "spell" and str(f.get("sub_role", "")) == "":
				return "Spell: is it a Droid or a Summon?"
			if role in ["playable", "enemy"] and ContentDB.get_class_res(str(f.get("class_id", ""))) == null:
				return "Pick a starting CLASS."
	if bool(f.get("animated", false)) and (int(f.get("hframes", 1)) < 1 or int(f.get("vframes", 1)) < 1 or float(f.get("fps", 0)) <= 0):
		return "Sheet layout needs hframes/vframes ≥ 1 and fps > 0."
	return ""


## Saves one queue item with answers `f`: copies files, writes the index entry,
## creates content stubs. Returns the index record (+ "id"), or {"error": msg}.
func commit(item: Dictionary, f: Dictionary) -> Dictionary:
	var err := validate(item, f)
	if err != "":
		return {"error": err}
	var type := str(f["type"])
	var role := str(f.get("role", ""))
	var index := AssetIndex.load()
	var id := _edit_id
	if id == "":
		id = AssetIndex.unique_id(str(f["name"]), _bucket_for(type, f), _unique_dir(type, f), index)
	var src_files: Array = item["files"]
	var combine: bool = bool(item.get("sequence", false)) and bool(f.get("combine", true))
	var paths: Array[String] = []
	if edit_path != "":
		paths.append(edit_path)
		var old_anim: Variant = _edit_record.get("anim")
		if old_anim is Dictionary and not (old_anim.get("frames", []) as Array).is_empty():
			paths.assign(old_anim["frames"])
	else:
		var dir := dest_dir(type, f, id)
		DirAccess.make_dir_recursive_absolute(dir)
		var to_copy: Array = src_files if combine else [src_files[0]]
		for i in to_copy.size():
			var src := str(to_copy[i])
			var ext := src.get_extension().to_lower()
			var dest := dir.path_join(("%s_%d.%s" % [id, i + 1, ext]) if combine else ("%s.%s" % [id, ext]))
			var cerr := DirAccess.copy_absolute(_os_path(src), ProjectSettings.globalize_path(dest))
			if cerr != OK:
				return {"error": "Copy failed: %s (%s)" % [src.get_file(), error_string(cerr)]}
			paths.append(dest)
	var record := {
		"path": paths[0], "type": type, "name": str(f["name"]).strip_edges(),
		"source": str(src_files[0]).get_file(),
	}
	if _edit_record.is_empty():
		record["created"] = Time.get_datetime_string_from_system(true)
	else:
		record["updated"] = Time.get_datetime_string_from_system(true)
	match type:
		"prop", "structure":
			record["placement"] = str(f.get("placement", "outdoor"))
		"tile":
			record["set"] = _tile_set(f)
			record["group"] = _tile_set(f)
			if str(f.get("terrain", "")) != "":
				record["terrain"] = str(f["terrain"])
		"character":
			record["role"] = role
			if role == "spell":
				record["sub_role"] = str(f.get("sub_role", ""))
			if str(f.get("class_id", "")) != "":
				record["class_id"] = str(f["class_id"])
		"item":
			record["role"] = str(f.get("item_type", "")) if str(f.get("item_type", "")) != "" else "pending"
		"portrait":
			if str(f.get("portrait_of", "")) != "":
				record["character_id"] = str(f["portrait_of"])
	if type in ANIMATABLE:
		record["animated"] = bool(f.get("animated", false)) or combine
	if record.get("animated", false):
		var frames: Array = paths.duplicate() if paths.size() > 1 else []
		record["anim"] = {
			"frames": frames, "hframes": int(f.get("hframes", 1)), "vframes": int(f.get("vframes", 1)),
			"fps": float(f.get("fps", 8)), "mode": str(f.get("mode", "loop")),
		}
	var links: Dictionary = _edit_record.get("links", {}).duplicate()
	if links.is_empty():
		links = _create_content(id, type, f, paths[0])
	if not links.is_empty():
		record["links"] = links
	if not AssetIndex.add(id, record):
		return {"error": "Couldn't write %s" % AssetIndex.index_path()}
	record["id"] = id
	saved_count += 1
	status.emit("INTAKE ▸ %s saved as '%s' → %s%s" % [record["source"], id, paths[0].get_base_dir(),
		("  (+ %s)" % ", ".join(links.values())) if not links.is_empty() else ""], NeonTheme.GREEN)
	imported.emit(record)
	return record


## Where a type's files land (character / portrait folders are per id).
func dest_dir(type: String, f: Dictionary, id: String) -> String:
	match type:
		"tile":
			return _join(TILES_DIR, _tile_set(f))
		"structure":
			return _join("res://assets/structures", str({"indoor": "interior", "outdoor": "exterior"}.get(str(f.get("placement", "")), "")))
		"prop":
			return _join("res://assets/props", str({"indoor": "indoor", "outdoor": "outdoor"}.get(str(f.get("placement", "")), "")))
		"character":
			return _join("res://assets/units", id)
		"portrait":
			var owner := str(f.get("portrait_of", ""))
			return _join("res://assets/portraits", owner if owner != "" else id)
	return str(TYPE_DIRS.get(type, "res://assets/ui"))


## Existing tile sets: every folder under assets/tiles, e.g. "god_tiles/water".
static func tile_sets() -> Array[String]:
	var out: Array[String] = []
	_collect_dirs(TILES_DIR, "", out)
	out.sort()
	return out


static func _collect_dirs(root: String, rel: String, out: Array[String]) -> void:
	var dir := root.path_join(rel) if rel != "" else root
	if not DirAccess.dir_exists_absolute(dir):
		return
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with("."):
			continue
		var sub := rel.path_join(d) if rel != "" else d
		out.append(sub)
		_collect_dirs(root, sub, out)


## Terrain rules for tiles: data/terrain.json keys plus "water".
static func terrain_rules() -> Array[String]:
	var out: Array[String] = []
	out.assign(ContentDB.terrain.keys())
	if not out.has("water"):
		out.append("water")
	return out


## Primary stats seeded from a class's multipliers (10 × multiplier, level 1).
static func class_stats(class_id: String) -> Dictionary:
	var cls := ContentDB.get_class_res(class_id)
	var out := {"strength": 10, "agility": 10, "intelligence": 10, "vitality": 10, "level": 1}
	if cls:
		for k: String in UnitStats.PRIMARY:
			out[k] = roundi(10.0 * cls.get_multiplier(k))
	return out


## Item ids that fit `slot` (weapon / armor / accessory) for class `class_id`.
static func items_for_slot(slot: String, class_id: String) -> Array[String]:
	var cls := ContentDB.get_class_res(class_id)
	var cats: Array = LOADOUT_SLOTS.get(slot, [])
	var out: Array[String] = []
	for it: ItemResource in ContentDB.get_all("items"):
		var cat: String = ItemResource.Category.keys()[it.category]
		if not cats.has(cat):
			continue
		if cls and slot == "weapon" and not cls.weapon_types.is_empty() and not cls.weapon_types.has(it.equip_type):
			continue
		if cls and slot == "armor" and it.equip_type != "" and not cls.armor_types.has(it.equip_type):
			continue
		out.append(it.id)
	return out


# --- Content stubs ----------------------------------------------------------

func _bucket_for(type: String, f: Dictionary) -> String:
	match type:
		"item":
			return "items"
		"character":
			match str(f.get("role", "")):
				"npc", "vendor":
					return "npcs"
				"spell":
					return "characters" if str(f.get("sub_role", "")) == "droid" else "abilities"
				_:
					return "characters"
	return ""


## Folder whose existing names (files and sub folders) the id must also avoid.
func _unique_dir(type: String, f: Dictionary) -> String:
	match type:
		"character":
			return "res://assets/units"
		"portrait":
			return _join("res://assets/portraits", str(f.get("portrait_of", "")))
	return dest_dir(type, f, "")


static func _join(base: String, sub: String) -> String:
	return base if sub == "" else base.path_join(sub)


## Creates the ContentDB records this asset implies and saves their files.
## Returns {kind: id} links for the index entry.
func _create_content(id: String, type: String, f: Dictionary, path: String) -> Dictionary:
	var links := {}
	var nice := str(f["name"]).strip_edges()
	match type:
		"character":
			match str(f.get("role", "")):
				"npc", "vendor":
					links.merge(_create_npc(id, nice, path, str(f["role"]) == "vendor"))
				"spell":
					if str(f.get("sub_role", "")) == "droid":
						links.merge(_create_droid(id, nice, path, f))
					else:
						links.merge(_create_summon(id, nice, path))
				_:
					links["character"] = _create_character(id, nice, path, f)
		"item":
			links["item"] = _create_item(id, nice, path, str(f.get("item_type", "")))
		"portrait":
			var c := ContentDB.get_character(str(f.get("portrait_of", "")))
			if c:
				c.portrait_path = path
				ForgeStore.save_bucket("characters")
				links["character"] = c.id
	return links


func _create_character(id: String, nice: String, path: String, f: Dictionary) -> String:
	var role := str(f.get("role", ""))
	var c := CharacterData.new()
	c.id = id
	c.display_name = nice
	c.class_id = str(f.get("class_id", "")) if ContentDB.get_class_res(str(f.get("class_id", ""))) else ClassLibrary.DEFAULT_CLASS
	c.team = 1 if role == "enemy" else 0
	c.is_unique = role != "enemy"
	c.ai_behavior = "aggressive" if role == "enemy" else "tactical"
	c.sprite_sheet_path = path
	c.bio = "Arrived through the Forge intake. Backstory pending; vibes confirmed."
	var stats: Dictionary = f.get("stats", {})
	c.base_stats = stats.duplicate() if not stats.is_empty() else class_stats(c.class_id)
	var gear: Dictionary = f.get("loadout", {})
	for slot: String in gear:
		if str(gear[slot]) != "":
			c.equipment[slot] = str(gear[slot])
	ForgeStore.put_entry("characters", c)
	ForgeStore.save_bucket("characters")
	return c.id


func _create_npc(id: String, nice: String, path: String, vendor: bool) -> Dictionary:
	var n := NPCResource.new()
	n.id = id
	n.display_name = nice
	n.sprite_path = path
	n.description = "Fresh off the Forge intake. Personality not yet installed."
	n.dialog.assign([
		{"id": "greet", "text": "Oh. You can see me? Nobody's written my lines yet.", "next": "wait"},
		{"id": "wait", "text": "I'm told I'll be very important. Or a lamp. The ticket said 'TBD'.", "next": "bye"},
		{"id": "bye", "text": "Come back after the next content patch."},
	])
	n.eavesdrop_lines.assign([
		{"text": "'…placeholder, placeholder, placeholder…'"},
		{"text": "'Does anyone know what my motivation is?'"},
		{"text": "'I was imported. It was cold.'"},
	])
	var links := {"npc": id}
	if vendor:
		var vid := id
		var n2 := 2
		while ContentDB.vendors.has(vid):
			vid = "%s_%d" % [id, n2]
			n2 += 1
		n.is_vendor = true
		n.vendor_id = vid
		ContentDB.vendors[vid] = {"name": nice, "greeting": "Browse. Don't lick anything.", "price_mult": 1.0, "character_id": "", "stock": []}
		ForgeStore.save_dict_file("vendors", ContentDB.vendors)
		links["vendor"] = vid
	ForgeStore.put_entry("npcs", n)
	ForgeStore.save_bucket("npcs")
	return links


## Droid Master droid: chassis class + AI-driven character + a build ability
## the Droid Master can learn (special summon_droid → params.character_id).
func _create_droid(id: String, nice: String, path: String, f: Dictionary) -> Dictionary:
	var chassis := ClassResource.new()
	var template := ContentDB.get_class_res(DROID_TEMPLATE_CLASS)
	if template:
		chassis.apply_dict(template.to_dict())
	chassis.id = ForgeStore.unique_id("classes", id + "_chassis")
	chassis.display_name = nice
	chassis.description = "Built by a Droid Master. Stub from the Forge intake."
	chassis.playable = false
	ForgeStore.put_entry("classes", chassis)
	var c := CharacterData.new()
	c.id = id
	c.display_name = nice
	c.class_id = chassis.id
	c.team = 0
	c.is_unique = false
	c.ai_controlled = true
	c.ai_behavior = "aggressive"
	c.sprite_sheet_path = path
	c.bio = "Built on the field."
	var stats: Dictionary = f.get("stats", {})
	c.base_stats = stats.duplicate() if not stats.is_empty() else class_stats(chassis.id)
	ForgeStore.put_entry("characters", c)
	var build := Ability.new()
	build.apply_dict({
		"id": ForgeStore.unique_id("abilities", "build_" + id), "display_name": "Build: " + nice,
		"class_id": DROID_CLASS, "kind": "UTILITY", "target": "TILE", "special": "summon_droid",
		"description": "Bolts together a %s. (Forge intake stub — tune the numbers.)" % nice,
		"params": {"character_id": id, "max_active": 2}, "mp_cost": 14, "range_min": 1, "range_max": 2,
		"ap_cost": 2, "chip_cost": 2, "icon_path": path,
	})
	ForgeStore.put_entry("abilities", build)
	var master := ContentDB.get_class_res(DROID_CLASS)
	if master and not master.learnable_ability_ids.has(build.id):
		master.learnable_ability_ids.append(build.id)
	for bucket in ["classes", "characters", "abilities"]:
		ForgeStore.save_bucket(bucket)
	return {"class": chassis.id, "character": id, "ability": build.id}


## Daemon Caller summon: an all-enemies call with the sprite as its art.
func _create_summon(id: String, nice: String, path: String) -> Dictionary:
	var summon := Ability.new()
	summon.apply_dict({
		"id": ForgeStore.unique_id("abilities", "call_" + id), "display_name": "Call: " + nice.to_upper(),
		"class_id": SUMMONER_CLASS, "kind": "MAGIC", "target": "TILE", "shape": "DIAMOND", "aoe_radius": 30,
		"range_min": 0, "range_max": 0, "power": 1.3, "scaling_stat": "magic", "damage_type": "tech",
		"mp_cost": 32, "charge_ticks": 3, "chip_cost": 4, "required_class_level": 5,
		"description": "%s answers the call. (Forge intake stub — pick its element and numbers.)" % nice,
		"icon_path": path, "params": {"summon_art": path},
	})
	ForgeStore.put_entry("abilities", summon)
	var caller := ContentDB.get_class_res(SUMMONER_CLASS)
	if caller and not caller.learnable_ability_ids.has(summon.id):
		caller.learnable_ability_ids.append(summon.id)
	ForgeStore.save_bucket("abilities")
	ForgeStore.save_bucket("classes")
	return {"ability": summon.id}


func _create_item(id: String, nice: String, path: String, item_type: String) -> String:
	var it := ItemResource.new()
	it.apply_dict({"id": id, "display_name": nice, "category": ITEM_CATEGORY.get(item_type, "MATERIAL"), "icon_path": path, "value": 50})
	match item_type:
		"":
			it.tags.append("intake_pending")
			it.description = "Type undecided (intake_pending). Find it under the 'intake_pending' tag."
		"status_remover":
			it.tags.append("status_remover")
			it.cure_status_ids.assign(["poisoned", "asleep", "blinded"])
		"booster":
			it.tags.append("booster")
		"key_item":
			it.value = 0
	ForgeStore.put_entry("items", it)
	ForgeStore.save_bucket("items")
	return id


static func _tile_set(f: Dictionary) -> String:
	var new_set := str(f.get("new_set", "")).strip_edges()
	if new_set != "":
		var parts: Array[String] = []
		for p in new_set.split("/", false):
			var s := ForgeStore.slugify(p)
			if s != "":
				parts.append(s)
		return "/".join(parts)
	return str(f.get("tile_set", ""))


static func _os_path(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") or p.begins_with("user://") else p


# --- UI ----------------------------------------------------------------------

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if _built:
		return
	_built = true
	title = "ASSET INTAKE"
	theme = NeonTheme.get_theme()
	add_theme_stylebox_override("panel", NeonTheme.panel_box(Color(NeonTheme.GREEN, 0.8), Color(0.03, 0.015, 0.06, 1.0)))
	dialog_hide_on_ok = false
	ok_button_text = "SAVE ▸ NEXT"
	add_button("SKIP", true, "skip")
	add_cancel_button("CLOSE")
	custom_action.connect(func(action: StringName) -> void:
		if action == &"skip":
			_advance())
	confirmed.connect(_on_save)
	canceled.connect(_finish)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 400
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)
	_header = NeonTheme.label("", 22, NeonTheme.GREEN)
	left.add_child(_header)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", NeonTheme.panel_box(Color(NeonTheme.CYAN, 0.5), Color(0, 0, 0, 0.5)))
	left.add_child(frame)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(380, 380)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_preview)
	_preview_info = NeonTheme.label("", 13, NeonTheme.TEXT_DIM)
	_preview_info.add_theme_font_override("font", NeonTheme.mono())
	_preview_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	left.add_child(_preview_info)
	_audio_box = HBoxContainer.new()
	left.add_child(_audio_box)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	for spec in [["▶  PLAY", _play], ["■  STOP", _player.stop]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		_audio_box.add_child(b)
	var note := NeonTheme.label("Files are COPIED into assets/. Your originals stay exactly where they are.", 12, NeonTheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(note)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(560, 560)
	right.add_child(scroll)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 8)
	scroll.add_child(_form)
	_error = NeonTheme.label("", 14, NeonTheme.MAGENTA)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_error)
	_apply_all = CheckBox.new()
	_apply_all.text = "Apply these answers to all remaining files"
	right.add_child(_apply_all)
	_anim_timer = Timer.new()
	_anim_timer.timeout.connect(_tick_preview)
	add_child(_anim_timer)


func _item() -> Dictionary:
	return queue[current] if current < queue.size() else {}


func _show_current() -> void:
	_build_ui()
	if current >= queue.size():
		_finish()
		return
	var item := _item()
	fields = default_fields(item)
	if edit_path != "" and not _edit_record.is_empty():
		_prefill_from_record(_edit_record)
	var files: Array = item["files"]
	var what: String = str(files[0]).get_file() if files.size() == 1 else "%s … (%d numbered frames)" % [str(files[0]).get_file(), files.size()]
	_header.text = ("EDIT INTAKE" if edit_path != "" else "INTAKE  %d / %d" % [current + 1, queue.size()])
	_preview_info.text = what
	_apply_all.visible = queue.size() - current > 1
	_error.text = ""
	_render_form()
	_update_preview()


func _prefill_from_record(rec: Dictionary) -> void:
	for k in ["type", "name", "placement", "role", "sub_role", "class_id", "terrain"]:
		if rec.has(k):
			fields[k] = rec[k]
	if rec.has("set"):
		fields["tile_set"] = rec["set"]
	if str(rec.get("type", "")) == "item" and str(rec.get("role", "")) != "pending":
		fields["item_type"] = rec.get("role", "")
	fields["portrait_of"] = rec.get("character_id", "")
	var anim: Variant = rec.get("anim")
	if anim is Dictionary:
		fields["animated"] = true
		for k in ["hframes", "vframes", "fps", "mode"]:
			if anim.has(k):
				fields[k] = anim[k]


func _on_save() -> void:
	var item := _item()
	if item.is_empty():
		_finish()
		return
	var res := commit(item, fields)
	if res.has("error"):
		_error.text = "⚠ " + str(res["error"])
		return
	if _apply_all.button_pressed and _apply_all.visible:
		var shared := fields.duplicate(true)
		for i in range(current + 1, queue.size()):
			var f := shared.duplicate(true)
			var d := default_fields(queue[i])
			f["name"] = d["name"]
			f["animated"] = bool(shared.get("animated", false)) or bool(queue[i].get("sequence", false))
			var r := commit(queue[i], f)
			if r.has("error"):
				status.emit("INTAKE ▸ skipped %s: %s" % [str(queue[i]["files"][0]).get_file(), r["error"]], NeonTheme.MAGENTA)
		current = queue.size()
	_advance()


func _advance() -> void:
	current += 1
	_player.stop()
	if current >= queue.size():
		_finish()
	else:
		_show_current()


func _finish() -> void:
	if _done:
		return
	_done = true
	_anim_timer.stop()
	_player.stop()
	hide()
	finished.emit(saved_count)
	queue_free()


# --- Form ------------------------------------------------------------------

func _render_form() -> void:
	for c in _form.get_children():
		c.queue_free()
	var type := str(fields.get("type", ""))
	var item := _item()
	_section("1 · WHAT IS IT?")
	var guess := _guess_type(str(item["files"][0]))
	var type_opts: Array = [["", "— pick a type —" + (" (looks like: %s)" % guess if guess != "" else "")]] + TYPES
	_add(_row("TYPE", _option("type", type_opts, true)))
	_section("2 · NAME")
	var name_edit := LineEdit.new()
	name_edit.text = str(fields.get("name", ""))
	var id_label := NeonTheme.label("", 12, NeonTheme.GREEN)
	id_label.add_theme_font_override("font", NeonTheme.mono())
	var refresh_id := func() -> void:
		id_label.text = "id ▸ " + (_edit_id if _edit_id != "" else AssetIndex.unique_id(str(fields["name"]), _bucket_for(type, fields), _unique_dir(type, fields)))
	name_edit.text_changed.connect(func(t: String) -> void:
		fields["name"] = t
		refresh_id.call())
	_add(_row("NAME", name_edit))
	_add(id_label)
	refresh_id.call()
	if bool(item.get("sequence", false)) and edit_path == "":
		_section("NUMBERED SEQUENCE")
		var cb := CheckBox.new()
		cb.text = "Combine these %d frames into ONE animated asset" % (item["files"] as Array).size()
		cb.button_pressed = bool(fields.get("combine", true))
		cb.toggled.connect(func(v: bool) -> void:
			fields["combine"] = v
			if not v:
				_split_current())
		_add(cb)
	if type == "":
		return
	_section("3 · DETAILS")
	match type:
		"prop", "structure":
			_add(_row("PLACEMENT", _option("placement", PLACEMENTS, true)))
		"tile":
			var sets: Array = [["", "(pick a set)"]]
			for s in tile_sets():
				sets.append([s, s])
			_add(_row("TILE SET", _option("tile_set", sets, false)))
			var new_set := LineEdit.new()
			new_set.placeholder_text = "…or a NEW set, e.g. god_tiles/water"
			new_set.text = str(fields.get("new_set", ""))
			new_set.text_changed.connect(func(t: String) -> void: fields["new_set"] = t)
			_add(_row("NEW SET", new_set))
			var rules: Array = [["", "(none)"]]
			for r in terrain_rules():
				rules.append([r, r])
			_add(_row("TERRAIN RULE", _option("terrain", rules, false)))
		"character":
			_character_form()
		"item":
			_add(_row("ITEM TYPE", _option("item_type", ITEM_TYPES, false)))
		"portrait":
			var chars: Array = [["", "(no character yet)"]]
			for c: CharacterData in ContentDB.get_all("characters"):
				chars.append([c.id, "%s  ·  %s" % [c.display_name, c.id]])
			_add(_row("PORTRAIT OF", _option("portrait_of", chars, true)))
	if type in ANIMATABLE:
		_add(_check("animated", "Is animated", true))
		if bool(fields.get("animated", false)):
			_anim_form()


func _character_form() -> void:
	_add(_row("ROLE", _option("role", CHARACTER_ROLES, true)))
	var role := str(fields.get("role", ""))
	if role == "spell":
		_add(_row("SPELL KIND", _option("sub_role", SPELL_KINDS, true)))
		var hint := NeonTheme.label("Droid → chassis class + character + 'Build:' ability for the Droid Master.\nSummon → 'Call:' ability for the Daemon Caller using this art.", 12, NeonTheme.TEXT_DIM)
		_add(hint)
	if role in ["playable", "enemy"]:
		var classes: Array = [["", "(pick a class)"]]
		for c: ClassResource in ContentDB.get_all("classes"):
			if c.playable or role == "enemy":
				classes.append([c.id, "%s  ·  %s" % [c.display_name, c.role_name()]])
		var ob := _option("class_id", classes, true)
		# Runs after _option's handler set class_id; the re-render is deferred.
		ob.item_selected.connect(func(_i: int) -> void: fields["stats"] = class_stats(str(fields["class_id"])))
		_add(_row("CLASS", ob))
		var cls := ContentDB.get_class_res(str(fields.get("class_id", "")))
		if cls:
			if (fields.get("stats", {}) as Dictionary).is_empty():
				fields["stats"] = class_stats(cls.id)
			var info := NeonTheme.label("HP %d (+%d/lv) · MP %d (+%d/lv) · SPD %d · MOVE %d · JUMP %d" % [cls.base_hp, cls.hp_growth, cls.base_mp, cls.mp_growth, cls.base_speed, cls.move, cls.jump], 12, NeonTheme.CYAN)
			info.add_theme_font_override("font", NeonTheme.mono())
			_add(info)
			var grid := GridContainer.new()
			grid.columns = STAT_KEYS.size()
			var stats: Dictionary = fields["stats"]
			for k: String in STAT_KEYS:
				grid.add_child(NeonTheme.label(k.substr(0, 3).to_upper(), 11, NeonTheme.TEXT_DIM))
			for k: String in STAT_KEYS:
				var key := k
				var sb := ForgeForm._spin(float(stats.get(k, 10)), true, func(v: float) -> void: stats[key] = int(v))
				sb.custom_minimum_size.x = 84
				grid.add_child(sb)
			_add(grid)
			var loadout: Dictionary = fields["loadout"]
			for slot: String in LOADOUT_SLOTS:
				var opts: Array = [["", "(none)"]]
				for iid in items_for_slot(slot, cls.id):
					var it := ContentDB.get_item(iid)
					opts.append([iid, "%s  ·  %s" % [it.display_name, iid]])
				var s := slot
				var pick := ForgeForm._option(opts.map(func(o: Array) -> String: return str(o[0])), str(loadout.get(slot, "")), func(v: String) -> void: loadout[s] = v)
				for i in opts.size():
					pick.set_item_text(i, opts[i][1])
				_add(_row(slot.to_upper(), pick))


func _anim_form() -> void:
	_section("SHEET LAYOUT")
	var h := HBoxContainer.new()
	for spec in [["hframes", "H FRAMES"], ["vframes", "V FRAMES"], ["fps", "FPS"]]:
		var key: String = spec[0]
		h.add_child(NeonTheme.label(spec[1], 11, NeonTheme.TEXT_DIM))
		var sb := ForgeForm._spin(float(fields.get(key, 1)), key != "fps", func(v: float) -> void:
			fields[key] = int(v) if key != "fps" else v
			_update_preview())
		sb.custom_minimum_size.x = 80
		h.add_child(sb)
	_add(h)
	var modes: Array = []
	for m in ANIM_MODES:
		modes.append([m, m])
	_add(_row("MODE", _option("mode", modes, false)))


func _split_current() -> void:
	var item := _item()
	var singles: Array[Dictionary] = []
	for f: String in item["files"]:
		var one: Array[String] = [f]
		singles.append({"files": one, "sequence": false})
	queue.remove_at(current)
	for i in singles.size():
		queue.insert(current + i, singles[i])
	_show_current.call_deferred()


func _section(text: String) -> void:
	var l := NeonTheme.label(text, 13, NeonTheme.VIOLET)
	l.add_theme_font_override("font", NeonTheme.mono())
	_form.add_child(l)


func _add(c: Control) -> void:
	_form.add_child(c)


func _row(label: String, widget: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := NeonTheme.label(label, 12, NeonTheme.TEXT_DIM)
	l.custom_minimum_size.x = 130
	row.add_child(l)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(widget)
	return row


## Dropdown bound to fields[key]; options are [value, label] pairs.
func _option(key: String, options: Array, rerender: bool) -> OptionButton:
	var ob := OptionButton.new()
	var current_val := str(fields.get(key, ""))
	for o: Array in options:
		ob.add_item(str(o[1]))
	ob.selected = maxi(options.map(func(o: Array) -> String: return str(o[0])).find(current_val), 0)
	ob.item_selected.connect(func(i: int) -> void:
		fields[key] = str(options[i][0])
		if rerender:
			_render_form.call_deferred()
		_update_preview())
	return ob


func _check(key: String, text: String, rerender: bool) -> CheckButton:
	var cb := CheckButton.new()
	cb.text = text
	cb.button_pressed = bool(fields.get(key, false))
	cb.toggled.connect(func(v: bool) -> void:
		fields[key] = v
		if v and key == "animated" and int(fields.get("hframes", 1)) == 1:
			_guess_sheet()
		if rerender:
			_render_form.call_deferred()
		_update_preview())
	return cb


## Wide strips of square frames: guess hframes = width / height.
func _guess_sheet() -> void:
	var item := _item()
	if item.is_empty() or (item["files"] as Array).size() > 1:
		return
	var tex := ForgeStore.load_texture(str(item["files"][0]))
	if tex and tex.get_height() > 0 and tex.get_width() >= tex.get_height() * 2 and tex.get_width() % tex.get_height() == 0:
		fields["hframes"] = roundi(tex.get_width() / float(tex.get_height()))


static func _guess_type(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext in ForgeStore.AUDIO_EXT:
		return "SFX"
	var lower := path.to_lower()
	for pair: Array in [["portrait", "Portrait"], ["tile", "Tile"], ["crater", "Detail / Decal"], ["river", "Detail / Decal"],
			["debris", "Detail / Decal"], ["building", "Structure"], ["tower", "Structure"], ["icon", "Item"], ["bg", "Background"],
			["background", "Background"], ["music", "Music"], ["vfx", "VFX sprite"], ["sheet", "Character"]]:
		if lower.get_file().contains(pair[0]):
			return pair[1]
	return ""


# --- Preview -----------------------------------------------------------------

func _update_preview() -> void:
	if _preview == null:
		return
	var item := _item()
	if item.is_empty():
		return
	var first := str(item["files"][0])
	var is_audio := first.get_extension().to_lower() in ForgeStore.AUDIO_EXT
	_audio_box.visible = is_audio
	_preview.get_parent().visible = not is_audio
	_anim_timer.stop()
	_anim_frame = 0
	if is_audio:
		return
	_tick_preview()
	var frames := _frame_count()
	if frames > 1:
		_anim_timer.wait_time = 1.0 / maxf(float(fields.get("fps", 8)), 1.0)
		_anim_timer.start()


func _frame_count() -> int:
	var item := _item()
	if bool(item.get("sequence", false)) and bool(fields.get("combine", true)):
		return (item["files"] as Array).size()
	if bool(fields.get("animated", false)):
		return maxi(int(fields.get("hframes", 1)) * int(fields.get("vframes", 1)), 1)
	return 1


## Shows frame `_anim_frame` (sequence file or sheet cell) and advances.
func _tick_preview() -> void:
	var item := _item()
	if item.is_empty():
		return
	var files: Array = item["files"]
	var count := _frame_count()
	var f := _anim_frame % maxi(count, 1)
	if bool(item.get("sequence", false)) and bool(fields.get("combine", true)):
		_preview.texture = ForgeStore.load_texture(str(files[f]))
	else:
		var tex := ForgeStore.load_texture(str(files[0]))
		var h := maxi(int(fields.get("hframes", 1)), 1)
		var v := maxi(int(fields.get("vframes", 1)), 1)
		if tex and bool(fields.get("animated", false)) and h * v > 1:
			var at := AtlasTexture.new()
			at.atlas = tex
			var fw := tex.get_width() / float(h)
			var fh := tex.get_height() / float(v)
			at.region = Rect2((f % h) * fw, floori(f / float(h)) * fh, fw, fh)
			_preview.texture = at
		else:
			_preview.texture = tex
		if tex and _anim_frame == 0:
			_preview_info.text = "%s  ·  %d × %d px" % [str(files[0]).get_file(), tex.get_width(), tex.get_height()]
	_anim_frame += 1


func _play() -> void:
	var item := _item()
	if item.is_empty():
		return
	_player.stream = ForgeStore.load_audio(str(item["files"][0]))
	_player.play()
