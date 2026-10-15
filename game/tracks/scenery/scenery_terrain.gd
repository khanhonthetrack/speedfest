class_name SceneryTerrain
extends RefCounted
## Ground / terrain heightfield that hugs the road: near the road it sits just below the lowest
## road edge, further away it blends to a theme height function. Elevated roads (bridges,
## highways) pass over the ground, sunk roads (underpasses) get a hole.
##
## The nearest road sample per vertex is found with a two-pass chamfer propagation over the
## grid (an approximate Voronoi), so it is linear in the vertex count.

var field: SceneryField
var cell: float = 12.0
var margin: float = 400.0
var base: float = 0.0
var flat_margin: float = 6.0       # flat shoulder beyond the road edge
var blend: float = 40.0            # blend distance from shoulder to far height
var elevated_above: float = 2.5    # road higher than (far + this) is not followed (bridges)
var hole_below: float = 1.2        # road lower than base - this cuts a hole (underpass)
var hole_margin: float = 3.0
var shoulder_drop: float = 0.3
var deck_clear: float = 5.0        # unfollowed (elevated) road: ground stays this far under the deck...
var deck_slope: float = 1.0        # ...plus this much per metre of distance from the road edge
var chunk_cells: int = 32
var far_fn: Callable               # func(x: float, z: float, side: float, road_y: float, edge_dist: float, sample: int) -> float
var follow_fn: Callable            # optional func(sample: int) -> float (1 = follow road, 0 = don't)
var color_fn: Callable             # optional func(x, z, h, edge_dist, sample) -> Color

var nx: int = 0
var nz: int = 0
var origin := Vector2.ZERO
var heights := PackedFloat32Array()
var edge := PackedFloat32Array()   # XZ distance to the road edge per vertex
var nearest := PackedInt32Array()
var holes := PackedByteArray()


func _init(p_field: SceneryField) -> void:
	field = p_field


func _site_d2(s: int, x: float, z: float) -> float:
	var p := field.pos[s]
	return (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z)


func compute() -> void:
	origin = field.bmin - Vector2(margin, margin)
	var size := field.extent() + Vector2(margin, margin) * 2.0
	nx = int(ceil(size.x / cell)) + 1
	nz = int(ceil(size.y / cell)) + 1
	var total := nx * nz
	nearest.resize(total)
	nearest.fill(-1)
	var best := PackedFloat32Array()
	best.resize(total)
	best.fill(1e18)
	# seed: every road sample claims its nearest grid vertex (and the 3x3 around it)
	for s in field.count:
		var p := field.pos[s]
		var gi := int(round((p.x - origin.x) / cell))
		var gj := int(round((p.z - origin.y) / cell))
		for di in range(-1, 2):
			for dj in range(-1, 2):
				var i := gi + di
				var j := gj + dj
				if i < 0 or j < 0 or i >= nx or j >= nz:
					continue
				var k := j * nx + i
				var d2 := _site_d2(s, origin.x + i * cell, origin.y + j * cell)
				if d2 < best[k]:
					best[k] = d2
					nearest[k] = s
	# two chamfer passes
	var fwd_n := [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)]
	var bwd_n := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]
	for pass_i in 2:
		var ns: Array = fwd_n if pass_i == 0 else bwd_n
		var j0 := 0 if pass_i == 0 else nz - 1
		var j1 := nz if pass_i == 0 else -1
		var jstep := 1 if pass_i == 0 else -1
		var i0 := 0 if pass_i == 0 else nx - 1
		var i1 := nx if pass_i == 0 else -1
		var j := j0
		while j != j1:
			var z := origin.y + j * cell
			var i := i0
			while i != i1:
				var k := j * nx + i
				var x := origin.x + i * cell
				for o in ns:
					var ii: int = i + o.x
					var jj: int = j + o.y
					if ii < 0 or jj < 0 or ii >= nx or jj >= nz:
						continue
					var s := nearest[jj * nx + ii]
					if s < 0:
						continue
					var d2 := _site_d2(s, x, z)
					if d2 < best[k]:
						best[k] = d2
						nearest[k] = s
				i += jstep
			j += jstep
	heights.resize(total)
	edge.resize(total)
	holes.resize(total)
	holes.fill(0)
	for j in nz:
		var z := origin.y + j * cell
		for i in nx:
			var x := origin.x + i * cell
			var k := j * nx + i
			var s := nearest[k]
			if s < 0:
				heights[k] = base
				edge[k] = 1e6
				continue
			# refine with the neighbouring segments
			var dist := sqrt(best[k])
			var lat := 0.0
			var road_y := field.pos[s].y
			var hw := field.half[s]
			var low := field.low[s]
			for sn: int in [s - 1, s]:
				if sn < 0 or sn + 1 >= field.count:
					continue
				var a := field.pos[sn]
				var b := field.pos[sn + 1]
				var ab := Vector2(b.x - a.x, b.z - a.z)
				var ap := Vector2(x - a.x, z - a.z)
				var l2 := ab.length_squared()
				var t := 0.0 if l2 < 1e-6 else clampf(ap.dot(ab) / l2, 0.0, 1.0)
				var dd := (ap - ab * t).length()
				if dd <= dist:
					dist = dd
					road_y = lerpf(a.y, b.y, t)
					low = lerpf(field.low[sn], field.low[sn + 1], t)
					hw = lerpf(field.half[sn], field.half[sn + 1], t)
			var r := field.rgt[s]
			lat = (x - field.pos[s].x) * r.x + (z - field.pos[s].z) * r.z
			var side := 1.0 if lat >= 0.0 else -1.0
			var ed := maxf(dist - hw, 0.0)
			edge[k] = ed
			var far: float = far_fn.call(x, z, side, road_y, ed, s) if far_fn.is_valid() else base
			var follow := 1.0
			if follow_fn.is_valid():
				follow = follow_fn.call(s)
			if road_y > far + elevated_above:
				follow = 0.0 if not follow_fn.is_valid() else follow
			var near_h := low - shoulder_drop
			var h := far
			if follow > 0.0:
				var t2 := clampf((ed - flat_margin) / maxf(blend, 0.01), 0.0, 1.0)
				t2 = t2 * t2 * (3.0 - 2.0 * t2)
				h = lerpf(lerpf(far, near_h, follow), far, t2)
			# never rise into an elevated deck
			if follow <= 0.0:
				h = minf(h, low - deck_clear + maxf(ed - 2.0, 0.0) * deck_slope)
			# never poke through the road surface
			if ed < 1.5 and h > near_h:
				h = near_h
			if road_y < base - hole_below and ed < hole_margin:
				holes[k] = 1
			heights[k] = h


func height_at(x: float, z: float) -> float:
	var fi := (x - origin.x) / cell
	var fj := (z - origin.y) / cell
	var i := clampi(int(floor(fi)), 0, nx - 2)
	var j := clampi(int(floor(fj)), 0, nz - 2)
	var u := clampf(fi - i, 0.0, 1.0)
	var w := clampf(fj - j, 0.0, 1.0)
	var h00 := heights[j * nx + i]
	var h10 := heights[j * nx + i + 1]
	var h01 := heights[(j + 1) * nx + i]
	var h11 := heights[(j + 1) * nx + i + 1]
	return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), w)


func edge_at(x: float, z: float) -> float:
	var i := clampi(int(round((x - origin.x) / cell)), 0, nx - 1)
	var j := clampi(int(round((z - origin.y) / cell)), 0, nz - 1)
	return edge[j * nx + i]


func inside(x: float, z: float) -> bool:
	return x >= origin.x and z >= origin.y and x <= origin.x + (nx - 1) * cell and z <= origin.y + (nz - 1) * cell


## Build chunked MeshInstance3D nodes under `parent` with `mat`.
func build_meshes(parent: Node3D, mat: Material, node_name := "Ground") -> int:
	var made := 0
	var cx := int(ceil(float(nx - 1) / chunk_cells))
	var cz := int(ceil(float(nz - 1) / chunk_cells))
	for ci in cx:
		for cj in cz:
			var m := SceneryMesh.new()
			var i0 := ci * chunk_cells
			var j0 := cj * chunk_cells
			var i1 := mini(i0 + chunk_cells, nx - 1)
			var j1 := mini(j0 + chunk_cells, nz - 1)
			var w := i1 - i0 + 1
			var base_v := m.v.size()
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var k := j * nx + i
					var x := origin.x + i * cell
					var z := origin.y + j * cell
					var h := heights[k]
					var hl := heights[j * nx + maxi(i - 1, 0)]
					var hr := heights[j * nx + mini(i + 1, nx - 1)]
					var hd := heights[maxi(j - 1, 0) * nx + i]
					var hu := heights[mini(j + 1, nz - 1) * nx + i]
					var nn := Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
					var col := Color(1, 1, 1, 1)
					if color_fn.is_valid():
						col = color_fn.call(x, z, h, edge[k], nearest[k])
					m.v.append(Vector3(x, h, z))
					m.n.append(nn)
					m.c.append(col)
					m.uv.append(Vector2(x, z))
					m.uv2.append(Vector2(minf(edge[k], 1000.0), 0.0))
			for j in range(j0, j1):
				for i in range(i0, i1):
					var k00 := j * nx + i
					if holes[k00] or holes[k00 + 1] or holes[k00 + nx] or holes[k00 + nx + 1]:
						continue
					var a := base_v + (j - j0) * w + (i - i0)
					var b := a + 1
					var c := a + w
					var d := c + 1
					# clockwise seen from above (+Y): a(x,z) -> c(x,z+1) is "down" on screen
					m.idx.append_array([a, b, d, a, d, c])
			if m.is_empty():
				continue
			var mi := MeshInstance3D.new()
			mi.name = "%s_%d_%d" % [node_name, ci, cj]
			mi.mesh = m.commit()
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mi.set_meta("scenery_ground", true)
			parent.add_child(mi)
			made += 1
	return made
