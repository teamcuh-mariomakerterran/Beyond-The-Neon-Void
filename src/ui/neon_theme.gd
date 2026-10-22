class_name NeonTheme
extends RefCounted
## The game's UI look: near-black violet glass, thin neon rims, Doctrine
## magenta for danger, crew green for "yours". Every value comes from
## data/ui_theme.json (Lattice's interface section edits it; the comments there
## give the format), with the built-in look as the fallback for anything
## missing. A style with a "texture" turns into a 9-slice frame, so Black
## Doctrine HUD art drops in without touching any screen. reload() re-reads it.

const PATH := "res://data/ui_theme.json"

static var _data: Dictionary = _read()
static var BG: Color = color(_value("colors", "bg", "#07040d"))
static var PANEL: Color = color(_value("colors", "panel", [0.07, 0.04, 0.12, 0.88]))
static var PANEL_HI: Color = color(_value("colors", "panel_hi", [0.12, 0.07, 0.2, 0.95]))
static var GREEN: Color = color(_value("colors", "green", "#39ff9f"))
static var MAGENTA: Color = color(_value("colors", "magenta", "#ff2e88"))
static var VIOLET: Color = color(_value("colors", "violet", "#b14dff"))
static var CYAN: Color = color(_value("colors", "cyan", "#3fd2ff"))
static var AMBER: Color = color(_value("colors", "amber", "#ffd23f"))
static var TEXT: Color = color(_value("colors", "text", "#e9e1ff"))
static var TEXT_DIM: Color = color(_value("colors", "text_dim", "#8f84ad"))
static var FONT_BODY: String = str(_value("fonts", "body", "res://assets/fonts/space-grotesk-latin-500-normal.woff2"))
static var FONT_BOLD: String = str(_value("fonts", "bold", "res://assets/fonts/space-grotesk-latin-700-normal.woff2"))
static var FONT_MONO: String = str(_value("fonts", "mono", "res://assets/fonts/jetbrains-mono-latin-400-normal.woff2"))

static var _theme: Theme
static var _fonts: Dictionary = {}


static func _read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return v if v is Dictionary else {}


static func _value(section: String, key: String, fallback: Variant) -> Variant:
	var sec: Variant = _data.get(section)
	return (sec as Dictionary).get(key, fallback) if sec is Dictionary else fallback


## A whole section of data/ui_theme.json ({} if missing), for screens and tools.
static func section(name: String) -> Dictionary:
	var sec: Variant = _data.get(name)
	return sec if sec is Dictionary else {}


## Re-reads data/ui_theme.json (Forge / sandbox / after Lattice writes it).
## Screens built afterwards get the new look; open ones keep theirs.
static func reload() -> void:
	_data = _read()
	BG = color(_value("colors", "bg", "#07040d"))
	PANEL = color(_value("colors", "panel", [0.07, 0.04, 0.12, 0.88]))
	PANEL_HI = color(_value("colors", "panel_hi", [0.12, 0.07, 0.2, 0.95]))
	GREEN = color(_value("colors", "green", "#39ff9f"))
	MAGENTA = color(_value("colors", "magenta", "#ff2e88"))
	VIOLET = color(_value("colors", "violet", "#b14dff"))
	CYAN = color(_value("colors", "cyan", "#3fd2ff"))
	AMBER = color(_value("colors", "amber", "#ffd23f"))
	TEXT = color(_value("colors", "text", "#e9e1ff"))
	TEXT_DIM = color(_value("colors", "text_dim", "#8f84ad"))
	FONT_BODY = str(_value("fonts", "body", FONT_BODY))
	FONT_BOLD = str(_value("fonts", "bold", FONT_BOLD))
	FONT_MONO = str(_value("fonts", "mono", FONT_MONO))
	_theme = null
	_fonts.clear()
	_textures.clear()


## A colour from the theme file: "#rrggbb[aa]", a palette name ("green"),
## a name with alpha ("violet@0.6"), [r, g, b(, a)] (HDR allowed) or a Color.
static func color(v: Variant, fallback: Color = Color.WHITE) -> Color:
	if v is Color:
		return v
	if v is Array:
		var a: Array = v
		if a.size() >= 3:
			return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else 1.0)
		return fallback
	var s := str(v).strip_edges()
	if s == "":
		return fallback
	var alpha := -1.0
	if "@" in s:
		alpha = s.get_slice("@", 1).to_float()
		s = s.get_slice("@", 0)
	var c := fallback
	var named: Variant = section("colors").get(s)
	if named != null and str(named).get_slice("@", 0) != s:
		c = color(named, fallback)
	elif s.begins_with("#") or s.is_valid_html_color():
		c = Color(s)
	else:
		c = Color.from_string(s, fallback)
	if alpha >= 0.0:
		c.a = alpha
	return c


static var _textures: Dictionary = {}


static func _texture(path: String) -> Texture2D:
	if path == "":
		return null
	if not _textures.has(path):
		_textures[path] = DialogueBox.load_texture(path)
	return _textures[path]


## A 9-slice frame when spec has a loadable "texture", else null.
static func _frame(spec: Dictionary, slice: Variant, content: Array) -> StyleBoxTexture:
	var tex := _texture(str(spec.get("texture", "")))
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	var sl: Array = slice if slice is Array and (slice as Array).size() == 4 else [8, 8, 8, 8]
	sb.texture_margin_left = float(sl[0])
	sb.texture_margin_top = float(sl[1])
	sb.texture_margin_right = float(sl[2])
	sb.texture_margin_bottom = float(sl[3])
	sb.content_margin_left = float(content[0])
	sb.content_margin_top = float(content[1])
	sb.content_margin_right = float(content[2])
	sb.content_margin_bottom = float(content[3])
	if spec.has("tint"):
		sb.modulate_color = color(spec["tint"])
	return sb


static func _margins(v: Variant, fallback: Array) -> Array:
	if v is Array and (v as Array).size() == 4:
		return v
	if v is float or v is int:
		return [v, v, v, v]
	return fallback


## Loads a font (imported or raw) with Godot's fallback for symbols ◈ ⌛ ▸ etc.
static func font(path: String) -> Font:
	if _fonts.has(path):
		return _fonts[path]
	var f: FontFile = null
	if ResourceLoader.exists(path):
		f = load(path) as FontFile
	if f == null and FileAccess.file_exists(path):
		f = FontFile.new()
		f.load_dynamic_font(path)
	var result: Font = ThemeDB.fallback_font
	if f:
		f.fallbacks = [ThemeDB.fallback_font]
		result = f
	_fonts[path] = result
	return result


static func mono() -> Font:
	return font(FONT_MONO)


static func bold() -> Font:
	return font(FONT_BOLD)


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var tx := section("text")
	var t := Theme.new()
	t.default_font = font(FONT_BODY)
	t.default_font_size = int(_value("fonts", "size", 17))
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_color("font_color", "Label", color(tx.get("label", "text"), TEXT))
	t.set_color("font_color", "Button", color(tx.get("button", "text"), TEXT))
	t.set_color("font_hover_color", "Button", color(tx.get("button_hover", "#ffffff"), Color.WHITE))
	t.set_color("font_pressed_color", "Button", color(tx.get("button_pressed", "bg"), BG))
	t.set_color("font_disabled_color", "Button", color(tx.get("button_disabled", "text_dim@0.5"), Color(TEXT_DIM, 0.5)))
	var btn := section("button")
	var states := {"normal": [[0.1, 0.06, 0.17, 0.95], "violet@0.55"], "hover": [[0.16, 0.08, 0.27, 1.0], "green"],
		"pressed": ["green", "green"], "focus": [[0.16, 0.08, 0.27, 1.0], "cyan"], "disabled": [[0.06, 0.04, 0.09, 0.8], "text_dim@0.2"]}
	for st: String in states:
		var spec: Dictionary = btn.get(st, {}) if btn.get(st) is Dictionary else {}
		var d: Array = states[st]
		var framed := _frame(spec, btn.get("slice"), _margins(btn.get("margin"), [14, 8, 14, 8]))
		t.set_stylebox(st, "Button", framed if framed else button_box(color(spec.get("fill", d[0])), color(spec.get("rim", d[1]))))
	var m := section("meter")
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = color(m.get("background", [0, 0, 0, 0.6]))
	var bar_bg_tex := _frame({"texture": m.get("texture_under", "")}, m.get("slice"), [0, 0, 0, 0])
	t.set_stylebox("background", "ProgressBar", bar_bg_tex if bar_bg_tex else bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = color(m.get("fill", "green"), GREEN)
	var bar_fill_tex := _frame({"texture": m.get("texture_fill", "")}, m.get("slice"), [0, 0, 0, 0])
	t.set_stylebox("fill", "ProgressBar", bar_fill_tex if bar_fill_tex else bar_fill)
	t.set_color("font_color", "RichTextLabel", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "TooltipPanel", panel_box(color(section("tooltip").get("rim", "cyan"), CYAN)))
	# Inputs: flat wells with a cyan focus rim — focus is always visible.
	var inp := section("input")
	var well := input_box(color(inp.get("rim", [1, 1, 1, 0.12])))
	var well_focus := input_box(color(inp.get("rim_focus", "cyan"), CYAN))
	for cls in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", cls, well)
		t.set_stylebox("focus", cls, well_focus)
		t.set_stylebox("read_only", cls, input_box(color(inp.get("rim_read_only", [1, 1, 1, 0.05]))))
		t.set_color("font_color", cls, TEXT)
		t.set_color("caret_color", cls, color(tx.get("caret", "green"), GREEN))
		t.set_color("selection_color", cls, color(tx.get("selection", "violet@0.45"), Color(VIOLET, 0.45)))
		t.set_color("font_placeholder_color", cls, color(tx.get("placeholder", "text_dim@0.6"), Color(TEXT_DIM, 0.6)))
	t.set_font("font", "LineEdit", mono())
	t.set_font("font", "TextEdit", mono())
	t.set_font_size("font_size", "LineEdit", int(_value("fonts", "input_size", 14)))
	t.set_font_size("font_size", "TextEdit", int(_value("fonts", "input_size", 14)))
	var opt := section("option")
	var odef := {"normal": [[0.06, 0.035, 0.1, 1.0], [1, 1, 1, 0.12]], "hover": [[0.1, 0.06, 0.17, 1.0], "cyan@0.7"],
		"pressed": [[0.1, 0.06, 0.17, 1.0], "green"], "focus": [[0.1, 0.06, 0.17, 1.0], "cyan"]}
	for cls in ["OptionButton", "MenuButton", "CheckButton", "CheckBox"]:
		for st: String in odef:
			var ospec: Dictionary = opt.get(st, {}) if opt.get(st) is Dictionary else {}
			var od: Array = odef[st]
			t.set_stylebox(st, cls, button_box(color(ospec.get("fill", od[0])), color(ospec.get("rim", od[1]))))
		t.set_color("font_color", cls, TEXT)
		# Their pressed box is dark (unlike Button's bright one), so keep text light.
		t.set_color("font_pressed_color", cls, TEXT)
		t.set_color("font_hover_pressed_color", cls, Color.WHITE)
		t.set_font_size("font_size", cls, int(_value("fonts", "option_size", 14)))
	var pp := section("popup")
	var popup := panel_box(color(pp.get("rim", "cyan"), CYAN), color(pp.get("fill", [0.05, 0.03, 0.09, 0.98])))
	popup.set_content_margin_all(float(pp.get("margin", 6)))
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", button_box(color(pp.get("hover_fill", "green@0.2")), color(pp.get("hover_rim", "green"), GREEN)))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	var ls := section("list")
	t.set_stylebox("panel", "ItemList", input_box(color(ls.get("rim", [1, 1, 1, 0.06]))))
	t.set_stylebox("selected", "ItemList", select_box())
	t.set_stylebox("selected_focus", "ItemList", select_box())
	t.set_stylebox("hovered", "ItemList", button_box(color(ls.get("hover_fill", [1, 1, 1, 0.05])), Color.TRANSPARENT))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_color("guide_color", "ItemList", color(ls.get("guide", [1, 1, 1, 0.04])))
	t.set_stylebox("panel", "PanelContainer", panel_box())
	var sep := int(section("split").get("separation", 10))
	t.set_constant("separation", "HSplitContainer", sep)
	t.set_constant("separation", "VSplitContainer", sep)
	_theme = t
	return t


## Panel glass. rim / fill default to the theme file's panel colours.
static func panel_box(rim: Variant = null, fill: Variant = null) -> StyleBox:
	var p := section("panel")
	var rim_c := color(rim if rim != null else p.get("rim", "violet@0.6"), Color(VIOLET, 0.6))
	var fill_c := color(fill if fill != null else p.get("fill", "panel"), PANEL)
	var margin := float(p.get("margin", 12))
	var framed := _frame(p, p.get("slice"), [margin, margin, margin, margin])
	if framed:
		return framed
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_c
	sb.border_color = rim_c
	sb.set_border_width_all(int(p.get("border", 1)))
	sb.border_width_left = int(p.get("border_left", 3))
	sb.set_corner_radius_all(int(p.get("radius", 2)))
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(rim_c, float(p.get("shadow_alpha", 0.18)))
	sb.shadow_size = int(p.get("shadow_size", 8))
	return sb


static func button_box(fill: Color, rim: Color) -> StyleBoxFlat:
	var b := section("button")
	var mg := _margins(b.get("margin"), [14, 8, 14, 8])
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = rim
	sb.set_border_width_all(int(b.get("border", 1)))
	sb.border_width_bottom = int(b.get("border_bottom", 2))
	sb.set_corner_radius_all(int(b.get("radius", 2)))
	sb.content_margin_left = float(mg[0])
	sb.content_margin_top = float(mg[1])
	sb.content_margin_right = float(mg[2])
	sb.content_margin_bottom = float(mg[3])
	return sb


static func input_box(rim: Color) -> StyleBox:
	var inp := section("input")
	var mg := _margins(inp.get("margin"), [8, 5, 8, 5])
	var framed := _frame(inp, inp.get("slice"), mg)
	if framed:
		return framed
	var sb := StyleBoxFlat.new()
	sb.bg_color = color(inp.get("fill", [0.02, 0.01, 0.04, 0.9]))
	sb.border_color = rim
	sb.set_border_width_all(int(inp.get("border", 1)))
	sb.set_corner_radius_all(int(inp.get("radius", 2)))
	sb.content_margin_left = float(mg[0])
	sb.content_margin_top = float(mg[1])
	sb.content_margin_right = float(mg[2])
	sb.content_margin_bottom = float(mg[3])
	return sb


## The "scan bar": selected rows get a 3px neon bar on the left edge.
static func select_box() -> StyleBoxFlat:
	var se := section("select")
	var sb := StyleBoxFlat.new()
	sb.bg_color = color(se.get("fill", "green@0.12"), Color(GREEN, 0.12))
	sb.border_color = color(se.get("bar", "green"), GREEN)
	sb.border_width_left = int(se.get("bar_width", 3))
	sb.content_margin_left = float(se.get("margin_left", 6))
	return sb


static func label(text: String, size: int = 17, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if size >= int(_value("fonts", "bold_from_size", 22)):
		l.add_theme_font_override("font", bold())
	l.add_theme_color_override("font_color", color)
	return l


static func bar(color: Color, height: float = 10.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
	return b


static func team_color(team: int) -> Color:
	return Unit.TEAM_COLORS.get(team, TEXT)


## The neon bloom: HDR 2D glow, so anything brighter than 1.0 blooms. One
## setup shared by battles and exploration so the same lights look the same.
static func glow_environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	var g := section("glow")
	env.glow_intensity = float(g.get("intensity", 0.9))
	env.glow_bloom = float(g.get("bloom", 0.05))
	env.glow_hdr_threshold = float(g.get("hdr_threshold", 1.0))
	var levels: Dictionary = g.get("levels", {"1": 1.0, "3": 0.6}) if g.get("levels") is Dictionary else {"1": 1.0, "3": 0.6}
	for k: Variant in levels:
		env.set_glow_level(int(k), float(levels[k]))
	var we := WorldEnvironment.new()
	we.environment = env
	return we


## Custom mouse cursors from the theme file (none set = the system cursor, as today).
static func apply_cursors() -> void:
	var cur := section("cursors")
	var hs: Array = cur.get("hotspot", [0, 0]) if cur.get("hotspot") is Array else [0, 0]
	for spec: Array in [["arrow", Input.CURSOR_ARROW], ["pointing_hand", Input.CURSOR_POINTING_HAND], ["ibeam", Input.CURSOR_IBEAM], ["busy", Input.CURSOR_BUSY]]:
		var tex := _texture(str(cur.get(spec[0], "")))
		if tex:
			Input.set_custom_mouse_cursor(tex, spec[1], Vector2(float(hs[0]), float(hs[1])))


## The sfx family for a UI moment ("hover", "confirm", "no_save"…), or "".
static func ui_sound(moment: String) -> String:
	return str(section("sounds").get(moment, ""))
