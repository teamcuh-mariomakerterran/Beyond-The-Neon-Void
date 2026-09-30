class_name ForgeKVEditor
extends VBoxContainer
## Dictionary editor: rows of key -> value. Keys can come from a reference
## (stats, classes, items...) and values are numbers or ids.

signal dict_changed(value: Dictionary)

var _dict: Dictionary = {}
var _key_ref: String = ""
var _val_ref: String = ""


static func create(value: Dictionary, key_ref: String, val_ref: String, cb: Callable) -> ForgeKVEditor:
	var e := ForgeKVEditor.new()
	e._dict = value.duplicate(true)
	e._key_ref = key_ref
	e._val_ref = val_ref
	e.dict_changed.connect(cb)
	e._rebuild()
	return e


func _emit() -> void:
	dict_changed.emit(_dict.duplicate(true))


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	add_theme_constant_override("separation", 4)
	for k: Variant in _dict.keys():
		var row := HBoxContainer.new()
		var kl := NeonTheme.label(str(k), 14, NeonTheme.CYAN)
		kl.add_theme_font_override("font", NeonTheme.mono())
		kl.custom_minimum_size.x = 170
		kl.tooltip_text = ForgeForm.ref_label(_key_ref, str(k)) if _key_ref != "" else ""
		row.add_child(kl)
		var v: Variant = _dict[k]
		var key: Variant = k
		if v is float or v is int:
			# Counts (class levels, item quantities) are ints; multipliers are floats.
			var as_int: bool = _key_ref in ["classes", "items", "items_and_cards", "stat_block"] or v is int or (is_equal_approx(float(v), roundf(float(v))) and _key_ref not in ["primary_stats", "elements"])
			var sb := ForgeForm._spin(float(v), as_int, func(n: float) -> void:
				_dict[key] = int(n) if as_int else n
				_emit())
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(sb)
		elif _val_ref != "":
			var ob := ForgeForm._ref_picker(_val_ref, str(v), func(s: String) -> void: _dict[key] = s; _emit())
			ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(ob)
		else:
			var le := LineEdit.new()
			le.text = str(v) if not (v is Array or v is Dictionary) else JSON.stringify(v)
			le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			le.text_changed.connect(func(s: String) -> void:
				var parsed: Variant = JSON.parse_string(s) if s.begins_with("[") or s.begins_with("{") else null
				_dict[key] = parsed if parsed != null else s
				_emit())
			row.add_child(le)
		var del := Button.new()
		del.text = "✕"
		del.tooltip_text = "Remove"
		del.pressed.connect(func() -> void: _dict.erase(key); _emit(); _rebuild())
		row.add_child(del)
		add_child(row)
	var add := HBoxContainer.new()
	if _key_ref != "":
		var opts: Array = [""] + ForgeForm.ref_options(_key_ref).filter(func(o: Variant) -> bool: return not _dict.has(o))
		var ob := ForgeForm._option(opts, "", func(s: String) -> void:
			if s != "":
				_dict[s] = "" if _val_ref != "" else (1.0 if _key_ref in ["primary_stats", "elements"] else 1)
				_emit()
				_rebuild.call_deferred())
		ob.set_item_text(0, "+ add key")
		add.add_child(ob)
	else:
		var le := LineEdit.new()
		le.placeholder_text = "+ new key & enter"
		le.text_submitted.connect(func(s: String) -> void:
			if s.strip_edges() != "":
				_dict[s.strip_edges()] = 0
				_emit()
				_rebuild.call_deferred())
		add.add_child(le)
	add_child(add)
