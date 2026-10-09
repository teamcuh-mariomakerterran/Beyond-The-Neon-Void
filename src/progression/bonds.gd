class_name Bonds
extends RefCounted
## Crew bonds: XP between every pair of crew (GameManager.bonds, "a|b" -> xp).
## Earned by winning fights together and at Hangover Morning. Levels unlock
## Bar Stories (data/bar_stories.json) and, at "Thick as Thieves", Duo Techs
## (both buzzed and side by side in a fight).
##
## Last Call: GameManager.drinks (character -> drink item) are ordered before a
## mission; those crew start the fight buzzed and wake up hungover
## (GameManager.hungover): a dispatch penalty until it's slept or nursed off.

const LEVELS := [0, 20, 50, 100]
const NAMES := ["Strangers", "Drinking Buddies", "Thick as Thieves", "Ride or Die"]
## Bond level that unlocks Duo Techs.
const DUO_LEVEL := 2
const WIN_XP := 3
const HUNGOVER_DISPATCH := 0.15
const DUO_TECH := "duo_last_round"
const STUMBLE := "stumble"


static func key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


static func xp(a: String, b: String) -> int:
	return int(GameManager.bonds.get(key(a, b), 0))


static func level_of_xp(x: int) -> int:
	var lv := 0
	for i in LEVELS.size():
		if x >= LEVELS[i]:
			lv = i
	return lv


static func level(a: String, b: String) -> int:
	return level_of_xp(xp(a, b))


static func level_name(a: String, b: String) -> String:
	return NAMES[level(a, b)]


## Adds bond XP (can be negative, floors at 0). Returns the new level if it
## went up, else -1.
static func add(a: String, b: String, amount: int) -> int:
	if a == b or a == "" or b == "":
		return -1
	var before := level(a, b)
	GameManager.bonds[key(a, b)] = maxi(xp(a, b) + amount, 0)
	var after := level(a, b)
	if after > before:
		EventBus.log_message.emit("%s & %s: %s" % [_name(a), _name(b), NAMES[after]])
		return after
	return -1


## Every pair in `ids` gets `amount`. Returns [[a, b, new_level]] for level-ups.
static func add_all(ids: Array, amount: int) -> Array:
	var ups: Array = []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var lv := add(str(ids[i]), str(ids[j]), amount)
			if lv >= 0:
				ups.append([str(ids[i]), str(ids[j]), lv])
	return ups


static func _name(id: String) -> String:
	var c := GameManager.get_character(id)
	return c.display_name.split(" ")[0] if c else id


# --- Last Call -------------------------------------------------------------------

## Order a drink for a crew member's next mission (uses one from the stash).
static func order_drink(char_id: String, item_id: String) -> String:
	if GameManager.get_stack_count(item_id) <= 0:
		return "None left."
	if GameManager.drinks.has(char_id):
		return "Already has one."
	GameManager.remove_stack_item(item_id)
	GameManager.drinks[char_id] = item_id
	return ""


static func cancel_drink(char_id: String) -> void:
	var item := str(GameManager.drinks.get(char_id, ""))
	if item != "":
		GameManager.add_stack_item(item)
	GameManager.drinks.erase(char_id)


## Drinks the bar stocks for Last Call (consumables called con_*).
static func drink_options() -> Array[String]:
	var out: Array[String] = []
	for id: String in GameManager.stack_items:
		if id.begins_with("con_") and int(GameManager.stack_items[id]) > 0 and id != "con_detox_patch":
			out.append(id)
	out.sort()
	return out


## Mission over: drinkers wake up hungover; survivors who won bond.
static func after_mission(victory: bool, survivors: Array) -> Array:
	for id: String in GameManager.drinks:
		GameManager.hungover[id] = true
	GameManager.drinks.clear()
	return add_all(survivors, WIN_XP) if victory else []


## Dispatch odds for someone nursing a hangover.
static func dispatch_penalty(char_id: String) -> float:
	return HUNGOVER_DISPATCH if GameManager.hungover.has(char_id) else 0.0
