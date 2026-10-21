extends RefCounted
## The inflatable castles (Inflatable/Castle, CastleBig, InflatableCastleDoor; inflatable.gd calls
## build()): TMNF's castles, our own geometry from measured numbers (TMNF block-local metres) and
## our own atlas (texgen/stadium.py inflatable_castle) laid out as TMNF's: rows of 512 from the top
## (ROW_*), u across a wall, a pillow, half a tower, reading left to right from outside.
##
## A castle is keeps of four towers standing on a ring of cushion pillows (green, each pillow
## printed with our board in its middle), stone walls between the towers bulging out in their
## middle and rounded over at the top, grey quilted roofs, battlements, red tie ropes. The big
## castle adds a hall (taller walls, battlements) and a courtyard closed by two beams to a second
## keep; the door castle two keeps joined by a bridge over the road, an arch under it.
## Every point here was measured from TMNF's blocks (the towers lean a little, as TMNF's).

const S_RUBBER := 9
const KEY := "castle"
const ROOF_KEY := "infl_roof"
const ROPE_KEY := "infl_rope_red"

## Atlas rows: a tower from its foot up: [r (of the shaft's / crown's radius), height (above its
## foot / the shaft's top), row]; the cone from the crown to the tip.
const ROW_FOOT := 425.5           ## the stone's foot (just above the cushion's green)
const ROW_SHAFT_TOP := 135.0      ## the stone's top (the battlements' band above)
const ROW_BAND := 105.0           ## the cream band's foot
const ROW_BAND_TOP := 47.0        ## its top (the trim line above, then the slate)
const TOWER_SIDES := 16
## The crown over the shaft's top: [share of the crown radius, height above the shaft's top, row]
const CROWN := [[0.98, 0.40, 118.8], [1.0, 0.68, 109.6], [1.0, 2.34, 48.0], [0.94, 2.71, 37.0]]
const TOWER_U := Vector2(0.188, 0.82)     ## half a tower carries the atlas from u 0.188 to 0.82
## A wall's section from its foot (on the outer line) up: [inward, height below its top's inner
## edge (the foot's own y for the first), row]: a keep's rounded over in the slate, a hall's (and
## the bridge's, the step walls') higher in the cream band; a step wall between two roofs shows
## the cream band only.
const WALL := [[0.0, 0.0, ROW_FOOT], [0.046, 0.9, 46.0], [0.112, 0.57, 34.3], [0.264, 0.30, 23.0],
	[0.507, 0.12, 13.8], [0.836, 0.0, 4.6]]
const WALL_HALL := [[0.0, 0.0, ROW_FOOT], [0.048, 1.245, 47.1], [0.117, 0.783, 54.3], [0.277, 0.409, 54.8],
	[0.531, 0.16, 55.8], [0.876, 0.0, 56.8]]
enum { KEEP_WALL, HALL_WALL, STEP_WALL }
const WALL_BULGE := 0.2           ## a wall pillow bulges out this much in its middle
const WALL_PILLOW := 17.0         ## about this long each (the atlas across once)
## The cushion ring's pillows: the outline bulging out from the seam line ([along from a seam,
## out]; the middle of the pillow BULGE out), its section from the ground up ([in from the
## outline, y, row]; in scaled with the bulge: a seam pinches it upright), the grey skirt under it.
const PILLOW := [[0.0, 0.0], [0.69, 0.63], [3.95, 0.86]]
const PILLOW_MID := 0.82
const CUSHION := [[0.02, 1.42, 511.0], [0.0, 2.28, 490.0], [0.235, 2.93, 466.0], [0.585, 3.32, 447.5],
	[1.5, 3.54, 428.5]]
const SKIRT := [0.1, 0.19, 0.89]        ## skirt foot: in = a + b * bulge share, at y
## Battlements: a rounded block (length, height, depth; corner radius)
const MERLON := [2.81, 1.7, 1.22, 0.35]
## Ropes from 6.96 m up a tower (at its shaft's radius) down to a peg ROPE_RUN further out
const ROPE_Y := 6.98
const ROPE_RUN := 2.4
const ROOF_TILE := 7.66           ## the roof's quilted tile (m)

## Per castle: towers [foot centre (x, z), crown centre (the lean), foot y, shaft top y, tip y,
## rope directions], shaft and crown radii, walls [outer foot line from, to (x, z), outward, foot
## y, top's inner edge y (, kind: KEEP_WALL when left out)], roofs
## (outlines, x y z), cushion rings (their seams, in order round), battlements [centre, along x],
## the cushion's top y; the crown's heights (CROWN) scaled by "crown".
const CASTLE := {
	"towers": [
		[Vector2(12.59, 5.14), Vector2(12.86, 5.14), 3.48, 12.79, 17.62, [Vector2(-1, 0), Vector2(0, -1)]],
		[Vector2(27.04, 5.14), Vector2(27.28, 5.14), 3.35, 12.45, 17.29, [Vector2(1, 0), Vector2(0, -1)]],
		[Vector2(27.04, 19.58), Vector2(27.28, 19.58), 3.35, 12.45, 17.29, [Vector2(1, 0), Vector2(0, 1)]],
		[Vector2(12.59, 19.58), Vector2(12.86, 19.58), 3.48, 12.79, 17.62, [Vector2(-1, 0), Vector2(0, 1)]],
	],
	"radii": Vector2(2.17, 2.40),
	"crown": 1.0,
	"walls": [
		[Vector2(11.46, 18.10), Vector2(11.46, 6.67), Vector2(-1, 0), 3.50, 11.64],
		[Vector2(14.08, 3.89), Vector2(25.52, 3.89), Vector2(0, -1), 3.43, 11.48],
		[Vector2(28.15, 6.69), Vector2(28.15, 18.12), Vector2(1, 0), 3.37, 11.29],
		[Vector2(14.09, 20.90), Vector2(25.53, 20.90), Vector2(0, 1), 3.43, 11.48],
	],
	"roofs": [[Vector3(12.48, 11.64, 6.67), Vector3(14.27, 11.59, 4.73), Vector3(19.95, 11.42, 4.55), Vector3(25.64, 11.37, 4.73),
		Vector3(27.44, 11.29, 6.69), Vector3(27.62, 11.16, 12.41), Vector3(27.44, 11.29, 18.12), Vector3(25.65, 11.37, 20.06),
		Vector3(19.97, 11.42, 20.24), Vector3(14.28, 11.59, 20.06), Vector3(12.48, 11.64, 18.10), Vector3(12.30, 11.51, 12.38)]],
	"rings": [[Vector2(11.109, 3.676), Vector2(28.536, 3.682), Vector2(28.533, 21.103), Vector2(11.106, 21.098)]],
	"merlons": [],
	"cushion_top": 3.6,
}
const BIG := {
	"towers": [
		[Vector2(6.28, 7.34), Vector2(6.55, 7.33), 3.27, 13.42, 18.49, [Vector2(-1, 0), Vector2(0, -1)]],
		[Vector2(6.28, 22.48), Vector2(6.56, 22.48), 3.27, 13.42, 18.49, [Vector2(-1, 0), Vector2(0, 1)]],
		[Vector2(21.60, 7.47), Vector2(22.00, 7.47), 3.14, 17.48, 23.15, [Vector2(0, -1)]],
		[Vector2(21.61, 22.48), Vector2(22.00, 22.48), 3.14, 17.47, 23.15, [Vector2(0, 1)]],
		[Vector2(57.97, 7.29), Vector2(57.97, 7.47), 3.14, 17.54, 23.21, [Vector2(1, 0)]],
		[Vector2(57.98, 22.54), Vector2(57.72, 22.48), 3.14, 17.54, 23.21, [Vector2(1, 0)]],
		[Vector2(41.72, 41.75), Vector2(41.91, 41.45), 3.14, 17.48, 23.15, [Vector2(-1, 0)]],
		[Vector2(56.97, 41.74), Vector2(56.92, 41.45), 3.14, 17.47, 23.15, [Vector2(1, 0)]],
		[Vector2(41.78, 57.17), Vector2(41.76, 56.90), 3.27, 13.42, 18.49, [Vector2(-1, 0), Vector2(0, 1)]],
		[Vector2(56.92, 57.17), Vector2(56.92, 56.89), 3.27, 13.42, 18.49, [Vector2(1, 0), Vector2(0, 1)]],
	],
	"radii": Vector2(2.25, 2.51),
	"crown": 1.05,
	"walls": [
		[Vector2(5.09, 20.93), Vector2(5.09, 8.94), Vector2(-1, 0), 3.29, 12.78],
		[Vector2(7.84, 6.03), Vector2(19.83, 6.03), Vector2(0, -1), 3.22, 12.61],
		[Vector2(7.85, 23.87), Vector2(19.84, 23.87), Vector2(0, 1), 3.22, 12.61],
		[Vector2(23.31, 6.03), Vector2(56.03, 6.03), Vector2(0, -1), 3.22, 14.85, HALL_WALL],
		[Vector2(23.33, 23.87), Vector2(56.05, 23.87), Vector2(0, 1), 3.22, 14.85, HALL_WALL],
		[Vector2(58.80, 8.97), Vector2(58.80, 20.95), Vector2(1, 0), 3.15, 14.82, HALL_WALL],
		[Vector2(21.01, 20.95), Vector2(21.01, 8.97), Vector2(-1, 0), 12.47, 14.64, STEP_WALL],
		[Vector2(40.47, 55.61), Vector2(40.47, 43.62), Vector2(-1, 0), 3.22, 12.61],
		[Vector2(58.30, 43.61), Vector2(58.30, 55.60), Vector2(1, 0), 3.22, 12.61],
		[Vector2(42.52, 40.86), Vector2(55.39, 40.86), Vector2(0, -1), 3.15, 12.41],
		[Vector2(43.38, 58.36), Vector2(55.37, 58.36), Vector2(0, 1), 3.29, 12.78],
	],
	"roofs": [
		[Vector3(6.16, 12.78, 8.94), Vector3(8.04, 12.73, 6.91), Vector3(19.96, 12.50, 6.91), Vector3(21.85, 12.42, 8.97),
			Vector3(22.03, 12.27, 14.96), Vector3(21.85, 12.42, 20.95), Vector3(19.97, 12.50, 22.99), Vector3(8.05, 12.73, 22.99),
			Vector3(6.16, 12.78, 20.93), Vector3(5.97, 12.65, 14.94)],
		# the hall's, in two halves meeting on its raised middle
		[Vector3(21.81, 14.82, 8.97), Vector3(23.56, 14.60, 6.91), Vector3(31.90, 14.92, 6.72), Vector3(40.57, 15.09, 6.91),
			Vector3(40.58, 15.13, 14.94), Vector3(40.59, 15.08, 22.99), Vector3(31.91, 14.92, 23.18), Vector3(23.57, 14.83, 22.99),
			Vector3(21.81, 14.82, 20.95), Vector3(21.62, 14.64, 14.96)],
		[Vector3(40.57, 15.09, 6.91), Vector3(48.90, 14.92, 6.72), Vector3(56.16, 14.93, 6.91), Vector3(58.05, 14.82, 8.97),
			Vector3(58.23, 14.64, 14.96), Vector3(58.05, 14.82, 20.95), Vector3(56.17, 14.93, 22.99), Vector3(49.06, 14.92, 23.18),
			Vector3(40.59, 15.08, 22.99), Vector3(40.58, 15.13, 14.94)],
		[Vector3(42.52, 12.42, 41.60), Vector3(49.40, 12.27, 41.42), Vector3(55.39, 12.42, 41.60), Vector3(57.42, 12.50, 43.48),
			Vector3(57.61, 12.49, 49.44), Vector3(57.42, 12.73, 55.40), Vector3(55.37, 12.78, 57.29), Vector3(49.37, 12.65, 57.48),
			Vector3(43.38, 12.78, 57.29), Vector3(41.34, 12.73, 55.41), Vector3(41.16, 12.49, 49.45), Vector3(41.34, 12.50, 43.49)],
		# the courtyard's floor between the hall, the beams and the second keep
		[Vector3(23.18, 3.0, 23.52), Vector3(31.72, 3.0, 23.52), Vector3(40.41, 3.0, 23.57), Vector3(48.90, 3.0, 23.52),
			Vector3(56.05, 3.0, 23.57), Vector3(59.34, 3.04, 23.97), Vector3(58.57, 3.0, 27.59), Vector3(58.24, 3.0, 32.23),
			Vector3(58.07, 3.0, 36.88), Vector3(58.42, 3.0, 40.53), Vector3(55.39, 2.94, 41.16), Vector3(49.40, 2.87, 41.20),
			Vector3(42.52, 2.86, 41.16), Vector3(40.32, 3.04, 40.47), Vector3(36.60, 3.0, 34.50), Vector3(33.28, 3.04, 30.73),
			Vector3(29.40, 3.04, 27.34), Vector3(22.94, 3.06, 23.97)],
	],
	"rings": [[Vector2(4.725, 5.809), Vector2(22.949, 5.812), Vector2(41.184, 5.813), Vector2(59.446, 5.814),
		Vector2(59.458, 24.036), Vector2(59.30, 40.58), Vector2(58.509, 58.729), Vector2(40.244, 58.727),
		Vector2(40.27, 40.543), Vector2(22.946, 24.076), Vector2(4.722, 24.074)]],
	"merlons": [
		[Vector3(28.48, 15.53, 6.93), true], [Vector3(34.26, 15.74, 6.88), true], [Vector3(40.02, 15.82, 7.02), true],
		[Vector3(45.61, 15.73, 6.96), true], [Vector3(51.29, 15.69, 6.92), true],
		[Vector3(28.57, 15.63, 22.99), true], [Vector3(34.25, 15.71, 22.98), true], [Vector3(39.85, 15.77, 22.81), true],
		[Vector3(45.61, 15.74, 22.95), true], [Vector3(51.39, 15.67, 22.94), true],
		[Vector3(58.05, 15.48, 17.53), false], [Vector3(57.99, 15.49, 11.85), false],
		[Vector3(21.79, 15.48, 17.53), false], [Vector3(21.87, 15.49, 11.85), false],
		[Vector3(41.81, 15.61, 27.60), false], [Vector3(41.81, 15.48, 32.03), false], [Vector3(41.81, 15.69, 36.22), false],
		[Vector3(57.64, 15.73, 28.10), false], [Vector3(57.39, 15.55, 32.35), false], [Vector3(57.15, 15.69, 36.37), false],
	],
	# the courtyard's beams: [from, to (x, z, the lower tube's centre y at that end)]
	"beams": [[Vector3(41.81, 12.82, 23.66), Vector3(41.81, 12.97, 39.65)], [Vector3(57.85, 12.82, 24.59), Vector3(56.97, 12.97, 39.66)]],
	"cushion_top": 3.42,
}
## The door castle's left half (the right one its mirror about x = 48) and its bridge.
const DOOR := {
	"towers": [
		[Vector2(13.12, 7.34), Vector2(13.39, 7.33), 3.27, 13.42, 18.49, [Vector2(-1, 0), Vector2(0, -1)]],
		[Vector2(13.12, 22.48), Vector2(13.40, 22.48), 3.27, 13.42, 18.49, [Vector2(-1, 0), Vector2(0, 1)]],
		[Vector2(28.44, 7.47), Vector2(28.85, 7.47), 3.15, 17.48, 23.15, [Vector2(0, -1)]],
		[Vector2(28.46, 22.48), Vector2(28.85, 22.48), 3.14, 17.47, 23.15, [Vector2(0, 1)]],
	],
	"radii": Vector2(2.25, 2.51),
	"crown": 1.05,
	"walls": [
		[Vector2(11.93, 20.93), Vector2(11.93, 8.94), Vector2(-1, 0), 3.29, 12.78],
		[Vector2(14.68, 6.03), Vector2(26.67, 6.03), Vector2(0, -1), 3.22, 12.61],
		[Vector2(14.69, 23.87), Vector2(26.68, 23.87), Vector2(0, 1), 3.22, 12.61],
		[Vector2(27.85, 20.95), Vector2(27.85, 8.97), Vector2(-1, 0), 12.47, 14.64, STEP_WALL],
	],
	"roofs": [[Vector3(13.0, 12.78, 8.94), Vector3(14.88, 12.73, 6.91), Vector3(26.80, 12.50, 6.91), Vector3(28.69, 12.42, 8.97),
		Vector3(28.87, 12.27, 14.96), Vector3(28.69, 12.42, 20.95), Vector3(26.81, 12.50, 22.99), Vector3(14.89, 12.73, 22.99),
		Vector3(13.0, 12.78, 20.93), Vector3(12.81, 12.65, 14.94)]],
	"rings": [[Vector2(11.567, 5.809), Vector2(30.843, 5.838), Vector2(30.841, 24.129), Vector2(11.564, 24.074)]],
	"merlons": [[Vector3(28.71, 15.49, 11.85), false], [Vector3(28.63, 15.48, 17.53), false]],
	"cushion_top": 3.42,
}
## The door's bridge, symmetric about x = BRIDGE_X: its faces' arch (the face's lower edge from
## the foot of a leg to the middle: [dx, y]) and the tunnel under it (the same, 0.3 m into the
## opening); the faces' outer ends (dx), top (y at the middle, and how much higher at the ends),
## their z (front; the back mirrored about BRIDGE_Z; bowed out in the middle); the rounded top's
## inner edge (y at the middle, higher at the ends), the rounded top ([in, share of its height,
## row]: the cream band's edge, as the hall's); the tunnel's z; the battlements along it.
const BRIDGE_X := 48.0
const BRIDGE_Z := 14.96
const ARCH := [[16.73, 3.18], [16.56, 5.28], [16.47, 7.38], [16.25, 9.0], [15.83, 9.6], [15.11, 10.11], [14.19, 10.47],
	[12.23, 10.83], [8.2, 11.06], [0.0, 10.97]]
const TUNNEL := [[16.15, 3.245], [16.17, 5.33], [16.21, 7.41], [16.0, 9.02], [15.62, 9.54], [14.94, 10.0], [14.06, 10.31],
	[12.1, 10.68], [8.07, 10.9], [0.0, 10.73]]
const BRIDGE_END := 17.75
const BRIDGE_TOP := [12.86, 0.82]
const BRIDGE_FACE_Z := [6.05, 0.25]
const BRIDGE_IN := [14.11, 0.66]
const BRIDGE_ROUND := [[0.0, 0.0, 47.1], [0.07, 0.37, 54.3], [0.23, 0.67, 54.8], [0.48, 0.87, 55.8], [0.85, 1.0, 56.8]]
const BRIDGE_TUNNEL_Z := 6.56
const BRIDGE_ROOF_END := 19.53         ## the roof reaches the step walls' tops (dx)
## The face's rows: stone to the battlements' band at 11.05 m, the cream band from 11.58 m
const BRIDGE_BANDS := [11.05, 11.58]
const BRIDGE_MERLONS := [[-11.38, 15.2], [-5.59, 14.91], [0.17, 14.84], [5.76, 14.88], [11.44, 15.28]]   ## [dx, y], both rows
const BRIDGE_MERLON_Z := 6.93


static func build(geo: TmGeo, name: String) -> bool:
	match name:
		"Castle":
			_castle(geo, CASTLE, Callable())
		"CastleBig":
			_castle(geo, BIG, Callable())
			for b: Array in BIG["beams"]:
				_beam(geo, b[0], b[1])
		"InflatableCastleDoor":
			_castle(geo, DOOR, Callable())
			_castle(geo, DOOR, func(p: Vector3) -> Vector3: return Vector3(2.0 * BRIDGE_X - p.x, p.y, p.z))
			_bridge(geo)
		_:
			return false
	return true


## One castle's (or half castle's) parts; mirror (when valid) maps every point (TMNF x, y, z).
static func _castle(geo: TmGeo, c: Dictionary, mirror: Callable) -> void:
	var m := func(p: Vector3) -> Vector3: return p if not mirror.is_valid() else mirror.call(p)
	var m2 := func(p: Vector2) -> Vector2:
		var q: Vector3 = m.call(Vector3(p.x, 0.0, p.y))
		return Vector2(q.x, q.z)
	var md := func(d: Vector2) -> Vector2: return d if not mirror.is_valid() else Vector2(-d.x, d.y)
	var radii: Vector2 = c["radii"]
	for t: Array in c["towers"]:
		var dirs := []
		for d: Vector2 in t[5]:
			dirs.append(md.call(d))
		_tower(geo, m2.call(t[0]), m2.call(t[1]), t[2], t[3], t[4], radii.x, radii.y, c["crown"], dirs)
	for w: Array in c["walls"]:
		_wall(geo, m2.call(w[0]), m2.call(w[1]), md.call(w[2]), w[3], w[4], int(w[5]) if w.size() > 5 else KEEP_WALL)
	for r: Array in c["roofs"]:
		var pts := []
		for p: Vector3 in r:
			pts.append(m.call(p))
		_roof(geo, pts)
	for ring: Array in c["rings"]:
		var seams := []
		for p: Vector2 in ring:
			seams.append(m2.call(p))
		_cushion(geo, seams, c["cushion_top"])
	for mer: Array in c["merlons"]:
		_merlon(geo, m.call(mer[0]), mer[1])


## A tower: its shaft from its foot, the crown flaring out over the shaft's top (the cream band
## round it), the slate cone to the tip; TOWER_SIDES round its axis (leaning from the foot's
## centre c0 to the crown's c1); each half round (from +x to -x either way) carries the atlas
## across once. Then its ropes.
static func _tower(geo: TmGeo, c0: Vector2, c1: Vector2, y0: float, top: float, tip: float, rs: float, rc: float,
		crown: float, ropes: Array) -> void:
	var lean_top := top + 1.5
	var axis := func(y: float) -> Vector2: return c0.lerp(c1, clampf((y - y0) / (lean_top - y0), 0.0, 1.2))
	var prof := [[rs, y0, ROW_FOOT], [rs, lerpf(y0, top, 0.45), lerpf(ROW_FOOT, ROW_SHAFT_TOP, 0.45)], [rs * 0.97, top, ROW_SHAFT_TOP]]
	for k: Array in CROWN:
		prof.append([rc * float(k[0]), top + float(k[1]) * crown, k[2]])
	var cone := [prof[prof.size() - 1], [0.3, tip - 0.11, 3.0], [0.0, tip, 0.5]]
	for part: Array in [prof, cone]:
		for half in 2:
			var pts := []
			var uvs := []
			for q: Array in part:
				var row := []
				var urow := []
				var c: Vector2 = axis.call(float(q[1]))
				for k in TOWER_SIDES / 2 + 1:
					# u grows with the angle (to the right seen from outside)
					var th := (0.0 if half == 0 else PI) - PI * k / (TOWER_SIDES / 2)
					row.append(Vector3(c.x + float(q[0]) * cos(th), float(q[1]), c.y + float(q[0]) * sin(th)))
					urow.append(Vector2(lerpf(TOWER_U.y, TOWER_U.x, float(k) / (TOWER_SIDES / 2)), float(q[2]) / 512.0))
				pts.append(row)
				uvs.append(urow)
			_grid(geo, pts, uvs, KEY, S_RUBBER, false)
	for d: Vector2 in ropes:
		var c: Vector2 = axis.call(ROPE_Y)
		var a := c + d * rs
		var b := a + d * ROPE_RUN
		geo.pipe(Vector3(b.x, 1.0, b.y), Vector3(a.x, ROPE_Y, a.y), 0.05, 4, ROPE_KEY, S_RUBBER)


## A wall between two towers: its stone face from the outer foot line a -> b up to the top, rounded
## over inward to the top's inner edge (WALL, WALL_HALL by kind), each pillow about WALL_PILLOW long
## bulging out in its middle.
static func _wall(geo: TmGeo, a: Vector2, b: Vector2, out: Vector2, y0: float, top: float, kind: int) -> void:
	var prof: Array = WALL if kind == KEEP_WALL else WALL_HALL
	var row0 := ROW_BAND if kind == STEP_WALL else ROW_FOOT
	var n := maxi(1, roundi(a.distance_to(b) / WALL_PILLOW))
	var right := _right(out)
	var cols := 8
	for p in n:
		var pts := []
		var uvs := []
		for k: int in prof.size():
			var s: Array = prof[k]
			var y := y0 if k == 0 else top - float(s[1])
			var row := []
			var urow := []
			for j in cols + 1:
				var t := (p + float(j) / cols) / n
				var q := a.lerp(b, t) + out * (WALL_BULGE * sin(PI * float(j) / cols) - float(s[0]))
				row.append(Vector3(q.x, y, q.y))
				var u := float(j) / cols
				urow.append(Vector2(u if (b - a).dot(right) > 0.0 else 1.0 - u, (row0 if k == 0 else float(s[2])) / 512.0))
			pts.append(row)
			uvs.append(urow)
		var d := b - a
		_grid(geo, pts, uvs, KEY, S_RUBBER, -d.y * out.x + d.x * out.y < 0.0)


## A roof (or a floor): the outline's points (x, y, z), quilted tiles ROOF_TILE m, facing up.
static func _roof(geo: TmGeo, pts: Array) -> void:
	var poly := PackedVector2Array()
	for p: Vector3 in pts:
		poly.append(Vector2(p.x, p.z))
	var idx := Geometry2D.triangulate_polygon(poly)
	for k in range(0, idx.size(), 3):
		var tri := [pts[idx[k]], pts[idx[k + 1]], pts[idx[k + 2]]]
		if ((tri[1] - tri[0]) as Vector3).cross(tri[2] - tri[0]).y < 0.0:
			tri = [tri[0], tri[2], tri[1]]
		var uv := []
		for p: Vector3 in tri:
			uv.append(Vector2(p.x, p.z) / ROOF_TILE + Vector2(1e-4, 0.0))
		geo.tri(tri[0], tri[1], tri[2], ROOF_KEY, S_RUBBER, Vector3.UP, Vector3.UP, Vector3.UP, uv[0], uv[1], uv[2])


## A ring of cushion pillows round a keep: between each two seams (in order round the ring) a
## pillow bulging out of the seam line (PILLOW), its section (CUSHION; top at `top`) pinched upright
## at the seams, the atlas across it once (our board in its middle), a grey skirt under it.
static func _cushion(geo: TmGeo, seams: Array, top: float) -> void:
	var area := 0.0
	for i in seams.size():
		var p: Vector2 = seams[i]
		var q: Vector2 = seams[(i + 1) % seams.size()]
		area += p.x * q.y - q.x * p.y
	for i in seams.size():
		var a: Vector2 = seams[i]
		var b: Vector2 = seams[(i + 1) % seams.size()]
		var d := b - a
		var length := d.length()
		var dir := d / length
		var out := Vector2(dir.y, -dir.x) * (1.0 if area > 0.0 else -1.0)
		var right := _right(out)
		# the outline's points along the pillow: [along, out]
		var line := []
		for q: Array in PILLOW:
			if float(q[0]) < length * 0.5:
				line.append([float(q[0]), float(q[1])])
		line.append([length * 0.5, PILLOW_MID])
		for k in range(PILLOW.size() - 1, -1, -1):
			if float(PILLOW[k][0]) < length * 0.5:
				line.append([length - float(PILLOW[k][0]), float(PILLOW[k][1])])
		var pts := []
		var uvs := []
		var skirt := []
		var skirt_uv := []
		var k_top := (top - 2.28) / (3.54 - 2.28)
		for s: Array in CUSHION:
			var row := []
			var urow := []
			for l: Array in line:
				var share := float(l[1]) / PILLOW_MID
				var q := a + dir * float(l[0]) + out * (float(l[1]) - float(s[0]) * share)
				var y := float(s[1]) if float(s[1]) <= 2.28 else 2.28 + (float(s[1]) - 2.28) * k_top
				row.append(Vector3(q.x, y, q.y))
				var u := float(l[0]) / length
				urow.append(Vector2(u if dir.dot(right) > 0.0 else 1.0 - u, float(s[2]) / 512.0))
			pts.append(row)
			uvs.append(urow)
		for j in 2:
			var row := []
			var urow := []
			for l: Array in line:
				var share := float(l[1]) / PILLOW_MID
				var inn := 0.02 * share if j == 1 else float(SKIRT[0]) + float(SKIRT[1]) * share
				var q := a + dir * float(l[0]) + out * (float(l[1]) - inn)
				row.append(Vector3(q.x, float(SKIRT[2]) if j == 0 else 1.42, q.y))
				urow.append(Vector2(float(l[0]) / ROOF_TILE, (float(SKIRT[2]) if j == 0 else 1.42) / ROOF_TILE))
			skirt.append(row)
			skirt_uv.append(urow)
		var flip := -d.y * out.x + d.x * out.y < 0.0
		_grid(geo, pts, uvs, KEY, S_RUBBER, flip)
		_grid(geo, skirt, skirt_uv, ROOF_KEY, S_RUBBER, flip)


## A battlement: a block MERLON rounded at its corners and over its top, centred at c, its length
## along x (or z); stone from the atlas.
static func _merlon(geo: TmGeo, c: Vector3, along_x: bool) -> void:
	var hl := float(MERLON[0]) * 0.5
	var hw := float(MERLON[2]) * 0.5
	var r := float(MERLON[3])
	var h := float(MERLON[1])
	var loop := []
	for corner in 4:
		var cc := Vector2(hl - r if corner == 0 or corner == 3 else -hl + r, hw - r if corner < 2 else -hw + r)
		for s in 4:
			var th := PI * 0.5 * corner + PI * 0.5 * s / 3.0
			loop.append(cc + Vector2(cos(th), sin(th)) * r)
	loop.append(loop[0])
	var total := 0.0
	for i in loop.size() - 1:
		total += (loop[i + 1] as Vector2).distance_to(loop[i])
	# rings up the block: its foot (hidden in the wall's top), straight up, then rounding in
	var rings := [[0.0, -h * 0.5, 300.0], [0.0, h * 0.25, 200.0], [0.12, h * 0.42, 160.0], [0.3, h * 0.5, 140.0]]
	var pts := []
	var uvs := []
	for ring: Array in rings:
		var row := []
		var urow := []
		var acc := 0.0
		for i in loop.size():
			if i > 0:
				acc += (loop[i] as Vector2).distance_to(loop[i - 1])
			var q: Vector2 = loop[i]
			var sh := (1.0 - float(ring[0]) / minf(hl, hw))
			var p := Vector2(q.x * sh, q.y * sh)
			row.append(Vector3(c.x + (p.x if along_x else p.y), c.y + float(ring[1]), c.z + (p.y if along_x else p.x)))
			urow.append(Vector2(acc / total * 2.0, float(ring[2]) / 512.0))
		pts.append(row)
		uvs.append(urow)
	# the loop runs anticlockwise seen from above when along x (clockwise along z: mirrored)
	_grid(geo, pts, uvs, KEY, S_RUBBER, along_x)
	var lid := PackedVector2Array()
	var last: Array = pts[pts.size() - 1]
	for i in last.size() - 1:
		lid.append(Vector2((last[i] as Vector3).x, (last[i] as Vector3).z))
	var y := c.y + float(rings[rings.size() - 1][1])
	var idx := Geometry2D.triangulate_polygon(lid)
	for k in range(0, idx.size(), 3):
		var t := [Vector3(lid[idx[k]].x, y, lid[idx[k]].y), Vector3(lid[idx[k + 1]].x, y, lid[idx[k + 1]].y),
			Vector3(lid[idx[k + 2]].x, y, lid[idx[k + 2]].y)]
		if ((t[1] - t[0]) as Vector3).cross(t[2] - t[0]).y < 0.0:
			t = [t[0], t[2], t[1]]
		var uv := []
		for p: Vector3 in t:
			uv.append(Vector2(0.3 + (p.x - c.x) * 0.1, (150.0 + (p.z - c.z) * 20.0) / 512.0))
		geo.tri(t[0], t[1], t[2], KEY, S_RUBBER, Vector3.UP, Vector3.UP, Vector3.UP, uv[0], uv[1], uv[2])


## The big castle's courtyard beam from a to b (the lower tube's centre at each end; it sags 0.38 m
## in the middle): two tubes one on the other, the lower showing the cream band on each side (our
## name reading from either side), the upper stone; its battlements are listed with the castle's.
static func _beam(geo: TmGeo, a: Vector3, b: Vector3) -> void:
	var along := Vector2(b.x - a.x, b.z - a.z)
	var side := Vector2(along.y, -along.x).normalized()
	var n := 12
	var tubes := [[0.0, Vector2(0.75, 0.67), Vector2(ROW_BAND - 3.0, ROW_BAND_TOP + 4.0)], [1.53, Vector2(0.755, 0.755), Vector2(409.0, 355.0)]]
	for tube: Array in tubes:
		var lift := float(tube[0])
		var size: Vector2 = tube[1]
		var rows: Vector2 = tube[2]
		for s in 2:
			var sgn := 1.0 if s == 0 else -1.0
			var pts := []
			var uvs := []
			for i in n + 1:
				var t := float(i) / n
				var c := a.lerp(b, t) + Vector3(0, lift - 0.38 * sin(PI * t) * (1.0 if lift == 0.0 else 0.8), 0)
				var row := []
				var urow := []
				for k in 7:
					# from the bottom round this side to the top
					var th := -PI * 0.5 + PI * k / 6.0
					var o := side * sgn * size.x * cos(th)
					row.append(Vector3(c.x + o.x, c.y + size.y * sin(th), c.z + o.y))
					var right := _right(side * sgn)
					var u := t if along.dot(right) > 0.0 else 1.0 - t
					urow.append(Vector2(u, lerpf(rows.x, rows.y, float(k) / 6.0) / 512.0))
				pts.append(row)
				uvs.append(urow)
			# rows along the beam, columns round the section: front = (round) x (along) = -nrm
			var probe := (pts[0][4] as Vector3) - (pts[0][3] as Vector3)
			var fwd := (pts[1][3] as Vector3) - (pts[0][3] as Vector3)
			var nrm := fwd.cross(probe)
			_grid(geo, pts, uvs, KEY, S_RUBBER, nrm.dot(Vector3(side.x * sgn, 0, side.y * sgn)) > 0.0)


## The door's bridge over the road between the keeps' tall towers: its two faces (stone legs and
## arch, the battlements' band, the cream band printed once on each half), the lip into the
## tunnel under the arch, the tunnel, the rounded top, the roof, the battlements, the step walls
## over the keeps' roofs (with the keeps' parts).
static func _bridge(geo: TmGeo) -> void:
	var face_z := func(dx: float) -> float: return BRIDGE_FACE_Z[0] + BRIDGE_FACE_Z[1] * pow(dx / BRIDGE_END, 2.0)
	var top_y := func(dx: float) -> float: return BRIDGE_TOP[0] + BRIDGE_TOP[1] * pow(dx / BRIDGE_END, 2.0)
	var in_y := func(dx: float) -> float: return BRIDGE_IN[0] + BRIDGE_IN[1] * pow(minf(absf(dx), BRIDGE_END) / BRIDGE_END, 2.0)
	# the arch's whole lower edge and the tunnel's, left leg to right leg
	var arch := []
	var tunnel := []
	for q: Array in ARCH:
		arch.append(Vector2(-float(q[0]), float(q[1])))
	for q: Array in TUNNEL:
		tunnel.append(Vector2(-float(q[0]), float(q[1])))
	for k in range(ARCH.size() - 2, -1, -1):
		arch.append(Vector2(float(ARCH[k][0]), float(ARCH[k][1])))
		tunnel.append(Vector2(float(TUNNEL[k][0]), float(TUNNEL[k][1])))
	# the face's outline (dx, y): up the left end, along the top, down the right end, back under the arch
	var outline := PackedVector2Array([Vector2(-BRIDGE_END, 3.17)])
	var steps := 16
	for k in steps + 1:
		var dx := lerpf(-BRIDGE_END, BRIDGE_END, float(k) / steps)
		outline.append(Vector2(dx, top_y.call(dx)))
	outline.append(Vector2(BRIDGE_END, 3.17))
	for k in range(arch.size() - 1, -1, -1):
		outline.append(arch[k])
	var bands := [[2.0, BRIDGE_BANDS[0]], [BRIDGE_BANDS[0], BRIDGE_BANDS[1]], [BRIDGE_BANDS[1], 20.0]]
	for side in 2:
		var zf := func(dx: float) -> float: return face_z.call(dx) if side == 0 else 2.0 * BRIDGE_Z - float(face_z.call(dx))
		var out := Vector3(0, 0, -1 if side == 0 else 1)
		for bi in bands.size():
			for half in 2:
				var rect := PackedVector2Array([Vector2(-BRIDGE_END - 1.0 if half == 0 else 0.0, bands[bi][0]),
					Vector2(0.0 if half == 0 else BRIDGE_END + 1.0, bands[bi][0]), Vector2(0.0 if half == 0 else BRIDGE_END + 1.0, bands[bi][1]),
					Vector2(-BRIDGE_END - 1.0 if half == 0 else 0.0, bands[bi][1])])
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(outline, rect):
					var idx := Geometry2D.triangulate_polygon(piece)
					for k in range(0, idx.size(), 3):
						var t := []
						var uv := []
						for m in 3:
							var q := piece[idx[k + m]]
							t.append(Vector3(BRIDGE_X + q.x, q.y, zf.call(q.x)))
							uv.append(_bridge_uv(q, bi, half, side, top_y.call(q.x)))
						_tri_out(geo, t, uv, out)
		# the lip from the face's arch edge into the tunnel
		var tz := BRIDGE_TUNNEL_Z if side == 0 else 2.0 * BRIDGE_Z - BRIDGE_TUNNEL_Z
		for k in arch.size() - 1:
			var p := [Vector3(BRIDGE_X + arch[k].x, arch[k].y, zf.call(arch[k].x)), Vector3(BRIDGE_X + arch[k + 1].x, arch[k + 1].y, zf.call(arch[k + 1].x)),
				Vector3(BRIDGE_X + tunnel[k + 1].x, tunnel[k + 1].y, tz), Vector3(BRIDGE_X + tunnel[k].x, tunnel[k].y, tz)]
			var mid := Vector3(BRIDGE_X, 6.0, (p[0] as Vector3).z)
			var o: Vector3 = ((p[0] + p[1]) * 0.5 - mid) * Vector3(-1, -1, 0) + out * 0.5
			var uv := []
			for q: Vector3 in p:
				uv.append(_stone_uv(q, side))
			_quad_out(geo, p, uv, o)
		# the rounded top from the face's top to the roof's edge
		var pts := []
		var uvs := []
		for r: Array in BRIDGE_ROUND:
			var row := []
			var urow := []
			for k in steps + 1:
				var dx := lerpf(-BRIDGE_END, BRIDGE_END, float(k) / steps)
				var y := lerpf(top_y.call(dx), in_y.call(dx), float(r[1]))
				var z: float = float(zf.call(dx)) - float(out.z) * float(r[0])
				row.append(Vector3(BRIDGE_X + dx, y, z))
				urow.append(Vector2(float(k) / steps * 2.0, float(r[2]) / 512.0))
			pts.append(row)
			uvs.append(urow)
		_grid(geo, pts, uvs, KEY, S_RUBBER, side == 0)
	# the tunnel under the arch, facing into the opening
	var tpts := []
	var tuvs := []
	for z: float in [BRIDGE_TUNNEL_Z, 2.0 * BRIDGE_Z - BRIDGE_TUNNEL_Z]:
		var row := []
		var urow := []
		for q: Vector2 in tunnel:
			var p := Vector3(BRIDGE_X + q.x, q.y, z)
			row.append(p)
			var uv := _stone_uv(p, 0)
			if q.y > 9.6:
				uv = Vector2((z - BRIDGE_TUNNEL_Z) / 15.2, (160.0 + absf(q.x) * 15.0) / 512.0)
			else:
				uv.x = (z - BRIDGE_TUNNEL_Z) / 15.2
			urow.append(uv)
		tpts.append(row)
		tuvs.append(urow)
	_grid(geo, tpts, tuvs, KEY, S_RUBBER, false)
	# the roof, sagging with the top, from step wall to step wall
	var roof := []
	var ruv := []
	var zin := BRIDGE_FACE_Z[0] + float(BRIDGE_ROUND[BRIDGE_ROUND.size() - 1][0])
	for z: float in [2.0 * BRIDGE_Z - zin, zin]:
		var row := []
		var urow := []
		for k in steps + 1:
			var dx := lerpf(-BRIDGE_ROOF_END, BRIDGE_ROOF_END, float(k) / steps)
			var zz: float = z + (float(face_z.call(minf(absf(dx), BRIDGE_END))) - BRIDGE_FACE_Z[0]) * (1.0 if z < BRIDGE_Z else -1.0)
			row.append(Vector3(BRIDGE_X + dx, in_y.call(dx), zz))
			urow.append(Vector2((BRIDGE_X + dx) / ROOF_TILE, zz / ROOF_TILE))
		roof.append(row)
		ruv.append(urow)
	_grid(geo, roof, ruv, ROOF_KEY, S_RUBBER, false)
	for q: Array in BRIDGE_MERLONS:
		for z: float in [BRIDGE_MERLON_Z, 2.0 * BRIDGE_Z - BRIDGE_MERLON_Z]:
			_merlon(geo, Vector3(BRIDGE_X + float(q[0]), float(q[1]), z), true)


## The bridge face's UV at (dx, y) in band bi (stone, battlements, cream) on half `half` of side.
static func _bridge_uv(q: Vector2, bi: int, half: int, side: int, top: float) -> Vector2:
	if bi == 0:
		return _stone_uv(Vector3(BRIDGE_X + q.x, q.y, 0.0), side)
	if bi == 1:
		var r := lerpf(ROW_SHAFT_TOP, ROW_BAND, (q.y - BRIDGE_BANDS[0]) / (BRIDGE_BANDS[1] - BRIDGE_BANDS[0]))
		return Vector2(_stone_uv(Vector3(BRIDGE_X + q.x, q.y, 0.0), side).x, r / 512.0)
	# the cream band: once across each half, reading left to right from outside
	var t := (q.x + BRIDGE_END) / BRIDGE_END if half == 0 else q.x / BRIDGE_END
	var u := t if side == 0 else 1.0 - t
	var r := lerpf(ROW_BAND, ROW_BAND_TOP, clampf((q.y - BRIDGE_BANDS[1]) / maxf(top - BRIDGE_BANDS[1], 0.1), 0.0, 1.0))
	return Vector2(u + 1e-4, r / 512.0)


## Stone on the bridge: rows by height (the face's foot to the battlements' band), u 15.2 m a tile
## running to the right seen from the front (side 0) or the back.
static func _stone_uv(p: Vector3, side: int) -> Vector2:
	var r := lerpf(ROW_FOOT, ROW_SHAFT_TOP, clampf((p.y - 3.17) / (BRIDGE_BANDS[0] - 3.17), 0.0, 1.0))
	var u := (p.x - BRIDGE_X + BRIDGE_END) / 15.2 if side == 0 else (BRIDGE_X + BRIDGE_END - p.x) / 15.2
	return Vector2(u + 1e-4, r / 512.0)


## The right hand of someone outside looking at a face that looks `out` (x, z): TMNF's
## coordinates are seen mirrored here (TmGeo.g), so it is +x for a face looking toward -z.
static func _right(out: Vector2) -> Vector2:
	return Vector2(-out.y, out.x)


## A triangle facing `out` with its UVs.
static func _tri_out(geo: TmGeo, t: Array, uv: Array, out: Vector3) -> void:
	var n := ((t[1] - t[0]) as Vector3).cross(t[2] - t[0])
	if n.dot(out) < 0.0:
		t = [t[0], t[2], t[1]]
		uv = [uv[0], uv[2], uv[1]]
		n = -n
	n = n.normalized()
	geo.tri(t[0], t[1], t[2], KEY, S_RUBBER, n, n, n, uv[0], uv[1], uv[2])


## A quad (corners in order round) facing `out` with its UVs.
static func _quad_out(geo: TmGeo, p: Array, uv: Array, out: Vector3) -> void:
	_tri_out(geo, [p[0], p[1], p[2]], [uv[0], uv[1], uv[2]], out)
	_tri_out(geo, [p[0], p[2], p[3]], [uv[0], uv[2], uv[3]], out)


## A grid of quads (rows of points, all rows as long, with their UVs) shaded round: each point's
## normal the mean of its quads'. Front = (next point along the row - this) x (the next row's -
## this), turned round when flip.
static func _grid(geo: TmGeo, pts: Array, uvs: Array, key: String, surface: int, flip: bool) -> void:
	var nr := pts.size()
	var nc := (pts[0] as Array).size()
	var acc := []
	for i in nr:
		var row := []
		row.resize(nc)
		row.fill(Vector3.ZERO)
		acc.append(row)
	for i in nr - 1:
		for j in nc - 1:
			var n := ((pts[i + 1][j + 1] as Vector3) - (pts[i][j] as Vector3)).cross((pts[i + 1][j] as Vector3) - (pts[i][j + 1] as Vector3))
			# (c - a) x (d - b) points the way the quad's front (b - a) x (d - a) does
			n *= -1.0 if flip else 1.0
			for q: Vector2i in [Vector2i(i, j), Vector2i(i, j + 1), Vector2i(i + 1, j), Vector2i(i + 1, j + 1)]:
				acc[q.x][q.y] = (acc[q.x][q.y] as Vector3) + n
	for i in nr - 1:
		for j in nc - 1:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j + 1]
			var c: Vector3 = pts[i + 1][j + 1]
			var d: Vector3 = pts[i + 1][j]
			var na: Vector3 = (acc[i][j] as Vector3).normalized()
			var nb: Vector3 = (acc[i][j + 1] as Vector3).normalized()
			var nc_: Vector3 = (acc[i + 1][j + 1] as Vector3).normalized()
			var nd: Vector3 = (acc[i + 1][j] as Vector3).normalized()
			var ua: Vector2 = uvs[i][j]
			var ub: Vector2 = uvs[i][j + 1]
			var uc: Vector2 = uvs[i + 1][j + 1]
			var ud: Vector2 = uvs[i + 1][j]
			if flip:
				geo.tri(a, c, b, key, surface, na, nc_, nb, ua, uc, ub)
				geo.tri(a, d, c, key, surface, na, nd, nc_, ua, ud, uc)
			else:
				geo.tri(a, b, c, key, surface, na, nb, nc_, ua, ub, uc)
				geo.tri(a, c, d, key, surface, na, nc_, nd, ua, uc, ud)
