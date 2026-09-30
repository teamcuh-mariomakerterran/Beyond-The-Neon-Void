class_name LootTable
extends GameResource
## Weighted loot table used by battles, dispatch missions and hidden prop loot.

## [{"item_id": "mat_scrap_wire", "weight": 40, "min": 1, "max": 3}, ...]
@export var entries: Array[Dictionary] = []
## How many independent rolls to make.
@export var rolls: int = 2
## Soul coin range added on top of items.
@export var soul_coins_min: int = 0
@export var soul_coins_max: int = 0


## Returns {"soul_coins": int, "items": {item_id: qty}}.
## `luck` (0..1) nudges rolls toward the rarer (lower-weight) half of the table.
func roll(rng: RandomNumberGenerator, luck: float = 0.0, extra_rolls: int = 0) -> Dictionary:
	var items := {}
	var total_weight := 0.0
	for e: Dictionary in entries:
		total_weight += float(e.get("weight", 1))
	if total_weight > 0.0:
		for _i in range(maxi(rolls + extra_rolls, 0)):
			var pick := rng.randf() * total_weight
			if luck > 0.0:
				pick = lerpf(pick, total_weight, clampf(luck, 0.0, 1.0) * rng.randf() * 0.5)
			var acc := 0.0
			for e: Dictionary in entries:
				acc += float(e.get("weight", 1))
				if pick <= acc:
					var qty := rng.randi_range(int(e.get("min", 1)), int(e.get("max", 1)))
					var item_id: String = e.get("item_id", "")
					items[item_id] = int(items.get(item_id, 0)) + qty
					break
	var coins := rng.randi_range(soul_coins_min, maxi(soul_coins_min, soul_coins_max))
	return {"soul_coins": coins, "items": items}
