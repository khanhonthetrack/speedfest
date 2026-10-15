class_name UITheme
extends RefCounted
## Shared look for every UI screen (menus, garage, lobby, HUD, pause, results).
## Core-owned: UI agents use it and request changes instead of editing it.
## NFSU2-inspired: deep navy panels, neon edges, skewed buttons, Orbitron for
## numbers/headings, Rajdhani for labels. See docs/DESIGN.md §7.

const CYAN := Color("#00e5ff")
const MAGENTA := Color("#ff2bd6")
const AMBER := Color("#ffb300")
const LIME := Color("#a6ff00")
const NAVY := Color("#070b1a")
const PANEL := Color(0.035, 0.055, 0.13, 0.86)
const PANEL_LIGHT := Color(0.07, 0.1, 0.22, 0.92)
const TEXT := Color("#e8f4ff")
const TEXT_DIM := Color(0.62, 0.7, 0.84)
const GOOD := Color("#2b8cff")   # split faster than PB (blue)
const BAD := Color("#ff3b3b")    # split slower than PB (red)

const SKEW := 0.18                # horizontal skew of buttons/panels

const FONT_HEAD_PATH := "res://assets/fonts/orbitron-latin-700-normal.woff2"
const FONT_HEAVY_PATH := "res://assets/fonts/orbitron-latin-900-normal.woff2"
const FONT_NUM_PATH := "res://assets/fonts/orbitron-latin-500-normal.woff2"
const FONT_BODY_PATH := "res://assets/fonts/rajdhani-latin-500-normal.woff2"
const FONT_BODY_BOLD_PATH := "res://assets/fonts/rajdhani-latin-700-normal.woff2"

static var _theme: Theme = null
static var _fonts: Dictionary = {}


## Fonts: "head" (Orbitron 700), "heavy" (Orbitron 900), "num" (Orbitron 500),
## "body" (Rajdhani 500), "body_bold" (Rajdhani 700).
static func font(kind: String = "body") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = {
		"head": FONT_HEAD_PATH, "heavy": FONT_HEAVY_PATH, "num": FONT_NUM_PATH,
		"body": FONT_BODY_PATH, "body_bold": FONT_BODY_BOLD_PATH,
	}.get(kind, FONT_BODY_PATH)
	var f: Font = load(path) as Font
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[kind] = f
	return f


## The shared Theme. Assign it to the root Control of a screen: `theme = UITheme.get_theme()`.
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 22

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 2)

	# Buttons (also used by OptionButton, MenuButton, CheckBox/CheckButton text)
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, panel_style(PANEL, CYAN.darkened(0.35), 2, SKEW))
		t.set_stylebox("hover", type, panel_style(PANEL_LIGHT, CYAN, 2, SKEW))
		t.set_stylebox("pressed", type, panel_style(Color(MAGENTA, 0.35), MAGENTA, 2, SKEW))
		t.set_stylebox("disabled", type, panel_style(Color(PANEL, 0.5), Color(TEXT_DIM, 0.3), 2, SKEW))
		t.set_stylebox("focus", type, focus_style())
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, CYAN)
		t.set_color("font_pressed_color", type, TEXT)
		t.set_color("font_focus_color", type, CYAN)
		t.set_color("font_disabled_color", type, TEXT_DIM)
		t.set_font("font", type, font("body_bold"))
		t.set_font_size("font_size", type, 24)

	for type in ["Panel", "PanelContainer"]:
		t.set_stylebox("panel", type, panel_style(PANEL, CYAN.darkened(0.45), 1, 0.0))

	var le_normal := panel_style(Color(0.02, 0.03, 0.08, 0.9), CYAN.darkened(0.45), 2, 0.0)
	t.set_stylebox("normal", "LineEdit", le_normal)
	t.set_stylebox("focus", "LineEdit", panel_style(Color(0.02, 0.03, 0.08, 0.95), CYAN, 2, 0.0))
	t.set_stylebox("read_only", "LineEdit", le_normal)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", CYAN)
	t.set_color("selection_color", "LineEdit", Color(MAGENTA, 0.45))
	t.set_stylebox("normal", "TextEdit", le_normal)
	t.set_stylebox("focus", "TextEdit", panel_style(Color(0.02, 0.03, 0.08, 0.95), CYAN, 2, 0.0))
	t.set_color("font_color", "TextEdit", TEXT)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = CYAN
	for type in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, track)
		t.set_stylebox("grabber_area", type, fill)
		t.set_stylebox("grabber_area_highlight", type, fill)

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(1, 1, 1, 0.1)
	pb_bg.skew = Vector2(SKEW, 0)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = CYAN
	pb_fill.skew = Vector2(SKEW, 0)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_color("font_color", "ProgressBar", TEXT)

	var tab_sel := panel_style(Color(CYAN, 0.25), CYAN, 2, SKEW)
	var tab_unsel := panel_style(PANEL, CYAN.darkened(0.5), 1, SKEW)
	for type in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", type, tab_sel)
		t.set_stylebox("tab_unselected", type, tab_unsel)
		t.set_stylebox("tab_hovered", type, panel_style(PANEL_LIGHT, CYAN, 1, SKEW))
		t.set_stylebox("tab_focus", type, focus_style())
		t.set_color("font_selected_color", type, TEXT)
		t.set_color("font_unselected_color", type, TEXT_DIM)
		t.set_color("font_hovered_color", type, CYAN)
		t.set_font("font", type, font("head"))
		t.set_font_size("font_size", type, 18)
	t.set_stylebox("panel", "TabContainer", panel_style(PANEL, CYAN.darkened(0.45), 1, 0.0))

	t.set_stylebox("panel", "PopupMenu", panel_style(Color(NAVY, 0.97), CYAN.darkened(0.3), 1, 0.0))
	t.set_stylebox("hover", "PopupMenu", panel_style(Color(CYAN, 0.25), CYAN, 0, 0.0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	t.set_stylebox("panel", "PopupPanel", panel_style(Color(NAVY, 0.97), CYAN.darkened(0.3), 1, 0.0))

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.06)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(CYAN, 0.6)
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, sb)
		t.set_stylebox("grabber", type, grab)
		t.set_stylebox("grabber_highlight", type, grab)
		t.set_stylebox("grabber_pressed", type, grab)

	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", CYAN)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", CYAN)
	t.set_stylebox("focus", "CheckBox", focus_style())
	t.set_stylebox("focus", "CheckButton", focus_style())

	t.set_color("font_color", "ItemList", TEXT)
	t.set_stylebox("panel", "ItemList", panel_style(PANEL, CYAN.darkened(0.45), 1, 0.0))
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", font("body"))
	t.set_font("bold_font", "RichTextLabel", font("body_bold"))

	_theme = t
	return t


## Flat neon-edged panel. `skew` is horizontal (0 = rectangle).
static func panel_style(bg: Color, border: Color, border_w: int = 2, skew: float = SKEW) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.skew = Vector2(skew, 0)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.anti_aliasing = true
	return s


static func focus_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = LIME
	s.set_border_width_all(2)
	s.skew = Vector2(SKEW, 0)
	s.expand_margin_left = 3
	s.expand_margin_right = 3
	s.expand_margin_top = 3
	s.expand_margin_bottom = 3
	return s


## Convenience: a Label with a font kind, size and color.
static func label(text: String, kind: String = "body", size: int = 22, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## "1:02.345" style time; -1 -> "--:--.---".
static func format_time(ms: int) -> String:
	if ms < 0:
		return "--:--.---"
	var m := ms / 60000
	var s := (ms / 1000) % 60
	var r := ms % 1000
	return "%d:%02d.%03d" % [m, s, r]


## "+0.123" / "-1.045" delta.
static func format_delta(delta_ms: int) -> String:
	var sign := "+" if delta_ms >= 0 else "-"
	var a := absi(delta_ms)
	return "%s%d.%03d" % [sign, a / 1000, a % 1000]
