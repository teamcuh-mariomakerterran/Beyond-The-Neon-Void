class_name UnitHUD
extends Node2D
## Compact overhead readout for a Unit: HP / MP bars, status pips, turn marker.
## The detailed stat panel lives in BattleHUD; this stays tiny and always on top.

const WIDTH := 40.0
const Y := -62.0

var _hp_ratio: float = 1.0
var _hp_shown: float = 1.0
var _mp_ratio: float = 1.0
var _team_color: Color = Color.WHITE
var _status_colors: Array[Color] = []
var _alive: bool = true
var is_active_turn: bool = false:
	set(v):
		is_active_turn = v
		queue_redraw()


func _ready() -> void:
	z_as_relative = false
	z_index = 4000


func refresh(unit: Unit) -> void:
	var max_hp := maxi(unit.get_stat("max_hp"), 1)
	var max_mp := maxi(unit.get_stat("max_mp"), 1)
	_hp_ratio = clampf(float(unit.current_hp) / max_hp, 0.0, 1.0)
	_mp_ratio = clampf(float(unit.current_mp) / max_mp, 0.0, 1.0)
	_team_color = Unit.TEAM_COLORS.get(unit.team, Color.WHITE)
	_alive = unit.is_alive()
	_status_colors.clear()
	for inst in unit.statuses:
		var eff: StatusEffect = inst.effect
		_status_colors.append(Color("39ff9f") if eff.type == StatusEffect.EffectType.BUFF else Color("ff5c5c") if eff.type == StatusEffect.EffectType.DEBUFF else Color("c9b3ff"))
	if is_inside_tree():
		var t := create_tween()
		t.tween_property(self, "_hp_shown", _hp_ratio, 0.35).set_trans(Tween.TRANS_CUBIC)
		t.tween_callback(queue_redraw)
	else:
		_hp_shown = _hp_ratio
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_equal_approx(_hp_shown, _hp_ratio):
		queue_redraw()


func _draw() -> void:
	if not _alive:
		return
	var x := -WIDTH * 0.5
	draw_rect(Rect2(x - 1, Y - 1, WIDTH + 2, 9), Color(0, 0, 0, 0.75))
	var hp_col := Color("39ff9f") if _hp_ratio > 0.6 else Color("ffd23f") if _hp_ratio > 0.3 else Color("ff3b5c")
	draw_rect(Rect2(x, Y, WIDTH * _hp_shown, 4), Color(1, 1, 1, 0.55))
	draw_rect(Rect2(x, Y, WIDTH * _hp_ratio, 4), hp_col)
	draw_rect(Rect2(x, Y + 5, WIDTH * _mp_ratio, 2), Color("8a5cff"))
	for i in _status_colors.size():
		draw_circle(Vector2(x + 3 + i * 7, Y - 5), 2.5, _status_colors[i])
	if is_active_turn:
		var tri := PackedVector2Array([Vector2(-6, Y - 16), Vector2(6, Y - 16), Vector2(0, Y - 8)])
		draw_colored_polygon(tri, _team_color)
