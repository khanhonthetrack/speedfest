class_name StorySatnav
extends RefCounted
## Vesper's satnav (docs/STORY.md, the frame): a dark city map, its streets in thin grey, the river
## black, nine violet pins with no route between them (red once their fact is learned), the bridge
## greyed out. One drawing for the cabin's screen in the cutscenes and, later, the Story page's board.
## Deterministic: the same streets every time.

const SIZE := Vector2i(384, 240)
## The nine pins (fractions of the map) and the bridge, laid out round the river.
const PINS := [Vector2(0.18, 0.72), Vector2(0.33, 0.28), Vector2(0.62, 0.58), Vector2(0.78, 0.30), Vector2(0.48, 0.80),
	Vector2(0.56, 0.36), Vector2(0.86, 0.74), Vector2(0.26, 0.46), Vector2(0.70, 0.86)]
const BRIDGE := [Vector2(0.40, 0.52), Vector2(0.52, 0.46)]


## The screen as the cutscenes' cabin shows it (the texture() below is the small drawing): a 2D view
## rendered once, antialiased: dark blocks, streets in two weights, the river black under the bridge,
## the nine pins as glowing drops (no route between them), the car's arrow, a bar with the time and a
## compass, the street it stands in, "NO ROUTE". Its texture is the screen's; add it to the tree.
static func view(red_pins := 0, bridge_open := false) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = "SatnavView"
	vp.size = VIEW
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var root := Control.new()
	root.size = Vector2(VIEW)
	vp.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.056, 0.078)           # the blocks
	bg.size = Vector2(VIEW)
	root.add_child(bg)
	var map := Rect2(0, 56, VIEW.x, VIEW.y - 56)
	var at := func(f: Vector2) -> Vector2: return map.position + f * map.size
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	# the streets: minor ones thin, a few major ones cased, all bent a little
	for i in 26:
		var y := rng.randf_range(0.0, 1.0)
		var x := rng.randf_range(0.0, 1.0)
		var major := i % 6 == 0
		for line in [[Vector2(0.0, y), Vector2(0.5, y + rng.randf_range(-0.06, 0.06)), Vector2(1.0, y + rng.randf_range(-0.12, 0.12))],
				[Vector2(x, 0.0), Vector2(x + rng.randf_range(-0.04, 0.04), 0.5), Vector2(x + rng.randf_range(-0.08, 0.08), 1.0)]]:
			var pts := PackedVector2Array()
			for f: Vector2 in line:
				pts.append(at.call(f))
			if major:
				root.add_child(_stroke(pts, 15.0, Color(0.07, 0.08, 0.11)))
			root.add_child(_stroke(pts, 10.0 if major else 4.5, Color(0.34, 0.36, 0.43) if major else Color(0.15, 0.17, 0.22)))
	# the river, wide and black between lighter banks, under the bridge
	var river := PackedVector2Array()
	for t in 41:
		var u := t / 40.0
		river.append(at.call(Vector2(u, 0.62 - 0.25 * u + 0.06 * sin(u * 6.0))))
	root.add_child(_stroke(river, 66.0, Color(0.08, 0.1, 0.14)))
	root.add_child(_stroke(river, 56.0, Color(0.01, 0.022, 0.05)))
	root.add_child(_stroke(PackedVector2Array([at.call(BRIDGE[0]), at.call(BRIDGE[1])]), 13.0,
		Color(0.55, 0.3, 1.0) if bridge_open else Color(0.3, 0.3, 0.34)))
	# the pins: a drop on a soft glow, a white heart
	for i in PINS.size():
		var c := Color(0.95, 0.2, 0.3) if i < red_pins else Color(0.6, 0.38, 1.0)
		var p: Vector2 = at.call(PINS[i])
		root.add_child(_disc(p + Vector2(0, -14), 30.0, Color(c, 0.16)))
		var drop := _disc(p + Vector2(0, -20), 13.0, c)
		root.add_child(drop)
		var tip := Polygon2D.new()
		tip.polygon = PackedVector2Array([p + Vector2(-10.5, -15), p + Vector2(10.5, -15), p])
		tip.color = c
		tip.antialiased = true
		root.add_child(tip)
		root.add_child(_disc(p + Vector2(0, -20), 4.5, Color(1, 1, 1, 0.95)))
	# the car: an arrow pointing up the screen, a cyan halo round it
	var car: Vector2 = at.call(Vector2(0.5, 0.86))
	root.add_child(_disc(car, 30.0, Color(0.25, 0.85, 1.0, 0.16)))
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([car + Vector2(0, -20), car + Vector2(14, 14), car + Vector2(0, 6), car + Vector2(-14, 14)])
	arrow.color = Color(0.92, 0.98, 1.0)
	arrow.antialiased = true
	root.add_child(arrow)
	# the bar: the time, the compass; the street; no route
	var bar := ColorRect.new()
	bar.color = Color(0.0, 0.0, 0.0, 0.7)
	bar.size = Vector2(VIEW.x, 56)
	root.add_child(bar)
	var time := SfUi.label("06:12", 30, Color(0.95, 0.96, 1.0), SfUi.BOLD)
	time.position = Vector2(22, 8)
	root.add_child(time)
	var north := SfUi.label("N", 26, Color(0.6, 0.38, 1.0), SfUi.BLACK)
	north.position = Vector2(VIEW.x - 46, 10)
	root.add_child(north)
	var street := SfUi.label("HARBOUR ROAD", 24, Color(0.85, 0.88, 0.95), SfUi.SEMI, 3)
	street.position = Vector2(VIEW.x * 0.5 - 110, 12)
	root.add_child(street)
	var none := SfUi.label("NO ROUTE", 20, Color(0.55, 0.58, 0.66), SfUi.BOLD, 4)
	none.position = Vector2(22, VIEW.y - 40)
	root.add_child(none)
	return vp


const VIEW := Vector2i(1024, 640)


static func _stroke(pts: PackedVector2Array, w: float, c: Color) -> Line2D:
	var l := Line2D.new()
	l.points = pts
	l.width = w
	l.default_color = c
	l.antialiased = true
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	return l


static func _disc(at: Vector2, r: float, c: Color) -> Polygon2D:
	var d := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 32:
		pts.append(at + Vector2.from_angle(TAU * k / 32.0) * r)
	d.polygon = pts
	d.color = c
	d.antialiased = true
	return d


static func texture(red_pins := 0, bridge_open := false) -> ImageTexture:
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.03, 0.03, 0.05))
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	# streets: a loose grid, bent a little
	for i in 22:
		var y := rng.randf_range(0.0, SIZE.y)
		_line(img, Vector2(0, y), Vector2(SIZE.x, y + rng.randf_range(-30, 30)), Color(0.16, 0.16, 0.2), 1)
		var x := rng.randf_range(0.0, SIZE.x)
		_line(img, Vector2(x, 0), Vector2(x + rng.randf_range(-30, 30), SIZE.y), Color(0.16, 0.16, 0.2), 1)
	# the river, wide and black, under the bridge
	for t in 60:
		var u := t / 59.0
		var p := Vector2(u * SIZE.x, SIZE.y * (0.62 - 0.25 * u + 0.06 * sin(u * 6.0)))
		img.fill_rect(Rect2i(Vector2i(p) - Vector2i(4, 9), Vector2i(9, 18)), Color(0.0, 0.0, 0.01))
	var bridge_col := Color(0.55, 0.3, 1.0) if bridge_open else Color(0.3, 0.3, 0.34)
	_line(img, BRIDGE[0] * Vector2(SIZE), BRIDGE[1] * Vector2(SIZE), bridge_col, 3)
	for i in PINS.size():
		var c := Color(0.95, 0.2, 0.3) if i < red_pins else Color(0.55, 0.35, 1.0)
		var p := Vector2i(PINS[i] * Vector2(SIZE))
		img.fill_rect(Rect2i(p - Vector2i(4, 4), Vector2i(9, 9)), c)
		img.fill_rect(Rect2i(p - Vector2i(1, 9), Vector2i(3, 6)), c)
	return ImageTexture.create_from_image(img)


static func _line(img: Image, a: Vector2, b: Vector2, c: Color, w: int) -> void:
	var n := int(a.distance_to(b))
	for i in n + 1:
		var p := Vector2i(a.lerp(b, float(i) / maxf(n, 1)))
		for dx in range(-w / 2, w / 2 + 1):
			for dy in range(-w / 2, w / 2 + 1):
				var q := p + Vector2i(dx, dy)
				if q.x >= 0 and q.y >= 0 and q.x < SIZE.x and q.y < SIZE.y:
					img.set_pixelv(q, c)
