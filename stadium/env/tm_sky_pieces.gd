class_name TmSkyPieces
extends RefCounted
## Builds the Sky maps' pieces of our own (M19; TmChallenge.extras, laid by TmSkyTrack) beside
## TMNF's blocks: the road swept through its frames (a deck 25.5 m wide between rails as tall as
## TMNF's curbs, so it meets TMNF's road flush; a slab under it), mag-road where it leans
## (TmTuning.MAG_SURFACE, its own glowing deck: env/tm_mag_road.gdshader), and the rooftops (a flat
## deck at the road's height with a lane of runway lights). With collision (surface ids per face,
## TmGeo), neon tubes along the rails and under the deck's edges (TmNeon.Tubes), and coloured lights
## along the rails (lights()). Everything in TMNF metres (TmGeo turns it into Godot's axes).

const HALF := TmSkyTrack.HALF
const EDGE := TmSkyTrack.EDGE
const RAIL_UP := 1.43            ## the rail's top over the deck (TMNF's curbs: 2.777 - 1.345)
const RAIL_IN := 0.55            ## the rail's inner face leans out this much at its top
const UNDER := 1.2               ## the deck's slab
const ROOF_SLAB := 2.2           ## a rooftop's edge, down from its deck
const S_ROAD := 16
const S_METAL := 4
const LIGHT_EVERY := 40.0        ## m between the coloured lights, each side (staggered)
const TUBE_R := 0.11
const STRIPS := 8                ## the deck's strips across

static var _made := false


## The pieces as one node (Godot axes; the map's origin).
static func build(extras: Array, night: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "SkyPieces"
	if extras.is_empty():
		return root
	_materials()
	var geo := TmGeo.new()
	var tubes := TmNeon.Tubes.new()
	tubes.night = night
	for e: Dictionary in extras:
		match String(e["kind"]):
			"ribbon":
				_ribbon(geo, tubes, e["frames"])
			"roof":
				_roof(geo, tubes, e)
	var node := geo.build()
	node.name = "Road"
	root.add_child(node)
	if not tubes.is_empty():
		root.add_child(tubes.build("SkyNeon"))
	return root


## Our materials, under TmMaterials keys (made once, on the main thread).
static func _materials() -> void:
	if _made and TmMaterials._cache.has("sky_mag"):
		return
	_made = true
	var shader := preload("res://env/tm_mag_road.gdshader")
	var mag := ShaderMaterial.new()
	mag.shader = shader
	mag.set_shader_parameter("mag", 1.0)
	TmMaterials.register("sky_mag", mag)
	var lane := ShaderMaterial.new()
	lane.shader = shader
	lane.set_shader_parameter("mag", 0.0)
	lane.render_priority = 1
	TmMaterials.register("sky_lane", lane)
	var rail := StandardMaterial3D.new()
	rail.albedo_color = Color(0.055, 0.06, 0.075)
	rail.metallic = 0.75
	rail.roughness = 0.28
	TmMaterials.register("sky_rail", rail)
	var under := StandardMaterial3D.new()
	under.albedo_color = Color(0.07, 0.07, 0.085)
	under.metallic = 0.4
	under.roughness = 0.55
	TmMaterials.register("sky_under", under)
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color(0.13, 0.13, 0.145)
	roof.roughness = 0.7
	TmMaterials.register("sky_roof", roof)


## A point of frame fr: x across (+ right), y up from the deck.
static func _at(fr: Dictionary, x: float, y: float) -> Vector3:
	var u: Vector3 = fr["u"]
	return (fr["o"] as Vector3) + TmSkyTrack.right_of(fr["f"], u) * x + u * y


## A quad facing `want` (its corners in order round it, either way): normals and UVs per corner.
static func _quad(geo: TmGeo, p: Array, want: Vector3, key: String, surf: int, nrm: Array = [], uv: Array = []) -> void:
	var o := [0, 1, 2, 3]
	if ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3)).dot(want) < 0.0:
		o = [0, 3, 2, 1]
	var n := nrm if not nrm.is_empty() else [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var t := uv if not uv.is_empty() else [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	geo.tri(p[o[0]], p[o[1]], p[o[2]], key, surf, n[o[0]], n[o[1]], n[o[2]], t[o[0]], t[o[1]], t[o[2]])
	geo.tri(p[o[0]], p[o[2]], p[o[3]], key, surf, n[o[0]], n[o[2]], n[o[3]], t[o[0]], t[o[2]], t[o[3]])


static func _has_rail(fr: Dictionary, left: bool) -> bool:
	var r := String(fr.get("rails", "both"))
	return r == "both" or r == ("l" if left else "r")


static func _ribbon(geo: TmGeo, tubes: TmNeon.Tubes, frames: Array) -> void:
	var n := frames.size()
	if n < 2:
		return
	# the neon runs: [points (Godot)] per tube, broken where a rail starts or stops
	var runs := {"rl": PackedVector3Array(), "rr": PackedVector3Array(), "ul": PackedVector3Array(), "ur": PackedVector3Array()}
	var colours := {"rl": TmNeon.CYAN, "rr": TmNeon.MAGENTA, "ul": TmNeon.VIOLET, "ur": TmNeon.VIOLET}
	for i in n:
		var a: Dictionary = frames[i]
		var ua: Vector3 = a["u"]
		var ra := TmSkyTrack.right_of(a["f"], ua)
		for left: bool in [true, false]:
			var sx := -1.0 if left else 1.0
			var key := "rl" if left else "rr"
			var y := RAIL_UP + 0.08 if _has_rail(a, left) else 0.06
			var x := (HALF + RAIL_IN * 0.6) if _has_rail(a, left) else EDGE - 0.15
			if i > 0 and _has_rail(frames[i - 1], left) != _has_rail(a, left):
				_tube(tubes, runs, key, colours[key])
			(runs[key] as PackedVector3Array).append(TmGeo.g(_at(a, sx * x, y)))
			(runs["ul" if left else "ur"] as PackedVector3Array).append(TmGeo.g(_at(a, sx * (EDGE + 0.05), -UNDER - 0.05)))
		if i == n - 1:
			break
		var c: Dictionary = frames[i + 1]
		var uc: Vector3 = c["u"]
		var rc := TmSkyTrack.right_of(c["f"], uc)
		var mag := bool(a["mag"]) or bool(c["mag"])
		var sa := float(a["s"])
		var sc := float(c["s"])
		# the deck, in strips across: a twisting deck's quads aren't flat, and one diagonal across
		# the whole deck would leave a washboard down its middle
		for k in STRIPS:
			var x0 := lerpf(-HALF, HALF, float(k) / STRIPS)
			var x1 := lerpf(-HALF, HALF, float(k + 1) / STRIPS)
			var t0 := float(k) / STRIPS
			var t1 := float(k + 1) / STRIPS
			_quad(geo, [_at(a, x0, 0.0), _at(a, x1, 0.0), _at(c, x1, 0.0), _at(c, x0, 0.0)], ua + uc,
				"sky_mag" if mag else "asphalt", TmTuning.MAG_SURFACE if mag else S_ROAD, [ua, ua, uc, uc],
				[Vector2(t0, sa), Vector2(t1, sa), Vector2(t1, sc), Vector2(t0, sc)])
		for left: bool in [true, false]:
			var sx := -1.0 if left else 1.0
			var out_a := ra * sx
			var out_c := rc * sx
			if _has_rail(a, left):
				# the rail: its inner face (leaning out), its top, its outer face down to the slab's foot
				var p0 := [_at(a, sx * HALF, 0.0), _at(c, sx * HALF, 0.0), _at(c, sx * (HALF + RAIL_IN), RAIL_UP), _at(a, sx * (HALF + RAIL_IN), RAIL_UP)]
				_quad(geo, p0, -(out_a + out_c) + (ua + uc) * 0.3, "sky_rail", S_METAL)
				_quad(geo, [p0[3], p0[2], _at(c, sx * EDGE, RAIL_UP), _at(a, sx * EDGE, RAIL_UP)], ua + uc, "sky_rail", S_METAL)
				_quad(geo, [_at(a, sx * EDGE, RAIL_UP), _at(c, sx * EDGE, RAIL_UP), _at(c, sx * EDGE, -UNDER), _at(a, sx * EDGE, -UNDER)],
					out_a + out_c, "sky_rail", S_METAL)
			else:
				# a bare edge: the deck runs on to it (driveable), then down to the slab's foot
				_quad(geo, [_at(a, sx * HALF, 0.0), _at(c, sx * HALF, 0.0), _at(c, sx * EDGE, 0.0), _at(a, sx * EDGE, 0.0)], ua + uc,
					"sky_mag" if mag else "asphalt", TmTuning.MAG_SURFACE if mag else S_ROAD, [ua, uc, uc, ua],
					[Vector2(0.0, sa), Vector2(0.0, sc), Vector2(0.0, sc), Vector2(0.0, sa)])
				_quad(geo, [_at(a, sx * EDGE, 0.0), _at(c, sx * EDGE, 0.0), _at(c, sx * EDGE, -UNDER), _at(a, sx * EDGE, -UNDER)],
					out_a + out_c, "sky_rail", S_METAL)
		# the slab's underside
		_quad(geo, [_at(a, -EDGE, -UNDER), _at(a, EDGE, -UNDER), _at(c, EDGE, -UNDER), _at(c, -EDGE, -UNDER)], -(ua + uc),
			"sky_under", S_METAL, [-ua, -ua, -uc, -uc])
	# the ends: the slab's section (a lip in the air shows it)
	for k: int in [0, n - 1]:
		var fr: Dictionary = frames[k]
		var f: Vector3 = fr["f"]
		var want := -f if k == 0 else f
		_quad(geo, [_at(fr, -EDGE, -UNDER), _at(fr, EDGE, -UNDER), _at(fr, EDGE, 0.0), _at(fr, -EDGE, 0.0)], want, "sky_rail", S_METAL)
		for left: bool in [true, false]:
			if _has_rail(fr, left):
				var sx := -1.0 if left else 1.0
				_quad(geo, [_at(fr, sx * HALF, 0.0), _at(fr, sx * EDGE, 0.0), _at(fr, sx * EDGE, RAIL_UP), _at(fr, sx * (HALF + RAIL_IN), RAIL_UP)],
					want, "sky_rail", S_METAL)
	for key: String in runs:
		_tube(tubes, runs, key, colours[key])


## Adds a neon run as a tube and starts the next one.
static func _tube(tubes: TmNeon.Tubes, runs: Dictionary, key: String, colour: int) -> void:
	var pts: PackedVector3Array = runs[key]
	if pts.size() >= 2:
		tubes.add(pts, TUBE_R, colour)
	runs[key] = PackedVector3Array()


## A rooftop: its deck at the road's height (asphalt, the bot's and the car's), the slab's edge
## round it, a lane of runway lights and arrows along the road's line over it, a neon ring round
## its edge.
static func _roof(geo: TmGeo, tubes: TmNeon.Tubes, e: Dictionary) -> void:
	var lo: Vector3 = e["lo"]
	var hi: Vector3 = e["hi"]
	var y: float = e["y"]
	var c := [Vector3(lo.x, y, lo.z), Vector3(hi.x, y, lo.z), Vector3(hi.x, y, hi.z), Vector3(lo.x, y, hi.z)]
	_quad(geo, c, Vector3.UP, "sky_roof", S_ROAD)
	var mid := (lo + hi) * 0.5
	for i in 4:
		var p: Vector3 = c[i]
		var q: Vector3 = c[(i + 1) % 4]
		var out := ((p + q) * 0.5 - mid)
		out.y = 0.0
		_quad(geo, [p, q, q - Vector3.UP * ROOF_SLAB, p - Vector3.UP * ROOF_SLAB], out, "sky_rail", S_METAL)
	var ring := PackedVector3Array()
	for p: Vector3 in c:
		var d := p - mid
		ring.append(TmGeo.g(p + Vector3(signf(d.x) * 0.1, 0.12, signf(d.z) * 0.1)))
	tubes.add(ring, TUBE_R * 1.3, TmNeon.CYAN, true)
	# the lane over the deck, a hair above it (visual only)
	var a: Vector3 = e["entry"]
	var z: Vector3 = e["exit"]
	var f: Vector3 = e["f"]
	var rt := TmSkyTrack.right_of(f, Vector3.UP)
	var lift := Vector3.UP * 0.03
	var len := a.distance_to(z)
	_quad(geo, [a - rt * HALF + lift, a + rt * HALF + lift, z + rt * HALF + lift, z - rt * HALF + lift], Vector3.UP, "sky_lane",
		TmGeo.NO_COLLISION, [], [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, len), Vector2(0.0, len)])


## Coloured light along the sky road's rails (as TmNeon.track_lights along TMNF's): an omni light
## every LIGHT_EVERY m each side, staggered, cyan on the left and magenta on the right, inside the
## rail over the deck, whichever way the road faces. Godot axes.
static func lights(extras: Array, night: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "SkyLights"
	for e: Dictionary in extras:
		if String(e["kind"]) != "ribbon":
			continue
		var frames: Array = e["frames"]
		var next := [LIGHT_EVERY * 0.25, LIGHT_EVERY * 0.75]
		for fr: Dictionary in frames:
			var s := float(fr["s"])
			for side in 2:
				if s < float(next[side]):
					continue
				next[side] = s + LIGHT_EVERY
				var l := OmniLight3D.new()
				l.light_color = TmNeon.COLOURS[TmNeon.CYAN if side == 0 else TmNeon.MAGENTA]
				l.light_energy = TmNeon.LIGHT_ENERGY * (1.0 if night else 0.25)
				l.omni_range = TmNeon.LIGHT_RANGE
				l.omni_attenuation = 1.4
				l.light_specular = 0.8
				l.light_volumetric_fog_energy = 1.5
				l.shadow_enabled = false
				l.distance_fade_enabled = true
				l.distance_fade_begin = 260.0
				l.distance_fade_length = 80.0
				l.position = TmGeo.g(_at(fr, (HALF - 1.2) * (-1.0 if side == 0 else 1.0), RAIL_UP + 0.4))
				root.add_child(l)
	return root
