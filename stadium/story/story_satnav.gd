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
