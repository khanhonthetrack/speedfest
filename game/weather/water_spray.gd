class_name WaterSpray
extends Node3D
## Water thrown up by a car's rear tires: a big splash plume in puddles, a light mist off wet
## asphalt at speed. Child of the car (local Car or RemoteCar); particles live in world space so
## the spray trails behind. CPUParticles3D, so it works on Compatibility (web) too.

const SPLASH_MIN_KMH := 25.0
const MIST_MIN_KMH := 90.0

var splash: Array[CPUParticles3D] = []
var mist: Array[CPUParticles3D] = []
var _wet := false
var _was_splashing := false
var play_sound := false        # local car: splash sound when hitting a puddle


static func create(car_id: String, wet_road: bool) -> WaterSpray:
	var s := WaterSpray.new()
	s.name = "WaterSpray"
	s._wet = wet_road
	s._build(car_id)
	return s


static func _material(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.75, 0.85, 1.0, alpha)
	m.disable_receive_shadows = true
	return m


static func _ramp(a0: float) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, a0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	return g


func _emitter(pos: Vector3, amount: int, size: float, alpha: float, vel: float, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	p.mesh = q
	p.material_override = _material(alpha)
	p.position = pos
	p.direction = Vector3(0, 0.55, 1.0)   # up and backwards (car +Z is backwards)
	p.spread = 22.0
	p.initial_velocity_min = vel * 0.6
	p.initial_velocity_max = vel
	p.gravity = Vector3(0, -9.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.color_ramp = _ramp(1.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _build(car_id: String) -> void:
	var g := CarDefs.geometry(car_id)
	var wp := CarDefs.wheel_positions(car_id)
	var r: float = g["wheel_radius"]
	var lite := Settings.quality <= 1
	for i in [2, 3]:
		var base: Vector3 = wp[i] + Vector3(0, -r * 0.7, r * 0.6)
		splash.append(_emitter(base, 10 if lite else 18, 0.9, 0.55, 7.0, 0.55))
		mist.append(_emitter(base, 5 if lite else 9, 1.4, 0.18, 4.0, 0.6))


## water 0..1 (Car.get_water_amount or puddle flag), speed in km/h.
func update_spray(water: float, speed_kmh: float) -> void:
	var v := absf(speed_kmh)
	var splashing := water > 0.15 and v > SPLASH_MIN_KMH
	var misting := _wet and v > MIST_MIN_KMH
	for p in splash:
		if p.emitting != splashing:
			p.emitting = splashing
	for p in mist:
		if p.emitting != misting:
			p.emitting = misting
	if play_sound and splashing and not _was_splashing and v > 60.0:
		Audio.play_sfx("splash", linear_to_db(clampf(v / 200.0, 0.4, 1.0)), randf_range(0.9, 1.1))
	_was_splashing = splashing
