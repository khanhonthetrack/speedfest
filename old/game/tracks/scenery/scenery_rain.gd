class_name SceneryRain
extends Node3D
## Rain streaks around the camera (child of the Camera3D). Particles live in world space; the
## emission box sits ahead of the camera. GPUParticles3D on Forward+, CPUParticles3D on
## Compatibility. Amount scales with Settings.quality.

const BOX := Vector3(36, 16, 36)

var particles: Node3D
var density := 1.0


## density: 1 = rain, ~1.6 = storm (Weather.rain_density).
static func create(p_density: float = 1.0) -> SceneryRain:
	var r := SceneryRain.new()
	r.name = "Rain"
	r.density = maxf(p_density, 0.1)
	r._build()
	return r


static func streak_mesh() -> Mesh:
	# two crossed thin quads, 0.9 m long, so a streak reads from any angle
	var m := SceneryMesh.new()
	var w := 0.008
	var h := 0.45
	m.add_quad(Vector3(-w, -h, 0), Vector3(-w, h, 0), Vector3(w, h, 0), Vector3(w, -h, 0), Color.WHITE)
	m.add_quad(Vector3(0, -h, -w), Vector3(0, h, -w), Vector3(0, h, w), Vector3(0, -h, w), Color.WHITE)
	return m.commit()


static func streak_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.5, 0.55, 0.7, 0.2)
	mat.vertex_color_use_as_albedo = true
	mat.disable_receive_shadows = true
	mat.no_depth_test = false
	return mat


func _build() -> void:
	var amount: int = int([600, 1400, 2600, 4000][Settings.quality] * density)
	var mesh := streak_mesh()
	var mat := streak_material()
	var vel := Vector3(1.5 + 3.0 * (density - 1.0), -22.0 - 6.0 * (density - 1.0), 0.0)
	if Settings.is_compat():
		amount = int([300, 700, 1100, 1500][Settings.quality] * density)
		var cp := CPUParticles3D.new()
		cp.amount = amount
		cp.lifetime = 0.9
		cp.preprocess = 1.0
		cp.local_coords = false
		cp.mesh = mesh
		cp.material_override = mat
		cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		cp.emission_box_extents = BOX * 0.5
		cp.direction = vel.normalized()
		cp.spread = 2.0
		cp.initial_velocity_min = vel.length() * 0.9
		cp.initial_velocity_max = vel.length() * 1.1
		cp.gravity = Vector3.ZERO
		cp.particle_flag_align_y = true
		cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles = cp
	else:
		var gp := GPUParticles3D.new()
		gp.amount = amount
		gp.lifetime = 0.9
		gp.preprocess = 1.0
		gp.local_coords = false
		gp.draw_pass_1 = mesh
		gp.material_override = mat
		gp.visibility_aabb = AABB(-BOX * 1.5, BOX * 3.0)
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = BOX * 0.5
		pm.direction = vel.normalized()
		pm.spread = 2.0
		pm.initial_velocity_min = vel.length() * 0.9
		pm.initial_velocity_max = vel.length() * 1.1
		pm.gravity = Vector3.ZERO
		pm.particle_flag_align_y = true
		gp.process_material = pm
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles = gp
	particles.name = "Streaks"
	# box centred a little ahead of and above the camera
	particles.position = Vector3(0, 4.0, -12.0)
	add_child(particles)


func _process(_delta: float) -> void:
	# keep the emitter upright even when the camera rolls (loops)
	if particles != null:
		var g := global_transform
		particles.global_transform = Transform3D(Basis.IDENTITY, g.origin + (-g.basis.z) * 12.0 + Vector3(0, 4.0, 0))
