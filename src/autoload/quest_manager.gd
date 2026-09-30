extends Node
## QuestManager — side jobs from the Neon Gutter regulars.
##
## State per quest: "locked" | "available" | "active" | "complete".
## Only active/complete (and chain-unlocked "available") states are stored;
## everything else is derived from prerequisites, so new content just works
## with old saves. Objective progress is driven by EventBus signals.
##
## Turning in a collect_item quest consumes the items ("bring me three...").

const LOCKED := "locked"
const AVAILABLE := "available"
const ACTIVE := "active"
const COMPLETE := "complete"

## quest_id -> stored state (ACTIVE, COMPLETE, or AVAILABLE when unlocked by a chain).
var _states: Dictionary = {}
## quest_id -> Array of int counts, one per objective.
var _progress: Dictionary = {}


func _ready() -> void:
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.loot_discovered.connect(_on_loot_discovered)
	EventBus.story_flag_changed.connect(_on_story_flag_changed)
	EventBus.unit_died.connect(_on_unit_died)


func reset() -> void:
	_states.clear()
	_progress.clear()


# --- Queries ---------------------------------------------------------------

func get_state(quest_id: String) -> String:
	var stored := str(_states.get(quest_id, ""))
	if stored == ACTIVE:
		return ACTIVE
	if stored == COMPLETE:
		var q := ContentDB.get_quest(quest_id)
		return AVAILABLE if q and q.repeatable and _prereqs_met(q) else COMPLETE
	return AVAILABLE if is_available(quest_id) else LOCKED


func is_available(quest_id: String) -> bool:
	var q := ContentDB.get_quest(quest_id)
	if q == null:
		return false
	var stored := str(_states.get(quest_id, ""))
	if stored == ACTIVE:
		return false
	if stored == COMPLETE:
		return q.repeatable and _prereqs_met(q)
	if stored == AVAILABLE:
		return true
	return _prereqs_met(q)


func _prereqs_met(q: QuestResource) -> bool:
	if GameManager.story_chapter < q.min_chapter:
		return false
	for pid in q.prerequisite_quest_ids:
		if str(_states.get(pid, "")) != COMPLETE:
			return false
	for f in q.prerequisite_flags:
		if not GameManager.check_story_flag(f):
			return false
	return true


## Quests this NPC hands out (giver_npc_id or listed in the NPC's quest_ids).
func quests_of(npc_id: String) -> Array[QuestResource]:
	var out: Array[QuestResource] = []
	var npc := ContentDB.get_npc(npc_id)
	for q: QuestResource in ContentDB.get_all("quests"):
		if q.giver_npc_id == npc_id or (npc and npc.quest_ids.has(q.id)):
			out.append(q)
	return out


func available_quests_for(npc_id: String) -> Array[QuestResource]:
	var out: Array[QuestResource] = []
	for q in quests_of(npc_id):
		if is_available(q.id):
			out.append(q)
	return out


func active_quests() -> Array[String]:
	var out: Array[String] = []
	for id: String in _states:
		if _states[id] == ACTIVE:
			out.append(id)
	return out


func get_progress(quest_id: String) -> Array:
	return (_progress.get(quest_id, []) as Array).duplicate()


func is_objective_done(quest_id: String, index: int) -> bool:
	var q := ContentDB.get_quest(quest_id)
	var p: Array = _progress.get(quest_id, [])
	if q == null or index < 0 or index >= p.size():
		return false
	return int(p[index]) >= q.objective_count(index)


func is_ready_to_complete(quest_id: String) -> bool:
	var q := ContentDB.get_quest(quest_id)
	if q == null or str(_states.get(quest_id, "")) != ACTIVE:
		return false
	_refresh_collect(quest_id)
	for i in q.objectives.size():
		if not is_objective_done(quest_id, i):
			return false
	return true


# --- Actions ---------------------------------------------------------------

## Returns "" on success, otherwise why it can't be accepted.
func accept(quest_id: String) -> String:
	var q := ContentDB.get_quest(quest_id)
	if q == null:
		return "Unknown quest."
	if str(_states.get(quest_id, "")) == ACTIVE:
		return "Already on it."
	if not is_available(quest_id):
		return "Not yet."
	_states[quest_id] = ACTIVE
	var counts: Array = []
	counts.resize(q.objectives.size())
	counts.fill(0)
	_progress[quest_id] = counts
	EventBus.quest_state_changed.emit(quest_id, ACTIVE)
	# Credit things that are already true (mission done, flag set, crate looted).
	for i in q.objectives.size():
		var o: Dictionary = q.objectives[i]
		var target := str(o.get("target", ""))
		match str(o.get("type", "")):
			"complete_mission":
				if CampaignManager.is_completed(target):
					_set_count(quest_id, i, q.objective_count(i))
			"flag":
				if GameManager.check_story_flag(target):
					_set_count(quest_id, i, 1)
			"find_loot":
				if GameManager.check_story_flag("found_" + target):
					_set_count(quest_id, i, q.objective_count(i))
	_refresh_collect(quest_id)
	return ""


## Turns the quest in if every objective is done. Pays rewards.
func try_complete(quest_id: String) -> bool:
	if not is_ready_to_complete(quest_id):
		return false
	var q := ContentDB.get_quest(quest_id)
	_states[quest_id] = COMPLETE
	_progress.erase(quest_id)
	for o: Dictionary in q.objectives:
		if str(o.get("type", "")) == "collect_item":
			_consume(str(o.get("target", "")), maxi(int(o.get("count", 1)), 1))
	GameManager.add_soul_coins(q.reward_soul_coins)
	GameManager.add_microchips(q.reward_microchips)
	for iid: String in q.reward_items:
		GameManager.give_item(iid, int(q.reward_items[iid]))
	if q.reward_xp > 0:
		for c in GameManager.get_party_members():
			ProgressionSystem.add_xp(c, q.reward_xp)
	for f in q.reward_flags:
		GameManager.set_story_flag(f)
	for mid in q.unlocks_mission_ids:
		CampaignManager.unlock_mission(mid)
	if q.next_quest_id != "" and not _states.has(q.next_quest_id):
		_states[q.next_quest_id] = AVAILABLE
		EventBus.quest_state_changed.emit(q.next_quest_id, AVAILABLE)
	EventBus.quest_state_changed.emit(quest_id, COMPLETE)
	EventBus.log_message.emit("Quest complete: %s" % q.display_name)
	return true


## Call when the player talks to an NPC (the hub's TALK button does).
func notify_talk(npc_id: String) -> void:
	_bump("talk_to", npc_id)


# --- Tracking --------------------------------------------------------------

func _bump(type: String, target: String, amount: int = 1) -> void:
	for qid in active_quests():
		var q := ContentDB.get_quest(qid)
		if q == null:
			continue
		for i in q.objectives.size():
			var o: Dictionary = q.objectives[i]
			if str(o.get("type", "")) == type and str(o.get("target", "")) == target:
				_set_count(qid, i, int(_progress[qid][i]) + amount)


func _set_count(quest_id: String, index: int, count: int) -> void:
	var q := ContentDB.get_quest(quest_id)
	var p: Array = _progress.get(quest_id, [])
	if q == null or index >= p.size():
		return
	var clamped := clampi(count, 0, q.objective_count(index))
	if int(p[index]) == clamped:
		return
	p[index] = clamped
	EventBus.quest_objective_progress.emit(quest_id, index, clamped)


func _refresh_collect(quest_id: String) -> void:
	var q := ContentDB.get_quest(quest_id)
	if q == null or str(_states.get(quest_id, "")) != ACTIVE:
		return
	for i in q.objectives.size():
		var o: Dictionary = q.objectives[i]
		if str(o.get("type", "")) == "collect_item":
			_set_count(quest_id, i, held_count(str(o.get("target", ""))))


## Stackables, cards, and unequipped-or-not gear instances all count.
static func held_count(item_id: String) -> int:
	var n := GameManager.get_stack_count(item_id) + int(GameManager.cards.get(item_id, 0))
	for inst: Dictionary in GameManager.item_instances.values():
		if inst.get("item_id") == item_id:
			n += 1
	return n


func _consume(item_id: String, qty: int) -> void:
	var from_stack := mini(GameManager.get_stack_count(item_id), qty)
	if from_stack > 0:
		GameManager.remove_stack_item(item_id, from_stack)
		qty -= from_stack
	if qty > 0 and GameManager.cards.has(item_id):
		var from_cards := mini(int(GameManager.cards[item_id]), qty)
		GameManager.cards[item_id] = int(GameManager.cards[item_id]) - from_cards
		if GameManager.cards[item_id] <= 0:
			GameManager.cards.erase(item_id)
		qty -= from_cards
		EventBus.inventory_changed.emit()
	for uid: String in GameManager.item_instances.keys():
		if qty <= 0:
			break
		if GameManager.item_instances[uid].get("item_id") == item_id:
			GameManager.remove_item_instance(uid)
			qty -= 1


func _on_battle_ended(victory: bool, battle_id: String) -> void:
	if victory and battle_id != "":
		_bump("complete_mission", battle_id)


func _on_inventory_changed() -> void:
	for qid in active_quests():
		_refresh_collect(qid)


func _on_loot_discovered(source_id: String, _item_id: String, _message: String) -> void:
	_bump("find_loot", source_id)


func _on_story_flag_changed(flag: String, value: Variant) -> void:
	if bool(value):
		_bump("flag", flag)


func _on_unit_died(unit: Node) -> void:
	var d: Variant = unit.get("data") if is_instance_valid(unit) else null
	if d is CharacterData:
		_bump("defeat_character", d.id)


# --- Save hooks ------------------------------------------------------------

func get_state_data() -> Dictionary:
	return {"states": _states.duplicate(), "progress": _progress.duplicate(true)}


func load_state_data(d: Dictionary) -> void:
	reset()
	var states: Dictionary = d.get("states", {})
	for id: Variant in states:
		_states[str(id)] = str(states[id])
	var prog: Dictionary = d.get("progress", {})
	for id: Variant in prog:
		var counts: Array = []
		for v: Variant in prog[id]:
			counts.append(int(v))
		_progress[str(id)] = counts
