extends Node
## The adverts on the remake's screens and LED boards (autoload "Adverts"): a strip of our own
## fictional ads (no real brands), drawn once with the UI fonts in a SubViewport and kept as a
## mipmapped texture that the surface shader's screen pattern scrolls (blocks/tm_surface.gdshader
## pattern 8; TmMaterials hands it to every screen material). texture() is valid from the start
## (blank until the first frame is drawn, then updated in place).

const PANEL := Vector2i(512, 256)
## [headline, sub line, text colour, background top, background bottom, chequered]
const ADS := [
	["SPEEDFEST", "STADIUM", Color(1, 1, 1), Color(0.85, 0.08, 0.06), Color(0.35, 0.02, 0.02), false],
	["TIME ATTACK", "BEAT THE AUTHOR", Color(0.35, 0.9, 1.0), Color(0.03, 0.08, 0.22), Color(0.01, 0.02, 0.07), false],
	["GO FAST", "", Color(1, 1, 1), Color(0.02, 0.02, 0.02), Color(0.02, 0.02, 0.02), true],
	["TRAP RADIO", "24/7 BEATS", Color(1.0, 0.45, 0.95), Color(0.16, 0.03, 0.22), Color(0.04, 0.0, 0.07), false],
	["NITROX", "ENERGY DRINK", Color(0.1, 0.1, 0.1), Color(1.0, 0.78, 0.1), Color(0.95, 0.45, 0.05), false],
	["TURBO >>>", "", Color(1.0, 0.85, 0.15), Color(0.06, 0.06, 0.07), Color(0.01, 0.01, 0.01), false],
	["GRIPLINE", "RACE TYRES", Color(1, 1, 1), Color(0.05, 0.45, 0.2), Color(0.01, 0.15, 0.06), false],
	["SF", "SPEEDFEST", Color(0.25, 0.82, 1.0), Color(0.02, 0.03, 0.06), Color(0.0, 0.0, 0.0), false],
]

var _texture := ImageTexture.new()
var _viewport: SubViewport


func _ready() -> void:
	var blank := Image.create(PANEL.x * ADS.size(), PANEL.y, true, Image.FORMAT_RGBA8)
	blank.fill(Color(0.02, 0.04, 0.1))
	_texture.set_image(blank)
	if DisplayServer.get_name() == "headless":
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(PANEL.x * ADS.size(), PANEL.y)
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	for i in ADS.size():
		_viewport.add_child(_panel(ADS[i], i))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image()
	if img and not img.is_empty():
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		_texture.set_image(img)
	_viewport.queue_free()


## The adverts' texture (one ad per PANEL, side by side).
func texture() -> Texture2D:
	return _texture


func _panel(ad: Array, i: int) -> Control:
	var root := Control.new()
	root.position = Vector2(i * PANEL.x, 0)
	root.size = PANEL
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, ad[3])
	g.set_color(1, ad[4])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 64
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = PANEL
	root.add_child(bg)
	if bool(ad[5]):
		# a chequered board
		var cell := 32
		for x in PANEL.x / cell:
			for y in PANEL.y / cell:
				if (x + y) % 2 == 0:
					var c := ColorRect.new()
					c.color = Color(0.95, 0.95, 0.95)
					c.position = Vector2(x * cell, y * cell)
					c.size = Vector2(cell, cell)
					root.add_child(c)
		var band := ColorRect.new()
		band.color = Color(0.02, 0.02, 0.03)
		band.position = Vector2(0, 80)
		band.size = Vector2(PANEL.x, 96)
		root.add_child(band)
	var head := Label.new()
	head.text = String(ad[0])
	head.add_theme_font_override("font", TmUi.font(TmUi.TITLE))
	head.add_theme_font_size_override("font_size", 92 if String(ad[0]).length() <= 8 else 70)
	head.add_theme_color_override("font_color", ad[2])
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.position = Vector2(0, 30 if not String(ad[1]).is_empty() else 64)
	head.size = Vector2(PANEL.x, 128)
	root.add_child(head)
	if not String(ad[1]).is_empty():
		var sub := Label.new()
		sub.text = String(ad[1])
		sub.add_theme_font_override("font", TmUi.font(TmUi.HEAD, 6))
		sub.add_theme_font_size_override("font_size", 34)
		sub.add_theme_color_override("font_color", Color(ad[2], 0.85))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.position = Vector2(0, 160)
		sub.size = Vector2(PANEL.x, 60)
		root.add_child(sub)
	return root
