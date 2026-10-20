extends RefCounted
## Stadium dirt roads (Road/Dirt: a track sunk 0.6 m into the grass between low berms; Road/DirtHigh:
## one raised on a 7.4 m embankment), their hills, tilts, curves and transitions. TMNF's pieces are
## hand-sculpted terrain, so each is our own bicubic surface through measured control heights 2 m
## apart over its footprint, grass, dirt or asphalt per 2 m cell (blocks/data/dirt_heights.json, from
## tools/research/tmnf/terrain_heights.py). The checkpoints are the straight's terrain under a
## gate standing on TMNF's two rubber bumpers; where a dirt road meets the road, TMNF's curbs
## (_to_road_curbs). The pieces' furniture where TMNF has it (_furniture: advert boards and bands,
## kiosks, inflatable bumpers) at TMNF's measured places (blocks/data/dirt_furniture.json, from
## tools/research/tmnf/dirt_furniture.py), ours to look at.

const RoadShapes := preload("res://blocks/shapes/road.gd")
const SculptShapes := preload("res://blocks/shapes/sculpt.gd")

const S_GRASS := 2
const S_DIRT := 6
const S_ROAD := 16
## Survey cell class -> [material, surface id]: grass, dirt (the track, its berms loose dirt: the
## material blends by slope) and the asphalt where a piece meets Road/Main.
const CLASSES := {"g": ["grass", S_GRASS], "d": ["dirt_road", S_DIRT], "r": ["asphalt", S_ROAD]}
const PATH := "res://blocks/data/dirt_heights.json"
const QUAD := 1.0               ## render/collision quad size (m)
const GRASS_EPS := 0.05         ## how far off the grass level (1 m) a corner still counts as on it
## Checkpoints: the terrain they stand on, and the Road/Main gate resized for them as TMNF's
## (measured): how far it is raised, its width's scale about the centre line; along z all alike
## (GATE_Z_SCALE about the block's centre, then GATE_Z_MOVE further); the clamps' straps lower
## (GATE_STRAP_DY: on the bumpers).
const CHECKPOINTS := {
	"Road/Dirt/RoadDirtCheckpoint/Ground": ["Road/Dirt/StraightGround", 1.075, 1.042],
	"Road/DirtHigh/RoadDirtCheckpointHigh/Ground": ["Road/DirtHigh/StraightGround", 5.78, 0.891],
}
const GATE_Z_SCALE := 0.963
const GATE_Z_MOVE := 0.119
const GATE_STRAP_DY := -1.345

## Where a dirt road meets Road/Main (TMNF's RoadDirtToRoad, measured): the road's ground curbs
## along both sides, full up to TO_ROAD_FULL, then a narrower, lower curb running into the dirt's
## berm (the section's d mapped to TO_ROAD_D.x + (d - 1) * TO_ROAD_D.y, its height above 1 m scaled
## by TO_ROAD_H, sinking TO_ROAD_SINK more by the block's end).
const TO_ROAD := ["Road/Dirt/RoadDirtToRoad/Ground"]
const TO_ROAD_FULL := 17.0
const TO_ROAD_D := Vector2(1.97, 0.476)
const TO_ROAD_H := 0.8
## The furniture: placements (FURNITURE_PATH: per shape, boards [kind, four corners], bumpers
## [kind, width, height, centre line], kiosks' legs [kind, corners (x, z), y0, y1]); the boards'
## white frame (FRAME_MARGIN round them, FRAME_T thick), their props (PROP_BACK behind them, from
## PROP_UP of their height down to their foot) toward the piece's middle; the bumpers BUMPER_SIDES
## round.
const FURNITURE_PATH := "res://blocks/data/dirt_furniture.json"
const FRAME_MARGIN := 0.15
const FRAME_T := 0.08
const PROP_BACK := 1.3
const PROP_UP := 0.8
const BUMPER_SIDES := 10
const S_METAL := 4
const S_RUBBER := 9
const TO_ROAD_SINK := 0.3

## The dirt checkpoint's bumpers (TMNF's, measured): along each side (z GATE_BUMPER_Z) a rounded
## dark rubber bumper the arch's feet stand on, a ribbed top; its section (x from the block edge,
## y, key, the atlas' rows from the point to the next) round to its buried bottom. Its rounded
## faces carry the CHECKPOINT sign as TMNF's (bumper_cp: the road gates' curbs' sign, its word
## every 5 m; its rows spread over each face by its length, the top row at the top; mirrored on
## the outer face).
const GATE_BUMPER_Z := Vector2(1.04, 30.93)
const GATE_BUMPER := [
	[0.56, 0.82, "road_metal", Vector2(-1, -1)], [0.56, 1.21, "bumper_cp_out", Vector2(512.0, 318.8)],
	[0.71, 1.7, "bumper_cp_out", Vector2(318.8, 192.4)], [0.81, 2.02, "bumper_cp_out", Vector2(192.4, 104.6)],
	[0.97, 2.19, "bumper_cp_out", Vector2(104.6, 0.0)], [1.22, 2.31, "border_ribs", Vector2(160.0, 200.0)],
	[3.56, 2.33, "bumper_cp", Vector2(0.0, 107.8)], [3.81, 2.19, "bumper_cp", Vector2(107.8, 193.1)],
	[3.96, 2.02, "bumper_cp", Vector2(193.1, 319.2)], [4.06, 1.7, "bumper_cp", Vector2(319.2, 512.0)],
	[4.21, 1.21, "road_metal", Vector2(-1, -1)], [4.21, 0.82, "", Vector2(-1, -1)],
]

static var _shapes: Dictionary = {}
static var _furniture_data: Dictionary = {}


static func furniture() -> Dictionary:
	if _furniture_data.is_empty():
		var f := FileAccess.open(FURNITURE_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_furniture_data = (parsed as Dictionary).get("shapes", {})
	return _furniture_data


static func shapes() -> Dictionary:
	if _shapes.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_shapes = (parsed as Dictionary).get("shapes", {})
	return _shapes


func handles(shape: String) -> bool:
	return shapes().has(shape) or CHECKPOINTS.has(shape)


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var geo := TmGeo.new()
	if CHECKPOINTS.has(shape):
		var c: Array = CHECKPOINTS[shape]
		_surface(geo, shapes()[c[0]])
		var gate := TmGeo.new()
		RoadShapes.new()._gate(gate, 16.0, GATE_STRAP_DY)
		gate.scale_move(Vector3(16, 0, 16), Vector3(float(c[2]), 1.0, GATE_Z_SCALE), Vector3(0.0, float(c[1]), GATE_Z_MOVE))
		geo.merge(gate)
		if shape.begins_with("Road/Dirt/"):
			_gate_bumpers(geo)
	elif shapes().has(shape):
		_surface(geo, shapes()[shape])
		if shape in TO_ROAD:
			_to_road_curbs(geo)
	else:
		return null
	if shapes().has(shape) and furniture().has(shape):
		var sd: Dictionary = shapes()[shape]
		_furniture(geo, furniture()[shape], Vector2(float(sd["w"]), float(sd["d"])))
	var node := geo.build()
	if CHECKPOINTS.has(shape):
		var c: Array = CHECKPOINTS[shape]
		TmGateDress.crown(node, "cp", 16.0 + GATE_Z_MOVE, Vector3(0.0, 0.0, float(c[1])), true,
			Vector3(float(c[2]), 1.0, GATE_Z_SCALE))
	return node


## The surface through a shape's control grid, QUAD m quads, grass or dirt by the grid cell.
func _surface(geo: TmGeo, s: Dictionary) -> void:
	var g: Array = s["g"]
	var cls: Array = s["cls"]
	var step := float(s["step"])
	var nx := int(round(float(s["w"]) / QUAD))
	var nz := int(round(float(s["d"]) / QUAD))
	var pts := []
	for j in nz + 1:
		var row := []
		for i in nx + 1:
			var x := i * QUAD
			var z := j * QUAD
			row.append(Vector3(x, _bicubic(g, step, x, z), z))
		pts.append(row)
	for j in nz:
		for i in nx:
			var cj := mini(int((j + 0.5) * QUAD / step), cls.size() - 1)
			var line := String(cls[cj])
			var ci := mini(int((i + 0.5) * QUAD / step), line.length() - 1)
			var c := line[ci]
			var q := [pts[j][i], pts[j + 1][i], pts[j + 1][i + 1], pts[j][i + 1]]
			# the dirt follows the ground's shape, as TMNF's meshes do, not the survey's 2 m cells
			# (their staircase): next to dirt, the ground off the grass's level is dirt and on it
			# grass, the line between them cut through the quads along the level
			if c == "d" or (c == "g" and _near_dirt(cls, cj, ci)):
				_split_tri(geo, q[0], q[1], q[2], cls, step)
				_split_tri(geo, q[0], q[2], q[3], cls, step)
				continue
			var m: Array = CLASSES.get(c, CLASSES["d"])
			geo.quad(q[0], q[1], q[2], q[3], m[0], m[1])


## A triangle of the terrain cut where it leaves the grass's level (|y - 1| = GRASS_EPS) or the
## survey's dirt (its cells' dirt, 1, or not, 0, interpolated between their centres: dirt over
## one half): dirt off the level or on the survey's dirt, grass elsewhere. (Dirt at the grass's
## level, as the inside of TMNF's curves, stays dirt; its edge runs smoothly between the cells.)
func _split_tri(geo: TmGeo, a: Vector3, b: Vector3, c: Vector3, cls: Array, step: float) -> void:
	var tri := [a, b, c]
	var off := func(p: Vector3) -> float: return maxf(absf(p.y - 1.0) - GRASS_EPS, _dirt_at(cls, step, p.x, p.z) - 0.5)
	var dirt := []
	var grass := []
	for k in 3:
		var p: Vector3 = tri[k]
		var r: Vector3 = tri[(k + 1) % 3]
		var dp: float = off.call(p)
		var dr: float = off.call(r)
		if dp > 0.0:
			dirt.append(p)
		else:
			grass.append(p)
		if (dp > 0.0) != (dr > 0.0):
			var m := p.lerp(r, dp / (dp - dr))
			dirt.append(m)
			grass.append(m)
	for poly: Array in [[dirt, CLASSES["d"]], [grass, CLASSES["g"]]]:
		var pp: Array = poly[0]
		for k in range(1, pp.size() - 1):
			geo.tri(pp[0], pp[k], pp[k + 1], poly[1][0], poly[1][1])


## The survey's dirt at (x, z): its cells' dirt (1) or not (0) interpolated between their centres.
static func _dirt_at(cls: Array, step: float, x: float, z: float) -> float:
	var fx := x / step - 0.5
	var fz := z / step - 0.5
	var i := floori(fx)
	var j := floori(fz)
	var tx := fx - i
	var tz := fz - j
	var cell := func(jj: int, ii: int) -> float:
		var line := String(cls[clampi(jj, 0, cls.size() - 1)])
		return 1.0 if line[clampi(ii, 0, line.length() - 1)] == "d" else 0.0
	var top := lerpf(cell.call(j, i), cell.call(j, i + 1), tx)
	var bot := lerpf(cell.call(j + 1, i), cell.call(j + 1, i + 1), tx)
	return lerpf(top, bot, tz)


## Whether a survey cell (row j, column i) touches a dirt cell (its eight neighbours).
static func _near_dirt(cls: Array, j: int, i: int) -> bool:
	for dj in [-1, 0, 1]:
		for di in [-1, 0, 1]:
			var jj: int = j + dj
			var ii: int = i + di
			if jj >= 0 and jj < cls.size() and ii >= 0 and ii < String(cls[jj]).length() and String(cls[jj])[ii] == "d":
				return true
	return false


static func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


## Catmull-Rom through the grid both ways (rows along z, columns along x, `step` m apart).
static func _bicubic(g: Array, step: float, x: float, z: float) -> float:
	var nz := g.size()
	var nx := (g[0] as Array).size()
	var fx := x / step
	var fz := z / step
	var i := mini(int(fx), nx - 2)
	var j := mini(int(fz), nz - 2)
	var at := func(jj: int, ii: int) -> float: return float(g[clampi(jj, 0, nz - 1)][clampi(ii, 0, nx - 1)])
	var rows := []
	for k in [-1, 0, 1, 2]:
		rows.append(_cr(at.call(j + k, i - 1), at.call(j + k, i), at.call(j + k, i + 1), at.call(j + k, i + 2), fx - i))
	return _cr(rows[0], rows[1], rows[2], rows[3], fz - j)


## TMNF's curbs where the dirt meets the road (TO_ROAD_*): both sides, the full curb then the narrow
## one sinking into the berm.
func _to_road_curbs(geo: TmGeo) -> void:
	var curb: Array = RoadShapes.new()._curb_section(true)
	var lat := [Vector3(1, 0, 0), Vector3(1, 0, 0)]
	for side: float in [1.0, -1.0]:
		var full := curb.map(func(q: Array) -> Array:
			var p: Vector2 = q[0]
			return [Vector2((p.x - 16.0) * side, p.y), q[1], q[2]] + q.slice(3))
		geo.wall_sweep(full, [Vector3(16, 0, 0), Vector3(16, 0, TO_ROAD_FULL)], lat, true, "road_metal", 4)
		var narrow := curb.map(func(q: Array) -> Array:
			var p: Vector2 = q[0]
			var d := TO_ROAD_D.x + (p.x - 1.0) * TO_ROAD_D.y
			return [Vector2((d - 16.0) * side, 1.0 + (p.y - 1.0) * TO_ROAD_H), q[1], q[2]] + q.slice(3))
		geo.wall_sweep(narrow, [Vector3(16, 0, TO_ROAD_FULL), Vector3(16, -TO_ROAD_SINK, 32.0)], lat, true, "road_metal", 4)


## The dirt checkpoint's two bumpers (GATE_BUMPER) along the sides, the arch's feet on them.
func _gate_bumpers(geo: TmGeo) -> void:
	var lat := [Vector3(1, 0, 0), Vector3(1, 0, 0)]
	var path := [Vector3(16, 0, GATE_BUMPER_Z.x), Vector3(16, 0, GATE_BUMPER_Z.y)]
	for side: float in [1.0, -1.0]:
		var sec := GATE_BUMPER.map(func(q: Array) -> Array:
			var p := Vector2((float(q[0]) - 16.0) * side, float(q[1]))
			if String(q[2]).is_empty():
				return [p, "", TmGeo.NO_COLLISION]
			var rows: Vector2 = q[3]
			return [p, q[2], 4] if rows.x < 0.0 else [p, q[2], 4, rows])
		geo.wall_sweep(sec, path, lat, true, "road_metal", 4)


## A piece's furniture (FURNITURE_PATH) on its footprint (size: x, z): boards and bands (our
## adverts on both faces, a white frame, props toward the piece's middle), kiosks (four advert faces
## round a white box over a ring of white X-braced leg cards), bumpers (our logo vinyl; their
## rubber parts dark). What TMNF lets overhang the next block (the clip pieces') is left out.
func _furniture(geo: TmGeo, f: Dictionary, size: Vector2) -> void:
	var mid := Vector3(size.x * 0.5, 0.0, size.y * 0.5)
	var ad := 0
	var kiosk := []
	for b: Array in f.get("boards", []):
		if not _on_footprint(b[1], size):
			continue
		var p := (b[1] as Array).map(func(q: Array) -> Vector3: return Vector3(q[0], q[1], q[2]))
		if String(b[0]) == "kiosk":
			kiosk.append(p)
			continue
		_board(geo, p, mid, ad)
		ad += 2
	# the kiosks: faces near one another make one
	var groups := []
	for p: Array in kiosk:
		var c: Vector3 = (p[0] + p[2]) * 0.5
		var home: Array = []
		for g: Array in groups:
			var gc := ((g[0][0] as Vector3) + (g[0][2] as Vector3)) * 0.5
			if gc.distance_to(c) < 12.0:
				home = g
				break
		if home.is_empty():
			groups.append([p])
		else:
			home.append(p)
	for g: Array in groups:
		_kiosk(geo, g, ad)
		ad += g.size()
	for k: Array in f.get("cards", []):
		var xz: Array = k[1]
		if not _on_footprint(xz, size):
			continue
		var y0: float = k[2]
		var y1: float = k[3]
		for i in xz.size():
			var a: Array = xz[i]
			var e: Array = xz[(i + 1) % xz.size()]
			var pa := Vector3(a[0], y0, a[1])
			var pb := Vector3(e[0], y0, e[1])
			var n := maxf(1.0, roundf(pa.distance_to(pb) / (y1 - y0)))
			geo.quad_uv(pa, pb, pb + Vector3(0, y1 - y0, 0), pa + Vector3(0, y1 - y0, 0), "lattice_x", TmGeo.NO_COLLISION,
				Vector2(0, 1), Vector2(n, 1), Vector2(n, 0), Vector2(0, 0))
	for b: Array in f.get("bumpers", []):
		if _on_footprint(b[3], size):
			_bumper(geo, b)


## Whether points ([x, (y,) z]) all lie on a footprint (size: x, z; 1 m spare).
static func _on_footprint(pts: Array, size: Vector2) -> bool:
	for q: Array in pts:
		var x := float(q[0])
		var z := float(q[q.size() - 1])
		if x <= -1.0 or x >= size.x + 1.0 or z <= -1.0 or z >= size.y + 1.0:
			return false
	return true


## A board or band on its four corners (bottom edge, then the top going the same way): our
## adverts on both faces (white panels on one too small for an advert), the white frame between
## them, two props from its back down to its foot.
func _board(geo: TmGeo, p: Array, mid: Vector3, ad: int) -> void:
	var along := ((p[1] as Vector3) - (p[0] as Vector3)).normalized()
	var up := ((p[3] as Vector3) - (p[0] as Vector3)).normalized()
	var n := along.cross(up).normalized()
	var c := ((p[0] as Vector3) + (p[2] as Vector3)) * 0.5
	var back := n if (mid - c).dot(n) > 0.0 else -n        # toward the piece's middle
	var blank := ((p[1] as Vector3) - (p[0] as Vector3)).length() < TmGeo.SCREEN_MIN_W \
		or ((p[3] as Vector3) - (p[0] as Vector3)).length() < TmGeo.SCREEN_MIN_H
	for k in 2:
		var o: Vector3 = (n if k == 0 else -n) * (FRAME_T * 0.5 + 0.01)
		if blank:
			continue
		geo.screen_rect(p[0] + o, p[1] + o, p[2] + o, p[3] + o, "screen", TmGeo.NO_COLLISION, ad + k, o.normalized())
	var m := FRAME_MARGIN
	var q := [p[0] - along * m - up * m, p[1] + along * m - up * m, p[2] + along * m + up * m, p[3] - along * m + up * m]
	SculptShapes._slab(geo, q.map(func(v: Vector3) -> Vector3: return v - n * FRAME_T * 0.5),
		q.map(func(v: Vector3) -> Vector3: return v + n * FRAME_T * 0.5), "control_panel", S_METAL)
	for e in 2:
		var foot: Vector3 = p[e]
		var top: Vector3 = (p[e] as Vector3).lerp(p[3 - e], PROP_UP)
		var ground := foot + back * PROP_BACK - Vector3(0, m + 0.3, 0)
		geo.pipe(top + back * FRAME_T, ground, 0.06, 6, "control_panel", TmGeo.NO_COLLISION)


## A kiosk: its faces (our adverts, facing out), a white box closed over and under them.
func _kiosk(geo: TmGeo, faces: Array, ad: int) -> void:
	var c := Vector3.ZERO
	for p: Array in faces:
		for v: Vector3 in p:
			c += v / (4.0 * faces.size())
	var tops := []
	var bots := []
	for i in faces.size():
		var p: Array = faces[i]
		var mid := ((p[0] as Vector3) + (p[2] as Vector3)) * 0.5
		var out := Vector3(mid.x - c.x, 0.0, mid.z - c.z).normalized()
		geo.screen_rect(p[0] + out * 0.02, p[1] + out * 0.02, p[2] + out * 0.02, p[3] + out * 0.02, "screen", S_METAL, ad + i, out)
		bots.append(p[0])
		bots.append(p[1])
		tops.append(p[2])
		tops.append(p[3])
	for lid: Array in [[tops, 1.0], [bots, -1.0]]:
		var pts: Array = lid[0]
		var y := 0.0
		for v: Vector3 in pts:
			y += v.y / pts.size()
		var ring := []
		for v: Vector3 in pts:
			if ring.all(func(r: Vector3) -> bool: return Vector2(r.x - v.x, r.z - v.z).length() > 0.3):
				ring.append(Vector3(v.x, y, v.z))
		ring.sort_custom(func(a: Vector3, b: Vector3) -> bool: return atan2(a.z - c.z, a.x - c.x) < atan2(b.z - c.z, b.x - c.x))
		var cy := Vector3(c.x, y, c.z)
		for i in ring.size():
			var a: Vector3 = ring[i]
			var b: Vector3 = ring[(i + 1) % ring.size()]
			if (a - cy).cross(b - cy).y * float(lid[1]) > 0.0:
				geo.tri(cy, a, b, "control_panel", S_METAL)
			else:
				geo.tri(cy, b, a, "control_panel", S_METAL)


## An inflatable bumper: a tube BUMPER_SIDES round, as wide as measured, along its centre line;
## our logo vinyl (u along it, 8 m a tile; v round it) or dark rubber; its ends closed.
func _bumper(geo: TmGeo, b: Array) -> void:
	var key := "dirt_bumper" if String(b[0]) == "logo" else "rubber_dark"
	var r := float(b[1]) * 0.5
	var line := (b[3] as Array).map(func(q: Array) -> Vector3: return Vector3(q[0], q[1], q[2]))
	var rings := []
	var us := []
	var u := 0.0
	for i in line.size():
		var prev: Vector3 = line[maxi(i - 1, 0)]
		var next: Vector3 = line[mini(i + 1, line.size() - 1)]
		var t := (next - prev).normalized()
		var side := t.cross(Vector3.UP).normalized()
		var upv := side.cross(t).normalized()
		if i > 0:
			u += (line[i] as Vector3).distance_to(line[i - 1])
		us.append(u / 8.0)
		var ring := []
		for k in BUMPER_SIDES + 1:
			var a := TAU * k / BUMPER_SIDES
			ring.append(line[i] + (upv * cos(a) + side * sin(a)) * r)
		rings.append(ring)
	for i in rings.size() - 1:
		for k in BUMPER_SIDES:
			var a: Vector3 = rings[i][k]
			var bb: Vector3 = rings[i][k + 1]
			var cc: Vector3 = rings[i + 1][k + 1]
			var d: Vector3 = rings[i + 1][k]
			var ua := Vector2(us[i], float(k) / BUMPER_SIDES)
			var ub := Vector2(us[i], float(k + 1) / BUMPER_SIDES)
			var uc := Vector2(us[i + 1], float(k + 1) / BUMPER_SIDES)
			var ud := Vector2(us[i + 1], float(k) / BUMPER_SIDES)
			var cen := ((line[i] as Vector3) + (line[i + 1] as Vector3)) * 0.5
			if (bb - a).cross(d - a).dot((a + cc) * 0.5 - cen) > 0.0:
				geo.quad_uv(a, bb, cc, d, key, S_RUBBER, ua, ub, uc, ud)
			else:
				geo.quad_uv(a, d, cc, bb, key, S_RUBBER, ua, ud, uc, ub)
	for e in [0, rings.size() - 1]:
		var ring: Array = rings[e]
		var o: Vector3 = line[e]
		var away: Vector3 = (o - (line[1] as Vector3 if e == 0 else line[line.size() - 2] as Vector3)).normalized()
		for k in BUMPER_SIDES:
			var a: Vector3 = ring[k]
			var bb: Vector3 = ring[k + 1]
			if (a - o).cross(bb - o).dot(away) > 0.0:
				geo.tri(o, a, bb, "rubber_dark", S_RUBBER)
			else:
				geo.tri(o, bb, a, "rubber_dark", S_RUBBER)

