class_name DispatchMission
extends GameResource
## An off-screen, timer-based errand a party member can be sent on (FFTA2-style).
## Success is rolled from the dispatched character's stats vs. difficulty.

@export var duration_minutes: float = 30.0
## 0 = trivial ... 100 = brutal. Compared against the character's dispatch score.
@export var difficulty: int = 30
## Stats that matter for this job, weighted: {"agility": 1.0, "intelligence": 0.5}.
@export var stat_weights: Dictionary = {"strength": 1.0}
## Classes that get a bonus (fits the job): {"smuggler": 15}.
@export var class_affinity: Dictionary = {}
@export var min_level: int = 1
@export var loot_table_id: String = ""
@export var soul_coin_reward: int = 150
@export var xp_reward: int = 60
## Flavor lines shown on return — success and failure. Rumors about the war go here.
@export var success_text: String = ""
@export var failure_text: String = ""
@export var rumor_ids: Array[String] = []
@export var required_flag: String = ""
