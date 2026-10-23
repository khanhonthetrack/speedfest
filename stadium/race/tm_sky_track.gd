class_name TmSkyTrack
extends RefCounted
## The Sky maps' road of our own (M19, the owner: "you ride on a building, or wallride on a building
## ... you jump and fly between building"), laid by TmTrackBuilder beside TMNF's blocks. A turtle in
## full 3D: where the road's centre is, which way it runs (fwd) and which way its surface faces
## (up). Its pieces sweep a road (TmSkyPieces builds it from the frames) along any curve: straights,
## turns in the road's own plane (on a wall: up or down it), pitches (a quarter pipe up a tower's
## face, over a roof's edge), twists about its line (onto a wall, upside down), banked and climbing
## turns, kickers, flights and landings, rooftops. Where the road leans more than MAG_COS from level
## it is mag-road (TmTuning.MAG_SURFACE): magnetic, it holds the car as the ground does on the flat.
##
## Pieces (tracks/*.json, among TMNF's; n in blocks of 32 m):
##   ["sky", n]                 n blocks straight on (on a wall or a face too)
##   ["go", m]                  m metres straight on (up and down a face: whole levels, 8 m each)
##   ["sl", k] / ["sr", k]      a quarter turn left / right in the road's own plane, radius 32k - 16
##   ["pu", r] / ["pd", r]      a quarter pitch up (a quarter pipe: up a face ahead) / down (over
##                              an edge: a crest), radius r m
##   ["twist", "l"|"r", deg, n] the road turns about its line over n blocks, the car's wheels
##                              swinging to that side by deg (90: a wall on that side; 180: upside down)
##   ["bank", "l"|"r", k, deg, levels]  a quarter turn about the vertical (radius 32k - 16) banked
##                              into it to deg by its end, from the bank it starts with, climbing
##                              `levels` (negative: down). deg 90: a wall round the inside of a tower
##   ["kick", deg, m]           a kicker: the road pitches up deg over m metres and ends at its lip
##   ["gap", n, levels]         air: lands, level, n blocks on from where the road last met the grid
##                              (the kicker's foot) and `levels` lower (negative: higher)
##   ["drop", n, levels, deg, r]  a ski jump off the road's end: a landing hill under the flight,
##                              down to `deg`, bending level (radius r m) at its foot, n blocks on and
##                              `levels` lower than the road's last grid face
##   ["roof", w, n]             n blocks of rooftop, w cells wide (odd), the road running on it
##   ["rails", "both"|"none"|"l"|"r"]  which sides the road laid next has rails on
## Back on TMNF's blocks the road must be level, facing along an axis, on a block's face.

const HALF := 12.75              ## the deck's half width, rail to rail (TMNF road: its curbs' feet)
const EDGE := 14.4               ## its outer edge (TMNF road: the curbs' backs)
const STEP := 2.0                ## m between the swept frames
const PATH_STEP := 8.0           ## m between the bot's points (TmTrackBuilder.STEP)
const MAG_COS := 0.96            ## frames whose up leans more than ~16 degrees are mag-road
const GRID_EPS := 0.05
const DROP_GAP := 3.0            ## m: a ski jump's landing hill starts this far under its lip
const TWIST_EASE := 0.2          ## a twist's rate ramps in and out over this share of it at each end
const TWIST_MAX := 0.025         ## rad/m: the most a twist turns (beyond: two wheels lift)
## Over an edge (a convex pitch) the road holds the car only up to sqrt(g r) (the mag-road's pull is
## the ground's gravity): the bot is told the radius is this much smaller, to keep it well under.
const CREST_MARGIN := 0.6
const PITCH_EASE := 0.3          ## a quarter pitch's curvature ramps in and out over this share at each end
## the grid: blocks 32 m across, levels 8 m, the road's top ROAD_Y over a level's base
const BLOCK := 32.0
const LEVEL := 8.0

var b: TmTrackBuilder
var on := false                  ## the turtle is out on the sky road (pos/fwd/up hold its state)
var pos := Vector3.ZERO          ## TMNF metres: the road surface's centre where the next piece starts
var fwd := Vector3(0, 0, 1)
var up := Vector3.UP
var grid_pos := Vector3.ZERO     ## where the road last met the grid (a kicker's foot: gaps count from it)
var rails := "both"
## The ribbon being laid: [{o, f, u, mag, rails}] (TMNF metres), flushed into the builder's extras.
var frames: Array = []
var _run := 0.0                  ## m along the ribbon since its last path point
var _len := 0.0                  ## m along the ribbon (its frames' s)


func _init(builder: TmTrackBuilder) -> void:
	b = builder


## The road's right (TMNF axes: x right of +z).
static func right_of(f: Vector3, u: Vector3) -> Vector3:
	return u.cross(f).normalized()


const KINDS := ["sky", "go", "sl", "sr", "pu", "pd", "twist", "bank", "kick", "gap", "drop", "roof", "rails"]


static func handles(kind: String) -> bool:
	return kind in KINDS


## Starts from the builder's turtle (the face it stands on) if the sky road isn't out yet.
func _begin() -> void:
	if on:
		return
	on = true
	pos = b.entry_face()
	fwd = TmTrackBuilder.vec(b.heading)
	up = Vector3.UP
	grid_pos = pos
	_start_ribbon()


func piece(p: Array) -> void:
	var kind := String(p[0])
	if kind == "rails":
		rails = String(p[1]) if p.size() > 1 else "both"
		return
	if b.surface != "road":
		b.errors.append("%s is laid from road, not %s (piece %d)" % [kind, b.surface, b.piece_count()])
		return
	_begin()
	match kind:
		"sky":
			_straight(float(p[1] if p.size() > 1 else 1) * BLOCK)
		"go":
			_straight(float(p[1]))
		"sl", "sr":
			_turn(kind == "sl", int(p[1]) * BLOCK - 16.0 if p.size() > 1 else 16.0)
		"pu", "pd":
			_pitch(kind == "pu", float(p[1]) if p.size() > 1 else 48.0, PI * 0.5)
		"twist":
			var deg := float(p[2]) if p.size() > 2 else 90.0
			_twist(String(p[1]) == "l", deg_to_rad(deg), float(p[3] if p.size() > 3 else 2) * BLOCK)
		"bank":
			_bank(String(p[1]) == "l", int(p[2]) * BLOCK - 16.0, deg_to_rad(float(p[3])), float(p[4] if p.size() > 4 else 0) * LEVEL)
		"kick":
			_pitch(true, float(p[2]) / deg_to_rad(float(p[1])), deg_to_rad(float(p[1])))
		"gap":
			_gap(float(p[1]) * BLOCK, float(p[2] if p.size() > 2 else 0) * LEVEL)
		"drop":
			_drop(float(p[1]) * BLOCK, float(p[2]) * LEVEL, deg_to_rad(float(p[3])), float(p[4]))
		"roof":
			_roof(int(p[1]), int(p[2]) if p.size() > 2 else 1)
	_check_grid()


## Before a TMNF piece: the ribbon laid so far becomes the builder's, and the turtle steps back
## onto the grid (it must be level, along an axis, on a block's face).
func land() -> bool:
	if not on:
		return true
	flush()
	on = false
	var h := _axis(fwd)
	if h < 0 or up.y < 0.999:
		b.errors.append("the sky road meets TMNF's blocks leaning or off an axis (piece %d: fwd %s up %s)"
			% [b.piece_count(), fwd.snapped(Vector3.ONE * 0.01), up.snapped(Vector3.ONE * 0.01)])
		return false
	var c := pos + fwd * 16.0
	var lv := (pos.y - TmTrackBuilder.ROAD_Y) / LEVEL
	var cell := Vector3i(floori(c.x / BLOCK), roundi(lv), floori(c.z / BLOCK))
	var face := Vector3((cell.x + 0.5) * BLOCK, cell.y * LEVEL + TmTrackBuilder.ROAD_Y, (cell.z + 0.5) * BLOCK) - fwd * 16.0
	if face.distance_to(pos) > GRID_EPS:
		b.errors.append("the sky road meets TMNF's blocks off a block's face (piece %d: at %s, nearest face %s)"
			% [b.piece_count(), pos.snapped(Vector3.ONE * 0.01), face])
		return false
	b.cell = cell
	b.heading = h
	return true


## The heading (0..3) of an axis direction, or -1.
static func _axis(f: Vector3) -> int:
	for h in 4:
		if TmTrackBuilder.vec(h).distance_to(f) < 1e-3:
			return h
	return -1


## Where the turtle stands on a block's face, level and along an axis: gaps count from there.
func _check_grid() -> void:
	if not on or _axis(fwd) < 0 or up.y < 0.999:
		return
	var lv := (pos.y - TmTrackBuilder.ROAD_Y) / LEVEL
	if absf(lv - roundf(lv)) * LEVEL > GRID_EPS:
		return
	var c := pos + fwd * 16.0
	var face := Vector3((floorf(c.x / BLOCK) + 0.5) * BLOCK, pos.y, (floorf(c.z / BLOCK) + 0.5) * BLOCK) - fwd * 16.0
	if face.distance_to(pos) <= GRID_EPS:
		grid_pos = face


# --- the frames -----------------------------------------------------------------------------------

## One frame of the ribbon (and, every PATH_STEP, a point of the bot's line). k: the line's
## curvature in the road's plane (1/m, + left); r: the turn's radius for the bot's speed (0:
## none); rv: a crest's radius (convex in the road's normal plane).
func _frame(o: Vector3, f: Vector3, u: Vector3, ds: float, k := 0.0, r := 0.0, rv := 0.0) -> void:
	f = f.normalized()
	u = (u - f * u.dot(f)).normalized()
	_len += ds
	frames.append({"o": o, "f": f, "u": u, "mag": u.y < MAG_COS, "rails": rails, "s": _len})
	_mark(o, f, u)
	_run += ds
	if _run >= PATH_STEP - 1e-3 or ds == 0.0:
		_run = 0.0
		var pt := {"p": TmTrackBuilder.to_godot(o), "dir": TmTrackBuilder.to_godot(f), "mode": TmTrackBuilder.Drive.STEER,
			"r": r, "k": k, "n": TmTrackBuilder.to_godot(u), "sky": true}
		if rv > 0.0:
			pt["rv"] = rv
		b.path.append(pt)
	pos = o
	fwd = f
	up = u


## The cells the road's deck covers (its middle and edges), level by the deck's height: TMNF's
## blocks can't be laid into them.
func _mark(o: Vector3, f: Vector3, u: Vector3) -> void:
	var rt := right_of(f, u)
	for x: float in [-HALF, 0.0, HALF]:
		var q := o + rt * x - f * 0.5            # (frames end their step: half a metre back is this step's)
		var w := Vector3i(floori(q.x / BLOCK), floori(q.y / LEVEL), floori(q.z / BLOCK))
		if not TmTrackBuilder.inside(w):
			b.errors.append("the sky road leaves the map at %s (piece %d)" % [q.snapped(Vector3.ONE * 0.1), b.piece_count()])
			return
		var was := b.occupant(w)
		if not was.is_empty() and not was.begins_with("Sky"):
			b.errors.append("the sky road runs into %s at %s (piece %d)" % [was, w, b.piece_count()])
			return
		b._occupied[w] = "SkyRoad"


func _straight(m: float) -> void:
	var n := maxi(1, ceili(m / STEP))
	var o := pos
	for i in range(1, n + 1):
		_frame(o + fwd * (m * i / n), fwd, up, m / n)


## A quarter turn in the road's own plane (about up): left or right, radius r.
func _turn(left: bool, r: float) -> void:
	var rt := right_of(fwd, up)
	var side := -rt if left else rt
	var c := pos + side * r
	var ang := -PI * 0.5 if left else PI * 0.5
	var n := maxi(2, ceili(r * PI * 0.5 / STEP))
	var p0 := pos
	var f0 := fwd
	var u0 := up
	for i in range(1, n + 1):
		var rot := Basis(u0, ang * i / n)
		_frame(c + rot * (p0 - c), rot * f0, u0, r * PI * 0.5 / n, (1.0 if left else -1.0) / r, r)


## A pitch about the road's right: up (concave, towards its surface's side) or down (convex), by
## `ang`, radius r. A quarter (90 degrees) is eased: its curvature ramps in and out over
## PITCH_EASE of it at each end (a straight meeting a circle unloads the springs at once: over an
## edge they throw the car off), the curve as long as it takes to move r on and r up, as the circle.
func _pitch(upward: bool, r: float, ang: float) -> void:
	if absf(ang - PI * 0.5) < 1e-3:
		_pitch_eased(upward, r)
		return
	var rt := right_of(fwd, up)
	var c := pos + up * (r if upward else -r)
	var a := -ang if upward else ang
	var n := maxi(2, ceili(r * ang / STEP))
	var p0 := pos
	var f0 := fwd
	var u0 := up
	for i in range(1, n + 1):
		var rot := Basis(rt, a * i / n)
		_frame(c + rot * (p0 - c), rot * f0, rot * u0, r * ang / n, 0.0, 0.0, 0.0 if upward else r * CREST_MARGIN)


## A quarter pitch with eased curvature (see _pitch): the shape is fixed up to its size, so its
## length is found from how far one of unit length moves (each way: it is symmetric).
func _pitch_eased(upward: bool, r: float) -> void:
	var a := PITCH_EASE
	var k1 := PI * 0.5 / (1.0 - a)           # the peak curvature of a unit-length quarter
	var steps := 400
	var d := 0.0                             # how far a unit-length quarter moves on
	var th := 0.0
	for i in steps:
		var t := (i + 0.5) / steps
		d += cos(th + _ease_k(t, a) * k1 / steps * 0.5) / steps
		th += _ease_k(t, a) * k1 / steps
	var length := r / d
	var kmax := k1 / length
	var rt := right_of(fwd, up)
	var n := maxi(4, ceili(length / STEP))
	var sgn := -1.0 if upward else 1.0
	var p := pos
	var f := fwd
	var u := up
	var start_f := fwd
	var start_u := up
	for i in range(1, n + 1):
		# the angle at the step's end (the curvature integrated); the position by the middle angle
		var t0 := float(i - 1) / n
		var t1 := float(i) / n
		var a1 := _ease_angle(t1, a) * PI * 0.5
		var amid := _ease_angle((t0 + t1) * 0.5, a) * PI * 0.5
		var rm := Basis(rt, sgn * amid)
		p += (rm * start_f) * (length / n)
		var r1 := Basis(rt, sgn * a1)
		f = r1 * start_f
		u = r1 * start_u
		var kk := _ease_k(t1, a) * kmax
		_frame(p, f, u, length / n, 0.0, 0.0, 0.0 if upward else (1.0 / maxf(kk, 1e-4)) * CREST_MARGIN if kk > 1e-4 else 0.0)
	# exactly on the quarter
	var q := Basis(rt, sgn * PI * 0.5)
	fwd = q * start_f
	up = q * start_u


## A quarter's curvature at t (0..1 along it) as a share of its peak: ramps of `a` at both ends.
static func _ease_k(t: float, a: float) -> float:
	if t < a:
		return t / a
	if t > 1.0 - a:
		return (1.0 - t) / a
	return 1.0


## Its angle at t as a share of the whole: the curvature integrated.
static func _ease_angle(t: float, a: float) -> float:
	var full := 1.0 - a
	if t < a:
		return t * t / (2.0 * a) / full
	if t > 1.0 - a:
		return 1.0 - (1.0 - t) * (1.0 - t) / (2.0 * a) / full
	return (t - a * 0.5) / full


## A twist about the line over m metres: the wheels' side swings to the left or right by ang, at an
## even rate eased in and out over TWIST_EASE of it at each end (the car is rigid: the road can't
## twist much along its wheelbase, TWIST_MAX, or two of its wheels lose the road).
func _twist(left: bool, ang: float, m: float) -> void:
	var n := maxi(2, ceili(m / STEP))
	var p0 := pos
	var f0 := fwd
	var u0 := up
	var a := -ang if left else ang
	if ang / (m * (1.0 - TWIST_EASE)) > TWIST_MAX + 1e-4:
		b.notes.append("twist (piece %d): %.3f rad/m, over %.3f: lengthen it" % [b.piece_count(), ang / (m * (1.0 - TWIST_EASE)), TWIST_MAX])
	for i in range(1, n + 1):
		_frame(p0 + f0 * (m * float(i) / n), f0, Basis(f0, a * ease_twist(float(i) / n)) * u0, m / n)


## The share of a twist done at t (0..1 along it): an even rate between ramps of TWIST_EASE.
static func ease_twist(t: float) -> float:
	var a := TWIST_EASE
	if t < a:
		return t * t / (2.0 * a) / (1.0 - a)
	if t > 1.0 - a:
		return 1.0 - (1.0 - t) * (1.0 - t) / (2.0 * a) / (1.0 - a)
	return (t - a * 0.5) / (1.0 - a)


## The bank about the line from the vertical: + where the road's up leans to its right (a right
## turn's bank).
static func bank_of(f: Vector3, u: Vector3) -> float:
	var fh := Vector3(f.x, 0.0, f.z).normalized()
	var rh := Vector3.UP.cross(fh)
	var u0 := fh.cross(rh)
	return atan2(u.dot(rh), u.dot(u0))


## A quarter turn about the vertical, radius r, banked into it to `bank` by its end (smoothstep from
## the bank it starts with), climbing dy (eased: level at both ends, so quarters chain into a spiral).
func _bank(left: bool, r: float, bank: float, dy: float) -> void:
	if absf(fwd.y) > 1e-3:
		b.errors.append("a banked turn starts level (piece %d)" % b.piece_count())
		return
	var fh := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var rh := Vector3.UP.cross(fh)
	var c := pos + (-rh if left else rh) * r
	var b0 := bank_of(fwd, up)
	var b1 := -bank if left else bank
	var ang := -PI * 0.5 if left else PI * 0.5
	var arc := r * PI * 0.5
	var n := maxi(2, ceili(arc / STEP))
	var p0 := pos
	var prev := p0
	for i in range(1, n + 1):
		var t := float(i) / n
		var e := t * t * (3.0 - 2.0 * t)
		var rot := Basis(Vector3.UP, ang * t)
		var p := c + rot * (p0 - c) + Vector3.UP * dy * e
		var climb := dy * 6.0 * t * (1.0 - t) / arc     # rise per metre along
		var th := (rot * fh + Vector3.UP * climb).normalized()
		var rr := Vector3.UP.cross(Vector3(th.x, 0.0, th.z).normalized())
		var u0 := th.cross(rr)
		var bk := lerpf(b0, b1, e)
		var u := u0 * cos(bk) + rr * sin(bk)
		_frame(p, th, u, p.distance_to(prev), (1.0 if left else -1.0) * cos(bk) / r,
			r / maxf(cos(bk), 0.2))
		prev = p
	# the last frame lies exactly on the quarter (no drift from the steps)
	pos = c + Basis(Vector3.UP, ang) * (p0 - c) + Vector3.UP * dy
	# the turn's middle: a round tower there (TmSkyCity), the road banked towards it
	b.extras.append({"kind": "hub", "c": c, "r": r, "lo": minf(p0.y, pos.y), "hi": maxf(p0.y, pos.y),
		"bank": maxf(absf(b0), absf(b1))})


## The ribbon so far into the builder's extras.
func flush() -> void:
	if frames.size() >= 2:
		b.extras.append({"kind": "ribbon", "frames": frames})
	frames = []
	_len = 0.0


## The road's start frame (a new ribbon after a flight): the turtle's own.
func _start_ribbon() -> void:
	frames = []
	_len = 0.0
	frames.append({"o": pos, "f": fwd, "u": up, "mag": up.y < MAG_COS, "rails": rails, "s": 0.0})
	_run = 0.0


## The line through the air from the lip to `to`: held straight (the bot's BLIND points).
func _air(to: Vector3, dir_after: Vector3) -> void:
	var from := pos
	var d := from.distance_to(to)
	var n := maxi(1, ceili(d / PATH_STEP))
	var dir := (to - from).normalized()
	for i in range(1, n + 1):
		b.path.append({"p": TmTrackBuilder.to_godot(from.lerp(to, float(i) / n)), "dir": TmTrackBuilder.to_godot(
			dir if i < n else dir_after), "mode": TmTrackBuilder.Drive.BLIND, "r": 0.0, "k": 0.0, "sky": true, "air": true})


## Air from the lip to a level landing n metres on (level) and dy lower than the last grid face.
func _gap(m: float, dy: float) -> void:
	flush()
	var fh := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var to := grid_pos + fh * m - Vector3.UP * dy
	_air(to, fh)
	pos = to
	fwd = fh
	up = Vector3.UP
	_start_ribbon()


## A ski jump off the road's end (a tower's edge): the landing hill (mag-road where it is steep)
## under the flight a car makes off the lip at the hill's design speed, as real ski jumps are built:
## it starts DROP_GAP m under the lip, follows that flight's parabola down to `ang`, runs straight
## at that slope, then bends level (radius r) at its foot, m metres on and dy lower than the road's
## last grid face. A slower car lands early on the parabola, a faster one on the straight, both at a
## shallow angle to the hill. The design speed follows from the numbers (kept in the builder's notes).
func _drop(m: float, dy: float, ang: float, r: float) -> void:
	flush()
	var fh := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var lip := pos
	var foot := grid_pos + fh * m - Vector3.UP * dy
	var big_x := (foot - lip).dot(fh)
	var t := tan(ang)
	var x2 := big_x - r * sin(ang)                     # where the curve to level starts (from the lip)
	var y2 := (foot.y - lip.y) + r * (1.0 - cos(ang))
	var den := t * x2 + DROP_GAP + y2
	if den <= 0.0:
		b.errors.append("a drop (piece %d) too short for its height" % b.piece_count())
		return
	var k := t * t / (4.0 * den)                        # the flight: y = -k x^2 below the lip
	var x1 := t / (2.0 * k)                             # the parabola reaches the slope `ang`
	if x1 > x2 + 0.01:
		b.errors.append("a drop (piece %d): its curve starts before its parabola ends" % b.piece_count())
		return
	var g := TmTuning.GRAVITY * TmTuning.GRAVITY_AIR
	b.notes.append("drop (piece %d): design speed %.0f km/h, %.0f m down, steep from %.0f m" % [b.piece_count(),
		sqrt(g / (2.0 * k)) * 3.6, lip.y - foot.y, x1])
	pos = lip - Vector3.UP * DROP_GAP
	fwd = fh
	up = Vector3.UP
	_start_ribbon()
	var x := 0.0
	while x < x1 - 1e-4:
		x = minf(x + STEP / sqrt(1.0 + 4.0 * k * k * x * x), x1)
		var slope := 2.0 * k * x
		var p := lip + fh * x - Vector3.UP * (k * x * x + DROP_GAP)
		var ds := p.distance_to(pos)
		var pts := b.path.size()
		_frame(p, fh - Vector3.UP * slope, fh * slope + Vector3.UP, ds)
		if b.path.size() > pts:
			b.path[b.path.size() - 1]["mode"] = TmTrackBuilder.Drive.BLIND      # (in the air: held straight)
	var f := (fh * cos(ang) - Vector3.UP * sin(ang)).normalized()
	var top := lip + fh * x2 + Vector3.UP * y2
	if pos.distance_to(top) > 0.5:
		_straight(pos.distance_to(top))
	pos = top
	fwd = f
	up = (fh * sin(ang) + Vector3.UP * cos(ang)).normalized()
	_pitch(true, r, ang)
	pos = foot
	fwd = fh
	up = Vector3.UP


## n blocks of rooftop, w cells wide: a flat deck at the road's height (TmSkyPieces "roof"), the
## road's line straight over it; the building under it is the scenery's (TmSkyCity).
func _roof(w: int, n: int) -> void:
	if up.y < 0.999 or _axis(fwd) < 0:
		b.errors.append("a roof lies level, along an axis (piece %d)" % b.piece_count())
		return
	flush()
	var rt := right_of(fwd, up)
	var a := pos
	var z := pos + fwd * BLOCK * n
	var half := w * BLOCK * 0.5
	var corners := [a - rt * half, a + rt * half, z + rt * half, z - rt * half]
	var lo := Vector3(INF, a.y, INF)
	var hi := Vector3(-INF, a.y, -INF)
	for q: Vector3 in corners:
		lo = Vector3(minf(lo.x, q.x), a.y, minf(lo.z, q.z))
		hi = Vector3(maxf(hi.x, q.x), a.y, maxf(hi.z, q.z))
	# the deck's cells
	for x in range(floori(lo.x / BLOCK + 0.01), ceili(hi.x / BLOCK - 0.01)):
		for zc in range(floori(lo.z / BLOCK + 0.01), ceili(hi.z / BLOCK - 0.01)):
			var cw := Vector3i(x, floori(a.y / LEVEL), zc)
			if not TmTrackBuilder.inside(cw):
				b.errors.append("a roof leaves the map at %s (piece %d)" % [cw, b.piece_count()])
				return
			var was := b.occupant(cw)
			if not was.is_empty() and not was.begins_with("Sky"):
				b.errors.append("a roof runs into %s at %s (piece %d)" % [was, cw, b.piece_count()])
				return
			b._occupied[cw] = "SkyRoof"
	b.extras.append({"kind": "roof", "lo": lo, "hi": hi, "y": a.y, "entry": a, "exit": z, "f": fwd})
	var steps := maxi(1, ceili(BLOCK * n / PATH_STEP))
	for i in range(1, steps + 1):
		b.path.append({"p": TmTrackBuilder.to_godot(a.lerp(z, float(i) / steps)), "dir": TmTrackBuilder.to_godot(fwd),
			"mode": TmTrackBuilder.Drive.STEER, "r": 0.0, "k": 0.0, "sky": true})
	pos = z
	_start_ribbon()
