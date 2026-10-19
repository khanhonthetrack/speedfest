class_name HudText
extends RefCounted
## Allocation-free text drawing for HUD gauges that update every physics tick.
## Numbers are stored as codepoint arrays (PackedInt32Array, resized in place) and
## drawn char by char in fixed-width cells, so digits are tabular (no jitter) even
## though Orbitron's digits are proportional.

const C_0 := 48
const C_COLON := 58
const C_DOT := 46
const C_MINUS := 45
const C_PLUS := 43
const C_SLASH := 47
const C_SPACE := 32

## Narrow punctuation gets a fraction of the digit cell.
const NARROW := 0.42


## "M:SS.mmm" (or "--:--.---" for ms < 0) into `out`.
static func time_codes(ms: int, out: PackedInt32Array) -> void:
	if ms < 0:
		out.resize(9)
		out[0] = C_MINUS; out[1] = C_MINUS; out[2] = C_COLON; out[3] = C_MINUS; out[4] = C_MINUS
		out[5] = C_DOT; out[6] = C_MINUS; out[7] = C_MINUS; out[8] = C_MINUS
		return
	var m := mini(ms / 60000, 99)
	var s := (ms / 1000) % 60
	var r := ms % 1000
	var i := 0
	out.resize(9 if m >= 10 else 8)
	if m >= 10:
		out[i] = C_0 + m / 10; i += 1
	out[i] = C_0 + m % 10; i += 1
	out[i] = C_COLON; i += 1
	out[i] = C_0 + s / 10; i += 1
	out[i] = C_0 + s % 10; i += 1
	out[i] = C_DOT; i += 1
	out[i] = C_0 + r / 100; i += 1
	out[i] = C_0 + (r / 10) % 10; i += 1
	out[i] = C_0 + r % 10


## "M:SS" (seconds rounded up, so the clock shows 0:00 only at the very end).
static func clock_codes(ms: int, out: PackedInt32Array) -> void:
	var total := maxi(0, (ms + 999) / 1000)
	var m := mini(total / 60, 99)
	var s := total % 60
	var i := 0
	out.resize(5 if m >= 10 else 4)
	if m >= 10:
		out[i] = C_0 + m / 10; i += 1
	out[i] = C_0 + m % 10; i += 1
	out[i] = C_COLON; i += 1
	out[i] = C_0 + s / 10; i += 1
	out[i] = C_0 + s % 10


## Non-negative integer, no leading zeros.
static func int_codes(v: int, out: PackedInt32Array) -> void:
	v = maxi(v, 0)
	var n := 1
	var t := v
	while t >= 10:
		t /= 10
		n += 1
	out.resize(n)
	for i in n:
		out[n - 1 - i] = C_0 + v % 10
		v /= 10


static func cell_width(code: int, cell_w: float) -> float:
	if code == C_COLON or code == C_DOT:
		return cell_w * NARROW
	if code == C_SPACE:
		return cell_w * 0.5
	return cell_w


static func codes_width(codes: PackedInt32Array, cell_w: float) -> float:
	var w := 0.0
	for c in codes:
		w += cell_width(c, cell_w)
	return w


## Draw `codes` with the baseline-left at `pos`. Optional neon glow via a font outline pass.
## Returns the drawn width.
static func draw_codes(ci: CanvasItem, font: Font, size: int, pos: Vector2, codes: PackedInt32Array,
		cell_w: float, color: Color, glow: Color = Color(0, 0, 0, 0), glow_size: int = 0) -> float:
	var rid := ci.get_canvas_item()
	var x := pos.x
	if glow_size > 0 and glow.a > 0.0:
		for c in codes:
			var cw := cell_width(c, cell_w)
			var gw := font.get_char_size(c, size).x
			font.draw_char_outline(rid, Vector2(x + (cw - gw) * 0.5, pos.y), c, size, glow_size, glow)
			x += cw
		x = pos.x
	for c in codes:
		var cw := cell_width(c, cell_w)
		var w := font.get_char_size(c, size).x
		font.draw_char(rid, Vector2(x + (cw - w) * 0.5, pos.y), c, size, color)
		x += cw
	return x - pos.x


## Centered horizontally on `center_x`.
static func draw_codes_centered(ci: CanvasItem, font: Font, size: int, center_x: float, baseline: float,
		codes: PackedInt32Array, cell_w: float, color: Color, glow: Color = Color(0, 0, 0, 0), glow_size: int = 0) -> void:
	var w := codes_width(codes, cell_w)
	draw_codes(ci, font, size, Vector2(center_x - w * 0.5, baseline), codes, cell_w, color, glow, glow_size)


## Right-aligned at `right_x`.
static func draw_codes_right(ci: CanvasItem, font: Font, size: int, right_x: float, baseline: float,
		codes: PackedInt32Array, cell_w: float, color: Color, glow: Color = Color(0, 0, 0, 0), glow_size: int = 0) -> void:
	var w := codes_width(codes, cell_w)
	draw_codes(ci, font, size, Vector2(right_x - w, baseline), codes, cell_w, color, glow, glow_size)


## A skewed (parallelogram) panel: rect with the top edge shifted right by `skew_px`.
static func skew_quad(rect: Rect2, skew_px: float, out: PackedVector2Array) -> void:
	out.resize(4)
	out[0] = Vector2(rect.position.x + skew_px, rect.position.y)
	out[1] = Vector2(rect.end.x + skew_px, rect.position.y)
	out[2] = Vector2(rect.end.x - skew_px, rect.end.y)
	out[3] = Vector2(rect.position.x - skew_px, rect.end.y)
