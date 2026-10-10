extends Node
## VendorSystem — shops defined in data/vendors.json.
##
## A vendor: {"name", "portrait", "greeting", "stock": [{"id", "price"?, "qty"?, "required_flag"?}],
##            "price_mult", "buyback": bool, "character_id"?}
## Vendors can be backed by a CharacterData (for the late-game "fight the
## shopkeeper" quest) via character_id.

signal purchased(vendor_id: String, item_id: String, price: int)
signal sold(item_id: String, price: int)

## Remaining limited stock: {vendor_id: {item_id: qty_left}}
var stock_left: Dictionary = {}


func get_vendor(vendor_id: String) -> Dictionary:
	return ContentDB.vendors.get(vendor_id, {})


func price_of(vendor_id: String, item_id: String) -> int:
	var v := get_vendor(vendor_id)
	var base := 0
	for s: Dictionary in v.get("stock", []):
		if s.get("id") == item_id and s.has("price"):
			base = int(s["price"])
	if base == 0:
		var item := ContentDB.get_item(item_id)
		var card := ContentDB.get_card(item_id)
		base = item.value if item else (card.price if card else 0)
	return roundi(base * float(v.get("price_mult", 1.0)))


func available_stock(vendor_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in get_vendor(vendor_id).get("stock", []):
		var flag := str(s.get("required_flag", ""))
		if flag != "" and not GameManager.check_story_flag(flag):
			continue
		var left := _qty_left(vendor_id, s)
		if left == 0:
			continue
		var entry := s.duplicate()
		entry["price"] = price_of(vendor_id, s["id"])
		entry["qty_left"] = left
		out.append(entry)
	return out


func _qty_left(vendor_id: String, s: Dictionary) -> int:
	if not s.has("qty"):
		return -1  # unlimited
	var v_stock: Dictionary = stock_left.get(vendor_id, {})
	return int(v_stock.get(s["id"], int(s["qty"])))


## Buys one item. Equipment goes to the inventory; pass a character to auto-equip.
func buy_item(vendor_id: String, item_id: String, equip_to: CharacterData = null) -> String:
	var entry: Dictionary = {}
	for s: Dictionary in available_stock(vendor_id):
		if s["id"] == item_id:
			entry = s
	if entry.is_empty():
		return "Not in stock."
	var price := int(entry["price"])
	if not GameManager.spend_soul_coins(price):
		Sfx.event("denied")
		return "Not enough soul coins."
	if int(entry["qty_left"]) > 0:
		if not stock_left.has(vendor_id):
			stock_left[vendor_id] = {}
		stock_left[vendor_id][item_id] = int(entry["qty_left"]) - 1
	var item := ContentDB.get_item(item_id)
	if item and item.is_equipment():
		var inst := GameManager.create_item_instance(item_id)
		if equip_to:
			equip_to.equipment[item.slot_name()] = inst["uid"]
	else:
		GameManager.give_item(item_id, 1)
	purchased.emit(vendor_id, item_id, price)
	Sfx.event("shop_buy")
	return ""


func sell_stack(item_id: String, qty: int = 1) -> String:
	var item := ContentDB.get_item(item_id)
	if item == null or not GameManager.remove_stack_item(item_id, qty):
		return "Nothing to sell."
	var price := roundi(item.value * 0.5) * qty
	GameManager.add_soul_coins(price)
	sold.emit(item_id, price)
	return ""


# --- Save hooks ------------------------------------------------------------

func reset() -> void:
	stock_left.clear()


func get_state_data() -> Dictionary:
	return {"stock_left": stock_left.duplicate(true)}


func load_state_data(d: Dictionary) -> void:
	stock_left.clear()
	var s: Dictionary = d.get("stock_left", {})
	for v: String in s:
		stock_left[v] = {}
		for item: String in s[v]:
			stock_left[v][item] = int(s[v][item])
