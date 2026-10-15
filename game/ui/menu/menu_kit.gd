class_name MenuKit
extends RefCounted
## Small builders shared by the menu screens (main menu, track select, garage, lobby, settings).
## Everything is styled through the core UITheme; this only adds layout helpers, sound wiring
## and a few NFSU2-style decorations (skewed header bars, swatches, stat bars).

## Curated neon/street colors for the swatch rows.
const SWATCHES: Array[String] = [
	"#ff2bd6", "#00e5ff", "#a6ff00", "#ffb300", "#ff6a00", "#d0101c", "#2b6bff", "#7a2bff",
	"#f4f4f4", "#9aa3ad", "#2b2f36", "#101218",
]
const PAINT_SWATCHES: Array[String] = [
	"#ff6a00", "#d0101c", "#ff2bd6", "#7a2bff", "#2b6bff", "#00e5ff", "#14c88c", "#a6ff00",
	"#ffd400", "#f4f4f4", "#9aa3ad", "#101218",
]
const LIGHT_SWATCHES: Array[String] = [
	"#00e5ff", "#ff2bd6", "#a6ff00", "#ffb300", "#ff3b3b", "#2b6bff", "#7a2bff", "#f4f4f4",
]
const HEADLIGHT_SWATCHES: Array[String] = [
	"#dfefff", "#fff3d6", "#ffd27a", "#bfe6ff", "#9ec8ff", "#c6a8ff", "#a6ff00", "#00e5ff",
]


## A themed button. Hovering it with the mouse moves keyboard focus onto it, so mouse and
## keyboard/gamepad highlight the same thing, and focus changes play the hover blip.
static func button(text: String, min_w: float = 0.0, min_h: float = 48.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.focus_mode = Control.FOCUS_ALL
	wire_button(b)
	return b


## Flat look for CheckButton/CheckBox rows (the theme's Button styles are meant for buttons).
static func style_toggle(c: Button) -> void:
	var flat := UITheme.panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0.0)
	flat.content_margin_left = 4
	var hot := UITheme.panel_style(Color(UITheme.CYAN, 0.08), Color(UITheme.CYAN, 0.4), 1, 0.0)
	hot.content_margin_left = 4
	for st in ["normal", "pressed", "disabled"]:
		c.add_theme_stylebox_override(st, flat)
	for st in ["hover", "hover_pressed"]:
		c.add_theme_stylebox_override(st, hot)
	c.add_theme_stylebox_override("focus", UITheme.panel_style(Color(0, 0, 0, 0), UITheme.LIME, 2, 0.0))
	c.add_theme_color_override("font_pressed_color", UITheme.TEXT)
	c.add_theme_color_override("font_hover_pressed_color", UITheme.CYAN)
	c.add_theme_color_override("font_focus_color", UITheme.CYAN)


static func wire_button(b: BaseButton) -> void:
	b.mouse_entered.connect(func() -> void:
		if b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus())
	b.pressed.connect(func() -> void: Audio.play_ui("click"))


## Plays the hover sound whenever keyboard/gamepad focus moves. Call once per screen.
static func wire_focus_sounds(root: Control) -> void:
	var vp := root.get_viewport()
	if vp == null:
		return
	var last := {"t": 0}
	vp.gui_focus_changed.connect(func(_c: Control) -> void:
		var now := Time.get_ticks_msec()
		if now - int(last["t"]) > 40:
			Audio.play_ui("hover")
		last["t"] = now)


## Big skewed title like "GARAGE" with a neon underline and an optional subtitle.
static func header(title: String, subtitle: String = "", color: Color = UITheme.CYAN) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var t := UITheme.label(title, "heavy", 44, UITheme.TEXT)
	t.add_theme_color_override("font_shadow_color", Color(color, 0.55))
	t.add_theme_constant_override("shadow_offset_x", 3)
	t.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(t)
	var bar := NeonBar.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(260, 6)
	box.add_child(bar)
	if subtitle != "":
		var s := UITheme.label(subtitle, "body_bold", 20, UITheme.TEXT_DIM)
		box.add_child(s)
	return box


## A small uppercase section caption ("PAINT COLOR").
static func caption(text: String, color: Color = UITheme.CYAN) -> Label:
	var l := UITheme.label(text.to_upper(), "head", 15, color)
	return l


## A panel with the theme's neon border and inner margins.
static func panel(bg: Color = UITheme.PANEL, border: Color = UITheme.CYAN.darkened(0.45), skew: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UITheme.panel_style(bg, border, 1, skew)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	return p


## A row of selectable options (OptionButton-like but all visible): returns the HBox.
## `on_pick(index)` is called when the user picks one. Use `select_chip(row, index)` to reflect state.
static func chip_row(labels: Array, on_pick: Callable, min_w: float = 0.0) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := Button.new()
		b.text = String(labels[i])
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(min_w, 40)
		b.add_theme_font_size_override("font_size", 18)
		var st_n := UITheme.panel_style(UITheme.PANEL, UITheme.CYAN.darkened(0.35), 2)
		var st_h := UITheme.panel_style(UITheme.PANEL_LIGHT, UITheme.CYAN, 2)
		var st_p := UITheme.panel_style(Color(UITheme.CYAN, 0.28), UITheme.CYAN, 2)
		var st_d := UITheme.panel_style(Color(UITheme.PANEL, 0.5), Color(UITheme.TEXT_DIM, 0.3), 2)
		for st in [st_n, st_h, st_p, st_d]:
			st.content_margin_left = 13
			st.content_margin_right = 13
		b.add_theme_stylebox_override("normal", st_n)
		b.add_theme_stylebox_override("hover", st_h)
		b.add_theme_stylebox_override("pressed", st_p)
		b.add_theme_stylebox_override("hover_pressed", st_p)
		b.add_theme_stylebox_override("disabled", st_d)
		b.add_theme_color_override("font_pressed_color", UITheme.TEXT)
		wire_button(b)
		b.pressed.connect(func() -> void: on_pick.call(i))
		row.add_child(b)
	return row


static func select_chip(row: Container, index: int) -> void:
	var i := 0
	for c in row.get_children():
		if c is BaseButton:
			(c as BaseButton).set_pressed_no_signal(i == index)
			i += 1


## A row of color swatches plus a "+" button that opens a ColorPicker popup.
## `on_pick(color_html)` is called with "#rrggbb".
static func swatch_row(colors: Array, on_pick: Callable) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 5)
	row.add_theme_constant_override("v_separation", 5)
	for c in colors:
		var sw := Swatch.new()
		sw.color = Color(String(c))
		sw.pressed.connect(func() -> void:
			Audio.play_ui("click")
			on_pick.call("#" + sw.color.to_html(false)))
		sw.mouse_entered.connect(func() -> void: sw.grab_focus())
		row.add_child(sw)
	var custom := Button.new()
	custom.text = "+"
	custom.tooltip_text = "Custom color"
	custom.custom_minimum_size = Vector2(40, 32)
	custom.add_theme_font_size_override("font_size", 22)
	wire_button(custom)
	var popup := PopupPanel.new()
	var picker := ColorPicker.new()
	picker.edit_alpha = false
	picker.presets_visible = false
	picker.color_modes_visible = false
	picker.sampler_visible = false
	popup.add_child(picker)
	custom.add_child(popup)
	picker.color_changed.connect(func(col: Color) -> void: on_pick.call("#" + col.to_html(false)))
	custom.pressed.connect(func() -> void:
		var cur: Variant = row.get_meta("current", null)
		if cur is Color:
			picker.color = cur
		var r := custom.get_global_rect()
		popup.popup(Rect2i(Vector2i(r.position + Vector2(0, r.size.y + 4)), Vector2i(300, 380))))
	row.add_child(custom)
	return row


## Highlights the swatch matching `html` (and remembers it for the custom picker).
static func select_swatch(row: Container, html: String) -> void:
	var col := Color(html) if Color.html_is_valid(html) else Color.WHITE
	row.set_meta("current", col)
	for c in row.get_children():
		if c is Swatch:
			(c as Swatch).selected = (c as Swatch).color.is_equal_approx(col)


## Horizontal slider with a caption, end labels and a value readout.
## Returns {"root": Control, "slider": HSlider, "value": Label}.
static func slider_row(title: String, left: String, right: String, min_v: float, max_v: float, step: float) -> Dictionary:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	var top := HBoxContainer.new()
	var t := UITheme.label(title, "body_bold", 21, UITheme.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var v := UITheme.label("0", "num", 15, UITheme.CYAN)
	top.add_child(v)
	root.add_child(top)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.custom_minimum_size = Vector2(0, 26)
	s.focus_mode = Control.FOCUS_ALL
	s.mouse_entered.connect(func() -> void: s.grab_focus())
	root.add_child(s)
	if left != "" or right != "":
		var ends := HBoxContainer.new()
		var l := UITheme.label(left, "body", 15, UITheme.TEXT_DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ends.add_child(l)
		ends.add_child(UITheme.label(right, "body", 15, UITheme.TEXT_DIM))
		ends.add_theme_constant_override("separation", 0)
		root.add_child(ends)
	return {"root": root, "slider": s, "value": v}


## Full-screen dark backdrop with an animated neon grid/glow shader (cheap on both renderers).
static func backdrop(tint: Color = UITheme.MAGENTA) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ui/menu/menu_backdrop.gdshader")
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("tint2", UITheme.CYAN)
	r.material = mat
	return r


## Labelled key/value line for info panels.
static func info_line(key: String, value: String, value_color: Color = UITheme.TEXT) -> HBoxContainer:
	var h := HBoxContainer.new()
	var k := UITheme.label(key, "body", 19, UITheme.TEXT_DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	h.add_child(UITheme.label(value, "body_bold", 20, value_color))
	return h


## Plain spacer.
static func spacer(w: float = 0.0, h: float = 0.0, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## The "[ESC] Back  [ENTER] Select" hint strip.
static func key_hints(pairs: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	for p in pairs:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		var k := Label.new()
		k.text = String(p[0])
		k.add_theme_font_override("font", UITheme.font("head"))
		k.add_theme_font_size_override("font_size", 13)
		k.add_theme_color_override("font_color", UITheme.NAVY)
		var sb := StyleBoxFlat.new()
		sb.bg_color = UITheme.CYAN
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		sb.skew = Vector2(UITheme.SKEW, 0)
		k.add_theme_stylebox_override("normal", sb)
		item.add_child(k)
		item.add_child(UITheme.label(String(p[1]), "body_bold", 18, UITheme.TEXT_DIM))
		h.add_child(item)
	return h


## A neon horizontal bar (used under headers).
class NeonBar extends Control:
	var color: Color = UITheme.CYAN

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var sk := h * 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(sk, 0), Vector2(w * 0.7, 0), Vector2(w * 0.7 - sk, h), Vector2(0, h)]), color)
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.72 + sk, 0), Vector2(w * 0.8, 0), Vector2(w * 0.8 - sk, h), Vector2(w * 0.72, h)]), Color(color, 0.6))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.82 + sk, 0), Vector2(w * 0.86, 0), Vector2(w * 0.86 - sk, h), Vector2(w * 0.82, h)]), Color(color, 0.35))


## A clickable color swatch (focusable, keyboard-pressable).
class Swatch extends BaseButton:
	var color: Color = Color.WHITE:
		set(v):
			color = v
			queue_redraw()
	var selected := false:
		set(v):
			selected = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(32, 32)
		focus_mode = Control.FOCUS_ALL
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		draw_rect(r, color)
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.35)), Color(1, 1, 1, 0.12))
		if selected:
			draw_rect(Rect2(Vector2.ZERO, size), UITheme.TEXT, false, 3.0)
		elif has_focus() or is_hovered():
			draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), UITheme.LIME, false, 2.0)
		else:
			draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)
