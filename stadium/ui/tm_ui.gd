class_name TmUi
extends RefCounted
## The remake's menu look (our own, in the spirit of TMNF's menus: dark green glass panels with a
## gloss along the top, white capitals, lime green for what's selected, glossy sphere checkboxes,
## medal discs; ui/tm_glass_box.gd draws the glass, tools/texgen/ui.py the icons in assets/ui;
## Orbitron for titles and times, Rajdhani for the rest, both SIL OFL, assets/fonts) and the
## player's settings (user://settings.cfg).

const ACCENT := Color(0.60, 0.88, 0.17)     ## lime: focus, selection, highlights
const PANEL := Color(0.04, 0.08, 0.06, 0.84)
const TEXT := Color(0.95, 0.97, 0.95)
const DIM := Color(0.66, 0.74, 0.70)
## The campaign's series in TMNF's colours: [letter, name, colour].
const SERIES := [["A", "White", Color(0.92, 0.93, 0.95)], ["B", "Green", Color(0.30, 0.78, 0.35)],
	["C", "Blue", Color(0.30, 0.52, 1.00)], ["D", "Red", Color(0.92, 0.25, 0.20)], ["E", "Black", Color(0.12, 0.12, 0.14)]]

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULTS := {"fullscreen": false, "shadows": true, "ghost": true, "sound": true, "hd": true,
	"name": "Player", "zone": "", "server": "", "token": "", "colour": 0, "music": true, "music_volume": 0.7, "sound_volume": 1.0, "quality": 1, "dlss": 0, "path_tracing": false, "rtx_bounces": 2,
	"car_pack": "", "community_car": ""}
	# car_pack: the SHA-256 of the car pack last picked on a server (Online); community_car: the
	# community car (a car pack from the Community page, TmCommunity) we drive ("" our own car)
## Car colours to pick from (online, the others see yours).
const CAR_COLOURS := [Color(0.85, 0.08, 0.06), Color(0.10, 0.35, 0.90), Color(0.95, 0.70, 0.05), Color(0.10, 0.65, 0.30),
	Color(0.92, 0.92, 0.94), Color(0.10, 0.10, 0.12), Color(0.95, 0.40, 0.05), Color(0.55, 0.20, 0.85)]


static func car_colour() -> Color:
	return CAR_COLOURS[clampi(int(setting("colour")), 0, CAR_COLOURS.size() - 1)]

static var _theme: Theme
static var _fonts := {}
static var _icons := {}

const TITLE := "orbitron-latin-900-normal"
const HEAD := "orbitron-latin-700-normal"
const BODY := "rajdhani-latin-500-normal"
const BOLD := "rajdhani-latin-700-normal"
## TMNF's own type (M10-5): a humanist sans for its menus and in-race text (Cabin, SIL OFL, in the
## spirit of TMNF's Gill-like face) and 7-segment digits for the race clock and speed (DSEG7
## Classic, SIL OFL).
const SANS := "cabin-latin-600-normal"
const SANS_BOLD := "cabin-latin-700-normal"
const SANS_ITALIC := "cabin-latin-700-italic"
const DIGITS := "dseg7-classic-bold"


## One of the UI fonts (TITLE, HEAD, BODY, BOLD), optionally letter-spaced (pixels).
static func font(key: String, spacing := 0) -> Font:
	var id := "%s/%d" % [key, spacing]
	if not _fonts.has(id):
		var f: Font = load("res://assets/fonts/%s.woff2" % key)
		if spacing != 0:
			var v := FontVariation.new()
			v.base_font = f
			v.spacing_glyph = spacing
			f = v
		_fonts[id] = f
	return _fonts[id]
static var _cfg: ConfigFile
static var _ui_player: AudioStreamPlayer


## A font made bolder and/or slanted (nicknames' $o and $i).
static func styled(key: String, bold: bool, italic: bool) -> Font:
	var id := "%s/b%d/i%d" % [key, int(bold), int(italic)]
	if not _fonts.has(id):
		var v := FontVariation.new()
		v.base_font = font(key)
		if bold:
			v.variation_embolden = 0.8
		if italic:
			v.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
		_fonts[id] = v
	return _fonts[id]


## An icon from assets/ui (medal_gold, check_on, star, play, logo, ...), optionally scaled to px
## pixels high (for theme icons, which draw at their texture's size).
static func icon(name: String, px := 0) -> Texture2D:
	var id := "%s/%d" % [name, px]
	if not _icons.has(id):
		var t: Texture2D = load("res://assets/ui/%s.png" % name)
		if px > 0 and t:
			var img := t.get_image()
			if img.is_compressed():
				img.decompress()
			img.resize(maxi(1, roundi(img.get_width() * float(px) / img.get_height())), px, Image.INTERPOLATE_LANCZOS)
			t = ImageTexture.create_from_image(img)
		_icons[id] = t
	return _icons[id]


## TMNF's green (focused and selected text, the dialogs' title bars).
const TM_GREEN := Color(0.10, 0.78, 0.10)
## TMNF's dark grey for text on its white pill buttons.
const TM_INK := Color(0.16, 0.16, 0.17)


## The glass: the plain panel and button, and their states; the tm_* kinds are TMNF's own dialog
## pieces (M10-5, drawn after its menus side by side): a dark rounded panel, a green title bar, white
## pill buttons with dark text, green text and a green ring for the focused one.
static func glass(kind: String) -> TmGlassBox:
	match kind:
		"tm_dialog":
			var d := TmGlassBox.make({"top": Color(0.24, 0.24, 0.25, 0.62), "bottom": Color(0.06, 0.06, 0.07, 0.82),
				"gloss": 0.05, "gloss_depth": 0.35, "radius": 10.0, "border": Color(0.42, 0.42, 0.44, 0.85),
				"border_top": Color(0.78, 0.78, 0.80, 0.9), "border_width": 2.0})
			d.content_margin_left = 10
			d.content_margin_right = 10
			d.content_margin_top = 8
			d.content_margin_bottom = 14
			return d
		"tm_column":     # the left column behind the rows: near black
			return TmGlassBox.make({"top": Color(0.07, 0.07, 0.075, 0.86), "bottom": Color(0.03, 0.03, 0.035, 0.9),
				"gloss": 0.0, "radius": 8.0, "border": Color(0.25, 0.25, 0.27, 0.8), "border_top": Color(0.4, 0.4, 0.42, 0.8),
				"border_width": 1.5})
		"tm_card":       # the column's header card: light grey
			var c := TmGlassBox.make({"top": Color(0.80, 0.80, 0.81, 0.97), "bottom": Color(0.47, 0.47, 0.49, 0.97),
				"gloss": 0.25, "gloss_depth": 0.45, "radius": 9.0, "border": Color(0.25, 0.25, 0.26, 0.9),
				"border_top": Color(0.95, 0.95, 0.95, 1.0), "border_width": 1.5})
			c.content_margin_left = 16
			c.content_margin_right = 10
			c.content_margin_top = 2
			c.content_margin_bottom = 4
			return c
		"tm_row":        # an entry of the column: a faint tile
			return TmGlassBox.make({"top": Color(1, 1, 1, 0.035), "bottom": Color(1, 1, 1, 0.02), "gloss": 0.0,
				"radius": 5.0, "border": Color(1, 1, 1, 0.04), "border_top": Color(1, 1, 1, 0.06), "border_width": 1.0})
		"tm_row_hover":
			return TmGlassBox.make({"top": Color(1, 1, 1, 0.07), "bottom": Color(1, 1, 1, 0.04), "gloss": 0.0,
				"radius": 5.0, "border": Color(1, 1, 1, 0.08), "border_top": Color(1, 1, 1, 0.1), "border_width": 1.0})
		"tm_row_chosen":  # the page's current choice: a green ring
			return TmGlassBox.make({"top": Color(0.05, 0.16, 0.05, 0.55), "bottom": Color(0.02, 0.08, 0.02, 0.55), "gloss": 0.0,
				"radius": 8.0, "border": TM_GREEN, "border_top": Color(0.5, 1.0, 0.5), "border_width": 2.0})
		"tm_row_focus":
			return TmGlassBox.make({"top": Color(0, 0, 0, 0), "bottom": Color(0, 0, 0, 0), "gloss": 0.0, "radius": 8.0,
				"border": Color(TM_GREEN, 0.55), "border_top": Color(TM_GREEN, 0.55), "border_width": 1.5})
		"tm_bar":        # the bar across the top (TmTopBar): near black, square
			return TmGlassBox.make({"top": Color(0.10, 0.10, 0.11, 1.0), "bottom": Color(0.03, 0.03, 0.035, 1.0),
				"gloss": 0.0, "radius": 0.0, "corners": 0, "border": Color(0.25, 0.25, 0.27, 0.8),
				"border_top": Color(0.25, 0.25, 0.27, 0.8), "border_width": 1.0})
		"tm_list":       # a row of a list (replays, tracks, servers): a light grey strip, dark text
			return TmGlassBox.make({"top": Color(0.86, 0.86, 0.87, 0.94), "bottom": Color(0.68, 0.68, 0.70, 0.94),
				"gloss": 0.15, "gloss_depth": 0.5, "radius": 4.0, "border": Color(0.25, 0.25, 0.26, 0.8),
				"border_top": Color(1, 1, 1, 0.9), "border_width": 1.0})
		"tm_list_hover":
			return TmGlassBox.make({"top": Color(0.97, 0.97, 0.97, 0.97), "bottom": Color(0.80, 0.81, 0.81, 0.97),
				"gloss": 0.2, "gloss_depth": 0.5, "radius": 4.0, "border": Color(0.25, 0.25, 0.26, 0.8),
				"border_top": Color(1, 1, 1, 1), "border_width": 1.0})
		"tm_list_chosen":  # the picked row: white, a green bar along its left edge
			return TmGlassBox.make({"top": Color(1, 1, 1, 0.98), "bottom": Color(0.88, 0.90, 0.88, 0.98),
				"gloss": 0.2, "gloss_depth": 0.5, "radius": 4.0, "border": Color(0.1, 0.5, 0.1, 0.9),
				"border_top": Color(1, 1, 1, 1), "border_width": 1.0, "stripe": TM_GREEN, "stripe_width": 6.0})
		"tm_list_focus":
			return TmGlassBox.make({"top": Color(0, 0, 0, 0), "bottom": Color(0, 0, 0, 0), "gloss": 0.0, "radius": 5.0,
				"border": TM_GREEN, "border_top": Color(0.45, 1.0, 0.45), "border_width": 2.0})
		"tm_title":
			return TmGlassBox.make({"top": Color(0.17, 0.62, 0.19, 1.0), "bottom": Color(0.07, 0.44, 0.10, 1.0),
				"gloss": 0.16, "gloss_depth": 0.5, "radius": 8.0, "border": Color(0.03, 0.25, 0.05, 0.9),
				"border_top": Color(0.55, 0.9, 0.5, 0.9), "border_width": 1.5})
		"tm_button":
			return TmGlassBox.make({"top": Color(0.98, 0.98, 0.98, 1.0), "bottom": Color(0.76, 0.77, 0.78, 1.0),
				"gloss": 0.3, "gloss_depth": 0.5, "radius": 100.0, "border": Color(0.30, 0.30, 0.31, 0.9),
				"border_top": Color(1, 1, 1, 1), "border_width": 1.5})
		"tm_button_hover":
			return TmGlassBox.make({"top": Color(1, 1, 1, 1.0), "bottom": Color(0.84, 0.86, 0.85, 1.0),
				"gloss": 0.35, "gloss_depth": 0.5, "radius": 100.0, "border": Color(0.30, 0.30, 0.31, 0.9),
				"border_top": Color(1, 1, 1, 1), "border_width": 1.5})
		"tm_button_pressed":
			return TmGlassBox.make({"top": Color(0.70, 0.72, 0.72, 1.0), "bottom": Color(0.90, 0.91, 0.91, 1.0),
				"gloss": 0.1, "radius": 100.0, "border": Color(0.25, 0.25, 0.26, 0.9), "border_width": 1.5})
		"tm_tile":       # a picture tile (the campaign's track cards, the editor's blocks): light grey
			return TmGlassBox.make({"top": Color(0.88, 0.88, 0.89, 1), "bottom": Color(0.62, 0.62, 0.64, 1), "gloss": 0.2,
				"radius": 6.0, "border": Color(0.35, 0.35, 0.36, 1), "border_top": Color(1, 1, 1, 1), "border_width": 1.5})
		"tm_tile_lit":   # focused or picked: all green
			return TmGlassBox.make({"top": Color(0.55, 0.95, 0.45, 1), "bottom": Color(0.15, 0.62, 0.12, 1), "gloss": 0.25,
				"radius": 6.0, "border": Color(0.1, 0.5, 0.1, 1), "border_top": Color(0.8, 1, 0.75, 1), "border_width": 1.5})
		"tm_button_disabled":   # greyed: the pill faded into the panel
			return TmGlassBox.make({"top": Color(0.62, 0.62, 0.63, 0.35), "bottom": Color(0.45, 0.45, 0.46, 0.35),
				"gloss": 0.1, "radius": 100.0, "border": Color(0.30, 0.30, 0.31, 0.5), "border_width": 1.5})
		"tm_button_focus":
			return TmGlassBox.make({"top": Color(0, 0, 0, 0), "bottom": Color(0, 0, 0, 0), "gloss": 0.0, "radius": 100.0,
				"border": TM_GREEN, "border_top": Color(0.45, 1.0, 0.45), "border_width": 2.5,
				"glow": Color(TM_GREEN, 0.7), "glow_size": 5.0})
		"panel":
			var p := TmGlassBox.make({"top": Color(0.08, 0.14, 0.11, 0.80), "bottom": Color(0.02, 0.05, 0.04, 0.88),
				"gloss": 0.07, "gloss_depth": 0.22, "radius": 14.0, "border": Color(1, 1, 1, 0.10), "border_top": Color(1, 1, 1, 0.26)})
			p.content_margin_left = 24
			p.content_margin_right = 24
			p.content_margin_top = 18
			p.content_margin_bottom = 18
			return p
		"bar":
			return TmGlassBox.make({"top": Color(0.05, 0.10, 0.08, 0.86), "bottom": Color(0.01, 0.03, 0.02, 0.92),
				"gloss": 0.06, "gloss_depth": 0.5, "radius": 0.0, "corners": 0, "border": Color(1, 1, 1, 0.0), "border_top": Color(1, 1, 1, 0.0),
				"border_width": 0.0})
		"hover":
			return TmGlassBox.make({"top": Color(0.22, 0.32, 0.22, 0.92), "bottom": Color(0.07, 0.14, 0.09, 0.94),
				"gloss": 0.18, "radius": 8.0, "border": Color(ACCENT, 0.5), "border_top": Color(1, 1, 1, 0.5),
				"stripe": ACCENT, "stripe_width": 5.0})
		"pressed":
			return TmGlassBox.make({"top": Color(0.48, 0.72, 0.12, 0.96), "bottom": Color(0.22, 0.40, 0.04, 0.98),
				"gloss": 0.28, "radius": 8.0, "border": Color(ACCENT, 0.9), "border_top": Color(1, 1, 1, 0.7)})
		"focus":
			return TmGlassBox.make({"top": Color(0, 0, 0, 0), "bottom": Color(0, 0, 0, 0), "gloss": 0.0, "radius": 8.0,
				"border": ACCENT, "border_top": Color(0.85, 1.0, 0.6), "border_width": 2.0, "glow": Color(ACCENT, 0.8), "glow_size": 7.0})
		"go":   # the race button: lime glass
			return TmGlassBox.make({"top": Color(0.62, 0.90, 0.22, 0.96), "bottom": Color(0.28, 0.52, 0.05, 0.98),
				"gloss": 0.32, "radius": 8.0, "border": Color(0.75, 1.0, 0.4), "border_top": Color(1, 1, 1, 0.8)})
		"go_hover":
			return TmGlassBox.make({"top": Color(0.74, 0.98, 0.32, 1.0), "bottom": Color(0.36, 0.64, 0.08, 1.0),
				"gloss": 0.38, "radius": 8.0, "border": Color(0.85, 1.0, 0.5), "border_top": Color(1, 1, 1, 0.9)})
		"disabled":
			return TmGlassBox.make({"top": Color(0.06, 0.08, 0.07, 0.55), "bottom": Color(0.03, 0.04, 0.04, 0.6),
				"gloss": 0.03, "radius": 8.0, "border": Color(1, 1, 1, 0.05), "border_top": Color(1, 1, 1, 0.1)})
		"field":
			return TmGlassBox.make({"top": Color(0.0, 0.02, 0.01, 0.75), "bottom": Color(0.03, 0.06, 0.05, 0.8),
				"gloss": 0.0, "radius": 6.0, "border": Color(1, 1, 1, 0.22), "border_top": Color(0, 0, 0, 0.5)})
	return TmGlassBox.make({"top": Color(0.17, 0.25, 0.20, 0.84), "bottom": Color(0.03, 0.07, 0.05, 0.90),
		"gloss": 0.16, "gloss_depth": 0.5, "radius": 8.0})   # "button"


## The theme every menu and overlay uses.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font(SANS)
	t.default_font_size = 23
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Label", 4)
	# buttons: TMNF's white pills with dark text, green text and ring when focused
	for kind in ["Button", "CheckButton", "OptionButton"]:
		t.set_stylebox("normal", kind, glass("tm_button"))
		t.set_stylebox("hover", kind, glass("tm_button_hover"))
		t.set_stylebox("pressed", kind, glass("tm_button_pressed"))
		t.set_stylebox("hover_pressed", kind, glass("tm_button_pressed"))
		t.set_stylebox("focus", kind, glass("tm_button_focus"))
		t.set_stylebox("disabled", kind, glass("tm_button_disabled"))
		t.set_font("font", kind, font(SANS_BOLD))
		t.set_color("font_color", kind, TM_INK)
		t.set_color("font_hover_color", kind, TM_GREEN.darkened(0.15))
		t.set_color("font_focus_color", kind, TM_GREEN.darkened(0.15))
		t.set_color("font_pressed_color", kind, TM_INK)
		t.set_color("font_hover_pressed_color", kind, TM_GREEN.darkened(0.15))
		t.set_color("font_disabled_color", kind, Color(1, 1, 1, 0.3))
		t.set_color("font_outline_color", kind, Color(0, 0, 0, 0.0))
		t.set_constant("outline_size", kind, 0)
		t.set_font_size("font_size", kind, 23)
	# checkboxes: TMNF's glossy spheres, dark off and lime on; the row doesn't light up when on
	t.set_stylebox("pressed", "CheckButton", glass("tm_button"))
	t.set_stylebox("hover_pressed", "CheckButton", glass("tm_button_hover"))
	t.set_color("font_pressed_color", "CheckButton", TM_INK)
	t.set_color("font_hover_pressed_color", "CheckButton", TM_GREEN.darkened(0.15))
	for state in ["", "_disabled", "_mirrored", "_disabled_mirrored"]:
		t.set_icon("checked" + state, "CheckButton", icon("check_on", 34))
		t.set_icon("unchecked" + state, "CheckButton", icon("check_off", 34))
	t.set_stylebox("panel", "PanelContainer", glass("tm_dialog"))
	for kind in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", kind, glass("field"))
		var f := glass("field")
		f.border = TM_GREEN
		f.border_top = TM_GREEN
		f.border_width = 2.0
		t.set_stylebox("focus", kind, f)
		t.set_stylebox("read_only", kind, glass("disabled"))
		t.set_font("font", kind, font(SANS))
		t.set_font_size("font_size", kind, 23)
		t.set_color("font_color", kind, TEXT)
		t.set_color("caret_color", kind, TM_GREEN)
		t.set_color("selection_color", kind, Color(TM_GREEN, 0.35))
		t.set_color("font_placeholder_color", kind, Color(DIM, 0.6))
	t.set_stylebox("panel", "PopupMenu", glass("panel"))
	t.set_stylebox("hover", "PopupMenu", glass("hover"))
	t.set_font("font", "PopupMenu", font(SANS))
	t.set_font_size("font_size", "PopupMenu", 22)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	var sep := StyleBoxLine.new()
	sep.color = Color(1, 1, 1, 0.14)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 14)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.16)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = ACCENT
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", icon("check_on", 28))
	t.set_icon("grabber_highlight", "HSlider", icon("check_on", 32))
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(1, 1, 1, 0.05)
	bar.set_corner_radius_all(4)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1, 1, 1, 0.3)
	grab.set_corner_radius_all(4)
	t.set_stylebox("scroll", "VScrollBar", bar)
	t.set_stylebox("grabber", "VScrollBar", grab)
	var grab_hi := grab.duplicate() as StyleBoxFlat
	grab_hi.bg_color = ACCENT
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)
	t.set_font("normal_font", "RichTextLabel", font(SANS))
	t.set_font("bold_font", "RichTextLabel", styled(SANS, true, false))
	t.set_font("italics_font", "RichTextLabel", styled(SANS, false, true))
	t.set_font("bold_italics_font", "RichTextLabel", styled(SANS, true, true))
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_outline_color", "RichTextLabel", Color(0, 0, 0, 0.7))
	t.set_constant("outline_size", "RichTextLabel", 3)
	_theme = t
	return t


## A label with a given size, colour and font (TITLE, HEAD, BODY, BOLD; spacing in pixels).
static func label(text: String, size := 24, colour := TEXT, key := BODY, spacing := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	if key != BODY or spacing != 0:
		l.add_theme_font_override("font", font(key, spacing))
	return l


## A nickname with its $-codes rendered (TmNick), one line.
static func nick_label(nick: String, size := 24, default_colour := TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for f in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		r.add_theme_font_size_override(f, size)
	r.text = TmNick.to_bbcode(nick, default_colour)
	return r


## A button in TMNF's dialog style: a white pill with dark text, green when focused.
static func tm_button(text: String, action: Callable, min_width := 220) -> Button:
	var b := button(text, action, min_width)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size.y = 40
	b.add_theme_stylebox_override("normal", glass("tm_button"))
	b.add_theme_stylebox_override("hover", glass("tm_button_hover"))
	b.add_theme_stylebox_override("pressed", glass("tm_button_pressed"))
	b.add_theme_stylebox_override("hover_pressed", glass("tm_button_pressed"))
	b.add_theme_stylebox_override("focus", glass("tm_button_focus"))
	b.add_theme_stylebox_override("disabled", glass("tm_button_disabled"))
	b.add_theme_font_override("font", font(SANS_BOLD))
	b.add_theme_font_size_override("font_size", 23)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_color_override("font_color", TM_INK)
	b.add_theme_color_override("font_pressed_color", TM_INK)
	b.add_theme_color_override("font_hover_color", TM_GREEN.darkened(0.15))
	b.add_theme_color_override("font_focus_color", TM_GREEN.darkened(0.15))
	b.add_theme_color_override("font_hover_pressed_color", TM_GREEN.darkened(0.15))
	b.add_theme_color_override("font_disabled_color", Color(0.75, 0.75, 0.76, 0.55))
	return b


## TMNF's dialog title: a green bar across the panel's top with the title in white.
static func tm_title(text: String) -> PanelContainer:
	var bar := PanelContainer.new()
	var st := glass("tm_title")
	st.content_margin_top = 3
	st.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", st)
	var l := label(text, 25, Color.WHITE, SANS_BOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", 1)
	bar.add_child(l)
	return bar


## Makes a button the lime "go" button (Race, Join).
static func go(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", glass("go"))
	b.add_theme_stylebox_override("hover", glass("go_hover"))
	b.add_theme_stylebox_override("pressed", glass("pressed"))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color(0.03, 0.07, 0.01))
	b.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.25))
	b.add_theme_color_override("icon_normal_color", Color(0.03, 0.07, 0.01))
	b.add_theme_color_override("icon_hover_color", Color(0.03, 0.07, 0.01))
	b.add_theme_color_override("icon_focus_color", Color(0.03, 0.07, 0.01))
	return b


static func button(text: String, action: Callable, min_width := 320) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 54)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if action.is_valid():
		b.pressed.connect(action)
	b.pressed.connect(play.bind("click"))
	b.mouse_entered.connect(play.bind("move"))
	b.mouse_entered.connect(b.grab_focus)
	return b


## A menu sound (TmSounds name) on a player that outlives scene changes.
static func play(name: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if not is_instance_valid(_ui_player):
		_ui_player = AudioStreamPlayer.new()
		_ui_player.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(_ui_player)
	_ui_player.stream = TmSounds.get_stream(name)
	_ui_player.play()


# --- settings ---

static var _cfg_path := ""


## The settings file: user://settings.cfg, or --settings=<file> (tests keep the player's own apart).
static func settings_path() -> String:
	return String(TestHooks.arg("settings", SETTINGS_PATH))


static func _settings() -> ConfigFile:
	if _cfg == null or _cfg_path != settings_path():
		_cfg_path = settings_path()
		_cfg = ConfigFile.new()
		_cfg.load(_cfg_path)
	return _cfg


## A setting; --set_<key>=value on the command line overrides it for a run (tests, screenshots).
static func setting(key: String) -> Variant:
	var v: Variant = _settings().get_value("game", key, DEFAULTS.get(key))
	if TestHooks.has_arg("set_" + key):
		v = TestHooks.arg("set_" + key, v)
	return v


static func set_setting(key: String, value: Variant) -> void:
	_settings().set_value("game", key, value)
	_settings().save(settings_path())
	if key == "hd":
		TmMaterials.clear_cache()
	if key in ["music", "music_volume"]:
		var tree := Engine.get_main_loop() as SceneTree
		var m := tree.root.get_node_or_null("Music") if tree else null
		if m:
			m.apply_volume()
	apply()


## Applies the sound and window settings (the scenes read the rest themselves).
static func apply() -> void:
	AudioServer.set_bus_mute(0, not bool(setting("sound")))
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(setting("sound_volume")), 0.0, 1.0) + 1e-4))
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		TmRtx.apply_viewport(tree.root)
	if DisplayServer.get_name() == "headless":
		return
	var full := bool(setting("fullscreen"))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
