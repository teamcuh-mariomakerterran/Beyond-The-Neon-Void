class_name ForgeForm
extends VBoxContainer
## Builds an editing form for any GameResource or plain Dictionary.
##
## Field widgets are chosen from the property type AND its name, so the form
## "knows" the game: `class_id` is a class dropdown, `status_ids` is a chip list
## of statuses, `*_path` accepts dropped files with a preview, `enemies` is a
## list of encounter rows with a character picker and a cell. Adding a new
## @export var to any content Resource makes it editable here automatically.

signal changed(key: String)

## Field name -> reference source for id pickers.
const REFS := {
	"class_id": "classes", "secondary_class_id": "classes",
	"innate_ability_ids": "abilities", "learnable_ability_ids": "abilities", "learned_ability_ids": "abilities",
	"status_ids": "status_effects", "cure_status_ids": "status_effects",
	"loot_table_id": "loot_tables", "map_id": "maps",
	"music_id": "music", "sfx_id": "sfx", "vfx_id": "vfx",
	"item_id": "items_and_cards", "evolves_into": "items", "result": "items_and_cards",
	"unlocks_mission_ids": "missions", "fight_mission_id": "missions",
	"quest_ids": "quests", "prerequisite_quest_ids": "quests", "next_quest_id": "quests",
	"giver_npc_id": "npcs", "character_id": "characters", "vendor_id": "vendors",
	"rumor_ids": "rumors", "equip_type": "weapon_types",
	"weapon_types": "weapon_types", "specialty_weapon_types": "weapon_types", "weapon_specialties": "weapon_types",
	"stock.id": "items_and_cards", "from": "items", "to": "items",
	"loot_item_id": "items_and_cards", "terrain": "terrain",
	"intro_cutscene": "cutscenes", "outro_cutscene": "cutscenes", "cutscene": "cutscenes",
	"offer_quest_id": "quests", "chain_quest_id": "quests", "give_item_id": "items_and_cards", "stage_cutscene": "cutscenes",
}
## Dictionary fields: key source / value source.
const DICT_KEYS := {
	"multipliers": "primary_stats", "growth": "primary_stats",
	"stat_modifiers": "stats", "stat_growth": "stats", "stat_multipliers": "stats", "stat_flat": "stats",
	"unlock_requirements": "classes", "class_affinity": "classes", "class_levels": "classes",
	"reward_items": "items_and_cards", "crafting_materials": "items", "materials": "items",
	"equipment": "slots", "element_modifiers": "elements", "stat_weights": "primary_stats",
	"base_stats": "stat_block",
	"fetch_items": "items", "fetch_reward_items_each": "items_and_cards", "fetch_reward_items_done": "items_and_cards",
}
const DICT_VALUES := {"equipment": "items"}
## New-row templates for Array[Dictionary] fields.
const TEMPLATES := {
	"enemies": {"character_id": "", "cell": [0, 0], "level": 1, "ai": "", "statuses": []},
	"guests": {"character_id": "", "cell": [0, 0], "level": 1},
	"entries": {"item_id": "", "weight": 10, "min": 1, "max": 1},
	"objectives": {"type": "complete_mission", "target": "", "count": 1, "text": ""},
	"dialog": {"id": "", "text": "", "speaker": "", "voice_path": "", "requires_flag": "", "sets_flag": "", "next": "", "choices": []},
	"choices": {"text": "", "next": "", "correct": false, "sets_flag": ""},
	"eavesdrop_lines": {"text": "", "voice_path": "", "requires_flag": ""},
	"stock": {"id": "", "price": 0, "required_flag": ""},
	"props": {"id": "", "cell": [0, 0], "asset": "", "loot_item_id": "", "found_text": "", "empty_text": ""},
}
const CHOICES := {
	"after_talk": ["none", "shop", "quest", "chain", "fetch", "battle", "cutscene"],
	"type": ["complete_mission", "collect_item", "talk_to", "find_loot", "flag", "defeat_character"],
	"ai": ["", "aggressive", "cautious", "tactical", "support"],
	"ai_behavior": ["aggressive", "cautious", "tactical", "support"],
	"scaling_stat": ["attack", "magic", "intelligence", "vitality", "agility", "strength"],
	"damage_type": ["physical", "kinetic", "plasma", "cryo", "electric", "tech", "void", "essence"],
	"win_condition": ["defeat_all", "defeat_target", "survive", "reach_cell"],
	"lose_condition": ["party_wiped", "leader_down", "protect", "time_limit"],
	"special": ["", "cleanse", "restore_mp", "blink", "summon", "summon_droid", "revive", "reanimate", "echo", "steal_coins", "steal_chip",
		"kinetic.charge", "kinetic.pull", "kinetic.repulse", "time.delay_thread", "time.stitch_turn", "time.rewind", "time.ct_shift",
		"terrain.fault_line", "terrain.elevate", "terrain.warp", "terrain.hazard", "terrain.geomancy"],
	"script": ["", "kinetic", "time", "terrain"],
	"channel": ["news", "gossip", "graffiti", "radio"],
	"location_id": ["neon_gutter"],
}
const HELP := {
	"multipliers": "Multiplicative stat scaling while in this class.",
	"charge_ticks": "0 = instant. >0 = FFT-style charged cast that resolves later on the CT clock.",
	"power": "Damage/heal multiplier on the scaling stat.",
	"aoe_radius": "For DIAMOND/CROSS: radius around target. For LINE: length.",
	"uses_deck": "Card class: fights with a deck instead of a weapon.",
	"blue_learnable": "A Bluescreen Mage hit by this learns it.",
	"absorb_only": "Only learnable by getting hit (not at terminals).",
	"ai_controlled": "On this team but driven by AI (droids, guests).",
	"unlock_flag": "Story flag that must be set (secret classes).",
	"potential": "Evolution multiplier.",
	"win_param": "defeat_target: character id  •  survive: rounds  •  reach_cell: x,y",
}

var _data: Dictionary = {}
var _meta: Dictionary = {}
var _context: String = ""
var _compact: bool = false


## Build from a resource: its exported properties + metadata (enums, groups).
func build_resource(res: GameResource) -> void:
	_meta.clear()
	_data = res.to_dict()
	var order: Array[String] = []
	var group := ""
	var groups := {}
	for p: Dictionary in res.get_property_list():
		if p["usage"] & PROPERTY_USAGE_GROUP:
			group = p["name"]
			continue
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and p["usage"] & PROPERTY_USAGE_STORAGE and _data.has(p["name"]):
			_meta[p["name"]] = p
			order.append(p["name"])
			groups[p["name"]] = group
	_render(order, groups)


## Build from a plain dictionary (vendors, terrain, list records...).
func build_dict(data: Dictionary, context: String = "", compact: bool = false) -> void:
	_meta.clear()
	_data = data
	_context = context
	_compact = compact
	var order: Array[String] = []
	order.assign(data.keys())
	_render(order, {})


func get_data() -> Dictionary:
	return _data


func _render(order: Array[String], groups: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	add_theme_constant_override("separation", 6 if _compact else 8)
	var last_group := "__none__"
	for key in order:
		var g: String = groups.get(key, "")
		if g != last_group and g != "" and not _compact:
			var gl := NeonTheme.label(g.to_upper(), 12, NeonTheme.VIOLET)
			gl.add_theme_font_override("font", NeonTheme.mono())
			var sep := HSeparator.new()
			sep.add_theme_stylebox_override("separator", _hairline())
			add_child(sep)
			add_child(gl)
		last_group = g
		_add_field(key)


func _hairline() -> StyleBoxLine:
	var l := StyleBoxLine.new()
	l.color = Color(NeonTheme.VIOLET, 0.25)
	l.thickness = 1
	return l


func _add_field(key: String) -> void:
	var value: Variant = _data[key]
	var meta: Dictionary = _meta.get(key, {})
	var widget := _make_widget(key, value, meta)
	if widget == null:
		return
	if _compact:
		var row := HBoxContainer.new()
		var l := NeonTheme.label(key.replace("_", " "), 12, NeonTheme.TEXT_DIM)
		l.custom_minimum_size.x = 110
		row.add_child(l)
		widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(widget)
		add_child(row)
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	var label := NeonTheme.label(key.replace("_", " ").to_upper(), 12, NeonTheme.TEXT_DIM)
	label.add_theme_font_override("font", NeonTheme.mono())
	head.add_child(label)
	if HELP.has(key):
		var h := NeonTheme.label("  — " + HELP[key], 12, Color(NeonTheme.TEXT_DIM, 0.7))
		head.add_child(h)
	box.add_child(head)
	widget.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if widget is CheckButton else Control.SIZE_EXPAND_FILL
	box.add_child(widget)
	add_child(box)


func _commit(key: String, value: Variant) -> void:
	_data[key] = value
	changed.emit(key)


# --- Widget factory ----------------------------------------------------------

func _ref_for(key: String) -> String:
	if _context != "" and REFS.has(_context + "." + key):
		return REFS[_context + "." + key]
	return REFS.get(key, "")


func _make_widget(key: String, value: Variant, meta: Dictionary) -> Control:
	var hint: int = meta.get("hint", PROPERTY_HINT_NONE)
	if value is bool:
		var cb := CheckButton.new()
		cb.button_pressed = value
		cb.text = "ON" if value else "OFF"
		cb.toggled.connect(func(v: bool) -> void: cb.text = "ON" if v else "OFF")
		cb.toggled.connect(func(v: bool) -> void: _commit(key, v))
		return cb
	if meta.get("type", -1) == TYPE_INT and hint == PROPERTY_HINT_ENUM:
		var names := []
		for part: String in str(meta["hint_string"]).split(","):
			names.append(GameResource._norm(part.split(":")[0]))
		return _option(names, str(value), func(v: String) -> void: _commit(key, v))
	if key == "team" and (value is int or value is float):
		var teams := ["PLAYER (crew)", "ENEMY (doctrine)", "NEUTRAL"]
		var ob := _option(teams, teams[clampi(int(value), 0, 2)], func(v: String) -> void: _commit(key, teams.find(v)))
		return ob
	if value is int or value is float:
		var is_int: bool = meta.get("type", TYPE_FLOAT if value is float else TYPE_INT) == TYPE_INT or (value is float and is_equal_approx(value, roundf(value)) and _meta.is_empty() and not key in ["weight", "potential", "price_mult", "power"])
		return _spin(float(value), is_int, func(v: float) -> void: _commit(key, int(v) if is_int else v))
	if value is String:
		if CHOICES.has(key):
			var opts: Array = CHOICES[key].duplicate()
			if not opts.has(value):
				opts.append(value)
			return _option(opts, value, func(v: String) -> void: _commit(key, v), true)
		var ref := _ref_for(key)
		if ref != "":
			return _ref_picker(ref, value, func(v: String) -> void: _commit(key, v))
		if key.ends_with("_path") or key == "texture" or key == "asset":
			return ForgePathField.create(value, key, func(v: String) -> void: _commit(key, v))
		if hint == PROPERTY_HINT_MULTILINE_TEXT or key in ["text", "description", "briefing", "bio", "found_text", "empty_text", "greeting", "success_text", "failure_text", "lore_text", "flavor_text"]:
			var te := TextEdit.new()
			te.text = value
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			te.custom_minimum_size.y = 64 if _compact else 84
			te.add_theme_font_override("font", NeonTheme.font(NeonTheme.FONT_BODY))
			te.text_changed.connect(func() -> void: _commit(key, te.text))
			return te
		var le := LineEdit.new()
		le.text = value
		if key == "id":
			le.add_theme_color_override("font_color", NeonTheme.GREEN)
		le.text_changed.connect(func(v: String) -> void: _commit(key, v))
		return le
	if value is Array:
		if key == "cell" or (value.size() == 2 and (value[0] is float or value[0] is int) and key.ends_with("cell")):
			return _vec2(value, func(v: Array) -> void: _commit(key, v))
		var typed := meta.get("hint_string", "") as String
		var dict_list: bool = key in TEMPLATES or (not value.is_empty() and value[0] is Dictionary) or typed.contains("Dictionary") or typed.begins_with("27")
		if dict_list:
			return ForgeRecordList.create(value, key, func(v: Array) -> void: _commit(key, v))
		return ForgeChipList.create(value, _ref_for(key), func(v: Array) -> void: _commit(key, v))
	if value is Dictionary:
		return ForgeKVEditor.create(value, DICT_KEYS.get(key, ""), DICT_VALUES.get(key, ""), func(v: Dictionary) -> void: _commit(key, v))
	var raw := LineEdit.new()
	raw.text = JSON.stringify(value)
	raw.text_submitted.connect(func(t: String) -> void:
		var parsed: Variant = JSON.parse_string(t)
		if parsed != null:
			_commit(key, parsed))
	return raw


static func _spin(value: float, is_int: bool, cb: Callable) -> SpinBox:
	var sb := SpinBox.new()
	sb.allow_greater = true
	sb.allow_lesser = true
	sb.min_value = -9999
	sb.max_value = 99999
	sb.step = 1.0 if is_int else 0.01
	sb.value = value
	sb.custom_minimum_size.x = 110
	sb.get_line_edit().add_theme_font_override("font", NeonTheme.mono())
	sb.value_changed.connect(cb)
	return sb


static func _option(options: Array, current: String, cb: Callable, editable: bool = false) -> OptionButton:
	var ob := OptionButton.new()
	ob.fit_to_longest_item = false
	for o: Variant in options:
		ob.add_item(str(o) if str(o) != "" else "(none)")
	var idx := options.find(current)
	ob.selected = maxi(idx, 0)
	ob.item_selected.connect(func(i: int) -> void: cb.call(str(options[i])))
	return ob


static func _vec2(value: Array, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	var v := [int(value[0]) if value.size() > 0 else 0, int(value[1]) if value.size() > 1 else 0]
	for i in 2:
		var l := NeonTheme.label("xy"[i], 12, NeonTheme.TEXT_DIM)
		h.add_child(l)
		var idx := i
		var sb := _spin(v[i], true, func(n: float) -> void:
			v[idx] = int(n)
			cb.call(v.duplicate()))
		h.add_child(sb)
	return h


## Dropdown of ids from a reference source, with "(none)" and live refresh.
static func _ref_picker(ref: String, current: String, cb: Callable) -> OptionButton:
	var opts: Array = [""] + ref_options(ref)
	if current != "" and not opts.has(current):
		opts.append(current)
	var ob := _option(opts, current, cb)
	ob.tooltip_text = "Reference: " + ref
	for i in opts.size():
		var label := ref_label(ref, str(opts[i]))
		if label != "":
			ob.set_item_text(i, label)
	return ob


static func ref_options(ref: String) -> Array:
	match ref:
		"maps": return ContentDB.maps.keys()
		"cutscenes": return ForgeStore.list_cutscenes()
		"vendors": return ContentDB.vendors.keys()
		"rumors": return ContentDB.rumors.keys()
		"terrain": return ContentDB.terrain.keys()
		"music", "sfx", "vfx":
			return ForgeStore.list_assets(ref).map(func(p: String) -> String: return p.get_file().get_basename())
		"items_and_cards": return ContentDB.get_ids("items") + ContentDB.get_ids("cards")
		"weapon_types":
			var set := {}
			for it: ItemResource in ContentDB.get_all("items"):
				if it.equip_type != "":
					set[it.equip_type] = true
			for c: ClassResource in ContentDB.get_all("classes"):
				for w in c.weapon_types:
					set[w] = true
			return set.keys()
		"primary_stats": return UnitStats.PRIMARY.duplicate()
		"stats": return UnitStats.PRIMARY + UnitStats.DERIVED
		"slots": return EquipmentManager.SLOTS.duplicate()
		"stat_block": return UnitStats.PRIMARY + ["level"]
		"elements": return ["physical", "kinetic", "plasma", "cryo", "electric", "tech", "void", "essence"]
	return ContentDB.get_ids(ref)


static func ref_label(ref: String, id: String) -> String:
	if id == "":
		return "(none)"
	if ref == "cutscenes":
		return id.get_file().trim_suffix(".json")
	var bucket := ref
	if ref == "items_and_cards":
		bucket = "items" if ContentDB.get_item(id) else "cards"
	var r := ContentDB.get_entry(bucket, id)
	if r and r.display_name != "":
		return "%s  ·  %s" % [r.display_name, id]
	return ""
