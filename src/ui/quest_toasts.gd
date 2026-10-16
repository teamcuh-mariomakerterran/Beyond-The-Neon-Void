class_name QuestToasts
extends CanvasLayer
## Quest cards that slide in at the top right on every screen: a job taken,
## a new lead, an objective ticking forward, a job done. UIManager owns one;
## it only listens to EventBus, so it works in the hub, streets and battles.

const LIFE := 3.6
const MAX_SHOWN := 4
## Card kind -> its id in data/toasts.json (sound + animated icon).
const TOAST_IDS := {"active": "quest_new", "available": "quest_lead", "progress": "quest_progress", "complete": "quest_done",
	"level": "level_up", "class": "job_unlocked", "ability": "ability_learned"}
const STYLE := {
	"active": ["NEW JOB", Color("39f5ff")],
	"available": ["NEW LEAD", Color("ffc857")],
	"progress": ["", Color("b98cff")],
	"complete": ["JOB DONE", Color("4dff9e")],
	"level": ["LEVEL UP", Color("ffc857")],
	"class": ["NEW JOB", Color("ff3fb4")],
	"ability": ["NEW ABILITY", Color("39f5ff")],
}

var _stack: VBoxContainer
## Every toast shown (tests / dev console): [{kind, title, text}].
var history: Array[Dictionary] = []


func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_stack = VBoxContainer.new()
	_stack.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_stack.position += Vector2(-24, 120)
	_stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stack.add_theme_constant_override("separation", 8)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)
	EventBus.quest_state_changed.connect(_on_state)
	EventBus.quest_objective_progress.connect(_on_progress)
	# Milestones: these signals had no listener, so nobody ever saw them.
	EventBus.character_leveled.connect(func(cid: String, lv: int) -> void:
		show_toast("level", _who(cid), "Level %d" % lv))
	EventBus.class_unlocked.connect(func(cid: String, class_id: String) -> void:
		var cl := ContentDB.get_class_res(class_id)
		show_toast("class", cl.display_name if cl else class_id, "Unlocked for " + _who(cid)))
	EventBus.ability_unlocked.connect(func(cid: String, aid: String) -> void:
		var ab := ContentDB.get_ability(aid)
		show_toast("ability", ab.display_name if ab else aid, _who(cid) + " learned it"))


func _on_state(quest_id: String, state: String) -> void:
	var q := ContentDB.get_quest(quest_id)
	if q == null:
		return
	if state == "active":
		show_toast("active", q.display_name, str(q.objectives[0].get("text", "")) if not q.objectives.is_empty() else "")
	elif state == "available":
		show_toast("available", q.display_name, "Ask around the Neon Gutter.")
	elif state == "complete":
		show_toast("complete", q.display_name, q.get_reward_text())


func _on_progress(quest_id: String, index: int, count: int) -> void:
	var q := ContentDB.get_quest(quest_id)
	if q == null or index < 0 or index >= q.objectives.size():
		return
	var need := q.objective_count(index)
	if count <= 0 or count > need:
		return
	var what := str(q.objectives[index].get("text", "Objective"))
	show_toast("progress", q.display_name, "%s  %d / %d%s" % [what, count, need, "  ✔" if count == need else ""])


static func _who(cid: String) -> String:
	var c := GameManager.get_character(cid)
	return c.display_name if c else cid


func show_toast(kind: String, title: String, text: String) -> void:
	history.append({"kind": kind, "title": title, "text": text})
	if _stack == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var st: Array = STYLE.get(kind, STYLE["progress"])
	var col: Color = st[1]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", NeonTheme.panel_box(col, Color(0.03, 0.01, 0.07, 0.92)))
	card.custom_minimum_size.x = 340
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var tid: String = TOAST_IDS.get(kind, kind)
	var icon := Toasts.anim_icon(tid, 44.0)
	if icon:
		row.add_child(icon)
	var v := VBoxContainer.new()
	row.add_child(v)
	var head := NeonTheme.label(("%s  ▸  %s" % [st[0], title.to_upper()]) if st[0] != "" else title.to_upper(), 14, col)
	v.add_child(head)
	if text != "":
		var body := NeonTheme.label(text, 13, NeonTheme.TEXT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 320
		v.add_child(body)
	_stack.add_child(card)
	while _stack.get_child_count() > MAX_SHOWN:
		var old := _stack.get_child(0)
		_stack.remove_child(old)  # queue_free alone wouldn't shrink the count
		old.queue_free()
	card.modulate.a = 0.0
	var t := card.create_tween()
	t.tween_property(card, "modulate:a", 1.0, 0.18)
	t.tween_interval(LIFE)
	t.tween_property(card, "modulate:a", 0.0, 0.5)
	t.tween_callback(card.queue_free)
	if not Toasts.play_sfx(tid):
		if kind == "complete":
			Sfx.event("loot", -4.0, 0.9)
		elif kind in ["level", "class", "ability"]:
			Sfx.event("level_up", -6.0)
