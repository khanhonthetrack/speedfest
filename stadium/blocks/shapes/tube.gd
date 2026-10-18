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
const R_CLIP := 1.47            ## Tube/Road/Clip's end cap
const SIDES := 12
const CENTRE := Vector3(16.0, 4.0, 16.0)
const S_PIPE := 16              # StadiumPillar (TmTuning.Surface.ASPHALT: pipes are drivable)
const S_METAL := 4
const S_RUBBER := 9

## Ground pillars' rubber foot (r, y), terrain at 1 m; PillarCap's top ring.
const FOOT := [[1.986, 1.0], [1.986, 1.142], [1.912, 1.516], [1.628, 1.893], [R, 2.0]]
const CAP := [[R, 7.0], [1.664, 7.142], [1.728, 7.516], [1.628, 7.893], [R, 8.0]]

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
		if form == "Clip":
			# where a pipe road meets another block: a 2 m end cap on the pipe at the +z edge (measured:
			# a 9-sided sleeve, radius 1.47, closed 0.25 m in; ours is the pipe's 12 sides)
			_pipe(geo, CENTRE, Vector3(0, 0, 1), R_CLIP, 14.0, 16.0, [], "metal", S_METAL, true, true)
			return geo.build()
		if not ARMS.has(form):
			return null
		var vertical: Array = []
		if parts[1] in ["RoadUp", "RoadCross"]:
			vertical.append(Vector3.UP)
		if parts[1] in ["RoadDown", "RoadCross"]:
			vertical.append(Vector3.DOWN)
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
			_pipe(geo, CENTRE, d, R_HUB, -INF, HUB, others, "metal", S_METAL, false, true)
			_pipe(geo, CENTRE, d, R, HUB, reach, [], "pipe", S_PIPE, false, stub)
		elif form == "Deadend":
			_pipe(geo, CENTRE, d, R, 0.0, reach, [], "pipe", S_PIPE, true, false)
		elif form == "Corner":
			_pipe(geo, CENTRE, d, R, -INF, reach, others, "pipe", S_PIPE, false, false)
		else:
			_pipe(geo, CENTRE, d, R, 0.0, reach, [], "pipe", S_PIPE, false, false)
	if ground and Vector3.DOWN in vertical:
		_revolve(geo, FOOT, "rubber_dark", S_RUBBER)


## Vertical pillars: Pillar (1 block), Pillar4 / Pillar8 (4 / 8 blocks), PillarCap (rubber top ring
## and a lid), PillarBranch (lids both ends). Ground ones stand on a rubber foot on the terrain.
func _pillar(geo: TmGeo, form: String, ground: bool) -> bool:
	var base := Vector3(CENTRE.x, 0.0, CENTRE.z)
	var y0 := 2.0 if ground else 0.0
	match form:
		"Pillar", "Pillar4", "Pillar8":
			var h := 8.0 * (1.0 if form == "Pillar" else float(form.to_int()))
			_pipe(geo, base, Vector3.UP, R, y0, h, [], "pipe", S_PIPE, false, false)
		"PillarCap":
			_pipe(geo, base, Vector3.UP, R, y0, 7.0, [], "pipe", S_PIPE, false, false)
			_revolve(geo, CAP, "rubber_dark", S_RUBBER)
			_disc(geo, _ring(base + Vector3.UP * 8.0, Vector3.UP, R), Vector3.UP, "metal", S_METAL)
		"PillarBranch":
			if ground:
				return false
			_pipe(geo, base, Vector3.UP, R, 0.0, 8.0, [], "pipe", S_PIPE, true, true)
		_:
			return false
	if ground:
		_revolve(geo, FOOT, "rubber_dark", S_RUBBER)
	return true


## RoadLightSystem: a 4 m square support column through the junction, a sleeve along each arm and
## rings of six spotlights around the pipe (visual only).
func _light_system(geo: TmGeo, form: String) -> void:
	geo.box(Vector3(14, 0, 14), Vector3(18, 8, 18), "structure", S_METAL)
	var arms: Array = ARMS[form]
	for d: Vector3 in arms:
		var others := arms.filter(func(e: Vector3) -> bool: return e != d)
		var reach := 2.0 if form == "Base" else 10.5
		_pipe(geo, CENTRE, d, R_HUB, -INF, reach, others, "structure", S_METAL, false, true)
		var t := 3.0 if form != "Base" else 99.0
		while t <= 15.0:
			_spots(geo, CENTRE + d * t, d)
			t += 3.0


func _spots(geo: TmGeo, at: Vector3, d: Vector3) -> void:
	var fr := _frame(d)
	for k in 6:
		var ang := TAU * k / 6.0
		var p: Vector3 = at + ((fr[0] as Vector3) * cos(ang) + (fr[1] as Vector3) * sin(ang)) * 3.3
		geo.box(p - Vector3.ONE * 0.3, p + Vector3.ONE * 0.3, "lamp", TmGeo.NO_COLLISION)


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
## bottom to top, outward normals.
func _revolve(geo: TmGeo, prof: Array, mat: String, surf: int) -> void:
	for i in prof.size() - 1:
		var r0 := float(prof[i][0])
		var y0 := float(prof[i][1])
		var r1 := float(prof[i + 1][0])
		var y1 := float(prof[i + 1][1])
		var n2 := Vector2(y1 - y0, r0 - r1).normalized()   # (radial, up)
		for k in SIDES:
			var k1 := (k + 1) % SIDES
			var dk := Vector3(cos(TAU * k / SIDES), 0.0, sin(TAU * k / SIDES))
			var dk1 := Vector3(cos(TAU * k1 / SIDES), 0.0, sin(TAU * k1 / SIDES))
			var c := Vector3(CENTRE.x, 0.0, CENTRE.z)
			_side(geo, c + dk * r0 + Vector3.UP * y0, c + dk * r1 + Vector3.UP * y1,
				c + dk1 * r1 + Vector3.UP * y1, c + dk1 * r0 + Vector3.UP * y0,
				dk * n2.x + Vector3.UP * n2.y, dk1 * n2.x + Vector3.UP * n2.y, mat, surf)


## Quad a, b (ring vertex k) and c, d (vertex k + 1), facing along the vertex normals na / nb.
func _side(geo: TmGeo, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3,
		mat: String, surf: int) -> void:
	if (c - a).cross(d - b).dot(na + nb) >= 0.0:
		geo.tri(a, b, c, mat, surf, na, na, nb)
		geo.tri(a, c, d, mat, surf, na, nb, nb)
	else:
		geo.tri(a, c, b, mat, surf, na, nb, na)
		geo.tri(a, d, c, mat, surf, na, nb, nb)


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
