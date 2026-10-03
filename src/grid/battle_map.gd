class_name BattleMap
extends Node2D
## The battle scene controller.
##
## Builds the IsometricGrid from a map file, renders it (TileView per cell),
## spawns the party + mission enemies, owns the camera and HUD, translates
## mouse input into CombatManager commands (the old InputBridge/InputManager),
## and plays lightweight ability FX. All rules live in CombatManager.

enum Mode { NONE, MOVE, TARGET }

const FALLBACK_MISSION := "m01_the_brew_plan"

@export var mission_id: String = ""

var grid := IsometricGrid.new()
var highlights := HighlightManager.new()
## Format-2 maps only: the stacked-tile renderer (x-ray cutaway lives here).
var world_renderer: WorldRenderer
var tiles: Dictionary = {}  # Vector2i -> TileView
var world: Node2D
var units_root: Node2D
var camera: CameraController
var hud: BattleHUD
var mission: MissionResource
var map_data: Dictionary

var mode: Mode = Mode.NONE
var selected_ability: Ability
var hovered_cell: Vector2i = Vector2i(-1, -1)
var _valid_cells: Array[Vector2i] = []
var _busy: bool = false
var _show_threat: bool = false


func _ready() -> void:
	mission = ContentDB.get_mission(mission_id if mission_id != "" else CampaignManager.current_mission_id)
	if mission == null:
		mission = ContentDB.get_mission(FALLBACK_MISSION)
	map_data = ContentDB.get_map(mission.map_id)
	_setup_environment()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	_build_grid()
	units_root = Node2D.new()
	units_root.name = "Units"
	world.add_child(units_root)
	camera = CameraController.new()
	add_child(camera)
	camera.make_current()
	var center := grid.grid_to_world(Vector2i(grid.width / 2, grid.depth / 2), false)
	camera.global_position = center
	camera.bounds = Rect2(center - Vector2(900, 700), Vector2(1800, 1400))
	hud = BattleHUD.new()
	add_child(hud)
	hud.move_pressed.connect(_enter_move_mode)
	hud.ability_pressed.connect(_enter_target_mode)
	hud.end_turn_pressed.connect(_end_turn)
	hud.continue_pressed.connect(_on_continue)
	_connect_events()
	var units := _spawn_units()
	AudioManager.play_music(mission.music_id)
	hud.show_banner(mission.display_name.to_upper(), NeonTheme.CYAN, 1.2)
	hud.add_log("[color=#8f84ad]%s[/color]" % mission.briefing)
	CombatManager.animate = true
	CombatManager.autobattle = false
	await get_tree().create_timer(0.4).timeout
	await play_cutscene(mission.intro_cutscene, {"PLACE": str(map_data.get("name", mission.display_name)).to_upper(), "MISSION": mission.display_name})
	CombatManager.start_battle(grid, units, mission, self)


func _exit_tree() -> void:
	if CombatManager.map_node == self:
		CombatManager.stop_battle()


# --- Construction ----------------------------------------------------------

func _setup_environment() -> void:
	# HDR 2D glow makes anything brighter than 1.0 bloom — the neon look.
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 0.6)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var bg := CanvasLayer.new()
	bg.layer = -10
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.material = _backdrop_material()
	bg.add_child(rect)
	add_child(bg)


func _backdrop_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
// Black-violet sky with drifting data-ring bands and faint scanlines.
void fragment() {
	vec2 uv = UV;
	vec3 top = vec3(0.02, 0.0, 0.05);
	vec3 low = vec3(0.09, 0.02, 0.14);
	vec3 col = mix(top, low, smoothstep(0.0, 1.0, uv.y));
	float ring = smoothstep(0.012, 0.0, abs(uv.y - 0.28 - 0.04 * sin(uv.x * 3.0 + TIME * 0.05)));
	col += vec3(0.25, 0.1, 0.45) * ring * 0.6;
	float ring2 = smoothstep(0.006, 0.0, abs(uv.y - 0.36 - 0.03 * sin(uv.x * 5.0 - TIME * 0.04)));
	col += vec3(0.1, 0.4, 0.5) * ring2 * 0.35;
	col *= 0.92 + 0.08 * sin(uv.y * 900.0);
	COLOR = vec4(col, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _build_grid() -> void:
	var stacked := int(map_data.get("format", 1)) >= 2
	if map_data.is_empty():
		grid.setup(10, 10)
	elif stacked:
		# Format 2 (World Painter): the renderer draws the stacked tiles, details,
		# objects and particles; the battle grid is the top of every column.
		var wm := WorldMap.from_dict(map_data)
		grid.load_dict(wm.to_grid().to_dict(), ContentDB.terrain)
		var renderer := WorldRenderer.new()
		renderer.world = wm
		world.add_child(renderer)
		world_renderer = renderer
		var post := HD2DPost.for_map(wm.post)
		if post:
			add_child(post)
		for o: Dictionary in wm.objects:
			if str(o.get("loot_item_id", "")) != "" or str(o.get("found_text", "")) != "":
				_spawn_prop({"id": o["id"], "cell": o["cell"], "loot_item_id": o.get("loot_item_id", ""),
					"found_text": o.get("found_text", ""), "empty_text": o.get("empty_text", ""), "asset": ""})
	else:
		grid.load_dict(map_data, ContentDB.terrain)
	for c in grid.all_cells():
		var tv := TileView.new()
		tv.overlay_only = stacked
		tv.setup(grid, c)
		world.add_child(tv)
		tiles[c] = tv
	highlights.tiles = tiles
	for prop: Dictionary in map_data.get("props", []):
		_spawn_prop(prop)


func _spawn_prop(prop: Dictionary) -> void:
	var cell := Vector2i(int(prop["cell"][0]), int(prop["cell"][1]))
	var trig := InteractionTrigger.new()
	trig.trigger_id = str(prop.get("id", ""))
	trig.loot_item_id = str(prop.get("loot_item_id", ""))
	trig.found_text = str(prop.get("found_text", ""))
	trig.empty_text = str(prop.get("empty_text", ""))
	trig.cell = cell
	trig.position = grid.grid_to_world(cell)
	trig.z_index = IsometricGrid.draw_order(cell) * 2 + 1
	world.add_child(trig)
	var tex := ForgeStore.load_texture(str(prop.get("asset", "")))
	if tex:
		# Props stand on their tile, bottom-centre anchored, sorted like units.
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + grid.tile_height * 0.25)
		trig.add_child(spr)


func _spawn_units() -> Array[Node]:
	var out: Array[Node] = []
	var spawns: Array = map_data.get("spawns", {}).get("player", [])
	var i := 0
	for c in GameManager.get_party_members().slice(0, mission.max_party_size):
		if i >= spawns.size():
			break
		out.append(_make_unit(c, Unit.Team.PLAYER, Vector2i(spawns[i][0], spawns[i][1]), 0))
		i += 1
	for e: Dictionary in mission.enemies:
		var data := ContentDB.get_character(str(e["character_id"]))
		if data:
			out.append(_make_unit(data, Unit.Team.ENEMY, Vector2i(e["cell"][0], e["cell"][1]), int(e.get("level", 1))))
	for g: Dictionary in mission.guests:
		var gdata := ContentDB.get_character(str(g["character_id"]))
		if gdata:
			var gu := _make_unit(gdata, Unit.Team.PLAYER, Vector2i(g["cell"][0], g["cell"][1]), int(g.get("level", 1)))
			gu.is_player_controlled = false
			out.append(gu)
	return out


func _make_unit(data: CharacterData, team: int, cell: Vector2i, level: int) -> Unit:
	var u := Unit.new()
	u.setup(data, team, level)
	u.grid = grid
	u.facing = Vector2i(-1, 0) if team == Unit.Team.ENEMY else Vector2i(1, 0)
	add_unit_node(u)
	u.place_at(cell)
	return u


## Called by CombatManager.spawn_unit for summons / echoes.
func add_unit_node(u: Node) -> void:
	units_root.add_child(u)


# --- Events ----------------------------------------------------------------

func _connect_events() -> void:
	_ensure_vfx_hooks()  # crit / death / landing effects from the first turn on
	CombatManager.player_input_needed.connect(_on_player_input_needed)
	CombatManager.battle_finished.connect(_on_battle_finished)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_order_changed.connect(func(_f: Array) -> void: hud.update_turn_order(CombatManager.turn_forecast(10)))
	EventBus.unit_damaged.connect(func(u: Node, amt: int, crit: bool) -> void: _float(u, str(amt), Color(2.0, 0.5, 0.7), crit, float(amt) / maxf(float(u.get_stat("max_hp")), 1.0) * 2.5))
	EventBus.unit_healed.connect(func(u: Node, amt: int) -> void: _float(u, "+%d" % amt, Color(0.5, 2.0, 1.0)) if amt > 0 else null)
	EventBus.unit_missed.connect(func(u: Node) -> void: _float(u, "MISS", Color(0.7, 0.7, 0.9)))
	EventBus.unit_status_applied.connect(func(u: Node, sid: String) -> void: _float(u, ContentDB.get_status(sid).display_name.to_upper() if ContentDB.get_status(sid) else sid, Color(1.8, 1.4, 0.4)))
	EventBus.grid_changed.connect(_on_grid_changed)
	EventBus.unit_died.connect(func(_u: Node) -> void: _refresh_tile_corpses())
	EventBus.unit_moved.connect(func(u: Node, _a: Vector2i, _b: Vector2i) -> void: if u == CombatManager.active_unit: hud.refresh_unit(u))


func _float(u: Node, text: String, color: Color, crit: bool = false, weight: float = 0.3) -> void:
	if is_instance_valid(u):
		DamageText.spawn(world, u.position, text, color, crit, weight)
		if u == CombatManager.active_unit:
			hud.refresh_unit(u)


func _on_grid_changed(cells: Array) -> void:
	for c: Vector2i in cells:
		if tiles.has(c):
			tiles[c].refresh()
	# Occupants of reshaped tiles must re-seat to the new height.
	for u in CombatManager.get_units():
		u.position = grid.grid_to_world(u.cell)


func _refresh_tile_corpses() -> void:
	for c in grid.corpse_cells():
		if tiles.has(c):
			tiles[c].queue_redraw()


func _on_turn_started(unit: Node) -> void:
	camera.follow_target = unit
	hud.update_turn_order(CombatManager.turn_forecast(10))
	var mine: bool = unit.is_player_controlled
	hud.show_unit(unit, false)
	if not mine:
		highlights.clear_highlights()
		hud.set_mode_hint("%s is thinking..." % unit.display_name())


func _on_player_input_needed(unit: Node) -> void:
	hud.show_banner("%s'S TURN" % unit.display_name().split(" ")[0].to_upper(), NeonTheme.GREEN, 0.5)
	_refresh_commands()
	if unit.can_move():
		_enter_move_mode()
	else:
		_set_mode(Mode.NONE)


func _refresh_commands() -> void:
	var u := CombatManager.active_unit
	hud.show_unit(u, CombatManager.is_player_turn())
	hud.update_turn_order(CombatManager.turn_forecast(10))


# --- Modes -----------------------------------------------------------------

func _set_mode(m: Mode) -> void:
	mode = m
	highlights.clear_highlights()
	_valid_cells.clear()
	if _show_threat:
		_draw_threat()
	match m:
		Mode.NONE:
			hud.set_mode_hint("Choose a command.  Click scenery next to you to search it.  [Tab] threat map")
		Mode.MOVE:
			hud.set_mode_hint("MOVE — click a green tile.  [Right-click] cancel")
		Mode.TARGET:
			hud.set_mode_hint("%s — click a target.  [Right-click] cancel" % selected_ability.display_name.to_upper())


func _enter_move_mode() -> void:
	var u := CombatManager.active_unit
	if u == null or not u.can_move() or not CombatManager.is_player_turn():
		return
	_set_mode(Mode.MOVE)
	_valid_cells = CombatManager.move_cells_for(u)
	highlights.highlight_range(_valid_cells, true)


func _enter_target_mode(ability: Ability) -> void:
	var u := CombatManager.active_unit
	if u == null or not CombatManager.is_player_turn():
		return
	selected_ability = ability
	_set_mode(Mode.TARGET)
	_valid_cells = CombatManager.target_cells_for(u, ability)
	highlights.highlight_range(_valid_cells, false)
	if ability.target == Ability.Target.SELF or (ability.range_max == 0 and ability.range_min == 0):
		_update_hover(u.cell)


func _end_turn() -> void:
	var u := CombatManager.active_unit
	if u == null or _busy:
		return
	# Auto-face the nearest enemy so you don't eat back-stabs (FFT facing, simplified).
	var foes := CombatManager.get_opponents(u)
	var face := Vector2i.ZERO
	var best := 9999
	for f in foes:
		var d := IsometricGrid.distance(u.cell, f.cell)
		if d < best:
			best = d
			face = IsometricGrid.cardinal_direction(u.cell, f.cell)
	highlights.clear_highlights()
	hud.show_unit(u, false)
	hud.show_inspect("")
	CombatManager.end_active_turn(face)


func _draw_threat() -> void:
	var u := CombatManager.active_unit
	if u == null:
		return
	var ai := AIBehavior.new()
	var threat := ai.build_threat_map(grid, CombatManager.get_opponents(u))
	highlights.highlight_danger_zone(threat.keys())


# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(grid.pick_cell(world.get_local_mouse_position()))
	elif event.is_action_pressed("mouse_left"):
		_on_click(grid.pick_cell(world.get_local_mouse_position()))
	elif event.is_action_pressed("mouse_right") or event.is_action_pressed("cancel"):
		if mode == Mode.TARGET or mode == Mode.MOVE:
			_set_mode(Mode.NONE)
			hud.show_inspect("")
	elif event.is_action_pressed("end_turn") and CombatManager.is_player_turn():
		_end_turn()
	elif event.is_action_pressed("move_mode"):
		_enter_move_mode()
	elif event.is_action_pressed("toggle_threat"):
		_show_threat = not _show_threat
		if _show_threat:
			_draw_threat()
		else:
			highlights.clear_layer("threat")


func _update_hover(cell: Vector2i) -> void:
	if cell == hovered_cell:
		return
	if world_renderer and grid.in_bounds(cell):
		# X-ray: what stands in front of the hovered tile fades out.
		world_renderer.set_cutaway(grid.grid_to_world(cell), cell.x + cell.y, grid.get_height(cell))
	if tiles.has(hovered_cell):
		tiles[hovered_cell].hovered = false
		tiles[hovered_cell].queue_redraw()
	hovered_cell = cell
	if not tiles.has(cell):
		hud.show_inspect("")
		highlights.clear_layer("aoe")
		highlights.clear_layer("path")
		return
	tiles[cell].hovered = true
	tiles[cell].queue_redraw()
	EventBus.cell_hovered.emit(cell)
	var u := CombatManager.active_unit
	if mode == Mode.TARGET and u and _valid_cells.has(cell):
		highlights.highlight_target(selected_ability.get_affected_cells(grid, u.cell, cell))
	else:
		highlights.clear_layer("aoe")
	if mode == Mode.MOVE and u and _valid_cells.has(cell):
		highlights.set_layer("path", grid.find_path(u.cell, cell, u.get_stat("move"), u.get_stat("jump"), u.team, Passives.phases(u)), HighlightManager.PATH)
	else:
		highlights.clear_layer("path")
	hud.show_inspect(_inspect_text(cell))


func _inspect_text(cell: Vector2i) -> String:
	var c := grid.get_cell(cell)
	var def: Dictionary = ContentDB.terrain.get(c.terrain, {})
	var lines := ["[color=#3fd2ff][b]%s[/b][/color]  (%d,%d)" % [str(def.get("name", c.terrain)).to_upper(), cell.x, cell.y]]
	lines.append("[color=#8f84ad]Height %d   Move cost %d%s%s[/color]" % [c.height, c.move_cost, "   COVER " + ["", "HALF", "FULL"][c.cover] if c.cover > 0 else "", "" if c.walkable else "   BLOCKED"])
	if c.hazard != "":
		lines.append("[color=#ff2e88]HAZARD: %s (%d)[/color]" % [c.hazard.replace("_", " ").to_upper(), c.hazard_turns])
	var occ := grid.get_occupant(cell)
	if occ:
		var col := NeonTheme.team_color(occ.team).to_html(false)
		lines.append("[color=#%s][b]%s[/b][/color]  LV%d %s" % [col, occ.display_name(), occ.get_stat("level"), occ.class_res().display_name if occ.class_res() else ""])
		lines.append("HP %d/%d   MP %d/%d   SPD %d   CT %d" % [occ.current_hp, occ.get_stat("max_hp"), occ.current_mp, occ.get_stat("max_mp"), occ.get_stat("speed"), occ.ct])
		var u := CombatManager.active_unit
		if mode == Mode.TARGET and u and selected_ability and _valid_cells.has(cell) and occ != u:
			var f := DamageCalculator.forecast(u, occ, selected_ability, grid)
			if f["damage"] > 0:
				lines.append("[color=#ffd23f]▶ HIT %d%%   DMG %d   CRIT %d%%%s[/color]" % [roundi(f["hit"] * 100), f["damage"], roundi(f["crit"] * 100), "   KILL" if f["kill"] else ""])
			elif f["damage"] < 0:
				lines.append("[color=#39ff9f]▶ HEAL %d[/color]" % -f["damage"])
			var angle := DamageCalculator.attack_angle(u.cell, occ.cell, occ.facing)
			if angle != "front":
				lines.append("[color=#39ff9f]%s ATTACK[/color]" % angle.to_upper())
	elif grid.get_corpse(cell):
		lines.append("[color=#b14dff]Fallen: %s[/color]" % grid.get_corpse(cell).display_name())
	return "\n".join(lines)


func _on_click(cell: Vector2i) -> void:
	if _busy or not CombatManager.is_player_turn() or not tiles.has(cell):
		return
	var u := CombatManager.active_unit
	match mode:
		Mode.MOVE:
			if _valid_cells.has(cell) and cell != u.cell:
				_busy = true
				highlights.clear_highlights()
				await CombatManager.request_move(u, cell)
				_busy = false
				_after_action()
		Mode.TARGET:
			if _valid_cells.has(cell):
				_busy = true
				highlights.clear_highlights()
				await CombatManager.request_ability(u, selected_ability, cell)
				_busy = false
				_after_action()
		Mode.NONE:
			var occ := grid.get_occupant(cell)
			if occ == u and u.can_move():
				_enter_move_mode()
			else:
				_try_search(u, cell)


## Hidden loot: click a prop next to the active unit to search it (free action).
func _try_search(u: Node, cell: Vector2i) -> void:
	for t in world.get_children():
		if t is InteractionTrigger and t.cell == cell:
			if IsometricGrid.distance(u.cell, cell) > 1:
				hud.show_notification("Get closer to search that.")
				return
			hud.show_notification(t.interact())
			return


func _after_action() -> void:
	if CombatManager.state == CombatManager.State.ENDED:
		return
	var u := CombatManager.active_unit
	if u == null or not u.is_alive():
		return
	_refresh_commands()
	if not u.can_act() and not u.can_move():
		_end_turn()
	elif u.can_move() and not u.can_act():
		_enter_move_mode()
	else:
		_set_mode(Mode.NONE)


# --- FX --------------------------------------------------------------------

## Plays a PARALLAX cutscene if `path` is set; awaitable. Missing files are skipped.
func play_cutscene(path: String, vars: Dictionary = {}, slots: Dictionary = {}) -> void:
	if path == "" or not FileAccess.file_exists(path):
		return
	hud.visible = false
	var cs := CutscenePlayer.play(self, path, vars, slots)
	await cs.finished
	hud.visible = true


## Awaited by CombatManager before an ability resolves. Picks a layered VFX
## (src/vfx/vfx.gd, data/vfx.json) from the ability's vfx_id / id / special /
## kind / damage_type: cast flourish → projectile travel → impact (or a
## caster→target arc, chain or drain stream), then the hit resolves.
func play_ability_fx(unit: Node, ability: Ability, cell: Vector2i) -> void:
	if not is_instance_valid(unit):
		return
	_ensure_vfx_hooks()
	if ability.cutscene != "":
		var target: Node = grid.get_occupant(cell)
		var dmg := ""
		if target and target != unit and ability.kind in [Ability.Kind.ATTACK, Ability.Kind.MAGIC]:
			dmg = str(DamageCalculator.forecast(unit, target, ability, grid)["damage"])
		await play_cutscene(ability.cutscene, {"ATTACKER": unit.display_name(), "TARGET": target.display_name() if target else "", "ABILITY": ability.display_name, "DAMAGE": dmg}, {"ATTACKER": unit.display_name()})
		if not is_instance_valid(unit):
			return
	var from: Vector2 = grid.grid_to_world(unit.cell)
	var to := grid.grid_to_world(cell)
	var color := _fx_color(ability)
	var self_cast: bool = ability.target == Ability.Target.SELF or cell == unit.cell
	var ranged: bool = IsometricGrid.distance(unit.cell, cell) > 1 and not self_cast
	var plan := VFX.plan_for_ability(ability, ranged)
	var cells := ability.get_affected_cells(grid, unit.cell, cell)
	unit.play_animation("attack")
	if plan["cast"] != "" and not self_cast:
		VFX.spawn(world, plan["cast"], from, _vfx_params(unit.cell))
	if plan["travel"] != "" and ranged and plan["mode"] == "point":
		VFX.spawn(world, plan["travel"], from, {"to": to})
		await get_tree().create_timer(maxf(VFX.impact_time(plan["travel"]), 0.05)).timeout
	elif not ranged and not self_cast and ability.is_offensive():
		var lunge := create_tween()
		var dir: Vector2 = (to - from).normalized() * 10.0
		lunge.tween_property(unit, "position", unit.position + dir, 0.07)
		lunge.tween_property(unit, "position", grid.grid_to_world(unit.cell), 0.1)
		await lunge.finished
	_spawn_impact_vfx(unit, plan, cell, cells)
	for c in cells:
		if tiles.has(c):
			var tv: TileView = tiles[c]
			var flash := create_tween()
			tv.modulate = Color(color.r, color.g, color.b, 1.0)
			flash.tween_property(tv, "modulate", Color.WHITE, 0.3)
	# Let the impact peak before damage numbers pop.
	await get_tree().create_timer(0.12).timeout


## Spawns the plan's impact effect in the shape its mode asks for.
func _spawn_impact_vfx(unit: Node, plan: Dictionary, cell: Vector2i, cells: Array[Vector2i]) -> void:
	var impact: String = plan["impact"]
	var from: Vector2 = grid.grid_to_world(unit.cell)
	var to := grid.grid_to_world(cell)
	match str(plan["mode"]):
		"arc", "stream":
			if cell == unit.cell:
				VFX.spawn(world, impact, to, _vfx_params(cell))
			else:
				var p := _vfx_params(cell)
				p["to"] = to
				VFX.spawn(world, impact, from, p)
		"chain":
			var hit: Array[Node] = []
			for c in cells:
				var occ := grid.get_occupant(c)
				if occ and occ != unit:
					hit.append(occ)
			hit.sort_custom(func(a: Node, b: Node) -> bool: return IsometricGrid.distance(unit.cell, a.cell) < IsometricGrid.distance(unit.cell, b.cell))
			var targets: Array = []
			for occ in hit.slice(0, 6):
				targets.append(grid.grid_to_world(occ.cell))
			if targets.is_empty():
				targets.append(to)
			var p := _vfx_params(cell)
			p["targets"] = targets
			VFX.spawn(world, impact, from, p)
		_:
			var spots: Array[Vector2i] = []
			if bool(plan["multi"]):
				for c in cells:
					if grid.get_occupant(c) != null and spots.size() < 6:
						spots.append(c)
			if spots.is_empty():
				spots.append(cell)
			for c in spots:
				VFX.spawn(world, impact, grid.grid_to_world(c), _vfx_params(c))


func _vfx_params(cell: Vector2i) -> Dictionary:
	# Decals sit on the floor of their cell, under the units standing there.
	return {"floor_z": IsometricGrid.draw_order(cell) * 2}


var _vfx_hooked := false


## Crits, deaths and landings get their own juice (connected on first use so
## the battle setup above stays untouched).
func _ensure_vfx_hooks() -> void:
	if _vfx_hooked:
		return
	_vfx_hooked = true
	EventBus.unit_damaged.connect(_on_vfx_unit_damaged)
	EventBus.unit_died.connect(_on_vfx_unit_died)
	EventBus.unit_moved.connect(_on_vfx_unit_moved)


func _on_vfx_unit_damaged(u: Node, _amount: int, crit: bool) -> void:
	if crit and is_instance_valid(u) and u.is_inside_tree():
		VFX.spawn(world, "crit_hit", u.position, _vfx_params(u.cell))


func _on_vfx_unit_died(u: Node) -> void:
	if is_instance_valid(u) and u.is_inside_tree():
		var c := NeonTheme.team_color(u.team)
		VFX.spawn(world, "death_dissolve", u.position, {"color": Color(c.r * 1.6, c.g * 1.6, c.b * 1.6), "floor_z": IsometricGrid.draw_order(u.cell) * 2})


func _on_vfx_unit_moved(u: Node, _from: Vector2i, to_cell: Vector2i) -> void:
	if not is_instance_valid(u) or not u.is_inside_tree() or not grid.in_bounds(to_cell):
		return
	var water := str(grid.get_cell(to_cell).terrain).contains("water")
	VFX.spawn(world, "water_splash" if water else "landing_dust", grid.grid_to_world(to_cell), _vfx_params(to_cell))


static func _fx_color(ability: Ability) -> Color:
	match ability.damage_type:
		"plasma": return Color(2.2, 0.6, 1.2)
		"cryo": return Color(0.6, 1.6, 2.4)
		"electric": return Color(1.6, 1.6, 2.6)
		"void", "essence": return Color(1.4, 0.5, 2.4)
		"tech": return Color(0.5, 2.2, 1.4)
		"kinetic": return Color(1.0, 1.1, 2.4)
	if ability.is_healing():
		return Color(0.6, 2.4, 1.2)
	match ability.kind:
		Ability.Kind.BUFF: return Color(2.2, 1.8, 0.6)
		Ability.Kind.DEBUFF: return Color(1.5, 0.6, 2.2)
	return Color(2.0, 2.0, 2.0)


# --- End -------------------------------------------------------------------

func _on_battle_finished(victory: bool) -> void:
	highlights.clear_highlights()
	hud.set_mode_hint("")
	hud.show_banner("VICTORY" if victory else "DEFEAT", NeonTheme.GREEN if victory else NeonTheme.MAGENTA, 1.4)
	var report := CombatManager.conclude_battle()
	await get_tree().create_timer(1.8).timeout
	if victory:
		await play_cutscene(mission.outro_cutscene, {"MISSION": mission.display_name})
	hud.show_results(victory, report)


func _on_continue() -> void:
	CombatManager.stop_battle()
	CampaignManager.return_to_hub()
