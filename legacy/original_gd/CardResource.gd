extends Resource
class_name CardResource

enum CardRarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum EffectType { DAMAGE, HEAL, BUFF, DEBUFF, UTILITY }

@export_group("Identity")
@export var card_name: String = "New Card"
@export var description: String = ""
@export var rarity: CardRarity = CardRarity.COMMON

@export_group("Mechanics")
@export var effect_type: EffectType = EffectType.DAMAGE
@export var value: float = 10.0
@export var target_count: int = 1
@export var cost_ap: int = 1

@export_group("Crafting")
@export var is_late_game: bool = false
@export var crafting_materials: Dictionary = {} # e.g. {"Steel": 2, "Essence": 1}

func execute_effect(user: Node, target: Node):
	# Logic to be handled by the combat system based on effect_type and value
	pass

# Helper to determine if this card is one of the 5 rare late-game cards
func is_legendary_craft():
	return rarity == CardRarity.LEGENDARY and is_late_game