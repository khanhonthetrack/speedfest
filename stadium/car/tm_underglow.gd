class_name TmUnderglow
extends Node3D
## Underglow (tuning "glow", PLAN M18): neon tubes under one of our cars and the light they throw.
## Fitted to each car in Blender (tools/assets/tuning_kit.py underglow()): the tubes' lines under its
## sills and across both ends (the manifest's "underglow"), and their light on the road baked from
## them, the tyres' shadows in it, the front tubes' share and the rear's apart
## (assets/car/<id>_glow_f/_r.png). Drawn here: the tubes (glass, the gas's colour, a white-hot core
## where they face the eye: tm_glow_tube.gdshader) in dark mounting channels, a halo of light in the
## air round each (tm_glow_halo.gdshader), the light on the road (two emissive decals: the front's
## share in the front's colour, the rear's in the rear's) and a small light at each tube's middle
## (the tyres, sills and kerbs round the car lit in the colour). One colour, two (the front's fading
## to the rear's along the car), or a rainbow flowing along it. Coordinates: the car's visual frame
## (TmCarVisual puts this node at -VIS).

const DIR := "res://assets/car/"
const TUBE_R := 0.011          ## the tubes' radius (tuning_kit.TUBE_R)
const SIDES := 10
const HALO_END := 0.05         ## the halos reach this far past the tubes' ends
const SPAN := 0.45             ## a rainbow: the share of the hues along the car (nose to tail)
const SPEED := 0.12            ## a rainbow: its turns per second

var front := Color(0.1, 0.4, 1.0)   ## the front's colour (one colour: the rear's the same)
var rear := Color(0.1, 0.4, 1.0)
var rainbow := false
var phase := 0.0                    ## a rainbow's hue at the nose

var _fit := {}
var _tube_mat: ShaderMaterial
var _halo_mat: ShaderMaterial
var _decals: Array[Decal] = []        # the front's share, the rear's
var _lights: Array[OmniLight3D] = []
var _light_t: Array[float] = []

static var _fits := {}                # car id -> its fitting (fit())
static var _channel_mat: StandardMaterial3D


## The underglow `glow` (one of TmRoadCars.GLOWS) for car `id` (a road car or "hyper"); null when
## it is off or the car has no fitting.
static func make(id: String, glow: Dictionary) -> TmUnderglow:
	if not glow.has("colour") and not glow.has("colours") and not bool(glow.get("cycle", false)):
		return null
	if fit(id).is_empty():
		return null
	var u := TmUnderglow.new()
	u.name = "Underglow"
	u._fit = fit(id)
	if glow.has("colours"):
		u.front = glow["colours"][0]
		u.rear = glow["colours"][1]
	elif glow.has("colour"):
		u.front = glow["colour"]
		u.rear = glow["colour"]
	u.rainbow = bool(glow.get("cycle", false))
	return u


## Car `id`'s fitting, built once: {"tubes": mesh (the glass, the channels), "halo": mesh, "rect",
## "lights", "light_t", "t_front"/"t_rear" (the mean place along the car of the light in each
## picture), "f"/"r": the pictures}; empty when the car has none.
static func fit(id: String) -> Dictionary:
	if _fits.has(id):
		return _fits[id]
	var out := {}
	var ug: Variant = TmRoadCars.manifest(id).get("underglow")
	var stem := DIR + ("hypercar" if id == "hyper" else id) + "_glow_"
	if ug is Dictionary and ResourceLoader.exists(stem + "f.png") and ResourceLoader.exists(stem + "r.png"):
		var tubes: Array = []
		for line: Array in ug["tubes"]:
			var pts := PackedVector3Array()
			for p: Array in line:
				pts.append(Vector3(p[0], p[1], p[2]))
			tubes.append(pts)
		var ts: Array = ug["tube_t"]
		# the mean place along the car of each picture's light (the side tubes' split by t)
		var wf := 0.0
		var wr := 0.0
		var sf := 0.0
		var sr := 0.0
		for line: Array in ts:
			for t: float in line:
				wf += 1.0 - t
				sf += (1.0 - t) * t
				wr += t
				sr += t * t
		var lt: Array[float] = []
		for line: Array in ts:
			lt.append(float(line[line.size() / 2]))
		out = {"tubes": _tube_mesh(tubes, ts), "halo": _halo_mesh(tubes, ts), "rect": ug["rect"],
			"lights": ug["lights"], "light_t": lt, "t_front": sf / maxf(wf, 1e-6), "t_rear": sr / maxf(wr, 1e-6),
			"f": load(stem + "f.png"), "r": load(stem + "r.png")}
	_fits[id] = out
	return out


## The gas's colour at place t along the car (0 the nose, 1 the tail): tm_glow.gdshaderinc's gas().
func colour_at(t: float) -> Color:
	if rainbow:
		return Color.from_hsv(fposmod(phase - SPAN * t, 1.0), 1.0, 1.0)
	return front.lerp(rear, smoothstep(0.0, 1.0, t))


func _ready() -> void:
	var night := TmStadiumEnv.night
	_tube_mat = ShaderMaterial.new()
	_tube_mat.shader = preload("res://car/tm_glow_tube.gdshader")
	_tube_mat.set_shader_parameter("energy", 5.0 if night else 8.0)
	_halo_mat = ShaderMaterial.new()
	_halo_mat.shader = preload("res://car/tm_glow_halo.gdshader")
	_halo_mat.set_shader_parameter("strength", 1.4 if night else 0.9)
	for m: ShaderMaterial in [_tube_mat, _halo_mat]:
		m.set_shader_parameter("front", front)
		m.set_shader_parameter("rear", rear)
		m.set_shader_parameter("rainbow", 1.0 if rainbow else 0.0)
		m.set_shader_parameter("span", SPAN)
	var tubes := MeshInstance3D.new()
	tubes.name = "GlowTubes"
	tubes.mesh = _fit["tubes"]
	tubes.set_surface_override_material(0, _tube_mat)
	tubes.set_surface_override_material(1, _channel())
	tubes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tubes)
	var halo := MeshInstance3D.new()
	halo.name = "GlowHalo"
	halo.mesh = _fit["halo"]
	halo.material_override = _halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.extra_cull_margin = 0.12
	add_child(halo)
	# the light on the road: the baked pictures laid flat round the car, projected down onto the
	# road through the suspension's travel, faded on what doesn't face up (the car's own underside)
	var r: Array = _fit["rect"]
	for part in ["f", "r"]:
		var d := Decal.new()
		d.name = "GlowFront" if part == "f" else "GlowRear"
		d.texture_emission = _fit[part]
		d.emission_energy = 1.7 if night else 1.1
		d.albedo_mix = 0.0
		d.size = Vector3(float(r[2]) - float(r[0]), 0.6, float(r[3]) - float(r[1]))
		d.position = Vector3((float(r[0]) + float(r[2])) * 0.5, -0.1, (float(r[1]) + float(r[3])) * 0.5)
		d.normal_fade = 0.5
		d.upper_fade = 0.15
		d.lower_fade = 0.5
		d.distance_fade_enabled = true
		d.distance_fade_begin = 90.0
		d.distance_fade_length = 20.0
		add_child(d)
		_decals.append(d)
	var lt: Array[float] = _fit["light_t"]
	for i in (_fit["lights"] as Array).size():
		var p: Array = _fit["lights"][i]
		var l := OmniLight3D.new()
		l.name = "GlowLight"
		l.light_energy = 0.9 if night else 0.6
		l.light_specular = 0.0          # no point glints on wet roads: the tubes' own reflections are the SSR's
		l.omni_range = 1.5
		l.omni_attenuation = 0.6
		l.shadow_enabled = false
		l.position = Vector3(p[0], p[1], p[2])
		add_child(l, true)
		_lights.append(l)
		_light_t.append(lt[i])
	_colour()


## How bright it shows, k times as fitted (a cutscene's shot dims it: StoryScene's car "glow"): the
## tubes, their halo, the light on the road. Once it is in the tree.
func set_strength(k: float) -> void:
	if _tube_mat == null:
		return
	var night := TmStadiumEnv.night
	_tube_mat.set_shader_parameter("energy", (5.0 if night else 8.0) * k)
	_halo_mat.set_shader_parameter("strength", (1.4 if night else 0.9) * k)
	for d in _decals:
		d.emission_energy = (1.7 if night else 1.1) * k
	for l in _lights:
		l.light_energy = (0.9 if night else 0.6) * k


## The decals' and lights' colours now (the tubes and halos colour themselves in their shaders).
func _colour() -> void:
	_decals[0].modulate = colour_at(float(_fit["t_front"]))
	_decals[1].modulate = colour_at(float(_fit["t_rear"]))
	for i in _lights.size():
		_lights[i].light_color = colour_at(_light_t[i])


func _process(delta: float) -> void:
	if not rainbow:
		return
	phase = fposmod(phase + delta * SPEED, 1.0)
	_tube_mat.set_shader_parameter("phase", phase)
	_halo_mat.set_shader_parameter("phase", phase)
	_colour()


## The tubes' mounting channels: dark anodised aluminium.
static func _channel() -> StandardMaterial3D:
	if _channel_mat == null:
		_channel_mat = StandardMaterial3D.new()
		_channel_mat.albedo_color = Color(0.035, 0.035, 0.04)
		_channel_mat.metallic = 0.6
		_channel_mat.roughness = 0.45
		_channel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _channel_mat


## A frame along a tube at point i: its direction, its side, its up.
static func _frame(pts: PackedVector3Array, i: int) -> Basis:
	var a := pts[maxi(i - 1, 0)]
	var b := pts[mini(i + 1, pts.size() - 1)]
	var t := (b - a).normalized()
	var s := t.cross(Vector3.UP).normalized()
	return Basis(t, s, s.cross(t))


## The tubes (surface 0: glass round the gas, UV.x the place along the car) and over each its
## mounting channel (surface 1: a U open downwards, the tube inside it).
static func _tube_mesh(tubes: Array, ts: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in tubes.size():
		var pts: PackedVector3Array = tubes[k]
		var tt: Array = ts[k]
		var base := 0
		var n := pts.size()
		var start := 0
		for i in n:
			var f := _frame(pts, i)
			for j in SIDES + 1:
				var a := TAU * j / SIDES
				var dir := f.y * cos(a) + f.z * sin(a)
				st.set_normal(dir)
				st.set_uv(Vector2(tt[i], float(j) / SIDES))
				st.add_vertex(pts[i] + dir * TUBE_R)
		for i in n - 1:
			for j in SIDES:
				var v := start + i * (SIDES + 1) + j
				st.add_index(v)
				st.add_index(v + SIDES + 1)
				st.add_index(v + 1)
				st.add_index(v + 1)
				st.add_index(v + SIDES + 1)
				st.add_index(v + SIDES + 2)
		base = start + n * (SIDES + 1)
		# the ends: flat glass caps
		for e in 2:
			var i := 0 if e == 0 else n - 1
			var f := _frame(pts, i)
			var out := -f.x if e == 0 else f.x
			st.set_normal(out)
			st.set_uv(Vector2(tt[i], 0.0))
			st.add_vertex(pts[i])
			var c := base
			for j in SIDES:
				var a := TAU * j / SIDES
				st.set_normal(out)
				st.set_uv(Vector2(tt[i], 0.0))
				st.add_vertex(pts[i] + (f.y * cos(a) + f.z * sin(a)) * TUBE_R)
			for j in SIDES:
				var p := c + 1 + j
				var q := c + 1 + (j + 1) % SIDES
				if e == 0:
					st.add_index(c)
					st.add_index(q)
					st.add_index(p)
				else:
					st.add_index(c)
					st.add_index(p)
					st.add_index(q)
			base += SIDES + 1
	st.commit(mesh)
	# the channels: (side, up) round the tube's centre
	var u := [Vector2(-0.017, -0.003), Vector2(-0.017, 0.017), Vector2(0.017, 0.017), Vector2(0.017, -0.003)]
	st.clear()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start := 0
	for k in tubes.size():
		var pts: PackedVector3Array = tubes[k]
		for i in pts.size():
			var f := _frame(pts, i)
			for w in 3:
				var nrm := [-f.y, f.z, f.y][w] as Vector3
				for e in 2:
					var c: Vector2 = u[w + e]
					st.set_normal(nrm)
					st.add_vertex(pts[i] + f.y * c.x + f.z * c.y)
		for i in pts.size() - 1:
			for w in 3:
				var v := start + i * 6 + w * 2
				st.add_index(v)
				st.add_index(v + 6)
				st.add_index(v + 1)
				st.add_index(v + 1)
				st.add_index(v + 6)
				st.add_index(v + 7)
		start += pts.size() * 6
	st.commit(mesh)
	return mesh


## The halos: a ribbon along each tube (turned to face the eye by tm_glow_halo.gdshader), reaching
## HALO_END past its ends.
static func _halo_mesh(tubes: Array, ts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start := 0
	for k in tubes.size():
		var pts: PackedVector3Array = tubes[k]
		var tt: Array = ts[k]
		var n := pts.size()
		var line: Array = []         # [point, axis, t, end fade]
		var f0 := _frame(pts, 0)
		var f1 := _frame(pts, n - 1)
		line.append([pts[0] - f0.x * HALO_END, f0.x, float(tt[0]), 0.0])
		for i in n:
			line.append([pts[i], _frame(pts, i).x, float(tt[i]), 1.0])
		line.append([pts[n - 1] + f1.x * HALO_END, f1.x, float(tt[n - 1]), 0.0])
		for q: Array in line:
			for side: float in [-1.0, 1.0]:
				st.set_normal(q[1])
				st.set_uv(Vector2(side, q[2]))
				st.set_uv2(Vector2(q[3], 0.0))
				st.add_vertex(q[0])
		for i in line.size() - 1:
			var v := start + i * 2
			st.add_index(v)
			st.add_index(v + 2)
			st.add_index(v + 1)
			st.add_index(v + 1)
			st.add_index(v + 2)
			st.add_index(v + 3)
		start += line.size() * 2
	return st.commit()
