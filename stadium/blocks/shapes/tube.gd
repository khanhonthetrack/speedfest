extends RefCounted
## Stadium "Tube" blocks: the round pipes (12-sided, radius 1.422 m) that run between blocks 4 m
## up (Tube/Road*), and the vertical pipe pillars (Tube/V). Our own geometry from measured numbers
## (TMNF block-local metres: x right, y up, z forward; see TmGeo).
##
## A road-type tube block's shape index (0 base, 1 dead end, 2 corner, 3 straight, 4 T, 5 cross)
## sets its arms: the dead end opens to +z, the corner turns +z -> -x, the T adds -x to the straight,
## the base is a lone junction with four 8 m stubs. Junctions (T, cross, base, and every RoadUp /
## RoadDown / RoadCross shape, which add a vertical arm to the block above and/or below) get a hub:
## a collar (radius 1.55) 1.9 m along each arm. Each collar (and a corner's pipes) starts on the
## mitre planes with the other arms (vertex offset o starts at t = max(o . other arm)), which
## reproduces TMNF's merged junction meshes exactly for arms of equal radius.

const R := 1.422                ## pipe radius (12 sides, a vertex on the frame's u axis)
const R_HUB := 1.55             ## junction collar radius
const HUB := 1.9                ## collar length from the junction centre
const SIDES := 12
const CENTRE := Vector3(16.0, 4.0, 16.0)
const S_PIPE := 16              # StadiumPillar (TmTuning.Surface.ASPHALT: pipes are drivable)
const S_METAL := 4
const S_RUBBER := 9

## Ground pillars' rubber foot (r, y), terrain at 1 m; PillarCap's top ring. Both TMNF's border
## atlas (TmMaterials "border_*"), once round, from row RING_ROWS.x at the bottom to .y at the top
## (its blue line low down, the black band with the white line above).
const FOOT := [[1.986, 1.0], [1.986, 1.142], [1.912, 1.516], [1.628, 1.893], [R, 2.0]]
const CAP := [[R, 7.0], [1.664, 7.142], [1.728, 7.516], [1.628, 7.893], [R, 8.0]]
const RING_ROWS := Vector2(301.3, 215.1)

const ARMS := {
	"Base": [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)],
	"Deadend": [Vector3(0, 0, 1)],
	"Corner": [Vector3(0, 0, 1), Vector3(-1, 0, 0)],
	"Straight": [Vector3(0, 0, 1), Vector3(0, 0, -1)],
	"TShaped": [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(-1, 0, 0)],
	"Cross": [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)],
}


func handles(shape: String) -> bool:
	return shape.begins_with("Tube/")


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var parts := shape.split("/")
	if parts.size() < 3:
		return null
	var geo := TmGeo.new()
	var ground := parts[2].ends_with("Ground")
	var form := parts[2].trim_suffix("Ground").trim_suffix("Air")
	if parts[1] == "V":
		if not _pillar(geo, form, ground):
			return null
	elif parts[1].begins_with("Road"):
		if not ARMS.has(form):
			return null   # Tube/Road/ClipGround: not placed by any block
		var vertical: Array = []
		if parts[1] in ["RoadUp", "RoadCross"]:
			vertical.append(Vector3.UP)
		if parts[1] in ["RoadDown", "RoadCross"]:
			vertical.append(Vector3.DOWN)
		if not (parts[1] == "RoadLightSystem" and form == "Base"):
			_road(geo, form, vertical, ground)
		if parts[1] == "RoadLightSystem":
			_light_system(geo, form)
		elif parts[1] == "RoadSoundSystem":
			_sound_system(geo)
	else:
		return null
	return geo.build()


## Pipe road: arms to the block edges (or 8 m stubs for the base), a hub at junctions.
func _road(geo: TmGeo, form: String, vertical: Array, ground: bool) -> void:
	var flat: Array = ARMS[form]
	var arms: Array = flat + vertical
	var hub := form in ["Base", "TShaped", "Cross"] or not vertical.is_empty()
	for d: Vector3 in arms:
		var others := arms.filter(func(e: Vector3) -> bool: return e != d)
		var reach := 8.0 if form == "Base" and d.y == 0.0 else 16.0
		if d.y > 0.0:
			reach = 8.0 - CENTRE.y
		elif d.y < 0.0:
			reach = CENTRE.y - (2.0 if ground else 0.0)
		var stub := form == "Base" and d.y == 0.0
		if hub:
			_pipe(geo, CENTRE, d, R_HUB, -INF, HUB, others, "road_metal", S_METAL, false, true)
			_pipe(geo, CENTRE, d, R, HUB, reach, [], "pillar", S_PIPE, false, stub)
		elif form == "Deadend":
			_pipe(geo, CENTRE, d, R, 0.0, reach, [], "pillar", S_PIPE, true, false)
		elif form == "Corner":
			_pipe(geo, CENTRE, d, R, -INF, reach, others, "pillar", S_PIPE, false, false)
		else:
			_pipe(geo, CENTRE, d, R, 0.0, reach, [], "pillar", S_PIPE, false, false)
	if ground and Vector3.DOWN in vertical:
		_revolve(geo, FOOT, "border_black", S_RUBBER, RING_ROWS)


## Vertical pillars: Pillar (1 block), Pillar4 / Pillar8 (4 / 8 blocks), PillarCap (rubber top ring
## and a lid), PillarBranch (lids both ends). Ground ones stand on a rubber foot on the terrain.
func _pillar(geo: TmGeo, form: String, ground: bool) -> bool:
	var base := Vector3(CENTRE.x, 0.0, CENTRE.z)
	var y0 := 2.0 if ground else 0.0
	match form:
		"Pillar", "Pillar4", "Pillar8":
			var h := 8.0 * (1.0 if form == "Pillar" else float(form.to_int()))
			_pipe(geo, base, Vector3.UP, R, y0, h, [], "pillar", S_PIPE, false, false)
		"PillarCap":
			_pipe(geo, base, Vector3.UP, R, y0, 7.0, [], "pillar", S_PIPE, false, false)
			_revolve(geo, CAP, "border_black", S_RUBBER, RING_ROWS)
			_disc(geo, _ring(base + Vector3.UP * 8.0, Vector3.UP, R), Vector3.UP, "road_metal", S_METAL)
		"PillarBranch":
			if ground:
				return false
			_pipe(geo, base, Vector3.UP, R, 0.0, 8.0, [], "pillar", S_PIPE, true, true)
		_:
			return false
	if ground:
		_revolve(geo, FOOT, "border_black", S_RUBBER, RING_ROWS)
	return true


## RoadLightSystem as TMNF's (measured): three lamp bars either side of the pipe along each arm
## (LIGHT_BARS: out from the pipe's axis, up, the face's tilt in degrees; LIGHT_BAR across, square),
## lamps on their outer face, top and bottom (spots_grid, LIGHT_LAMP_TILE m a tile), from
## LIGHT_LONG (m from the block edge) beside an arm with nothing on that side, LIGHT_SHORT on a side
## facing another arm, the length of a straight (LIGHT_STRAIGHT); a frame across each arm (two
## octagonal collars LIGHT_COLLAR m round, LIGHT_COLLAR_T long, LIGHT_FRAME_GAP apart from
## LIGHT_FRAME m from the edge, the straight's LIGHT_FRAME_STRAIGHT; plates LIGHT_ARM thick out to
## each bar between them); a 4 m column at the junction with two strips up each closed face
## (LIGHT_STRIPS: along the face, LIGHT_STRIP out), the pipe collared where it enters it
## (LIGHT_ENTRY: from, to, radius). The lone base has no pipe: four bars up each of two faces of
## the column (LIGHT_BASE_BARS: out from the middle, heights; LIGHT_BASE_RUN along z), turned 45
## degrees. TMNF's glow cards in front of the lamps are not built (ours are lit).
const LIGHT_BARS := [[3.61, 0.0, 0.0], [2.795, -2.13, -6.5], [2.795, 2.115, 6.5]]
const LIGHT_BAR := 0.6
const LIGHT_LAMP_TILE := 3.0
const LIGHT_LONG := Vector2(1.0, 13.0)
const LIGHT_SHORT := Vector2(4.14, 10.14)
const LIGHT_STRAIGHT := Vector2(1.0, 31.0)
const LIGHT_COLLAR := 1.51
const LIGHT_COLLAR_T := 0.68
const LIGHT_FRAME_GAP := 2.19
const LIGHT_FRAME := 5.73
const LIGHT_FRAME_STRAIGHT := 5.13
const LIGHT_ARM := 0.16
const LIGHT_STRIPS := [Vector2(-0.87, -0.15), Vector2(0.15, 0.87)]
const LIGHT_STRIP := 0.15
const LIGHT_ENTRY := [2.0, 2.44, 1.57]
const LIGHT_BASE_BARS := [2.465, [1.09, 3.03, 5.03, 7.03]]
const LIGHT_BASE_RUN := Vector2(12.99, 18.99)


func _light_system(geo: TmGeo, form: String) -> void:
	geo.box(Vector3(14, 0, 14), Vector3(18, 8, 18), "stands_dark", S_METAL)
	var arms: Array = ARMS[form] if form != "Base" else []
	for o: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		if arms.has(o) or (form == "Base" and o.x == 0.0):
			continue
		# the strips up a closed face
		var t := Vector3(-o.z, 0, o.x)
		for st: Vector2 in LIGHT_STRIPS:
			var a := Vector3(16, 0, 16) + o * 2.0 + t * st.x
			var b := Vector3(16, 0, 16) + o * (2.0 + LIGHT_STRIP) + t * st.y
			geo.box(Vector3(minf(a.x, b.x), 0, minf(a.z, b.z)), Vector3(maxf(a.x, b.x), 8, maxf(a.z, b.z)), "road_metal", S_METAL)
	if form == "Base":
		for sx: float in [-1.0, 1.0]:
			for y: float in LIGHT_BASE_BARS[1]:
				var c := Vector3(16.0 + sx * float(LIGHT_BASE_BARS[0]), y, 0.0)
				var n := Vector3(sx, 0, 0)
				_light_bar(geo, Vector3(c.x, c.y, LIGHT_BASE_RUN.x), Vector3(c.x, c.y, LIGHT_BASE_RUN.y), n, 45.0)
		return
	var straight := form == "Straight"
	for d: Vector3 in arms:
		var others := arms.filter(func(e: Vector3) -> bool: return e != d)
		_pipe(geo, CENTRE, d, LIGHT_ENTRY[2], LIGHT_ENTRY[0], LIGHT_ENTRY[1], [], "road_metal", S_METAL, true, true)
		var side0 := Vector3.UP.cross(d)
		for s: float in [-1.0, 1.0]:
			var side := side0 * s
			var span: Vector2 = LIGHT_SHORT if arms.has(side) else LIGHT_LONG
			if straight:
				if d.z < 0.0:
					continue
				span = LIGHT_STRAIGHT
			for b: Array in LIGHT_BARS:
				var off: Vector3 = side * float(b[0]) + Vector3.UP * float(b[1])
				var t0 := 16.0 - span.y
				var t1 := 16.0 - span.x
				_light_bar(geo, CENTRE + off + d * t0, CENTRE + off + d * t1, side, float(b[2]))
		var f := (LIGHT_FRAME_STRAIGHT if straight else LIGHT_FRAME)
		_light_frame(geo, d, 16.0 - f)


## A lamp bar from a to b (its axis), its lamp face out toward n, tilted (degrees, up positive):
## lamps on that face and the two beside it, the back and ends dark.
func _light_bar(geo: TmGeo, a: Vector3, b: Vector3, n: Vector3, tilt: float) -> void:
	var ax := (b - a).normalized()
	var m := ax.cross(n).normalized()
	if m.y < 0.0:
		m = -m
	var ang := deg_to_rad(tilt)
	var out := (n * cos(ang) + m * sin(ang)).normalized()
	var upf := (m * cos(ang) - n * sin(ang)).normalized()
	var h := LIGHT_BAR * 0.5
	var len := a.distance_to(b)
	var corner := func(p: Vector3, i: float, j: float) -> Vector3: return p + out * i * h + upf * j * h
	# faces: [normal, the two section corners (i, j) in order]
	var faces := [[out, Vector2(1, -1), Vector2(1, 1), true], [upf, Vector2(1, 1), Vector2(-1, 1), true],
		[-upf, Vector2(-1, -1), Vector2(1, -1), true], [-out, Vector2(-1, 1), Vector2(-1, -1), false]]
	for fc: Array in faces:
		var c0: Vector2 = fc[1]
		var c1: Vector2 = fc[2]
		var p0: Vector3 = corner.call(a, c0.x, c0.y)
		var p1: Vector3 = corner.call(a, c1.x, c1.y)
		var q0: Vector3 = corner.call(b, c0.x, c0.y)
		var q1: Vector3 = corner.call(b, c1.x, c1.y)
		var u1 := len / LIGHT_LAMP_TILE
		if fc[3]:
			_face_uv(geo, [p0, q0, q1, p1], fc[0], "spots_grid", [Vector2(0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(0, 0)])
		else:
			_face_uv(geo, [p0, q0, q1, p1], fc[0], "stands_dark", [])
	for e: Array in [[a, -ax], [b, ax]]:
		var p: Vector3 = e[0]
		_face_uv(geo, [corner.call(p, -1.0, -1.0), corner.call(p, 1.0, -1.0), corner.call(p, 1.0, 1.0), corner.call(p, -1.0, 1.0)],
			e[1], "stands_dark", [])


## A quad facing n (its corners turned round if they face the other way), with UVs or the key's own.
func _face_uv(geo: TmGeo, q: Array, n: Vector3, key: String, uv: Array) -> void:
	if ((q[1] - q[0]) as Vector3).cross(q[2] - q[0]).dot(n) < 0.0:
		q = [q[0], q[3], q[2], q[1]]
		if not uv.is_empty():
			uv = [uv[0], uv[3], uv[2], uv[1]]
	if uv.is_empty():
		geo.quad(q[0], q[1], q[2], q[3], key, S_METAL)
	else:
		geo.quad_uv(q[0], q[1], q[2], q[3], key, S_METAL, uv[0], uv[1], uv[2], uv[3])


## The frame across an arm d, its first collar at t (m from the junction, the edge-most side) going
## in: two octagonal collars, plates between them out to each bar.
func _light_frame(geo: TmGeo, d: Vector3, t: float) -> void:
	for t0: float in [t - LIGHT_COLLAR_T, t - LIGHT_FRAME_GAP - LIGHT_COLLAR_T]:
		var ring := []
		for k in 8:
			var ang := TAU * (k + 0.5) / 8.0
			var fr := _frame(d)
			ring.append(((fr[0] as Vector3) * cos(ang) + (fr[1] as Vector3) * sin(ang)) * LIGHT_COLLAR / cos(PI / 8.0))
		var a := CENTRE + d * t0
		var b := CENTRE + d * (t0 + LIGHT_COLLAR_T)
		for k in 8:
			var r0: Vector3 = ring[k]
			var r1: Vector3 = ring[(k + 1) % 8]
			_face_uv(geo, [a + r0, b + r0, b + r1, a + r1], (r0 + r1).normalized(), "road_metal", [])
		for e: Array in [[a, -d], [b, d]]:
			var c: Vector3 = e[0]
			for k in 8:
				var tri := [c, c + (ring[k] as Vector3), c + (ring[(k + 1) % 8] as Vector3)]
				if ((tri[1] - tri[0]) as Vector3).cross(tri[2] - tri[0]).dot(e[1]) < 0.0:
					tri = [tri[0], tri[2], tri[1]]
				geo.tri(tri[0], tri[1], tri[2], "road_metal", S_METAL)
	# the plates, across the gap between the collars
	var ta := t - LIGHT_COLLAR_T - LIGHT_FRAME_GAP + 0.31
	var tb := t - 0.31
	var side0 := Vector3.UP.cross(d)
	for s: float in [-1.0, 1.0]:
		for bar: Array in LIGHT_BARS:
			var dir: Vector3 = (side0 * s * float(bar[0]) + Vector3.UP * float(bar[1]))
			var r := dir.length()
			dir = dir / r
			var w := dir.cross(d).normalized() * LIGHT_ARM * 0.5
			var p0 := CENTRE + dir * LIGHT_COLLAR
			var p1 := CENTRE + dir * (r - LIGHT_BAR * 0.5)
			var q := [p0 - w + d * ta, p1 - w + d * ta, p1 - w + d * tb, p0 - w + d * tb]
			for k in 2:
				var sg := 1.0 if k == 0 else -1.0
				var qq := q.map(func(p: Vector3) -> Vector3: return p + w * (1.0 + sg))
				_face_uv(geo, qq, w * sg, "stands_dark", [])


## RoadSoundSystem: the support column and speaker stacks on both sides.
func _sound_system(geo: TmGeo) -> void:
	geo.box(Vector3(14, 0, 14), Vector3(18, 8, 18), "structure", S_METAL)
	for x0 in [3.86, 26.07]:
		for z0 in [7.57, 20.43]:
			geo.screen_box(Vector3(x0, 0.0, z0), Vector3(x0 + 2.07, 4.18, z0 + 4.0), "screen", S_METAL, 0.03, int(z0) % 3)
	for x0 in [4.18, 26.01]:
		for z0 in [2.0, 12.67, 17.33, 28.0]:
			geo.screen_box(Vector3(x0, 0.0, z0), Vector3(x0 + 1.81, 4.0, z0 + 2.0), "screen", S_METAL, 0.03, int(z0) % 3)


## Frame (u, v) of a pipe along d: vertical pipes have a vertex toward +x, horizontal ones a
## vertex on the horizontal perpendicular and one on top.
static func _frame(d: Vector3) -> Array:
	if absf(d.y) > 0.5:
		return [Vector3(1, 0, 0), Vector3(0, 0, 1)]
	return [Vector3.UP.cross(d), Vector3.UP]


static func _ring(c: Vector3, d: Vector3, r: float) -> Array:
	var fr := _frame(d)
	var pts := []
	for k in SIDES:
		var ang := TAU * k / SIDES
		pts.append(c + ((fr[0] as Vector3) * cos(ang) + (fr[1] as Vector3) * sin(ang)) * r)
	return pts


## A 12-sided pipe along unit axis d from point c: ring vertex k (offset o) runs from
## max(t_min, o . e for each mitre direction e) to t_out. Smooth radial normals; ends optionally
## closed by flat lids.
func _pipe(geo: TmGeo, c: Vector3, d: Vector3, r: float, t_min: float, t_out: float, mitre: Array,
		mat: String, surf: int, cap_in: bool, cap_out: bool) -> void:
	var fr := _frame(d)
	var p_in := []
	var p_out := []
	var nrm := []
	for k in SIDES:
		var ang := TAU * k / SIDES
		var dir: Vector3 = (fr[0] as Vector3) * cos(ang) + (fr[1] as Vector3) * sin(ang)
		var o := dir * r
		var t0 := t_min
		for e: Vector3 in mitre:
			t0 = maxf(t0, o.dot(e))
		if t0 == -INF:
			t0 = 0.0
		p_in.append(c + o + d * t0)
		p_out.append(c + o + d * t_out)
		nrm.append(dir)
	for k in SIDES:
		var k1 := (k + 1) % SIDES
		_side(geo, p_in[k], p_out[k], p_out[k1], p_in[k1], nrm[k], nrm[k1], mat, surf)
	if cap_in:
		_disc(geo, p_in, -d, mat, surf)
	if cap_out:
		_disc(geo, p_out, d, mat, surf)


## Surface of revolution about the vertical axis through the block centre: profile (r, y) points
## bottom to top, outward normals; rows (when given): the border atlas' rows at its bottom and top
## (UVs once round; else the planar default).
func _revolve(geo: TmGeo, prof: Array, mat: String, surf: int, rows := Vector2(-1, -1)) -> void:
	var ya := float(prof[0][1])
	var yb := float(prof[prof.size() - 1][1])
	for i in prof.size() - 1:
		var r0 := float(prof[i][0])
		var y0 := float(prof[i][1])
		var r1 := float(prof[i + 1][0])
		var y1 := float(prof[i + 1][1])
		var n2 := Vector2(y1 - y0, r0 - r1).normalized()   # (radial, up)
		var v0 := lerpf(rows.x, rows.y, (y0 - ya) / (yb - ya)) / 512.0
		var v1 := lerpf(rows.x, rows.y, (y1 - ya) / (yb - ya)) / 512.0
		for k in SIDES:
			var k1 := (k + 1) % SIDES
			var dk := Vector3(cos(TAU * k / SIDES), 0.0, sin(TAU * k / SIDES))
			var dk1 := Vector3(cos(TAU * k1 / SIDES), 0.0, sin(TAU * k1 / SIDES))
			var c := Vector3(CENTRE.x, 0.0, CENTRE.z)
			var uv: Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
			if rows.x >= 0.0:
				var u0 := float(k) / SIDES
				var u1 := float(k + 1) / SIDES
				uv = [Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0)]
			_side(geo, c + dk * r0 + Vector3.UP * y0, c + dk * r1 + Vector3.UP * y1,
				c + dk1 * r1 + Vector3.UP * y1, c + dk1 * r0 + Vector3.UP * y0,
				dk * n2.x + Vector3.UP * n2.y, dk1 * n2.x + Vector3.UP * n2.y, mat, surf, uv)


## Quad a, b (ring vertex k) and c, d (vertex k + 1), facing along the vertex normals na / nb;
## uv: the corners' UVs (a, b, c, d), all zero for the planar default.
func _side(geo: TmGeo, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3,
		mat: String, surf: int, uv: Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]) -> void:
	if (c - a).cross(d - b).dot(na + nb) >= 0.0:
		geo.tri(a, b, c, mat, surf, na, na, nb, uv[0], uv[1], uv[2])
		geo.tri(a, c, d, mat, surf, na, nb, nb, uv[0], uv[2], uv[3])
	else:
		geo.tri(a, c, b, mat, surf, na, nb, na, uv[0], uv[2], uv[1])
		geo.tri(a, d, c, mat, surf, na, nb, nb, uv[0], uv[3], uv[2])


## Flat lid over a ring of points, facing n.
func _disc(geo: TmGeo, pts: Array, n: Vector3, mat: String, surf: int) -> void:
	var c := Vector3.ZERO
	for p: Vector3 in pts:
		c += p
	c /= pts.size()
	for k in pts.size():
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[(k + 1) % pts.size()]
		if (a - c).cross(b - c).dot(n) >= 0.0:
			geo.tri(c, a, b, mat, surf)
		else:
			geo.tri(c, b, a, mat, surf)
