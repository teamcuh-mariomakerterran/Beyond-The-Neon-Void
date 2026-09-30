class_name ItemResource
extends GameResource
## Item definition: weapons, armor, accessories, consumables, crafting mats, chips.
## Player-owned copies (with level / XP / rolled bonuses) are ItemInstance dictionaries
## managed by GameManager and ForgeManager.

enum Category { WEAPON, ARMOR, ACCESSORY, TRINKET, MATERIAL, CONSUMABLE, MICROCHIP, KEY }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var category: Category = Category.MATERIAL
@export var rarity: Rarity = Rarity.COMMON
@export var icon_path: String = ""
## Buy price in soul coins (sell = 50%).
@export var value: int = 100

@export_group("Equipment")
## Weapon family ("blade", "pistol", "rifle", "deck", ...) or armor family.
@export var equip_type: String = ""
## Flat stat bonuses at item level 1, e.g. {"attack": 6}.
@export var stat_modifiers: Dictionary = {}
## Per-level growth of stat_modifiers (multiplied by item level - 1).
@export var stat_growth: Dictionary = {}
@export var weapon_range: int = 1
## Hook for on-hit or passive effects.
@export var special_ability: String = ""

@export_group("Consumable")
@export var heal_hp: int = 0
@export var heal_mp: int = 0
@export var cure_status_ids: Array[String] = []

@export_group("Crafting")
## Material quality: 0 = junk (sell / filler), 1 = common, 2 = uncommon, 3 = rare, 4 = super.
@export var material_grade: int = 0
## Max level this item can reach (weapons/gear cap at 50).
@export var max_level: int = 50
## Item ids this can evolve into once level >= ForgeManager.EVOLVE_MIN_LEVEL.
@export var evolves_into: Array[String] = []

@export_group("Discovery")
@export var lore_text: String = ""


func is_equipment() -> bool:
	return category in [Category.WEAPON, Category.ARMOR, Category.ACCESSORY, Category.TRINKET]


func slot_name() -> String:
	match category:
		Category.WEAPON: return "weapon"
		Category.ARMOR: return "armor"
		Category.ACCESSORY: return "accessory"
		Category.TRINKET: return "trinket"
	return ""


## Stat bonus at a given item level, before evolution potential.
func get_stat_bonus(stat_name: String, item_level: int = 1) -> int:
	var base := float(stat_modifiers.get(stat_name, 0))
	var per_level := float(stat_growth.get(stat_name, 0))
	return roundi(base + per_level * maxi(item_level - 1, 0))
