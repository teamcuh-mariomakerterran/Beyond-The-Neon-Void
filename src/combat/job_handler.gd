class_name JobHandler
extends Node
## Manages a Unit's current Job (class): applies it to stats and builds the
## command list (innate + learned + secondary class + cards). Abilities are
## Resources; the handler only provides context and calls ability.resolve().

signal job_changed(new_job: ClassResource)

var current_job: ClassResource
var secondary_job: ClassResource
var learned_ability_ids: Array[String] = []
var deck: DeckResource


func unit() -> Node:
	return get_parent()


func set_job(new_job: ClassResource) -> void:
	current_job = new_job
	job_changed.emit(new_job)
	if unit() and unit().has_method("refresh_stats"):
		unit().refresh_stats()


func set_job_by_id(class_id: String) -> void:
	var job := ClassLibrary.get_class_res(class_id)
	if job:
		set_job(job)


## Command list for the action menu.
func get_ability_list() -> Array[Ability]:
	var out: Array[Ability] = []
	var basic := ContentDB.get_ability("basic_attack")
	if current_job and current_job.uses_deck and deck:
		for card_id in deck.playable_cards():
			var card := ContentDB.get_card(card_id)
			if card and not out.has(card):
				out.append(card)
	elif basic:
		out.append(basic)
	for job: ClassResource in [current_job, secondary_job]:
		if job == null:
			continue
		for aid in job.innate_ability_ids:
			_append_ability(out, aid, job == current_job)
		for aid in job.learnable_ability_ids:
			if learned_ability_ids.has(aid):
				_append_ability(out, aid, true)
	return out


func _append_ability(out: Array[Ability], ability_id: String, allowed: bool) -> void:
	if not allowed:
		return
	var a := ContentDB.get_ability(ability_id)
	if a and not out.has(a):
		out.append(a)


func get_ability_by_id(ability_id: String) -> Ability:
	for a in get_ability_list():
		if a.id == ability_id:
			return a
	return null


## Resolves an ability with a fully built context. Cost checks live in CombatManager.
func execute_ability(ability: Ability, ctx: Ability.Context) -> Array[Dictionary]:
	if ability is CardResource and deck:
		if not deck.spend(ability.id):
			return []
		EventBus.card_spent.emit(unit(), ability)
	return ability.resolve(ctx)
