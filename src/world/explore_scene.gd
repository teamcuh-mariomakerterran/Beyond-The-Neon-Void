class_name ExploreScene
extends Node2D
## Walkable world / city / hub / interior maps (format 2).
##
## WASD / arrows step between columns (or click a tile to walk there). Walking
## up to a location shows its name above it — or "?" until the first visit.
## Confirm (E / Enter / Space) enters: world-map places play their intro
## cutscene on the first visit, inner places only if one is set. Hidden loot
## and NPC talk work the same way on props. Esc leaves (back to the Forge when
## launched from it).

const STEP_TIME := 0.16
const MAX_CLIMB := 2

var world: WorldMap
var grid: IsometricGrid
var cell: Vector2i
var _renderer: WorldRenderer
var _avatar: Node2D
var _cam: Camera2D
var _labels: Dictionary = {}  # object id -> Label
var _moving: bool = false
var _busy: bool = false
var _path: Array[Vector2i] = []
var _toast: Label
var _hud: CanvasLayer
var _prompt: Label
var _post: HD2DPost
## Region ids the player currently stands in (enter / exit triggers).
var _inside: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## Interaction anchors (terminals, doors, hidden loot, NPC hooks…). State
## carries between visits in GameManager.story_flags["ixstate:<map>"].
var ix: Interactions


func _ready() -> void:
	var info: Dictionary = CampaignManager.current_explore
	var d := ContentDB.get_map(str(info.get("map_id", "")))
	if d.is_empty():
		push_error("ExploreScene: no map to explore")
		return
	world = WorldMap.from_dict(d)
	grid = world.to_grid(world.tiles.size() >= WorldRenderer.STREAM_MIN_CELLS)  # huge maps: cells on demand
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05)
	bg.size = Vector2(60000, 60000)
	bg.position = Vector2(-30000, -30000)
	bg.z_index = -4096
	add_child(bg)
	_renderer = WorldRenderer.new()
	_renderer.world = world
	add_child(_renderer)
	cell = _start_cell(info)
	CampaignManager.current_explore["at"] = cell
	_avatar = _make_avatar()
	add_child(_avatar)
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 7.0
	# Frame ~20 tiles across whatever the map's tile size (zoom < 1 = wider).
	var z := clampf(1920.0 / (world.tile_width * 20.0), 0.3, 2.0)
	_cam.zoom = Vector2(z, z)
	add_child(_cam)
	_cam.make_current()
	_build_hud()
	_post = HD2DPost.for_map(world.post)
	if _post:
		add_child(_post)
	_build_labels()
	ix = Interactions.new().setup(world, grid, self, "explore")
	var saved: Variant = GameManager.story_flags.get(_ix_key())
	if saved is Dictionary:
		ix.set_state(saved)
	if not world.anchors.is_empty():
		var marks := AnchorMarks.new()
		marks.ix = ix
		marks.to_pos = func(c: Vector2i) -> Vector2: return world.to_screen(Vector2(c), grid.get_height(c))
		marks.actor_cell = func() -> Vector2i: return cell
		marks.lift = world.tile_height * 1.4
		marks.size = clampf(world.tile_width / 64.0, 1.0, 3.0)
		marks.z_index = 3000
		add_child(marks)
	_place_avatar()
	_cam.reset_smoothing()
	if world.music != "":
		AudioManager.play_music(world.music)
	_toast_text(world.name.to_upper(), NeonTheme.CYAN)
	_rng.randomize()
	for r: Dictionary in world.regions_at(cell):
		_inside[str(r["id"])] = r


func _start_cell(info: Dictionary) -> Vector2i:
	var at: Vector2i = info.get("at", Vector2i(-1, -1))
	if grid.in_bounds(at) and grid.is_walkable(at):
		return at
	var sp: Array = world.spawns.get("player", [])
	var i := int(info.get("spawn", -1))
	if not sp.is_empty():
		var e: Array = sp[clampi(i, 0, sp.size() - 1)]
		return Vector2i(int(e[0]), int(e[1]))
	# No spawns: the walkable column nearest the middle.
	var mid := Vector2i(world.width / 2, world.depth / 2)
	var best := mid
	var best_d := 1 << 30
	for c in grid.all_cells():
		if grid.is_walkable(c) and IsometricGrid.distance(c, mid) < best_d:
			best_d = IsometricGrid.distance(c, mid)
			best = c
	return best


func _make_avatar() -> Node2D:
	var root := Node2D.new()
	var party := GameManager.get_party_members()
	var frames_path := party[0].sprite_frames_path if not party.is_empty() else ""
	var uset: Dictionary = PixelMatrix.unit_set(frames_path) if PixelMatrix.is_root(frames_path) else (LatticeClip.unit_set(frames_path) if frames_path.ends_with(".json") and LatticeClip.is_clip(frames_path) else {})
	if uset.get("ok", false):
		var ls := AnimatedSprite2D.new()
		ls.sprite_frames = uset["frames"]
		ls.scale = Vector2.ONE * world.tile_width / 64.0
		LatticeClip.play_on(ls, uset, "idle", "SE")
		root.add_child(ls)
	elif frames_path != "" and ResourceLoader.exists(frames_path):
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = load(frames_path)
		spr.offset = Vector2(0, -spr.sprite_frames.get_frame_texture(spr.sprite_frames.get_animation_names()[0], 0).get_height() * 0.5)
		spr.play(spr.sprite_frames.get_animation_names()[0])
		root.add_child(spr)
	else:
		var marker := AvatarMarker.new()
		marker.size = world.tile_height
		root.add_child(marker)
	return root


class AvatarMarker extends Node2D:
	var size: float = 32.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var bob := sin(t * 4.0) * 2.0
		draw_circle(Vector2(0, 0), size * 0.28, Color(0, 0, 0, 0.35))
		var h := size * 1.1
		draw_rect(Rect2(-size * 0.18, -h + bob, size * 0.36, h * 0.8), Color(0.3, 1.9, 1.6))
		draw_circle(Vector2(0, -h + bob), size * 0.2, Color(2.0, 0.5, 1.6))


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10  # above the HD-2D post layer, so text stays crisp
	add_child(_hud)
	_toast = NeonTheme.label("", 28, NeonTheme.CYAN)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 40
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_override("font", NeonTheme.mono())
	_hud.add_child(_toast)
	_prompt = NeonTheme.label("", 18, NeonTheme.GREEN)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position.y -= 60
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_prompt)
	var help := NeonTheme.label("WASD / arrows / click: move   ·   E / Enter: enter · search · talk   ·   Esc: leave", 13, NeonTheme.TEXT_DIM)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.position += Vector2(16, -28)
	_hud.add_child(help)


func _toast_text(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.8)


# --- Locations -----------------------------------------------------------------

static func visited_flag(map_id: String, obj_id: String) -> String:
	return "visited:%s:%s" % [map_id, obj_id]


func is_known(o: Dictionary) -> bool:
	var loc: Dictionary = o["location"]
	return bool(loc.get("discovered", false)) or GameManager.check_story_flag(visited_flag(world.id, str(o["id"])))


func _build_labels() -> void:
	for o: Dictionary in world.locations():
		var l := Label.new()
		l.add_theme_font_override("font", NeonTheme.mono())
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_color", Color(0.4, 2.0, 1.6))
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.05))
		l.add_theme_constant_override("outline_size", 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.z_as_relative = false
		l.z_index = 4050
		l.modulate.a = 0.0
		add_child(l)
		_labels[str(o["id"])] = l


func _update_labels() -> void:
	for o: Dictionary in world.locations():
		var l: Label = _labels.get(str(o["id"]))
		if l == null:
			continue
		var oc := Vector2i(int(o["cell"][0]), int(o["cell"][1]))
		var near := WorldMap.distance_to(o, cell) <= float(o["location"].get("radius", 1.5)) + 0.01
		l.text = str(o["location"].get("name", "?")) if is_known(o) else "?"
		var node := _renderer.object_node(str(o["id"]))
		var top := world.to_screen(Vector2(oc), float(o.get("z", 0))) + Vector2(0, -world.tile_height * 2.2)
		if node and node._rect.size.y > 0:
			top = node.position + Vector2(0, node._rect.position.y - 26)
		l.size = Vector2(400, 30)
		l.position = top - Vector2(200, 0)
		var target := 1.0 if near else 0.0
		l.modulate.a = move_toward(l.modulate.a, target, 0.12)


## Location / prop / NPC within reach of the player, or {}.
func _interactable() -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for o: Dictionary in world.objects:
		var dist := WorldMap.distance_to(o, cell)
		var reach := float(o["location"].get("radius", 1.5)) if o.get("location") is Dictionary else 1.01
		var useful: bool = o.get("location") is Dictionary or str(o.get("loot_item_id", "")) != "" or str(o.get("dialog_npc", "")) != "" or str(o.get("found_text", "")) != ""
		if useful and dist <= reach + 0.01 and dist < best_d:
			best_d = dist
			best = o
	return best


func _ix_key() -> String:
	return "ixstate:" + world.id


func _save_ix() -> void:
	GameManager.story_flags[_ix_key()] = ix.get_state()


## Anchor the player can use from here (standing on it beats next to it).
func _anchor_here() -> Dictionary:
	if ix == null:
		return {}
	var list := ix.usable_from(cell)
	return list[0] if not list.is_empty() else {}


func _interact() -> void:
	var anc := _anchor_here()
	if not anc.is_empty() and (Interactions.cell_of(anc) == cell or _interactable().is_empty()):
		_busy = true
		ix.interact(anc, null)
		_save_ix()
		_busy = false
		return
	var o := _interactable()
	if o.is_empty():
		for r: Dictionary in world.regions_at(cell):
			await fire_triggers(r, "interact")
		return
	if o.get("location") is Dictionary:
		_enter(o)
	elif str(o.get("dialog_npc", "")) != "":
		await ix_npc(str(o["dialog_npc"]))
	else:
		var flag := "looted:%s:%s" % [world.id, str(o["id"])]
		var item := str(o.get("loot_item_id", ""))
		if item != "" and not GameManager.check_story_flag(flag):
			GameManager.give_item(item)
			GameManager.set_story_flag(flag)
			var it := ContentDB.get_item(item)
			_toast_text(str(o.get("found_text", "")) if str(o.get("found_text", "")) != "" else "Found: " + (it.display_name if it else item), NeonTheme.AMBER)
		else:
			_toast_text(str(o.get("empty_text", "Nothing here.")) if str(o.get("empty_text", "")) != "" else "Nothing here.", NeonTheme.TEXT_DIM)


func _enter(o: Dictionary) -> void:
	var loc: Dictionary = o["location"]
	var target := str(loc.get("target_map", ""))
	if target == "" or ContentDB.get_map(target).is_empty():
		_toast_text("%s — not built yet." % loc.get("name", "This place"), NeonTheme.MAGENTA)
		return
	var first := not GameManager.check_story_flag(visited_flag(world.id, str(o["id"])))
	GameManager.set_story_flag(visited_flag(world.id, str(o["id"])))
	var cut := str(loc.get("intro_cutscene", ""))
	_busy = true
	if first and cut != "" and FileAccess.file_exists(cut):
		var player := CutscenePlayer.play(get_tree().root, cut, {"PLACE": str(loc.get("name", "")), "MAP": target})
		if player:
			await player.finished
	elif first and world.kind == "world":
		# No cutscene authored yet: a title card stands in for it.
		_toast_text(str(loc.get("name", "")).to_upper(), NeonTheme.GREEN)
		await get_tree().create_timer(1.2).timeout
	CampaignManager.explore(target, int(loc.get("target_spawn", 0)))


# --- Regions & triggers ---------------------------------------------------------

## Fires enter / exit triggers as the player crosses region borders, then rolls
## that region's random encounter.
func _update_regions() -> void:
	var now_in := {}
	for r: Dictionary in world.regions_at(cell):
		now_in[str(r["id"])] = r
	for id: String in _inside.keys():
		if not now_in.has(id):
			await fire_triggers(_inside[id], "exit")
	for id2: String in now_in:
		if not _inside.has(id2):
			await fire_triggers(now_in[id2], "enter")
	_inside = now_in
	var m := roll_encounter()
	if m != "":
		_toast_text("AMBUSH!", NeonTheme.MAGENTA)
		CampaignManager.start_mission(m)


## Mission id if a random encounter triggers on this step, else "".
func roll_encounter() -> String:
	for r: Dictionary in world.regions_at(cell):
		var enc: Dictionary = r.get("encounter", {})
		var ms: Array = enc.get("missions", [])
		if not ms.is_empty() and _rng.randf() < float(enc.get("rate", 0.0)):
			var mid := str(ms[_rng.randi() % ms.size()])
			if ContentDB.get_mission(mid):
				return mid
	return ""


static func trigger_flag(map_id: String, region: Dictionary, index: int) -> String:
	return "trig:%s:%s:%d" % [map_id, region.get("id", ""), index]


func fire_triggers(region: Dictionary, on: String) -> void:
	var trigs: Array = region.get("triggers", [])
	for i in trigs.size():
		var t: Dictionary = trigs[i]
		if str(t.get("on", "enter")) != on:
			continue
		var req := str(t.get("requires_flag", ""))
		if req != "" and not GameManager.check_story_flag(req):
			continue
		var blk := str(t.get("blocks_flag", ""))
		if blk != "" and GameManager.check_story_flag(blk):
			continue
		var once_flag := trigger_flag(world.id, region, i)
		if bool(t.get("once", false)):
			if GameManager.check_story_flag(once_flag):
				continue
			GameManager.set_story_flag(once_flag)
		await run_trigger(str(t.get("do", "toast")), str(t.get("arg", "")))


# --- Interaction host ------------------------------------------------------------

func ix_toast(text: String, color: Color) -> void:
	_toast_text(text, color)


func ix_group_changed(group: String, open: bool) -> void:
	for o: Dictionary in world.objects:
		if str(o.get("mask_group", "")) == group:
			var node := _renderer.object_node(str(o["id"]))
			if node:
				create_tween().tween_property(node, "modulate:a", 0.0 if open else 1.0, 0.35)
	_save_ix()


func ix_teleport_local(_actor: Node, to: Vector2i) -> void:
	if grid.in_bounds(to) and grid.is_walkable(to):
		cell = to
		CampaignManager.current_explore["at"] = cell
		_place_avatar()
		_cam.reset_smoothing()


func ix_npc(npc_id: String) -> void:
	var npc := ContentDB.get_npc(npc_id)
	if npc:
		_busy = true
		await NpcStages.run(npc, self)
		_busy = false


func run_trigger(action: String, arg: String) -> void:
	match action:
		"toast":
			_toast_text(arg, NeonTheme.CYAN)
		"flag":
			GameManager.set_story_flag(arg)
		"dialog":
			var npc := ContentDB.get_npc(arg)
			if npc:
				UIManager.get_dialogue_box().play_npc(npc)
			else:
				UIManager.get_dialogue_box().say("", arg)
		"cutscene":
			if FileAccess.file_exists(arg):
				_busy = true
				var player := CutscenePlayer.play(get_tree().root, arg, {"PLACE": world.name})
				if player:
					await player.finished
				_busy = false
		"battle":
			if ContentDB.get_mission(arg):
				CampaignManager.start_mission(arg)
		"music":
			AudioManager.play_music(arg)
		"teleport":
			var parts := arg.split(":")
			if parts.size() > 0 and not ContentDB.get_map(parts[0]).is_empty():
				CampaignManager.explore(parts[0], int(parts[1]) if parts.size() > 1 else 0)


# --- Movement ------------------------------------------------------------------

func _place_avatar() -> void:
	_avatar.position = world.to_screen(Vector2(cell), grid.get_height(cell))
	_avatar.z_index = (cell.x + cell.y) * 2 + 1
	_cam.position = _avatar.position


func can_step(from: Vector2i, to: Vector2i) -> bool:
	if not grid.in_bounds(to) or not grid.is_walkable(to):
		return false
	if absi(grid.get_height(to) - grid.get_height(from)) > MAX_CLIMB:
		return false
	for o: Dictionary in world.objects_at(to):
		if str(o.get("kind", "")) in ["structure", "location"]:
			return false
	return true


func _step(dir: Vector2i) -> void:
	var to := cell + dir
	if _moving or _busy or not can_step(cell, to):
		return
	_moving = true
	var from_pos := _avatar.position
	var to_pos := world.to_screen(Vector2(to), grid.get_height(to))
	_avatar.z_index = maxi(cell.x + cell.y, to.x + to.y) * 2 + 1
	if to_pos.x != from_pos.x:
		_avatar.scale.x = -1 if to_pos.x < from_pos.x else 1
	var tw := create_tween()
	var hop := grid.get_height(to) != grid.get_height(cell)
	if hop:
		var mid := (from_pos + to_pos) * 0.5 + Vector2(0, -world.height_step * 0.8)
		tw.tween_property(_avatar, "position", mid, STEP_TIME * 0.5)
		tw.tween_property(_avatar, "position", to_pos, STEP_TIME * 0.5)
	else:
		tw.tween_property(_avatar, "position", to_pos, STEP_TIME)
	cell = to
	CampaignManager.current_explore["at"] = cell
	await tw.finished
	_avatar.z_index = (cell.x + cell.y) * 2 + 1
	_moving = false
	if ix and not ix.on_enter(cell, null).is_empty():
		_save_ix()
	await _update_regions()


func _process(_delta: float) -> void:
	if world == null:
		return
	_cam.position = _avatar.position
	# X-ray: whatever stands between the camera and the player turns see-through.
	_renderer.set_cutaway(_avatar.position + Vector2(0, -world.tile_height * 0.6), cell.x + cell.y, grid.get_height(cell))
	_update_labels()
	if _post:
		# Keep the player in the sharp band of the tilt-shift.
		var sp := get_viewport().get_canvas_transform() * _avatar.position
		_post.set_focus(sp.y / maxf(get_viewport().get_visible_rect().size.y, 1.0) - 0.04)
	var o := _interactable()
	var anc := _anchor_here()
	if not anc.is_empty() and (Interactions.cell_of(anc) == cell or o.is_empty()):
		var info := Interactions.kind_info(str(anc.get("kind", "")))
		_prompt.text = "E  ·  %s %s" % [info["verb"], Interactions.title(anc).to_upper()] if ix.is_visible(anc) else "E  ·  SEARCH"
	elif o.is_empty():
		_prompt.text = ""
	elif o.get("location") is Dictionary:
		_prompt.text = "E  ·  ENTER " + (str(o["location"].get("name", "")).to_upper() if is_known(o) else "???")
	elif str(o.get("dialog_npc", "")) != "":
		_prompt.text = "E  ·  TALK"
	else:
		_prompt.text = "E  ·  SEARCH"
	if _moving or _busy:
		return
	if not _path.is_empty():
		var nxt: Vector2i = _path.pop_front()
		_step(nxt - cell)
		return
	# Screen-aligned keys: up/down walk the screen diagonals of the iso grid.
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): dir = Vector2i(0, -1)
	elif Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): dir = Vector2i(0, 1)
	elif Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): dir = Vector2i(-1, 0)
	elif Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): dir = Vector2i(1, 0)
	if dir != Vector2i.ZERO:
		_step(dir)


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		if k.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_interact()
		elif k.keycode == KEY_ESCAPE:
			_leave()
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var hit := world.pick_top(get_global_mouse_position())
		if not hit.is_empty():
			_path = walk_path(cell, hit[0])


## BFS over steppable columns (climb limit, structures block).
func walk_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for d in IsometricGrid.DIRECTIONS:
			var n: Vector2i = c + d
			if not prev.has(n) and can_step(c, n):
				prev[n] = c
				queue.append(n)
	var out: Array[Vector2i] = []
	if not prev.has(to):
		return out
	var cur := to
	while cur != from:
		out.push_front(cur)
		cur = prev[cur]
	return out


func _leave() -> void:
	if bool(CampaignManager.current_explore.get("from_forge", false)):
		CampaignManager.current_explore = {}
		SceneManager.change_scene(CampaignManager.FORGE_SCENE)
	else:
		SceneManager.change_scene(CampaignManager.HUB_SCENE)
