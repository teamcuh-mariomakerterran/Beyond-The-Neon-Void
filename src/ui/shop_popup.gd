class_name ShopPopup
extends CanvasLayer
## A vendor's stock as a pop-up, for NPC shops met out in the world (the hub
## has its own SHOPS screen). Awaitable: `await ShopPopup.open(host, vendor_id)`.

signal closed

var vendor_id: String = ""
var _list: VBoxContainer
var _coins: Label


static func open(host: Node, p_vendor_id: String) -> void:
	var p := ShopPopup.new()
	p.vendor_id = p_vendor_id
	(host if host else Engine.get_main_loop().root).add_child(p)
	await p.closed


func _ready() -> void:
	layer = 60
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", NeonTheme.panel_box(NeonTheme.AMBER))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var vend := VendorSystem.get_vendor(vendor_id)
	v.add_child(NeonTheme.label(str(vend.get("name", vendor_id)).to_upper(), 22, NeonTheme.AMBER))
	if str(vend.get("greeting", "")) != "":
		var g := NeonTheme.label(str(vend["greeting"]), 14, NeonTheme.TEXT_DIM)
		g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(g)
	_coins = NeonTheme.label("", 14, NeonTheme.CYAN)
	v.add_child(_coins)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var close := Button.new()
	close.text = "LEAVE  [Esc]"
	close.pressed.connect(_close)
	v.add_child(close)
	_refresh()


func _refresh() -> void:
	_coins.text = "Soul coins: %d" % GameManager.soul_coins
	for c in _list.get_children():
		c.queue_free()
	for s: Dictionary in VendorSystem.available_stock(vendor_id):
		var id := str(s["id"])
		var it := ContentDB.get_item(id)
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = UIIcons.item(it) if it else null
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var name := NeonTheme.label((it.display_name if it else id) + (("  (%d left)" % int(s["qty_left"])) if int(s["qty_left"]) > 0 else ""), 15)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var buy := Button.new()
		buy.text = "%d ◈" % int(s["price"])
		buy.disabled = GameManager.soul_coins < int(s["price"])
		buy.pressed.connect(func() -> void:
			var why := VendorSystem.buy_item(vendor_id, id)
			if why != "":
				_coins.text = why
			else:
				_refresh())
		row.add_child(buy)
		_list.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
