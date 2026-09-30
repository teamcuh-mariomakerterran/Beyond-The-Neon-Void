class_name CardResource
extends Ability
## A card for Deck Stacker-style classes. Cards ARE abilities, with two twists:
## each card can be played once per battle, and cards are crafted/collected
## like gear. A deck (DeckResource) replaces the weapon for card classes.

enum CardRarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export_group("Card")
@export var rarity: CardRarity = CardRarity.COMMON
@export var card_art_path: String = ""
## One of the rare late-game craftable cards.
@export var is_late_game: bool = false
## Materials to craft this card, e.g. {"mat_neon_ink": 2, "mat_essence_shard": 1}.
@export var crafting_materials: Dictionary = {}
## Soul coin price at the card dealer.
@export var price: int = 200


func is_legendary_craft() -> bool:
	return rarity == CardRarity.LEGENDARY and is_late_game
