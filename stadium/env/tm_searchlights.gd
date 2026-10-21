class_name TmSearchlights
extends Node3D
## Searchlights sweeping the sky over a City night (M14, owner: "futuristic and alive"): beams from
## round the Stadium and from the downtowns, each leaning out and swinging slowly to and fro, at
## its own pace (env/tm_searchlight.gdshader: additive, fading to the tip). Godot coordinates of
## the map; this node sits at the Stadium's centre on the field.

const LENGTH := 1700.0
const FOOT_R := 2.0
const TIP_R := 42.0
## [x, y, z (from the Stadium's centre, Godot axes), lean (deg from vertical), sweep (deg), period (s)]
const LAMPS := [
	[720.0, 30.0, 470.0, 24.0, 40.0, 23.0], [-720.0, 30.0, 470.0, 26.0, 35.0, 29.0],
	[720.0, 30.0, -470.0, 22.0, 45.0, 26.0], [-720.0, 30.0, -470.0, 25.0, 38.0, 31.0],
	[-2450.0, 10.0, 200.0, 18.0, 30.0, 37.0], [2350.0, 10.0, -300.0, 20.0, 34.0, 33.0],
	[250.0, 10.0, 1850.0, 16.0, 28.0, 41.0], [-450.0, 10.0, -1800.0, 17.0, 30.0, 39.0],
]
const COLOURS := [Color(0.72, 0.82, 1.0), Color(0.85, 0.55, 1.0), Color(0.5, 0.95, 1.0), Color(1.0, 0.55, 0.85)]

var _beams: Array[Node3D] = []
var _base: Array[float] = []
var _time := 0.0


static func make() -> TmSearchlights:
	var s := TmSearchlights.new()
	s.name = "Searchlights"
	s.position = TmGeo.g(TmStadiumBuild.CENTRE)
	var mesh := _cone()
	for i in LAMPS.size():
		var l: Array = LAMPS[i]
		var pivot := Node3D.new()
		pivot.position = Vector3(l[0], l[1], l[2])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var m := ShaderMaterial.new()
		m.shader = preload("res://env/tm_searchlight.gdshader")
		m.set_shader_parameter("colour", COLOURS[i % COLOURS.size()])
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.rotation.x = deg_to_rad(float(l[3]))       # the lean, out from the vertical
		pivot.add_child(mi)
		s.add_child(pivot)
		s._beams.append(pivot)
		# lean away from the Stadium's centre (lamps round it) or towards it (downtowns)
		var away := atan2(float(l[0]), float(l[2]))
		s._base.append(away + (PI if Vector2(l[0], l[2]).length() > 1500.0 else 0.0))
	s._process(0.0)
	return s


## The beam: an open cone up +y from the lamp, FOOT_R to TIP_R over LENGTH, 20 sides; v 0..1 up it.
static func _cone() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 20
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var p := [d0 * FOOT_R, d1 * FOOT_R, d1 * TIP_R + Vector3.UP * LENGTH, d0 * TIP_R + Vector3.UP * LENGTH]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var nn := [d0, d1, d1, d0]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nn[i])
			st.set_uv(uv[i])
			st.add_vertex(p[i])
	return st.commit()


func _process(delta: float) -> void:
	_time += delta
	for i in _beams.size():
		var l: Array = LAMPS[i]
		var swing := deg_to_rad(float(l[4])) * sin(TAU * _time / float(l[5]) + i * 1.7)
		_beams[i].rotation.y = _base[i] + swing
