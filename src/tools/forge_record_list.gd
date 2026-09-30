class_name ForgeRecordList
extends VBoxContainer
## Array[Dictionary] editor: each record is a compact card with its own form
## (encounter enemies, loot entries, quest objectives, dialog nodes, stock...).

signal records_changed(value: Array)

var _records: Array = []
var _key: String = ""


static func create(value: Array, key: String, cb: Callable) -> ForgeRecordList:
	var r := ForgeRecordList.new()
	r._records = value.duplicate(true)
	r._key = key
	r.records_changed.connect(cb)
	r._rebuild()
	return r


func _emit() -> void:
	records_changed.emit(_records.duplicate(true))


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	add_theme_constant_override("separation", 6)
	for i in _records.size():
		var rec: Dictionary = _records[i] if _records[i] is Dictionary else {}
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", NeonTheme.panel_box(Color(NeonTheme.CYAN, 0.35), Color(0.03, 0.02, 0.06, 0.9)))
		var v := VBoxContainer.new()
		card.add_child(v)
		var head := HBoxContainer.new()
		var title := NeonTheme.label("#%d  %s" % [i + 1, _summary(rec)], 13, NeonTheme.CYAN)
		title.add_theme_font_override("font", NeonTheme.mono())
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		head.add_child(title)
		var idx := i
		for spec in [["↑", -1], ["↓", 1]]:
			var mv := Button.new()
			mv.text = spec[0]
			var d: int = spec[1]
			mv.disabled = (idx + d) < 0 or (idx + d) >= _records.size()
			mv.pressed.connect(func() -> void:
				var tmp: Variant = _records[idx]
				_records[idx] = _records[idx + d]
				_records[idx + d] = tmp
				_emit()
				_rebuild())
			head.add_child(mv)
		var dup := Button.new()
		dup.text = "⧉"
		dup.tooltip_text = "Duplicate"
		dup.pressed.connect(func() -> void: _records.insert(idx + 1, _records[idx].duplicate(true)); _emit(); _rebuild())
		head.add_child(dup)
		var del := Button.new()
		del.text = "✕"
		del.tooltip_text = "Delete"
		del.pressed.connect(func() -> void: _records.remove_at(idx); _emit(); _rebuild())
		head.add_child(del)
		v.add_child(head)
		var form := ForgeForm.new()
		# Fill in any template keys missing from older data.
		var template: Dictionary = ForgeForm.TEMPLATES.get(_key, {})
		for k: String in template:
			if not rec.has(k):
				rec[k] = template[k]
		_records[idx] = rec
		form.build_dict(rec, _key, true)
		form.changed.connect(func(_k: String) -> void:
			_records[idx] = form.get_data()
			title.text = "#%d  %s" % [idx + 1, _summary(form.get_data())]
			_emit())
		v.add_child(form)
		add_child(card)
	var add := Button.new()
	add.text = "+ ADD %s" % _key.trim_suffix("s").replace("_", " ").to_upper()
	add.add_theme_stylebox_override("normal", NeonTheme.button_box(Color(NeonTheme.GREEN, 0.08), Color(NeonTheme.GREEN, 0.5)))
	add.pressed.connect(func() -> void:
		_records.append(ForgeForm.TEMPLATES.get(_key, {"key": ""}).duplicate(true))
		_emit()
		_rebuild())
	add_child(add)


static func _summary(rec: Dictionary) -> String:
	for k in ["character_id", "item_id", "id", "type", "text"]:
		if rec.has(k) and str(rec[k]) != "":
			var s := str(rec[k])
			if rec.has("cell") and rec["cell"] is Array and rec["cell"].size() >= 2:
				s += "  @%d,%d" % [int(rec["cell"][0]), int(rec["cell"][1])]
			return s.left(60)
	return ""
