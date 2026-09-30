extends Resource
class_name ItemResource

enum ItemCategory {
	WEAPON,
	ARMOR,
	ACCESSORY,
	TRINKET,
	MATERIAL,
	CONSUMABLE
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

@export_group("Identity")
@export var item_name: String = "New Item"
@export var description: String = ""
@export var category: ItemCategory = ItemCategory.MATERIAL
@export var slot: String = "MainHand" # Defines which equipment slot this occupies
@export var rarity: Rarity = Rarity.COMMON
@export var icon_path: String = ""

@export_group("Stats & Effects")
@export var stat_modifiers: Dictionary = {} # e.g., {"attack": 5, "defense": 2}
@export var special_ability: String = "" # Hook for specific gameplay logic
@export var value: int = 100

@export_group("Crafting")
@export var is_craftable: bool = false
@export var required_materials: Array[ItemResource] = []
@export var crafting_cost: int = 0

# Helper to get a specific stat bonus
func get_stat_bonus(stat_name: String) -> int:
	return stat_modifiers.get(stat_name, 0)