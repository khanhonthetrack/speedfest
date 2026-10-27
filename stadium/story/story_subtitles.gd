class_name StorySubtitles
extends CanvasLayer
## A cutscene's 2D layer (PLAN M20-3), in the menus' look (SfUi: charcoal, red and violet,
## Montserrat): cinema bars (2.39:1), the subtitle (the speaker's name in the accent colour over
## the line), a fade to and from black, title cards ("NIGHT 3", the place; centred, or "align":
## "left": low in the left third over an establishing shot), a phone's message
## thread (texts arriving, the shot grammar's faceless way to speak), and the skip hint: hold a key
## and the bar fills; under them the film finish (docs/CINEMATICS.md: grain, vignette, halation, a lens's
## distortion and fringing, the grade; and rain on the windscreen). Driven by StoryScene each frame
## (show(t)); holds no time of its own.

const ASPECT := 2.39               ## the bars' picture: CinemaScope
const SKIP_HOLD := 0.8             ## seconds a key is held to skip
const FILM_FPS := 24.0             ## the grain changes this often (film's rate), whatever the game's

var _bars: Array[ColorRect] = []
var _black: ColorRect
var _sub: VBoxContainer
var _speaker: Label
var _text: Label
var _card: VBoxContainer
var _card_title: Label
var _card_sub: Label
var _phone: PanelContainer
var _phone_who: Label
var _phone_list: VBoxContainer
var _skip: HBoxContainer
var _skip_bar: ProgressBar
var _mirror_frame: PanelContainer  ## the rear-view mirror: its housing and its flipped picture
var _mirror: TextureRect
var _mirror_rect := Rect2()
var _flash: ColorRect
var _cctv: ColorRect               ## a security camera's picture (a shot's "cctv"): grey, grain, lines
var _cctv_label: Label
var _cctv_clock: Label
const CCTV := """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float time = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + time * 37.0) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += (hash(vec2(floor(uv.y * 90.0), 1.0)) - 0.5) * 0.002;
	vec3 c = textureLod(screen, uv, 1.2).rgb;
	float g = dot(c, vec3(0.3, 0.59, 0.11)) * 1.5;
	g += (hash(uv * 900.0) - 0.5) * 0.14;
	g *= 0.82 + 0.18 * sin(uv.y * 900.0);
	vec2 q = uv - 0.5;
	g *= 1.0 - dot(q, q) * 1.3;
	COLOR = vec4(vec3(g * 0.92, g, g * 0.95), 1.0);
}
"""
const FILM := """shader_type canvas_item;
// the film finish over a cutscene's picture (docs/CINEMATICS.md), one read of the screen: rain on the
// windscreen (drops that bend the picture and slide down, the glass between them a little soft), a
// slight barrel distortion with colour fringing towards the corners, halation round bright light, a
// streak on headlights, the grade (saturation, contrast, split toning, highlights that roll off,
// lifted blacks), a vignette over the picture between the bars, and grain seeded by the frame (a
// render comes out the same every time)
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float glass = 0.0;
uniform float time = 0.0;
uniform int frame = 0;
uniform float bars = 0.0;          // a bar's height, a fraction of the screen's
uniform float lift = 0.0;
uniform vec4 shadows = vec4(0.5, 0.5, 0.5, 0.0);     // a tint for the darks, its amount in alpha
uniform vec4 highlights = vec4(0.5, 0.5, 0.5, 0.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float knee = 1.0;          // highlights over it roll off
uniform float grain = 0.0;
uniform float vignette = 0.0;
uniform float halation = 0.0;
uniform float streak = 0.0;
uniform float fringe = 0.0;        // px at the picture's corners
uniform float barrel = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 drops(vec2 uv, float scale, float speed) {
	vec2 g = uv * scale;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	float y = fract(h * 7.0 - time * speed * (0.3 + h)) - 0.5;
	vec2 d = f - vec2((h - 0.5) * 0.6, -y);
	float r = 0.1 + 0.12 * h;
	float m = smoothstep(r, r * 0.55, length(d * vec2(1.0, 0.75))) * step(0.35, h);
	return d * m;
}
float noise(uvec3 p) {
	uint h = p.x * 1664525u + p.y * 1013904223u + p.z * 2654435761u;
	h ^= h >> 16u;
	h *= 2246822519u;
	h ^= h >> 13u;
	h *= 3266489917u;
	h ^= h >> 16u;
	return float(h) / 4294967295.0;
}
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 bright(vec3 c, float from) { return max(c - from, vec3(0.0)) / (1.0 - from); }
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 q = SCREEN_UV - 0.5;
	vec2 p = q / px;                                   // pixels from the centre
	vec2 corner = vec2(0.5 / px.x, (0.5 - bars) / px.y);
	float r2 = dot(p, p) / dot(corner, corner);        // 1 at the picture's corners
	vec2 uv = 0.5 + q * (1.0 + barrel * r2) / (1.0 + barrel);
	vec2 off = p / length(corner) * r2 * fringe * px;
	float lod = 0.0;
	float drop = 0.0;
	if (glass > 0.001) {
		vec2 a = SCREEN_UV * vec2(1.7, 1.0);
		vec2 o = drops(a, 8.0, 0.22) * 0.7 + drops(a + 0.37, 15.0, 0.35) * 0.4 + drops(a + 0.71, 26.0, 0.0) * 0.3;
		float l = length(o);
		uv += o * 0.12 * glass;
		lod = mix(1.6, 0.0, smoothstep(0.0, 0.05, l)) * glass;
		drop = smoothstep(0.02, 0.06, l) * glass;
	}
	vec3 c = vec3(textureLod(screen, uv + off, lod).r, textureLod(screen, uv, lod).g, textureLod(screen, uv - off, lod).b);
	if (halation > 0.0) {
		vec3 h = bright(textureLod(screen, uv, 3.0).rgb, 0.55) * 0.6 + bright(textureLod(screen, uv, 5.0).rgb, 0.5) * 0.4;
		c += h * vec3(1.0, 0.42, 0.22) * halation;
	}
	if (streak > 0.0) {
		float st = 0.0;
		for (int i = 1; i <= 8; i++) {
			vec2 o = vec2(float(i) * 0.011, 0.0);
			float w = pow(1.0 - float(i) / 9.0, 2.0);
			st += luma(bright(textureLod(screen, uv + o, 1.5).rgb, 0.8) + bright(textureLod(screen, uv - o, 1.5).rgb, 0.8)) * w;
		}
		c += st * vec3(0.55, 0.72, 1.0) * streak * 0.25;
	}
	float l = luma(c);
	c = max((mix(vec3(l), c, saturation) - 0.45) * contrast + 0.45, vec3(0.0));
	l = clamp(luma(c), 0.0, 1.0);
	c += (shadows.rgb - luma(shadows.rgb)) * shadows.a * (1.0 - l) * (1.0 - l);
	c += (highlights.rgb - luma(highlights.rgb)) * highlights.a * l * l;
	c = max(c + vec3(0.02, 0.025, 0.03) * drop, vec3(0.0));
	if (knee < 1.0) {
		c = min(c, vec3(knee)) + (1.0 - knee) * (1.0 - exp(-max(c - knee, vec3(0.0)) / (1.0 - knee)));
	}
	c *= 1.0 - vignette * smoothstep(0.45, 1.45, length(q / vec2(0.5, 0.5 - bars)));
	c = lift + c * (1.0 - lift);
	l = luma(c);
	c += (noise(uvec3(uvec2(FRAGCOORD.xy), uint(frame))) - 0.5) * grain * (0.6 + 1.6 * l * (1.0 - l));
	COLOR = vec4(c, 1.0);
}
"""
## The film finish's looks (a scene's or a shot's "grade": a name, or {"preset": a name, and any key
## below over it}). "film" is every scene's unless it says otherwise; "none" is the bare picture.
const GRADES := {
	"none": {"lift": 0.0, "shadows": "#808080", "shadows_amount": 0.0, "highlights": "#808080",
		"highlights_amount": 0.0, "saturation": 1.0, "contrast": 1.0, "knee": 1.0, "grain": 0.0,
		"vignette": 0.0, "halation": 0.0, "streak": 0.0, "fringe": 0.0, "barrel": 0.0},
	"film": {"lift": 0.02, "knee": 0.85, "grain": 0.025, "vignette": 0.25, "halation": 0.1,
		"fringe": 0.8, "barrel": 0.03},
	"night": {"lift": 0.02, "knee": 0.85, "grain": 0.025, "vignette": 0.3, "halation": 0.14,
		"streak": 0.25, "fringe": 0.8, "barrel": 0.03, "saturation": 0.95, "contrast": 1.06,
		"shadows": "#24608a", "shadows_amount": 0.2, "highlights": "#ffa25a", "highlights_amount": 0.25},
	"dawn": {"lift": 0.025, "knee": 0.85, "grain": 0.025, "vignette": 0.25, "halation": 0.08,
		"fringe": 0.8, "barrel": 0.03, "saturation": 0.85, "contrast": 1.04,
		"shadows": "#3a5a9a", "shadows_amount": 0.22, "highlights": "#ffc9a0", "highlights_amount": 0.15},
	"dream": {"lift": 0.04, "knee": 0.8, "grain": 0.035, "vignette": 0.35, "halation": 0.3,
		"fringe": 1.2, "barrel": 0.04, "saturation": 0.7, "contrast": 0.95,
		"shadows": "#4a3a7a", "shadows_amount": 0.25, "highlights": "#e8d8ff", "highlights_amount": 0.15},
}
var _film: ColorRect               ## the film finish and rain on the windscreen (a shot's "grade", "glass")
var _film_on := false              ## a grade other than "none"
var _glass_amount := 0.0
var bars := 1.0                    ## 0..1: how far in the bars are


func _ready() -> void:
	layer = 20
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_mirror_frame = PanelContainer.new()
	var mb := StyleBoxFlat.new()
	mb.bg_color = Color(0.01, 0.01, 0.012)
	mb.set_corner_radius_all(18)
	mb.set_content_margin_all(7)
	mb.shadow_color = Color(0, 0, 0, 0.6)
	mb.shadow_size = 18
	_mirror_frame.add_theme_stylebox_override("panel", mb)
	_mirror_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mirror = TextureRect.new()
	_mirror.flip_h = true                 # a mirror: left and right swapped
	_mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mirror.stretch_mode = TextureRect.STRETCH_SCALE
	_mirror_frame.add_child(_mirror)
	_mirror_frame.visible = false
	root.add_child(_mirror_frame)
	root.move_child(_mirror_frame, 0)
	# the film finish after the mirror (graded with the picture), before the security camera's (its
	# own picture) and everything drawn on top: bars, subtitles, cards, the fade and the flash
	_film = ColorRect.new()
	_film.set_anchors_preset(Control.PRESET_FULL_RECT)
	_film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = Shader.new()
	fm.shader.code = FILM
	_film.material = fm
	_film.visible = false
	root.add_child(_film)
	root.move_child(_film, 1)
	_cctv = ColorRect.new()
	_cctv.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cctv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := ShaderMaterial.new()
	cm.shader = Shader.new()
	cm.shader.code = CCTV
	_cctv.material = cm
	_cctv.visible = false
	root.add_child(_cctv)
	root.move_child(_cctv, 2)
	_cctv_label = SfUi.label("", 20, Color(0.85, 0.9, 0.85), SfUi.BOLD, 2, true)
	_cctv_clock = SfUi.label("", 20, Color(0.85, 0.9, 0.85), SfUi.BOLD, 2)
	for l: Label in [_cctv_label, _cctv_clock]:
		l.visible = false
		root.add_child(l)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	for top in [true, false]:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(b)
		_bars.append(b)
	# the subtitle: low in the picture, over the bottom bar's edge
	_sub = VBoxContainer.new()
	_sub.alignment = BoxContainer.ALIGNMENT_END
	_sub.add_theme_constant_override("separation", 2)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_sub)
	_speaker = SfUi.label("", 20, SfUi.HOT, SfUi.BLACK, 3, true)
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_child(_speaker)
	_text = SfUi.label("", 30, SfUi.TEXT, SfUi.SEMI)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l: Label in [_speaker, _text]:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_constant_override("shadow_outline_size", 8)
	_sub.add_child(_text)
	# a title card: centred, the accent line under it
	_card = VBoxContainer.new()
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_theme_constant_override("separation", 10)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_card)
	_card_title = SfUi.label("", 64, SfUi.TEXT, SfUi.WORDMARK, 6, true)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_card_title)
	var line := SfUi.accent_line(3.0, 220.0)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card.add_child(line)
	_card_sub = SfUi.label("", 22, SfUi.DIM, SfUi.BOLD, 4, true)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_card_sub)
	_card.visible = false
	# a phone: a dark rounded panel at the right with a message thread
	_phone = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.045, 0.92)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 20
	sb.content_margin_bottom = 26
	_phone.add_theme_stylebox_override("panel", sb)
	_phone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_phone)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_phone.add_child(col)
	_phone_who = SfUi.label("", 18, SfUi.TEXT, SfUi.BOLD, 1)
	_phone_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_phone_who)
	col.add_child(SfUi.accent_line(1.0))
	_phone_list = VBoxContainer.new()
	_phone_list.add_theme_constant_override("separation", 8)
	_phone_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_phone_list.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(_phone_list)
	_phone.visible = false
	root.add_child(_black)
	root.move_child(_black, _sub.get_index())    # under the subtitles, cards and texts: a black shot still reads
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	root.add_child(_flash)
	# skip: bottom right, under the picture
	_skip = HBoxContainer.new()
	_skip.add_theme_constant_override("separation", 10)
	_skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_skip)
	_skip.add_child(SfUi.caption("Hold Space to skip", 13, SfUi.DIM))
	_skip_bar = ProgressBar.new()
	_skip_bar.show_percentage = false
	_skip_bar.custom_minimum_size = Vector2(90, 4)
	_skip_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = SfUi.RED
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.15)
	_skip_bar.add_theme_stylebox_override("fill", fill)
	_skip_bar.add_theme_stylebox_override("background", bg)
	_skip_bar.max_value = 1.0
	_skip.add_child(_skip_bar)
	_skip.modulate.a = 0.0
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var h := maxf(0.0, (vs.y - vs.x / ASPECT) * 0.5) * bars
	_bars[0].position = Vector2.ZERO
	_bars[0].size = Vector2(vs.x, h)
	_bars[1].position = Vector2(0.0, vs.y - h)
	_bars[1].size = Vector2(vs.x, h)
	var w := minf(vs.x * 0.72, 1180.0)
	_sub.position = Vector2((vs.x - w) * 0.5, vs.y - maxf(h, vs.y * 0.08) - 150.0 + 40.0)
	_sub.size = Vector2(w, 150.0 - 40.0 + h * 0.0)
	_phone.size = Vector2(360, 520)
	_phone.position = Vector2(vs.x * 0.68, (vs.y - 520.0) * 0.5)
	_skip.position = Vector2(vs.x - 290.0, vs.y - 34.0)
	if _mirror_frame != null:
		_mirror_frame.position = _mirror_rect.position * vs
		_mirror_frame.size = _mirror_rect.size * vs
	if _film != null:
		(_film.material as ShaderMaterial).set_shader_parameter("bars", h / maxf(vs.y, 1.0))
	if _cctv_label != null:
		var top := maxf(0.0, (vs.y - vs.x / ASPECT) * 0.5) * bars + 18.0
		_cctv_label.position = Vector2(40.0, top)
		_cctv_clock.position = Vector2(vs.x - 260.0, top)


## What shows at this moment: line ({speaker, text} or {}), fade (0 clear .. 1 black), card
## ({title, subtitle} or {}), phone ({from, messages: [{text, mine}]} with the ones arrived), skip
## (0..1 how far the key has been held).
func show_state(line: Dictionary, fade: float, card: Dictionary, phone: Dictionary, skip: float, bars_in := 1.0) -> void:
	if not is_equal_approx(bars, bars_in):
		bars = bars_in
		_layout()
	_speaker.text = String(line.get("speaker", "")).to_upper()
	_speaker.visible = not _speaker.text.is_empty()
	_text.text = String(line.get("text", ""))
	_sub.visible = not _text.text.is_empty()
	_black.modulate.a = clampf(fade, 0.0, 1.0)
	_card.visible = not card.is_empty()
	if _card.visible:
		_card_title.text = String(card.get("title", "")).to_upper()
		_card_sub.text = String(card.get("subtitle", "")).to_upper()
		_card.modulate.a = float(card.get("alpha", 1.0))
		# "align": "left": low in the left third, over the picture (a title over an establishing shot)
		var left := String(card.get("align", "")) == "left"
		var vs := get_viewport().get_visible_rect().size
		_card.alignment = BoxContainer.ALIGNMENT_END if left else BoxContainer.ALIGNMENT_CENTER
		_card.position = Vector2(vs.x * 0.08, 0.0) if left else Vector2.ZERO
		_card.size = Vector2(vs.x * 0.4, vs.y * 0.72) if left else vs
		for l: Label in [_card_title, _card_sub]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_CENTER
		(_card.get_child(1) as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if left else Control.SIZE_SHRINK_CENTER
	_phone.visible = not phone.is_empty()
	if _phone.visible:
		_phone_who.text = String(phone.get("from", ""))
		var msgs: Array = phone.get("messages", [])
		while _phone_list.get_child_count() > msgs.size():
			var c := _phone_list.get_child(_phone_list.get_child_count() - 1)
			_phone_list.remove_child(c)
			c.free()
		for i in msgs.size():
			var m: Dictionary = msgs[i]
			if i >= _phone_list.get_child_count():
				_phone_list.add_child(_bubble())
			var b := _phone_list.get_child(i) as PanelContainer
			var mine := bool(m.get("mine", false))
			var l := b.get_child(0) as Label
			l.text = String(m.get("text", ""))
			# wrap at the thread's width, not at the bubble's narrowest
			var w := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			l.custom_minimum_size = Vector2(minf(w + 2.0, 236.0), 0.0)
			b.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
			(b.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(SfUi.VIOLET, 0.85) if mine else Color(1, 1, 1, 0.1)
	_skip.modulate.a = 1.0 if skip > 0.0 else 0.0
	_skip_bar.value = skip


func _bubble() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var l := SfUi.label("", 17, SfUi.TEXT, SfUi.MEDIUM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(0, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(120, 0)
	p.add_child(l)
	return p


## Rain on the windscreen (0: none), its drops and the film's grain moving with the scene's time.
func set_glass(amount: float, time: float) -> void:
	_glass_amount = amount if amount > 0.001 else 0.0
	var m := _film.material as ShaderMaterial
	m.set_shader_parameter("glass", _glass_amount)
	m.set_shader_parameter("time", time)
	m.set_shader_parameter("frame", int(floor(time * FILM_FPS)))
	_show_film()


## The film finish's look (`grade_of`'s result: every key of GRADES' "none"); "none"'s turns it off.
func set_grade(g: Dictionary) -> void:
	var full: Dictionary = GRADES["none"].duplicate()
	full.merge(g, true)
	_film_on = false
	for k: String in full:
		if full[k] != GRADES["none"][k]:
			_film_on = true
	var m := _film.material as ShaderMaterial
	for k: String in ["lift", "saturation", "contrast", "knee", "grain", "vignette", "halation", "streak", "fringe", "barrel"]:
		m.set_shader_parameter(k, float(full[k]))
	for k: String in ["shadows", "highlights"]:
		var c := Color(String(full[k]))
		m.set_shader_parameter(k, Vector4(c.r, c.g, c.b, float(full[k + "_amount"])))
	_show_film()


func _show_film() -> void:
	_film.visible = (_film_on or _glass_amount > 0.0) and not _cctv.visible


## A shot's look: the scene's "grade" with the shot's over it, each a preset's name or {"preset",
## keys over it}; "film" where neither names a preset. An unknown name warns and stays "film".
static func grade_of(scene_grade: Variant, shot_grade: Variant) -> Dictionary:
	var out: Dictionary = GRADES["none"].duplicate()
	out.merge(GRADES["film"], true)
	for g: Variant in [scene_grade, shot_grade]:
		var d: Dictionary = {"preset": g} if g is String else (g as Dictionary if g is Dictionary else {})
		if d.has("preset"):
			var preset := String(d["preset"])
			if not GRADES.has(preset):
				push_warning("story: no grade \"%s\" (%s)" % [preset, ", ".join(GRADES.keys())])
				preset = "film"
			out = GRADES["none"].duplicate()
			out.merge(GRADES[preset], true)
		for k: String in d:
			if k != "preset":
				out[k] = d[k]
	return out


## The rear-view mirror's picture in its housing at `rect` (fractions of the screen); null hides it.
func show_mirror(tex: Texture2D, rect: Rect2) -> void:
	_mirror_frame.visible = tex != null
	_mirror.texture = tex
	_mirror_rect = rect
	_layout()


## A white frame (0..1).
func set_flash(a: float) -> void:
	_flash.modulate.a = clampf(a, 0.0, 1.0)


## A security camera's picture: grey, grainy, its label and a running clock ({} hides it).
func set_cctv(c: Dictionary, local: float, time: float) -> void:
	var on := not c.is_empty()
	_cctv.visible = on
	_cctv_label.visible = on
	_cctv_clock.visible = on
	_show_film()
	if not on:
		return
	(_cctv.material as ShaderMaterial).set_shader_parameter("time", time)
	_cctv_label.text = String(c.get("label", "CAM 1"))
	var hms := String(c.get("clock", "00:00:00")).split(":")
	var secs := int(hms[0]) * 3600 + int(hms[1]) * 60 + int(hms[2]) + int(local) if hms.size() == 3 else int(local)
	_cctv_clock.text = "%02d:%02d:%02d" % [(secs / 3600) % 24, (secs / 60) % 60, secs % 60]

