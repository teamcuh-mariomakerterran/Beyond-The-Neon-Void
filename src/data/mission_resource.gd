class_name MissionResource
extends GameResource
## A story or side battle: which map, who shows up, how you win, what you get.

@export var map_id: String = ""
@export var chapter: int = 1
@export var music_id: String = ""
@export var briefing: String = ""
## PARALLAX cutscenes (tools/cutscene_builder) played before / after the fight.
@export var intro_cutscene: String = ""
@export var outro_cutscene: String = ""

@export_group("Encounter")
## [{"character_id": "doctrine_grunt", "cell": [x, y], "level": 3, "ai": "aggressive"}, ...]
@export var enemies: Array[Dictionary] = []
## Guest / allied NPC units controlled by the AI on the player's team.
@export var guests: Array[Dictionary] = []
@export var max_party_size: int = 5
@export var difficulty_modifier: float = 1.0

@export_group("Win / lose")
## One of: "defeat_all", "defeat_target", "survive", "reach_cell", "protect"
@export var win_condition: String = "defeat_all"
## Target character id, round count, or "x,y" cell depending on win_condition.
@export var win_param: String = ""
## "party_wiped", "leader_down" (lose_param = character id), "time_limit" (rounds)
@export var lose_condition: String = "party_wiped"
@export var lose_param: String = ""

@export_group("Rewards")
@export var soul_coin_reward: int = 200
@export var xp_reward: int = 120
@export var loot_table_id: String = ""
@export var microchip_reward: int = 1
@export var story_flags_on_win: Array[String] = []
@export var unlocks_mission_ids: Array[String] = []
## The Lying HUD (InfoFilter): the warped zone's Doctrine Relay skews what the
## HUD shows until it's hacked or destroyed.
@export var lying_hud: bool = false
## Winning this closes its chapter (story_chapter + 1, Hangover Morning).
@export var ends_chapter: bool = false


func get_total_reward_text() -> String:
	return "Rewards: %d Soul Coins, %d XP, %d Microchip(s)" % [soul_coin_reward, xp_reward, microchip_reward]
