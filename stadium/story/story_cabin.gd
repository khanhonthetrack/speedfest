class_name StoryCabin
extends Node3D
## A car's inside for the cutscenes (PLAN M20-3): our road cars are bodies and glass, so a shot from
## the driver's seat or in the rear-view mirror needs seats, a dash and a headlining. At night, seen
## past a shoulder or in a mirror, simple shapes in dark leather are enough: two front seats, a rear
## bench, the dash with its glow, the satnav's screen (StorySatnav) and the rear-view mirror (its
## housing and glass: StoryScene shows on the glass what the driver would see in it).
## Built in the car's road frame (x left, y up, z ahead, the road under the wheels at y = 0) from
## its manifest (TmRoadCars.manifest: wheels, box, and the body's lines along it, "anchors"), so it
## fits any of the sixteen under its own roof; fit_car() lines the body itself from inside.

const LEATHER := Color(0.045, 0.045, 0.05)
const FLOOR_Y := 0.24
## A seated person's crown over their root, and how far behind it (m): the library's Sitting and
## Driving clips hold the pelvis 0.54 m over the feet and 0.33 m behind them, the head bone at
## 1.17 m, the 1.83 m mannequin's skull 0.26 m over that bone (measured in Godot: tests/tmp/crown_probe)
## (the layout's; seated people are measured in their own clips, StoryCast.seated: a cast member sits
## where the Mannequin's seat rests, and anyone whose crown would come within 5 cm of the roof goes
## down with the seat, StoryScene)
const CROWN := Vector2(1.43, -0.11)

var satnav: MeshInstance3D
var mirror_glass: MeshInstance3D   ## the rear-view mirror's glass (StoryScene shows a reflection on it)
var mirror_normal := Vector3.BACK  ## the glass's facing (road frame): halfway between the driver's eyes and the rear window
const GLASS := Vector2(0.26, 0.075)  ## the glass's size (m)
const MIRROR_LAYER := 19             ## the mirror's own render layer: its camera leaves it out
var mirror_point := Vector3.ZERO   ## the rear-view mirror's place (road frame)
var driver_head := Vector3.ZERO    ## the driver's eyes
var rear_seat := Vector3.ZERO      ## the rear bench's middle, where a passenger sits (hips)
var _seats := {}                   ## "driver" / "passenger" / "rear" -> its cushion, back (and headrest)
var _drops := {}                   ## a seat -> how far it was lowered (lower)


## Where people sit and look from in a car (road frame): "driver" / "passenger" (feet on the floor,
## seated), "rear" (the bench's middle), "driver_head" (the driver's eyes: a shot from the seat),
## "mirror" (the rear-view mirror's glass: a mirror shot's camera).
static func points(model: String) -> Dictionary:
	return _layout(TmRoadCars.manifest(model))


## Which seat a place in the car is on (road frame): the rear bench, or the front seat on its side.
static func seat_at(model: String, p: Vector3) -> String:
	var pts := points(model)
	if absf(p.z - (pts["rear"] as Vector3).z) < absf(p.z - (pts["driver"] as Vector3).z):
		return "rear"
	return "driver" if p.x >= 0.0 else "passenger"


## How far a seated person's crown at p (road frame) is under the roof's line less 5 cm, the room
## the layout leaves the Mannequin (negative: into it).
static func headroom(model: String, p: Vector3) -> float:
	return line(TmRoadCars.manifest(model), "top", p.z) - 0.05 - p.y


## dome: the courtesy light over the rear bench (0: off), cold white; it lights a passenger.
static func make(model: String, red_pins := 0, dome := 0.0) -> StoryCabin:
	var c := StoryCabin.new()
	var m := TmRoadCars.manifest(model)
	c._build(m, red_pins)
	if dome > 0.0:
		var l := OmniLight3D.new()
		l.name = "Dome"
		l.light_color = Color(0.78, 0.86, 1.0)
		l.light_energy = dome
		l.omni_range = 2.2
		l.omni_attenuation = 1.6
		var z := (_layout(m)["rear"] as Vector3).z + 0.03      # in the headlining just ahead of the face: lit from above
		l.position = Vector3(0.0, line(m, "top", z) - 0.06, z)
		c.add_child(l)
	return c


## The body's line `key` along the car at z (road frame): "top" (the roof's crown), "belt" (the
## window line), "hw" (half the body's width), from the manifest's anchors; a car without them
## (the hypercar) gets its box.
static func line(m: Dictionary, key: String, z: float) -> float:
	var an: Dictionary = m.get("anchors", {})
	var zs: Array = an.get("z", [])
	var vs: Array = an.get(key, [])
	if zs.size() < 2 or vs.size() != zs.size():
		var box: Array = m.get("box", [[-0.97, 0.11, -2.03], [0.97, 1.32, 2.5]])
		return {"top": float(box[1][1]), "belt": float(box[1][1]) * 0.7, "hw": float(box[1][0])}.get(key, 0.0)
	# the anchors run nose to tail (z falling)
	if z >= float(zs[0]):
		return float(vs[0])
	for i in range(1, zs.size()):
		if z >= float(zs[i]):
			var f := (z - float(zs[i])) / (float(zs[i - 1]) - float(zs[i]))
			return lerpf(float(vs[i]), float(vs[i - 1]), f)
	return float(vs[vs.size() - 1])


static func _layout(m: Dictionary) -> Dictionary:
	var wheels: Array = m.get("wheels", [[0.77, 0.31, 1.65], [-0.77, 0.31, 1.65], [0.78, 0.32, -1.07], [-0.78, 0.32, -1.07]])
	var rear_axle := float(wheels[2][2])
	var wheelbase := float(wheels[0][2]) - rear_axle
	var front_z := rear_axle + wheelbase * 0.42       # the front seats' cushions
	var rear_z := rear_axle + wheelbase * 0.2         # the rear bench, under the roof's crown still
	# a seated person's root (CROWN): a sports car's seat is low, so the root sits under the road's
	# level, the feet tucked under the dash, the pelvis on the back of the cushion, the crown at least
	# 5 cm under the roof (lower still under a supercar's); the rear bench under the coupe's falling roof
	var dz := front_z + 0.18
	var dy := minf(-0.16, line(m, "top", dz + CROWN.y) - 0.05 - CROWN.x)
	var rz := rear_z + 0.18
	var ry := minf(-0.18, line(m, "top", rz + CROWN.y) - 0.05 - CROWN.x)
	# the mirror on the windscreen 0.42 m ahead of the driver's eyes, hung under the glass, or nearer
	# (not under 0.3 m) where a raked screen would bring it down to the eyes
	var eyes := Vector3(0.37, dy + 1.25, front_z + 0.1)
	var mz := eyes.z + 0.42
	while mz - 0.02 >= eyes.z + 0.3 and line(m, "top", mz) - 0.11 < eyes.y + 0.04:
		mz -= 0.02
	return {"driver": Vector3(0.37, dy, dz), "passenger": Vector3(-0.37, dy, dz), "rear": Vector3(0.0, ry, rz),
		"driver_head": eyes, "mirror": Vector3(0.0, line(m, "top", mz) - 0.11, mz)}


func _build(m: Dictionary, red_pins: int) -> void:
	var pts := _layout(m)
	var wheels: Array = m.get("wheels", [[0.77, 0.31, 1.65], [-0.77, 0.31, 1.65], [0.78, 0.32, -1.07], [-0.78, 0.32, -1.07]])
	var rear_axle := float(wheels[2][2])
	var wheelbase := float(wheels[0][2]) - rear_axle
	var half := line(m, "hw", rear_axle + wheelbase * 0.5) - 0.16
	var front_z := rear_axle + wheelbase * 0.42
	var rear_z := rear_axle + wheelbase * 0.2
	var hip := (pts["driver"] as Vector3).y + 0.42         # the front cushions' middle, under the seated
	var rear_hip := (pts["rear"] as Vector3).y + 0.42
	var leather := StandardMaterial3D.new()
	leather.albedo_color = LEATHER
	leather.roughness = 0.55
	leather.metallic_specular = 0.4
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.02, 0.02, 0.025)
	trim.roughness = 0.8
	for side: float in [1.0, -1.0]:
		var x := 0.37 * side
		_seats["driver" if side > 0.0 else "passenger"] = [
			_box(Vector3(x, hip, front_z), Vector3(0.5, 0.12, 0.52), leather),                       # cushion
			_box(Vector3(x, hip + 0.31, front_z - 0.3), Vector3(0.48, 0.56, 0.12), leather, -12.0),    # back
			_box(Vector3(x, hip + 0.68, front_z - 0.35), Vector3(0.24, 0.16, 0.1), leather, -8.0)]     # headrest
	_seats["rear"] = [_box(Vector3(0.0, rear_hip, rear_z), Vector3(half * 2.0 - 0.2, 0.12, 0.46), leather),
		_box(Vector3(0.0, rear_hip + 0.3, rear_z - 0.28), Vector3(half * 2.0 - 0.2, 0.54, 0.12), leather, -18.0)]
	_box(Vector3(0.0, FLOOR_Y, (front_z + rear_z) * 0.5), Vector3(half * 2.0, 0.04, wheelbase * 0.9), trim)
	var dash_z := front_z + 0.85
	_box(Vector3(0.0, hip + 0.42, dash_z), Vector3(half * 2.0, 0.22, 0.4), trim)
	# the steering wheel, a hand's reach ahead of the driver's chest, a third of a metre under the eyes
	var wheel := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.165
	ring.outer_radius = 0.19
	ring.rings = 32
	wheel.mesh = ring
	wheel.material_override = leather
	wheel.position = Vector3(0.37, (pts["driver_head"] as Vector3).y - 0.33, front_z + 0.42)
	wheel.rotation = Vector3(deg_to_rad(70.0), 0.0, 0.0)          # its axis up the column to the driver
	add_child(wheel)
	(_seats["driver"] as Array).append(wheel)                     # a lowered seat takes the wheel down too
	var hub := MeshInstance3D.new()
	var boss := CylinderMesh.new()
	boss.top_radius = 0.05
	boss.bottom_radius = 0.06
	boss.height = 0.08
	hub.mesh = boss
	hub.material_override = trim
	wheel.add_child(hub)
	# behind the bench: a bulkhead up to the parcel shelf, the shelf under the rear window, so a look
	# back shows the window and what follows, not the boot (the body itself is lined by fit_car)
	var shelf_z := rear_z - 0.62
	var shelf_y := minf(line(m, "belt", shelf_z) + 0.03, line(m, "top", shelf_z - 0.25) - 0.06)
	_box(Vector3(0.0, (FLOOR_Y + shelf_y) * 0.5, rear_z - 0.4), Vector3(half * 2.0, shelf_y - FLOOR_Y, 0.04), trim)
	_box(Vector3(0.0, shelf_y, shelf_z), Vector3(half * 2.0, 0.03, 0.44), trim)
	# the dash's glow: a faint cyan line and the satnav's violet
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.25, 0.75, 1.0)
	_box(Vector3(0.37, hip + 0.54, dash_z - 0.2), Vector3(0.22, 0.012, 0.01), glow)
	satnav = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.24, 0.15)
	satnav.mesh = q
	var view := StorySatnav.view(red_pins)
	add_child(view)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_texture = view.get_texture()
	sm.emission_enabled = true
	sm.emission_texture = sm.albedo_texture
	sm.emission_energy_multiplier = 1.4
	satnav.material_override = sm
	satnav.position = Vector3(0.0, hip + 0.62, dash_z - 0.22)
	satnav.rotation = Vector3(deg_to_rad(-15.0), PI, 0.0)     # facing the seats (a quad faces +z)
	add_child(satnav)
	# its bezel: dark satin plastic a little proud of the screen all round, behind it
	var bezel_mat := StandardMaterial3D.new()
	bezel_mat.albedo_color = Color(0.03, 0.03, 0.033)
	bezel_mat.roughness = 0.55
	var bezel := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(q.size.x + 0.022, q.size.y + 0.02, 0.022)
	bezel.mesh = bb
	bezel.material_override = bezel_mat
	bezel.transform = satnav.transform * Transform3D(Basis(), Vector3(0.0, 0.0, -0.0115))
	add_child(bezel)
	var screen_light := OmniLight3D.new()
	screen_light.light_color = Color(0.55, 0.4, 1.0)
	screen_light.light_energy = 0.35
	screen_light.omni_range = 0.9
	screen_light.shadow_enabled = false
	screen_light.position = satnav.position + Vector3(0.0, 0.0, -0.15)
	add_child(screen_light)
	mirror_point = pts["mirror"]
	# the glass turned so the driver sees the rear window in it (it faces halfway between the two)
	var rear_window := Vector3(0.0, (shelf_y + line(m, "top", shelf_z)) * 0.5, shelf_z)
	mirror_normal = (((pts["driver_head"] as Vector3) - mirror_point).normalized() + (rear_window - mirror_point).normalized()).normalized()
	mirror_glass = MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = GLASS
	mirror_glass.mesh = gq
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.05, 0.055, 0.06)
	gm.metallic = 1.0
	gm.roughness = 0.08
	mirror_glass.material_override = gm
	mirror_glass.position = mirror_point
	mirror_glass.basis = Basis.looking_at(-mirror_normal, Vector3.UP)     # a quad faces +z
	mirror_glass.layers = 1 << (MIRROR_LAYER - 1)
	add_child(mirror_glass)
	# its housing behind it, turned with it, and the stem up to the headlining
	var housing := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(GLASS.x + 0.02, GLASS.y + 0.016, 0.03)
	housing.mesh = hb
	housing.material_override = trim
	housing.position = Vector3(0.0, 0.0, -0.016)
	housing.layers = 1 << (MIRROR_LAYER - 1)
	mirror_glass.add_child(housing)
	var roof := line(m, "top", mirror_point.z) - 0.03
	_box(Vector3(0.0, (mirror_point.y + roof) * 0.5 + 0.02, mirror_point.z + 0.02), Vector3(0.025, maxf(0.02, roof - mirror_point.y - 0.02), 0.025), trim)
	driver_head = pts["driver_head"]
	rear_seat = pts["rear"]


## Lowers a seat (its cushion, back and headrest; the driver's the wheel too) to `by` under where it
## was built: a tall sitter's crown would meet a low car's roof (StoryScene sinks its sitters as far;
## the "driver_head" and "mirror" points stay the layout's).
func lower(seat: String, by: float) -> void:
	var d := by - float(_drops.get(seat, 0.0))
	_drops[seat] = by
	for n: Node3D in _seats.get(seat, []):
		n.position.y -= d


## Readies a car for shots from inside: its glass tinted but clear (the game's road glass is dark
## and mirror-like: right from outside, blind from inside), so a mirror shot sees out of the rear
## window and a shot from outside sees who sits inside; and its body lined from inside (the body's
## faces are one-sided, so from the seats the roof and doors are not there): the same surfaces
## again in dark trim drawn from behind only, so the lining follows the body exactly and is never
## seen from outside; glass left out, and every face just behind it (the paint runs on under the
## windscreen and the rear window, the glass laid over it).
static func fit_car(car: TmCarVisual) -> void:
	if _clear_glass == null:
		_clear_glass = StandardMaterial3D.new()
		_clear_glass.albedo_color = Color(0.03, 0.035, 0.045, 0.32)
		_clear_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_clear_glass.roughness = 0.03
		_clear_glass.metallic = 0.3
		_lining = StandardMaterial3D.new()
		_lining.albedo_color = Color(0.03, 0.03, 0.034)
		_lining.roughness = 0.85
	var glass: Material = car._mats.get("road_glass", null)
	if glass == null:
		return
	for mi: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var glass_k: Array[int] = []
		var lined_k: Array[int] = []
		for k in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(k)
			if mat == glass:
				mi.set_surface_override_material(k, _clear_glass)
				glass_k.append(k)
			elif not (mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
				lined_k.append(k)
		if glass_k.is_empty() or lined_k.is_empty():
			continue
		if not _linings.has(mi.mesh):
			_linings[mi.mesh] = _line(mi.mesh, glass_k, lined_k)
		var lining := MeshInstance3D.new()
		lining.name = "Lining"
		lining.mesh = _linings[mi.mesh]
		lining.material_override = _lining
		lining.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(lining)


## Winds a fitted car's front side windows down: sides {"driver" (+x, the road frame's left) |
## "passenger": [from s, to s] (wound down over that time in the shot) | true (down already)}. The
## door's glass (from about 0.46 m behind the driver's eyes, a coupe's B-pillar, forwards) comes out of
## the body into its own piece, "Window_<side>", which wind() slides down along its own slope into the
## door; none of it shows under the door's top. The car's own copy of the body; the lining as it is.
static func open_windows(car: TmCarVisual, sides: Dictionary) -> void:
	if sides.is_empty() or _clear_glass == null:
		return
	var eyes: Vector3 = _layout(TmRoadCars.manifest(car.model))["driver_head"]
	var b_pillar := eyes.z - 0.46
	var winding := {}                                  # side -> [piece, slide (m, the body's frame), from s, to s]
	for mi: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.mesh is ArrayMesh:
			continue
		var glass_k: Array[int] = []
		for k in mi.mesh.get_surface_count():
			if mi.get_surface_override_material(k) == _clear_glass:
				glass_k.append(k)
		if glass_k.is_empty():
			continue
		var names := sides.keys()
		names.sort()
		var key := [mi.mesh, names]
		if not _opened.has(key):
			_opened[key] = _split_windows(mi.mesh as ArrayMesh, glass_k, names, b_pillar)
		var split: Dictionary = _opened[key]
		var overrides := []
		for k in mi.mesh.get_surface_count():
			overrides.append(mi.get_surface_override_material(k))
		mi.mesh = split["body"]
		for k in overrides.size():
			mi.set_surface_override_material(k, overrides[k])
		for side: String in split["windows"]:
			var w: Array = split["windows"][side]              # [mesh, slide, the door's top]
			var piece := MeshInstance3D.new()
			piece.name = "Window_" + side
			piece.mesh = w[0]
			var mat := ShaderMaterial.new()
			mat.shader = _window_shader()
			mat.set_shader_parameter("floor_y", float(w[2]))
			piece.material_override = mat
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(piece)
			var when: Variant = sides[side]
			var span: Array = when if when is Array and (when as Array).size() >= 2 else [-1.0, -1.0]
			winding[side] = [piece, w[1], float(span[0]), float(span[1])]
	car.set_meta("windows", winding)
	wind(car, 0.0)


## The car's wound windows at time t of the shot (open_windows): each as far down as its span says.
static func wind(car: TmCarVisual, t: float) -> void:
	var winding: Dictionary = car.get_meta("windows", {})
	for side: String in winding:
		var w: Array = winding[side]
		var from := float(w[2])
		var to := float(w[3])
		var f := 1.0 if to <= from else clampf((t - from) / (to - from), 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		var piece := w[0] as MeshInstance3D
		piece.position = (w[1] as Vector3) * f
		(piece.material_override as ShaderMaterial).set_shader_parameter("drop", -piece.position.y)


## The body's mesh with its front side windows' glass taken out: {"body": the rest, "windows": {side:
## [that glass as a mesh, the slide that takes its top just under the door's top, the door's top's y]}}.
## The body's paint behind that glass goes too (the greenhouse is lofted whole and the glass laid 4 mm
## over it: with the glass wound down the opening would still show paint from outside).
static func _split_windows(mesh: ArrayMesh, glass_k: Array[int], sides: Array, b_pillar: float) -> Dictionary:
	# (plain Arrays: a packed array taken out of a dictionary is a copy, and an append to it is lost)
	var tris := {}                                     # side -> its glass's corners, three a triangle
	var normals := {}                                  # side -> its glass's corners' normals
	var masks := {}                                    # side -> its glass (GlassMask)
	var glass_keep := {}                               # glass surface -> the indices it keeps
	for side: String in sides:
		tris[side] = []
		normals[side] = []
		masks[side] = GlassMask.new()
	for k in glass_k:
		var arrays := mesh.surface_get_arrays(k)
		if arrays[Mesh.ARRAY_INDEX] == null:
			continue
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var vn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for i in range(0, idx.size(), 3):
			var a := v[idx[i]]
			var b := v[idx[i + 1]]
			var c := v[idx[i + 2]]
			var n := (c - a).cross(b - a).normalized()   # out of the car (Godot's front faces turn clockwise)
			var side := ""
			if (a.z + b.z + c.z) / 3.0 > b_pillar:
				side = "driver" if n.x > 0.6 else "passenger" if n.x < -0.6 else ""
			if side in tris:
				for q in [idx[i], idx[i + 1], idx[i + 2]]:
					(tris[side] as Array).append(v[q])
					(normals[side] as Array).append(vn[q] if vn.size() > q else n)
				(masks[side] as GlassMask).add(a, b, c)
			else:
				keep.append_array([idx[i], idx[i + 1], idx[i + 2]])
		glass_keep[k] = keep
	var body := ArrayMesh.new()
	for k in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(k)
		if glass_keep.has(k):
			arrays[Mesh.ARRAY_INDEX] = glass_keep[k]
		elif arrays[Mesh.ARRAY_INDEX] != null:
			# the paint just behind a wound window goes: a triangle wholly behind it, none of one clear of
			# it, and one across its outline halved three times, the pieces behind it dropped (every
			# attribute carried to the new corners: the livery runs on to the edge)
			var cut := Cutter.new(arrays, masks.values())
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, idx.size(), 3):
				cut.keep_off(idx[i], idx[i + 1], idx[i + 2], 3)
			cut.store(arrays)
		if (arrays[Mesh.ARRAY_INDEX] is PackedInt32Array) and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
			arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 0, 0])   # (a surface keeps its place: overrides go by index)
		body.add_surface_from_arrays(mesh.surface_get_primitive_type(k), arrays)
		body.surface_set_material(k, mesh.surface_get_material(k))
	var windows := {}
	for side: String in tris:
		var t := PackedVector3Array(tris[side] as Array)
		if t.is_empty():
			continue
		var lo := INF
		var hi := -INF
		var facing := Vector3.ZERO
		for i in range(0, t.size(), 3):
			facing += (t[i + 2] - t[i]).cross(t[i + 1] - t[i])
		for p in t:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		facing = facing.normalized()
		# down along the glass's own slope, until its top is 2 cm under its lowest edge (the door's top)
		var down := (Vector3.DOWN - facing * Vector3.DOWN.dot(facing)).normalized()
		var slide := down * ((hi - lo + 0.02) / maxf(-down.y, 0.3))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = t
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals[side] as Array)
		var wm := ArrayMesh.new()
		wm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		windows[side] = [wm, slide, lo]
	return {"body": body, "windows": windows}


## The wound glass: the clear glass's look, nothing drawn under the door's top as it slides down.
static func _window_shader() -> Shader:
	if _window == null:
		_window = Shader.new()
		_window.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform float drop = 0.0;      // how far down the glass has slid (m)
uniform float floor_y = 0.0;   // the door's top, in the body's frame
varying float body_y;
void vertex() { body_y = VERTEX.y - drop; }
void fragment() {
	if (body_y < floor_y) { discard; }
	ALBEDO = vec3(0.03, 0.035, 0.045);
	ALPHA = 0.32;
	ROUGHNESS = 0.03;
	METALLIC = 0.3;
}
"""
	return _window


## The lining of a body's mesh: its lined surfaces' triangles, but those under the glass.
static func _line(mesh: Mesh, glass_k: Array[int], lined_k: Array[int]) -> ArrayMesh:
	var glass := GlassMask.new()
	for k in glass_k:
		var t: PackedVector3Array = _triangles(mesh, k)[0]
		for i in range(0, t.size(), 3):
			glass.add(t[i], t[i + 1], t[i + 2])
	var out := ArrayMesh.new()
	for k in lined_k:
		var tn := _triangles(mesh, k)
		var t: PackedVector3Array = tn[0]
		var tnorm: PackedVector3Array = tn[1]
		var keep := PackedVector3Array()
		var normals := PackedVector3Array()
		for i in range(0, t.size(), 3):
			_clip(t[i], t[i + 1], t[i + 2], -tnorm[i], -tnorm[i + 1], -tnorm[i + 2], 3, glass, keep, normals)  # normals into the cabin
		if keep.is_empty():
			continue
		# turned to face into the cabin, drawn with the usual culling: drawn from the body's own faces
		# with their fronts culled instead, Godot's side check turned the normals back out and lights
		# outside the car (the arch lamp over the roof, its own tail lights) lit the headliner and pillars
		for i in range(0, keep.size(), 3):
			var v := keep[i + 1]
			keep[i + 1] = keep[i + 2]
			keep[i + 2] = v
			var nv := normals[i + 1]
			normals[i + 1] = normals[i + 2]
			normals[i + 2] = nv
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = keep
		arrays[Mesh.ARRAY_NORMAL] = normals
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Keeps a triangle of the lining, all of it, none (its corners under the glass) or, where it crosses
## the glass's edge, its quarters by the same rule down `depth` halvings, the last ones cut where
## their edges cross the glass's outline (the paint's triangles cross the windows' outlines: kept or
## dropped whole, the pillars' edges came out as saw teeth, a centimetre or two from the seats). The
## windows are far bigger than the paint's triangles, so a triangle with no corner under the glass is
## not under it.
static func _clip(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, depth: int,
		glass: GlassMask, out_v: PackedVector3Array, out_n: PackedVector3Array) -> void:
	var under := int(glass.under(a)) + int(glass.under(b)) + int(glass.under(c))
	if under == 0:
		out_v.append_array([a, b, c])
		out_n.append_array([na, nb, nc])
		return
	if under == 3:
		return
	if depth == 0:
		_cut(a, b, c, na, nb, nc, glass, out_v, out_n)
		return
	var ab := (a + b) * 0.5
	var bc := (b + c) * 0.5
	var ca := (c + a) * 0.5
	var nab := (na + nb).normalized()
	var nbc := (nb + nc).normalized()
	var nca := (nc + na).normalized()
	_clip(a, ab, ca, na, nab, nca, depth - 1, glass, out_v, out_n)
	_clip(ab, b, bc, nab, nb, nbc, depth - 1, glass, out_v, out_n)
	_clip(ca, bc, c, nca, nbc, nc, depth - 1, glass, out_v, out_n)
	_clip(ab, bc, ca, nab, nbc, nca, depth - 1, glass, out_v, out_n)


## The part of a triangle off the glass, one or two of its corners under it: cut where its two
## crossing edges meet the glass's outline (each found by halving), the corners kept in the triangle's
## own turn.
static func _cut(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		glass: GlassMask, out_v: PackedVector3Array, out_n: PackedVector3Array) -> void:
	var p := [a, b, c]
	var pn := [na, nb, nc]
	var u := [glass.under(a), glass.under(b), glass.under(c)]
	var odd := 0                          # the corner unlike the other two
	for i in 3:
		if u[i] != u[(i + 1) % 3] and u[i] != u[(i + 2) % 3]:
			odd = i
	var x: Vector3 = p[odd]
	var y: Vector3 = p[(odd + 1) % 3]
	var z: Vector3 = p[(odd + 2) % 3]
	var nx: Vector3 = pn[odd]
	var ny: Vector3 = pn[(odd + 1) % 3]
	var nz: Vector3 = pn[(odd + 2) % 3]
	var fy := _crossing(x, y, u[odd], glass)
	var fz := _crossing(x, z, u[odd], glass)
	var xy := x.lerp(y, fy)
	var xz := x.lerp(z, fz)
	var nxy := nx.lerp(ny, fy).normalized()
	var nxz := nx.lerp(nz, fz).normalized()
	if u[odd]:                            # x alone under the glass: the rest is a quad
		out_v.append_array([xy, y, z, xy, z, xz])
		out_n.append_array([nxy, ny, nz, nxy, nz, nxz])
	else:                                 # x alone off it
		out_v.append_array([x, xy, xz])
		out_n.append_array([nx, nxy, nxz])


## Where the glass's outline crosses the edge from `from` (under the glass or not) to `to` (the
## other), as a fraction along it: on the side off the glass, so the lining stops at its edge. Six
## halvings: the last triangles' edges are millimetres long (median 4, at most about 9 on the
## coupe), so the cut lands within a fifth of a millimetre.
static func _crossing(from: Vector3, to: Vector3, from_under: bool, glass: GlassMask) -> float:
	var lo := 0.0                         # still on from's side
	var hi := 1.0                         # on to's side
	for i in 6:
		var mid := (lo + hi) * 0.5
		if glass.under(from.lerp(to, mid)) == from_under:
			lo = mid
		else:
			hi = mid
	return hi if from_under else lo


## A surface's triangles as flat lists of corners and their normals: [corners, normals].
static func _triangles(mesh: Mesh, k: int) -> Array:
	var arrays := mesh.surface_get_arrays(k)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	if n.size() != v.size():
		n.resize(v.size())
		n.fill(Vector3.UP)
	if arrays[Mesh.ARRAY_INDEX] == null:
		return [v, n]
	var ov := PackedVector3Array()
	var on := PackedVector3Array()
	for i: int in arrays[Mesh.ARRAY_INDEX]:
		ov.append(v[i])
		on.append(n[i])
	return [ov, on]


## A body's glass, to ask quickly whether a point lies just behind it (within BEHIND of a glass
## triangle's face, over it, not beside it): the triangles' planes and barycentric terms in a grid,
## a box round all of it, each point's answer kept (the corners are shared).
## A surface's arrays being cut along a glass's outline (_split_windows): a triangle across it halved
## down to `depth`, each new corner made halfway between two others with every attribute carried.
class Cutter:
	var v: PackedVector3Array
	var nrm: PackedVector3Array
	var tan: PackedFloat32Array
	var col: PackedColorArray
	var uv: PackedVector2Array
	var uv2: PackedVector2Array
	var out := PackedInt32Array()
	var masks: Array
	var _mid := {}                                     # Vector2i(a, b) -> the corner halfway between them
	var _behind := {}                                  # corner -> behind the glass

	func _init(arrays: Array, glass: Array) -> void:
		masks = glass
		v = arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_NORMAL] != null:
			nrm = arrays[Mesh.ARRAY_NORMAL]
		if arrays[Mesh.ARRAY_TANGENT] != null:
			tan = arrays[Mesh.ARRAY_TANGENT]
		if arrays[Mesh.ARRAY_COLOR] != null:
			col = arrays[Mesh.ARRAY_COLOR]
		if arrays[Mesh.ARRAY_TEX_UV] != null:
			uv = arrays[Mesh.ARRAY_TEX_UV]
		if arrays[Mesh.ARRAY_TEX_UV2] != null:
			uv2 = arrays[Mesh.ARRAY_TEX_UV2]

	func behind(i: int) -> bool:
		if not _behind.has(i):
			var hit := false
			for m: GlassMask in masks:
				if m.behind(v[i]):
					hit = true
					break
			_behind[i] = hit
		return _behind[i]

	func half(a: int, b: int) -> int:
		var key := Vector2i(mini(a, b), maxi(a, b))
		if _mid.has(key):
			return _mid[key]
		var i := v.size()
		v.append((v[a] + v[b]) * 0.5)
		if not nrm.is_empty():
			nrm.append((nrm[a] + nrm[b]).normalized())
		if not tan.is_empty():
			var t := (Vector3(tan[a * 4], tan[a * 4 + 1], tan[a * 4 + 2]) + Vector3(tan[b * 4], tan[b * 4 + 1], tan[b * 4 + 2])).normalized()
			tan.append_array([t.x, t.y, t.z, tan[a * 4 + 3]])
		if not col.is_empty():
			col.append(col[a].lerp(col[b], 0.5))
		if not uv.is_empty():
			uv.append((uv[a] + uv[b]) * 0.5)
		if not uv2.is_empty():
			uv2.append((uv2[a] + uv2[b]) * 0.5)
		_mid[key] = i
		return i

	## Keeps what of the triangle (a, b, c) isn't behind the glass, in its own turn.
	func keep_off(a: int, b: int, c: int, depth: int) -> void:
		var n := int(behind(a)) + int(behind(b)) + int(behind(c))
		if n == 0 or (depth == 0 and n < 2):
			out.append_array([a, b, c])
			return
		if n == 3 or depth == 0:
			return
		var ab := half(a, b)
		var bc := half(b, c)
		var ca := half(c, a)
		keep_off(a, ab, ca, depth - 1)
		keep_off(ab, b, bc, depth - 1)
		keep_off(ca, bc, c, depth - 1)
		keep_off(ab, bc, ca, depth - 1)

	func store(arrays: Array) -> void:
		arrays[Mesh.ARRAY_VERTEX] = v
		if not nrm.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = nrm
		if not tan.is_empty():
			arrays[Mesh.ARRAY_TANGENT] = tan
		if not col.is_empty():
			arrays[Mesh.ARRAY_COLOR] = col
		if not uv.is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = uv
		if not uv2.is_empty():
			arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_INDEX] = out


class GlassMask:
	const CELL := 0.03
	const BEHIND := 0.01
	var grid := {}
	var a := PackedVector3Array()
	var n := PackedVector3Array()
	var e0 := PackedVector3Array()
	var e1 := PackedVector3Array()
	var terms := PackedFloat32Array()      ## per triangle: d00, d01, d11, 1 / the determinant
	var box := AABB()
	var seen := {}

	func add(p0: Vector3, p1: Vector3, p2: Vector3) -> void:
		var v0 := p1 - p0
		var v1 := p2 - p0
		var nn := v0.cross(v1)
		var d00 := v0.dot(v0)
		var d01 := v0.dot(v1)
		var d11 := v1.dot(v1)
		var den := d00 * d11 - d01 * d01
		if nn.length_squared() < 1.0e-12 or absf(den) < 1.0e-12:
			return
		var i := a.size()
		a.append(p0)
		n.append(nn.normalized())
		e0.append(v0)
		e1.append(v1)
		terms.append_array([d00, d01, d11, 1.0 / den])
		var lo := p0.min(p1).min(p2) - Vector3.ONE * BEHIND
		var hi := p0.max(p1).max(p2) + Vector3.ONE * BEHIND
		box = AABB(lo, hi - lo) if i == 0 else box.merge(AABB(lo, hi - lo))
		for x in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			for y in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
				for z in range(floori(lo.z / CELL), floori(hi.z / CELL) + 1):
					var key := Vector3i(x, y, z)
					if grid.has(key):
						(grid[key] as Array).append(i)      # (a packed array would be copied out and the append lost)
					else:
						grid[key] = [i]

	## Inside the car just behind the glass (within BEHIND of it, on the side its triangles' (b - a) x
	## (c - a) points to: in, for Godot's clockwise front faces), over one of its triangles.
	func behind(p: Vector3) -> bool:
		if not box.has_point(p):
			return false
		for j: int in grid.get(Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL)), []):
			var d := n[j].dot(p - a[j])
			if d < -0.001 or d > BEHIND:
				continue
			var v2 := p - n[j] * d - a[j]
			var d20 := v2.dot(e0[j])
			var d21 := v2.dot(e1[j])
			var b1 := (terms[j * 4 + 2] * d20 - terms[j * 4 + 1] * d21) * terms[j * 4 + 3]
			var b2 := (terms[j * 4] * d21 - terms[j * 4 + 1] * d20) * terms[j * 4 + 3]
			if b1 >= -0.002 and b2 >= -0.002 and b1 + b2 <= 1.002:
				return true
		return false

	func under(p: Vector3) -> bool:
		if not box.has_point(p):
			return false
		var known: Variant = seen.get(p)
		if known != null:
			return known
		var hit := false
		for j: int in grid.get(Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL)), []):
			var d := n[j].dot(p - a[j])
			if absf(d) > BEHIND:
				continue
			var v2 := p - n[j] * d - a[j]
			var d20 := v2.dot(e0[j])
			var d21 := v2.dot(e1[j])
			var b1 := (terms[j * 4 + 2] * d20 - terms[j * 4 + 1] * d21) * terms[j * 4 + 3]
			var b2 := (terms[j * 4] * d21 - terms[j * 4 + 1] * d20) * terms[j * 4 + 3]
			if b1 >= -0.002 and b2 >= -0.002 and b1 + b2 <= 1.002:
				hit = true
				break
		seen[p] = hit
		return hit


static var _clear_glass: StandardMaterial3D
static var _lining: StandardMaterial3D
static var _linings := {}             ## a body's mesh -> its lining (made once a model)
static var _opened := {}              ## [a body's mesh, sides] -> it split (_split_windows)
static var _window: Shader                ## the wound glass's


func _box(at: Vector3, size: Vector3, mat: Material, tilt_deg := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	mi.rotation = Vector3(deg_to_rad(tilt_deg), 0.0, 0.0)
	add_child(mi)
	return mi


## The camera that sees what the driver sees in the mirror (road frame): the driver's eyes reflected
## in the glass's plane, looking through the glass's middle, its field of view just the glass
## (vertical, degrees), its near plane at the glass so nothing between it and the glass (the
## housing, the windscreen) is drawn. eyes: the driver's eyes (road frame; default the layout's).
func reflection(eyes := Vector3.INF) -> Dictionary:
	var e := driver_head if eyes == Vector3.INF else eyes
	var n := mirror_normal
	var pos := e - 2.0 * (e - mirror_point).dot(n) * n
	var d := pos.distance_to(mirror_point)
	return {"pos": pos, "look": mirror_point, "fov": rad_to_deg(2.0 * atan(GLASS.y * 0.5 / d)), "near": d * 0.98}
