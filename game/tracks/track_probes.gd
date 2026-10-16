class_name TrackProbes
extends RefCounted
## Sector ReflectionProbes (M7 look plan step 9, Forward+ from Medium): car paint, glass and the
## road reflect the neon, lit windows and floods around them instead of the black sky wherever
## SSR has nothing on screen. UPDATE_ONCE (captured while the track loads / during the countdown),
## one about every 80 m, capped per quality; tunnels get an interior probe with a dark ambient.
## Cars stay out of the captures (they sit on render layer 2; the probes cull layer 1 only).

const SPACING := 80.0
const CAR_LAYER := 2
const MAX_PER_QUALITY := [0, 10, 24, 40]


static func build(root: Node3D, path: TrackPath, theme: String) -> int:
	if Settings.is_compat() or Settings.quality < 1 or TestHooks.has_arg("no_probes"):
		return 0
	var cap: int = MAX_PER_QUALITY[clampi(Settings.quality, 0, 3)]
	var size_by_theme := {"city": Vector3(50, 40, 90), "arena": Vector3(120, 70, 120), "coast": Vector3(80, 40, 100)}
	var extra: Vector3 = size_by_theme.get(theme, Vector3(60, 40, 100))
	var tunnels: Array = []
	for z in path.zones:
		if z["kind"] == "tunnel":
			tunnels.append([float(z["from"]), float(z["to"])])
	var n := mini(cap, maxi(1, int(path.length / SPACING)))
	var step := path.length / n
	var made := 0
	var holder := Node3D.new()
	holder.name = "ReflectionProbes"
	root.add_child(holder)
	for i in n:
		var d := (i + 0.5) * step
		var in_tunnel := false
		for t: Array in tunnels:
			if d >= t[0] - 10.0 and d <= t[1] + 10.0:
				in_tunnel = true
		if in_tunnel:
			continue
		var f := path.sample_transform(d)
		var fwd := -f.basis.z
		fwd.y = 0.0
		var yaw := Basis.looking_at(fwd.normalized() if fwd.length_squared() > 1e-4 else Vector3.FORWARD, Vector3.UP)
		var p := ReflectionProbe.new()
		p.name = "Probe%d" % made
		p.transform = Transform3D(yaw, f.origin + Vector3.UP * 10.0)
		p.size = Vector3(path.width_at(d) + extra.x, extra.y, extra.z)
		p.origin_offset = Vector3(0, -8.0, 0)       # capture from about car-roof height
		p.box_projection = theme == "city"
		p.blend_distance = 10.0
		p.max_distance = 400.0
		p.enable_shadows = false
		p.update_mode = ReflectionProbe.UPDATE_ONCE
		p.mesh_lod_threshold = 4.0
		p.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		p.cull_mask = 1                              # no cars in the capture
		holder.add_child(p)
		made += 1
	# tunnels: an interior probe fitted to the bore keeps the sky ambient out
	for t: Array in tunnels:
		var mid := (float(t[0]) + float(t[1])) * 0.5
		var f := path.sample_transform(mid)
		var p := ReflectionProbe.new()
		p.name = "TunnelProbe%d" % made
		p.transform = Transform3D(f.basis, f * Vector3(0, 4.0, 0))
		p.size = Vector3(path.width_at(mid) + 6.0, 9.0, float(t[1]) - float(t[0]) + 4.0)
		p.interior = true
		p.box_projection = true
		p.update_mode = ReflectionProbe.UPDATE_ONCE
		p.ambient_mode = ReflectionProbe.AMBIENT_COLOR
		p.ambient_color = Color(0.18, 0.14, 0.1)
		p.ambient_color_energy = 0.5
		p.cull_mask = 1
		holder.add_child(p)
		made += 1
	return made
