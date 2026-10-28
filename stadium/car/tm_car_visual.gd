class_name TmCarVisual
extends Node3D
## Our own Stadium car, modelled to the proportions of TMNF's car (measured locally from its
## visual mesh: tyres r 0.364 m, 0.35 m wide, at x 0.863 / 0.885 and z 1.785 / -1.205; the body
## 3.95 m long and 1.66 m wide; the helmet's top at 1.02 m; guards over the front wheels that
## steer with them and over the rear ones) with our own shapes and livery:
## - a slim tub and nose lofted through rounded trapezoid sections; the section opens into a U
##   for the cockpit, so its rim, inner walls and floor are one surface with the body;
## - sidepods with an undercut and dark inlets, an airbox over the driver's head with its intake,
##   an engine cover with a fin down to a low tail, a floor, front and rear wings with end plates;
## - wishbones, push rods, track rods and drive shafts that follow the wheels;
## - wheels that hold together: the tyre's bead sits under the rim's flange, a dished alloy rim
##   with five twin spokes into the barrel, a centre-lock nut, a ventilated disc and a caliper on
##   the upright (it steers but doesn't spin);
## - the driver: helmet with visor and stripe, collar, shoulders, arms on the steering wheel;
##   windscreen, mirrors, rain light.
## Geometry is built once and shared by every car (static cache); materials are per car (paint
## colour, ghost). Parent it to a TmCar; or, as a ghost (ghost = true), to any Node3D and feed
## ghost_speed and ghost_steer (a replayed run): translucent, no shadow.
## With a pack (TmCarPack: a community car, e.g. from ManiaPark, set before it enters the tree) it
## draws that model and skin instead: its body, its wheels spinning, steering and riding the
## suspension about their own centres, glows at its lamps (the rear ones brighter under braking).
## model "hyper" (set before it enters the tree; the player's pick: TmUi.car_model()) is our
## closed Le Mans hypercar instead of the open-wheeler: its body from assets/car/hypercar.glb
## (made by tools/assets/hypercar.py, in visual coordinates) dressed in our materials by their
## names, on these same wheels without the open-wheeler's guards; its livery in the paint shader
## (mode 3) and stickers (HYPER_STICKERS).
## A road car's id as model (TmRoadCars: tools/assets/roadcar.py's assets/car/<id>.glb) draws that
## car: its body in our materials by name, its paint in the livery `livery` (TmRoadCars.LIVERIES:
## tm_car_surface.gdshader mode 4), on its own wheels at its own places (from its manifest), each
## wheel spinning, steering and riding the suspension like ours, the brake behind it fixed.
## `tuning` (PLAN M18; the road cars and the hypercar) swaps parts: the spoiler and the hood's shape
## for kit parts fitted to the car (TmRoadCars.kit), the rims for the library's (TmRoadCars.rims,
## scaled to the car's wheels, in their own finishes), the hood's finish (the paint shader's carbon
## or black), and lights the road under the car (underglow: a glow decal, tubes under the sills,
## lights; not on ghosts).

const T := preload("res://core/tm_tuning.gd")

## The measured visual's origin in the car's frame (the physics origin is the centre of mass):
## everything below is in visual coordinates (ground at y 0, nose towards +z, left +x).
const VIS := Vector3(0.0, 0.441, 0.29)

## Tub and nose stations: [z, y bottom, y top, half width at the bottom, at the top (shoulder),
## bottom corner radius, shoulder radius, cockpit half width at the rim (0: closed), cockpit depth].
const TUB := [
	[2.168, 0.232, 0.258, 0.014, 0.011, 0.006, 0.005, 0.0, 0.0],
	[2.145, 0.210, 0.286, 0.040, 0.032, 0.018, 0.016, 0.0, 0.0],
	[2.085, 0.188, 0.322, 0.072, 0.058, 0.028, 0.026, 0.0, 0.0],
	[1.950, 0.170, 0.368, 0.108, 0.086, 0.034, 0.036, 0.0, 0.0],
	[1.750, 0.158, 0.418, 0.146, 0.114, 0.040, 0.046, 0.0, 0.0],
	[1.450, 0.150, 0.488, 0.190, 0.146, 0.045, 0.056, 0.0, 0.0],
	[1.100, 0.145, 0.562, 0.236, 0.176, 0.050, 0.066, 0.0, 0.0],
	[0.780, 0.142, 0.622, 0.276, 0.204, 0.055, 0.072, 0.0, 0.0],
	[0.520, 0.140, 0.655, 0.302, 0.224, 0.055, 0.076, 0.0, 0.0],
	[0.400, 0.140, 0.660, 0.312, 0.232, 0.055, 0.076, 0.085, 0.10],
	[0.280, 0.140, 0.650, 0.322, 0.242, 0.055, 0.072, 0.185, 0.24],
	[0.000, 0.140, 0.632, 0.336, 0.256, 0.055, 0.068, 0.205, 0.28],
	[-0.250, 0.140, 0.632, 0.346, 0.266, 0.055, 0.068, 0.205, 0.28],
	[-0.400, 0.142, 0.665, 0.352, 0.262, 0.055, 0.070, 0.170, 0.24],
	[-0.470, 0.144, 0.725, 0.352, 0.240, 0.055, 0.070, 0.060, 0.08],
	[-0.540, 0.146, 0.785, 0.350, 0.226, 0.055, 0.065, 0.0, 0.0],
	[-0.700, 0.150, 0.835, 0.345, 0.222, 0.055, 0.055, 0.0, 0.0],
	[-0.950, 0.160, 0.855, 0.325, 0.218, 0.055, 0.050, 0.0, 0.0],
	[-1.250, 0.185, 0.818, 0.282, 0.196, 0.050, 0.050, 0.0, 0.0],
	[-1.500, 0.235, 0.742, 0.210, 0.156, 0.045, 0.045, 0.0, 0.0],
	[-1.680, 0.295, 0.662, 0.140, 0.106, 0.035, 0.035, 0.0, 0.0],
	[-1.790, 0.350, 0.602, 0.074, 0.056, 0.025, 0.025, 0.0, 0.0],
	[-1.818, 0.380, 0.575, 0.030, 0.024, 0.010, 0.010, 0.0, 0.0],
]
## Sidepods (the +x one; the other is its mirror): [z, x inner, x outer, y bottom, y top, undercut,
## bottom-outer radius, top-outer radius].
const POD := [
	[1.020, 0.20, 0.54, 0.200, 0.420, 0.030, 0.030, 0.040],
	[0.940, 0.20, 0.71, 0.170, 0.460, 0.050, 0.040, 0.050],
	[0.600, 0.20, 0.78, 0.155, 0.480, 0.070, 0.050, 0.060],
	[0.100, 0.20, 0.79, 0.150, 0.475, 0.070, 0.050, 0.060],
	[-0.400, 0.20, 0.76, 0.150, 0.450, 0.070, 0.050, 0.060],
	[-0.750, 0.20, 0.68, 0.155, 0.410, 0.060, 0.040, 0.050],
	[-0.920, 0.20, 0.58, 0.160, 0.370, 0.050, 0.040, 0.050],
]
## The sidepod's inlet is cut at a slant: its top edge this far ahead of its bottom edge (m).
const POD_RAKE := 0.16
const TYRE_R := 0.364
const BEAD_R := 0.232                       ## the tyre's bead: it sits on the rim's seat
const TYRE_HW := [0.172, 0.180]             ## tyre half width, front and rear
const HELMET := Vector3(0.0, 0.852, -0.245)
const HELMET_R := 0.132
const STEER_WHEEL := Vector3(0.0, 0.675, 0.14)

var car: TmCar
var ghost := false
var ghost_speed := 0.0            ## m/s along the car
var ghost_steer := 0.0
var paint_colour := Color(0.85, 0.08, 0.06)
var ghost_tint := Color(0.55, 0.75, 1.0)   ## a ghost's colour (other online players: theirs)
var pack: TmCarPack               ## a community car to draw instead of ours (null: ours)
var model := ""                   ## ours: "" the open-wheeler, "hyper" the hypercar, or a road car (TmRoadCars)
var livery := 0                   ## the road car's (or the hypercar's) livery (TmRoadCars.liveries)
var livery_spec := {}             ## a livery of its own (TmRoadCars.LIVERIES' keys) instead: a story's car
var tuning := {}                  ## its tuning {part: index} (TmRoadCars.TUNING; missing parts: 0, the car as it comes)
var _from_pack := true            ## drawn from the pack's model (false: ours)
var _wheels: Array[Node3D] = []   ## per wheel: the pivot (suspension travel, steering)
var _rest: Array[Vector3] = []    ## per wheel: the pivot's place at rest (node space)
var _radius: Array[float] = []    ## per wheel: the tyre's radius (its spin)
var _spins: Array[Node3D] = []    ## per wheel: the node that spins (about its x)
var _brake_glow: Array[StandardMaterial3D] = []
var _arms := []                   ## [MeshInstance3D, inner point (node space), outer offset from the wheel centre, wheel]
var _spin := 0.0
var _mats := {}
var _rename := {}                 ## our parts' material names -> this car's (the hypercar's rims)

static var _shared := {}          ## part name -> ArrayMesh, built once for every car


## Wheel centre at rest (visual coordinates; the tyre's bottom 1 cm into the road, as TMNF's).
static func wheel_centre(i: int) -> Vector3:
	return T.WHEELS[i] + VIS


func _ghostly(m: StandardMaterial3D) -> StandardMaterial3D:
	if ghost:
		m.albedo_color = Color(m.albedo_color, 0.38)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.clearcoat_enabled = false
		m.emission_enabled = false
	return m


## The car's own surface shader (HD graphics, not for ghosts): paint with flakes and a stripe,
## carbon weave, tyre tread, the hypercar's livery.
func _surface(mode: int, colour: Color, stripe: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://car/tm_car_surface.gdshader")
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("colour", colour)
	m.set_shader_parameter("stripe_half", stripe)
	m.set_shader_parameter("tyre_radius", TYRE_R)
	m.set_shader_parameter("tyre_half_width", TYRE_HW[0])
	return m


func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	if not ghost and TmMaterials.hd() and key in ["paint", "paint_plain", "white", "carbon", "tyre", "hyper_paint",
			"hyper_carbon", "hyper_black"]:
		var sm: ShaderMaterial
		match key:
			"paint": sm = _surface(0, paint_colour, 0.07)
			"paint_plain": sm = _surface(0, paint_colour, 0.0)
			"white":
				sm = _surface(0, Color(0.93, 0.93, 0.94), 0.0)
				sm.set_shader_parameter("flakes", 0.0)
			"carbon": sm = _surface(1, Color.BLACK, 0.0)
			"tyre": sm = _surface(2, Color.BLACK, 0.0)
			# the hypercar's parts are in visual coordinates (the ground at y 0); its first livery is
			# its own (mode 3, the player's colour), the others are drawn like a road car's
			"hyper_paint":
				var lv := TmRoadCars.livery("hyper", livery)
				if String(lv.get("pattern", "hyper")) == "hyper":
					sm = _surface(3, paint_colour, 0.0)
					_frame_uniforms(sm, "hyper")
					sm.set_shader_parameter("liv_hood", _hood_finish(""))
				else:
					sm = _livery_paint("hyper", lv)
			"hyper_carbon": sm = _surface(1, Color.BLACK, 0.0)
			"hyper_black":
				sm = _surface(0, Color(0.012, 0.012, 0.014), 0.0)
				sm.set_shader_parameter("flakes", 0.0)
		if key.begins_with("hyper_"):
			sm.set_shader_parameter("ground_y", 0.0)
		_mats[key] = sm
		return sm
	var m := StandardMaterial3D.new()
	match key:
		"paint", "paint_plain", "hyper_paint":
			m.albedo_color = paint_colour if not ghost else ghost_tint
			m.metallic = 0.15
			m.roughness = 0.32
			m.clearcoat_enabled = true
		"hyper_black":
			m.albedo_color = Color(0.012, 0.012, 0.014)
			m.metallic = 0.2
			m.roughness = 0.2
			m.clearcoat_enabled = true
		"led":
			m.albedo_color = Color(0.92, 0.96, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.85, 0.92, 1.0)
			m.emission_energy_multiplier = 4.0
		"white", "helmet":
			m.albedo_color = Color(0.93, 0.93, 0.94) if not ghost else Color(0.7, 0.85, 1.0)
			m.metallic = 0.1
			m.roughness = 0.3
			m.clearcoat_enabled = true
		"carbon", "hyper_carbon":
			m.albedo_color = Color(0.06, 0.06, 0.07)
			m.metallic = 0.3
			m.roughness = 0.4
		"metal":
			m.albedo_color = Color(0.70, 0.71, 0.74)
			m.metallic = 1.0
			m.roughness = 0.3
		"rim":
			# machined alloy: bright, a little rough so it doesn't mirror the sky like chrome
			m.albedo_color = Color(0.83, 0.84, 0.86)
			m.metallic = 1.0
			m.roughness = 0.22
		"rim_dark":
			m.albedo_color = Color(0.16, 0.16, 0.17)
			m.metallic = 0.8
			m.roughness = 0.5
		"hyper_rim":
			# forged, in dark graphite
			m.albedo_color = Color(0.11, 0.11, 0.12)
			m.metallic = 0.9
			m.roughness = 0.32
		"disc":
			m.albedo_color = Color(0.36, 0.35, 0.34)
			m.metallic = 0.9
			m.roughness = 0.55
		"caliper":
			m.albedo_color = Color(0.82, 0.10, 0.06)
			m.metallic = 0.2
			m.roughness = 0.35
			m.clearcoat_enabled = true
		"tyre":
			m.albedo_color = Color(0.035, 0.035, 0.04)
			m.roughness = 0.9
		"visor":
			m.albedo_color = Color(0.04, 0.05, 0.07)
			m.metallic = 0.7
			m.roughness = 0.08
		"cockpit":
			m.albedo_color = Color(0.035, 0.035, 0.04)
			m.roughness = 0.85
		"inlet":
			m.albedo_color = Color(0.015, 0.015, 0.018)
			m.roughness = 0.95
		"suit":
			m.albedo_color = Color(0.08, 0.08, 0.10) if not ghost else ghost_tint
			m.roughness = 0.8
		"glass_dark":
			m.albedo_color = Color(0.03, 0.035, 0.045)
			m.metallic = 0.4
			m.roughness = 0.06
			m.clearcoat_enabled = true
		"glass":
			m.albedo_color = Color(0.55, 0.62, 0.70, 0.28)
			m.roughness = 0.04
			m.metallic = 0.3
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"mirror":
			m.albedo_color = Color(0.9, 0.92, 0.95)
			m.metallic = 1.0
			m.roughness = 0.02
		"light":
			m.albedo_color = Color(0.9, 0.08, 0.05)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.1, 0.05)
			m.emission_energy_multiplier = 2.0
	_mats[key] = _ghostly(m)
	return _mats[key]


func _ready() -> void:
	car = get_parent() as TmCar
	if pack != null and pack.ok() and not pack.skin_only:
		_pack_parts()
		if not ghost:
			add_child(contact_shadow())
		return
	if pack != null and pack.skin_only:
		paint_colour = pack.colour       # a skin without its model: ours in its colour
		if ghost:
			ghost_tint = pack.colour
	_from_pack = false
	if TmRoadCars.is_road(model) and not TmRoadCars.meshes(model).is_empty():
		_road_parts()
		if not ghost:
			add_child(contact_shadow())
			_underglow()
		return
	_shared_meshes()
	var hyper := model == "hyper" and _hyper_mesh() != null
	if hyper:
		_rename = {"rim": "hyper_rim"}     # dark forged rims on the hypercar
	_part(_hyper_instance() if hyper else _instance("body"))
	if hyper:
		_tuned_parts(_hyper_mesh("HyperSpoiler"), _hyper_dress)
	var rim := _tune("rims") if hyper else 0
	for i in 4:
		var front := i < 2
		var pivot := Node3D.new()
		# steered, sprung and spun every rendered frame (_process): not interpolated again between
		# physics ticks on top of the car's own interpolation
		pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		pivot.position = wheel_centre(i) - VIS
		add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var side := "L" if T.WHEELS[i].x > 0.0 else "R"
		var axle := "F" if front else "B"
		if rim > 0:
			# the library's rim on our tyre (its bead) and disc
			spin.add_child(_instance("tyre" + axle + side, true))
			spin.add_child(_kit_rim(rim, BEAD_R + 0.004, float(TYRE_HW[0 if front else 1]), side == "R"))
		else:
			spin.add_child(_instance("wheel" + axle + side, true))
		pivot.add_child(_instance(("hubH" if hyper else "hub") + axle + side, true))
		_wheels.append(pivot)
		_spins.append(spin)
		_rest.append(pivot.position)
		_radius.append(TYRE_R)
	if not hyper:
		_suspension()                # (the hypercar's are under its bodywork)
	if not ghost:
		add_child(contact_shadow())
		if TmMaterials.hd():
			_livery(HYPER_STICKERS if hyper else STICKERS)
		if hyper:
			_underglow()


## The soft shade on the road under the car (TMNF and TM2020 bake it into the map; ours moves
## with the car): a decal projected straight down from just below the floor, so it reaches the
## road through the suspension's travel and nothing of the car itself; faded on surfaces that
## don't face up, and gone when the car is in the air (nothing within its reach).
func contact_shadow() -> Decal:
	var d := Decal.new()
	d.name = "ContactShadow"
	d.texture_albedo = _shadow_tex()
	d.modulate = Color(0.0, 0.0, 0.0, CONTACT_SHADOW)
	d.albedo_mix = 1.0
	d.normal_fade = 0.6
	d.upper_fade = 0.15
	d.lower_fade = 0.4
	d.size = Vector3(3.0, 0.42, 5.6)     # reaching ~0.45 m past the wheels and the wings
	# visual coords: ground at y 0, the floor at 0.13; the box from 0.29 below the ground up to 0.13
	d.position = Vector3(0.0, -0.08, 0.17) - VIS
	d.distance_fade_enabled = true
	d.distance_fade_begin = 80.0
	d.distance_fade_length = 20.0
	return d


## Livery stickers (stadium/tools/texgen/livery.py): [texture, centre (visual coords), size
## (u across, projection depth, v along), basis: u, projection (decal -y), v].
const STICKERS := [
	# the race number on the nose, read from in front (the chase camera can't see the nose past
	# the airbox; other players and replays do)
	["livery_number", Vector3(0.0, 0.66, 1.12), Vector3(0.30, 0.34, 0.38), Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1)],
	# (no sponsor on the sidepods: the owner, 22 Oct, "remove the ORLAN stickers from the formula car")
	# our emblem on the engine cover's flanks, behind the driver
	["livery_emblem", Vector3(0.27, 0.70, -0.85), Vector3(0.62, 0.22, 0.16), Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, -1, 0)],
	["livery_emblem", Vector3(-0.27, 0.70, -0.85), Vector3(0.62, 0.22, 0.16), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, -1, 0)],
]
## The hypercar's stickers (as STICKERS): the race number on the nose and on each flank ahead of
## the rear wheels, our emblem on the end plates (no sponsors: the owner, 22 Oct).
const HYPER_STICKERS := [
	["livery_number", Vector3(0.0, 0.50, 2.20), Vector3(0.26, 0.30, 0.32), Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1)],
	["livery_number", Vector3(1.0, 0.43, -0.32), Vector3(0.30, 0.34, 0.37), Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, -1, 0)],
	["livery_number", Vector3(-1.0, 0.43, -0.32), Vector3(0.30, 0.34, 0.37), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, -1, 0)],
	["livery_emblem", Vector3(1.0, 0.97, -1.90), Vector3(0.50, 0.10, 0.13), Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, -1, 0)],
	["livery_emblem", Vector3(-1.0, 0.97, -1.90), Vector3(0.50, 0.10, 0.13), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, -1, 0)],
]


## The livery: decals that move with the car (the stickers' places are on the tub's nose and the
## sidepods' flat sides; faded on surfaces that don't face them).
func _livery(stickers: Array) -> void:
	for st: Array in stickers:
		var tex := TmMaterials._tex(String(st[0]), "albedo")
		if tex == null:
			continue
		var d := Decal.new()
		d.name = "Sticker"
		d.texture_albedo = tex
		d.size = st[2]
		var u: Vector3 = st[3]
		var down: Vector3 = st[4]
		var v: Vector3 = st[5]
		d.transform = Transform3D(Basis(u, -down, v), (st[1] as Vector3) - VIS)
		d.normal_fade = 0.55
		d.upper_fade = 0.05
		d.lower_fade = 0.05
		d.distance_fade_enabled = true
		d.distance_fade_begin = 60.0
		d.distance_fade_length = 15.0
		add_child(d)


const CONTACT_SHADOW := 0.8          ## the shade's darkness at its core
static var _shadow: ImageTexture


## A soft rounded rectangle, the car's footprint (wheels included), dark at the core.
static func _shadow_tex() -> ImageTexture:
	if _shadow == null:
		var w := 64
		var h := 128
		var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				# distance outside a core rectangle, in fractions of the half size
				var u := absf((x + 0.5) / w * 2.0 - 1.0)
				var v := absf((y + 0.5) / h * 2.0 - 1.0)
				var du := maxf(0.0, u - 0.5) / 0.5
				var dv := maxf(0.0, v - 0.62) / 0.38
				var t := clampf(1.0 - sqrt(du * du + dv * dv), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, t * t * (3.0 - 2.0 * t)))
		img.generate_mipmaps()
		_shadow = ImageTexture.create_from_image(img)
	return _shadow


func _part(mi: MeshInstance3D) -> void:
	add_child(mi)


## A community car's model: the body, and per wheel a pivot at the wheel's centre that steers and
## rides the suspension, holding the hub and guard (fixed) and the wheel (spinning). A model whose
## wheels are part of its body gets empty pivots.
func _pack_parts() -> void:
	var body := _pack_instance(pack.body)
	body.position = -VIS
	add_child(body)
	for i in 4:
		var w: Dictionary = pack.wheels[i]
		var pivot := Node3D.new()
		pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		pivot.position = ((w["centre"] as Vector3) - VIS) if not w.is_empty() else T.WHEELS[i]
		add_child(pivot)
		# the wheel part's own frame: it spins about its x (a hovercraft's fan, cambered wheels)
		var axle := Node3D.new()
		axle.basis = w.get("axle", Basis.IDENTITY)
		pivot.add_child(axle)
		var spin := Node3D.new()
		axle.add_child(spin)
		_spins.append(spin)
		var radius := TYRE_R
		if not w.is_empty():
			if w["spin"] != null:
				spin.add_child(_pack_instance(w["spin"], true))
				var box := (w["spin"] as ArrayMesh).get_aabb()
				radius = maxf(0.1, maxf(box.size.y, box.size.z) * 0.5)
			if w["fixed"] != null:
				pivot.add_child(_pack_instance(w["fixed"], true))
		_wheels.append(pivot)
		_rest.append(pivot.position)
		_radius.append(radius)
	if ghost:
		return
	for name: String in pack.lamps:
		var low := name.to_lower()
		if not low.begins_with("lightr") and not low.begins_with("lightf") or low.contains("proj"):
			continue
		var rear := low.begins_with("lightr")
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.12, 0.08) if rear else Color(1.0, 0.95, 0.85)
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 1.6 if rear else 2.5
		var glow := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.05
		sphere.height = 0.1
		sphere.radial_segments = 8
		sphere.rings = 4
		glow.mesh = sphere
		glow.material_override = m
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.position = (pack.lamps[name] as Vector3) - VIS
		add_child(glow)
		if rear:
			_brake_glow.append(m)


func _pack_instance(mesh: ArrayMesh, wheel := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	for s in mesh.get_surface_count():
		var key := mesh.surface_get_name(s)
		if not _mats.has(key):
			_mats[key] = pack.material(key, ghost, paint_colour if not ghost else ghost_tint)
		mi.set_surface_override_material(s, _mats[key])
	if ghost:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if wheel:
		mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return mi


const HYPER_GLB := "res://assets/car/hypercar.glb"
## The hypercar's materials (by the names tools/assets/hypercar.py gives them) -> ours.
const HYPER_MATS := {"paint": "hyper_paint", "carbon": "hyper_carbon", "black": "hyper_black",
	"glass_dark": "glass_dark", "inlet": "inlet", "light": "light", "led": "led", "mirror": "mirror"}


## The hypercar's parts (HyperBody: one mesh, a surface per material; HyperSpoiler: its wing, end
## plates and their lights), loaded once for every car. An older glb's only mesh is its body.
static func _hyper_mesh(part := "HyperBody") -> ArrayMesh:
	if not _shared.has("hyper"):
		var parts := {}
		var scene := load(HYPER_GLB) as PackedScene
		if scene != null:
			var root := scene.instantiate()
			var found := root.find_children("*", "MeshInstance3D", true, false)
			for mi: MeshInstance3D in found:
				parts[String(mi.name)] = mi.mesh
			if not parts.has("HyperBody") and not found.is_empty():
				parts["HyperBody"] = (found[0] as MeshInstance3D).mesh
			root.free()
		_shared["hyper"] = parts
	return (_shared["hyper"] as Dictionary).get(part) as ArrayMesh


func _hyper_instance() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = _hyper_mesh()
	mi.position = -VIS
	_hyper_dress(mi)
	return mi


## The hypercar's materials on a part (its body's, a kit part's) by their names.
func _hyper_dress(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		var src := mesh.surface_get_material(s)
		var name: String = src.resource_name if src != null else mesh.surface_get_name(s)
		mi.set_surface_override_material(s, _mat(String(HYPER_MATS.get(name, "hyper_paint"))))
	if ghost:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _instance(name: String, wheel := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh: ArrayMesh = _shared[name]
	mi.mesh = mesh
	for s in mesh.get_surface_count():
		var key := mesh.surface_get_name(s)
		mi.set_surface_override_material(s, _mat(String(_rename.get(key, key))))
	if ghost:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if wheel:
		mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return mi


# --- road cars (TmRoadCars) ---------------------------------------------------------------------

## The road car's materials by the names tools/assets/roadcar.py gives them -> ours.
const ROAD_MATS := {"paint": "road_paint", "glass": "road_glass", "rim": "road_rim", "caliper": "road_caliper",
	"tyre": "road_tyre", "grille": "road_grille", "plate": "road_plate"}


func _road_parts() -> void:
	var rc := TmRoadCars.meshes(model)
	var man := TmRoadCars.manifest(model)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = rc["Body"]
	body.position = -VIS
	_road_dress(body)
	add_child(body)
	_tuned_parts(rc.get("Spoiler"), _road_dress)
	var cs: Array = man["wheels"]
	var radii: Array = man["tyre_r"]
	var rim := _tune("rims")
	for i in 4:
		var axle := "F" if i < 2 else "R"
		var c: Array = cs[i]
		var pivot := Node3D.new()
		pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		pivot.position = Vector3(float(c[0]), float(c[1]), float(c[2])) - VIS
		add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var right := float(c[0]) < 0.0
		# the tyre and the car's own rim (an older glb: one wheel), or the library's rim
		for part: String in ["Wheel", "Tyre", "Rim", "Brake"]:
			if not rc.has(part + axle) or part == "Rim" and rim > 0:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = rc[part + axle]
			mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			if right:
				mi.scale = Vector3(-1.0, 1.0, 1.0)
			_road_dress(mi)
			(pivot if part == "Brake" else spin).add_child(mi)
		if rim > 0 and rc.has("Tyre" + axle):
			var rr: Array = man.get("rim_r", [float(radii[0]) - 0.08, float(radii[1]) - 0.08])
			var hw: Array = man.get("tyre_hw", [0.12, 0.12])
			spin.add_child(_kit_rim(rim, float(rr[0 if i < 2 else 1]), float(hw[0 if i < 2 else 1]), right))
		_wheels.append(pivot)
		_spins.append(spin)
		_rest.append(pivot.position)
		_radius.append(float(radii[0 if i < 2 else 1]))


func _road_dress(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		var src := mesh.surface_get_material(s)
		var name: String = src.resource_name if src != null else mesh.surface_get_name(s)
		mi.set_surface_override_material(s, _road_mat(String(ROAD_MATS.get(name, name))))
	if ghost:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The car's livery: its own (livery_spec) or its model's `livery`.
func _livery_now() -> Dictionary:
	return livery_spec if not livery_spec.is_empty() else TmRoadCars.livery(model, livery)


## A livery's paint (tm_car_surface.gdshader mode 4) on car `id`'s body (its manifest's lines).
func _livery_paint(id: String, lv: Dictionary) -> ShaderMaterial:
	var man := TmRoadCars.manifest(id)
	var sm := _surface(4, lv.get("base", paint_colour), 0.0)
	sm.set_shader_parameter("livery", maxi(0, TmRoadCars.PATTERNS.find(String(lv.get("pattern", "plain")))))
	sm.set_shader_parameter("liv_a", lv.get("a", Color.WHITE))
	sm.set_shader_parameter("liv_b", lv.get("b", Color.BLACK))
	sm.set_shader_parameter("liv_c", lv.get("c", Color.BLACK))
	sm.set_shader_parameter("liv_p", lv.get("p", Vector4.ZERO))
	sm.set_shader_parameter("finish", FINISHES.get(String(lv.get("finish", "metallic")), FINISHES["metallic"]))
	sm.set_shader_parameter("liv_hood", _hood_finish(String(lv.get("hood", ""))))
	sm.set_shader_parameter("liv_roof", ["", "black"].find(String(lv.get("roof", ""))))
	_frame_uniforms(sm, id)
	sm.set_shader_parameter("flakes", 1.0 if String(lv.get("finish", "metallic")) in ["metallic", "pearl"] else 0.0)
	return sm


## The body's lines along the car (its manifest) for the paint shader's livery and hood.
func _frame_uniforms(sm: ShaderMaterial, id: String) -> void:
	var man := TmRoadCars.manifest(id)
	var an: Dictionary = man.get("anchors", {})
	for k: String in ["top", "belt", "mid", "sill", "hw"]:
		sm.set_shader_parameter("an_" + k, PackedFloat32Array(an.get(k, [])))
	sm.set_shader_parameter("z_nose", float(man.get("z_nose", 2.5)))
	sm.set_shader_parameter("z_tail", float(man.get("z_tail", -2.0)))
	var cab: Array = man.get("cabin", [1.5, 3.5])
	sm.set_shader_parameter("cabin", Vector2(float(cab[0]), float(cab[1])))
	# the hypercar's hood is its whole front deck (the nose between and over the fender pods)
	sm.set_shader_parameter("hood_all", id == "hyper")


## The hood's finish for the paint shader (0 paint, 1 carbon, 2 black): the tuning's, else the
## livery's.
func _hood_finish(livery_hood: String) -> int:
	var hf := String(TmRoadCars.HOODS[_tune("hood")]["finish"])
	return ["", "carbon", "black"].find(hf if hf != "" else livery_hood)


## Tuning part `part`'s pick for this car (0 for a car without tuning).
func _tune(part: String) -> int:
	if not TmRoadCars.tunable(model):
		return 0
	return clampi(int(tuning.get(part, 0)), 0, TmRoadCars.options(part).size() - 1)


## The tuning's spoiler (the car's own `stock` for 0, none for 1, else the kit's) and the hood's
## shape (the kit's), each a part in visual coordinates dressed like the body (`dress`).
func _tuned_parts(stock: Mesh, dress: Callable) -> void:
	var kit := TmRoadCars.kit(model)
	var parts := {}
	var sp := _tune("spoiler")
	if sp == 0:
		parts["Spoiler"] = stock
	elif sp >= 2:
		parts["Spoiler"] = kit.get("Spoiler%d" % sp)
	var shape := String(TmRoadCars.HOODS[_tune("hood")]["shape"])
	if shape != "":
		parts["Hood"] = kit.get("Hood" + shape.capitalize())
	for name: String in parts:
		if parts[name] == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = name
		mi.mesh = parts[name]
		mi.position = -VIS
		dress.call(mi)
		add_child(mi)


## The rim library's rim k (TmRoadCars.rims) scaled to a wheel whose bead sits at radius rr and
## whose half width is hw, in its finish (the +x side's; mirrored for the right side).
func _kit_rim(k: int, rr: float, hw: float, right: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Rim"
	mi.mesh = TmRoadCars.rims().get("Rim%d" % k)
	if mi.mesh == null:
		return mi
	var a := hw / TmRoadCars.RIM_REF.y
	var r := rr / TmRoadCars.RIM_REF.x
	mi.scale = Vector3(-a if right else a, r, r)
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for s in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(s)
		var name: String = src.resource_name if src != null else mi.mesh.surface_get_name(s)
		mi.set_surface_override_material(s, _kit_rim_mat(k) if name == "rim" else _road_mat("rim_lip"))
	if ghost:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A library rim's finish (TmRoadCars.RIMS): its own colour, else the livery's rim colour.
func _kit_rim_mat(k: int) -> Material:
	var key := "kit_rim%d" % k
	if not _mats.has(key):
		var r: Dictionary = TmRoadCars.RIMS[k]
		var m := StandardMaterial3D.new()
		m.albedo_color = r.get("colour", _livery_now().get("rim", Color(0.78, 0.79, 0.81)))
		m.metallic = float(r.get("metallic", 0.9))
		m.roughness = float(r.get("roughness", 0.28))
		_mats[key] = _ghostly(m)
	return _mats[key]


## Underglow (tuning "glow"; not on ghosts): TmUnderglow, fitted to this car.
func _underglow() -> void:
	var u := TmUnderglow.make(model, TmRoadCars.GLOWS[_tune("glow")])
	if u != null:
		u.position = -VIS
		add_child(u)


## The finishes a livery can have: metallic, roughness, clearcoat, pearl.
const FINISHES := {"gloss": Vector4(0.05, 0.22, 1.0, 0.0), "metallic": Vector4(0.45, 0.3, 1.0, 0.0),
	"pearl": Vector4(0.25, 0.26, 1.0, 0.55), "matte": Vector4(0.1, 0.62, 0.0, 0.0), "chrome": Vector4(1.0, 0.06, 0.6, 0.0)}


func _road_mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var lv := _livery_now()
	var man := TmRoadCars.manifest(model)
	var base: Color = lv.get("base", paint_colour)
	if not ghost and TmMaterials.hd() and key in ["road_paint", "road_tyre", "road_grille", "carbon"]:
		var sm: ShaderMaterial
		match key:
			"road_paint": sm = _livery_paint(model, lv)
			"road_tyre":
				sm = _surface(2, Color.BLACK, 0.0)
				var r: Array = man.get("tyre_r", [TYRE_R])
				var hw: Array = man.get("tyre_hw", [TYRE_HW[0]])
				sm.set_shader_parameter("tyre_radius", float(r[0]))
				sm.set_shader_parameter("tyre_half_width", float(hw[0]))
			"road_grille": sm = _surface(5, Color.BLACK, 0.0)
			"carbon": sm = _surface(1, Color.BLACK, 0.0)
		sm.set_shader_parameter("ground_y", 0.0)
		_mats[key] = sm
		return sm
	var m := StandardMaterial3D.new()
	match key:
		"road_paint":
			m.albedo_color = base if not ghost else ghost_tint
			m.metallic = 0.3
			m.roughness = 0.3
			m.clearcoat_enabled = true
		"trim":
			m.albedo_color = Color(0.03, 0.03, 0.033)
			m.roughness = 0.62
		"gloss_black":
			m.albedo_color = Color(0.01, 0.01, 0.012)
			m.metallic = 0.1
			m.roughness = 0.12
			m.clearcoat_enabled = true
		"chrome", "rim_lip":
			m.albedo_color = Color(0.9, 0.9, 0.92)
			m.metallic = 1.0
			m.roughness = 0.06 if key == "chrome" else 0.12
		"road_glass":
			# tinted, mirrors the sky; the cabin behind it reads dark
			m.albedo_color = Color(0.015, 0.018, 0.024)
			m.metallic = 0.6
			m.roughness = 0.03
			m.clearcoat_enabled = true
		"lens":
			m.albedo_color = Color(0.85, 0.9, 0.95, 0.12)
			m.metallic = 0.2
			m.roughness = 0.02
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"lens_red":
			m.albedo_color = Color(0.6, 0.02, 0.02, 0.55)
			m.roughness = 0.03
			m.metallic = 0.2
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"lamp":
			# the lamps' insides: a darkened chrome, so the lenses and LEDs stand out
			m.albedo_color = Color(0.42, 0.43, 0.46)
			m.metallic = 1.0
			m.roughness = 0.24
		"proj":
			# a projector's lens: thick dark glass with sharp highlights
			m.albedo_color = Color(0.02, 0.022, 0.03)
			m.metallic = 0.6
			m.roughness = 0.02
			m.clearcoat_enabled = true
		"amber":
			m.albedo_color = Color(1.0, 0.55, 0.08)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.5, 0.05)
			m.emission_energy_multiplier = 0.5
			m.roughness = 0.3
		"road_grille":
			m.albedo_color = Color(0.02, 0.02, 0.022)
			m.roughness = 0.7
		"gap":
			m.albedo_color = Color(0.004, 0.004, 0.005)
			m.roughness = 0.9
		"road_plate":
			m.albedo_color = Color(0.9, 0.9, 0.88)
			m.roughness = 0.45
		"road_rim":
			m.albedo_color = Color(lv.get("rim", Color(0.75, 0.76, 0.78)))
			m.metallic = 0.9
			m.roughness = 0.28
		"road_caliper":
			m.albedo_color = Color(lv.get("caliper", Color(0.82, 0.10, 0.06)))
			m.metallic = 0.2
			m.roughness = 0.35
			m.clearcoat_enabled = true
		"road_tyre":
			m.albedo_color = Color(0.035, 0.035, 0.04)
			m.roughness = 0.9
		_:
			return _mat(key)
	_mats[key] = _ghostly(m)
	return _mats[key]


# --- suspension: arms from the tub to the upright, re-aimed every frame -----------------------

## [wheel, inner point, outer point at rest, radius across, radius up, material] (visual coords;
## the +x side, mirrored for the others).
const ARMS := [
	[0, Vector3(0.09, 0.220, 1.98), Vector3(0.70, 0.275, 1.79), 0.020, 0.009, "carbon"],
	[0, Vector3(0.17, 0.200, 1.58), Vector3(0.70, 0.275, 1.78), 0.020, 0.009, "carbon"],
	[0, Vector3(0.07, 0.360, 1.97), Vector3(0.69, 0.495, 1.79), 0.018, 0.008, "carbon"],
	[0, Vector3(0.13, 0.450, 1.62), Vector3(0.69, 0.495, 1.78), 0.018, 0.008, "carbon"],
	[0, Vector3(0.10, 0.450, 1.70), Vector3(0.68, 0.300, 1.78), 0.012, 0.012, "metal"],
	[0, Vector3(0.11, 0.330, 1.91), Vector3(0.68, 0.380, 1.91), 0.010, 0.010, "metal"],
	[2, Vector3(0.30, 0.200, -0.95), Vector3(0.73, 0.245, -1.20), 0.020, 0.009, "carbon"],
	[2, Vector3(0.21, 0.215, -1.45), Vector3(0.73, 0.245, -1.21), 0.020, 0.009, "carbon"],
	[2, Vector3(0.23, 0.480, -1.00), Vector3(0.72, 0.490, -1.20), 0.018, 0.008, "carbon"],
	[2, Vector3(0.165, 0.500, -1.42), Vector3(0.72, 0.490, -1.21), 0.018, 0.008, "carbon"],
	[2, Vector3(0.22, 0.355, -1.204), Vector3(0.74, 0.355, -1.204), 0.024, 0.024, "metal"],
]


func _suspension() -> void:
	for a: Array in ARMS:
		for side: float in [1.0, -1.0]:
			var w: int = a[0] + (0 if side > 0.0 else 1)
			var inner: Vector3 = a[1]
			var outer: Vector3 = a[2]
			inner.x *= side
			outer.x *= side
			var mi := MeshInstance3D.new()
			mi.mesh = _tube_mesh(float(a[3]), float(a[4]))
			mi.material_override = _mat(String(a[5]))
			mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			if ghost:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_arms.append([mi, inner - VIS, outer - wheel_centre(w), w])
	_aim_arms()


func _aim_arms() -> void:
	for a: Array in _arms:
		var mi: MeshInstance3D = a[0]
		var inner: Vector3 = a[1]
		var outer: Vector3 = (_wheels[int(a[3])] as Node3D).position + (a[2] as Vector3)
		var d := outer - inner
		var len := d.length()
		if len < 1e-4:
			continue
		var z := d / len
		var x := Vector3.UP.cross(z)
		x = x.normalized() if x.length_squared() > 1e-6 else Vector3.RIGHT
		var y := z.cross(x)
		mi.transform = Transform3D(Basis(x, y, z * len), inner)


## A streamlined tube along +z from 0 to 1 (scaled to each arm's length), elliptic section.
static func _tube_mesh(rx: float, ry: float) -> ArrayMesh:
	var key := "tube_%.3f_%.3f" % [rx, ry]
	if _shared.has(key):
		return _shared[key]
	var m := TmMesher.new()
	var rows := []
	for z: float in [0.0, 1.0]:
		var ring := PackedVector3Array()
		for k in 10:
			var a := TAU * k / 10.0
			ring.append(Vector3(cos(a) * rx, sin(a) * ry, z))
		rows.append(ring)
	m.loft("tube", rows, true)
	var mesh := m.build()
	_shared[key] = mesh
	return mesh


func _process(delta: float) -> void:
	if car and _mats.has("light") and _mats["light"] is StandardMaterial3D:   # brake lights
		(_mats["light"] as StandardMaterial3D).emission_energy_multiplier = 7.0 if car.brake > 0.1 else 1.6
	for m in _brake_glow:
		m.emission_energy_multiplier = 6.0 if car and car.brake > 0.1 else 1.6
	var vz := car.local_velocity().z if car else ghost_speed
	_spin += vz * delta             # metres rolled: each wheel turns by its own radius
	var steer_vis := deg_to_rad(T.lin([[0.0, 30.0], [100.0, 10.0]], absf(vz) * 3.6)) * (car.model.steer if car else ghost_steer)
	for i in 4:
		var w := _wheels[i]
		w.position = _rest[i] + Vector3(0.0, T.SUSP_STATIC - (car.model.susp_len[i] if car else T.SUSP_STATIC), 0.0)
		w.rotation = Vector3(0.0, steer_vis if i < 2 else 0.0, 0.0)
		_spins[i].rotation = Vector3(fmod(_spin / _radius[i], TAU), 0.0, 0.0)
	if not _from_pack:
		_aim_arms()


# --- the shared geometry ------------------------------------------------------------------------

static func _shared_meshes() -> void:
	if _shared.has("body"):
		return
	var body := TmMesher.new()
	body.offset = -VIS
	var half := TmMesher.new()           # the +x side's own parts, mirrored into the body
	half.offset = -VIS
	_tub(body)
	_pods(half)
	_wings(body, half)
	_floor(body)
	_cockpit(body, half)
	_driver(body, half)
	body.add_mirror_x(half)             # the -x side ...
	var h2 := TmMesher.new()
	h2.add_mirror_x(half)
	body.add_mirror_x(h2)               # ... and the +x side itself (mirrored twice)
	_shared["body"] = body.build()
	for axle in ["F", "B"]:
		var front: bool = axle == "F"
		var hw: float = TYRE_HW[0 if front else 1]
		var wl := TmMesher.new()
		_wheel(wl, hw)
		var hl := TmMesher.new()
		_hub(hl, hw, front)
		var bl := TmMesher.new()            # the hypercar's: no guard (its body covers the wheel)
		_hub(bl, hw, front, false)
		_shared["wheel" + axle + "L"] = wl.build()
		_shared["hub" + axle + "L"] = hl.build()
		_shared["hubH" + axle + "L"] = bl.build()
		var wr := TmMesher.new()
		wr.add_mirror_x(wl)
		var hr := TmMesher.new()
		hr.add_mirror_x(hl)
		var br := TmMesher.new()
		br.add_mirror_x(bl)
		_shared["wheel" + axle + "R"] = wr.build()
		_shared["hub" + axle + "R"] = hr.build()
		_shared["hubH" + axle + "R"] = br.build()
		# the tyre and disc alone (a tuned rim goes in their place)
		for side: String in ["L", "R"]:
			_shared["tyre" + axle + side] = _surfaces(_shared["wheel" + axle + side], ["tyre", "disc"])


## A mesh of some of another's surfaces (by name).
static func _surfaces(src: ArrayMesh, keep: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		if src.surface_get_name(s) in keep:
			out.add_surface_from_arrays(src.surface_get_primitive_type(s), src.surface_get_arrays(s))
			out.surface_set_name(out.get_surface_count() - 1, src.surface_get_name(s))
	return out


## The tub's section at a station: a rounded trapezoid that opens into a U for the cockpit.
## Corners (counter-clockwise seen from the front): bottom centre, bottom-right, shoulder, rim,
## the cockpit's floor corner, floor centre, then the left side back down.
const ARC := 5
const MID := 3


static func _tub_ring(s: Array) -> PackedVector2Array:
	var yb: float = s[1]
	var yt: float = s[2]
	var wb: float = s[3]
	var wt: float = s[4]
	var cw: float = maxf(float(s[7]), 0.0)
	var cd: float = maxf(float(s[8]), 0.0)
	var poly := [Vector2(0.0, yb), Vector2(wb, yb), Vector2(wt, yt), Vector2(cw, yt),
		Vector2(cw * 0.88, yt - cd), Vector2(0.0, yt - cd), Vector2(-cw * 0.88, yt - cd),
		Vector2(-cw, yt), Vector2(-wt, yt), Vector2(-wb, yb)]
	var r_rim := minf(0.018, cw * 0.2)
	var r_floor := minf(0.04, cd * 0.3)
	var radii := [0.0, s[5], s[6], r_rim, r_floor, 0.0, r_floor, r_rim, s[6], s[5]]
	return TmMesher.rounded(poly, radii, ARC, MID)


static func _tub(m: TmMesher) -> void:
	var rows := TmMesher.resample(TUB, 4)
	var outer := []
	var inner := []
	var per := ARC + MID
	var rim_r := 3 * per + ARC - 1          # the right rim corner's last point
	var rim_l := 7 * per                     # the left rim corner's first point
	var tip := Vector3.ZERO
	var tail := Vector3.ZERO
	for k in rows.size():
		var s: Array = rows[k]
		var ring := _tub_ring(s)
		var z: float = s[0]
		var o := PackedVector3Array()
		var n := ring.size()
		for i in range(rim_l, n + rim_r + 1):
			var q := ring[i % n]
			o.append(Vector3(q.x, q.y, z))
		var ins := PackedVector3Array()
		for i in range(rim_r, rim_l + 1):
			var q := ring[i]
			ins.append(Vector3(q.x, q.y, z))
		outer.append(o)
		inner.append(ins)
		if k == 0:
			tip = Vector3(0.0, (float(s[1]) + float(s[2])) * 0.5, z)
		tail = Vector3(0.0, (float(s[1]) + float(s[2])) * 0.5, z)
	m.grid("paint", outer, false, func(c: Vector3, r: int, _c: int) -> Vector3:
		var s: Array = rows[r]
		return c - Vector3(0.0, (float(s[1]) + float(s[2])) * 0.5, c.z))
	m.grid("cockpit", inner, false, func(c: Vector3, r: int, _c: int) -> Vector3:
		var s: Array = rows[r]
		return Vector3(0.0, float(s[2]), c.z) - c)
	# the nose tip and the tail: small caps
	var first := PackedVector3Array()
	var last := PackedVector3Array()
	var r0 := _tub_ring(rows[0])
	var r1 := _tub_ring(rows[rows.size() - 1])
	for q in r0:
		first.append(Vector3(q.x, q.y, float(rows[0][0])))
	for q in r1:
		last.append(Vector3(q.x, q.y, float(rows[rows.size() - 1][0])))
	m.fan("paint", first, tip + Vector3(0, 0, 0.004), Vector3(0, 0, 1))
	m.fan("paint", last, tail, Vector3(0, 0, -1))
	# the roll hoop behind the head, its opening the engine's intake (dark), and a glass strip
	# down the engine cover's flat top
	var path := []
	for k in 13:
		var t := float(k) / 12.0
		var a := lerpf(PI, 0.0, t)
		path.append(Vector2(cos(a) * 0.115, 0.775 + sin(a) * 0.20))
	var hoop := []
	for k in path.size():
		var q: Vector2 = path[k]
		var q0: Vector2 = path[maxi(k - 1, 0)]
		var q1: Vector2 = path[mini(k + 1, path.size() - 1)]
		var tan2 := (q1 - q0).normalized()
		var nrm := Vector2(tan2.y, -tan2.x)          # outward from the hoop's middle
		var ring := PackedVector3Array()
		for c in TmMesher.rounded([Vector2(-0.02, -0.045), Vector2(0.02, -0.045), Vector2(0.02, 0.045), Vector2(-0.02, 0.045)],
				[0.012, 0.012, 0.012, 0.012], 3, 0):
			var p2 := q + nrm * c.x
			ring.append(Vector3(p2.x, p2.y, -0.50 + c.y))
		hoop.append(ring)
	m.loft("carbon", hoop, true, true, true)
	var mouth := PackedVector3Array()
	for k in path.size():
		var q: Vector2 = path[k]
		mouth.append(Vector3(q.x * 0.84, 0.775 + (q.y - 0.775) * 0.86, -0.53))
	m.fan("inlet", mouth, Vector3(0.0, 0.80, -0.53), Vector3(0, 0, 1))
	var strip := []
	for k in 9:
		var z := lerpf(-0.62, -1.42, float(k) / 8.0)
		var yt := _top_at(z) + 0.004
		var ring := PackedVector3Array()
		for j in 5:
			var x := lerpf(-0.13, 0.13, float(j) / 4.0)
			ring.append(Vector3(x, yt - 0.25 * x * x, z))
		strip.append(ring)
	m.grid("glass_dark", strip, false, func(_c: Vector3, _r: int, _cc: int) -> Vector3: return Vector3.UP)
	m.extrude("white", [Vector2(-1.00, 0.85), Vector2(-1.08, 0.93), Vector2(-1.42, 0.89), Vector2(-1.56, 0.74),
		Vector2(-1.46, 0.72), Vector2(-1.20, 0.80)], "x", -0.005, 0.005)
	# rain light at the tail
	m.extrude("light", [Vector2(-1.819, 0.455), Vector2(-1.819, 0.525), Vector2(-1.828, 0.525), Vector2(-1.828, 0.455)],
		"x", -0.045, 0.045)


## The tub's top (y) at z, from the stations (linear between them: for small parts on top).
static func _top_at(z: float) -> float:
	for i in TUB.size() - 1:
		var a: Array = TUB[i]
		var b: Array = TUB[i + 1]
		if z <= float(a[0]) and z >= float(b[0]):
			return lerpf(float(a[2]), float(b[2]), (float(a[0]) - z) / (float(a[0]) - float(b[0])))
	return float(TUB[TUB.size() - 1][2])


## The +x sidepod: undercut sections, a dark inlet at the front.
static func _pods(m: TmMesher) -> void:
	var rows := TmMesher.resample(POD, 5)
	var rings := []
	for s: Array in rows:
		var z: float = s[0]
		var xi: float = s[1]
		var xo: float = s[2]
		var yb: float = s[3]
		var yt: float = s[4]
		var uc: float = s[5]
		var poly := [Vector2(xi, yb), Vector2(xo - uc, yb), Vector2(xo, yb + (yt - yb) * 0.45),
			Vector2(xo - 0.015, yt), Vector2(xi, yt)]
		var ring := PackedVector3Array()
		# the first span leans forward with height, so the inlet's face is raked
		var lean := POD_RAKE * maxf(0.0, 1.0 - (float(POD[0][0]) - z) / 0.16)
		for q in TmMesher.rounded(poly, [0.0, s[6], 0.03, s[7], 0.0], ARC, 2):
			ring.append(Vector3(q.x, q.y, z + lean * (q.y - yb) / (yt - yb) - lean * 0.5))
		rings.append(ring)
	m.loft("paint", rings, true, false, true)
	# the inlet: a dark face just inside the front ring, framed by a lip
	var front: PackedVector3Array = rings[0]
	var c := Vector3.ZERO
	for q in front:
		c += q
	c /= front.size()
	var inset := PackedVector3Array()
	var lip := PackedVector3Array()
	for q in front:
		inset.append(c + (q - c) * 0.84 + Vector3(0, 0, -0.06))
		lip.append(q)
	m.grid("paint", [lip, inset], true, func(_p: Vector3, _r: int, _c: int) -> Vector3: return Vector3(0, 0, 1))
	m.fan("inlet", inset, c + Vector3(0, 0, -0.06), Vector3(0, 0, 1))


## Wings: a cambered section extruded across. The +x end plates go to `half`.
static func _airfoil(chord: float, thick: float, camber: float, le: Vector2, pitch: float) -> Array:
	# (z, y) points around the section, leading edge at `le`, trailing edge towards -z
	var up := []
	var lo := []
	var n := 12
	for k in n + 1:
		var x := (1.0 - cos(PI * k / n)) * 0.5          # cosine spacing
		var yt := 5.0 * thick * (0.2969 * sqrt(x) - 0.126 * x - 0.3516 * x * x + 0.2843 * x * x * x - 0.1036 * x * x * x * x)
		var yc := camber * 4.0 * x * (1.0 - x)
		up.append(Vector2(x, yc + yt))
		lo.append(Vector2(x, yc - yt))
	var pts := []
	for q: Vector2 in up:
		pts.append(q)
	for k in range(lo.size() - 2, 0, -1):
		pts.append(lo[k])
	var out := []
	for q: Vector2 in pts:
		var r := Vector2(-q.x * chord, q.y * chord).rotated(pitch)
		out.append(le + r)
	return out


static func _wing(m: TmMesher, key: String, section: Array, x0: float, x1: float) -> void:
	var rows := []
	for x: float in [x0, x1]:
		var ring := PackedVector3Array()
		for q: Vector2 in section:
			ring.append(Vector3(x, q.y, q.x))
		rows.append(ring)
	m.loft(key, rows, true, true, true)


static func _wings(m: TmMesher, half: TmMesher) -> void:
	# front: a main plane and a flap under the nose, between the front tyres
	_wing(m, "carbon", _airfoil(0.22, 0.10, -0.06, Vector2(2.12, 0.118), -0.10), -0.62, 0.62)
	_wing(m, "paint", _airfoil(0.11, 0.12, -0.08, Vector2(1.93, 0.150), -0.42), -0.60, 0.60)
	half.extrude("paint", TmMesher.rounded([Vector2(2.16, 0.10), Vector2(2.16, 0.215), Vector2(1.94, 0.25),
		Vector2(1.80, 0.20), Vector2(1.80, 0.10)], [0.02, 0.04, 0.04, 0.03, 0.01], 3, 0), "x", 0.62, 0.635)
	# rear: two elements over the tail, a pylon from the gearbox, end plates
	_wing(m, "carbon", _airfoil(0.24, 0.11, -0.05, Vector2(-1.58, 0.835), -0.12), -0.58, 0.58)
	_wing(m, "paint", _airfoil(0.13, 0.12, -0.06, Vector2(-1.70, 0.912), -0.45), -0.57, 0.57)
	m.extrude("carbon", [Vector2(-1.62, 0.58), Vector2(-1.67, 0.84), Vector2(-1.76, 0.84), Vector2(-1.80, 0.58)],
		"x", -0.012, 0.012)
	half.extrude("paint", TmMesher.rounded([Vector2(-1.48, 0.62), Vector2(-1.48, 0.88), Vector2(-1.62, 0.99),
		Vector2(-1.86, 0.98), Vector2(-1.86, 0.66), Vector2(-1.70, 0.58)], [0.03, 0.05, 0.05, 0.03, 0.04, 0.04], 3, 0),
		"x", 0.58, 0.596)


static func _floor(m: TmMesher) -> void:
	var outline := [Vector2(0.0, 1.30), Vector2(0.26, 1.25), Vector2(0.60, 0.95), Vector2(0.78, 0.80),
		Vector2(0.78, -0.85), Vector2(0.66, -1.00), Vector2(0.62, -1.55), Vector2(0.45, -1.75),
		Vector2(0.18, -1.80)]
	var poly := []
	for q: Vector2 in outline:
		poly.append(q)
	for k in range(outline.size() - 1, 0, -1):
		var q: Vector2 = outline[k]
		poly.append(Vector2(-q.x, q.y))
	m.extrude("carbon", poly, "y", 0.098, 0.124)


static func _cockpit(m: TmMesher, half: TmMesher) -> void:
	# windscreen: a curved strip ahead of the opening
	var rows := []
	for k in 4:
		var t := float(k) / 3.0
		var z := lerpf(0.50, 0.375, t)
		var y := lerpf(0.705, 0.79, t)
		var ring := PackedVector3Array()
		for j in 9:
			var u := lerpf(-1.0, 1.0, float(j) / 8.0)
			ring.append(Vector3(u * lerpf(0.20, 0.17, t), y - 0.03 * u * u, z))
		rows.append(ring)
	m.grid("glass", rows, false, func(_c: Vector3, _r: int, _cc: int) -> Vector3: return Vector3(0, 0.4, 1))
	# steering wheel, facing the driver
	var sw := TmMesher.rounded([Vector2(-0.12, -0.05), Vector2(0.12, -0.05), Vector2(0.13, 0.04),
		Vector2(0.06, 0.07), Vector2(-0.06, 0.07), Vector2(-0.13, 0.04)], [0.03, 0.03, 0.03, 0.02, 0.02, 0.03], 3, 0)
	var swp := []
	for q in sw:
		swp.append(q)
	var wheel := TmMesher.new()
	wheel.extrude("carbon", swp, "z", -0.012, 0.012)
	var b := Basis(Vector3.RIGHT, deg_to_rad(-25.0))
	for key: String in wheel.parts:
		var p: TmMesher.Part = wheel.parts[key]
		var d := m.part(key)
		var base := d.v.size()
		for i in p.v.size():
			d.v.append(b * p.v[i] + STEER_WHEEL + m.offset)
			d.n.append(b * p.n[i])
		for i in p.idx:
			d.idx.append(base + i)
	# mirrors on stalks
	var pod := []
	for k in 5:
		var t := float(k) / 4.0
		var z := lerpf(0.36, 0.26, t)
		var s := sin(t * PI) * 0.9 + 0.1
		var ring := PackedVector3Array()
		for j in 10:
			var a := TAU * j / 10.0
			ring.append(Vector3(0.40 + cos(a) * 0.055 * s, 0.765 + sin(a) * 0.03 * s, z))
		pod.append(ring)
	half.loft("paint", pod, true)
	var glass := PackedVector3Array()
	for j in 10:
		var a := TAU * j / 10.0
		glass.append(Vector3(0.40 + cos(a) * 0.046, 0.765 + sin(a) * 0.024, 0.285))
	half.fan("mirror", glass, Vector3(0.40, 0.765, 0.284), Vector3(0, 0, -1))
	half.extrude("carbon", [Vector2(0.31, 0.74), Vector2(0.32, 0.748), Vector2(0.30, 0.66), Vector2(0.29, 0.66)],
		"x", 0.27, 0.36)


static func _sphere_patch(m: TmMesher, key: String, c: Vector3, r: float, lat0: float, lat1: float,
		lon0: float, lon1: float, nlat: int, nlon: int, scale := Vector3.ONE) -> void:
	# lat: up from the horizontal; lon: around y from +z towards +x (degrees)
	var rows := []
	for i in nlat + 1:
		var la := deg_to_rad(lerpf(lat0, lat1, float(i) / nlat))
		var ring := PackedVector3Array()
		for j in nlon + 1:
			var lo := deg_to_rad(lerpf(lon0, lon1, float(j) / nlon))
			ring.append(c + Vector3(sin(lo) * cos(la), sin(la), cos(lo) * cos(la)) * r * scale)
		rows.append(ring)
	m.grid(key, rows, false, func(p: Vector3, _r: int, _c: int) -> Vector3: return p - c)


static func _driver(m: TmMesher, half: TmMesher) -> void:
	var hs := Vector3(0.94, 1.0, 1.1)
	_sphere_patch(m, "white", HELMET, HELMET_R, -60.0, 90.0, -180.0, 180.0, 14, 28, hs)
	# the visor, a stripe over the top, the chin's opening dark
	_sphere_patch(m, "visor", HELMET, HELMET_R * 1.012, -12.0, 20.0, -62.0, 62.0, 6, 14, hs)
	_sphere_patch(m, "paint_plain", HELMET, HELMET_R * 1.008, 28.0, 89.0, -14.0, 14.0, 6, 4, hs)
	_sphere_patch(m, "paint_plain", HELMET, HELMET_R * 1.008, -30.0, 28.0, 166.0, 194.0, 6, 4, hs)
	# collar and shoulders (mostly inside the cockpit), arms to the wheel
	var collar := []
	for y: float in [0.70, 0.765]:
		var ring := PackedVector3Array()
		for j in 14:
			var a := TAU * j / 14.0
			ring.append(Vector3(cos(a) * 0.085, y, -0.25 + sin(a) * 0.09))
		collar.append(ring)
	m.loft("suit", collar, true, false, true)
	var shoulders := []
	for k in 7:
		var x := lerpf(-0.21, 0.21, float(k) / 6.0)
		var s := sqrt(maxf(1.0 - pow(x / 0.23, 6.0), 0.05))
		var ring := PackedVector3Array()
		for j in 12:
			var a := TAU * j / 12.0
			ring.append(Vector3(x, 0.625 + sin(a) * 0.085 * s, -0.24 + cos(a) * 0.11 * s))
		shoulders.append(ring)
	m.loft("suit", shoulders, true, true, true)
	var arm := []
	var sh := Vector3(0.18, 0.66, -0.20)
	var el := Vector3(0.18, 0.60, -0.01)
	var hand := STEER_WHEEL + Vector3(0.11, 0.0, -0.01)
	for pts: Array in [[sh, el], [el, hand]]:
		var a: Vector3 = pts[0]
		var bb: Vector3 = pts[1]
		var d := (bb - a).normalized()
		var x := d.cross(Vector3.UP).normalized()
		var y := x.cross(d)
		var rows := []
		for p: Vector3 in [a, bb]:
			var ring := PackedVector3Array()
			for j in 8:
				var an := TAU * j / 8.0
				ring.append(p + (x * cos(an) + y * sin(an)) * 0.04)
			rows.append(ring)
		half.loft("suit", rows, true, true, true)
	_sphere_patch(half, "carbon", hand, 0.04, -90.0, 90.0, -180.0, 180.0, 6, 8)


# --- wheels -------------------------------------------------------------------------------------

## The tyre (lathed, its bead under the rim's flange), the rim (flange, dish, barrel), five twin
## spokes, hub, nut and the ventilated disc: everything that spins. Built for a +x (left) wheel.
static func _wheel(m: TmMesher, hw: float) -> void:
	var b := hw - 0.016                 # the bead's x, both sides
	var half := [Vector2(b, BEAD_R), Vector2(hw - 0.005, 0.255), Vector2(hw, 0.287), Vector2(hw - 0.002, 0.315),
		Vector2(hw - 0.012, 0.338), Vector2(hw - 0.030, 0.356), Vector2(hw - 0.058, TYRE_R - 0.001),
		Vector2(hw * 0.5, TYRE_R), Vector2(0.0, TYRE_R + 0.001)]
	# from the inner bead over the tread to the outer bead
	var tyre := []
	for k in range(half.size() - 1, -1, -1):
		var q: Vector2 = half[k]
		tyre.append(Vector2(-q.x, q.y))
	tyre.reverse()
	var full := []
	for q: Vector2 in tyre:
		full.append(q)
	for k in range(half.size() - 2, -1, -1):
		full.append(half[k])
	m.revolve("tyre", full, 64, 1.0)
	# the rim's face: the flange over the bead, its lip, down into the dish
	var face := [Vector2(b - 0.008, 0.238), Vector2(b + 0.003, 0.249), Vector2(b + 0.010, 0.247),
		Vector2(b + 0.013, 0.240), Vector2(b + 0.008, 0.231), Vector2(b - 0.010, 0.223),
		Vector2(b - 0.035, 0.215), Vector2(b - 0.060, 0.209)]
	m.revolve("rim", face, 64, 1.0)
	# the barrel behind the spokes, and the inner flange
	var barrel := [Vector2(b - 0.060, 0.209), Vector2(-hw + 0.03, 0.207), Vector2(-b - 0.004, 0.226),
		Vector2(-b + 0.004, 0.245)]
	m.revolve("rim_dark", barrel, 48, 1.0)
	# five broad spokes, widening into the rim, from a large hub
	for k in 5:
		_spoke(m, TAU * k / 5.0, TAU * k / 5.0, b)
	m.revolve("rim", [Vector2(b - 0.045, 0.082), Vector2(b - 0.018, 0.082), Vector2(b - 0.010, 0.074),
		Vector2(b - 0.008, 0.050), Vector2(b - 0.010, 0.034)], 30, 1.0)
	for k in 5:     # wheel studs around the nut
		var a := TAU * (k + 0.5) / 5.0
		var cy := cos(a) * 0.058
		var cz := sin(a) * 0.058
		m.extrude("rim_dark", [Vector2(cz - 0.007, cy - 0.007), Vector2(cz + 0.007, cy - 0.007),
			Vector2(cz + 0.007, cy + 0.007), Vector2(cz - 0.007, cy + 0.007)], "x", b - 0.012, b - 0.001)
	m.revolve("caliper", [Vector2(b - 0.012, 0.034), Vector2(b + 0.006, 0.032), Vector2(b + 0.010, 0.022),
		Vector2(b + 0.010, 0.0)], 6, 1.0)
	# the disc: a ventilated ring inside the barrel
	m.revolve("disc", [Vector2(-0.040, 0.108), Vector2(-0.040, 0.178), Vector2(-0.004, 0.178),
		Vector2(-0.004, 0.108), Vector2(-0.040, 0.108)], 40, 1.0)


static func _spoke(m: TmMesher, a_hub: float, a_rim: float, b: float) -> void:
	var h := Vector3(b - 0.022, 0.0, 0.0)
	var r_hub := 0.060
	var r_rim := 0.212
	var x_rim := b - 0.052
	var pts := []
	for end in [[a_hub, r_hub + 0.02, h.x, 0.040], [a_rim, r_rim, x_rim, 0.072]]:
		var a: float = end[0]
		var r: float = end[1]
		var x: float = end[2]
		var w: float = end[3]
		var radial := Vector3(0.0, cos(a), sin(a))
		var tang := Vector3(0.0, -sin(a), cos(a))
		var c := Vector3(x, 0.0, 0.0) + radial * r
		pts.append([c + tang * w * 0.5 + Vector3(0.013, 0, 0), c - tang * w * 0.5 + Vector3(0.013, 0, 0),
			c - tang * w * 0.5 - Vector3(0.013, 0, 0), c + tang * w * 0.5 - Vector3(0.013, 0, 0)])
	var r0 := PackedVector3Array(pts[0])
	var r1 := PackedVector3Array(pts[1])
	# flat faces: each side its own pair of rows
	var p := m.part("rim")
	var c0 := Vector3.ZERO
	for q in r0:
		c0 += q
	var c1 := Vector3.ZERO
	for q in r1:
		c1 += q
	var mid := (c0 + c1) * 0.125
	for i in 4:
		var j := (i + 1) % 4
		var quad := [r0[i], r0[j], r1[j], r1[i]]
		var fn: Vector3 = ((quad[1] as Vector3) - (quad[0] as Vector3)).cross((quad[3] as Vector3) - (quad[0] as Vector3))
		var fc: Vector3 = ((quad[0] as Vector3) + (quad[1] as Vector3) + (quad[2] as Vector3) + (quad[3] as Vector3)) * 0.25
		if fn.dot(fc - mid) < 0.0:
			fn = -fn
		fn = fn.normalized()
		var base := p.v.size()
		for q: Vector3 in quad:
			p.v.append(q)
			p.n.append(fn)
		p.tri(base, base + 1, base + 2, fn)
		p.tri(base, base + 2, base + 3, fn)


## What steers with the wheel but doesn't spin: the caliper, the upright, the front guard (on its
## bracket) or the rear guard (guard: false, none). +x (left) wheel.
static func _hub(m: TmMesher, hw: float, front: bool, guard := true) -> void:
	# caliper over the disc, at the top towards the back
	m.revolve("caliper", [Vector2(-0.052, 0.150), Vector2(-0.052, 0.198), Vector2(0.010, 0.198),
		Vector2(0.010, 0.150), Vector2(-0.052, 0.150)], 8, 1.0, deg_to_rad(-50.0), deg_to_rad(-10.0), Vector3.ZERO, true)
	m.extrude("carbon", [Vector2(-0.06, -0.13), Vector2(0.06, -0.13), Vector2(0.05, 0.15), Vector2(-0.05, 0.15)],
		"x", -0.135, -0.075)
	if not guard:
		return
	# the guard: a shell over the tyre, its edges rolled
	var r_in := TYRE_R + (0.032 if front else 0.040)
	var x0 := -hw + 0.01 if front else -hw - 0.06
	var x1 := hw * (0.55 if front else 0.50)
	var a0 := deg_to_rad(38.0 if front else 4.0)
	var a1 := deg_to_rad(138.0 if front else 145.0)
	var sec := TmMesher.rounded([Vector2(x0, 0.0), Vector2(x1, 0.0), Vector2(x1, 0.013), Vector2(x0, 0.013)],
		[0.006, 0.006, 0.006, 0.006], 3, 2)
	var rows := []
	var steps := 24
	for k in steps + 1:
		var a := lerpf(a0, a1, float(k) / steps)
		# from ahead (+z) over the top to behind
		var radial := Vector3(0.0, sin(a), cos(a))
		var ring := PackedVector3Array()
		for q in sec:
			ring.append(Vector3(q.x, 0.0, 0.0) + radial * (r_in + q.y))
		rows.append(ring)
	m.loft("paint_plain", rows, true, true, true)
	# the guard's bracket down to the upright, just inside the tyre
	var bx := -hw + 0.012 if front else -hw - 0.05
	m.extrude("carbon", [Vector2(-0.05, 0.02), Vector2(0.05, 0.02), Vector2(0.03, r_in + 0.01), Vector2(-0.04, r_in + 0.01)],
		"x", bx - 0.012, bx + 0.004)
