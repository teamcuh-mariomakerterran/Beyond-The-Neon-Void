extends Node
## ForgeManager — weapon/gear leveling, upgrades and evolution crafting.
##
## Rules (from the design brief):
##  * Gear levels 1..50 by gaining item XP (kills, feeding materials).
##  * At level >= 10 an item can EVOLVE into a new item using a recipe
##    (uncommon mats at low levels, rare/super mats at high levels).
##  * Evolving early gives a small immediate boost; waiting raises the new
##    item's POTENTIAL (a permanent multiplier on all its stats):
##        potential = old_potential * (1 + 0.02 * (level_at_evolve - 10))
##    Evolve at 10 -> x1.00, at 20 -> x1.20, at 30 -> x1.40, at 50 -> x1.80.
##  * The immediate boost is +1 flat per 10 levels on the main stats, so early
##    crafting feels good now; late crafting wins long-term.

signal item_crafted(result: Dictionary)
signal craft_failed(reason: String)

const EVOLVE_MIN_LEVEL := 10
const MAX_LEVEL := 50
const POTENTIAL_PER_LEVEL := 0.02
## XP per material grade when fed to gear: junk, common, uncommon, rare, super.
const MATERIAL_XP: Array[int] = [5, 20, 60, 180, 500]


static func xp_to_next(item_level: int) -> int:
	return 40 + 12 * item_level + item_level * item_level


func add_item_xp(uid: String, amount: int) -> int:
	var inst := GameManager.get_item_instance(uid)
	if inst.is_empty():
		return 0
	var item := ContentDB.get_item(inst["item_id"])
	var cap := mini(item.max_level if item else MAX_LEVEL, MAX_LEVEL)
	var gained := 0
	inst["xp"] = int(inst.get("xp", 0)) + maxi(amount, 0)
	while int(inst["level"]) < cap and int(inst["xp"]) >= xp_to_next(int(inst["level"])):
		inst["xp"] = int(inst["xp"]) - xp_to_next(int(inst["level"]))
		inst["level"] = int(inst["level"]) + 1
		gained += 1
	if int(inst["level"]) >= cap:
		inst["xp"] = 0
	EventBus.inventory_changed.emit()
	return gained


## Feed stackable materials into a piece of gear for XP.
func upgrade(uid: String, materials: Dictionary) -> String:
	var total_xp := 0
	for mat_id: String in materials:
		var qty := int(materials[mat_id])
		var mat := ContentDB.get_item(mat_id)
		if mat == null or mat.category != ItemResource.Category.MATERIAL:
			return _fail("%s isn't a material." % mat_id)
		if GameManager.get_stack_count(mat_id) < qty:
			return _fail("Not enough %s." % mat.display_name)
		total_xp += MATERIAL_XP[clampi(mat.material_grade, 0, MATERIAL_XP.size() - 1)] * qty
	for mat_id: String in materials:
		GameManager.remove_stack_item(mat_id, int(materials[mat_id]))
	add_item_xp(uid, total_xp)
	return ""


## Recipes live in data/recipes.json: {"wpn_x->wpn_y": {"from": ..., "to": ..., "materials": {...}, "min_level": 10, "soul_coins": 300}}
func get_evolutions(uid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var inst := GameManager.get_item_instance(uid)
	if inst.is_empty():
		return out
	for key: String in ContentDB.recipes:
		var r: Dictionary = ContentDB.recipes[key]
		if r.get("from", "") == inst["item_id"]:
			out.append(r)
	return out


func can_evolve(uid: String, recipe: Dictionary) -> String:
	var inst := GameManager.get_item_instance(uid)
	if inst.is_empty():
		return "Unknown item."
	var min_level := maxi(int(recipe.get("min_level", EVOLVE_MIN_LEVEL)), EVOLVE_MIN_LEVEL)
	if int(inst["level"]) < min_level:
		return "Needs level %d." % min_level
	var mats: Dictionary = recipe.get("materials", {})
	for mat_id: String in mats:
		if GameManager.get_stack_count(mat_id) < int(mats[mat_id]):
			return "Missing %s." % mat_id
	if GameManager.soul_coins < int(recipe.get("soul_coins", 0)):
		return "Not enough soul coins."
	return ""


static func evolved_potential(old_potential: float, level_at_evolve: int) -> float:
	var extra := maxi(level_at_evolve - EVOLVE_MIN_LEVEL, 0) * POTENTIAL_PER_LEVEL
	return snappedf(old_potential * (1.0 + extra), 0.001)


## Evolves the instance in place (keeps its uid, so equipped slots stay valid).
func evolve(uid: String, recipe: Dictionary) -> Dictionary:
	var err := can_evolve(uid, recipe)
	if err != "":
		_fail(err)
		return {}
	var inst := GameManager.get_item_instance(uid)
	var mats: Dictionary = recipe.get("materials", {})
	for mat_id: String in mats:
		GameManager.remove_stack_item(mat_id, int(mats[mat_id]))
	GameManager.spend_soul_coins(int(recipe.get("soul_coins", 0)))
	var level_at := int(inst["level"])
	var old_item := ContentDB.get_item(inst["item_id"])
	inst["potential"] = evolved_potential(float(inst.get("potential", 1.0)), level_at)
	var bonus: Dictionary = inst.get("bonus", {})
	if old_item:
		for stat: Variant in old_item.stat_modifiers:
			bonus[stat] = int(bonus.get(stat, 0)) + level_at / 10
	inst["bonus"] = bonus
	inst["item_id"] = recipe["to"]
	inst["level"] = 1
	inst["xp"] = 0
	inst["evolved_from"] = str(recipe.get("from", ""))
	inst["evolved_at_level"] = level_at
	item_crafted.emit(inst)
	EventBus.item_crafted.emit(inst)
	EventBus.inventory_changed.emit()
	return inst


## Simple consumable / card crafting: {"materials": {...}, "result": id, "qty": n}
func craft_simple(recipe_id: String) -> bool:
	var r: Dictionary = ContentDB.recipes.get(recipe_id, {})
	if r.is_empty() or not r.has("result"):
		_fail("Unknown recipe.")
		return false
	var mats: Dictionary = r.get("materials", {})
	for mat_id: String in mats:
		if GameManager.get_stack_count(mat_id) < int(mats[mat_id]):
			_fail("Missing %s." % mat_id)
			return false
	for mat_id: String in mats:
		GameManager.remove_stack_item(mat_id, int(mats[mat_id]))
	GameManager.give_item(str(r["result"]), int(r.get("qty", 1)))
	item_crafted.emit({"item_id": r["result"]})
	return true


func _fail(reason: String) -> String:
	craft_failed.emit(reason)
	return reason
