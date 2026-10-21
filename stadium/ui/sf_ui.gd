class_name SfUi
extends RefCounted
## SpeedFest's own menu look (PLAN M16; the owner: "move away from this trackmania vibe and have our
## own vibe ... panel-based. Colours minimalistic, slight hint of red and blue/purple"): charcoal
## panels with square corners and hairline borders, white type in Montserrat (SIL OFL,
## assets/fonts), red for what is chosen, violet as the second accent, the two meeting in a
## gradient line (`accent_line`). The menus (TmMenu, SfHeader, SfTile) use it; the race's overlays
## keep TmUi's for now.

const BG := Color("0b0c10")
const PANEL := Color(0.07, 0.074, 0.094, 0.94)
const PANEL_HI := Color(0.115, 0.12, 0.15, 0.96)
const LINE := Color(1, 1, 1, 0.09)
const TEXT := Color("f2f3f7")
const DIM := Color("9296a8")
const FAINT := Color("5b5f70")
const RED := Color("e8364f")
const VIOLET := Color("7357ff")
const HOT := Color("ff5b70")          ## red text on the dark (values, what is on)

const BLACK := "montserrat-latin-800-normal"
const BOLD := "montserrat-latin-700-normal"
const SEMI := "montserrat-latin-600-normal"
const MEDIUM := "montserrat-latin-500-normal"
const WORDMARK := "montserrat-latin-800-italic"

static var _theme: Theme
static var _boxes := {}
static var _gradient: GradientTexture2D


## A flat box: fill, border (all sides, or `left` only: a bar along the left edge), margins.
static func _flat(fill: Color, border := Color(0, 0, 0, 0), width := 0, left := 0, margin := Vector2(16, 8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.draw_center = fill.a > 0.0
	s.border_color = border
	s.set_border_width_all(width)
	if left > 0:
		s.border_width_left = left
	s.set_corner_radius_all(2)
	s.anti_aliasing = true
	s.content_margin_left = margin.x
	s.content_margin_right = margin.x
	s.content_margin_top = margin.y
	s.content_margin_bottom = margin.y
	return s


## The menus' boxes by kind: panel, column, row (+ _hover, _chosen), focus, button (+ _hover,
## _pressed, _disabled), primary (+ _hover), field (+ _focus), list (+ _hover, _chosen, _focus),
## tile (+ _lit), header, chip.
static func box(kind: String) -> StyleBoxFlat:
	if _boxes.has(kind):
		return _boxes[kind]
	var s: StyleBoxFlat
	match kind:
		"panel":
			s = _flat(PANEL, LINE, 1, 0, Vector2(18, 14))
		"column":
			s = _flat(Color(0.055, 0.058, 0.075, 0.9), LINE, 1)
		"row":
			s = _flat(Color(1, 1, 1, 0.0), Color(0, 0, 0, 0), 0, 0, Vector2(18, 6))
		"row_hover":
			s = _flat(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 0, Vector2(18, 6))
		"row_chosen":
			s = _flat(Color(1, 1, 1, 0.07), RED, 0, 3, Vector2(18, 6))
		"focus":
			s = _flat(Color(0, 0, 0, 0), Color(1, 1, 1, 0.55), 1)
		"button":
			s = _flat(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.14), 1, 0, Vector2(20, 8))
		"button_hover":
			s = _flat(Color(1, 1, 1, 0.13), Color(1, 1, 1, 0.24), 1, 0, Vector2(20, 8))
		"button_pressed":
			s = _flat(RED.darkened(0.15), RED, 1, 0, Vector2(20, 8))
		"button_disabled":
			s = _flat(Color(1, 1, 1, 0.025), Color(1, 1, 1, 0.06), 1, 0, Vector2(20, 8))
		"primary":
			s = _flat(RED, RED.lightened(0.15), 1, 0, Vector2(20, 8))
		"primary_hover":
			s = _flat(RED.lightened(0.12), RED.lightened(0.35), 1, 0, Vector2(20, 8))
		"field":
			s = _flat(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.14), 1, 0, Vector2(14, 6))
		"field_focus":
			s = _flat(Color(0, 0, 0, 0.45), RED, 1, 0, Vector2(14, 6))
		"list":
			s = _flat(Color(1, 1, 1, 0.035), Color(0, 0, 0, 0), 0, 0, Vector2(14, 4))
		"list_hover":
			s = _flat(Color(1, 1, 1, 0.085), Color(0, 0, 0, 0), 0, 0, Vector2(14, 4))
		"list_chosen":
			s = _flat(Color(RED, 0.16), RED, 0, 3, Vector2(14, 4))
		"list_focus":
			s = _flat(Color(0, 0, 0, 0), Color(1, 1, 1, 0.45), 1)
		"tile":
			s = _flat(PANEL_HI, LINE, 1, 0, Vector2(0, 0))
		"tile_lit":
			s = _flat(Color(0, 0, 0, 0), RED, 2, 0, Vector2(0, 0))
		"header":
			s = _flat(Color(0.035, 0.037, 0.05, 0.86), Color(0, 0, 0, 0), 0)
			s.border_color = LINE
			s.border_width_bottom = 1
			s.set_corner_radius_all(0)
		"chip":
			s = _flat(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.25), 1, 0, Vector2(10, 3))
		"chip_violet":
			s = _flat(Color(VIOLET, 0.22), VIOLET.lightened(0.2), 1, 0, Vector2(10, 3))
		_:
			s = _flat(PANEL, LINE, 1)
	_boxes[kind] = s
	return s


## The red-to-violet gradient (accent lines, the chosen tab's underline, the wordmark's slashes).
static func gradient() -> GradientTexture2D:
	if _gradient == null:
		var g := Gradient.new()
		g.set_color(0, RED)
		g.set_color(1, VIOLET)
		_gradient = GradientTexture2D.new()
		_gradient.gradient = g
		_gradient.width = 256
		_gradient.height = 1
	return _gradient


## A thin red-to-violet line (`h` px high; its width from its container, or `w`).
static func accent_line(h := 2.0, w := 0.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = gradient()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A label in Montserrat (BLACK, BOLD, SEMI, MEDIUM), optionally letter-spaced (px) and in capitals.
static func label(text: String, size := 20, colour := TEXT, key := MEDIUM, spacing := 0, caps := false) -> Label:
	var l := Label.new()
	l.text = text.to_upper() if caps else text
	l.add_theme_font_override("font", TmUi.font(key, spacing))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_constant_override("outline_size", 0)
	return l


## A caption: small capitals, letter-spaced, dim (panel titles, column headings, field names).
static func caption(text: String, size := 13, colour := DIM) -> Label:
	return label(text, size, colour, BOLD, 2, true)


## A panel's title: a caption with a short accent bar before it.
static func title(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := accent_line(14.0, 3.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var l := caption(text, 14, TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(l)
	return row


## A plain button of the menus (dark, a hairline border; red when pressed); `primary` makes it red.
static func button(text: String, action: Callable, min_width := 200, primary := false) -> Button:
	var b := TmUi.button(text, action, min_width)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size.y = 42
	style_button(b, primary)
	return b


static func style_button(b: Button, primary := false) -> void:
	b.add_theme_stylebox_override("normal", box("primary" if primary else "button"))
	b.add_theme_stylebox_override("hover", box("primary_hover" if primary else "button_hover"))
	b.add_theme_stylebox_override("pressed", box("button_pressed"))
	b.add_theme_stylebox_override("hover_pressed", box("button_pressed"))
	b.add_theme_stylebox_override("focus", box("focus"))
	b.add_theme_stylebox_override("disabled", box("button_disabled"))
	b.add_theme_font_override("font", TmUi.font(BOLD, 1))
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_constant_override("outline_size", 0)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, TEXT)
	b.add_theme_color_override("font_disabled_color", FAINT)


## The theme of the menus' pages: dark flat controls, red for focus and what is on.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = TmUi.font(MEDIUM)
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("outline_size", "Label", 0)
	for kind in ["Button", "CheckButton", "OptionButton"]:
		t.set_stylebox("normal", kind, box("button"))
		t.set_stylebox("hover", kind, box("button_hover"))
		t.set_stylebox("pressed", kind, box("button_pressed"))
		t.set_stylebox("hover_pressed", kind, box("button_pressed"))
		t.set_stylebox("focus", kind, box("focus"))
		t.set_stylebox("disabled", kind, box("button_disabled"))
		t.set_font("font", kind, TmUi.font(SEMI))
		t.set_font_size("font_size", kind, 17)
		for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			t.set_color(c, kind, TEXT)
		t.set_color("font_disabled_color", kind, FAINT)
		t.set_constant("outline_size", kind, 0)
	# switches: just the switch (red when on), no box round it
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(state, "CheckButton", box("row"))
	for state in ["", "_disabled", "_mirrored", "_disabled_mirrored"]:
		t.set_icon("checked" + state, "CheckButton", _switch(true))
		t.set_icon("unchecked" + state, "CheckButton", _switch(false))
	t.set_stylebox("panel", "PanelContainer", box("panel"))
	for kind in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", kind, box("field"))
		t.set_stylebox("focus", kind, box("field_focus"))
		t.set_stylebox("read_only", kind, box("button_disabled"))
		t.set_font("font", kind, TmUi.font(MEDIUM))
		t.set_font_size("font_size", kind, 18)
		t.set_color("font_color", kind, TEXT)
		t.set_color("caret_color", kind, RED)
		t.set_color("selection_color", kind, Color(RED, 0.35))
		t.set_color("font_placeholder_color", kind, FAINT)
	var pop := _flat(Color(0.06, 0.063, 0.08, 0.98), LINE, 1, 0, Vector2(8, 8))
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", _flat(Color(RED, 0.3), Color(0, 0, 0, 0), 0))
	t.set_font("font", "PopupMenu", TmUi.font(MEDIUM))
	t.set_font_size("font_size", "PopupMenu", 17)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_separator_color", "PopupMenu", DIM)
	var sep := StyleBoxLine.new()
	sep.color = LINE
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 14)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = RED
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _knob(14, TEXT))
	t.set_icon("grabber_highlight", "HSlider", _knob(16, Color.WHITE))
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(1, 1, 1, 0.04)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1, 1, 1, 0.22)
	t.set_stylebox("scroll", "VScrollBar", bar)
	t.set_stylebox("grabber", "VScrollBar", grab)
	var grab_hi := grab.duplicate() as StyleBoxFlat
	grab_hi.bg_color = RED
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)
	t.set_font("normal_font", "RichTextLabel", TmUi.font(SEMI))
	t.set_font("bold_font", "RichTextLabel", TmUi.font(BLACK))
	t.set_font("italics_font", "RichTextLabel", TmUi.styled(SEMI, false, true))
	t.set_font("bold_italics_font", "RichTextLabel", TmUi.styled(BLACK, false, true))
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_constant("outline_size", "RichTextLabel", 0)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("panel", "TooltipPanel", pop)
	_theme = t
	return t


## A switch's icon: a pill, red with the knob right when on, grey with it left when off.
static func _switch(on: bool) -> ImageTexture:
	var w := 44
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var back := RED if on else Color(1, 1, 1, 0.18)
	var r := h * 0.5
	var knob := Vector2(w - r, r) if on else Vector2(r, r)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var a := clampf(r - p.distance_to(Vector2(cx, r)) + 0.5, 0.0, 1.0)
			var c := Color(back, back.a * a)
			var k := clampf(r - 3.0 - p.distance_to(knob) + 0.5, 0.0, 1.0)
			c = c.blend(Color(1, 1, 1, k))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _knob(px: int, colour: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var r := px * 0.5
	for y in px:
		for x in px:
			var a := clampf(r - Vector2(x + 0.5, y + 0.5).distance_to(Vector2(r, r)) + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(colour, a))
	return ImageTexture.create_from_image(img)
