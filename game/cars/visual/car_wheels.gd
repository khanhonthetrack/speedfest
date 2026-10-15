class_name CarWheels
extends RefCounted
## Procedural wheel (tire + rim + brake disc) and brake caliper meshes.
## Wheel local space: axle along X, the outer face points +X. Vertex color R * 8 = part class
## (see car_wheel.gdshader). All four wheels share one mesh (drawn through a MultiMesh).

const C_TREAD := 0
const C_RIM := 1
const C_LIP := 2
const C_DISC := 3
const C_CALIPER := 4
const C_HUB := 5
const C_SIDEWALL := 6

const DESIGNS := 5


static func _cls(c: int) -> Color:
	return Color(float(c) / 8.0, 0, 0, 1)


static func rim_radius(radius: float) -> float:
	return radius - clampf(radius * 0.29, 0.08, 0.11)


## Brake disc center x (wheel local) for this wheel size and rim design.
static func disc_x(width: float, design: int) -> float:
	var hw := width * 0.5
	return hw - (0.15 if design == 2 else 0.11)


static func build_wheel(radius: float, width: float, design: int, segs := 28) -> ArrayMesh:
	var kit := MeshKit.new()
	var hw := width * 0.5
	var rr := rim_radius(radius)
	var side_h := radius - rr
	# --- tire ---
	kit.color = _cls(C_TREAD)
	var tread := PackedVector2Array([
		Vector2(-hw, radius - side_h * 0.3), Vector2(-hw + 0.014, radius - 0.008), Vector2(-hw + 0.035, radius),
		Vector2(hw - 0.035, radius), Vector2(hw - 0.014, radius - 0.008), Vector2(hw, radius - side_h * 0.3)])
	kit.revolve_x("w", tread, segs)
	kit.color = _cls(C_SIDEWALL)
	for sgn in [1.0, -1.0]:
		var sw := PackedVector2Array([
			Vector2(hw, radius - side_h * 0.3), Vector2(hw + 0.006, radius - side_h * 0.55),
			Vector2(hw + 0.004, radius - side_h * 0.8), Vector2(hw - 0.006, rr + 0.004), Vector2(hw - 0.016, rr - 0.004)])
		if sgn < 0.0:
			# inner sidewall: mirror x and run the other way so normals still face out
			var inner := PackedVector2Array()
			for k in range(sw.size() - 1, -1, -1):
				inner.append(Vector2(-sw[k].x, sw[k].y))
			sw = inner
		kit.revolve_x("w", sw, segs)
	# --- rim barrel (seen through the spokes) ---
	var x_face := hw - (0.085 if design == 2 else 0.035)
	kit.color = _cls(C_HUB)
	kit.revolve_x("w", PackedVector2Array([Vector2(x_face - 0.01, rr - 0.03), Vector2(-hw + 0.02, rr - 0.02)]), segs)
	# lip and dish wall
	kit.color = _cls(C_LIP)
	var lip_w := 0.045 if design == 2 else 0.016
	kit.revolve_x("w", PackedVector2Array([
		Vector2(hw - 0.022, rr + 0.012), Vector2(hw - 0.006, rr + 0.008), Vector2(hw - 0.003, rr - 0.004),
		Vector2(hw - 0.006, rr - lip_w * 0.6), Vector2(hw - 0.012, rr - lip_w)]), segs, [2])
	kit.color = _cls(C_RIM)
	kit.revolve_x("w", PackedVector2Array([Vector2(hw - 0.012, rr - lip_w), Vector2(x_face, rr - lip_w - 0.008)]), segs)
	# --- brake disc ---
	var dx := disc_x(width, design)
	kit.color = _cls(C_DISC)
	kit.cylinder("w", Vector3(dx - 0.014, 0, 0), Vector3.RIGHT, 0.028, rr * 0.8, rr * 0.8, 24)
	kit.color = _cls(C_HUB)
	kit.cylinder("w", Vector3(dx + 0.014, 0, 0), Vector3.RIGHT, x_face - dx - 0.03, rr * 0.38, 0.075, 16, false, false)
	# --- spokes ---
	kit.color = _cls(C_RIM)
	var r_in := 0.055
	var r_out := rr - lip_w - 0.004
	match design:
		0:  # Spoke-5: chunky tapered spokes
			for k in 5:
				_spoke(kit, TAU * k / 5.0, 0.0, r_in, r_out, 0.06, 0.042, x_face - 0.03, x_face + 0.004)
		1:  # Mesh: two crossing layers of thin bars
			for k in 12:
				_spoke(kit, TAU * k / 12.0, 0.42, r_in + 0.01, r_out, 0.014, 0.012, x_face - 0.022, x_face - 0.002)
				_spoke(kit, TAU * k / 12.0, -0.42, r_in + 0.01, r_out, 0.014, 0.012, x_face - 0.012, x_face + 0.006)
			kit.revolve_x("w", PackedVector2Array([Vector2(x_face + 0.004, r_out + 0.002), Vector2(x_face + 0.004, r_out - 0.016)]), segs)
		2:  # Deep dish: six flat spokes set deep behind a wide polished lip
			for k in 6:
				_spoke(kit, TAU * k / 6.0, 0.0, r_in, r_out + 0.004, 0.05, 0.05, x_face - 0.025, x_face + 0.002)
		3:  # Turbine: many curved blades
			for k in 16:
				_spoke(kit, TAU * k / 16.0, 0.5, r_in, r_out, 0.026, 0.03, x_face - 0.03, x_face + 0.002)
		_:  # Split-6: six pairs of thin spokes
			for k in 6:
				var a := TAU * k / 6.0
				_spoke(kit, a - 0.035, -0.07, r_in, r_out, 0.022, 0.017, x_face - 0.028, x_face + 0.002)
				_spoke(kit, a + 0.035, 0.07, r_in, r_out, 0.022, 0.017, x_face - 0.028, x_face + 0.002)
	# --- hub, center cap, lug nuts ---
	kit.cylinder("w", Vector3(x_face - 0.03, 0, 0), Vector3.RIGHT, 0.042, 0.072, 0.064, 18, false, true)
	kit.color = _cls(C_LIP)
	kit.cylinder("w", Vector3(x_face + 0.012, 0, 0), Vector3.RIGHT, 0.008, 0.034, 0.03, 14, false, true)
	kit.color = _cls(C_HUB)
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		kit.cylinder("w", Vector3(x_face + 0.008, cos(a) * 0.048, sin(a) * 0.048), Vector3.RIGHT, 0.012, 0.009, 0.009, 6, false, true)
	return kit.commit({})


## One spoke bar in the wheel face: from radius r_in at angle a to r_out at angle a + twist.
static func _spoke(kit: MeshKit, a: float, twist: float, r_in: float, r_out: float, w_in: float, w_out: float, x0: float, x1: float) -> void:
	var ci := Vector2(cos(a), sin(a)) * r_in
	var co := Vector2(cos(a + twist), sin(a + twist)) * r_out
	var dir := (co - ci).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var poly := PackedVector2Array([ci - perp * w_in * 0.5, co - perp * w_out * 0.5, co + perp * w_out * 0.5, ci + perp * w_in * 0.5])
	# poly coordinates are (y, z); extrude along x
	kit.prism("w", Vector3((x0 + x1) * 0.5, 0, 0), poly, Vector3.UP, Vector3.BACK, Vector3.RIGHT, x1 - x0)


## Caliper: an arc block hugging the disc, centered on x = 0 (so it is symmetric for both sides).
static func build_caliper(radius: float) -> ArrayMesh:
	var kit := MeshKit.new()
	var rr := rim_radius(radius)
	kit.color = _cls(C_CALIPER)
	var r0 := rr * 0.6
	var r1 := rr * 0.86
	var prof := PackedVector2Array([Vector2(0.032, r1), Vector2(0.032, r0), Vector2(-0.032, r0), Vector2(-0.032, r1), Vector2(0.032, r1)])
	kit.revolve_x("w", prof, 6, [1, 2, 3], 0.25, 1.05)
	# end caps
	for a in [0.25, 1.05]:
		var d := Vector3(0, cos(a), sin(a))
		var tdir := Vector3(0, -sin(a), cos(a)) * (1.0 if a > 0.5 else -1.0)
		kit.flat_quad("w", Vector3(0.032, 0, 0) + d * r1, Vector3(0.032, 0, 0) + d * r0, Vector3(-0.032, 0, 0) + d * r0, Vector3(-0.032, 0, 0) + d * r1, tdir)
	return kit.commit({})
