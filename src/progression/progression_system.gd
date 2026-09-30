class_name ProgressionSystem
extends RefCounted
## XP, levels and class (job) levels.
##
## Character level: polynomial curve (the original 100 * 1.5^level overflowed
## int64 long before level 99). Class levels 1-8 follow FFT job-level pacing.
## Ability XP is boosted when a character fights with a specialty weapon.

const LEVEL_MAX := UnitStats.LEVEL_MAX
const CLASS_LEVEL_THRESHOLDS: Array[int] = [0, 0, 200, 400, 700, 1100, 1600, 2200, 3000]  # index = level
const CLASS_LEVEL_MAX := 8


static func xp_to_next(level: int) -> int:
	var l := clampi(level, 1, LEVEL_MAX) - 1
	return 100 + 20 * l + 2 * l * l


## Adds XP, applying level-ups with the character's current class growth.
## Returns the number of levels gained.
static func add_xp(character: CharacterData, amount: int) -> int:
	var stats := character.get_stats()
	var cls := ContentDB.get_class_res(character.class_id)
	character.experience += maxi(amount, 0)
	var gained := 0
	while stats.level < LEVEL_MAX and character.experience >= xp_to_next(stats.level):
		character.experience -= xp_to_next(stats.level)
		stats.level_up(cls)
		gained += 1
	if stats.level >= LEVEL_MAX:
		character.experience = 0
	character.set_stats(stats)
	if gained > 0:
		EventBus.character_leveled.emit(character.id, stats.level)
	return gained


## Class XP ("JP"). `specialized` = fought with a specialty weapon (+25%).
static func add_class_xp(character: CharacterData, amount: int, specialized: bool = false) -> int:
	var cid := character.class_id
	var mult := EquipmentManager.SPECIALTY_XP_MULT if specialized else 1.0
	var total := int(character.class_xp.get(cid, 0)) + roundi(amount * mult)
	character.class_xp[cid] = total
	var before := character.get_class_level(cid)
	var lvl := maxi(before, 1)
	while lvl < CLASS_LEVEL_MAX and total >= CLASS_LEVEL_THRESHOLDS[lvl + 1]:
		lvl += 1
	character.class_levels[cid] = lvl
	if lvl > before:
		_check_class_unlocks(character)
	return lvl - before


static func _check_class_unlocks(character: CharacterData) -> void:
	for cls in ClassLibrary.get_all_classes():
		if character.get_class_level(cls.id) == 0 and ClassLibrary.is_unlocked_for(cls.id, character):
			character.class_levels[cls.id] = 1
			EventBus.class_unlocked.emit(character.id, cls.id)


## Spend microchips at a terminal to learn an ability of an unlocked class.
static func learn_ability(character: CharacterData, ability_id: String) -> String:
	var ability := ContentDB.get_ability(ability_id)
	if ability == null:
		return "Unknown ability."
	if character.learned_ability_ids.has(ability_id):
		return "Already learned."
	if ability.absorb_only:
		return "This can only be learned by taking the hit."
	if ability.class_id != "" and character.get_class_level(ability.class_id) == 0:
		return "Class not unlocked."
	if GameManager.microchips < ability.chip_cost:
		return "Need %d microchips." % ability.chip_cost
	GameManager.add_microchips(-ability.chip_cost)
	character.learned_ability_ids.append(ability_id)
	EventBus.ability_unlocked.emit(character.id, ability_id)
	return ""


## Switch jobs (only to unlocked classes).
static func change_class(character: CharacterData, class_id: String) -> bool:
	if character.get_class_level(class_id) == 0 and not ClassLibrary.is_unlocked_for(class_id, character):
		return false
	character.class_id = class_id
	if character.get_class_level(class_id) == 0:
		character.class_levels[class_id] = 1
	return true
