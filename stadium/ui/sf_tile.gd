class_name SfTile
extends Button
## A picture panel of the home page (PLAN M16, after RaceRoom's DRIVE page the owner pointed to): a
## picture filling the panel (cropped to its shape round `focus`), darker towards the bottom, the
## title in heavy capitals and a spaced line under it at the bottom left. Hovered or focused: the
## picture leans in, a white frame, a red-to-violet line under the title. Locked (Story): the
## picture greyed and dark, a padlock and COMING SOON; a press only shakes it.

signal locked_pressed

const LOCKED_SHADER := """shader_type canvas_item;
uniform float saturation = 0.12;
uniform float brightness = 0.5;
void fragment() {
	float l = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(vec3(l), COLOR.rgb, saturation) * brightness;
}
"""

var title := ""
var subtitle := ""
var info := ""                       ## a line at the bottom right (Solo: your campaign)
var picture: Texture2D
var focus_point := Vector2(0.5, 0.5) ## where the crop keeps the picture (0-1 of its width and height)
var big := false
var locked := false
var badge := ""                      ## a chip at the top left (locked: COMING SOON)

var _zoom := 1.0:
	set(v):
		_zoom = v
		queue_redraw()
var _hot := 0.0:
	set(v):
		_hot = v
		queue_redraw()
		if is_instance_valid(_line):
			_line.custom_minimum_size.x = 76.0 * v
			_line.modulate.a = v
var _line: TextureRect
var _shade: GradientTexture2D
var _tween: Tween


func _init(t: String, sub: String, pic: String, is_big := false) -> void:
	title = t
	subtitle = sub
	big = is_big
	var path := "res://assets/ui/menu/%s.jpg" % pic
	picture = load(path) if ResourceLoader.exists(path) else null
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var none := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(s, none)


func _ready() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.02, 0.03, 0.55), Color(0.02, 0.02, 0.03, 0.92)])
	_shade = GradientTexture2D.new()
	_shade.gradient = g
	_shade.fill_from = Vector2(0, 0)
	_shade.fill_to = Vector2(0, 1)
	_shade.width = 4
	_shade.height = 128
	if locked:
		var m := ShaderMaterial.new()
		m.shader = Shader.new()
		m.shader.code = LOCKED_SHADER
		material = m
	var margin := 34.0 if big else 24.0
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 6 if big else 4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE)
	text.grow_vertical = Control.GROW_DIRECTION_BEGIN
	text.offset_left = margin
	text.offset_bottom = -margin + 4.0
	add_child(text)
	var t := SfUi.label(title, 40 if big else 25, SfUi.TEXT if not locked else Color(SfUi.TEXT, 0.7), SfUi.BLACK, 0, true)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	t.add_theme_constant_override("shadow_offset_y", 2)
	t.add_theme_constant_override("shadow_outline_size", 6)
	text.add_child(t)
	text.add_child(SfUi.label(subtitle, 13 if big else 11, Color(1, 1, 1, 0.78 if not locked else 0.55), SfUi.BOLD, 2, true))
	_line = SfUi.accent_line(3.0, 0.0)
	_line.modulate.a = 0.0
	var holder := Control.new()            # keeps the line's height when it is 0 wide
	holder.custom_minimum_size = Vector2(0, 7)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_line)
	_line.position.y = 4
	_line.size = Vector2(0, 3)
	_line.resized.connect(func() -> void: _line.size.y = 3)
	text.add_child(holder)
	if not info.is_empty():
		var i := SfUi.caption(info, 12, Color(1, 1, 1, 0.7))
		i.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE)
		i.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		i.grow_vertical = Control.GROW_DIRECTION_BEGIN
		i.offset_right = -margin
		i.offset_bottom = -margin + 2.0
		add_child(i)
	if not badge.is_empty():
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", SfUi.box("chip_violet" if locked else "chip"))
		chip.position = Vector2(margin - 6.0, margin - 10.0)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(SfUi.caption(badge, 11, SfUi.TEXT))
		add_child(chip)
	if locked:
		var lock := SfHeader.Glyph.new("lock", "")
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.focus_mode = Control.FOCUS_NONE
		lock.colour = Color(1, 1, 1, 0.85)
		lock.scale = Vector2(1.6, 1.6)
		lock.custom_minimum_size = Vector2(24, 24)
		lock.size = Vector2(24, 24)
		lock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
		lock.position = Vector2(size.x - margin - 34.0, margin - 12.0)
		resized.connect(func() -> void: lock.position = Vector2(size.x - margin - 34.0, margin - 12.0))
		add_child(lock)
	mouse_entered.connect(grab_focus)
	focus_entered.connect(_light.bind(true))
	focus_exited.connect(_light.bind(false))
	mouse_entered.connect(TmUi.play.bind("move"))
	pressed.connect(_on_press)


func _light(on: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_zoom", (1.025 if locked else 1.05) if on else 1.0, 0.45)
	_tween.tween_property(self, "_hot", 1.0 if on else 0.0, 0.22)


func _on_press() -> void:
	if not locked:
		TmUi.play("click")
		return
	locked_pressed.emit()
	var x := position.x
	var tw := create_tween()
	for d: float in [7.0, -6.0, 4.0, -2.0, 0.0]:
		tw.tween_property(self, "position:x", x + d, 0.045)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if picture != null:
		var ts := picture.get_size()
		var s := maxf(size.x / ts.x, size.y / ts.y) * _zoom
		var src := size / s
		var at := (ts - src) * focus_point
		draw_texture_rect_region(picture, r, Rect2(at, src))
	else:
		draw_rect(r, SfUi.PANEL_HI)
	draw_texture_rect(_shade, Rect2(0, size.y * 0.3, size.x, size.y * 0.7), false)
	draw_rect(r, Color(1, 1, 1, 0.08), false, 1.0)
	if _hot > 0.0:
		draw_rect(r.grow(-1.0), Color(1, 1, 1, 0.9 * _hot), false, 2.0)
