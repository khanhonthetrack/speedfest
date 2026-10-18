class_name TmGeo
extends RefCounted
## Block geometry builder. Faces are authored in TMNF block-local coordinates (x right, y up, z
## forward, metres; the measured block data uses them), front side = (b - a) x (c - a); build()
## converts to Godot (x negated: the mirror and Godot's clockwise front faces cancel, so the vertex
## order is kept). Visual triangles are grouped per material key (TmMaterials); collision faces
## carry a TMNF surface id each (TmTuning.Surface), stored as the body's "surfaces" meta (per face).

const NO_COLLISION := -1
const UV_TILE := 8.0               ## sweeps hold a whole number of these along their length (m)

class Group:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()

var _vis := {}                      ## material key -> Group
var _col := PackedVector3Array()
var _surf := PackedInt32Array()
var sheared := Vector3.ZERO           ## the shear_y applied so far: (kx, kz, dy)


static func g(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, p.z)


func _group(mat: String) -> Group:
	if not _vis.has(mat):
		_vis[mat] = Group.new()
	return _vis[mat]


## One triangle (TMNF coords). mat "" = collision only; surface NO_COLLISION = visual only.
## Normals: flat unless given (smooth sweeps pass vertex normals).
func tri(a: Vector3, b: Vector3, c: Vector3, mat: String, surface: int, na := Vector3.ZERO,
		nb := Vector3.ZERO, nc := Vector3.ZERO, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if not mat.is_empty():
		var grp := _group(mat)
		var auto_uv := ua == Vector2.ZERO and ub == Vector2.ZERO and uc == Vector2.ZERO
		for k in 3:
			var p: Vector3 = [a, b, c][k]
			var vn: Vector3 = [na, nb, nc][k]
			grp.v.append(g(p))
			grp.n.append(g(n if vn == Vector3.ZERO else vn))
			grp.uv.append(_tri_uv(p, n) if auto_uv else [ua, ub, uc][k])
	if surface != NO_COLLISION:
		_col.append(g(a))
		_col.append(g(b))
		_col.append(g(c))
		_surf.append(surface)


## Quad a-b-c-d around its edge, front = (b - a) x (c - a).
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, mat: String, surface: int) -> void:
	tri(a, b, c, mat, surface)
	tri(a, c, d, mat, surface)


## World-aligned UVs in metres / 8 (texture tiles every 8 m), projected on the dominant axis.
static func _tri_uv(p: Vector3, n: Vector3) -> Vector2:
	var an := n.abs()
	if an.y >= an.x and an.y >= an.z:
		return Vector2(p.x, p.z) / 8.0
	if an.x >= an.z:
		return Vector2(p.z, p.y) / 8.0
	return Vector2(p.x, p.y) / 8.0


## Axis-aligned box [lo, hi] (TMNF coords), all six faces outward.
func box(lo: Vector3, hi: Vector3, mat: String, surface: int, top_mat := "", top_surface := -2) -> void:
	var tm := mat if top_mat.is_empty() else top_mat
	var ts := surface if top_surface == -2 else top_surface
	var p := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	quad(p[4], p[7], p[6], p[5], tm, ts)          # top (+y)
	quad(p[0], p[1], p[2], p[3], mat, surface)    # bottom (-y)
	quad(p[0], p[4], p[5], p[1], mat, surface)    # -z
	quad(p[2], p[6], p[7], p[3], mat, surface)    # +z
	quad(p[3], p[7], p[4], p[0], mat, surface)    # -x
	quad(p[1], p[5], p[6], p[2], mat, surface)    # +x


## Sweep a 2D profile along frames. profile: Array of [Vector2(lateral, up), mat, surface] points;
## segment k (point k -> k+1) uses point k's mat/surface. frames: Array[Transform3D] (TMNF coords:
## basis.x = lateral, basis.y = up, origin = profile origin). The front side is to the right of the
## profile's direction of travel when looking along +frame z... i.e. author profiles so that
## (p[k+1] - p[k]) turned by -90 deg (lateral, up) -> (up, -lateral) is the outward normal.
## profiles: optional per-frame profiles (same point count and materials) instead of one profile.
## UVs (for textured materials): u = metres travelled along the path by that point of the section
## (stretched so the sweep holds a whole number of UV_TILE tiles: no seam where blocks meet);
## v = metres along the section, measured from its nearer end (a closed road section: from the
## bottom centre, the same on both sides) and restarting at 0 on each run of one material, so a
## material's texture starts at the run's end nearer the section's ends (a curb face's top).
## halves: the section is a left half (lateral x < 0) and its mirror; u runs backwards on the
## right half's segments so text reads the same way from the road on both sides. u_dir: -1 when
## the path was reversed (keeps u running with the path as authored).
func sweep(profile: Array, frames: Array, smooth := false, profiles: Array = [], halves := false, u_dir := 1.0) -> void:
	var nf := frames.size()
	var np := profile.size()
	var pts := []                    # [frame][point] -> Vector3
	for f in nf:
		var fr: Transform3D = frames[f]
		var pr: Array = profile if profiles.is_empty() else profiles[f]
		var row := []
		for k in np:
			var q: Vector2 = pr[k][0]
			row.append(fr.origin + fr.basis.x * q.x + fr.basis.y * q.y)
		pts.append(row)
	var us := []                     # [frame][point] -> u
	for f in nf:
		us.append([])
	for k in np:
		var acc := 0.0
		(us[0] as Array).append(0.0)
		for f in range(1, nf):
			acc += ((pts[f][k] as Vector3) - (pts[f - 1][k] as Vector3)).length()
			(us[f] as Array).append(acc)
		if acc > 1e-4:
			var fit := maxf(1.0, roundf(acc / UV_TILE)) * UV_TILE / acc
			for f in nf:
				us[f][k] = float(us[f][k]) * fit
	var arc := [0.0]
	var pr0: Array = profile if profiles.is_empty() else profiles[0]
	for k in range(1, np):
		arc.append(float(arc[k - 1]) + ((pr0[k][0] as Vector2) - (pr0[k - 1][0] as Vector2)).length())
	var total: float = arc[np - 1]
	# measured both ways round from the section's bottom centre (halves: the lowest point on the
	# centre line, wherever the loop starts), else from the nearer end
	var origin := 0.0
	if halves:
		var lo_y := INF
		for k in np - 1:
			var q: Vector2 = pr0[k][0]
			if absf(q.x) < 1e-3 and q.y < lo_y:
				lo_y = q.y
				origin = float(arc[k])
	var dsym := []
	for k in np:
		var fwd := fposmod(float(arc[k]) - origin, total) if total > 0.0 else 0.0
		dsym.append(minf(fwd, total - fwd))
	# each segment's v at its two ends, relative to its material run's lowest dsym
	var v0s := []
	var v1s := []
	var k0 := 0
	while k0 < np - 1:
		var k1 := k0
		while k1 + 1 < np - 1 and String(profile[k1 + 1][1]) == String(profile[k0][1]):
			k1 += 1
		var lo := INF
		for k in range(k0, k1 + 2):
			lo = minf(lo, float(dsym[k]))
		for k in range(k0, k1 + 1):
			v0s.append(float(dsym[k]) - lo)
			v1s.append(float(dsym[k + 1]) - lo)
		k0 = k1 + 1
	for f in nf - 1:
		for k in np - 1:
			var mat: String = profile[k][1]
			var surf: int = profile[k][2]
			var a: Vector3 = pts[f][k]
			var b: Vector3 = pts[f][k + 1]
			var c: Vector3 = pts[f + 1][k + 1]
			var d: Vector3 = pts[f + 1][k]
			var side := u_dir
			if halves and ((pr0[k][0] as Vector2).x + (pr0[k + 1][0] as Vector2).x) > 0.0:
				side = -side
			var ua := Vector2(side * float(us[f][k]), float(v0s[k]))
			var ub := Vector2(side * float(us[f][k + 1]), float(v1s[k]))
			var uc := Vector2(side * float(us[f + 1][k + 1]), float(v1s[k]))
			var ud := Vector2(side * float(us[f + 1][k]), float(v0s[k]))
			if ua == Vector2.ZERO and ub == Vector2.ZERO:
				ua.x = 1e-6       # (all-zero UVs mean "make them up" to tri())
			tri(a, b, c, mat, surf, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, ua, ub, uc)
			tri(a, c, d, mat, surf, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, ua, uc, ud)


## Sweeps a closed vertical section along a path. section: Array of [Vector2(d, y), mat, surface]
## where d is the offset along `outward` (horizontal vector per path point; all path points equal
## = a revolve about that point) and y the height above the path point. Any loop orientation and path direction: both are fixed so faces point
## out. caps: close both ends with the section polygon (cap_mat, cap_surface). y_at: optional
## func(y: float, i: int) -> float, the section's heights at path point i (e.g. a lowered top).
## p_at: optional func(p: Vector2, i: int) -> Vector2, the section's points (d, y) at path point i
## (applied after y_at; e.g. curbs moved sideways).
func wall_sweep(section: Array, path: Array, outward: Array, caps := true, cap_mat := "wall_dark", cap_surface := 4,
		y_at := Callable(), p_at := Callable(), halves := true) -> void:
	var loop := section.duplicate()
	if TmGeo.loop_area(loop) < 0.0:
		loop = TmGeo.reversed_loop(loop)
	var pts := path.duplicate()
	var outs := outward.duplicate()
	# frames: lateral L = outward, up U, travel F = L x U; the path must run along F
	var f0 := (outs[0] as Vector3).cross(Vector3.UP)
	var travel := (pts[1] as Vector3) - (pts[0] as Vector3)
	if travel.length_squared() < 1e-10:
		travel = (outs[1] as Vector3) - (outs[0] as Vector3)   # a revolve about one point
	var reversed := f0.dot(travel) < 0.0
	if reversed:
		pts.reverse()
		outs.reverse()
	var frames := []
	var loops := []
	for i in pts.size():
		var l: Vector3 = outs[i]
		frames.append(Transform3D(Basis(l, Vector3.UP, l.cross(Vector3.UP)), pts[i]))
		var li := loop
		var src := (pts.size() - 1 - i) if reversed else i
		if y_at.is_valid():
			li = li.map(func(q: Array) -> Array: return [Vector2((q[0] as Vector2).x, y_at.call((q[0] as Vector2).y, src)), q[1], q[2]])
		if p_at.is_valid():
			li = li.map(func(q: Array) -> Array: return [p_at.call(q[0], src), q[1], q[2]])
		var closed_i := li.duplicate()
		closed_i.append(li[0])
		loops.append(closed_i)
	var closed := loop.duplicate()
	closed.append(loop[0])
	sweep(closed, frames, false, loops if y_at.is_valid() or p_at.is_valid() else [], halves, -1.0 if reversed else 1.0)
	if caps:
		_section_cap((loops[0] as Array).slice(0, loop.size()), frames[0], -1.0, cap_mat, cap_surface)
		_section_cap((loops[loops.size() - 1] as Array).slice(0, loop.size()), frames[frames.size() - 1], 1.0, cap_mat, cap_surface)


## A closed (z, radius) section [[z, r, mat, surface], ...] revolved about the axis through
## centre (x, y) along z, from angle a0 to a1 (degrees, from +x toward +y); caps close both ends.
func revolve_z(section: Array, centre: Vector2, a0: float, a1: float, steps: int, caps := true) -> void:
	var loop := []
	for q in section:
		loop.append([Vector2(float(q[0]), float(q[1])), String(q[2]), int(q[3])])
	if TmGeo.loop_area(loop) < 0.0:
		loop = TmGeo.reversed_loop(loop)
	var frames := []
	for k in steps + 1:
		var a := deg_to_rad(lerpf(a0, a1, float(k) / steps))
		var up := Vector3(cos(a), sin(a), 0)
		var fwd := Vector3(-sin(a), cos(a), 0)
		frames.append(Transform3D(Basis(Vector3(0, 0, 1), up, fwd), Vector3(centre.x, centre.y, 0)))
	sweep(loop + [loop[0]], frames)
	if caps:
		var mat: String = loop[0][1]
		_section_cap(loop, frames[0], -1.0, mat, loop[0][2])
		_section_cap(loop, frames[steps], 1.0, mat, loop[0][2])


## Polygon cap of a section at a frame, facing along +frame z (side > 0) or -z.
func _section_cap(loop: Array, frame: Transform3D, side: float, mat: String, surface: int) -> void:
	var poly := PackedVector2Array()
	for p in loop:
		poly.append(p[0])
	var idx := Geometry2D.triangulate_polygon(poly)
	var fwd := frame.basis.z * side
	for k in range(0, idx.size(), 3):
		var pts := []
		for j in 3:
			var q: Vector2 = poly[idx[k + j]]
			pts.append(frame.origin + frame.basis.x * q.x + frame.basis.y * q.y)
		var a: Vector3 = pts[0]
		var b: Vector3 = pts[1]
		var c: Vector3 = pts[2]
		if (b - a).cross(c - a).dot(fwd) < 0.0:
			tri(a, c, b, mat, surface)
		else:
			tri(a, b, c, mat, surface)


## A vertical prism over a closed horizontal loop of [Vector2(x, z), mat, surface] points (each
## segment takes its start point's material) from y0 to y1, sides facing out; caps: lids at both
## ends (cap_mat, cap_surface).
func extrude_y(loop: Array, y0: float, y1: float, caps := false, cap_mat := "", cap_surface := NO_COLLISION) -> void:
	var ccw := TmGeo.loop_area(loop) > 0.0
	for i in loop.size():
		var p: Vector2 = loop[i][0]
		var q: Vector2 = loop[(i + 1) % loop.size()][0]
		var a := Vector3(p.x, y0, p.y)
		var b := Vector3(q.x, y0, q.y)
		var c := Vector3(q.x, y1, q.y)
		var d := Vector3(p.x, y1, p.y)
		if ccw:
			quad(a, d, c, b, loop[i][1], loop[i][2])
		else:
			quad(a, b, c, d, loop[i][1], loop[i][2])
	if caps:
		var poly := PackedVector2Array()
		for q in loop:
			poly.append(q[0])
		flat_polygon(poly, y1, cap_mat, cap_surface)
		flat_polygon(poly, y0, cap_mat, cap_surface, true)


## A straight pipe (open n-gon prism) from a to b, radius r, smooth radial normals. Its frame: u =
## horizontal perpendicular (+x for vertical pipes), v = up (+z); the first vertex at angle phase.
func pipe(a: Vector3, b: Vector3, r: float, sides: int, mat: String, surface: int, phase := 0.0) -> void:
	var d := (b - a).normalized()
	var u := Vector3(1, 0, 0) if absf(d.y) > 0.5 else Vector3.UP.cross(d).normalized()
	var v := Vector3(0, 0, 1) if absf(d.y) > 0.5 else Vector3.UP
	for k in sides:
		var a0 := phase + TAU * k / sides
		var a1 := phase + TAU * (k + 1) / sides
		var n0 := u * cos(a0) + v * sin(a0)
		var n1 := u * cos(a1) + v * sin(a1)
		var p0 := a + n0 * r
		var p1 := a + n1 * r
		var q0 := b + n0 * r
		var q1 := b + n1 * r
		if (q0 - p0).cross(p1 - p0).dot(n0 + n1) >= 0.0:
			tri(p0, q0, q1, mat, surface, n0, n0, n1)
			tri(p0, q1, p1, mat, surface, n0, n1, n1)
		else:
			tri(p0, q1, q0, mat, surface, n0, n1, n0)
			tri(p0, p1, q1, mat, surface, n0, n1, n1)


## Horizontal polygon (TMNF x, z points) at height y, facing up (or down if down).
func flat_polygon(poly: PackedVector2Array, y: float, mat: String, surface: int, down := false) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for k in range(0, idx.size(), 3):
		var a := Vector3(poly[idx[k]].x, y, poly[idx[k]].y)
		var b := Vector3(poly[idx[k + 1]].x, y, poly[idx[k + 1]].y)
		var c := Vector3(poly[idx[k + 2]].x, y, poly[idx[k + 2]].y)
		if ((b - a).cross(c - a).y < 0.0) != down:
			tri(a, c, b, mat, surface)
		else:
			tri(a, b, c, mat, surface)


static func loop_area(loop: Array) -> float:
	var a := 0.0
	for i in loop.size():
		var p: Vector2 = loop[i][0]
		var q: Vector2 = loop[(i + 1) % loop.size()][0]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## Reverses a section loop; each segment keeps its material (moved to its new start point).
static func reversed_loop(loop: Array) -> Array:
	var n := loop.size()
	var out := []
	for i in n:
		var p: Array = loop[n - 1 - i]
		var seg: Array = loop[(n - 2 - i + n) % n]
		out.append([p[0], seg[1], seg[2]])
	return out


## Points of an arc in the TMNF x-z plane: centre c (x, z), radius r, angles a0 -> a1 (radians,
## measured from +x toward +z), at height y; and the radial unit vectors (outward from c).
static func arc(c: Vector2, r: float, a0: float, a1: float, y: float, steps: int) -> Array:
	var pts := []
	var rad := []
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / steps)
		var d := Vector3(cos(a), 0.0, sin(a))
		pts.append(Vector3(c.x, y, c.y) + d * r)
		rad.append(d)
	return [pts, rad]


## Shears everything added so far vertically (TMNF coords): y += kx * x + kz * z + dy. Planes stay
## planes; normals follow (inverse transpose). Sloped and banked variants of flat pieces use it.
func shear_y(kx: float, kz: float, dy: float) -> void:
	sheared += Vector3(kx, kz, dy)
	# stored points are Godot's (x negated): TMNF x = -v.x
	for key in _vis:
		var grp: Group = _vis[key]
		for k in grp.v.size():
			var v := grp.v[k]
			grp.v[k] = Vector3(v.x, v.y - kx * v.x + kz * v.z + dy, v.z)
			var n := grp.n[k]
			grp.n[k] = Vector3(n.x + kx * n.y, n.y, n.z - kz * n.y).normalized()
	for k in _col.size():
		var v := _col[k]
		_col[k] = Vector3(v.x, v.y - kx * v.x + kz * v.z + dy, v.z)


## Turns everything added so far by quarters x 90 deg about the vertical axis through (c.x, c.y)
## (TMNF x, z), from +x toward +z. A rotation keeps the winding, so faces stay outward.
func turn_y(quarters: int, c: Vector2) -> void:
	var q := posmod(quarters, 4)
	if q == 0:
		return
	var cs := [1.0, 0.0, -1.0, 0.0][q] as float
	var sn := [0.0, 1.0, 0.0, -1.0][q] as float
	# stored points are Godot's (x negated): TMNF x = -v.x
	var rot := func(v: Vector3, pivot: bool) -> Vector3:
		var x := -v.x - (c.x if pivot else 0.0)
		var z := v.z - (c.y if pivot else 0.0)
		var x2 := x * cs - z * sn + (c.x if pivot else 0.0)
		var z2 := x * sn + z * cs + (c.y if pivot else 0.0)
		return Vector3(-x2, v.y, z2)
	for key in _vis:
		var grp: Group = _vis[key]
		for k in grp.v.size():
			grp.v[k] = rot.call(grp.v[k], true)
			grp.n[k] = rot.call(grp.n[k], false)
	for k in _col.size():
		_col[k] = rot.call(_col[k], true)


## The lowest point (y, TMNF and Godot alike) of everything added so far; 0 when empty.
func min_y() -> float:
	var lo := INF
	for key in _vis:
		for v in (_vis[key] as Group).v:
			lo = minf(lo, v.y)
	for v in _col:
		lo = minf(lo, v.y)
	return 0.0 if lo == INF else lo


## Adds everything another builder holds (built separately, e.g. to be sheared on its own).
func merge(other: TmGeo) -> void:
	for key in other._vis:
		var src: Group = other._vis[key]
		var dst := _group(key)
		dst.v.append_array(src.v)
		dst.n.append_array(src.n)
		dst.uv.append_array(src.uv)
	_col.append_array(other._col)
	_surf.append_array(other._surf)


## Keeps only what lies on the side of the plane n . p <= d (TMNF coords): triangles crossing it are
## cut (normals and UVs interpolated). The cut is left open, for a piece whose mirror closes it.
func clip(n: Vector3, d: float) -> void:
	var gn := g(n)        # stored points are Godot's, and g() is its own inverse
	for key in _vis:
		var grp: Group = _vis[key]
		var out := Group.new()
		for k in range(0, grp.v.size(), 3):
			var poly := []
			for i in 3:
				poly.append([grp.v[k + i], grp.n[k + i], grp.uv[k + i]])
			poly = _clip_poly(poly, gn, d)
			for i in range(1, poly.size() - 1):
				for q: Array in [poly[0], poly[i], poly[i + 1]]:
					out.v.append(q[0])
					out.n.append((q[1] as Vector3).normalized())
					out.uv.append(q[2])
		_vis[key] = out
	var col := PackedVector3Array()
	var surf := PackedInt32Array()
	for f in _surf.size():
		var poly := []
		for i in 3:
			poly.append([_col[f * 3 + i], Vector3.ZERO, Vector2.ZERO])
		poly = _clip_poly(poly, gn, d)
		for i in range(1, poly.size() - 1):
			col.append_array([poly[0][0], poly[i][0], poly[i + 1][0]])
			surf.append(_surf[f])
	_col = col
	_surf = surf


## Sutherland-Hodgman against one plane; points are [position, normal, uv].
static func _clip_poly(poly: Array, n: Vector3, d: float) -> Array:
	var out := []
	for i in poly.size():
		var a: Array = poly[i]
		var b: Array = poly[(i + 1) % poly.size()]
		var da := n.dot(a[0]) - d
		var db := n.dot(b[0]) - d
		if da <= 0.0:
			out.append(a)
		if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0):
			var t := da / (da - db)
			out.append([(a[0] as Vector3).lerp(b[0], t), (a[1] as Vector3).lerp(b[1], t), (a[2] as Vector2).lerp(b[2], t)])
	return out


## Adds this geometry's mirror image across the plane x = a (TMNF coords), e.g. the other half of a
## symmetric piece built as one half.
func add_mirror_x(a: float) -> void:
	for key in _vis:
		var grp: Group = _vis[key]
		var count := grp.v.size()
		for k in range(0, count, 3):
			for i in [0, 2, 1]:      # reversed winding keeps the front side out
				var v := grp.v[k + i]
				var n := grp.n[k + i]
				grp.v.append(Vector3(-2.0 * a - v.x, v.y, v.z))
				grp.n.append(Vector3(-n.x, n.y, n.z))
				var uv := grp.uv[k + i]
				grp.uv.append(Vector2(-uv.x, uv.y))   # a mirrored texture reads backwards
	var faces := _surf.size()
	for f in faces:
		for i in [0, 2, 1]:
			var v := _col[f * 3 + i]
			_col.append(Vector3(-2.0 * a - v.x, v.y, v.z))
		_surf.append(_surf[f])


func is_empty() -> bool:
	return _vis.is_empty() and _col.is_empty()


## A Node3D: one MeshInstance3D (a surface per material) and a StaticBody3D (layer 1) whose
## "surfaces" meta holds the TMNF surface id of each collision face.
func build() -> Node3D:
	var root := Node3D.new()
	if not _vis.is_empty():
		var mesh := ArrayMesh.new()
		var keys := _vis.keys()
		keys.sort()
		for key in keys:
			var grp: Group = _vis[key]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = grp.v
			arrays[Mesh.ARRAY_NORMAL] = grp.n
			arrays[Mesh.ARRAY_TEX_UV] = grp.uv
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, TmMaterials.get_material(String(key)))
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mesh
		root.add_child(mi)
	if not _col.is_empty():
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(_col)
		cs.shape = shape
		body.add_child(cs)
		body.set_meta("surfaces", _surf)
		root.add_child(body)
	return root
