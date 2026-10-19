class_name UiTheme
extends RefCounted
## One look for every screen: the Underground palette (cyan / magenta on near-black), the two
## fonts, and small helpers that build the panels, bars and buttons the menus are made of.

const CYAN := Color(0.16, 0.90, 1.00)
const MAGENTA := Color(1.00, 0.18, 0.78)
const AMBER := Color(1.00, 0.68, 0.10)
const LIME := Color(0.65, 1.00, 0.10)
const WHITE := Color(0.92, 0.95, 1.00)
const DIM := Color(0.56, 0.62, 0.72)
const INK := Color(0.030, 0.033, 0.045)
const INK_SOFT := Color(0.060, 0.065, 0.085)
const DANGER := Color(1.00, 0.25, 0.22)

const FONT_DISPLAY := "res://assets/fonts/orbitron-latin-900-normal.woff2"
const FONT_BOLD := "res://assets/fonts/orbitron-latin-700-normal.woff2"
const FONT_BODY := "res://assets/fonts/rajdhani-latin-500-normal.woff2"
const FONT_BODY_BOLD := "res://assets/fonts/rajdhani-latin-700-normal.woff2"

static var _fonts: Dictionary = {}


static func font(path: String) -> Font:
	if not _fonts.has(path):
		var f: Variant = load(path)
		_fonts[path] = f if f is Font else null
	return _fonts[path]


static func label(text: String, size: int, col: Color = WHITE, display: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	var f := font(FONT_DISPLAY if display else FONT_BODY_BOLD)
	if f:
		l.add_theme_font_override("font", f)
	l.add_theme_constant_override("outline_size", 0)
	return l


## A dark glass panel with a neon edge on one side.
static func panel(accent: Color = CYAN, fill: Color = INK) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(fill.r, fill.g, fill.b, 0.86)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	sb.set_border_width_all(0)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	sb.shadow_size = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


static func button(text: String, accent: Color = CYAN) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	var f := font(FONT_BOLD)
	if f:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 20)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var lit := state == "hover" or state == "focus" or state == "pressed"
		sb.bg_color = Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25, 0.9 if lit else 0.5)
		sb.border_color = Color(accent.r, accent.g, accent.b, 1.0 if lit else 0.5)
		sb.set_border_width_all(2 if lit else 1)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", accent.lightened(0.4))
	b.add_theme_color_override("font_focus_color", accent.lightened(0.4))
	b.add_theme_color_override("font_pressed_color", WHITE)
	return b


## A labelled 0..1 bar, Underground style: a dark track with a glowing fill and tick marks.
static func stat_bar(accent: Color = CYAN) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(220, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.11, 0.14, 0.9)
	bg.set_corner_radius_all(2)
	pb.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = accent
	fg.set_corner_radius_all(2)
	pb.add_theme_stylebox_override("fill", fg)
	return pb


static func set_bar_color(pb: ProgressBar, accent: Color) -> void:
	var fg := StyleBoxFlat.new()
	fg.bg_color = accent
	fg.set_corner_radius_all(2)
	pb.add_theme_stylebox_override("fill", fg)


## Full-screen dark gradient backdrop for the menus.
static func backdrop() -> ColorRect:
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.color = Color(0.018, 0.020, 0.030, 1.0)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cr
