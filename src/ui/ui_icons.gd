class_name UIIcons
extends RefCounted
## One place to get the icon for anything in the game. Packs live in
## res://assets/ui/icons/<pack>/<name>.png (Black Doctrine UI drops, named
## after our own ids). The chosen style (SettingsFlags.icon_style) is tried
## first, then the other packs, then a sensible fallback (e.g. an ability
## without its own art uses its type icon). A data entry's icon_path always wins.
##
##   UIIcons.get_icon("class", "chrome_warrior")
##   UIIcons.ability(ability)   UIIcons.item(item)   UIIcons.status("burning")

const ROOT := "res://assets/ui/icons"
const STYLES := {"painted": ["painted", "painted2", "framed"], "framed": ["framed", "painted", "painted2"]}
## Our item ids → icon names (weapons map by type in item()).
const ITEM_MAP := {
	"arm_work_jacket": "armor_medium", "arm_riot_plate": "armor_heavy", "arm_signal_cloak": "armor_light", "arm_cantor_robe": "armor_light",
	"con_neon_gin": "neon_gin", "con_cyber_sake": "mp_stim", "con_void_vodka": "buff_shot", "con_synth_stew": "ration", "con_detox_patch": "cleanse",
	"chip_microchip": "microchip", "mat_scrap_wire": "mat_microcoil", "mat_dead_battery": "mat_plasma_core", "mat_corrupted_wafer": "mat_circuit_weave",
	"mat_memory_core": "mat_data_shard", "mat_dream_battery": "mat_cryo_cell", "mat_neon_ink": "mat_neon_filament",
	"mat_archive_fragment": "mat_data_shard", "mat_warframe_plating": "mat_chrome_rivet", "mat_essence_shard": "mat_essence_vial",
	"mat_nyx_crystal": "mat_void_shard", "mat_pioneer_shell": "mat_scrap_plate", "mat_null_wafer": "mat_circuit_weave",
}
## Our command / UI names → icon names.
const ALIASES := {"move": ["move", "cmd_move"], "attack": ["attack_cmd", "cmd_attack", "attack"], "wait": ["wait", "cmd_wait"],
	"item": ["item", "cmd_item"], "cards": ["cards", "cmd_cards"], "act": ["act", "cmd_act"], "end_turn": ["wait", "cmd_wait"]}

static var _cache: Dictionary = {}


## Path for `name` in the preferred packs, or "".
static func find(name: String) -> String:
	if name == "":
		return ""
	var packs: Array = STYLES.get(SettingsFlags.icon_style, STYLES["painted"])
	for p: String in packs + ["mats"]:
		var path := ROOT.path_join(p).path_join(name + ".png")
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	return ""


## "Rally Cry" → "rally_cry" (how new art can be named).
static func slug(t: String) -> String:
	var out := ""
	for ch in t.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges().trim_prefix("_").trim_suffix("_")


static func load_path(path: String) -> Texture2D:
	if path == "":
		return null
	var key := SettingsFlags.icon_style + "|" + path
	if not _cache.has(key):
		_cache[key] = ForgeStore.load_texture(path)
	return _cache[key]


static func named(name: String) -> Texture2D:
	return load_path(find(name))


## kind: class | status | ability | item | passive | stat | element | weapon | rarity | cmd | unit
static func get_icon(kind: String, id: String) -> Texture2D:
	match kind:
		"class":
			var c := ContentDB.get_class_res(id)
			return ability_like(c, id)
		"status":
			return status(id)
		"ability":
			var a := ContentDB.get_ability(id)
			return ability(a) if a else named(id)
		"item":
			var it := ContentDB.get_item(id)
			return item(it) if it else named(id)
		"stat":
			return named("stat_" + id)
		"cmd":
			for n: String in ALIASES.get(id, [id]):
				var t := named(n)
				if t:
					return t
			return null
		"unit":
			var cd := ContentDB.get_character(id)
			if cd:
				# id, then the display name ("Shift Warden" → shift_warden), then the class.
				for n: String in [id, cd.display_name.to_lower().replace(" ", "_").replace("'", "")]:
					if named(n):
						return named(n)
				return get_icon("class", cd.class_id)
			return named(id)
	return named(id)


static func ability_like(res: Resource, id: String) -> Texture2D:
	if res and str(res.get("icon_path")) != "":
		return load_path(str(res.get("icon_path")))
	return named(id)


## Statuses without their own art borrow a close one.
const STATUS_FALLBACK := {"shielded": "shield", "cloaked": "hidden"}


static func status(id: String) -> Texture2D:
	var t := ability_like(ContentDB.get_status(id), id)
	if t == null and STATUS_FALLBACK.has(id):
		return named(STATUS_FALLBACK[id])
	return t


## Own art, else the ability's type icon (attack, magic, heal…).
static func ability(a: Ability) -> Texture2D:
	if a == null:
		return null
	if a.icon_path != "":
		return load_path(a.icon_path)
	var own := named(a.id)
	if own:
		return own
	own = named(slug(a.display_name))  # art named after the ability ("Chrome Cleave" → chrome_cleave)
	if own:
		return own
	if a.id == "basic_attack":
		return get_icon("cmd", "attack")
	return named(str(Ability.Kind.keys()[a.kind]).to_lower())


static func item(it: ItemResource) -> Texture2D:
	if it == null:
		return null
	if it.icon_path != "":
		return load_path(it.icon_path)
	var id := it.id
	if ITEM_MAP.has(id):
		return named(ITEM_MAP[id])
	if id.begins_with("wpn_"):
		# wpn_<type>_<n> → <type>
		var t := id.substr(4)
		t = t.substr(0, t.rfind("_")) if t.rfind("_") > 0 else t
		return named(t)
	if id.begins_with("acc_"):
		return named("accessory")
	if id.begins_with("dsk_"):
		return named("data_disk")
	if id.begins_with("key_"):
		return named("quest_key")
	return named(id)


static func passive(p: PassiveResource) -> Texture2D:
	if p == null:
		return null
	if p.icon_path != "":
		return load_path(p.icon_path)
	return named(p.id) if named(p.id) else named({"reaction": "focused", "support": "fortified", "movement": "haste"}.get(p.slot, "buff"))
