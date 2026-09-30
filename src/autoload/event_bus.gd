extends Node
## EventBus — global signal hub.
##
## Systems emit here instead of holding hard references to each other, so the
## battle, hub, HUD and (later) the Neon Forge editor stay decoupled.

# --- Battle flow ---
signal battle_started(battle_id: String)
signal battle_ended(victory: bool, battle_id: String)
signal round_advanced(tick: int)
signal turn_started(unit: Node)
signal turn_ended(unit: Node)
signal turn_order_changed(forecast: Array)

# --- Unit events ---
signal unit_moved(unit: Node, from_cell: Vector2i, to_cell: Vector2i)
signal unit_damaged(unit: Node, amount: int, is_critical: bool)
signal unit_healed(unit: Node, amount: int)
signal unit_missed(unit: Node)
signal unit_died(unit: Node)
signal unit_status_applied(unit: Node, status_id: String)
signal unit_status_removed(unit: Node, status_id: String)

# --- Abilities ---
signal ability_used(caster: Node, ability: Resource, cell: Vector2i)
signal ability_charging(caster: Node, ability: Resource, cell: Vector2i, ticks: int)
signal card_spent(unit: Node, card: Resource)

# --- Grid ---
signal grid_changed(cells: Array)
signal cell_hovered(cell: Vector2i)

# --- Economy / progression ---
signal soul_coins_changed(total: int)
signal inventory_changed
signal item_crafted(instance: Dictionary)
signal ability_unlocked(character_id: String, ability_id: String)
signal class_unlocked(character_id: String, class_id: String)
signal character_leveled(character_id: String, new_level: int)

# --- World / narrative ---
signal story_flag_changed(flag: String, value: Variant)
signal loot_discovered(source_id: String, item_id: String, message: String)
signal dialog_requested(speaker: String, text: String)
signal broadcast_line(channel: String, text: String)  # news ticker / eavesdrop chatter

# --- Quests ---
## state: "locked" | "available" | "active" | "complete"
signal quest_state_changed(quest_id: String, state: String)
signal quest_objective_progress(quest_id: String, index: int, count: int)

# --- Dispatch ---
signal dispatch_started(assignment: Dictionary)
signal dispatch_resolved(assignment: Dictionary, success: bool, rewards: Dictionary)

# --- Cutscenes ---
## Fired by CutscenePlayer for each shot event (e.g. "impact") so gameplay can react.
signal cutscene_event(event_name: String, data: Variant)

# --- Misc ---
signal play_sfx(sfx_id: String)
signal camera_shake(intensity: float, duration: float)
signal log_message(text: String)
