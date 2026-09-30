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

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
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


static func label(text: String, size: int = 17, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
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
