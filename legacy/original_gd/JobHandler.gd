extends Node

## JobHandler manages the current Job (Class) of a unit.
## It handles stat application and the execution of job-specific abilities.

@export var current_job: JobData

signal job_changed(new_job: JobData)

func _ready() -> void:
	if current_job:
		apply_job_stats()

## Sets the active job and refreshes the unit's stats.
func set_job(new_job: JobData) -> void:
	current_job = new_job
	apply_job_stats()
	job_changed.emit(new_job)

## Applies the base stats from the JobData to the Unit's stats component.
func apply_job_stats() -> void:
	if not current_job:
		return
		
	var unit = get_parent() as Unit
	if unit:
		var stats = unit.get_node("UnitStats") as UnitStats
		if stats:
			stats.apply_class_modifiers(current_job)

## Executes an ability defined in the JobData.
## The Ability resource handles the actual logic, while the Handler provides the context.
func execute_ability(ability: Ability, target_pos: Vector2 = Vector2.ZERO, target_unit: Unit = null) -> void:
	if not ability:
		return
		
	var unit = get_parent() as Unit
	if not unit:
		return

	# Check if the unit has enough AP/Resources as defined by the ability
	if not unit.has_resource(ability.resource_cost):
		return

	# Ability logic is delegated to the Ability resource itself
	var success = ability.resolve(unit, target_pos, target_unit)
	
	if success:
		unit.consume_resource(ability.resource_cost)

## Helper to get a specific ability by name from the current job.
func get_ability_by_name(ability_name: String) -> Ability:
	if not current_job:
		return null
		
	for ability in current_job.abilities:
		if ability.ability_name == ability_name:
			return ability
			
	return null