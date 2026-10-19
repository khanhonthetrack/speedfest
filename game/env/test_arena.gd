class_name TestArena
extends Node3D
## A test ground for the Stadium car built in code: a large floor on the 32 m block grid, a 15 deg
## kicker, a helix loop (r 16 m), a wall-ride quarter pipe, a straight wall, and a sky with a sun.
## Positions (car frame: the car faces +Z):
##   spawn          (0, 0, 0)
##   kicker         x = 0, z 140..~164: arc to 15 deg (top ~3.2 m)
##   loop           entry at (64, 0, 300), radius 16, shift 12 m to +X, 14 m wide
##   quarter pipe   along z -200..400 at x = -64 (curves up toward -X, r 12 m)
##   wall           x = 128 plane, faces -X

const KICKER_Z := 140.0
const LOOP_START := Vector3(64.0, 0.0, 300.0)
const LOOP_R := 16.0
const LOOP_SHIFT := 12.0
const LOOP_HALF_WIDTH := 7.0
const PIPE_X := -64.0
const PIPE_R := 12.0
const WALL_X := 128.0

var floor_mat: ShaderMaterial
var road_mat: StandardMaterial3D


func _ready() -> void:
	_materials()
	_environment()
	# floor: one big box, top at y = 0
	var fl := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4096, 2, 4096)
	cs.shape = bs
	cs.position = Vector3(0, -1, 0)
	fl.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4096, 4096)
	mi.mesh = pm
	mi.material_override = floor_mat
	fl.add_child(mi)
	fl.set_meta("surface", 16)
	add_child(fl)
	# kicker: a 24 m arc bending the road up to 15 deg (TM ramps have a curved base), then the lip
	var k := ProcGeo.new()
	var secs: Array = []
	var arc_r := 24.0 / deg_to_rad(15.0)
	for i in 13:
		var a := deg_to_rad(15.0) * i / 12.0
		var c := Vector3(0.0, arc_r - arc_r * cos(a), KICKER_Z + arc_r * sin(a))
		secs.append([c, Vector3(6, 0, 0), Vector3(0.0, cos(a), -sin(a))])
	k.ribbon(secs)
	var lip: Vector3 = secs[12][0]
	k.quad(Vector3(6, lip.y, lip.z), Vector3(-6, lip.y, lip.z), Vector3(-6, 0, lip.z), Vector3(6, 0, lip.z), Vector3.FORWARD)
	add_child(k.body(road_mat, 16))
	# loop
	var lp := ProcGeo.new()
	lp.ribbon(ProcGeo.loop_sections(LOOP_START, LOOP_R, LOOP_SHIFT, LOOP_HALF_WIDTH))
	add_child(lp.body(road_mat, 16))
	# quarter pipe (wall ride)
	var qp := ProcGeo.new()
	qp.quarter_pipe(PIPE_X, -200.0, 400.0, PIPE_R)
	add_child(qp.body(road_mat, 16))
	# straight wall
	var wb := StaticBody3D.new()
	var wcs := CollisionShape3D.new()
	var wbs := BoxShape3D.new()
	wbs.size = Vector3(1, 4, 1200)
	wcs.shape = wbs
	wb.add_child(wcs)
	var wmi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = wbs.size
	wmi.mesh = bm
	wmi.material_override = road_mat
	wb.add_child(wmi)
	wb.position = Vector3(WALL_X + 0.5, 2, 200)
	add_child(wb)


func _materials() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	vec2 g = abs(fract(p / 32.0 + 0.5) - 0.5) * 32.0;
	float line = 1.0 - smoothstep(0.08, 0.16, min(g.x, g.y));
	vec2 c = floor(p / 32.0);
	float chk = mod(c.x + c.y, 2.0);
	vec3 base = mix(vec3(0.20, 0.21, 0.23), vec3(0.24, 0.25, 0.27), chk);
	ALBEDO = mix(base, vec3(0.85, 0.85, 0.8), line * 0.8);
	ROUGHNESS = 0.82;
}
"""
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = sh
	road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.32, 0.33, 0.36)
	road_mat.roughness = 0.6
	road_mat.uv1_triplanar = true


func _environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	add_child(sun)
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.22, 0.42, 0.78)
	psm.sky_horizon_color = Color(0.68, 0.76, 0.86)
	psm.ground_horizon_color = Color(0.68, 0.76, 0.86)
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
