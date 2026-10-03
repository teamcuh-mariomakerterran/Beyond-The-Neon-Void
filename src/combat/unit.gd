class_name Unit
extends Node2D
## A combatant on the battle grid.
##
## Composition: UnitStats (calculator) + JobHandler (class & commands) +
## EquipmentManager (gear) + UnitHUD (overhead bars) + an AIBehavior resource.
## Grid movement is tween-based on an IsometricGrid, so this is a Node2D rather
## than the original CharacterBody2D (no physics needed for tile tactics).

signal health_changed(current_hp: int, max_hp: int)
signal ap_changed(current_ap: int, max_ap: int)
signal died

enum Team { PLAYER = 0, ENEMY = 1, NEUTRAL = 2 }

const TEAM_COLORS := {0: Color("39ff9f"), 1: Color("ff2e88"), 2: Color("3fd2ff")}

var data: CharacterData
var stats: UnitStats
var behavior: AIBehavior
var team: int = Team.PLAYER
var is_player_controlled: bool = true

var cell: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i(1, 0):
	set(v):
		if v != facing:
			facing = v
			if not _lattice.is_empty() and _action != "death":
				play_animation(_action)
var ct: int = 0
var current_hp: int = 1
var current_mp: int = 0
var current_ap: int = 0
var has_moved: bool = false
var has_acted: bool = false
var statuses: Array = []  # Array of StatusEffect.StatusInstance
## Temporary per-battle stat changes from abilities: {stat: float multiplier}.
var battle_mults: Dictionary = {}
var kills: int = 0
## Tiles moved this turn in one straight line (Kinetic Charge).
var move_streak: int = 0
## Who built / raised this unit (droids, echoes). Null for normal units.
var summoner: Node = null
## Reanimated by a Digimancer: fades over time, can't be revived.
var is_echo: bool = false

var job_handler: JobHandler
var equipment: EquipmentManager
var hud: UnitHUD
var sprite: AnimatedSprite2D
var _lattice: Dictionary = {}  # LatticeClip.unit_set() when the art is a Lattice pack
var _action: String = "idle"
var grid: IsometricGrid


func _init() -> void:
	job_handler = JobHandler.new()
	job_handler.name = "JobHandler"
	equipment = EquipmentManager.new()
	equipment.name = "EquipmentManager"
	add_child(job_handler)
	add_child(equipment)
	equipment.equipment_changed.connect(_on_equipment_changed)


func _ready() -> void:
	hud = UnitHUD.new()
	hud.name = "UnitHUD"
	add_child(hud)
	_try_load_sprite()
	_update_hud()


## Builds the unit from roster data. Call before adding to the tree.
func setup(p_data: CharacterData, p_team: int, level_override: int = 0) -> void:
	data = p_data
	name = p_data.id if p_data.id != "" else "Unit"
	team = p_team
	is_player_controlled = p_team == Team.PLAYER and not p_data.ai_controlled
	stats = p_data.get_stats()
	if level_override > 0:
		stats.level = level_override
	job_handler.learned_ability_ids = p_data.learned_ability_ids.duplicate()
	job_handler.current_job = ClassLibrary.get_class_res(p_data.class_id)
	if p_data.secondary_class_id != "":
		job_handler.secondary_job = ClassLibrary.get_class_res(p_data.secondary_class_id)
	var specs: Array[String] = p_data.weapon_specialties.duplicate()
	if job_handler.current_job:
		for t in job_handler.current_job.specialty_weapon_types:
			if not specs.has(t):
				specs.append(t)
		if job_handler.current_job.uses_deck:
			job_handler.deck = p_data.get_deck()
			job_handler.deck.reset_for_battle()
	equipment.specialties = specs
	for slot: String in p_data.equipment:
		var ref := str(p_data.equipment[slot])
		var inst := GameManager.get_item_instance(ref)
		if inst.is_empty() and ContentDB.get_item(ref):
			# Enemy / guest templates reference item ids directly.
			inst = {"uid": "", "item_id": ref, "level": maxi(level_override, 1), "xp": 0, "potential": 1.0, "bonus": {}}
		if not inst.is_empty():
			equipment.slots[slot] = inst
	behavior = AIBehavior.create(p_data.ai_behavior)
	refresh_stats()
	current_hp = get_stat("max_hp")
	current_mp = get_stat("max_mp")
	current_ap = get_stat("max_ap")


func display_name() -> String:
	return data.display_name if data and data.display_name != "" else String(name)


func class_res() -> ClassResource:
	return job_handler.current_job


# --- Stats -----------------------------------------------------------------

func refresh_stats() -> void:
	if stats == null:
		return
	var mult := battle_mults.duplicate()
	var flat := {}
	for inst in statuses:
		var eff: StatusEffect = inst.effect
		for k: Variant in eff.stat_multipliers:
			mult[k] = float(mult.get(k, 1.0)) * pow(float(eff.stat_multipliers[k]), inst.stacks)
		for k: Variant in eff.stat_flat:
			flat[k] = int(flat.get(k, 0)) + int(eff.stat_flat[k]) * inst.stacks
		if eff.prevents_move:
			flat["move"] = int(flat.get("move", 0)) - 99
	stats.calculate(class_res(), equipment.get_total_bonus(), mult, flat)
	current_hp = mini(current_hp, get_stat("max_hp"))
	current_mp = mini(current_mp, get_stat("max_mp"))
	_update_hud()
	if not statuses.is_empty() or material != null:
		StatusLook.update(self)


func get_stat(stat: String) -> int:
	if stats == null:
		return 0
	if stat == "hp":
		return current_hp
	return stats.get_stat(stat)


func _on_equipment_changed() -> void:
	refresh_stats()


# --- State -----------------------------------------------------------------

func is_alive() -> bool:
	return current_hp > 0


## True if any active status carries `tag` (e.g. "stone", "untouchable").
func has_status_tag(tag: String) -> bool:
	for inst in statuses:
		if tag in inst.effect.tags:
			return true
	return false


func is_disabled() -> bool:
	for inst in statuses:
		if inst.effect.prevents_action:
			return true
	return false


func can_move() -> bool:
	return is_alive() and not has_moved and get_stat("move") > 0


func can_act() -> bool:
	return is_alive() and current_ap > 0 and not is_disabled()


func hp_cost_of(ability: Ability) -> int:
	return roundi(get_stat("max_hp") * ability.hp_cost_pct)


func can_afford(ability: Ability) -> bool:
	return current_ap >= ability.ap_cost and current_mp >= ability.mp_cost and (ability.hp_cost_pct <= 0.0 or current_hp > hp_cost_of(ability))


func spend_for(ability: Ability) -> void:
	current_ap = maxi(current_ap - ability.ap_cost, 0)
	current_mp = maxi(current_mp - ability.mp_cost, 0)
	if ability.hp_cost_pct > 0.0:
		current_hp = maxi(current_hp - hp_cost_of(ability), 1)
	has_acted = true
	_update_hud()


func get_abilities() -> Array[Ability]:
	return job_handler.get_ability_list()


func begin_turn() -> Dictionary:
	has_moved = false
	has_acted = false
	move_streak = 0
	current_ap = get_stat("max_ap")
	var skip := is_disabled()
	var total_dot := 0
	for inst in statuses.duplicate():
		var eff: StatusEffect = inst.effect
		var dot := eff.damage_per_turn + roundi(eff.damage_per_turn_pct * get_stat("max_hp"))
		if dot != 0:
			total_dot += dot
	if total_dot > 0:
		take_damage(total_dot)
	elif total_dot < 0:
		heal(-total_dot)
	_tick_status_durations()
	_update_hud()
	return {"skip": skip or not is_alive(), "dot": total_dot}


# --- Damage / healing -----------------------------------------------------

func take_damage(amount: int, is_critical: bool = false) -> int:
	if not is_alive():
		return 0
	var dealt := clampi(amount, 0, current_hp)
	if dealt >= current_hp and has_status("rewind_anchor"):
		# Chrono-Stitcher save point: snap back instead of dying.
		var anchor := get_status("rewind_anchor")
		statuses.erase(anchor)
		EventBus.unit_status_removed.emit(self, "rewind_anchor")
		_rewind_to(anchor.payload)
		return 0
	current_hp -= dealt
	health_changed.emit(current_hp, get_stat("max_hp"))
	EventBus.unit_damaged.emit(self, dealt, is_critical)
	hit_flash(Color(2.0, 0.4, 0.6), is_critical or dealt >= get_stat("max_hp") * 0.25)
	_update_hud()
	if current_hp <= 0:
		die()
	return dealt


func heal(amount: int) -> int:
	if not is_alive():
		return 0
	var before := current_hp
	current_hp = mini(current_hp + maxi(amount, 0), get_stat("max_hp"))
	var healed := current_hp - before
	health_changed.emit(current_hp, get_stat("max_hp"))
	EventBus.unit_healed.emit(self, healed)
	_update_hud()
	return healed


func element_mult(damage_type: String) -> float:
	var m := 1.0
	var cls := class_res()
	if cls:
		m *= float(cls.element_modifiers.get(damage_type, 1.0))
	if data:
		m *= float(data.element_modifiers.get(damage_type, 1.0))
	return m


## Brings a fallen unit back (Phoenix Stim). Caller re-adds it to the turn queue.
func revive(hp: int) -> void:
	if is_alive() or grid == null or grid.get_occupant(cell) != null:
		return
	current_hp = clampi(hp, 1, get_stat("max_hp"))
	grid.remove_corpse(cell)
	grid.set_occupant(cell, self)
	ct = 0
	modulate.a = 1.0
	_update_hud()
	EventBus.unit_healed.emit(self, current_hp)


func restore_mp(amount: int) -> void:
	current_mp = mini(current_mp + maxi(amount, 0), get_stat("max_mp"))
	_update_hud()


func die() -> void:
	current_hp = 0
	statuses.clear()
	if grid:
		grid.clear_occupant(cell, self)
		if not is_echo and (data == null or not data.ai_controlled or team != Team.PLAYER):
			grid.add_corpse(cell, self)
	died.emit()
	EventBus.unit_died.emit(self)
	if not _lattice.is_empty() and LatticeClip.resolve(_lattice, "death", "SE")[0] != "":
		play_animation("death")  # the clip (and its wreck loop) is the death
		return
	var t := create_tween() if is_inside_tree() else null
	if t:
		t.tween_property(self, "modulate:a", 0.25, 0.4)


# --- Statuses --------------------------------------------------------------

func has_status(status_id: String) -> bool:
	for inst in statuses:
		if inst.effect.id == status_id:
			return true
	return false


func get_status(status_id: String) -> StatusEffect.StatusInstance:
	for inst in statuses:
		if inst.effect.id == status_id:
			return inst
	return null


func apply_status(status_id: String, source: Node = null, payload: Dictionary = {}) -> bool:
	var eff := ContentDB.get_status(status_id)
	if eff == null or not is_alive():
		return false
	var existing := get_status(status_id)
	if existing:
		existing.turns_left = maxi(existing.turns_left, eff.duration_turns)
		existing.stacks = mini(existing.stacks + 1, eff.max_stacks)
		existing.payload.merge(payload, true)
	else:
		var inst := StatusEffect.StatusInstance.new(eff, source)
		inst.payload = payload.duplicate()
		statuses.append(inst)
	refresh_stats()
	EventBus.unit_status_applied.emit(self, status_id)
	return true


func remove_status(status_id: String) -> void:
	var inst := get_status(status_id)
	if inst:
		statuses.erase(inst)
		_on_status_expired(inst)
		refresh_stats()
		EventBus.unit_status_removed.emit(self, status_id)


func cleanse(status_ids: Array[String]) -> void:
	for sid in status_ids:
		if has_status(sid):
			statuses.erase(get_status(sid))
			EventBus.unit_status_removed.emit(self, sid)
	refresh_stats()


func _tick_status_durations() -> void:
	for inst in statuses.duplicate():
		if inst.effect.is_permanent:
			continue
		inst.turns_left -= 1
		if inst.is_expired():
			statuses.erase(inst)
			EventBus.unit_status_removed.emit(self, inst.effect.id)
			_on_status_expired(inst)
	refresh_stats()


func _on_status_expired(inst: StatusEffect.StatusInstance) -> void:
	if inst.payload.has("rewind_cell"):
		_rewind_to(inst.payload)
	var deferred := int(inst.payload.get("deferred_damage", 0))
	if deferred > 0 and is_alive():
		take_damage(deferred)
		if inst.payload.get("knockdown", false) and is_alive():
			apply_status("knockdown", inst.source)


func _rewind_to(payload: Dictionary) -> void:
	current_hp = clampi(int(payload.get("rewind_hp", current_hp)), 1, get_stat("max_hp"))
	var target_cell: Vector2i = payload.get("rewind_cell", cell)
	if grid and (grid.get_occupant(target_cell) == null or grid.get_occupant(target_cell) == self):
		force_move(target_cell)
	EventBus.log_message.emit("%s rewinds." % display_name())
	_update_hud()


# --- Movement & visuals ----------------------------------------------------

func place_at(p_cell: Vector2i) -> void:
	if grid:
		grid.clear_occupant(cell, self)
		cell = p_cell
		grid.set_occupant(cell, self)
		position = grid.grid_to_world(cell)
		z_index = IsometricGrid.draw_order(cell) * 2 + 1


func face_towards(target_cell: Vector2i) -> void:
	if target_cell != cell:
		facing = IsometricGrid.cardinal_direction(cell, target_cell)
		queue_redraw()


## Walks along `path` (first element = current cell). Awaitable.
func move_along(path: Array[Vector2i], animate: bool = true) -> void:
	if path.size() < 2 or grid == null:
		return
	var start := path[0]
	var goal := path[path.size() - 1]
	grid.clear_occupant(start, self)
	if animate and is_inside_tree():
		for i in range(1, path.size()):
			var next := path[i]
			face_towards(next)
			z_index = maxi(IsometricGrid.draw_order(next), IsometricGrid.draw_order(cell)) * 2 + 1
			var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			var hop := grid.get_height(next) != grid.get_height(cell)
			if hop:
				# Jump arc: up and over, then land with a squash.
				var mid := (position + grid.grid_to_world(next)) * 0.5 + Vector2(0, -grid.height_step * 1.1)
				t.tween_property(self, "position", mid, 0.11).set_ease(Tween.EASE_OUT)
				t.tween_property(self, "position", grid.grid_to_world(next), 0.11).set_ease(Tween.EASE_IN)
			else:
				t.tween_property(self, "position", grid.grid_to_world(next), 0.16)
			cell = next
			await t.finished
			if hop:
				land_squash()
	else:
		face_towards(goal)
	cell = goal
	grid.set_occupant(goal, self)
	position = grid.grid_to_world(goal)
	z_index = IsometricGrid.draw_order(goal) * 2 + 1
	has_moved = true
	move_streak = _straight_run(path)
	EventBus.unit_moved.emit(self, start, goal)


static func _straight_run(path: Array[Vector2i]) -> int:
	# Length of the final straight segment of the path.
	if path.size() < 2:
		return 0
	var last_dir := path[path.size() - 1] - path[path.size() - 2]
	var run := 1
	for i in range(path.size() - 2, 0, -1):
		if path[i] - path[i - 1] != last_dir:
			break
		run += 1
	return run


## Instant reposition used by pushes, pulls and warps (no move cost).
func force_move(to_cell: Vector2i, animate: bool = true) -> void:
	if grid == null or not grid.in_bounds(to_cell):
		return
	var from := cell
	grid.clear_occupant(cell, self)
	cell = to_cell
	grid.set_occupant(cell, self)
	z_index = IsometricGrid.draw_order(cell) * 2 + 1
	if animate and is_inside_tree():
		var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "position", grid.grid_to_world(cell), 0.2)
	else:
		position = grid.grid_to_world(cell)
	EventBus.unit_moved.emit(self, from, to_cell)


func play_animation(anim_name: String) -> void:
	if sprite and not _lattice.is_empty():
		if LatticeClip.play_on(sprite, _lattice, anim_name, LatticeClip.facing_of(facing)):
			_action = anim_name
		return
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)


## Lattice one-shots: death chains to its wreck loop (endsOn), anything else
## returns to idle.
func _on_clip_finished() -> void:
	var nxt := str((_lattice.get("next", {}) as Dictionary).get(sprite.animation, ""))
	if nxt != "" and sprite.sprite_frames.has_animation(nxt):
		sprite.play(nxt)
	elif _action != "death":
		play_animation("idle")


func hit_flash(color: Color = Color(2.0, 0.4, 0.6), heavy: bool = false) -> void:
	if not is_inside_tree():
		return
	if not _lattice.is_empty() and _action == "idle":
		play_animation("hit")
	var t := create_tween()
	modulate = color
	t.tween_property(self, "modulate", Color.WHITE, 0.18)
	# Hit reaction: squash at the feet, spring back; heavy hits also wobble.
	var s := create_tween()
	s.tween_property(self, "scale", Vector2(1.18, 0.8) if heavy else Vector2(1.1, 0.88), 0.05)
	s.tween_property(self, "scale", Vector2(0.94, 1.07), 0.08)
	s.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if heavy:
		var r := create_tween()
		r.tween_property(self, "rotation", 0.12, 0.05)
		r.tween_property(self, "rotation", -0.08, 0.07)
		r.tween_property(self, "rotation", 0.0, 0.1)


## Little squash when landing after a hop / jump.
func land_squash() -> void:
	if not is_inside_tree():
		return
	var s := create_tween()
	s.tween_property(self, "scale", Vector2(1.14, 0.86), 0.05)
	s.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _try_load_sprite() -> void:
	if data == null or data.sprite_frames_path == "" or not FileAccess.file_exists(data.sprite_frames_path):
		return
	if data.sprite_frames_path.ends_with(".json") and LatticeClip.is_clip(data.sprite_frames_path):
		_lattice = LatticeClip.unit_set(data.sprite_frames_path)
		if not _lattice.get("ok", false):
			_lattice = {}
			return
		sprite = AnimatedSprite2D.new()
		sprite.use_parent_material = true  # status looks (StatusLook) shade the sprite too
		sprite.sprite_frames = _lattice["frames"]
		# Lattice packs are drawn for 64×32 tiles; scale to this grid.
		var s := (grid.tile_width if grid else 64.0) / 64.0
		sprite.scale = Vector2(s, s)
		sprite.animation_finished.connect(_on_clip_finished)
		add_child(sprite)
		play_animation("idle")
		return
	var frames := ResourceLoader.load(data.sprite_frames_path, "SpriteFrames") as SpriteFrames
	if frames:
		sprite = AnimatedSprite2D.new()
		sprite.use_parent_material = true  # status looks (StatusLook) shade the sprite too
		sprite.sprite_frames = frames
		sprite.offset = Vector2(0, -24)
		add_child(sprite)
		play_animation("idle")


func _update_hud() -> void:
	ap_changed.emit(current_ap, get_stat("max_ap"))
	if hud:
		hud.refresh(self)
	queue_redraw()


## Placeholder silhouette until character sprite sheets are dropped in.
func _draw() -> void:
	if sprite:
		return
	var col: Color = TEAM_COLORS.get(team, Color.WHITE)
	var dim := col.darkened(0.55)
	# Ground ring + facing notch (drawn in iso space).
	var ring := PackedVector2Array()
	for i in 24:
		var ang := TAU * i / 24.0
		ring.append(Vector2(cos(ang) * 18.0, sin(ang) * 9.0))
	draw_colored_polygon(ring, Color(col, 0.18))
	draw_polyline(ring + PackedVector2Array([ring[0]]), Color(col, 0.8), 1.5)
	var f := Vector2((facing.x - facing.y) * 0.5, (facing.x + facing.y) * 0.25).normalized()
	draw_line(f * 10.0, f * 22.0, col, 3.0)
	# Body: a hooded figure silhouette.
	var body := PackedVector2Array([Vector2(-10, 0), Vector2(-12, -22), Vector2(-7, -34), Vector2(7, -34), Vector2(12, -22), Vector2(10, 0)])
	draw_colored_polygon(body, dim)
	draw_polyline(body + PackedVector2Array([body[0]]), col, 1.5)
	draw_circle(Vector2(0, -41), 7.0, dim)
	draw_arc(Vector2(0, -41), 7.0, 0, TAU, 20, col, 1.5)
	draw_line(Vector2(-4, -42), Vector2(4, -42), col.lightened(0.4), 2.0)  # visor
	var font := ThemeDB.fallback_font
	var initials := display_name().substr(0, 2).to_upper()
	draw_string(font, Vector2(-8, -12), initials, HORIZONTAL_ALIGNMENT_CENTER, 16, 11, col.lightened(0.3))
