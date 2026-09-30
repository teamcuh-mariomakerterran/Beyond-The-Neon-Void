extends Resource
class_name DeckResource

@export var owner_unit_id: String = ""
@export var total_pool: Array[CardResource] = []
@export var active_deck: Array[CardResource] = []

func add_card_to_pool(card: CardResource) -> void:
	if not total_pool.has(card):
		total_pool.append(card)

func set_active_deck(cards: Array[CardResource]) -> void:
	if cards.size() > 10:
		push_error("Deck Stacker active deck cannot exceed 10 cards.")
		return
	
	for card in cards:
		if not total_pool.has(card):
			push_error("Cannot add card to active deck that is not in the player's pool.")
			return
			
	active_deck = cards

func remove_card_from_deck(card: CardResource) -> void:
	if active_deck.has(card):
		active_deck.erase(card)

func get_card_count() -> int:
	return total_pool.size()

func get_active_count() -> int:
	return active_deck.size()

func draw_random_card() -> CardResource:
	if active_deck.size() == 0:
		return null
	return active_deck.pick_random()