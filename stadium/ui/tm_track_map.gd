class_name TmTrackMap
extends Control
## A track seen from above (TMNF's cards show each track's thumbnail): our own tracks' line (the
## bot's path), or a .Gbx track's road blocks; the start green, the checkpoints blue, the finish
## red. North (Godot -z) is up.

const ROAD_WORDS := ["Road", "Platform", "Circuit", "Dirt", "Turbo", "Start", "Finish", "Checkpoint", "Loop"]
const DECOR_WORDS := ["Pillar", "Fabric", "Control", "Inflatable", "Sculpt", "Airship", "Tube", "Grass", "Pool", "Water"]

var challenge: TmChallenge
var line_colour := Color(0.95, 0.97, 0.95)
var line_width := 3.0


func _init(ch: TmChallenge = null) -> void:
	challenge = ch
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _cell(coord: Vector3i) -> Vector2:
	return Vector2(-(coord.x * 32.0 + 16.0), coord.z * 32.0 + 16.0)


static func _is_road(block_name: String) -> bool:
	for w: String in DECOR_WORDS:
		if block_name.contains(w):
			return false
	for w: String in ROAD_WORDS:
		if block_name.contains(w):
			return true
	return false


func _draw() -> void:
	if challenge == null or not challenge.ok():
		return
	var pts := PackedVector2Array()
	var cells := PackedVector2Array()
	var cps := PackedVector2Array()
	var start := Vector2.INF
	var finish := Vector2.INF
	for b: Dictionary in challenge.blocks:
		var n := String(b["name"])
		if n.contains("Checkpoint"):
			cps.append(_cell(b["coord"]))
		if n.contains("Start"):
			start = _cell(b["coord"])
		if n.contains("Finish"):
			finish = _cell(b["coord"])
	for pt: Dictionary in challenge.path:
		var p: Vector3 = pt["p"]
		pts.append(Vector2(p.x, p.z))
	if pts.is_empty():
		for b: Dictionary in challenge.blocks:
			if _is_road(String(b["name"])):
				cells.append(_cell(b["coord"]))
	else:
		start = pts[0]
		finish = pts[pts.size() - 1]
	var all := pts + cells + cps
	if all.is_empty():
		return
	var lo := all[0]
	var hi := all[0]
	for p in all:
		lo = lo.min(p)
		hi = hi.max(p)
	if not cells.is_empty():
		lo -= Vector2(16, 16)
		hi += Vector2(16, 16)
	var margin := 8.0
	var span := (hi - lo).max(Vector2(32, 32))
	var k := minf((size.x - 2.0 * margin) / span.x, (size.y - 2.0 * margin) / span.y)
	var off := (size - span * k) * 0.5 - lo * k
	var to := func(p: Vector2) -> Vector2: return p * k + off
	for c in cells:
		var r := Rect2(to.call(c - Vector2(16, 16)), Vector2(32, 32) * k)
		draw_rect(r.grow(-maxf(0.5, k * 2.0)), Color(line_colour, 0.85))
	if pts.size() >= 2:
		var screen := PackedVector2Array()
		for p in pts:
			screen.append(to.call(p))
		draw_polyline(screen, Color(0, 0, 0, 0.55), line_width + 3.0, true)
		draw_polyline(screen, line_colour, line_width, true)
	var dot := maxf(3.5, line_width + 1.5)
	for c in cps:
		_marker(to.call(c), dot, Color(0.25, 0.55, 1.0))
	if finish != Vector2.INF:
		_marker(to.call(finish), dot + 1.0, Color(0.95, 0.22, 0.18))
	if start != Vector2.INF:
		_marker(to.call(start), dot + 1.0, Color(0.35, 0.85, 0.30))


func _marker(at: Vector2, r: float, c: Color) -> void:
	draw_circle(at, r + 1.5, Color(0, 0, 0, 0.6))
	draw_circle(at, r, c)
