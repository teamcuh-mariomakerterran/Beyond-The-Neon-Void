class_name NeonTheme
extends RefCounted
## The game's UI look, built in code: near-black violet glass, thin neon rims,
## Doctrine magenta for danger, crew green for "yours". One place to retune.
## When the Black Doctrine green-purple HUD art lands in assets/ui/hud, swap the
## StyleBoxFlat panels here for StyleBoxTexture without touching any screen.

const BG := Color("07040d")
const PANEL := Color(0.07, 0.04, 0.12, 0.88)
const PANEL_HI := Color(0.12, 0.07, 0.2, 0.95)
const GREEN := Color("39ff9f")
const MAGENTA := Color("ff2e88")
const VIOLET := Color("b14dff")
const CYAN := Color("3fd2ff")
const AMBER := Color("ffd23f")
const TEXT := Color("e9e1ff")
const TEXT_DIM := Color("8f84ad")

const FONT_BODY := "res://assets/fonts/space-grotesk-latin-500-normal.woff2"
const FONT_BOLD := "res://assets/fonts/space-grotesk-latin-700-normal.woff2"
const FONT_MONO := "res://assets/fonts/jetbrains-mono-latin-400-normal.woff2"

static var _theme: Theme
static var _fonts: Dictionary = {}


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
	var t := Theme.new()
	t.default_font = font(FONT_BODY)
	t.default_font_size = 17
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_disabled_color", "Button", Color(TEXT_DIM, 0.5))
	t.set_stylebox("normal", "Button", button_box(Color(0.1, 0.06, 0.17, 0.95), Color(VIOLET, 0.55)))
	t.set_stylebox("hover", "Button", button_box(Color(0.16, 0.08, 0.27, 1.0), GREEN))
	t.set_stylebox("pressed", "Button", button_box(GREEN, GREEN))
	t.set_stylebox("focus", "Button", button_box(Color(0.16, 0.08, 0.27, 1.0), CYAN))
	t.set_stylebox("disabled", "Button", button_box(Color(0.06, 0.04, 0.09, 0.8), Color(TEXT_DIM, 0.2)))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.6)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GREEN
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "RichTextLabel", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("panel", "TooltipPanel", panel_box(CYAN))
	# Inputs: flat wells with a cyan focus rim — focus is always visible.
	var well := input_box(Color(1, 1, 1, 0.12))
	var well_focus := input_box(CYAN)
	for cls in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", cls, well)
		t.set_stylebox("focus", cls, well_focus)
		t.set_stylebox("read_only", cls, input_box(Color(1, 1, 1, 0.05)))
		t.set_color("font_color", cls, TEXT)
		t.set_color("caret_color", cls, GREEN)
		t.set_color("selection_color", cls, Color(VIOLET, 0.45))
		t.set_color("font_placeholder_color", cls, Color(TEXT_DIM, 0.6))
	t.set_font("font", "LineEdit", mono())
	t.set_font("font", "TextEdit", mono())
	t.set_font_size("font_size", "LineEdit", 14)
	t.set_font_size("font_size", "TextEdit", 14)
	for cls in ["OptionButton", "MenuButton", "CheckButton", "CheckBox"]:
		t.set_stylebox("normal", cls, button_box(Color(0.06, 0.035, 0.1, 1.0), Color(1, 1, 1, 0.12)))
		t.set_stylebox("hover", cls, button_box(Color(0.1, 0.06, 0.17, 1.0), Color(CYAN, 0.7)))
		t.set_stylebox("pressed", cls, button_box(Color(0.1, 0.06, 0.17, 1.0), GREEN))
		t.set_stylebox("focus", cls, button_box(Color(0.1, 0.06, 0.17, 1.0), CYAN))
		t.set_color("font_color", cls, TEXT)
		# Their pressed box is dark (unlike Button's bright one), so keep text light.
		t.set_color("font_pressed_color", cls, TEXT)
		t.set_color("font_hover_pressed_color", cls, Color.WHITE)
		t.set_font_size("font_size", cls, 14)
	var popup := panel_box(CYAN, Color(0.05, 0.03, 0.09, 0.98))
	popup.set_content_margin_all(6)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", button_box(Color(GREEN, 0.2), GREEN))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_stylebox("panel", "ItemList", input_box(Color(1, 1, 1, 0.06)))
	t.set_stylebox("selected", "ItemList", select_box())
	t.set_stylebox("selected_focus", "ItemList", select_box())
	t.set_stylebox("hovered", "ItemList", button_box(Color(1, 1, 1, 0.05), Color.TRANSPARENT))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_color("guide_color", "ItemList", Color(1, 1, 1, 0.04))
	t.set_stylebox("panel", "PanelContainer", panel_box())
	var split := StyleBoxFlat.new()
	split.bg_color = Color(VIOLET, 0.25)
	t.set_constant("separation", "HSplitContainer", 10)
	t.set_constant("separation", "VSplitContainer", 10)
	_theme = t
	return t


static func panel_box(rim: Color = Color(VIOLET, 0.6), fill: Color = PANEL) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = rim
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(rim, 0.18)
	sb.shadow_size = 8
	return sb


static func button_box(fill: Color, rim: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = rim
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func input_box(rim: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.01, 0.04, 0.9)
	sb.border_color = rim
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


## The "scan bar": selected rows get a 3px neon bar on the left edge.
static func select_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GREEN, 0.12)
	sb.border_color = GREEN
	sb.border_width_left = 3
	sb.content_margin_left = 6
	return sb


static func label(text: String, size: int = 17, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if size >= 22:
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
