extends "res://Scripts/Combat/Ability.gd"

class_name TimeAbilities

# --- Delay Thread ---
# Targets an enemy. Damage is deferred and inflicts 100% knockdown on their next turn.
func execute_delay_thread(caster: Unit, target: Unit):
	var delay_effect = {
		"type": "delay_thread",
		"deferred_damage": caster.stats.attack_power * 1.5,
		"knockdown": true
	}
	target.apply_status_effect(delay_effect)
	
	# Visuals
	CombatManager.play_effect("chrono_stitch", target.global_position)
	CombatManager.spawn_damage_text("DEFERRED", target.global_position, Color.GOLD)

# --- Stitch Turn ---
# Links ally and enemy. When enemy turns, ally gains 50 CT.
func execute_stitch_turn(caster: Unit, ally: Unit, enemy: Unit):
	# Create a link between the two units
	# The logic is handled by the TurnManager checking for linked pairs
	TurnManager.link_units(ally, enemy, 50)
	
	# Visuals
	CombatManager.play_effect("thread_link", ally.global_position, enemy.global_position)
	CombatManager.spawn_damage_text("STITCHED", ally.global_position, Color.CYAN)

# --- Rewind Position ---
# Records position at start of round, pulls back at end of round.
func execute_rewind_position(caster: Unit):
	var start_pos = caster.get_meta("round_start_position")
	if start_pos == null:
		return
	
	# Physically teleport the unit back
	var tween = create_tween()
	tween.tween_property(caster, "global_position", start_pos, 0.3).set_trans(Tween.TRANS_CUBIC)
	
	# Visuals
	CombatManager.play_effect("chrono_snap", caster.global_position)
	CombatManager.spawn_damage_text("REWIND", caster.global_position, Color.LIGHT_BLUE)

# Helper to be called by GameManager/TurnManager at the start of a round
func record_start_position(unit: Unit):
	unit.set_meta("round_start_position", unit.global_position)