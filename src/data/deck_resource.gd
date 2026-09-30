class_name DeckResource
extends RefCounted
## A card-class character's deck. The pool is every card they own; the active
## deck (max MAX_ACTIVE) is what they bring into battle. Each card in the active
## deck can be played once per battle.

const MAX_ACTIVE := 10

var owner_id: String = ""
var pool: Array[String] = []
var active: Array[String] = []
var _spent_this_battle: Array[String] = []


func add_card_to_pool(card_id: String) -> void:
	pool.append(card_id)  # duplicates allowed: owning two copies lets you run two


func set_active_deck(card_ids: Array[String]) -> String:
	if card_ids.size() > MAX_ACTIVE:
		return "A deck can hold at most %d cards." % MAX_ACTIVE
	var remaining := pool.duplicate()
	for id in card_ids:
		var idx := remaining.find(id)
		if idx == -1:
			return "Card '%s' is not in the pool (or not enough copies)." % id
		remaining.remove_at(idx)
	active = card_ids.duplicate()
	return ""


func reset_for_battle() -> void:
	_spent_this_battle.clear()


## Cards still playable this battle (one entry per copy).
func playable_cards() -> Array[String]:
	var remaining := active.duplicate()
	for id in _spent_this_battle:
		remaining.erase(id)
	return remaining


func spend(card_id: String) -> bool:
	if not playable_cards().has(card_id):
		return false
	_spent_this_battle.append(card_id)
	return true


func to_dict() -> Dictionary:
	return {"owner_id": owner_id, "pool": pool.duplicate(), "active": active.duplicate()}


static func from_dict(data: Dictionary) -> DeckResource:
	var deck := DeckResource.new()
	deck.owner_id = str(data.get("owner_id", ""))
	deck.pool.assign(data.get("pool", []))
	deck.active.assign(data.get("active", []))
	return deck
