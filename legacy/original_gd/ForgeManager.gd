extends Node

## ForgeManager handles the logic for upgrading and combining items.
## It interfaces with the ItemResource system to determine recipes and results.

# Signal to notify UI that a crafting process has finished
signal item_crafted(result_item: Resource)
signal craft_failed(reason: String)

# Store the current inventory reference to check for materials
var player_inventory: Array = []

func _ready():
	# In a real scenario, this would be linked to a Global Inventory Manager
	pass

## Attempts to craft a higher-tier item from a list of ingredients
## ingredients: Array of ItemResource to be consumed
## target_recipe_id: The ID of the item the player is trying to create
func craft_item(ingredients: Array[Resource], target_recipe_id: String) -> bool:
	if ingredients.is_empty():
		_fail_craft("No materials provided.")
		return false

	# Verify if the target item exists in the library and if the ingredients match