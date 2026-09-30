extends Node
class_name DispatchManager

## Manages asynchronous unit missions, timers, and loot distribution.
## This is an Autoload singleton.

signal mission_started(mission_id: String, unit_id: int)
signal mission_completed(mission_id: String, unit_id: int, success: bool, rewards: Array)
signal mission_failed(mission_id: String, unit_id: int)

# Data structure for a dispatch mission
class MissionData:
	var mission_id: String
	var unit_id: int
	var duration_seconds: float
	var start_time: float
	var difficulty: float # 0.0 to 1.0
	var reward_table: Array[Resource] # List of ItemResources
	var currency_reward: int

var active_missions: Dictionary = {} # { mission_id: MissionData }
var dispatch_timer: Timer

func _ready() -> void:
	dispatch_timer = Timer.new()
	dispatch_timer.timeout.connect(_on_timer_timeout)
	add_child(dispatch_timer)

## Starts a dispatch mission for a specific unit
func start_mission(unit_id: int, mission_id: String) -> void:
	var mission_data = _get_mission_config(mission_id)
	if not mission_data:
		return

	var unit = UnitManager.get_unit_by_id(unit_id)
	if not unit:
		return

	# Mark unit as unavailable
	unit.set_status("dispatched")
	
	var completion_time = Time.get_unix_time_from_datetime(DateTime.current_datetime_to_datetime()) + mission_data.duration_seconds
	
	active_missions[mission_id] = {
		"unit_id": unit_id,
		"completion_time": completion_time,
		"mission_config": mission_data
	}
	
	# Start global timer check if not already running
	if dispatch_timer.is_stopped():
		dispatch_timer.start(60.0) # Check every minute

func _on_timer_timeout() -> void:
	var current_time = Time.get_unix_time_from_datetime(DateTime.current_datetime_to_datetime())
	var completed_missions = []

	for mid