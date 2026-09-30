class_name ForgeChipList
extends HFlowContainer
## Array[String] editor as removable chips + an "add" picker (id reference or free text).

signal list_changed(values: Array)

var _values: Array = []
var _ref: String = ""


static func create(values: Array, ref: String, cb: Callable) -> ForgeChipList:
	var c := ForgeChipList.new()
	c._values = values.duplicate()
	c._ref = ref
	c.list_changed.connect(cb)
	c._rebuild()
	return c


func _rebuild() -> void:
	for ch in get_children():
		ch.queue_free()
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	for i in _values.size():
		var chip := Button.new()
		var v := str(_values[i])
		var label := ForgeForm.ref_label(_ref, v) if _ref != "" else ""
		chip.text = "%s  ✕" % (label.split("  ·  ")[0] if label != "" else v)
		chip.tooltip_text = v + "\n(click to remove)"
		chip.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.VIOLET, 0.16), Color(NeonTheme.VIOLET, 0.6)))
		chip.add_theme_stylebox_override("hover", NeonTheme.button_box(Color(NeonTheme.MAGENTA, 0.25), NeonTheme.MAGENTA))
		chip.add_theme_font_size_override("font_size", 13)
		var idx := i
		chip.pressed.connect(func() -> void:
			_values.remove_at(idx)
			list_changed.emit(_values.duplicate())
			_rebuild())
		add_child(chip)
	if _ref != "":
		var opts: Array = [""] + ForgeForm.ref_options(_ref).filter(func(o: Variant) -> bool: return not _values.has(o))
		var ob := ForgeForm._option(opts, "", func(v: String) -> void:
			if v != "":
				_values.append(v)
				list_changed.emit(_values.duplicate())
				_rebuild.call_deferred())
		ob.set_item_text(0, "+ add")
		for i in range(1, opts.size()):
			var l := ForgeForm.ref_label(_ref, str(opts[i]))
			if l != "":
				ob.set_item_text(i, l)
		add_child(ob)
	var le := LineEdit.new()
	le.placeholder_text = "+ type & enter" if _ref == "" else "+ custom id"
	le.custom_minimum_size.x = 140
	le.text_submitted.connect(func(t: String) -> void:
		if t.strip_edges() != "":
			_values.append(t.strip_edges())
			list_changed.emit(_values.duplicate())
			_rebuild.call_deferred())
	add_child(le)
