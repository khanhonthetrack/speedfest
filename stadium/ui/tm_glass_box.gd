@tool
class_name TmGlassBox
extends StyleBox
## The menus' glass (our own, in the spirit of TMNF's glossy panels and buttons): a rounded box
## filled with a vertical gradient, a gloss band fading down from its top edge, an antialiased
## border brighter along the top, and an optional soft glow around it (focus). Drawn as vectors, so
## it stays sharp at any resolution. Corners can be rounded selectively (tabs: the top ones only).

@export var top := Color(0.10, 0.16, 0.13, 0.82)
@export var bottom := Color(0.03, 0.06, 0.05, 0.88)
@export var gloss := 0.12                         ## the gloss band's alpha at the top
@export var gloss_depth := 0.48                   ## how far down the band reaches (fraction of the height)
@export var border := Color(1, 1, 1, 0.16)
@export var border_top := Color(1, 1, 1, 0.38)    ## the border's colour along the top edge
@export var border_width := 1.5
@export var radius := 10.0
@export var corners := 15                         ## bit mask: 1 top left, 2 top right, 4 bottom right, 8 bottom left
@export var glow := Color(0, 0, 0, 0)
@export var glow_size := 0.0
@export var stripe := Color(0, 0, 0, 0)           ## a bar along the left edge (the selected entry)
@export var stripe_width := 0.0

const ARC := 6   ## segments per rounded corner


func _init() -> void:
	content_margin_left = 18
	content_margin_right = 18
	content_margin_top = 8
	content_margin_bottom = 8


## A copy with some properties changed: TmGlassBox.make({...}).
static func make(props: Dictionary) -> TmGlassBox:
	var b := TmGlassBox.new()
	for k: String in props:
		b.set(k, props[k])
	return b


## The outline of a rounded box, clockwise from the top left corner's start.
func outline(rect: Rect2, grow := 0.0) -> PackedVector2Array:
	var r := rect.grow(grow)
	var rad := minf(radius + grow, minf(r.size.x, r.size.y) * 0.5)
	rad = maxf(rad, 0.0)
	var pts := PackedVector2Array()
	var centres := [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad),
		r.end - Vector2(rad, rad), Vector2(r.position.x + rad, r.end.y - rad)]
	var raw := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if corners & (1 << i) == 0 or rad <= 0.5:
			pts.append(raw[i])
			continue
		var a0 := PI + i * PI * 0.5
		for s in ARC + 1:
			var a := a0 + PI * 0.5 * s / ARC
			pts.append(centres[i] + Vector2(cos(a), sin(a)) * rad)
	return pts


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	if glow.a > 0.0 and glow_size > 0.0:
		var steps := 4
		for k in steps:
			var g := glow_size * (k + 1) / steps
			var c := glow
			c.a *= 0.42 * (1.0 - float(k) / steps)
			var ring := outline(rect, g)
			ring.append(ring[0])
			rs.canvas_item_add_polyline(to_canvas_item, ring, PackedColorArray([c]), glow_size / steps + 1.0, true)
	var pts := outline(rect)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)))
	rs.canvas_item_add_polygon(to_canvas_item, pts, cols)
	if gloss > 0.0:
		# the outline's points above the band's depth run from the top left corner round to the
		# top right one; a straight bottom edge at the depth closes the band
		var depth := rect.position.y + rect.size.y * gloss_depth
		var band := PackedVector2Array()
		for p in outline(rect, -border_width):
			if p.y <= depth:
				band.append(p)
		band.append(Vector2(rect.end.x - border_width, depth))
		band.append(Vector2(rect.position.x + border_width, depth))
		var gc := PackedColorArray()
		for p in band:
			var t := clampf((p.y - rect.position.y) / maxf(depth - rect.position.y, 1.0), 0.0, 1.0)
			gc.append(Color(1, 1, 1, gloss * (1.0 - t) * (1.0 - t)))
		if band.size() >= 3:
			rs.canvas_item_add_polygon(to_canvas_item, band, gc)
	if stripe.a > 0.0 and stripe_width > 0.0:
		var sr := Rect2(rect.position + Vector2(border_width + 3.0, border_width + 5.0), Vector2(stripe_width, rect.size.y - 2.0 * border_width - 10.0))
		rs.canvas_item_add_rect(to_canvas_item, sr, stripe)
	if border_width > 0.0 and (border.a > 0.0 or border_top.a > 0.0):
		var line := outline(rect, -border_width * 0.5)
		line.append(line[0])
		var lc := PackedColorArray()
		for p in line:
			lc.append(border_top.lerp(border, clampf((p.y - rect.position.y) / maxf(rect.size.y * 0.5, 1.0), 0.0, 1.0)))
		rs.canvas_item_add_polyline(to_canvas_item, line, lc, border_width, true)


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow(glow_size) if glow.a > 0.0 else rect
