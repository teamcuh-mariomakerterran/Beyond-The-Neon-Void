class_name AIAnchors
extends RefCounted
## How the AI values map anchors (terminals, switches, devices, medstations):
## the actions an anchor would run, scored with the same weights the AI uses
## for abilities, so "drop the boss's shield" competes fairly with "shoot".
## Pure and deterministic: reads the board, never changes it.
##
## Who uses anchors: the player side's AI (auto-battle, guests) always; the
## enemy side only when CombatManager.enemy_anchor_use is on (ASK BRIAN).
##
## Scored verbs (others, like loot, coins, flags and story, are the player's
## business and score 0):
##   unshield <id>   a shielded foe → 1.5 × kill bonus (it unlocks the win)
##   open <group>    big when the unit can't reach any foe, small otherwise
##   reveal          status value × cloaked / hidden foes
##   heal N | N%     missing HP covered × heal weight (users only)
##   ap +N           status value × N / 2
##   status s@who    buff on allies / debuff on foes, by count
##   spawn x@c@team  ally reinforcements good, enemy ones bad
## Sequences only score the step that's next, and earlier steps borrow part
## of the final step's value so the AI commits to the chain.

const OPEN_STUCK := 45.0
const OPEN_FREE := 3.0


static func allowed(unit: Node, battle: Node) -> bool:
	var ix: Interactions = _ix(battle)
	if ix == null:
		return false
	return int(unit.team) == Unit.Team.PLAYER or bool(battle.get("enemy_anchor_use"))


static func _ix(battle: Node) -> Interactions:
	return battle.get("ix") as Interactions if battle and "ix" in battle else null


## Value of using `a` now for `unit` (≤ 0 = not worth it).
static func score(unit: Node, a: Dictionary, ix: Interactions, battle: Node, ai: AIBehavior, stuck: bool) -> float:
	var seq := str(a.get("sequence", ""))
	if seq != "":
		var want := int(ix.progress.get(seq, 1))
		if int(a.get("step", 0)) != want:
			return -100.0  # out of order resets the chain and runs fail actions
		var total := ix.sequence_length(seq)
		var final_v := 0.0
		for b: Dictionary in ix.world.anchors:
			if str(b.get("sequence", "")) == seq and int(b.get("step", 0)) == total:
				final_v = actions_value(unit, b.get("actions", []), ix, battle, ai, stuck)
		var own := actions_value(unit, a.get("actions", []), ix, battle, ai, stuck)
		return own + final_v * float(want) / float(maxi(total, 1)) * (1.0 if want < total else 0.0)
	return actions_value(unit, a.get("actions", []), ix, battle, ai, stuck)


static func actions_value(unit: Node, actions: Variant, ix: Interactions, battle: Node, ai: AIBehavior, stuck: bool) -> float:
	var v := 0.0
	if not (actions is Array):
		return v
	var foes: Array = battle.get_opponents(unit)
	var friends: Array = battle.get_allies(unit)
	for act: Variant in actions:
		if not (act is Dictionary):
			continue
		var what := str(act.get("do", ""))
		var arg := str(act.get("arg", ""))
		match what:
			"unshield":
				for f: Node in foes:
					if f.has_status("shielded") and (arg == "" or (f.data and f.data.id == arg)):
						v += ai.kill_bonus * 1.5
				for al: Node in friends:
					if al.has_status("shielded") and al.data and al.data.id == arg:
						v -= ai.kill_bonus
			"open":
				if not ix.is_open(arg):
					v += OPEN_STUCK if stuck else OPEN_FREE
			"close":
				if ix.is_open(arg):
					v -= OPEN_FREE
			"reveal":
				for f2: Node in foes:
					if f2.has_status("cloaked") or f2.has_status("hidden"):
						v += ai.status_value
			"heal":
				var mx := float(unit.get_stat("max_hp"))
				var amt := mx * float(arg.trim_suffix("%")) / 100.0 if arg.ends_with("%") else float(arg)
				var missing := mx - float(unit.current_hp)
				# Only worth a stop when properly hurt.
				if missing >= mx * 0.35:
					v += minf(amt, missing) * ai.heal_weight * 0.5
			"ap":
				v += ai.status_value * float(arg.trim_prefix("+")) * 0.5
			"status":
				var bits := arg.split("@")
				var eff := ContentDB.get_status(bits[0])
				if eff:
					var who := bits[1] if bits.size() > 1 else "self"
					var buff := eff.type == StatusEffect.EffectType.BUFF
					var n := 0.0
					match who:
						"self": n = 1.0 if buff else -1.0
						"allies": n = float(friends.size()) * (1.0 if buff else -1.0)
						"enemies": n = float(foes.size()) * (-1.0 if buff else 1.0)
						"boss":
							for f3: Node in foes:
								if f3.data and f3.data.is_boss:
									n += -1.0 if buff else 1.0
						"all": n = 0.0
					v += ai.status_value * n
			"spawn":
				var team_s := arg.split("@")[2] if arg.split("@").size() > 2 else "enemy"
				var ours := (team_s == "player") == (int(unit.team) == Unit.Team.PLAYER)
				v += ai.status_value * (2.0 if ours else -2.0)
			"damage":
				v -= 5.0  # it hurts whoever pulls the lever
	return v


## The best anchor worth walking to when nothing useful is in reach:
## {anchor, value} or {}.
static func goal(unit: Node, ix: Interactions, battle: Node, ai: AIBehavior, stuck: bool) -> Dictionary:
	var best := {}
	var best_v := 10.0
	for a: Dictionary in ix.world.anchors:
		if not ix.is_visible(a) or ix.blocker(a, null) != "" or str(a.get("kind", "")) == "trap":
			continue
		var v := score(unit, a, ix, battle, ai, stuck)
		if v > best_v:
			best_v = v
			best = {"anchor": a, "value": v}
	return best


## True if no foe can be reached from `origin` at any distance (a shut door,
## a shield wall): the walk-flood never touches a cell next to a foe.
static func cut_off(unit: Node, grid: IsometricGrid, foes: Array[Node]) -> bool:
	if foes.is_empty():
		return false
	var flood := grid.flood(unit.cell, 99, unit.get_stat("jump"), unit.team, Passives.phases(unit))
	for f in foes:
		for d in IsometricGrid.DIRECTIONS:
			if flood.has(f.cell + d) or flood.has(f.cell):
				return false
	return true
