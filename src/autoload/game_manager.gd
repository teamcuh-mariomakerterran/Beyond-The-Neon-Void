extends Node
## GameManager — party, inventory, currency and story state for the campaign.
##
## Everything here is plain data (Dictionaries / CharacterData) so SaveManager
## can serialize it to JSON in one pass.

signal party_changed
signal story_progress_updated
signal currency_changed

const MAX_PARTY_SIZE := 5
const STARTING_SOUL_COINS := 500
const STARTING_ROSTER: Array[String] = ["rook", "mags", "dizzy", "brannoc", "patch"]

# --- Currency & counters ---
var soul_coins: int = STARTING_SOUL_COINS
var microchips: int = 0
var story_chapter: int = 1
var story_flags: Dictionary = {}
var hub_visits_count: int = 0
var correct_dialog_streak: int = 0
var secret_characters_unlocked: Array[String] = []

# --- Roster ---
var roster: Dictionary = {}  # character_id -> CharacterData (runtime copies)
var active_party: Array[String] = []

# --- Inventory ---
## Stackables (consumables, materials, keys): {item_id: qty}
var stack_items: Dictionary = {}
## Unique gear: {uid: ItemInstance dict}. See EquipmentManager for the schema.
var item_instances: Dictionary = {}
## Cards owned: {card_id: qty}
var cards: Dictionary = {}
var _uid_counter: int = 0

# --- Crew life (see Bonds) ---
## "a|b" -> bond xp
var bonds: Dictionary = {}
## Last Call: character -> drink item ordered for the next mission.
var drinks: Dictionary = {}
## character -> true while hungover (dispatch penalty).
var hungover: Dictionary = {}


func _enter_tree() -> void:
	InputActions.register()


func _ready() -> void:
	new_game()


func new_game() -> void:
	soul_coins = STARTING_SOUL_COINS
	microchips = 0
	story_chapter = 1
	story_flags.clear()
	hub_visits_count = 0
	correct_dialog_streak = 0
	secret_characters_unlocked.clear()
	roster.clear()
	active_party.clear()
	stack_items.clear()
	item_instances.clear()
	cards.clear()
	bonds.clear()
	drinks.clear()
	hungover.clear()
	_uid_counter = 0
	for cid in STARTING_ROSTER:
		var template := ContentDB.get_character(cid)
		if template:
			add_character_to_roster(template)
	active_party = STARTING_ROSTER.slice(0, MAX_PARTY_SIZE).filter(func(id: String) -> bool: return roster.has(id))
	add_stack_item("con_neon_gin", 3)
	add_stack_item("con_synth_stew", 2)
	# QuestManager loads after us, so it doesn't exist during our own _ready().
	var quests := get_node_or_null("/root/QuestManager")
	if quests:
		quests.reset()
	var vendors := get_node_or_null("/root/VendorSystem")
	if vendors:
		vendors.reset()
	party_changed.emit()


# --- Party ---------------------------------------------------------------

## Adds a *copy* of the template so campaign progress never mutates content.
func add_character_to_roster(template: CharacterData) -> CharacterData:
	if roster.has(template.id):
		return roster[template.id]
	var copy := CharacterData.new()
	copy.apply_dict(template.to_dict())
	if copy.get_class_level(copy.class_id) == 0:
		copy.class_levels[copy.class_id] = 1
	for slot: String in template.equipment:
		# Templates reference item ids; the roster copy gets real instances.
		var inst := create_item_instance(str(template.equipment[slot]))
		copy.equipment[slot] = inst.get("uid", "")
	roster[copy.id] = copy
	party_changed.emit()
	return copy


func get_character(character_id: String) -> CharacterData:
	return roster.get(character_id)


func get_party_members() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for id in active_party:
		var c := get_character(id)
		if c and not c.is_dispatched:
			out.append(c)
	return out


func set_active_party(ids: Array[String]) -> bool:
	if ids.size() > MAX_PARTY_SIZE:
		push_error("Party size cannot exceed %d" % MAX_PARTY_SIZE)
		return false
	active_party = ids.duplicate()
	party_changed.emit()
	return true


# --- Economy ---------------------------------------------------------------

func add_soul_coins(amount: int) -> void:
	soul_coins = clampi(soul_coins + amount, 0, 99_999_999)
	if amount > 0 and is_inside_tree() and get_node_or_null("/root/AudioManager"):
		Sfx.event("coins", -6.0)
	currency_changed.emit()
	EventBus.soul_coins_changed.emit(soul_coins)


func spend_soul_coins(amount: int) -> bool:
	if amount < 0 or soul_coins < amount:
		return false
	soul_coins -= amount
	currency_changed.emit()
	EventBus.soul_coins_changed.emit(soul_coins)
	return true


func add_microchips(amount: int) -> void:
	microchips = maxi(microchips + amount, 0)


# --- Inventory -------------------------------------------------------------

func add_stack_item(item_id: String, qty: int = 1) -> void:
	stack_items[item_id] = int(stack_items.get(item_id, 0)) + qty
	if stack_items[item_id] <= 0:
		stack_items.erase(item_id)
	EventBus.inventory_changed.emit()


func remove_stack_item(item_id: String, qty: int = 1) -> bool:
	if int(stack_items.get(item_id, 0)) < qty:
		return false
	add_stack_item(item_id, -qty)
	return true


func get_stack_count(item_id: String) -> int:
	return int(stack_items.get(item_id, 0))


## Adds any item: equipment becomes a unique instance, the rest stacks.
func give_item(item_id: String, qty: int = 1) -> void:
	var item := ContentDB.get_item(item_id)
	if item and item.grants_flag != "" and not check_story_flag(item.grants_flag):
		set_story_flag(item.grants_flag)
		EventBus.log_message.emit("%s — something new stirs. (%s)" % [item.display_name, item.grants_flag])
	if item == null:
		if ContentDB.get_card(item_id):
			cards[item_id] = int(cards.get(item_id, 0)) + qty
			EventBus.inventory_changed.emit()
		else:
			push_warning("give_item: unknown item " + item_id)
		return
	if item.category == ItemResource.Category.MICROCHIP:
		add_microchips(qty)
	elif item.is_equipment():
		for _i in qty:
			create_item_instance(item_id)
	else:
		add_stack_item(item_id, qty)


func create_item_instance(item_id: String) -> Dictionary:
	if ContentDB.get_item(item_id) == null:
		return {}
	_uid_counter += 1
	var uid := "i%05d" % _uid_counter
	var inst := {"uid": uid, "item_id": item_id, "level": 1, "xp": 0, "potential": 1.0, "bonus": {}}
	item_instances[uid] = inst
	EventBus.inventory_changed.emit()
	return inst


func get_item_instance(uid: String) -> Dictionary:
	return item_instances.get(uid, {})


func remove_item_instance(uid: String) -> void:
	item_instances.erase(uid)
	for c: CharacterData in roster.values():
		for slot: String in c.equipment.keys():
			if c.equipment[slot] == uid:
				c.equipment.erase(slot)
	EventBus.inventory_changed.emit()


# --- Story -----------------------------------------------------------------

func set_story_flag(flag_name: String, value: Variant = true) -> void:
	story_flags[flag_name] = value
	story_progress_updated.emit()
	EventBus.story_flag_changed.emit(flag_name, value)


func check_story_flag(flag_name: String) -> bool:
	return bool(story_flags.get(flag_name, false))


## Hub dialog streak: 5 "right" answers in a row unlocks the Drunken Oracle.
func record_hub_visit(dialog_correct: bool) -> void:
	hub_visits_count += 1
	correct_dialog_streak = correct_dialog_streak + 1 if dialog_correct else 0
	if correct_dialog_streak >= 5:
		unlock_secret_character("drunken_oracle")
		correct_dialog_streak = 0


func unlock_secret_character(char_id: String) -> void:
	if secret_characters_unlocked.has(char_id):
		return
	secret_characters_unlocked.append(char_id)
	var template := ContentDB.get_character(char_id)
	if template:
		add_character_to_roster(template)
	EventBus.log_message.emit("Secret character unlocked: %s" % (template.display_name if template else char_id))


# --- Save hooks ------------------------------------------------------------

func get_state_data() -> Dictionary:
	var roster_out := {}
	for id: String in roster:
		roster_out[id] = roster[id].to_dict()
	return {
		"soul_coins": soul_coins,
		"microchips": microchips,
		"story_chapter": story_chapter,
		"story_flags": story_flags.duplicate(true),
		"hub_visits_count": hub_visits_count,
		"correct_dialog_streak": correct_dialog_streak,
		"secret_characters_unlocked": secret_characters_unlocked.duplicate(),
		"roster": roster_out,
		"active_party": active_party.duplicate(),
		"stack_items": stack_items.duplicate(),
		"item_instances": item_instances.duplicate(true),
		"cards": cards.duplicate(),
		"uid_counter": _uid_counter,
		"bonds": bonds.duplicate(),
		"drinks": drinks.duplicate(),
		"hungover": hungover.duplicate(),
	}


func load_state_data(d: Dictionary) -> void:
	soul_coins = int(d.get("soul_coins", STARTING_SOUL_COINS))
	microchips = int(d.get("microchips", 0))
	story_chapter = int(d.get("story_chapter", 1))
	story_flags = d.get("story_flags", {})
	hub_visits_count = int(d.get("hub_visits_count", 0))
	correct_dialog_streak = int(d.get("correct_dialog_streak", 0))
	secret_characters_unlocked.assign(d.get("secret_characters_unlocked", []))
	roster.clear()
	var r: Dictionary = d.get("roster", {})
	for id: String in r:
		var c := CharacterData.new()
		c.apply_dict(r[id])
		roster[id] = c
	active_party.assign(d.get("active_party", []))
	stack_items = _int_values(d.get("stack_items", {}))
	item_instances = d.get("item_instances", {})
	for uid: String in item_instances:
		var inst: Dictionary = item_instances[uid]
		inst["level"] = int(inst.get("level", 1))
		inst["xp"] = int(inst.get("xp", 0))
	cards = _int_values(d.get("cards", {}))
	_uid_counter = int(d.get("uid_counter", item_instances.size()))
	bonds = _int_values(d.get("bonds", {}))
	drinks = (d.get("drinks", {}) as Dictionary).duplicate()
	hungover = (d.get("hungover", {}) as Dictionary).duplicate()
	party_changed.emit()
	currency_changed.emit()


static func _int_values(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d:
		out[k] = int(d[k])
	return out
