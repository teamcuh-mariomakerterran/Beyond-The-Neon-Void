extends Node2D

## HubWorld.gd - Manages the Cyberpunk Dive Bar hub
## Handles character roaming, NPC interactions, and transition to battle.

@export var player_character: CharacterBody2D
@export var bartender_npc: Area2D
@export var gear_vendor_npc: Area2D

var active_dialogue: String = ""
var is_interacting: bool = false

func _ready() -> void:
	setup_hub_environment()
	spawn_roaming_party_members()

func setup_hub_environment() -> void:
	# Logic to initialize the dive bar atmosphere (lighting, ambient sound)
	print("Welcome to the Neon Gutter Dive Bar.")

func spawn_roaming_party_members() -> void:
	# Iterate through GameManager's current party and spawn them as NPCs
	# if they aren't the current player character.
	var party = GameManager.get_party_members()
	for member in party:
		if member != player_character:
			var roaming_npc = instantiate_roaming_character(member)
			add_child(roaming_npc)
			roaming_npc.position = get_random_hub_position()

var current_trigger: Node2D = null

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact") and current_trigger != null:
		handle_interaction()

func on_trigger_entered(trigger: Node2D) -> void:
	current_trigger = trigger
	UIManager.show_interaction_prompt(trigger.interaction_text)

func on_trigger_exited() -> void:
	current_trigger = null
	UIManager.hide_interaction_prompt()

func handle_interaction() -> void:
	if current_trigger == bartender_npc:
		open_bartender_menu()
	elif current_trigger == gear_vendor_npc:
		open_gear_vendor_menu()
	elif current_trigger.is_in_group("mission_boards"):
		start_mission(current_trigger.get_mission_id())
	else:
		print("Interacted with unknown object")

func check_for_mission_triggers() -> void:
	# Check for nearby mission boards or contracts
	var mission_boards = get_tree().get_nodes_in_group("mission_boards")
	for board in mission_boards:
		if player_character.global_position.distance_to(board.global_position) < 100:
			# In a real scenario, this opens a list of available missions
			# For now, we trigger the first available mission associated with the board
			var available_mission = board.get_mission_id()
			start_mission(available_mission)
			return

func start_mission(mission_id: String) -> void:
	print("Starting Mission: ", mission_id)
	CampaignManager.current_mission = mission_id
	# Transition to battle scene
	get_tree().change_scene_to_file("res://Scenes/BattleMap.tscn")

func open_bartender_menu() -> void:
	# Bartender handles consumable items (healing/buffs)
	print("Bartender: 'What's your poison? Keep it simple, I've had a long day.'")
	UIManager.open_vendor_menu("bartender_stock")

func open_gear_vendor_menu() -> void:
	# Gear vendor modifies ClassResource stats (strength/defense)
	print("Vendor: '*hiccup*... You want a laser rifle? I got a laser rifle... maybe.'")
	UIManager.open_vendor_menu("gear_vendor_stock")

func _on_purchase_confirmed(item_id: String) -> void:
	# Bridge between UI and CampaignManager for currency deduction
	var cost = CampaignManager.get_item_cost(item_id)
	if CampaignManager.currency >= cost:
		CampaignManager.spend_currency(cost)
		CampaignManager.add_item_to_party(item_id)
		print("Purchased ", item_id, ". Remaining Credits: ", CampaignManager.currency)
	else:
		print("Not enough credits!")

func get_random_hub_position() -> Vector2:
	# Return a valid walkable coordinate within the dive bar bounds
	return Vector2(randf_range(100, 500), randf_range(100, 500))

func instantiate_roaming_character(data) -> CharacterBody2D:
	# Logic to spawn a character model based on the ClassResource
	var char_node = CharacterBody2D.new()
	# Assign sprite, animation, and basic 'idle' wandering AI
	return char_node
)
)
