class_name TmUi
extends RefCounted
## The remake's menu look (our own, in the spirit of TMNF's: dark glass panels, bold white
## capitals, a cyan accent) and the player's settings (user://settings.cfg).

const ACCENT := Color(0.30, 0.78, 1.00)
const PANEL := Color(0.03, 0.05, 0.10, 0.82)
const TEXT := Color(0.94, 0.96, 1.00)
const DIM := Color(0.62, 0.68, 0.78)
## The campaign's series in TMNF's colours: [letter, name, colour].
const SERIES := [["A", "White", Color(0.92, 0.93, 0.95)], ["B", "Green", Color(0.30, 0.78, 0.35)],
	["C", "Blue", Color(0.30, 0.52, 1.00)], ["D", "Red", Color(0.92, 0.25, 0.20)], ["E", "Black", Color(0.12, 0.12, 0.14)]]

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULTS := {"fullscreen": false, "shadows": true, "ghost": true}

static var _theme: Theme
static var _cfg: ConfigFile


static func _box(bg: Color, border: Color, width: int, radius := 6) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	return b


## The theme every menu and overlay uses.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 24
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Label", 4)
	for kind in ["Button", "CheckButton"]:
		t.set_stylebox("normal", kind, _box(Color(0.06, 0.09, 0.16, 0.85), Color(1, 1, 1, 0.10), 1))
		t.set_stylebox("hover", kind, _box(Color(0.10, 0.18, 0.30, 0.95), ACCENT, 2))
		t.set_stylebox("pressed", kind, _box(Color(0.14, 0.30, 0.46, 0.95), ACCENT, 2))
		t.set_stylebox("focus", kind, _box(Color(0, 0, 0, 0), ACCENT, 3))
		t.set_stylebox("disabled", kind, _box(Color(0.05, 0.06, 0.08, 0.6), Color(1, 1, 1, 0.05), 1))
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_focus_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, Color.WHITE)
		t.set_color("font_disabled_color", kind, Color(1, 1, 1, 0.3))
		t.set_font_size("font_size", kind, 26)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, Color(1, 1, 1, 0.08), 1, 10))
	_theme = t
	return t


## A label with a given size and colour.
static func label(text: String, size := 24, colour := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


static func button(text: String, action: Callable, min_width := 320) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 54)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	return b


# --- settings ---

static func _settings() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(SETTINGS_PATH)
	return _cfg


static func setting(key: String) -> Variant:
	return _settings().get_value("game", key, DEFAULTS.get(key))


static func set_setting(key: String, value: Variant) -> void:
	_settings().set_value("game", key, value)
	_settings().save(SETTINGS_PATH)
	apply()


## Applies the window settings (the scenes read the rest themselves).
static func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var full := bool(setting("fullscreen"))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
