class_name DirtSpray
extends InterpAnchor
## Dust and clippings thrown up by the rear tires on grass, gravel or sand (session 4 ground
## patches, res://weather/track_surface.gd). Child of the local Car; particles live in world space
## so they trail. CPUParticles3D, so it works on Compatibility (web) too.

const MIN_KMH := 20.0
## Per TrackSurface kind: [color, size, amount scale]
const LOOK := {
	1: [Color(0.22, 0.42, 0.12, 0.85), 0.35, 0.7],   # grass clippings
	2: [Color(0.55, 0.52, 0.46, 0.7), 0.7, 1.0],     # gravel dust
	3: [Color(0.85, 0.72, 0.5, 0.65), 0.9, 1.2],     # sand
	4: [Color(0.42, 0.26, 0.15, 0.75), 0.8, 1.1],    # dirt dust (M7)
	5: [Color(0.9, 0.95, 1.0, 0.45), 0.4, 0.6],      # ice frost
}

var emitters: Array[CPUParticles3D] = []
var _kind := 0


static func create(car_id: String) -> DirtSpray:
	var s := DirtSpray.new()
	s.name = "DirtSpray"
	var wp := CarDefs.wheel_positions(car_id)
	var r: float = CarDefs.geometry(car_id)["wheel_radius"]
	for i in [2, 3]:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.local_coords = false
		p.amount = 40
		p.lifetime = 0.8
		p.explosiveness = 0.0
		p.position = wp[i] + Vector3(0, -r * 0.8, 0.3)
		p.direction = Vector3(0, 0.6, 1)
		p.spread = 25.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 5.0
		p.gravity = Vector3(0, -4.0, 0)
		p.damping_min = 1.5
		p.damping_max = 3.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.4
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.4))
		sc.add_point(Vector2(1, 1.6))
		p.scale_amount_curve = sc
		var q := QuadMesh.new()
		q.size = Vector2(0.6, 0.6)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = WaterSpray._puff()
		q.material = m
		p.mesh = q
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = g
		s.add_child(p)
		s.emitters.append(p)
	return s


## kind: TrackSurface kind under the rear wheels (Car.get_ground_kind()).
func update_dirt(kind: int, speed_kmh: float) -> void:
	var on := kind > 0 and LOOK.has(kind) and absf(speed_kmh) > MIN_KMH   # (plastic throws nothing)
	if on and kind != _kind:
		var look: Array = LOOK.get(kind, LOOK[2])
		for p in emitters:
			p.color = look[0]
			(p.mesh as QuadMesh).size = Vector2.ONE * float(look[1])
	_kind = kind if on else 0
	for p in emitters:
		if on:
			var look2: Array = LOOK.get(kind, LOOK[2])
			p.initial_velocity_max = 3.0 + absf(speed_kmh) * 0.03
			p.speed_scale = clampf(absf(speed_kmh) / 120.0, 0.5, 1.5) * float(look2[2])
		if p.emitting != on:
			p.emitting = on
