class_name TmNeon
extends RefCounted
## The City maps' neon (owner, M14: "introduce real neon lights, around the track, near barriers,
## on the buildings ... around the stadium. it should be futuristic and alive"). Our own:
## - the barriers: the road's lines in the border atlas glow (TmMaterials "border_panel": the curb's
##   top, magenta; "border_blue": the road edge's strip, cyan, with pulses running along it), lit by
##   the global tm_neon (blocks/tm_textured.gdshader), which only City maps switch on (setup);
## - real light: coloured omni lights along both barriers, from the track's line (track_lights);
## - tubes: glowing tubes (Tubes: merged per colour) on the buildings (TmSkyline) and the Stadium.
## Emissive, so SDFGI (Ultra) takes their light on to what is round them; SSR mirrors them in the
## wet road (TmStadiumEnv.city_night).

## The neon colours (linear-ish HDR bases): cyan, magenta, violet, amber, ice white, lime.
const COLOURS := [Color(0.1, 0.85, 1.0), Color(1.0, 0.16, 0.62), Color(0.62, 0.26, 1.0), Color(1.0, 0.58, 0.14),
	Color(0.85, 0.93, 1.0), Color(0.45, 1.0, 0.3)]
const CYAN := 0
const MAGENTA := 1
const VIOLET := 2
const AMBER := 3
const ICE := 4
const LIME := 5
## The barrier's top from the road's centre (blocks/shapes/road.gd: the curb's top at 1.67-1.79 m
## from the block's side) and its height over the road (2.777 - 1.345 m).
const RAIL := 14.27
const RAIL_UP := 1.43
const LIGHT_EVERY := 32.0         ## m along the line, each side
const LIGHT_RANGE := 13.0
const LIGHT_ENERGY := 2.2
const TUBE_ENERGY := 7.0          ## a tube's glow at night (day: a third)

static var _materials := {}


## City maps: their neon on (night full, by day a little), the barriers' lines set on the shared
## border materials; other maps: off.
static func setup(on: bool, night: bool) -> void:
	RenderingServer.global_shader_parameter_set(&"tm_neon", (1.0 if night else 0.3) if on else 0.0)
	if not on:
		return
	_line("border_panel", Vector2(9.0, 19.4), COLOURS[MAGENTA], 3.2, false)      # the curb's top
	_line("border_blue", Vector2(364.0, 393.0), COLOURS[CYAN], 3.5, true)        # the road edge's strip
	_line("airship", Vector2(0.47, 0.53) * 512.0, COLOURS[CYAN], 6.0, true)     # along the envelope's belly
	_materials.clear()
	for c in COLOURS.size():          # made here, on the main thread: the city builds on a worker
		material(c, night)


static func _line(key: String, rows: Vector2, colour: Color, energy: float, chase: bool) -> void:
	var m := TmMaterials.get_material(key) as ShaderMaterial
	if m == null or m.shader == null or not String(m.shader.resource_path).ends_with("tm_textured.gdshader"):
		return
	m.set_shader_parameter("neon_rows", rows / 512.0)
	m.set_shader_parameter("neon_colour", colour)
	m.set_shader_parameter("neon_energy", energy)
	m.set_shader_parameter("neon_chase", 1.0 if chase else 0.0)


## Real light along both barriers: an omni light every LIGHT_EVERY m of the track's line on each
## side (staggered), cyan on the left, magenta on the right, just inside the curb over the road
## edge; none over jumps or round loops (the line's BLIND, LOOP and WALL points). No shadows; they
## fade out far off. Godot coordinates of the map.
static func track_lights(path: Array, night: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "NeonLights"
	if path.is_empty():
		return root
	var run := 0.0
	var next := [0.0, LIGHT_EVERY * 0.5]
	for i in range(1, path.size()):
		var a: Dictionary = path[i - 1]
		var b: Dictionary = path[i]
		run += (b["p"] as Vector3).distance_to(a["p"])
		if int(b["mode"]) != TmTrackBuilder.Drive.STEER or bool(b.get("sky", false)):
			continue          # (the Sky maps' own road has its own: TmSkyPieces.lights)
		var dir: Vector3 = b["dir"]
		var right := dir.cross(Vector3.UP).normalized()
		for side in 2:
			if run < float(next[side]):
				continue
			next[side] = run + LIGHT_EVERY
			var l := OmniLight3D.new()
			l.light_color = COLOURS[CYAN if side == 0 else MAGENTA]
			l.light_energy = LIGHT_ENERGY * (1.0 if night else 0.25)
			l.omni_range = LIGHT_RANGE
			l.omni_attenuation = 1.4
			l.light_specular = 0.8
			l.light_volumetric_fog_energy = 1.5
			l.shadow_enabled = false
			l.distance_fade_enabled = true
			l.distance_fade_begin = 260.0
			l.distance_fade_length = 80.0
			l.position = (b["p"] as Vector3) + right * (RAIL - 1.2) * (-1.0 if side == 0 else 1.0) + Vector3.UP * (RAIL_UP + 0.4)
			root.add_child(l)
	return root


## Glowing tubes, merged per colour: add(points, radius, colour) a polyline tube (8 sides), then
## build() the meshes, emissive (night: TUBE_ENERGY), unshadowed.
class Tubes:
	var _st := {}          ## colour index -> SurfaceTool
	var night := true
	var sides := 8         ## round each tube (4 for the far city)

	func add(points: PackedVector3Array, radius: float, colour: int, closed := false) -> void:
		if points.size() < 2:
			return
		if not _st.has(colour):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_st[colour] = st
		var st: SurfaceTool = _st[colour]
		var pts := points.duplicate()
		if closed:
			pts.append(points[0])
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var d := b - a
			if d.length() < 1e-4:
				continue
			var t := d.normalized()
			var u := (Vector3.UP if absf(t.y) < 0.95 else Vector3.RIGHT).cross(t).normalized()
			var v := t.cross(u)
			for k in sides:
				var a0 := TAU * k / sides
				var a1 := TAU * (k + 1) / sides
				var n0 := u * cos(a0) + v * sin(a0)
				var n1 := u * cos(a1) + v * sin(a1)
				st.set_normal(n0)
				st.add_vertex(a + n0 * radius)
				st.set_normal(n1)
				st.add_vertex(a + n1 * radius)
				st.set_normal(n1)
				st.add_vertex(b + n1 * radius)
				st.set_normal(n0)
				st.add_vertex(a + n0 * radius)
				st.set_normal(n1)
				st.add_vertex(b + n1 * radius)
				st.set_normal(n0)
				st.add_vertex(b + n0 * radius)

	## A rectangle's outline (corners in order) a little proud of a wall: a closed tube.
	func outline(corners: PackedVector3Array, radius: float, colour: int) -> void:
		add(corners, radius, colour, true)

	func is_empty() -> bool:
		return _st.is_empty()

	func build(name := "Neon") -> Node3D:
		var root := Node3D.new()
		root.name = name
		for c: int in _st:
			var mi := MeshInstance3D.new()
			mi.name = "Neon%d" % c
			mi.mesh = (_st[c] as SurfaceTool).commit()
			mi.material_override = TmNeon.material(c, night)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
			root.add_child(mi)
		return root


## A building's neon from a hash (not a random draw: the city's layout stays as it was): -1 none, else
## a colour (cyan, magenta, violet, amber, ice: not lime); `share` of them get one.
static func pick(h: int, share: float) -> int:
	var hv := absi(h)
	return (hv / 100) % LIME if float(hv % 100) < share * 100.0 else -1


## A neon outline round a footprint (x, z in the parent's frame) at height y, `out` m proud of the
## wall; `down` > 0 runs a tube down each corner that far as well (footprints of up to 8 corners).
static func ring(tubes: Tubes, poly: PackedVector2Array, y: float, colour: int, radius: float, out := 0.25, down := 0.0) -> void:
	if poly.size() < 3:
		return
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= poly.size()
	var pts := PackedVector3Array()
	for p in poly:
		var d := p - c
		var q := p + (d.normalized() * out if d.length() > 0.01 else Vector2.ZERO)
		pts.append(Vector3(q.x, y, q.y))
	tubes.add(pts, radius, colour, true)
	if down > 0.0 and poly.size() <= 8:
		for q in pts:
			tubes.add(PackedVector3Array([q, q - Vector3(0.0, down, 0.0)]), radius, colour)


## A tube's material: its colour, glowing (shared per colour and mood).
static func material(colour: int, night: bool) -> StandardMaterial3D:
	var key := "%d:%s" % [colour, night]
	if _materials.has(key):
		return _materials[key]
	var c: Color = COLOURS[colour]
	var m := StandardMaterial3D.new()
	m.albedo_color = c.lerp(Color.WHITE, 0.55)
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = TUBE_ENERGY * (1.0 if night else 0.33)
	m.rim_enabled = false
	_materials[key] = m
	return m
