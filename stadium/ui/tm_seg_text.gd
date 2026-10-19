class_name TmSegText
extends Control
## Text in TMNF's race digits (M10-5, drawn after its HUD side by side): seven-segment figures
## with pointed segment ends and small gaps, a narrow 1, square dots for ':' and '.', white over a
## soft drop shadow. Letters (the distance's "m") fall back to the UI's sans. Drawn as polygons, so
## sharp at any size and the same on both renderers.

@export var text := "":
	set(v):
		if v != text:
			text = v
			queue_redraw()
@export var digit_height := 32.0:
	set(v):
		digit_height = v
		queue_redraw()
@export var colour := Color.WHITE:
	set(v):
		colour = v
		queue_redraw()
@export var shadow := Color(0, 0, 0, 0.55)
@export var h_align := HORIZONTAL_ALIGNMENT_CENTER
@export var v_align := VERTICAL_ALIGNMENT_CENTER

## Segments a (top), b (top right), c (bottom right), d (bottom), e (bottom left), f (top left),
## g (middle) lit for each figure.
const SEGMENTS := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
	"6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg", "-": "g"}
const WIDTH := 0.6          ## a figure's width, of its height
const THICK := 0.15         ## a segment's thickness
const GAP := 0.022          ## between segments
const SPACING := 0.14       ## between characters


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var h := digit_height
	var x := 0.0
	var total := _advance_all(h)
	match h_align:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = (size.x - total) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = size.x - total
	var y := (size.y - h) * 0.5
	if v_align == VERTICAL_ALIGNMENT_TOP:
		y = 0.0
	elif v_align == VERTICAL_ALIGNMENT_BOTTOM:
		y = size.y - h
	var off := Vector2(1.0, 1.0) * maxf(1.0, h * 0.045)
	for pass_ in 2:
		var c := shadow if pass_ == 0 else colour
		var o := off if pass_ == 0 else Vector2.ZERO
		var cx := x
		for ch in text:
			_char(ch, Vector2(cx, y) + o, h, c)
			cx += _advance(ch, h)


func _advance_all(h: float) -> float:
	var w := 0.0
	for ch in text:
		w += _advance(ch, h)
	return maxf(0.0, w - h * SPACING)


func _advance(ch: String, h: float) -> float:
	match ch:
		"1":
			return h * (THICK + 0.06 + SPACING)
		":", ".":
			return h * (THICK + SPACING)
		" ":
			return h * 0.3
	if SEGMENTS.has(ch):
		return h * (WIDTH + SPACING)
	return TmUi.font(TmUi.SANS).get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.95)).x + h * SPACING


func _char(ch: String, p: Vector2, h: float, c: Color) -> void:
	var t := h * THICK
	match ch:
		":":
			draw_rect(Rect2(p + Vector2(0, h * 0.27 - t * 0.5), Vector2(t, t)), c)
			draw_rect(Rect2(p + Vector2(0, h * 0.73 - t * 0.5), Vector2(t, t)), c)
			return
		".":
			draw_rect(Rect2(p + Vector2(0, h - t), Vector2(t, t)), c)
			return
		" ":
			return
	if not SEGMENTS.has(ch):
		var f := TmUi.font(TmUi.SANS)
		var px := int(h * 0.95)
		draw_string(f, p + Vector2(0, h - f.get_descent(px) * 0.4), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, c)
		return
	# the 1 stands in a narrow cell: its segments at the cell's left edge
	var x0 := p.x if ch != "1" else p.x - (WIDTH - THICK) * h
	var x1 := x0 + WIDTH * h
	var y0 := p.y
	var ym := p.y + h * 0.5
	var y1 := p.y + h
	var g := GAP * h
	for s in String(SEGMENTS[ch]):
		match s:
			"a":
				_hseg(x0, x1, y0 + t * 0.5, t, g, c)
			"g":
				_hseg(x0, x1, ym, t, g, c)
			"d":
				_hseg(x0, x1, y1 - t * 0.5, t, g, c)
			"f":
				_vseg(x0 + t * 0.5, y0, ym, t, g, c)
			"e":
				_vseg(x0 + t * 0.5, ym, y1, t, g, c)
			"b":
				_vseg(x1 - t * 0.5, y0, ym, t, g, c)
			"c":
				_vseg(x1 - t * 0.5, ym, y1, t, g, c)


## A horizontal segment between x0 and x1 centred on y: a hexagon with pointed ends.
func _hseg(x0: float, x1: float, y: float, t: float, g: float, c: Color) -> void:
	var h := t * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + g, y), Vector2(x0 + g + h, y - h), Vector2(x1 - g - h, y - h),
		Vector2(x1 - g, y), Vector2(x1 - g - h, y + h), Vector2(x0 + g + h, y + h)]), c)


func _vseg(x: float, y0: float, y1: float, t: float, g: float, c: Color) -> void:
	var h := t * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(x, y0 + g), Vector2(x + h, y0 + g + h), Vector2(x + h, y1 - g - h),
		Vector2(x, y1 - g), Vector2(x - h, y1 - g - h), Vector2(x - h, y0 + g + h)]), c)
