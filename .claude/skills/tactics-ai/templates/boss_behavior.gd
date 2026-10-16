class_name BossBehavior  # TEMPLATE: proposal, see references/team-and-boss.md. Needs Brian's OK on the phase vocabulary.
extends AIBehavior
## Wraps a preset and swaps it per HP phase. Deterministic: HP thresholds only.
## Data source (proposed): CharacterData.boss_script (add `@export var boss_script: Dictionary`
## first, or GameResource.apply_dict silently drops the key).

var phases: Array = []        # [{at_hp_pct, behavior, prefer: [ability ids], on_enter: [{do,arg}]}], sorted high→low
var _inner: AIBehavior
var _phase := -1


static func from_script(script: Dictionary) -> BossBehavior:
	var b := BossBehavior.new()
	b.phases = (script.get("phases", []) as Array).duplicate(true)
	b.phases.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.get("at_hp_pct", 100)) > float(y.get("at_hp_pct", 100)))
	return b


func plan_turn(unit: Node, battle: Node) -> Dictionary:
	_update_phase(unit)
	if _inner == null:
		_inner = AIBehavior.create("tactical")
	var plan := _inner.plan_turn(unit, battle)
	return plan


func _update_phase(unit: Node) -> void:
	var pct := 100.0 * float(unit.current_hp) / maxf(unit.get_stat("max_hp"), 1.0)
	var want := -1
	for i in phases.size():
		if pct <= float(phases[i].get("at_hp_pct", 100)):
			want = i
	if want == _phase or want < 0:
		return
	_phase = want
	var ph: Dictionary = phases[want]
	_inner = AIBehavior.create(str(ph.get("behavior", "tactical")))
	Cues.fire("boss.phase", {"unit": unit, "name": unit.display_name()})  # register "boss.phase" in data/cues.json
	# on_enter actions: route through Interactions.run_action when CombatManager has an ix (anchor-use-plan Layer 0).
	EventBus.log_message.emit("%s shifts tactics!" % unit.display_name())
