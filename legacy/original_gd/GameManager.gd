extends Node

# GameManager.gd - Global singleton for party, progression, and world state
# Handles character rosters, unlocked classes, story flags, and currency.

signal party_changed
signal story_progress_updated
signal currency_changed

# --- State Variables ---
var current_currency: int = 500
var story_chapter: int = 1
var story_flags: Dictionary = {}
var hub_visits_count: int = 0
var correct_dialog_streak: int = 0

# --- Character & Party Management ---
# All characters available in the game
var all_characters: Array[CharacterData] = []
# Characters currently selected for the 5-man battle party
var active_party: Array[CharacterData] = []
const MAX_PARTY_SIZE: int = 5

# --- Class & Unlockables ---
var unlocked_classes: Array[String] = ["Corporate Enforcer", "Gunslinger", "Hacker", "Digital Healer", "Neon Samurai", "Void Technician", "Cyber-Medic", "Neural Saboteur"]
var secret_characters_unlocked: Array[String] = []

func _ready() -> void:
	initialize_game()

func initialize_game() -> void:
	# Initialize the class registry before loading saves
	ClassLibrary.initialize_archetypes()
	
	# Integration with SaveManager to restore world state
	if SaveManager.has_save_file():
		SaveManager.load_game()
	else:
		# Setup initial new game state
		print("Cyberpunk Tactics: Starting new campaign.")
	
	print("Cyberpunk Tactics: GameManager initialized.")

# --- Party Logic ---
func add_character_to_roster(char_data: CharacterData) -> void:
	if not all_characters.has(char_data):
		all_characters.append(char_data)

func set_active_party(chars: Array[CharacterData]) -> void:
	if chars.size() > MAX_PARTY_SIZE:
		push_error("Party size cannot exceed " + str(MAX_PARTY_SIZE))
		return
	
	active_party = chars
	party_changed.emit()

# --- Economy & Progression ---
func add_currency(amount: int) -> void:
	current_currency += amount
	currency_changed.emit()

func spend_currency(amount: int) -> bool:
	if current_currency >= amount:
		current_currency -= amount
		currency_changed.emit()
		return true
	return false

func set_story_flag(flag_name: String, value: bool) -> void:
	story_flags[flag_name] = value
	story_progress_updated.emit()

func check_story_flag(flag_name: String) -> bool:
	return story_flags.get(flag_name, false)

# --- Hub & Secret Unlocks ---
func record_hub_visit(dialog_correct: bool) -> void:
	hub_visits_count += 1
	if dialog_correct:
		correct_dialog_streak += 1
	else:
		correct_dialog_streak = 0 # Reset streak on wrong choice
	
	# Check for secret unlock: 5 consecutive correct dialogs
	if correct_dialog_streak >= 5:
		unlock_secret_character("The Drunken Oracle")
		correct_dialog_streak = 0 # Reset after unlock

func unlock_secret_character(char_id: String) -> void:
	if not secret_characters_unlocked.has(char_id):
		secret_characters_unlocked.append(char_id)
		print("Secret Character Unlocked: " + char_id)
		# Here you would trigger a UI notification or event

# --- Helper Data Class (Simplified) ---
# In a real project, this would be a separate script extending Resource
class CharacterData:
	@export var name: String
	@export var job_class: String
	@export var level: int = 1
	@export var base_stats: Dictionary = {"hp": 10, "mp": 10, "atk": 5}
	
	func _init(_name: String, _class: String):
		self.name = _name
		self.job_class = _class