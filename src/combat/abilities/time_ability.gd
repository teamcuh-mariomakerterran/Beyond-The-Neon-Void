class_name TimeAbility
extends Ability
## Chrono-Stitcher kit: manipulates the CT clock.
##
##  time.delay_thread   Damage is deferred; it lands (with knockdown) when the
##                      target's next turn begins.
##  time.stitch_turn    Links the target enemy to the caster's closest ally: every
##                      time the enemy takes a turn, that ally gains CT.
##  time.rewind         Save point: anchors caster's cell + HP; when the anchor
##                      expires (or would-be lethal damage lands) they snap back.
##  time.ct_shift       Pushes the target's CT by params.ct (negative = delay).


func _resolve_special(ctx: Context) -> void:
	match special:
		"time.delay_thread":
			_delay_thread(ctx)
		"time.stitch_turn":
			_stitch_turn(ctx)
		"time.rewind":
			_rewind(ctx)
		"time.ct_shift":
			_ct_shift(ctx)


func _delay_thread(ctx: Context) -> void:
	var target: Node = ctx.grid.get_occupant(ctx.target_cell)
	if target == null or target.team == ctx.caster.team:
		return
	var dmg := roundi(ctx.caster.get_stat("magic") * float(params.get("mult", 1.5)))
	target.apply_status("delay_thread", ctx.caster, {"deferred_damage": dmg, "knockdown": true})
	ctx.log_result(target, "deferred", dmg)


func _stitch_turn(ctx: Context) -> void:
	var enemy: Node = ctx.grid.get_occupant(ctx.target_cell)
	if enemy == null or enemy.team == ctx.caster.team:
		return
	var ally: Node = ctx.caster
	var best := 9999
	for u: Node in ctx.battle.get_allies(ctx.caster):
		if u != ctx.caster and u.is_alive():
			var d := IsometricGrid.distance(u.cell, ctx.caster.cell)
			if d < best:
				best = d
				ally = u
	enemy.apply_status("stitched", ctx.caster, {"linked_ally": ally, "ct_gain": int(params.get("ct_gain", 50))})
	ctx.log_result(enemy, "stitched")


func _rewind(ctx: Context) -> void:
	var c := ctx.caster
	c.apply_status("rewind_anchor", c, {"rewind_cell": c.cell, "rewind_hp": c.current_hp})
	ctx.log_result(c, "anchored")


func _ct_shift(ctx: Context) -> void:
	var target: Node = ctx.grid.get_occupant(ctx.target_cell)
	if target == null:
		return
	target.ct = clampi(target.ct + int(params.get("ct", -50)), -200, TurnQueue.CT_READY + 99)
	ctx.log_result(target, "ct_shift", int(params.get("ct", -50)))
	EventBus.turn_order_changed.emit([])
