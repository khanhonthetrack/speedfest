class_name TrackBuilder
extends RefCounted
## Turns a layout definition (res://tracks/defs/<id>.gd) into a TrackPath plus track data,
## and builds all track geometry: road, curbs, walls, tunnels, supports, ground/terrain,
## checkpoint gates and boost pads. See docs/modules/tracks.md for the layout format.
##
## Layout "turtle": segments are driven one after another from a start pose.
##   {"s": 120}                          straight, optional "dy" (climb, eased), "w" (end width)
##   {"t": 90, "r": 40}                  turn (+ right / - left), optional "bank" (deg), "dy", "w"
##   {"loop": 20, "shift": 17}           vertical loop (radius, lateral shift to the right)
##   {"jump": {"ramp": 40, "h": 4, "gap": 20, "land": 60}}   kicker, gap (no road), landing
##   {"hermite": [Vector3 end, yaw_deg], "len_scale": 1.0}  smooth connector to a pose
##   {"close": true}                     circuits: smooth connector back to the start pose
## Markers (zero length): {"cp": true}, {"start": true}, {"finish": true},
##   {"boost": 10} (pad length), {"zone": "tunnel", "on": true/false}, {"walls": "both"|"left"|"right"|"none"}
## Any segment may also carry "zone": "tunnel"|"bridge"|"no_props" which covers just that segment.

const STEP := 2.5
const LOOP_STEP := 1.6
const G := 9.81

const FWD_EPS := 0.001


static func forward_of(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


static func right_of(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


static func _ease_bank(f: float) -> float:
	return smoothstep(0.0, 0.3, f) * (1.0 - smoothstep(0.7, 1.0, f))


## Result dictionary:
## {path: TrackPath, checkpoints: [d...], start_d, finish_d, boosts: [{d, len}], gaps: [[from,to]],
##  loops: [{from, to, radius}], jumps: [{...}], walls: [[from, to, mode]], points: PackedVector3Array}
static func build_layout(layout: Dictionary) -> Dictionary:
	var circuit: bool = layout.get("circuit", true)
	var width: float = layout.get("width", 14.0)
	var pos: Vector3 = layout.get("start_pos", Vector3.ZERO)
	var yaw: float = deg_to_rad(float(layout.get("start_yaw", 0.0)))
	var start_pose := [pos, yaw]
	var pts: Array[Vector3] = [pos]
	var tilts: Array[float] = [0.0]
	var dist: Array[float] = [0.0]
	var cps: Array[float] = []
	var boosts: Array = []
	var zones: Array = []
	var gaps: Array = []
	var loops: Array = []
	var jumps: Array = []
	var walls: Array = []
	var widths: Array = [[0.0, width]]
	var open_zones := {}
	var wall_mode: String = layout.get("walls", "both")
	var wall_from := 0.0
	var start_d := -1.0
	var finish_d := -1.0
	var cur_w := width

	var emit := func(p: Vector3, tilt: float) -> void:
		var last: Vector3 = pts[pts.size() - 1]
		var seg := p.distance_to(last)
		if seg < 0.01:
			return
		pts.append(p)
		tilts.append(tilt)
		dist.append(dist[dist.size() - 1] + seg)

	for seg in layout["segments"]:
		var s: Dictionary = seg
		var d0: float = dist[dist.size() - 1]
		# --- markers
		if s.has("cp"):
			cps.append(d0)
			continue
		if s.has("start"):
			start_d = d0
			continue
		if s.has("finish"):
			finish_d = d0
			continue
		if s.has("boost"):
			boosts.append({"d": d0, "len": float(s["boost"]), "accel": float(s.get("accel", 22.0)), "dur": float(s.get("dur", 1.4))})
			zones.append({"from": d0 - 2.0, "to": d0 + float(s["boost"]) + 2.0, "kind": "boost"})
			continue
		if s.has("walls") and s.size() == 1:
			if d0 > wall_from:
				walls.append([wall_from, d0, wall_mode])
			wall_mode = s["walls"]
			wall_from = d0
			continue
		if s.has("zone") and s.has("on"):
			if s["on"]:
				open_zones[s["zone"]] = d0
			elif open_zones.has(s["zone"]):
				zones.append({"from": open_zones[s["zone"]], "to": d0, "kind": s["zone"]})
				open_zones.erase(s["zone"])
			continue
		# --- geometry segments
		var start_p: Vector3 = pts[pts.size() - 1]
		var y0 := start_p.y
		var fwd := forward_of(yaw)
		var right := right_of(yaw)
		if s.has("s"):
			var L: float = s["s"]
			var dy: float = s.get("dy", 0.0)
			var n := maxi(1, ceili(L / STEP))
			for i in range(1, n + 1):
				var f := float(i) / n
				var p := start_p + fwd * (L * f)
				p.y = y0 + dy * smoothstep(0.0, 1.0, f)
				emit.call(p, 0.0)
		elif s.has("t"):
			var ang := deg_to_rad(float(s["t"]))
			var r: float = s["r"]
			var dy: float = s.get("dy", 0.0)
			var bank := deg_to_rad(float(s.get("bank", 0.0))) * signf(ang)
			var sg := signf(ang)
			var center := start_p + right * r * sg
			center.y = 0.0
			var rel := start_p - center
			rel.y = 0.0
			var n := maxi(2, ceili(absf(ang) * r / STEP))
			# Banking rolls the road about its centerline; lift the centerline so the low
			# (inner) edge stays at the original height instead of sinking into the ground.
			var lift_w := cur_w * 0.5 + 1.0
			for i in range(1, n + 1):
				var f := float(i) / n
				var p := center + rel.rotated(Vector3.UP, -ang * f)
				var tilt := bank * _ease_bank(f)
				p.y = y0 + dy * smoothstep(0.0, 1.0, f) + lift_w * sin(absf(tilt))
				emit.call(p, tilt)
			yaw -= ang
		elif s.has("loop"):
			var r: float = s["loop"]
			var shift: float = s.get("shift", r * 0.85)
			var n := ceili(TAU * r / LOOP_STEP)
			var lf := d0
			for i in range(1, n + 1):
				var a := TAU * float(i) / n
				var p := start_p + fwd * (r * sin(a)) + Vector3.UP * (r - r * cos(a)) + right * (shift * smoothstep(0.0, 1.0, float(i) / n))
				emit.call(p, 0.0)
			loops.append({"from": lf, "to": dist[dist.size() - 1], "radius": r, "shift": shift, "axis": right})
			zones.append({"from": lf - 10.0, "to": dist[dist.size() - 1] + 10.0, "kind": "loop"})
		elif s.has("jump"):
			var j: Dictionary = s["jump"]
			var L1: float = j.get("ramp", 40.0)
			var h: float = j.get("h", 4.0)
			var gap: float = j.get("gap", 20.0)
			var L2: float = j.get("land", 60.0)
			var j0 := d0
			# kicker: y = h (x/L1)^2
			var n1 := ceili(L1 / STEP)
			for i in range(1, n1 + 1):
				var x := L1 * i / n1
				var p := start_p + fwd * x
				p.y = y0 + h * pow(x / L1, 2.0)
				emit.call(p, 0.0)
			var lip_d: float = dist[dist.size() - 1]
			var slope0 := 2.0 * h / L1
			var k := slope0 / gap
			var n2 := ceili(gap / STEP)
			for i in range(1, n2 + 1):
				var x := gap * i / n2
				var p := start_p + fwd * (L1 + x)
				p.y = y0 + h + slope0 * x - k * x * x
				emit.call(p, 0.0)
			var land_d: float = dist[dist.size() - 1]
			var n3 := ceili(L2 / STEP)
			for i in range(1, n3 + 1):
				var x := L2 * i / n3
				var p := start_p + fwd * (L1 + gap + x)
				p.y = y0 + h * pow(1.0 - x / L2, 2.0)
				emit.call(p, 0.0)
			var end_d: float = dist[dist.size() - 1]
			gaps.append([lip_d, land_d])
			var theta := atan(slope0)
			var v_min := sqrt(G * gap / sin(2.0 * theta))
			jumps.append({"from": j0, "lip": lip_d, "land": land_d, "to": end_d, "h": h, "angle": theta,
				"gap": gap, "ramp": L1, "land_len": L2, "v_min": v_min, "base_y": y0})
			zones.append({"from": j0, "to": end_d, "kind": "jump"})
		elif s.has("hermite") or s.has("close"):
			var p1: Vector3
			var yaw1: float
			if s.has("close"):
				p1 = start_pose[0]
				yaw1 = start_pose[1]
			else:
				p1 = s["hermite"][0]
				yaw1 = deg_to_rad(float(s["hermite"][1]))
			var t0 := forward_of(yaw)
			var t1 := forward_of(yaw1)
			var flat0 := Vector3(start_p.x, 0, start_p.z)
			var flat1 := Vector3(p1.x, 0, p1.z)
			var m := flat0.distance_to(flat1) * float(s.get("len_scale", 1.0))
			var approx := m * 1.2
			var n := maxi(4, ceili(approx / STEP))
			var tlast := 1.0 if s.has("close") else 1.0
			for i in range(1, n + 1):
				var f := float(i) / n * tlast
				var f2 := f * f
				var f3 := f2 * f
				var h00 := 2 * f3 - 3 * f2 + 1
				var h10 := f3 - 2 * f2 + f
				var h01 := -2 * f3 + 3 * f2
				var h11 := f3 - f2
				var p := flat0 * h00 + t0 * m * h10 + flat1 * h01 + t1 * m * h11
				p.y = lerpf(y0, p1.y, smoothstep(0.0, 1.0, f))
				if s.has("close") and i == n:
					continue  # the start point closes the curve below
				emit.call(p, 0.0)
			yaw = yaw1
		else:
			push_warning("TrackBuilder: unknown segment %s" % str(s))
			continue
		var d1: float = dist[dist.size() - 1]
		if s.has("w"):
			widths.append([d0, cur_w])
			cur_w = float(s["w"])
			widths.append([d1, cur_w])
		if s.has("zone"):
			zones.append({"from": d0, "to": d1, "kind": s["zone"]})
		if layout.get("debug", false):
			print("  seg %s -> pos %s yaw %.0f d %.0f" % [str(s).left(40), str(pts[pts.size() - 1].snapped(Vector3.ONE)), rad_to_deg(yaw), d1])

	var poly_len: float = dist[dist.size() - 1]
	if circuit:
		var first: Vector3 = pts[0]
		poly_len += pts[pts.size() - 1].distance_to(first)
		pts.append(first)
		tilts.append(0.0)
		dist.append(poly_len)
	walls.append([wall_from, poly_len, wall_mode])
	for zk in open_zones:
		zones.append({"from": open_zones[zk], "to": poly_len, "kind": zk})
	if start_d < 0.0:
		start_d = 0.0
	if finish_d < 0.0:
		finish_d = start_d if circuit else poly_len - 20.0

	# Curve3D with Catmull-Rom handles through the dense points.
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	var n := pts.size()
	for i in n:
		var prev: Vector3
		var next: Vector3
		if i == 0:
			prev = pts[n - 2] if circuit else pts[0]
		else:
			prev = pts[i - 1]
		if i == n - 1:
			next = pts[1] if circuit else pts[n - 1]
		else:
			next = pts[i + 1]
		var tan := (next - prev) / 6.0
		curve.add_point(pts[i], -tan, tan)
		curve.set_point_tilt(i, tilts[i])
	var path := TrackPath.new(curve, circuit, width)
	var scale := path.length / poly_len
	var sc := func(d: float) -> float: return d * scale
	for i in cps.size():
		cps[i] = sc.call(cps[i])
	for b in boosts:
		b["d"] = sc.call(b["d"])
	for z in zones:
		z["from"] = sc.call(z["from"])
		z["to"] = sc.call(z["to"])
	for g in gaps:
		g[0] = sc.call(g[0])
		g[1] = sc.call(g[1])
	for l in loops:
		l["from"] = sc.call(l["from"])
		l["to"] = sc.call(l["to"])
	for j in jumps:
		for key in ["from", "lip", "land", "to"]:
			j[key] = sc.call(j[key])
	for w in walls:
		w[0] = sc.call(w[0])
		w[1] = sc.call(w[1])
	for w in widths:
		w[0] = sc.call(w[0])
	path.set_width_profile(widths)
	path.zones = zones
	if not loops.is_empty():
		var axes := []
		for l in loops:
			axes.append({"from": l["from"], "to": l["to"], "axis": l["axis"]})
		path.set_loop_axes(axes)
	return {
		"path": path, "checkpoints": cps, "start_d": sc.call(start_d), "finish_d": sc.call(finish_d),
		"boosts": boosts, "gaps": gaps, "loops": loops, "jumps": jumps, "walls": walls,
		"points": PackedVector3Array(pts), "circuit": circuit,
	}


static func in_ranges(d: float, ranges: Array, margin := 0.0) -> bool:
	for r in ranges:
		if d >= float(r[0]) - margin and d <= float(r[1]) + margin:
			return true
	return false


# =============================================================================
# Geometry
# =============================================================================

const CHUNK := 150.0
const RING := 1.5
const ROAD_DEPTH := 1.0
const WALL_GAP := 0.15          # space between road edge and barrier foot
const WALL_COLLISION_H := 2.6   # invisible collision height of barriers above the road
const LAYER_WORLD := 1
const LAYER_TRIGGER := 4        # physics layer 3
const MASK_CAR := 2             # physics layer 2

static var _mat_cache := {}


## Mesh accumulator: positions, normals, UV (u = along profile, v = distance), UV2 (custom).
class Acc:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	func add(p: Vector3, nn: Vector3, t: Vector2, t2 := Vector2.ZERO) -> int:
		v.append(p)
		n.append(nn)
		uv.append(t)
		uv2.append(t2)
		return v.size() - 1

	## a = near start, b = far start, c = far end, d = near end (front face on the normal side).
	func quad(a: int, b: int, c: int, d: int) -> void:
		idx.append_array(PackedInt32Array([a, b, c, a, c, d]))

	func box(xf: Transform3D, size: Vector3, uv_scale := 1.0) -> void:
		var h := size * 0.5
		var dirs := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
		for nrm: Vector3 in dirs:
			var u: Vector3 = Vector3.UP if absf(nrm.y) < 0.5 else Vector3.BACK
			var s := nrm.cross(u)
			var c := nrm * h
			var su := s * (h * s.abs()).length()
			var uu := u * (h * u.abs()).length()
			var wn := (xf.basis * nrm).normalized()
			var p0 := add(xf * (c - su - uu), wn, Vector2(0, 0) * uv_scale)
			var p1 := add(xf * (c - su + uu), wn, Vector2(0, 1) * uv_scale)
			var p2 := add(xf * (c + su + uu), wn, Vector2(1, 1) * uv_scale)
			var p3 := add(xf * (c + su - uu), wn, Vector2(1, 0) * uv_scale)
			quad(p0, p1, p2, p3)

	func is_empty() -> bool:
		return idx.is_empty()

	func commit(mesh: ArrayMesh, mat: Material) -> void:
		if idx.is_empty():
			return
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)

	func faces() -> PackedVector3Array:
		var f := PackedVector3Array()
		f.resize(idx.size())
		for i in idx.size():
			f[i] = v[idx[i]]
		return f


## Loft a 2D profile (frame-local x right / y up) along frames. profiles[i] belongs to ring i.
## Flat-shaded per profile segment. u = profile length, v = distance along the path.
static func loft(acc: Acc, frames: Array[Transform3D], ds: PackedFloat32Array, profiles: Array, uv2s := PackedVector2Array(), close_profile := false) -> void:
	if frames.size() < 2:
		return
	var np: int = profiles[0].size()
	var segs := np if close_profile else np - 1
	for k in segs:
		var k2 := (k + 1) % np
		var prev := -1
		var prev2 := -1
		for i in frames.size():
			var pr: PackedVector2Array = profiles[i]
			var a2 := pr[k]
			var b2 := pr[k2]
			var e := b2 - a2
			var ln := Vector2(-e.y, e.x).normalized()
			var f := frames[i]
			var wn := (f.basis.x * ln.x + f.basis.y * ln.y).normalized()
			var u0 := 0.0
			for q in k:
				u0 += pr[q].distance_to(pr[(q + 1) % np])
			var t2 := uv2s[i] if uv2s.size() > i else Vector2.ZERO
			var ia := acc.add(f * Vector3(a2.x, a2.y, 0.0), wn, Vector2(u0, ds[i]), t2)
			var ib := acc.add(f * Vector3(b2.x, b2.y, 0.0), wn, Vector2(u0 + e.length(), ds[i]), t2)
			if prev >= 0:
				acc.quad(prev, ia, ib, prev2)
			prev = ia
			prev2 = ib


static func mirror_profile(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(p.size() - 1, -1, -1):
		out.append(Vector2(-p[i].x, p[i].y))
	return out


static func offset_profile(p: PackedVector2Array, dx: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in p:
		out.append(Vector2(q.x + dx, q.y))
	return out


## Split [a, b] into runs that avoid the given ranges.
static func runs_excluding(a: float, b: float, excl: Array) -> Array:
	var runs := [[a, b]]
	for e in excl:
		var nr := []
		for r in runs:
			var e0: float = e[0]
			var e1: float = e[1]
			if e1 <= r[0] or e0 >= r[1]:
				nr.append(r)
				continue
			if e0 > r[0]:
				nr.append([r[0], e0])
			if e1 < r[1]:
				nr.append([e1, r[1]])
		runs = nr
	return runs.filter(func(r): return r[1] - r[0] > 0.5)


static func ring_ds(a: float, b: float, step: float) -> PackedFloat32Array:
	var n := maxi(1, ceili((b - a) / step))
	var out := PackedFloat32Array()
	for i in n + 1:
		out.append(lerpf(a, b, float(i) / n))
	return out


static func wall_mode_at(data: Dictionary, d: float) -> String:
	for w in data["walls"]:
		if d >= w[0] and d <= w[1]:
			return w[2]
	return "both"


static func horizontal_curvature(path: TrackPath, d: float) -> float:
	var a := path.sample_transform(d - 4.0).basis.z
	var b := path.sample_transform(d + 4.0).basis.z
	a.y = 0
	b.y = 0
	if a.length_squared() < 0.01 or b.length_squared() < 0.01:
		return 0.0
	return a.normalized().angle_to(b.normalized()) / 8.0


# ----------------------------------------------------------------- materials

static func material(key: String) -> Material:
	var compat := Settings.is_compat()
	var ck := "%s_%s" % [key, compat]
	if _mat_cache.has(ck):
		return _mat_cache[ck]
	var m: Material
	match key:
		"concrete":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.42, 0.42, 0.44)
			s.roughness = 0.85
			m = s
		"concrete_dark":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.2, 0.2, 0.22)
			s.roughness = 0.9
			m = s
		"barrier_neon_body":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.05, 0.05, 0.08)
			s.metallic = 0.6
			s.roughness = 0.3
			m = s
		"metal":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.72, 0.74, 0.78)
			s.metallic = 0.85
			s.roughness = 0.35
			m = s
		"metal_dark":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.08, 0.08, 0.1)
			s.metallic = 0.7
			s.roughness = 0.35
			m = s
		"tunnel":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.36, 0.34, 0.32)
			s.roughness = 0.8
			# fake sodium bounce light (there are no real lights on web / low quality)
			s.emission_enabled = true
			s.emission = Color(1.0, 0.6, 0.3)
			s.emission_energy_multiplier = 0.25 if (compat or Settings.quality < 2) else 0.08
			m = s
		"sidewalk":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.3, 0.3, 0.31)
			s.roughness = 0.35
			m = s
		"rock":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.35, 0.28, 0.24)
			s.roughness = 0.95
			m = s
		_:
			m = null
	if m == null:
		if key.begins_with("neon_"):
			var s := ShaderMaterial.new()
			s.shader = load("res://shaders/track_neon.gdshader")
			s.set_shader_parameter("color", _neon_color(key.substr(5)))
			s.set_shader_parameter("energy", 2.6 if compat else 3.2)
			m = s
		else:
			var s := StandardMaterial3D.new()
			s.albedo_color = Color.MAGENTA
			m = s
	_mat_cache[ck] = m
	return m


static func _neon_color(name: String) -> Color:
	match name:
		"cyan":
			return Color(0.0, 0.85, 1.0)
		"magenta":
			return Color(1.0, 0.1, 0.75)
		"orange":
			return Color(1.0, 0.55, 0.12)
		"sodium":
			return Color(1.0, 0.62, 0.25)
		"white":
			return Color(1.0, 0.95, 0.9)
		"red":
			return Color(1.0, 0.1, 0.1)
		"green":
			return Color(0.2, 1.0, 0.4)
		"amber":
			return Color(1.0, 0.7, 0.1)
	return Color(0.5, 0.5, 1.0)


static func road_material(style: String, wet: bool) -> ShaderMaterial:
	var ck := "road_%s_%s_%s" % [style, wet, Settings.is_compat()]
	if _mat_cache.has(ck):
		return _mat_cache[ck]
	var s := ShaderMaterial.new()
	s.shader = load("res://shaders/road.gdshader")
	s.set_shader_parameter("wetness", 0.85 if wet else 0.0)
	match style:
		"neon":
			s.set_shader_parameter("asphalt_color", Color(0.07, 0.07, 0.1))
			s.set_shader_parameter("edge_color", Color(0.0, 0.85, 1.0))
			s.set_shader_parameter("edge_emission", 2.2)
			s.set_shader_parameter("center_mode", 0)
			s.set_shader_parameter("curb_a", Color(1.0, 0.1, 0.75))
			s.set_shader_parameter("curb_b", Color(0.06, 0.06, 0.08))
			s.set_shader_parameter("lane_count", 2)
			s.set_shader_parameter("tech_panels", 1.0)
		"guardrail":
			s.set_shader_parameter("asphalt_color", Color(0.2, 0.19, 0.19))
			s.set_shader_parameter("edge_color", Color(0.95, 0.95, 0.92))
			s.set_shader_parameter("edge_emission", 0.0)
			s.set_shader_parameter("center_mode", 2)
			s.set_shader_parameter("lane_count", 2)
		_:
			s.set_shader_parameter("asphalt_color", Color(0.11, 0.11, 0.12))
			s.set_shader_parameter("edge_color", Color(0.92, 0.92, 0.9))
			s.set_shader_parameter("edge_emission", 0.0)
			s.set_shader_parameter("center_mode", 1)
			s.set_shader_parameter("lane_count", 3)
	var fake := 1.0 if (Settings.is_compat() or Settings.quality < 2) else 0.3
	s.set_shader_parameter("tunnel_fake", 0.9 * fake)
	s.set_shader_parameter("paint_glow", 0.5 if style == "concrete" else 0.15)
	_mat_cache[ck] = s
	return s


static func shader_material(path: String, params := {}) -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.shader = load(path)
	for k in params:
		s.set_shader_parameter(k, params[k])
	return s


# ----------------------------------------------------------------- road + walls

## Builds road chunks (visual + collision), barriers, skirts and the tunnel shells.
static func build_road(root: Node3D, data: Dictionary, layout: Dictionary) -> void:
	var path: TrackPath = data["path"]
	var L := path.length
	var style: String = layout.get("wall_style", "concrete")
	var road_mat := road_material(style, layout.get("wet", false))
	var side_mat := material("concrete_dark") if style != "neon" else material("barrier_neon_body")
	var ground_y: float = layout.get("ground_y", 0.0)
	var has_flat_ground: bool = layout.get("ground", "none") in ["city", "arena"]
	var gaps: Array = data["gaps"]
	var loop_ranges: Array = []
	for l in data["loops"]:
		loop_ranges.append([l["from"], l["to"]])
	var bridge_ranges: Array = []
	var tunnel_ranges: Array = []
	for z in path.zones:
		if z["kind"] == "bridge":
			bridge_ranges.append([z["from"], z["to"]])
		elif z["kind"] == "tunnel":
			tunnel_ranges.append([z["from"], z["to"]])
	var nchunks := maxi(1, ceili(L / CHUNK))
	var all_faces := PackedVector3Array()
	var roads := Node3D.new()
	roads.name = "Road"
	root.add_child(roads)
	for c in nchunks:
		var c0 := c * L / nchunks
		var c1 := (c + 1) * L / nchunks
		var top := Acc.new()
		var sides := Acc.new()
		var wall := Acc.new()
		var neon := Acc.new()
		var col := Acc.new()
		var posts: Array[Transform3D] = []
		var loop_glow := Acc.new()
		var walk := Acc.new()
		for run in runs_excluding(c0, c1, gaps):
			var step := RING
			if in_ranges((run[0] + run[1]) * 0.5, loop_ranges, 5.0):
				step = 1.0
			var ds := ring_ds(run[0], run[1], step)
			var frames: Array[Transform3D] = []
			var top_prof: Array = []
			var side_prof: Array = []
			var uv2s := PackedVector2Array()
			for d in ds:
				var f := path.sample_transform(d)
				frames.append(f)
				var hw := path.width_at(d) * 0.5
				top_prof.append(PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0)]))
				var depth: float = layout.get("road_depth", ROAD_DEPTH)
				if in_ranges(d, bridge_ranges):
					depth = 1.8
				var bottom := -depth
				# Skirt down to the ground on low ramps so they read as solid structures.
				if has_flat_ground and f.basis.y.y > 0.8:
					var above := f.origin.y - ground_y
					if above > 0.3 and above < 7.0 and not in_ranges(d, loop_ranges, 2.0):
						bottom = -(above + 0.3) / f.basis.y.y
						if layout.get("ground", "") == "arena" and in_ranges(d, gaps, 8.0):
							bottom = -(above + 16.0) / f.basis.y.y
				side_prof.append(PackedVector2Array([Vector2(hw, 0), Vector2(hw, bottom), Vector2(-hw, bottom), Vector2(-hw, 0)]))
				var curb := 0.0
				if not in_ranges(d, loop_ranges, 4.0):
					curb = smoothstep(1.0 / 260.0, 1.0 / 110.0, horizontal_curvature(path, d))
				if in_ranges(d, tunnel_ranges, -1.0):
					curb += 2.0   # tunnel flag for the road shader
				uv2s.append(Vector2(hw, curb))
			loft(top, frames, ds, top_prof, uv2s)
			loft(sides, frames, ds, side_prof)
			if in_ranges((run[0] + run[1]) * 0.5, loop_ranges, 12.0):
				var glow_r: Array = []
				var glow_l: Array = []
				for i in frames.size():
					var hw3: float = top_prof[i][1].x + 0.02
					glow_r.append(PackedVector2Array([Vector2(hw3, -0.35), Vector2(hw3, -0.12)]))
					glow_l.append(PackedVector2Array([Vector2(-hw3, -0.12), Vector2(-hw3, -0.35)]))
				loft(loop_glow, frames, ds, glow_r)
				loft(loop_glow, frames, ds, glow_l)
			loft(col, frames, ds, top_prof)
			# collision for the slab sides (short) so cars don't snag on edges
			var cside: Array = []
			for i in frames.size():
				var hw2: float = top_prof[i][1].x
				cside.append(PackedVector2Array([Vector2(hw2, 0), Vector2(hw2, -0.6), Vector2(-hw2, -0.6), Vector2(-hw2, 0)]))
			loft(col, frames, ds, cside)
		# --- barriers
		var wall_excl := gaps.duplicate()
		for l in loop_ranges:
			wall_excl.append([l[0] - 1.0, l[1] + 1.0])
		for run in runs_excluding(c0, c1, wall_excl):
			var ds := ring_ds(run[0], run[1], RING * 2.0)
			for side in [1.0, -1.0]:
				var sub_runs := []
				var cur := PackedFloat32Array()
				for d in ds:
					var m := wall_mode_at(data, d)
					var on: bool = m == "both" or (m == "right" and side > 0) or (m == "left" and side < 0)
					if on:
						cur.append(d)
					elif cur.size() > 0:
						sub_runs.append(cur)
						cur = PackedFloat32Array()
				if cur.size() > 1:
					sub_runs.append(cur)
				for sr: PackedFloat32Array in sub_runs:
					if sr.size() < 2:
						continue
					_build_wall_run(path, sr, side, style, wall, neon, col, posts, walk)
		var mesh := ArrayMesh.new()
		top.commit(mesh, road_mat)
		sides.commit(mesh, side_mat)
		loop_glow.commit(mesh, material("neon_magenta"))
		match style:
			"neon":
				wall.commit(mesh, material("barrier_neon_body"))
				neon.commit(mesh, material("neon_cyan"))
			"guardrail":
				wall.commit(mesh, material("metal"))
			_:
				wall.commit(mesh, material("concrete"))
				neon.commit(mesh, material("neon_amber"))
				walk.commit(mesh, material("sidewalk"))
		if mesh.get_surface_count() > 0:
			var mi := MeshInstance3D.new()
			mi.name = "Chunk%d" % c
			mi.mesh = mesh
			roads.add_child(mi)
		if not posts.is_empty():
			_add_multimesh(roads, _box_mesh(Vector3(0.14, 1.0, 0.14)), posts, material("metal"), "Posts%d" % c)
		if not col.is_empty():
			all_faces.append_array(col.faces())
	# One seamless collision mesh for the whole road: separate per-chunk bodies left internal
	# edges at the seams that cars could snag on under load (e.g. at the crown of the loop).
	if not all_faces.is_empty():
		var sb := StaticBody3D.new()
		sb.name = "RoadBody"
		sb.collision_layer = LAYER_WORLD
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(all_faces)
		cs.shape = shape
		sb.add_child(cs)
		roads.add_child(sb)
	for t in tunnel_ranges:
		_build_tunnel(root, path, t[0], t[1], style)


static func _build_wall_run(path: TrackPath, ds: PackedFloat32Array, side: float, style: String, wall: Acc, neon: Acc, col: Acc, posts: Array[Transform3D], walk: Acc = null) -> void:
	var frames: Array[Transform3D] = []
	var vis: Array = []
	var strip: Array = []
	var cprof: Array = []
	for d in ds:
		var f := path.sample_transform(d)
		frames.append(f)
		var o := path.width_at(d) * 0.5 + WALL_GAP
		var p: PackedVector2Array
		var s := PackedVector2Array()
		match style:
			"neon":
				p = PackedVector2Array([Vector2(o, -0.4), Vector2(o, 1.05), Vector2(o + 0.5, 1.05), Vector2(o + 0.5, -0.4)])
				s = PackedVector2Array([Vector2(o - 0.02, 0.72), Vector2(o - 0.02, 0.86)])
			"guardrail":
				p = PackedVector2Array([Vector2(o + 0.1, 0.45), Vector2(o + 0.04, 0.55), Vector2(o + 0.04, 0.7), Vector2(o + 0.1, 0.8), Vector2(o + 0.2, 0.8), Vector2(o + 0.2, 0.45)])
			_:
				p = PackedVector2Array([Vector2(o, -0.3), Vector2(o, 0.1), Vector2(o + 0.16, 0.32), Vector2(o + 0.26, 1.0), Vector2(o + 0.44, 1.0), Vector2(o + 0.54, 0.32), Vector2(o + 0.7, 0.1), Vector2(o + 0.7, -0.3)])
				s = PackedVector2Array([Vector2(o + 0.255, 0.9), Vector2(o + 0.262, 0.97)])
		# collision is taller than the visual barrier so fast cars can't climb over it
		var c := PackedVector2Array([Vector2(o, -0.6), Vector2(o, WALL_COLLISION_H), Vector2(o + 0.6, WALL_COLLISION_H), Vector2(o + 0.6, -0.6)])
		if side < 0:
			p = mirror_profile(p)
			c = mirror_profile(c)
			if s.size() > 0:
				s = mirror_profile(s)
		vis.append(p)
		cprof.append(c)
		strip.append(s)
	loft(wall, frames, ds, vis)
	loft(col, frames, ds, cprof)
	if style == "concrete" and walk != null:
		# raised sidewalk behind the barrier, only where the road is at street level
		var wf: Array[Transform3D] = []
		var wds := PackedFloat32Array()
		var wp: Array = []
		for i in frames.size():
			var f := frames[i]
			if f.origin.y > 0.6 or f.basis.y.y < 0.97:
				if wf.size() > 1:
					loft(walk, wf, wds, wp)
				wf = []
				wds = PackedFloat32Array()
				wp = []
				continue
			var o := path.width_at(ds[i]) * 0.5 + WALL_GAP + 0.7
			var q := PackedVector2Array([Vector2(o, -0.2), Vector2(o, 0.18), Vector2(o + 5.0, 0.18), Vector2(o + 5.0, -0.2)])
			if side < 0:
				q = mirror_profile(q)
			wf.append(f)
			wds.append(ds[i])
			wp.append(q)
		if wf.size() > 1:
			loft(walk, wf, wds, wp)
	if style == "neon" or style == "concrete":
		# reflector / neon strip: only every other piece for concrete (reflector dashes)
		if style == "neon":
			loft(neon, frames, ds, strip)
		else:
			for i in range(0, frames.size() - 1, 4):
				var fr: Array[Transform3D] = [frames[i], frames[i + 1]]
				loft(neon, fr, PackedFloat32Array([ds[i], ds[i + 1]]), [strip[i], strip[i + 1]])
	if style == "guardrail":
		for i in range(0, frames.size(), 2):
			var f := frames[i]
			var o := path.width_at(ds[i]) * 0.5 + WALL_GAP + 0.28
			var pos := f * Vector3(o * side, 0.0, 0.0)
			var b := Basis(f.basis.x, f.basis.y, f.basis.z)
			posts.append(Transform3D(b.scaled_local(Vector3(1, 1.05, 1)), pos + f.basis.y * 0.35))


static func _box_mesh(size: Vector3) -> ArrayMesh:
	var a := Acc.new()
	a.box(Transform3D.IDENTITY, size)
	var m := ArrayMesh.new()
	a.commit(m, null)
	return m


static func _add_multimesh(parent: Node3D, mesh: Mesh, xforms: Array[Transform3D], mat: Material, node_name: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)
	return mmi


static func _build_tunnel(root: Node3D, path: TrackPath, d0: float, d1: float, style: String) -> void:
	var ds := ring_ds(d0, d1, 2.0)
	var frames: Array[Transform3D] = []
	var inner: Array = []
	var outer: Array = []
	var lights_l: Array = []
	var lights_r: Array = []
	for d in ds:
		frames.append(path.sample_transform(d))
		var rw := path.width_at(d) * 0.5
		var hw := rw + 1.2
		var ip := PackedVector2Array()
		# inner arch, ordered so normals face inward: right shoulder -> right wall -> over the
		# top -> left wall -> left shoulder. The shoulders close the gap to the road edge.
		ip.append(Vector2(rw - 0.05, -0.02))
		ip.append(Vector2(hw, -0.02))
		ip.append(Vector2(hw, 5.0))
		for k in range(1, 8):
			var a := PI * k / 8.0
			ip.append(Vector2(hw * cos(a), 5.0 + 3.2 * sin(a)))
		ip.append(Vector2(-hw, 5.0))
		ip.append(Vector2(-hw, -0.02))
		ip.append(Vector2(-rw + 0.05, -0.02))
		inner.append(ip)
		var oh := hw + 1.6
		outer.append(PackedVector2Array([Vector2(-oh, -0.5), Vector2(-oh, 9.4), Vector2(oh, 9.4), Vector2(oh, -0.5)]))
		var lx := hw * 0.45
		lights_r.append(PackedVector2Array([Vector2(lx - 0.25, 7.62), Vector2(lx + 0.25, 7.58)]))
		lights_l.append(PackedVector2Array([Vector2(-lx - 0.25, 7.58), Vector2(-lx + 0.25, 7.62)]))
	# Inner profile is ordered right->left over the top, so its loft normals point inward; flip for outer.
	var shell := Acc.new()
	var lit := Acc.new()
	loft(shell, frames, ds, inner)
	var outer_acc := Acc.new()
	loft(outer_acc, frames, ds, outer)
	# light strips face down: reverse order gives downward normals
	var lr2: Array = []
	var ll2: Array = []
	for i in lights_r.size():
		var a: PackedVector2Array = lights_r[i]
		var b: PackedVector2Array = lights_l[i]
		lr2.append(PackedVector2Array([a[1] - Vector2(0, 0.05), a[0] - Vector2(0, 0.05)]))
		ll2.append(PackedVector2Array([b[1] - Vector2(0, 0.05), b[0] - Vector2(0, 0.05)]))
	loft(lit, frames, ds, lr2)
	loft(lit, frames, ds, ll2)
	# portals: faces between the outer box and the inner arch at both ends
	for end in [0, 1]:
		var i := 0 if end == 0 else frames.size() - 1
		var f := frames[i]
		var nrm := f.basis.z if end == 0 else -f.basis.z
		var ip: PackedVector2Array = inner[i]
		var op: PackedVector2Array = outer[i]
		var oh: float = absf(op[0].x)
		var top := 9.4
		# collect quads as (x0, y0_low, x1, y1_low) -> top; plus side columns
		var cols := []
		for k in range(2, ip.size() - 3):
			cols.append([ip[k], ip[k + 1]])
		cols.append([Vector2(-oh, -0.5), Vector2(ip[ip.size() - 2].x, -0.5)])
		cols.append([Vector2(ip[1].x, -0.5), Vector2(oh, -0.5)])
		for cpair in cols:
			var p0: Vector2 = cpair[0]
			var p1: Vector2 = cpair[1]
			if p0.x > p1.x:
				var tmp := p0
				p0 = p1
				p1 = tmp
			var a0 := outer_acc.add(f * Vector3(p0.x, p0.y, 0), nrm, p0 * 0.25)
			var b0 := outer_acc.add(f * Vector3(p0.x, top, 0), nrm, Vector2(p0.x, top) * 0.25)
			var c0 := outer_acc.add(f * Vector3(p1.x, top, 0), nrm, Vector2(p1.x, top) * 0.25)
			var e0 := outer_acc.add(f * Vector3(p1.x, p1.y, 0), nrm, p1 * 0.25)
			if end == 0:
				outer_acc.quad(a0, b0, c0, e0)
			else:
				outer_acc.quad(e0, c0, b0, a0)
	var mesh := ArrayMesh.new()
	shell.commit(mesh, material("tunnel"))
	outer_acc.commit(mesh, material("concrete") if style != "guardrail" else material("rock"))
	lit.commit(mesh, material("neon_sodium"))
	var mi := MeshInstance3D.new()
	mi.name = "Tunnel"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	root.add_child(mi)
	# A few real lights inside the tunnel when the budget allows (Forward+ only).
	if not Settings.is_compat() and Settings.quality >= 2:
		var count := mini(6, int((d1 - d0) / 30.0))
		for k in count:
			var d := lerpf(d0, d1, (k + 0.5) / count)
			var ol := OmniLight3D.new()
			ol.light_color = Color(1.0, 0.65, 0.3)
			ol.light_energy = 2.0
			ol.omni_range = 16.0
			ol.position = path.sample_transform(d) * Vector3(0, 6.5, 0)
			root.add_child(ol)


# ----------------------------------------------------------------- supports

## Pillars under elevated road (and the coast bridge), avoiding roads below.
static func build_supports(root: Node3D, data: Dictionary, layout: Dictionary) -> void:
	var path: TrackPath = data["path"]
	var ground_kind: String = layout.get("ground", "none")
	var ground_y: float = layout.get("ground_y", 0.0)
	var bridges: Array = []
	var tunnels: Array = []
	for z in path.zones:
		if z["kind"] == "bridge":
			bridges.append([z["from"], z["to"]])
		elif z["kind"] == "tunnel":
			tunnels.append([z["from"], z["to"]])
	var loops: Array = []
	for l in data["loops"]:
		loops.append([l["from"], l["to"]])
	# sample the path for "is there road below this point" checks
	var samples: Array[Vector3] = []
	var sw: Array[float] = []
	var sd := 0.0
	while sd < path.length:
		samples.append(path.sample_position(sd))
		sw.append(path.width_at(sd) * 0.5)
		sd += 3.0
	var pillars: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var body := StaticBody3D.new()
	body.name = "Supports"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	var d := 10.0
	var spacing := 26.0
	while d < path.length - 5.0:
		var f := path.sample_transform(d)
		var base_y := ground_y
		var ok := false
		if ground_kind == "terrain":
			# pillars only near the ends; the arch carries the main span
			ok = in_ranges(d, bridges) and not in_ranges(d, _shrink(bridges, ARCH_INSET + 8.0))
			base_y = -9.0
		else:
			ok = f.origin.y - ground_y > 6.0
		if ok and not in_ranges(d, tunnels) and not in_ranges(d, loops, 5.0) and not in_ranges(d, data["gaps"], 3.0):
			var hw := path.width_at(d) * 0.5
			var xs := [0.0] if hw < 8.5 else [-hw * 0.45, hw * 0.45]
			if ground_kind == "terrain":
				xs = [-hw * 0.5, hw * 0.5]
			var placed := false
			for x in xs:
				var top := f * Vector3(x, -ROAD_DEPTH - (0.8 if ground_kind == "terrain" else 0.0), 0)
				var foot := Vector3(top.x, base_y, top.z)
				# skip if another road passes under this pillar
				var blocked := false
				for i in samples.size():
					var sp := samples[i]
					if sp.y < top.y - 3.0 and Vector2(sp.x - foot.x, sp.z - foot.z).length() < sw[i] + 2.5:
						blocked = true
						break
				if blocked:
					continue
				var h := top.y - base_y
				if h < 1.0:
					continue
				var yaw_b := Basis.looking_at(Vector3(f.basis.z.x, 0, f.basis.z.z).normalized() * -1.0, Vector3.UP)
				var thick := 1.4 if ground_kind != "terrain" else 2.4
				pillars.append(Transform3D(yaw_b.scaled_local(Vector3(thick, h, thick)), Vector3(top.x, base_y + h * 0.5, top.z)))
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(thick, h, thick)
				cs.shape = bs
				cs.transform = Transform3D(yaw_b, Vector3(top.x, base_y + h * 0.5, top.z))
				body.add_child(cs)
				placed = true
			if placed:
				var cap_c := f * Vector3(0, -ROAD_DEPTH - 0.4, 0)
				caps.append(Transform3D(f.basis.scaled_local(Vector3(hw * 1.6, 0.8, 1.8)), cap_c))
		d += spacing if ground_kind != "terrain" else 34.0
	if ground_kind == "terrain":
		for b in bridges:
			_build_arch_bridge(root, path, b[0] + ARCH_INSET, b[1] - ARCH_INSET)
	if pillars.is_empty():
		body.free()
		return
	root.add_child(body)
	var pm := _box_mesh(Vector3.ONE)
	_add_multimesh(root, pm, pillars, material("concrete"), "Pillars")
	_add_multimesh(root, pm, caps, material("concrete"), "PillarCaps")


# ----------------------------------------------------------------- ground

static func path_bbox(path: TrackPath, margin: float) -> Rect2:
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	var d := 0.0
	while d <= path.length:
		var p := path.sample_position(d)
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.z))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.z))
		d += 4.0
	return Rect2(mn - Vector2(margin, margin), mx - mn + Vector2(margin, margin) * 2.0)


## Flat ground for city/arena (arena: pits under the jump gaps).
static func build_flat_ground(root: Node3D, data: Dictionary, layout: Dictionary) -> void:
	var path: TrackPath = data["path"]
	var kind: String = layout.get("ground", "city")
	var gy: float = float(layout.get("ground_y", 0.0)) - 0.12
	var rect := path_bbox(path, 260.0 if kind == "city" else 140.0)
	var tile := 10.0
	var nx := ceili(rect.size.x / tile)
	var nz := ceili(rect.size.y / tile)
	var pit := PackedByteArray()
	pit.resize(nx * nz)
	pit.fill(0)
	var any_pit := false
	if kind == "arena":
		for g in data["gaps"]:
			# mark tiles under the gap (and a margin) as pit
			var d: float = g[0] - 6.0
			while d <= g[1] + 6.0:
				var f := path.sample_transform(d)
				var hw := path.width_at(d) * 0.5 + 4.0
				var lx := -hw
				while lx <= hw:
					var p := f.origin + f.basis.x * lx
					var ix := int((p.x - rect.position.x) / tile)
					var iz := int((p.z - rect.position.y) / tile)
					if ix >= 0 and iz >= 0 and ix < nx and iz < nz:
						pit[iz * nx + ix] = 1
						any_pit = true
					lx += 2.0
				d += 2.0
	var floor_acc := Acc.new()
	var pit_acc := Acc.new()
	var edge_acc := Acc.new()
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	for iz in nz:
		var ix := 0
		while ix < nx:
			if pit[iz * nx + ix] == 1:
				ix += 1
				continue
			var start := ix
			while ix < nx and pit[iz * nx + ix] == 0:
				ix += 1
			var x0 := rect.position.x + start * tile
			var x1 := rect.position.x + ix * tile
			var z0 := rect.position.y + iz * tile
			var z1 := z0 + tile
			var a := floor_acc.add(Vector3(x0, gy, z1), Vector3.UP, Vector2(x0, z1))
			var b := floor_acc.add(Vector3(x0, gy, z0), Vector3.UP, Vector2(x0, z0))
			var c := floor_acc.add(Vector3(x1, gy, z0), Vector3.UP, Vector2(x1, z0))
			var e := floor_acc.add(Vector3(x1, gy, z1), Vector3.UP, Vector2(x1, z1))
			floor_acc.quad(a, b, c, e)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(x1 - x0, 1.0, tile)
			cs.shape = bs
			cs.position = Vector3((x0 + x1) * 0.5, gy - 0.5, (z0 + z1) * 0.5)
			body.add_child(cs)
	if any_pit:
		var depth := -16.0
		for iz in nz:
			for ix in nx:
				if pit[iz * nx + ix] == 0:
					continue
				var x0 := rect.position.x + ix * tile
				var z0 := rect.position.y + iz * tile
				# pit bottom
				var a := pit_acc.add(Vector3(x0, depth, z0 + tile), Vector3.UP, Vector2.ZERO)
				var b := pit_acc.add(Vector3(x0, depth, z0), Vector3.UP, Vector2.ZERO)
				var c := pit_acc.add(Vector3(x0 + tile, depth, z0), Vector3.UP, Vector2.ZERO)
				var e := pit_acc.add(Vector3(x0 + tile, depth, z0 + tile), Vector3.UP, Vector2.ZERO)
				pit_acc.quad(a, b, c, e)
				# walls toward solid neighbours, facing into the pit
				var nbs := [[1, 0], [-1, 0], [0, 1], [0, -1]]
				for nb in nbs:
					var jx: int = ix + nb[0]
					var jz: int = iz + nb[1]
					if jx >= 0 and jz >= 0 and jx < nx and jz < nz and pit[jz * nx + jx] == 1:
						continue
					var nrm := Vector3(-nb[0], 0, -nb[1])
					var cx: float = x0 + tile * 0.5 + nb[0] * tile * 0.5
					var cz: float = z0 + tile * 0.5 + nb[1] * tile * 0.5
					var tang := Vector3(nb[1], 0, -nb[0]) * tile * 0.5
					var p0 := Vector3(cx, depth, cz) - tang
					var p1 := Vector3(cx, depth, cz) + tang
					var q0 := pit_acc.add(p0, nrm, Vector2.ZERO)
					var q1 := pit_acc.add(Vector3(p0.x, gy, p0.z), nrm, Vector2.ZERO)
					var q2 := pit_acc.add(Vector3(p1.x, gy, p1.z), nrm, Vector2.ZERO)
					var q3 := pit_acc.add(p1, nrm, Vector2.ZERO)
					pit_acc.quad(q0, q1, q2, q3)
					pit_acc.quad(q3, q2, q1, q0)
					var r0 := edge_acc.add(Vector3(p0.x, gy - 0.6, p0.z) + nrm * 0.02, nrm, Vector2.ZERO)
					var r1 := edge_acc.add(Vector3(p0.x, gy - 0.05, p0.z) + nrm * 0.02, nrm, Vector2.ZERO)
					var r2 := edge_acc.add(Vector3(p1.x, gy - 0.05, p1.z) + nrm * 0.02, nrm, Vector2.ZERO)
					var r3 := edge_acc.add(Vector3(p1.x, gy - 0.6, p1.z) + nrm * 0.02, nrm, Vector2.ZERO)
					edge_acc.quad(r0, r1, r2, r3)
					edge_acc.quad(r3, r2, r1, r0)
	var mesh := ArrayMesh.new()
	var fm := shader_material("res://shaders/track_floor.gdshader", {
		"base_color": Color(0.05, 0.05, 0.07) if kind == "arena" else Color(0.07, 0.07, 0.08),
		"grid_color": Color(0.45, 0.15, 1.0) if kind == "arena" else Color(0.0, 0.0, 0.0),
		"grid_energy": 0.7 if kind == "arena" else 0.0,
		"wetness": 0.8 if layout.get("wet", false) else 0.15,
		"tile": 20.0 if kind == "arena" else 6.0,
	})
	floor_acc.commit(mesh, fm)
	pit_acc.commit(mesh, material("metal_dark"))
	edge_acc.commit(mesh, material("neon_magenta"))
	var mi := MeshInstance3D.new()
	mi.name = "GroundMesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# layout "ground_visual": false keeps only the collision (when scenery draws the ground)
	mi.visible = layout.get("ground_visual", true)
	root.add_child(mi)
	root.add_child(body)


## Coast terrain: a heightfield that hugs the road, rises into cliffs on the left (land)
## and falls into the sea on the right. The bay under the bridge drops to the sea floor,
## and a mountain covers the tunnel.
static func build_terrain(root: Node3D, data: Dictionary, layout: Dictionary) -> void:
	var path: TrackPath = data["path"]
	var rect := path_bbox(path, 280.0)
	var cell := 10.0
	var nx := ceili(rect.size.x / cell) + 1
	var nz := ceili(rect.size.y / cell) + 1
	var count := nx * nz
	var best := PackedFloat32Array()
	best.resize(count)
	best.fill(1e12)
	var ry := PackedFloat32Array()
	ry.resize(count)
	var lat := PackedFloat32Array()
	lat.resize(count)
	var dd := PackedFloat32Array()
	dd.resize(count)
	var radius := 290.0
	var rc := ceili(radius / cell)
	var d := 0.0
	while d <= path.length:
		var f := path.sample_transform(d)
		var p := f.origin
		var right := Vector3(f.basis.x.x, 0, f.basis.x.z).normalized()
		var cx := int(round((p.x - rect.position.x) / cell))
		var cz := int(round((p.z - rect.position.y) / cell))
		for iz in range(maxi(0, cz - rc), mini(nz, cz + rc + 1)):
			var wz := rect.position.y + iz * cell
			var dz := wz - p.z
			for ix in range(maxi(0, cx - rc), mini(nx, cx + rc + 1)):
				var wx := rect.position.x + ix * cell
				var dx := wx - p.x
				var dist2 := dx * dx + dz * dz
				var k := iz * nx + ix
				if dist2 < best[k]:
					best[k] = dist2
					ry[k] = p.y
					lat[k] = dx * right.x + dz * right.z
					dd[k] = d
		d += 9.0
	var zones_b: Array = []
	var zones_t: Array = []
	for z in path.zones:
		if z["kind"] == "bridge":
			zones_b.append([z["from"], z["to"]])
		elif z["kind"] == "tunnel":
			zones_t.append([z["from"], z["to"]])
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var heights := PackedFloat32Array()
	heights.resize(count)
	for k in count:
		var wx := rect.position.x + (k % nx) * cell
		var wz := rect.position.y + (k / nx) * cell
		var n := noise.get_noise_2d(wx, wz)
		var h: float
		if best[k] > 1e11:
			h = -12.0
		else:
			var dist := sqrt(best[k])
			var hw := path.width_at(dd[k]) * 0.5
			var e := maxf(0.0, dist - hw - 4.0)
			var base: float = ry[k] - 1.6
			var fall := 1.0 - smoothstep(radius - 110.0, radius - 10.0, dist)
			if lat[k] < 0.0:
				var rise := 78.0 * (1.0 - exp(-e / 70.0)) + absf(n) * minf(e, 60.0) * 0.55
				h = lerpf(-14.0, base + rise, fall) if fall < 1.0 else base + rise
			else:
				h = base - e * 0.55 + n * minf(e, 40.0) * 0.2
				h = maxf(h, -12.0 + n * 3.0)
			if e <= 0.0:
				h = base
			# bay under the bridge
			var bf := 0.0
			for b in zones_b:
				bf = maxf(bf, smoothstep(b[0] - 30.0, b[0] + 30.0, dd[k]) * (1.0 - smoothstep(b[1] - 30.0, b[1] + 30.0, dd[k])))
			if bf > 0.0:
				var bay := -10.0 + n * 2.0
				if lat[k] < 0.0:
					bf *= 1.0 - smoothstep(90.0, 230.0, e)
				h = lerpf(h, bay, bf)
			# mountain over the tunnel
			for t in zones_t:
				var tf := smoothstep(t[0] - 2.0, t[0] + 14.0, dd[k]) * (1.0 - smoothstep(t[1] - 14.0, t[1] + 2.0, dd[k]))
				if tf > 0.0:
					var m: float = ry[k] + 14.0 + absf(n) * 18.0 + e * 0.3
					h = lerpf(h, maxf(h, m), tf)
		heights[k] = h
	# smooth seams between path sections, keeping the road bed fixed
	for _pass in 3:
		var src := heights.duplicate()
		for iz in range(1, nz - 1):
			for ix in range(1, nx - 1):
				var k := iz * nx + ix
				if best[k] > 1e11:
					continue
				var hwk := path.width_at(dd[k]) * 0.5 + 6.0
				if best[k] < hwk * hwk:
					continue
				heights[k] = (src[k] * 4.0 + src[k - 1] + src[k + 1] + src[k - nx] + src[k + nx]) / 8.0
	# chunked mesh
	var mat := shader_material("res://shaders/track_terrain.gdshader")
	var csz := 40
	var terr := Node3D.new()
	terr.name = "Terrain"
	root.add_child(terr)
	for bz in range(0, nz - 1, csz):
		for bx in range(0, nx - 1, csz):
			var acc := Acc.new()
			var ex := mini(bx + csz, nx - 1)
			var ez := mini(bz + csz, nz - 1)
			var w := ex - bx + 1
			for iz in range(bz, ez + 1):
				for ix in range(bx, ex + 1):
					var k := iz * nx + ix
					var hl := heights[iz * nx + maxi(ix - 1, 0)]
					var hr := heights[iz * nx + mini(ix + 1, nx - 1)]
					var hd := heights[maxi(iz - 1, 0) * nx + ix]
					var hu := heights[mini(iz + 1, nz - 1) * nx + ix]
					var nrm := Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
					var pos := Vector3(rect.position.x + ix * cell, heights[k], rect.position.y + iz * cell)
					acc.add(pos, nrm, Vector2(pos.x, pos.z), Vector2(dd[k], lat[k]))
			for iz in range(0, ez - bz):
				for ix in range(0, ex - bx):
					var a := iz * w + ix
					var k0 := (bz + iz) * nx + bx + ix
					if best[k0] > 1e11 or best[k0 + 1] > 1e11 or best[k0 + nx] > 1e11 or best[k0 + nx + 1] > 1e11:
						continue
					# a=(x,z) b=(x,z+1) ... clockwise from above: (x,z+1),(x,z),(x+1,z),(x+1,z+1)
					acc.quad(a + w, a, a + 1, a + w + 1)
			if acc.is_empty():
				continue
			var mesh := ArrayMesh.new()
			acc.commit(mesh, mat)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			terr.add_child(mi)



const ARCH_INSET := 14.0


static func _shrink(ranges: Array, by: float) -> Array:
	var out := []
	for r in ranges:
		if r[1] - r[0] > by * 2.0:
			out.append([r[0] + by, r[1] - by])
	return out


## Two steel arches over the deck with hangers and top bracing (tied-arch bridge).
static func _build_arch_bridge(root: Node3D, path: TrackPath, d0: float, d1: float) -> void:
	var span := d1 - d0
	var rise := clampf(span * 0.13, 18.0, 46.0)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.78, 0.24, 0.1)
	steel.metallic = 0.35
	steel.roughness = 0.45
	var acc := Acc.new()
	var hangers: Array[Transform3D] = []
	var n := 64
	var arch_pts := {}
	for side in [-1.0, 1.0]:
		var pts: Array[Vector3] = []
		for i in n + 1:
			var t := float(i) / n
			var d := lerpf(d0, d1, t)
			var f := path.sample_transform(d)
			var off := path.width_at(d) * 0.5 + 1.4
			pts.append(f.origin + f.basis.x * off * side + Vector3.UP * (rise * 4.0 * t * (1.0 - t) - 0.8))
		arch_pts[side] = pts
		var frames: Array[Transform3D] = []
		var ds := PackedFloat32Array()
		var profs: Array = []
		for i in pts.size():
			var tan := (pts[mini(i + 1, n)] - pts[maxi(i - 1, 0)]).normalized()
			var right := tan.cross(Vector3.UP).normalized()
			var up := right.cross(tan).normalized()
			frames.append(Transform3D(Basis(right, up, -tan), pts[i]))
			ds.append(float(i))
			var thick := lerpf(2.2, 1.3, sin(PI * float(i) / n))
			profs.append(PackedVector2Array([Vector2(-0.6, -thick * 0.5), Vector2(-0.6, thick * 0.5), Vector2(0.6, thick * 0.5), Vector2(0.6, -thick * 0.5)]))
		loft(acc, frames, ds, profs, PackedVector2Array(), true)
		# hangers every 4th sample (skip the ends)
		for i in range(4, n - 3, 3):
			var top: Vector3 = pts[i]
			var d := lerpf(d0, d1, float(i) / n)
			var f := path.sample_transform(d)
			var off := path.width_at(d) * 0.5 + 1.4
			var foot: Vector3 = f.origin + f.basis.x * off * side
			var h: float = top.y - foot.y
			if h < 2.0:
				continue
			hangers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.18, h, 0.18)), (top + foot) * 0.5))
	# top bracing between the arches where they are high enough to clear traffic
	var left: Array = arch_pts[-1.0]
	var right_pts: Array = arch_pts[1.0]
	for i in range(10, n - 9, 6):
		var a: Vector3 = left[i]
		var b: Vector3 = right_pts[i]
		if a.y - path.sample_position(lerpf(d0, d1, float(i) / n)).y < 9.0:
			continue
		var c := (a + b) * 0.5
		var x := (b - a)
		var bas := Basis(x.normalized(), Vector3.UP, x.normalized().cross(Vector3.UP)).orthonormalized()
		acc.box(Transform3D(bas, c), Vector3(x.length(), 0.8, 0.8))
		# X bracing between consecutive braces is omitted for the triangle budget
	var mesh := ArrayMesh.new()
	acc.commit(mesh, steel)
	var mi := MeshInstance3D.new()
	mi.name = "ArchBridge"
	mi.mesh = mesh
	root.add_child(mi)
	if not hangers.is_empty():
		_add_multimesh(root, _box_mesh(Vector3.ONE), hangers, material("metal"), "Hangers")



# ----------------------------------------------------------------- corner boards

## Glowing chevron boards on the outside of tight corners (readability at night).
static func build_corner_signs(root: Node3D, data: Dictionary, layout: Dictionary) -> void:
	var style: String = layout.get("wall_style", "concrete")
	var max_r: float = layout.get("sign_radius", 75.0)
	var path: TrackPath = data["path"]
	var acc := Acc.new()
	var excl: Array = data["gaps"].duplicate()
	for l in data["loops"]:
		excl.append([l["from"] - 15.0, l["to"] + 15.0])
	var d := 0.0
	var last := -100.0
	while d < path.length:
		var a := path.sample_transform(d - 5.0).basis.z
		var b := path.sample_transform(d + 5.0).basis.z
		a.y = 0
		b.y = 0
		if a.length_squared() > 0.01 and b.length_squared() > 0.01 and not in_ranges(d, excl, 2.0):
			a = a.normalized()
			b = b.normalized()
			var k := a.signed_angle_to(b, Vector3.UP) / 10.0   # + = left turn
			if absf(k) > 1.0 / max_r and d - last > 9.0 and wall_mode_at(data, d) == "both":
				last = d
				var f := path.sample_transform(d)
				var outside := 1.0 if k > 0.0 else -1.0     # left turn -> outside is right (+x)
				var xo := (path.width_at(d) * 0.5 + WALL_GAP + 0.75) * outside
				var y0 := 1.15
				var y1 := 2.45
				var z0 := 1.3    # behind (toward +z)
				var z1 := -1.3   # ahead
				var nrm := (f.basis.x * -outside).normalized()
				var p0 := acc.add(f * Vector3(xo, y0, z0), nrm, Vector2(0, 1))
				var p1 := acc.add(f * Vector3(xo, y1, z0), nrm, Vector2(0, 0))
				var p2 := acc.add(f * Vector3(xo, y1, z1), nrm, Vector2(1, 0))
				var p3 := acc.add(f * Vector3(xo, y0, z1), nrm, Vector2(1, 1))
				acc.quad(p0, p1, p2, p3)
		d += 1.0
	if acc.is_empty():
		return
	var fg := Color(1.0, 0.72, 0.1)
	match style:
		"neon":
			fg = Color(1.0, 0.15, 0.8)
		"guardrail":
			fg = Color(1.0, 0.85, 0.2)
	var mesh := ArrayMesh.new()
	acc.commit(mesh, shader_material("res://shaders/track_chevron.gdshader", {"fg": fg}))
	var mi := MeshInstance3D.new()
	mi.name = "CornerSigns"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)



# ----------------------------------------------------------------- stunt dressing

## Hazard stripes on the last meters of each kicker and the first meters of each landing,
## glowing bars along the lip and landing edges.
static func build_jump_dressing(root: Node3D, data: Dictionary, layout: Dictionary) -> void:
	if data["jumps"].is_empty():
		return
	var path: TrackPath = data["path"]
	var neon_style: bool = layout.get("wall_style", "") == "neon"
	var stripes := Acc.new()
	var bars := Acc.new()
	for j in data["jumps"]:
		for rng in [[float(j["lip"]) - 7.0, float(j["lip"]) - 0.05], [float(j["land"]) + 0.05, float(j["land"]) + 5.0]]:
			var ds := ring_ds(rng[0], rng[1], 0.5)
			var frames: Array[Transform3D] = []
			var prof: Array = []
			for d in ds:
				var f := path.sample_transform(d)
				frames.append(Transform3D(f.basis, f.origin + f.basis.y * 0.03))
				var hw := path.width_at(d) * 0.5 - 0.95
				prof.append(PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0)]))
			loft(stripes, frames, ds, prof)
		for d in [float(j["lip"]) - 0.12, float(j["land"]) + 0.12]:
			var f := path.sample_transform(d)
			var hw := path.width_at(d) * 0.5
			bars.box(Transform3D(f.basis, f.origin + f.basis.y * -0.2), Vector3(hw * 2.0 + 0.1, 0.3, 0.25))
	var mesh := ArrayMesh.new()
	stripes.commit(mesh, shader_material("res://shaders/track_stripes.gdshader", {
		"color_a": Color(1.0, 0.15, 0.75) if neon_style else Color(1.0, 0.75, 0.05)}))
	bars.commit(mesh, material("neon_magenta" if neon_style else "neon_amber"))
	var mi := MeshInstance3D.new()
	mi.name = "JumpDressing"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## A neon gantry over each vertical loop: two towers outside the entry/exit roads and a top
## beam above the loop's crown, with hangers. Purely decorative (towers have collision).
static func build_loop_gantries(root: Node3D, data: Dictionary, _layout: Dictionary) -> void:
	var path: TrackPath = data["path"]
	for l in data["loops"]:
		var f0 := path.sample_transform(float(l["from"]))
		var r: float = l["radius"]
		var shift: float = l["shift"]
		var hw := path.width_at(float(l["from"])) * 0.5
		var right: Vector3 = l["axis"]
		var fwd := Vector3(-f0.basis.z.x, 0, -f0.basis.z.z).normalized()
		var base := f0.origin
		var x_left := -hw - 3.5
		var x_right := shift + hw + 3.5
		var top := 2.0 * r + 4.0
		var frame := Acc.new()
		var neon := Acc.new()
		var bas := Basis(right, Vector3.UP, -fwd)
		var body := StaticBody3D.new()
		body.name = "LoopGantry"
		body.collision_layer = LAYER_WORLD
		body.collision_mask = 0
		for x in [x_left, x_right]:
			var c: Vector3 = base + right * x + Vector3.UP * (top * 0.5)
			frame.box(Transform3D(bas, c), Vector3(1.6, top + 1.0, 1.6))
			for sz in [-1.0, 1.0]:
				neon.box(Transform3D(bas, c + fwd * 0.82 * sz), Vector3(0.18, top, 0.06))
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.6, top + 1.0, 1.6)
			cs.shape = bs
			cs.transform = Transform3D(bas, c)
			body.add_child(cs)
		var span := x_right - x_left
		var bc := base + right * ((x_left + x_right) * 0.5) + Vector3.UP * (top + 0.4)
		frame.box(Transform3D(bas, bc), Vector3(span + 1.6, 1.6, 2.2))
		for sz in [-1.0, 1.0]:
			neon.box(Transform3D(bas, bc + fwd * 1.12 * sz - Vector3.UP * 0.55), Vector3(span + 1.4, 0.14, 0.06))
		# hangers down to the crown of the loop (outer surface ~ 2r + depth)
		for k in [-1.0, 1.0]:
			var x: float = shift * 0.5 + k * (hw - 0.5)
			var hb := 2.0 * r + ROAD_DEPTH
			var hc: Vector3 = base + right * x + Vector3.UP * ((hb + top) * 0.5)
			frame.box(Transform3D(bas, hc), Vector3(0.3, top - hb, 0.3))
		var mesh := ArrayMesh.new()
		frame.commit(mesh, material("barrier_neon_body"))
		neon.commit(mesh, material("neon_cyan"))
		var mi := MeshInstance3D.new()
		mi.name = "LoopGantryMesh"
		mi.mesh = mesh
		root.add_child(mi)
		root.add_child(body)



## Simple sea plane at y = 0 around the track (only used when scenery doesn't add a sea).
static func build_fallback_sea(path: TrackPath) -> MeshInstance3D:
	var rect := path_bbox(path, 2500.0)
	var acc := Acc.new()
	var n := 8
	var step := rect.size / n
	for iz in n:
		for ix in n:
			var x0 := rect.position.x + ix * step.x
			var z0 := rect.position.y + iz * step.y
			var a := acc.add(Vector3(x0, 0, z0 + step.y), Vector3.UP, Vector2(x0, z0 + step.y))
			var b := acc.add(Vector3(x0, 0, z0), Vector3.UP, Vector2(x0, z0))
			var c := acc.add(Vector3(x0 + step.x, 0, z0), Vector3.UP, Vector2(x0 + step.x, z0))
			var d := acc.add(Vector3(x0 + step.x, 0, z0 + step.y), Vector3.UP, Vector2(x0 + step.x, z0 + step.y))
			acc.quad(a, b, c, d)
	var mesh := ArrayMesh.new()
	acc.commit(mesh, shader_material("res://shaders/track_sea.gdshader"))
	var mi := MeshInstance3D.new()
	mi.name = "TrackSeaFallback"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
