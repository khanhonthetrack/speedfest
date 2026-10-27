class_name StoryProps
extends RefCounted
## Set dressing for the cutscenes (PLAN M20-3; docs/STORY.md, production notes: every set is a corner
## of the same City): shipping containers (stacked, ribbed, a little rust), a gantry crane with its hook
## and warning light, floodlight poles that light what is under them, and toll booths. Made here in
## code like the rest of the game; placed by a shot's "props": [{"kind", "pos": [x, y, z] (the shot's
## anchor frame), "yaw" (deg), "colour", "stack" (containers high), "light" (poles: on)}]; a container
## terminal's block in one ("containers": "rows" side by side along its x, "bays" end to end along its
## z, centred on "pos"; "stack": [lowest, highest] or a number, each stack's height and each box's
## colour picked by "seed"; "gaps": [between rows, between bays] m; "skip": [[row, bay], ...] left
## empty). Every container is one instance of a MultiMesh (thousands draw as one); "mast": a terminal's
## high-mast light ("height", "colour", "energy", "shadow"). And the
## railway viaduct ("viaduct": brick arches along its x, their faces towards +z; "arches" each side of
## the one at its origin, which is Dee's, Arch 9: a roller door half up, a bare bulb inside, its
## number painted over it; "train": [from s, speed m/s] a lit train crossing the deck, StoryProps.pose).
## The docks set (docs/CINEMATICS.md): "quay" (the deck a "bare": "set" shot stands on, its walls, its
## bollards, painted lines, the water round it), "sts_crane" (a ship-to-shore crane at the quay's
## edge), "warehouse", "portacabin" (with a "sign"), "stage" (the auctioneer's, a lit truss),
## "barrel" (a fire), "fence" (chain-link, "from" / "to").

const CONTAINER := Vector3(2.44, 2.6, 12.2)      ## an ISO 40-foot box (m)
const RIBS := """shader_type spatial;
// a container's corrugated steel: vertical ribs along its length, paint worn to rust at the edges;
// one MultiMesh instance per box: INSTANCE_CUSTOM.rgb its paint, .a its own rust's seed
varying vec3 lp;
varying vec3 ln;
varying vec4 paint;
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 13758.5453); }
void vertex() { lp = VERTEX; ln = NORMAL; paint = INSTANCE_CUSTOM; }
void fragment() {
	// the box's own face (its local normal: the view's would turn a wall facing the camera flat)
	bool side = abs(ln.x) > 0.5;
	float along = side ? lp.z : lp.x;
	float rib = sin(along * 9.0);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * MODEL_MATRIX * vec4(side ? vec3(0.0, 0.0, rib * 0.35) : vec3(rib * 0.35, 0.0, 0.0), 0.0)).xyz);
	float edge = max(smoothstep(1.1, 1.3, abs(lp.y)), 0.0);
	float rust = smoothstep(0.55, 0.95, hash(floor(lp.xz * 3.0) + floor(lp.y * 4.0) + paint.a * 17.0) * 0.6 + edge);
	ALBEDO = mix(paint.rgb, vec3(0.22, 0.1, 0.05), rust * 0.7) * (0.85 + 0.15 * rib);
	ROUGHNESS = 0.55 + 0.3 * rust;
	METALLIC = 0.4;
}
"""
const COLOURS := [Color("8c2a1c"), Color("1f4f7a"), Color("2f5a33"), Color("9a6a1a"), Color("3a3f45"),
	Color("b8b2a4"), Color("6b2a4a")]        ## rust red, blue, green, ochre, grey, white, maroon

static var _ribs: Shader
static var _ribs_mat: ShaderMaterial    ## every container's (their paint per instance)


## Builds a shot's props under `parent`, placed in the anchor frame `anchor`.
static func build(parent: Node3D, list: Array, anchor: Transform3D) -> void:
	for p: Dictionary in list:
		var node: Node3D
		match String(p.get("kind", "")):
			"container":
				node = _containers(p)
			"containers":
				node = _terminal(p)
			"crane":
				node = _crane(p)
			"pole":
				node = _pole(p)
			"mast":
				node = _mast(p)
			"booth":
				node = _booth(p)
			"viaduct":
				node = _viaduct(p)
			"quay":
				node = _quay(p)
			"sts_crane":
				node = _sts_crane(p)
			"warehouse":
				node = _warehouse(p)
			"portacabin":
				node = _portacabin(p)
			"stage":
				node = _stage(p)
			"barrel":
				node = _barrel(p)
			"fence":
				node = _fence(p)
			_:
				continue
		parent.add_child(node)
		var pos: Array = p.get("pos", [0, 0, 0])
		node.global_transform = anchor * Transform3D(Basis(Vector3.UP, deg_to_rad(float(p.get("yaw", 0.0)))),
			Vector3(float(pos[0]), float(pos[1]), float(pos[2])))


static func _mat(c: Color, rough := 0.7, metal := 0.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


static func _containers(p: Dictionary) -> Node3D:
	var boxes: Array = []
	var base := int(p.get("colour", 0))
	for k in int(p.get("stack", 1)):
		boxes.append([Vector3(0.0, CONTAINER.y * (k + 0.5), 0.0), COLOURS[(base + k * 2) % 5], float(base * 7 + k)])
	return _boxes(boxes)


## A block of a container terminal (the doc above): its rows along x and bays along z, centred.
static func _terminal(p: Dictionary) -> Node3D:
	var rows := int(p.get("rows", 4))
	var bays := int(p.get("bays", 2))
	var gaps: Array = p.get("gaps", [0.3, 0.6])
	var stack: Variant = p.get("stack", [2, 3])
	var lo := int(stack[0]) if stack is Array else int(stack)
	var hi := int(stack[1]) if stack is Array else int(stack)
	var skip: Array = p.get("skip", [])
	var seed := int(p.get("seed", 1))
	var pitch := Vector2(CONTAINER.x + float(gaps[0]), CONTAINER.z + float(gaps[1]))
	var boxes: Array = []
	for r in rows:
		for b in bays:
			if skip.any(func(e: Array) -> bool: return int(e[0]) == r and int(e[1]) == b):    # (JSON's numbers are floats)
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([seed, r, b])        # each stack its own: a gap punched in a block leaves the rest as they were
			var h := rng.randi_range(lo, hi)
			var at := Vector2((r - (rows - 1) * 0.5) * pitch.x, (b - (bays - 1) * 0.5) * pitch.y)
			for k in h:
				boxes.append([Vector3(at.x, CONTAINER.y * (k + 0.5), at.y), COLOURS[rng.randi_range(0, COLOURS.size() - 1)],
					rng.randf() * 100.0])
	return _boxes(boxes)


## Containers as one MultiMesh: [[centre, colour, rust seed], ...] in the node's frame.
static func _boxes(boxes: Array) -> Node3D:
	if _ribs == null:
		_ribs = Shader.new()
		_ribs.code = RIBS
	if _ribs_mat == null:
		_ribs_mat = ShaderMaterial.new()
		_ribs_mat.shader = _ribs
	var mesh := BoxMesh.new()
	mesh.size = CONTAINER
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = boxes.size()
	for i in boxes.size():
		var c: Color = boxes[i][1]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, boxes[i][0]))
		mm.set_instance_custom_data(i, Color(c.r, c.g, c.b, fposmod(float(boxes[i][2]) * 0.618034, 1.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Containers"
	mmi.multimesh = mm
	mmi.material_override = _ribs_mat
	var root := Node3D.new()
	root.add_child(mmi)
	return root


static func _crane(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var steel := _mat(Color(0.75, 0.42, 0.08), 0.6, 0.5)
	var h := float(p.get("height", 26.0))
	var span := float(p.get("span", 20.0))
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(span * 0.5 * side, h * 0.5, 0.0), Vector3(1.0, h, 1.0), steel)
		_box(root, Vector3(span * 0.5 * side, h * 0.5, 6.0), Vector3(1.0, h, 1.0), steel)
	_box(root, Vector3(0.0, h, 3.0), Vector3(span + 1.2, 1.4, 7.4), steel)
	_box(root, Vector3(0.0, h + 1.2, 3.0), Vector3(3.0, 1.0, 3.0), _mat(Color(0.2, 0.2, 0.22)))
	var drop := float(p.get("hook", 14.0))
	_box(root, Vector3(0.0, h - drop * 0.5, 3.0), Vector3(0.06, drop, 0.06), _mat(Color(0.1, 0.1, 0.1), 0.4, 0.8))
	_box(root, Vector3(0.0, h - drop - 0.6, 3.0), Vector3(1.2, 1.2, 0.6), _mat(Color(0.85, 0.65, 0.1), 0.5, 0.4))
	var warn := OmniLight3D.new()
	warn.light_color = Color(1.0, 0.1, 0.05)
	warn.light_energy = 2.5
	warn.omni_range = 9.0
	warn.position = Vector3(0.0, h + 2.0, 3.0)
	root.add_child(warn)
	return root


static func _pole(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var h := float(p.get("height", 10.0))
	_box(root, Vector3(0.0, h * 0.5, 0.0), Vector3(0.25, h, 0.25), _mat(Color(0.3, 0.3, 0.32), 0.5, 0.6))
	var head_mat := StandardMaterial3D.new()
	head_mat.emission_enabled = true
	head_mat.emission = Color(1.0, 0.95, 0.85)
	head_mat.emission_energy_multiplier = 6.0 if bool(p.get("light", true)) else 0.0
	_box(root, Vector3(0.0, h, 0.6), Vector3(0.9, 0.3, 0.6), head_mat)
	if bool(p.get("light", true)):
		var s := SpotLight3D.new()
		s.light_color = Color(String(p.get("colour", "#e8eeff")))
		s.light_energy = float(p.get("energy", 9.0))
		s.spot_range = h * 2.5
		s.spot_angle = 42.0
		s.shadow_enabled = true
		s.position = Vector3(0.0, h - 0.2, 0.6)
		s.rotation = Vector3(-PI * 0.5 + 0.2, 0.0, 0.0)          # down, a little outwards
		root.add_child(s)
	return root


## A container terminal's high-mast light: a ring of lamps on a tall pole, one wide spot straight
## down ("height", "colour", "energy", "shadow": off by default, so a terminal's dozen stay cheap):
## what makes a yard of boxes read from the air at night.
static func _mast(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var h := float(p.get("height", 28.0))
	var colour := Color(String(p.get("colour", "#ffe2b8")))
	_box(root, Vector3(0.0, h * 0.5, 0.0), Vector3(0.6, h, 0.6), _mat(Color(0.35, 0.35, 0.37), 0.5, 0.6))
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(0.1, 0.1, 0.1)
	lamp.emission_enabled = true
	lamp.emission = colour
	lamp.emission_energy_multiplier = 8.0
	for i in 4:
		var a := TAU * i / 4.0
		_box(root, Vector3(cos(a) * 0.9, h, sin(a) * 0.9), Vector3(0.7, 0.3, 0.7), lamp)
	var s := SpotLight3D.new()
	s.light_color = colour
	s.light_energy = float(p.get("energy", 6.0))
	s.spot_range = h * 2.6
	s.spot_angle = 62.0
	s.spot_attenuation = 0.8
	s.shadow_enabled = bool(p.get("shadow", false))
	s.position = Vector3(0.0, h - 0.4, 0.0)
	s.rotation = Vector3(-PI * 0.5, 0.0, 0.0)                 # straight down
	root.add_child(s)
	return root


static func _booth(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	_box(root, Vector3(0.0, 1.3, 0.0), Vector3(1.6, 2.6, 2.4), _mat(Color(0.82, 0.83, 0.85), 0.6, 0.1))
	_box(root, Vector3(0.0, 2.75, 0.0), Vector3(2.2, 0.25, 3.0), _mat(Color(0.15, 0.15, 0.17)))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.1, 0.12, 0.14)
	glass.emission_enabled = bool(p.get("light", false))
	glass.emission = Color(1.0, 0.85, 0.6)
	glass.emission_energy_multiplier = 1.5
	_box(root, Vector3(0.81, 1.6, 0.0), Vector3(0.02, 1.0, 1.6), glass)
	return root


const BRICK := """shader_type spatial;
// soot-dark railway brick in world space: stretcher bond, mortar lines, a few bricks darker
varying vec3 wp;
varying vec3 wn;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	vec2 uv = abs(wn.x) > 0.5 ? wp.zy : (abs(wn.z) > 0.5 ? wp.xy : wp.xz);
	uv /= vec2(0.44, 0.15);
	float row = floor(uv.y);
	uv.x += mod(row, 2.0) * 0.5;
	vec2 f = fract(uv);
	float mortar = step(f.x, 0.05) + step(f.y, 0.1);
	float shade = 0.75 + 0.5 * hash(floor(uv));
	vec3 brick = vec3(0.32, 0.13, 0.08) * shade;
	ALBEDO = mix(brick, vec3(0.16, 0.15, 0.14), clamp(mortar, 0.0, 1.0));
	ROUGHNESS = 0.92;
}
"""
const SPAN := 9.0                      ## an arch's opening and pier (m)
const DECK := 7.2                      ## the deck's underside over the street (m)
static var _brick: Shader


static func _viaduct(p: Dictionary) -> Node3D:
	if _brick == null:
		_brick = Shader.new()
		_brick.code = BRICK
	var root := Node3D.new()
	var bm := ShaderMaterial.new()
	bm.shader = _brick
	var n := int(p.get("arches", 3))
	var depth := 9.0
	var open_w := SPAN - 1.8
	var spring := 4.2                  # where each arch's curve starts
	var wall := CSGCombiner3D.new()
	wall.material_override = bm
	root.add_child(wall)
	var body := CSGBox3D.new()
	body.size = Vector3(SPAN * (2 * n + 1), DECK + 1.6, depth)
	body.position = Vector3(0.0, (DECK + 1.6) * 0.5, -depth * 0.5)
	wall.add_child(body)
	for k in range(-n, n + 1):
		# each opening: a box up to the springing and a half round over it, cut right through
		var x := k * SPAN
		var hole := CSGBox3D.new()
		hole.operation = CSGShape3D.OPERATION_SUBTRACTION
		hole.size = Vector3(open_w, spring, depth + 1.0)
		hole.position = Vector3(x, spring * 0.5 - 0.01, -depth * 0.5)
		wall.add_child(hole)
		var vault := CSGCylinder3D.new()
		vault.operation = CSGShape3D.OPERATION_SUBTRACTION
		vault.radius = open_w * 0.5
		vault.height = depth + 1.0
		vault.sides = 24
		vault.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		vault.position = Vector3(x, spring, -depth * 0.5)
		wall.add_child(vault)
		# closed a metre in: a back wall, and a shutter (down, or Dee's half up)
		var mine := k == 0
		var back := _box(root, Vector3(x, (spring + open_w * 0.5) * 0.5, -1.2 - 0.15), Vector3(open_w, spring + open_w * 0.5, 0.3),
			_mat(Color(0.05, 0.045, 0.04)) if not mine else _mat(Color(0.12, 0.1, 0.08)))
		back.position.z = -1.35 if not mine else -depth + 0.6
		var shutter_h := spring if not mine else spring * 0.45
		_box(root, Vector3(x, spring - shutter_h * 0.5, -1.15), Vector3(open_w - 0.1, shutter_h, 0.06),
			_mat(Color(0.28, 0.29, 0.3) if mine else Color(0.18, 0.19, 0.2), 0.5, 0.6))
		_box(root, Vector3(x, spring + open_w * 0.5 * 0.5, -1.15), Vector3(open_w - 0.1, open_w * 0.5, 0.06),
			_mat(Color(0.03, 0.03, 0.03)))          # the vault's lunette, dark glass
	# Dee's arch: the bulb inside, the pit's glow, the number
	var bulb := OmniLight3D.new()
	bulb.light_color = Color(1.0, 0.78, 0.45)
	bulb.light_energy = 3.5
	bulb.omni_range = 11.0
	bulb.shadow_enabled = true
	bulb.position = Vector3(0.0, 1.95, -3.5)      # hung low on its flex, so it shows under the door
	root.add_child(bulb)
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.8, 0.5)
	glow.emission_energy_multiplier = 8.0
	_box(root, Vector3(0.0, 2.1, -3.5), Vector3(0.12, 0.16, 0.12), glow)
	_box(root, Vector3(0.0, (2.18 + spring + open_w * 0.5) * 0.5, -3.5), Vector3(0.012, spring + open_w * 0.5 - 2.18, 0.012), _mat(Color(0.05, 0.05, 0.05)))
	var sign := Label3D.new()
	sign.text = "ARCH 9"
	sign.font_size = 160
	sign.pixel_size = 0.004
	sign.modulate = Color(0.92, 0.9, 0.85)
	sign.position = Vector3(0.0, spring + open_w * 0.5 + 0.45, 0.02)
	root.add_child(sign)
	# the deck: a parapet each side and the rails between
	var deck_y := DECK + 1.6
	_box(root, Vector3(0.0, deck_y + 0.5, -0.25), Vector3(SPAN * (2 * n + 1), 1.0, 0.5), bm)
	_box(root, Vector3(0.0, deck_y + 0.5, -depth + 0.25), Vector3(SPAN * (2 * n + 1), 1.0, 0.5), bm)
	if p.has("train"):
		root.add_child(_train(p["train"]))
	return root


## A lit train on the deck, crossing along x: [from (s into the shot), speed (m/s)].
static func _train(spec: Array) -> Node3D:
	var t := Node3D.new()
	t.name = "Train"
	t.set_meta("train", [float(spec[0]), float(spec[1])])
	var body := _mat(Color(0.12, 0.13, 0.15), 0.5, 0.5)
	var lit := StandardMaterial3D.new()
	lit.emission_enabled = true
	lit.emission = Color(0.95, 0.92, 0.8)
	lit.emission_energy_multiplier = 3.0
	for car in 4:
		var x := -car * 20.5
		_box(t, Vector3(x, DECK + 1.6 + 1.9, -4.5), Vector3(20.0, 3.0, 3.0), body)
		_box(t, Vector3(x, DECK + 1.6 + 2.2, -2.99), Vector3(18.0, 0.8, 0.02), lit)       # the windows' strip
	t.visible = false
	return t


## Moves what moves in a shot's props at its time (s into the shot): a train crosses its deck; and at
## the scene's `time` (props that stay over a cut carry on): the water ripples, a fire flickers.
static func pose(parent: Node3D, local: float, time := -1.0) -> void:
	if time < 0.0:
		time = local
	for w: Node in parent.find_children("Water", "MeshInstance3D", true, false):
		((w as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("time", time)
	for f: Node in parent.find_children("Fire", "OmniLight3D", true, false):
		var l := f as OmniLight3D
		var base := float(l.get_meta("fire", 2.5))
		l.light_energy = base * (0.78 + 0.14 * sin(time * 11.0 + l.position.x) + 0.08 * sin(time * 23.0 + 1.3))
	for t: Node3D in parent.find_children("Train", "Node3D", true, false):
		var m: Array = t.get_meta("train", [0.0, 0.0])
		var run := (local - float(m[0])) * float(m[1])
		t.visible = run >= 0.0 and run < 260.0
		t.position.x = -120.0 + run


# --- the docks set (docs/CINEMATICS.md: a dark, wet quay, water below its edge, the city across it) ---

const DECK_SHADER := """shader_type spatial;
// a wet dock's asphalt at night (StoryProps "quay"): dark and grained, laid in slabs with tar seams and
// darker patches, the yard's painted lines worn, puddles that mirror the lights; in the deck's own
// frame, so the pattern stays with the set
uniform vec2 offset;               // the mesh's centre in the deck's frame
uniform vec4 lines[24];            // painted segments: x0, z0, x1, z1
uniform vec4 line_style[24];       // their r, g, b, width (m)
uniform int line_count = 0;
uniform float wetness = 1.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
float hash(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * noise(p); p = p * 2.03 + 17.1; a *= 0.5; }
	return s;
}
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
	return length(pa - ba * h);
}
void fragment() {
	vec2 p = lp.xz + offset;
	float big = fbm(p * 0.035);
	float grain = noise(p * 9.0) * 0.6 + noise(p * 31.0) * 0.4;
	vec2 cell = vec2(9.0, 14.0);
	float patch = step(0.8, hash(floor(p / cell) + 3.7));
	vec3 col = vec3(0.078, 0.077, 0.08) * (0.8 + 0.45 * big) * (0.88 + 0.24 * grain) * mix(1.0, 0.68, patch);
	vec2 sf = abs(fract(p / cell) - 0.5) * cell;
	float seam = max(smoothstep(cell.x * 0.5 - 0.06, cell.x * 0.5 - 0.02, sf.x), smoothstep(cell.y * 0.5 - 0.06, cell.y * 0.5 - 0.02, sf.y));
	col = mix(col, vec3(0.025), seam * 0.85);
	for (int i = 0; i < line_count; i++) {
		float d = seg(p, lines[i].xy, lines[i].zw);
		float w = line_style[i].w * 0.5;
		float worn = smoothstep(0.3, 0.6, noise(p * 2.5 + float(i) * 7.0) * 0.7 + noise(p * 19.0) * 0.3 + 0.2);
		col = mix(col, line_style[i].rgb, (1.0 - smoothstep(w - 0.015, w + 0.015, d)) * worn * 0.9);
	}
	// standing water in the low places (smooth mirrors), damp tarmac round them, drier crowns between
	float wet = fbm(p * 0.07 + vec2(5.2, 1.3));
	float puddle = smoothstep(0.54, 0.56, wet) * wetness;
	float damp = smoothstep(0.46, 0.54, wet) * wetness;
	ALBEDO = col * mix(1.0, 0.6, damp);
	ROUGHNESS = mix(mix(0.78, 0.45, damp) + grain * 0.08, 0.02, puddle);
	SPECULAR = 0.5;
	float e = 0.06;
	float hx = noise((p + vec2(e, 0.0)) * 9.0) - noise((p - vec2(e, 0.0)) * 9.0);
	float hz = noise((p + vec2(0.0, e)) * 9.0) - noise((p - vec2(0.0, e)) * 9.0);
	NORMAL_MAP = normalize(vec3(-hx * 0.18, -hz * 0.18, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0 - puddle;
}
"""
const WATER_SHADER := """shader_type spatial;
// harbour water at night: near black, glassy, slow ripples, so the lights across it smear down it
uniform float time = 0.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float h(vec2 p) {
	return noise(p * 0.35 + vec2(time * 0.06, time * 0.04)) * 0.6 + noise(p * 1.3 - vec2(time * 0.17, -time * 0.11)) * 0.3
		+ noise(p * 3.7 + vec2(-time * 0.3, time * 0.25)) * 0.1;
}
void fragment() {
	vec2 p = wp.xz;
	float e = 0.12;
	float dx = h(p + vec2(e, 0.0)) - h(p - vec2(e, 0.0));
	float dz = h(p + vec2(0.0, e)) - h(p - vec2(0.0, e));
	ALBEDO = vec3(0.008, 0.011, 0.014);
	ROUGHNESS = 0.05;
	SPECULAR = 0.6;
	NORMAL_MAP = normalize(vec3(-dx * 1.2, -dz * 1.2, 1.0)) * 0.5 + 0.5;
}
"""
const CORRUGATED := """shader_type spatial;
// a shed's corrugated cladding: ribs along each face, streaks of grime down from the eaves
uniform vec3 paint : source_color = vec3(0.35, 0.37, 0.38);
varying vec3 lp;
varying vec3 ln;
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 13758.5453); }
void vertex() { lp = VERTEX; ln = NORMAL; }
void fragment() {
	bool side = abs(ln.x) > 0.5;
	bool roof = abs(ln.y) > 0.5;
	float along = side ? lp.z : lp.x;
	float rib = roof ? sin(lp.x * 8.0) : sin(along * 8.0);
	vec3 bump = side ? vec3(0.0, 0.0, rib * 0.3) : vec3(rib * 0.3, 0.0, 0.0);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * MODEL_MATRIX * vec4(bump, 0.0)).xyz);
	float streak = hash(vec2(floor(along * 1.5), 3.0)) * smoothstep(-2.0, 4.0, lp.y);
	ALBEDO = paint * (0.82 + 0.18 * rib) * (1.0 - 0.45 * streak);
	ROUGHNESS = 0.5 + 0.25 * streak;
	METALLIC = 0.35;
}
"""
static var _deck_shader: Shader
static var _water_shader: Shader
static var _corrugated: Shader


static func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.05)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## A box from a to b (its long axis along them), `w` wide and deep: a beam, a brace, a stay.
static func _beam(parent: Node3D, a: Vector3, b: Vector3, w: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var len := a.distance_to(b)
	bm.size = Vector3(w, w, len)
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	var dir := (b - a) / maxf(len, 0.001)
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(dir, up), (a + b) * 0.5)
	return mi


## "quay": the set's deck, a level slab whose top is the shot's ground ("rect": [x0, z0, x1, z1] m in
## its frame), walled on every side down into the water ("depth" m below the top, default
## StoryScene.SET_DECK less a hand), the water all round it ("water" m beyond its edges); "edges": the
## sides where boats would tie up ("x0", "x1", "z0", "z1": bollards every "bollards" m, a yellow
## line along them); "paint": [[x0, z0, x1, z1, width, "#colour"], ...] the yard's lines; "walls": false
## for the wet ground alone (a street's, laid a hand over the map's: "pos": [0, 0.01, 0]), no walls or water.
static func _quay(p: Dictionary) -> Node3D:
	if _deck_shader == null:
		_deck_shader = Shader.new()
		_deck_shader.code = DECK_SHADER
		_water_shader = Shader.new()
		_water_shader.code = WATER_SHADER
	var root := Node3D.new()
	root.name = "Quay"
	var r: Array = p.get("rect", [-100.0, -100.0, 100.0, 100.0])
	var x0 := float(r[0])
	var z0 := float(r[1])
	var x1 := float(r[2])
	var z1 := float(r[3])
	var depth := float(p.get("depth", 1.85))
	var centre := Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
	var size := Vector2(x1 - x0, z1 - z0)
	var deck := MeshInstance3D.new()
	deck.name = "Deck"
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 0
	pm.subdivide_depth = 0
	deck.mesh = pm
	deck.position = centre
	var dm := ShaderMaterial.new()
	dm.shader = _deck_shader
	dm.set_shader_parameter("offset", Vector2(centre.x, centre.z))
	var edges: Array = p.get("edges", [])
	var lines: Array = []
	var styles: Array = []
	for l: Array in p.get("paint", []):
		lines.append(Vector4(float(l[0]), float(l[1]), float(l[2]), float(l[3])))
		var c := Color(String(l[5])) if l.size() > 5 else Color("d9a31e")
		styles.append(Vector4(c.r, c.g, c.b, float(l[4]) if l.size() > 4 else 0.15))
	var inset := 0.9
	for e: String in edges:
		var seg: Vector4 = {"x0": Vector4(x0 + inset, z0, x0 + inset, z1), "x1": Vector4(x1 - inset, z0, x1 - inset, z1),
			"z0": Vector4(x0, z0 + inset, x1, z0 + inset), "z1": Vector4(x0, z1 - inset, x1, z1 - inset)}.get(e, Vector4.ZERO)
		lines.append(seg)
		styles.append(Vector4(0.85, 0.64, 0.12, 0.3))
	while lines.size() > 24:
		lines.pop_back()
		styles.pop_back()
	dm.set_shader_parameter("line_count", lines.size())
	while lines.size() < 24:
		lines.append(Vector4.ZERO)
		styles.append(Vector4.ZERO)
	dm.set_shader_parameter("lines", lines)
	dm.set_shader_parameter("line_style", styles)
	dm.set_shader_parameter("wetness", float(p.get("wetness", 1.0)))
	deck.material_override = dm
	root.add_child(deck)
	if not bool(p.get("walls", true)):
		return root                       # the ground alone: a wet street under a set ("walls": false)
	# the quay walls: concrete, a dark wet band at the waterline, a pale capping on top
	var concrete := _mat(Color(0.2, 0.2, 0.2), 0.85, 0.0)
	var cap := _mat(Color(0.42, 0.41, 0.39), 0.75, 0.0)
	var low := depth + 1.5
	for e in [[Vector3(x0, 0, z0), Vector3(x1, 0, z0)], [Vector3(x0, 0, z1), Vector3(x1, 0, z1)],
			[Vector3(x0, 0, z0), Vector3(x0, 0, z1)], [Vector3(x1, 0, z0), Vector3(x1, 0, z1)]]:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var along_x := absf(b.x - a.x) > 0.1
		var wall_size := Vector3(absf(b.x - a.x) + 1.2, low, 1.2) if along_x else Vector3(1.2, low, absf(b.z - a.z) + 1.2)
		_box(root, (a + b) * 0.5 + Vector3(0.0, -low * 0.5 - 0.02, 0.0), wall_size, concrete)
		var cap_size := Vector3(wall_size.x, 0.12, wall_size.z)
		_box(root, (a + b) * 0.5 + Vector3(0.0, -0.04, 0.0), cap_size, cap)
	# bollards along the working edges
	var iron := _mat(Color(0.06, 0.06, 0.065), 0.45, 0.7)
	var every := float(p.get("bollards", 18.0))
	for e: String in edges:
		var a := Vector3(x0 + 0.5, 0.0, z0) if e == "x0" else (Vector3(x1 - 0.5, 0.0, z0) if e == "x1" else Vector3(x0, 0.0, z0 + 0.5 if e == "z0" else z1 - 0.5))
		var b := Vector3(a.x, 0.0, z1) if e in ["x0", "x1"] else Vector3(x1, 0.0, a.z)
		var n := int(a.distance_to(b) / every)
		for k in n:
			var at := a.lerp(b, (k + 0.5) / float(n))
			var bol := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.22
			cyl.bottom_radius = 0.3
			cyl.height = 0.7
			cyl.radial_segments = 12
			bol.mesh = cyl
			bol.material_override = iron
			bol.position = at + Vector3(0.0, 0.35, 0.0)
			root.add_child(bol)
	# the water: out to "water" m past every edge, a hand above the map's own ground
	var water := MeshInstance3D.new()
	water.name = "Water"
	var wm := PlaneMesh.new()
	var reach := float(p.get("water", 900.0))
	wm.size = size + Vector2(reach, reach) * 2.0
	water.mesh = wm
	water.position = centre + Vector3(0.0, -depth, 0.0)
	var wsm := ShaderMaterial.new()
	wsm.shader = _water_shader
	water.material_override = wsm
	water.set_meta("water", true)
	root.add_child(water)
	return root


## "sts_crane": a ship-to-shore gantry crane, its boom out over the water along +x from the quay's
## edge at its origin ("height" of the portal m, "outreach" over the water, "colour"): legs, portal,
## a lattice boom, the A-frame and its stays, the machinery house, the trolley and its spreader
## hanging, lamps under the boom and a red light on top.
static func _sts_crane(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var h := float(p.get("height", 40.0))
	var out := float(p.get("outreach", 48.0))
	var back := 22.0
	var gauge := 28.0                       # legs across the quay (x)
	var wide := 17.0                        # legs along it (z)
	var red := _mat(Color(String(p.get("colour", "#b0302a"))), 0.55, 0.5)
	var white := _mat(Color(0.82, 0.82, 0.8), 0.55, 0.4)
	var dark := _mat(Color(0.12, 0.12, 0.13), 0.6, 0.5)
	for x: float in [-1.5, -1.5 - gauge]:
		for z: float in [-wide * 0.5, wide * 0.5]:
			_box(root, Vector3(x, h * 0.5, z), Vector3(1.6, h, 1.6), red)
			_box(root, Vector3(x, 0.6, z), Vector3(3.2, 1.2, 6.0), dark)            # the bogies on the rail
		_box(root, Vector3(x, h, 0.0), Vector3(1.8, 2.2, wide + 1.6), red)
		_box(root, Vector3(x, h * 0.45, 0.0), Vector3(1.0, 1.0, wide), red)
	for z: float in [-wide * 0.5, wide * 0.5]:
		_box(root, Vector3(-1.5 - gauge * 0.5, h, z), Vector3(gauge + 1.6, 2.2, 1.8), red)
	# the boom: two chords each side, braced every 5 m
	var y0 := h + 2.0
	var y1 := h + 6.0
	for z: float in [-2.2, 2.2]:
		_beam(root, Vector3(-1.5 - gauge - back, y0, z), Vector3(out, y0, z), 0.8, white)
		_beam(root, Vector3(-1.5 - gauge - back, y1, z), Vector3(out - 6.0, y1, z), 0.6, white)
		var x := -1.5 - gauge - back
		var up := true
		while x < out - 6.0:
			var nx := minf(x + 5.0, out - 6.0)
			_beam(root, Vector3(x, y0 if up else y1, z), Vector3(nx, y1 if up else y0, z), 0.3, white)
			x = nx
			up = not up
	# the A-frame and its stays to the boom's ends
	var apex := Vector3(-1.5 - gauge * 0.5, h + 26.0, 0.0)
	for z: float in [-wide * 0.5, wide * 0.5]:
		_beam(root, Vector3(-1.5, h + 1.0, z), apex + Vector3(4.0, 0.0, z * 0.3), 1.0, red)
		_beam(root, Vector3(-1.5 - gauge, h + 1.0, z), apex + Vector3(-4.0, 0.0, z * 0.3), 1.0, red)
	_box(root, apex, Vector3(9.0, 1.2, wide * 0.3 + 1.0), red)
	for z: float in [-2.2, 2.2]:
		_beam(root, apex + Vector3(4.0, 0.0, z), Vector3(out - 2.0, y1, z), 0.25, dark)
		_beam(root, apex + Vector3(-4.0, 0.0, z), Vector3(-1.5 - gauge - back + 2.0, y1, z), 0.25, dark)
	_box(root, Vector3(-1.5 - gauge - back * 0.5, y1 + 3.0, 0.0), Vector3(12.0, 5.0, 7.0), white)       # the machinery house
	# the trolley, out over the water, its spreader hanging low
	var tx := out * 0.45
	_box(root, Vector3(tx, y0 - 1.0, 0.0), Vector3(5.0, 2.0, 5.6), dark)
	var drop := float(p.get("hook", h * 0.55))
	for z: float in [-1.2, 1.2]:
		_box(root, Vector3(tx, y0 - 2.0 - drop * 0.5, z), Vector3(0.08, drop, 0.08), dark)
	_box(root, Vector3(tx, y0 - 2.0 - drop, 0.0), Vector3(2.6, 0.8, 12.4), _mat(Color(0.75, 0.6, 0.1), 0.5, 0.4))
	# lamps under the boom, a few lighting the quay; the red light on top
	var lamp := _emissive(Color("#ffd9a8"), 6.0)
	var x := 0.0
	var k := 0
	while x < out:
		_box(root, Vector3(x, y0 - 0.6, 0.0), Vector3(0.8, 0.3, 0.8), lamp)
		if k % 3 == 0:
			var s := SpotLight3D.new()
			s.light_color = Color("#ffd9a8")
			s.light_energy = float(p.get("energy", 5.0))
			s.spot_range = h * 1.6
			s.spot_angle = 40.0
			s.shadow_enabled = false
			s.position = Vector3(x, y0 - 0.8, 0.0)
			s.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
			root.add_child(s)
		x += 9.0
		k += 1
	_box(root, apex + Vector3(0.0, 1.0, 0.0), Vector3(0.6, 0.6, 0.6), _emissive(Color(1.0, 0.08, 0.04), 12.0))
	return root


## "warehouse": a shed on the quay ("size": [w (x), h, d (z)], "colour"): corrugated walls, a low
## pitched roof, roller doors along its +z face ("doors"), the ones in "lit" open on a warm inside,
## a sodium lamp over each door lighting the apron.
static func _warehouse(p: Dictionary) -> Node3D:
	if _corrugated == null:
		_corrugated = Shader.new()
		_corrugated.code = CORRUGATED
	var root := Node3D.new()
	var sz: Array = p.get("size", [40.0, 9.0, 24.0])
	var w := float(sz[0])
	var h := float(sz[1])
	var d := float(sz[2])
	var wall := ShaderMaterial.new()
	wall.shader = _corrugated
	wall.set_shader_parameter("paint", Color(String(p.get("colour", "#4d5559"))))
	_box(root, Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d), wall)
	var roof := ShaderMaterial.new()
	roof.shader = _corrugated
	roof.set_shader_parameter("paint", Color(0.22, 0.23, 0.24))
	var rise := d * 0.12
	for side: float in [-1.0, 1.0]:
		var slab := _box(root, Vector3(0.0, h + rise * 0.5, side * d * 0.25), Vector3(w + 0.8, 0.25, d * 0.52), roof)
		slab.rotation.x = side * atan2(rise, d * 0.5)
	var doors := int(p.get("doors", 3))
	var lit: Array = p.get("lit", [])
	var shutter := _mat(Color(0.3, 0.31, 0.3), 0.6, 0.5)
	var sodium := Color(String(p.get("lamp", "#ff9d3c")))
	for k in doors:
		var x := (k - (doors - 1) * 0.5) * (w / doors)
		var open := lit.any(func(v: Variant) -> bool: return int(v) == k)
		var dw := minf(6.0, w / doors - 2.0)
		var dh := minf(5.5, h - 2.0)
		if open:
			_box(root, Vector3(x, dh * 0.5, d * 0.5 + 0.01), Vector3(dw, dh, 0.02), _emissive(Color("#ffc58a"), 1.6))
			_box(root, Vector3(x, dh + 0.45, d * 0.5 + 0.05), Vector3(dw, 0.9, 0.08), shutter)
			var spill := OmniLight3D.new()
			spill.light_color = Color("#ffbf80")
			spill.light_energy = 3.0
			spill.omni_range = 9.0
			spill.shadow_enabled = false
			spill.position = Vector3(x, dh * 0.5, d * 0.5 + 1.2)
			root.add_child(spill)
		else:
			_box(root, Vector3(x, dh * 0.5, d * 0.5 + 0.03), Vector3(dw, dh, 0.06), shutter)
		_box(root, Vector3(x, dh + 1.4, d * 0.5 + 0.35), Vector3(0.6, 0.25, 0.5), _emissive(sodium, 6.0))
		var s := SpotLight3D.new()
		s.light_color = sodium
		s.light_energy = 3.0
		s.spot_range = 14.0
		s.spot_angle = 55.0
		s.shadow_enabled = false
		s.position = Vector3(x, dh + 1.2, d * 0.5 + 0.5)
		s.rotation = Vector3(-PI * 0.5 + 0.35, 0.0, 0.0)
		root.add_child(s)
	return root


## "portacabin": the yard's office, its "sign" on a board on the roof, its windows lit ("lit"),
## a door and steps on its +z face.
static func _portacabin(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var body := _mat(Color(0.72, 0.72, 0.68), 0.7, 0.1)
	_box(root, Vector3(0.0, 1.55, 0.0), Vector3(7.2, 2.6, 2.6), body)
	_box(root, Vector3(0.0, 0.12, 0.0), Vector3(7.0, 0.24, 2.4), _mat(Color(0.1, 0.1, 0.1)))
	var lit := bool(p.get("lit", true))
	var glass: Material = _emissive(Color("#ffd6a0"), 1.4) if lit else _mat(Color(0.05, 0.06, 0.07), 0.1, 0.0)
	for x: float in [-2.4, 1.0]:
		_box(root, Vector3(x, 1.8, 1.31), Vector3(1.6, 0.9, 0.02), glass)
	_box(root, Vector3(2.7, 1.3, 1.31), Vector3(0.9, 2.0, 0.03), _mat(Color(0.35, 0.36, 0.38), 0.5, 0.4))
	_box(root, Vector3(2.7, 0.2, 1.75), Vector3(1.2, 0.4, 0.8), _mat(Color(0.25, 0.25, 0.26), 0.6, 0.6))
	if lit:
		var spill := OmniLight3D.new()
		spill.light_color = Color("#ffcf96")
		spill.light_energy = 1.2
		spill.omni_range = 6.0
		spill.position = Vector3(-0.7, 1.8, 2.2)
		root.add_child(spill)
	var sign := String(p.get("sign", ""))
	if not sign.is_empty():
		_box(root, Vector3(0.0, 3.3, 1.0), Vector3(5.2, 0.9, 0.12), _mat(Color(0.08, 0.1, 0.16), 0.6, 0.2))
		var l := Label3D.new()
		l.text = sign
		l.font = TmUi.font(SfUi.BLACK, 3)
		l.font_size = 64
		l.pixel_size = 0.006
		l.modulate = Color(0.92, 0.9, 0.85)
		l.outline_size = 0
		l.position = Vector3(0.0, 3.3, 1.07)
		root.add_child(l)
		var s := SpotLight3D.new()
		s.light_color = Color("#ffe0b0")
		s.light_energy = 2.0
		s.spot_range = 4.0
		s.spot_angle = 50.0
		s.position = Vector3(0.0, 4.1, 1.8)
		s.rotation = Vector3(-PI * 0.5 + 0.45, 0.0, 0.0)
		root.add_child(s)
	return root


## "stage": the auctioneer's low platform ("size": [w, d], "height"), a truss across its back with
## two lamp heads aimed at its front ("energy", "colour").
static func _stage(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var sz: Array = p.get("size", [5.0, 3.0])
	var w := float(sz[0])
	var d := float(sz[1])
	var h := float(p.get("height", 0.6))
	_box(root, Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d), _mat(Color(0.07, 0.07, 0.075), 0.8, 0.0))
	_box(root, Vector3(0.0, h * 0.25, d * 0.5 + 0.4), Vector3(1.4, h * 0.5, 0.8), _mat(Color(0.09, 0.09, 0.09), 0.8, 0.0))
	var steel := _mat(Color(0.62, 0.62, 0.64), 0.35, 0.85)
	var th := float(p.get("truss", 4.2))
	for x: float in [-w * 0.5 - 0.2, w * 0.5 + 0.2]:
		for c in 4:
			_box(root, Vector3(x + (0.15 if c % 2 == 0 else -0.15), th * 0.5, -d * 0.5 + (0.15 if c < 2 else -0.15)), Vector3(0.05, th, 0.05), steel)
		var y := 0.0
		while y < th:
			_beam(root, Vector3(x - 0.15, y, -d * 0.5), Vector3(x + 0.15, y + 0.4, -d * 0.5), 0.03, steel)
			y += 0.4
	for c in 4:
		_box(root, Vector3(0.0, th + (0.15 if c % 2 == 0 else -0.15), -d * 0.5 + (0.15 if c < 2 else -0.15)), Vector3(w + 0.7, 0.05, 0.05), steel)
	var colour := Color(String(p.get("colour", "#fff1dc")))
	for x: float in [-w * 0.3, w * 0.3]:
		_box(root, Vector3(x, th - 0.35, -d * 0.5 + 0.2), Vector3(0.35, 0.4, 0.45), _mat(Color(0.05, 0.05, 0.05), 0.5, 0.5))
		var s := SpotLight3D.new()
		s.light_color = colour
		s.light_energy = float(p.get("energy", 8.0))
		s.spot_range = 14.0
		s.spot_angle = 26.0
		s.spot_angle_attenuation = 0.8
		s.shadow_enabled = true
		var at := Vector3(x, th - 0.4, -d * 0.5 + 0.4)
		s.transform = Transform3D(Basis.looking_at(Vector3(-x * 0.4, h + 1.4, d * 0.5 + 1.0) - at, Vector3.UP), at)
		root.add_child(s)
	return root


## "barrel": an oil drum, a fire in it ("fire": true) whose light flickers with the scene's time.
static func _barrel(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var drum := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.29
	cyl.bottom_radius = 0.29
	cyl.height = 0.88
	cyl.radial_segments = 16
	drum.mesh = cyl
	drum.material_override = _mat(Color(0.2, 0.08, 0.04), 0.8, 0.5)
	drum.position = Vector3(0.0, 0.44, 0.0)
	root.add_child(drum)
	if bool(p.get("fire", true)):
		var flame := _emissive(Color("#ff8a2a"), 5.0)
		for k in 3:
			var f := _box(root, Vector3((k - 1) * 0.08, 1.0 + k * 0.04, 0.0), Vector3(0.22, 0.3 + k * 0.08, 0.22), flame)
			f.rotation.y = k * 0.7
		var l := OmniLight3D.new()
		l.name = "Fire"
		l.light_color = Color("#ff9440")
		l.light_energy = float(p.get("energy", 2.5))
		l.omni_range = float(p.get("range", 7.0))
		l.shadow_enabled = true
		l.position = Vector3(0.0, 1.25, 0.0)
		l.set_meta("fire", l.light_energy)
		root.add_child(l)
	return root


## "fence": chain-link between "from" and "to" ([x, z] m in the shot's frame, so "pos" stays at
## the origin), "height", posts every 3 m.
static func _fence(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	var a: Array = p.get("from", [0.0, 0.0])
	var b: Array = p.get("to", [10.0, 0.0])
	var pa := Vector3(float(a[0]), 0.0, float(a[1]))
	var pb := Vector3(float(b[0]), 0.0, float(b[1]))
	var h := float(p.get("height", 2.4))
	var steel := _mat(Color(0.45, 0.46, 0.47), 0.4, 0.8)
	var n := maxi(1, int(pa.distance_to(pb) / 3.0))
	for k in n + 1:
		_box(root, pa.lerp(pb, float(k) / n) + Vector3(0.0, h * 0.5, 0.0), Vector3(0.06, h, 0.06), steel)
	_beam(root, pa + Vector3(0.0, h, 0.0), pb + Vector3(0.0, h, 0.0), 0.05, steel)
	var mesh := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(pa.distance_to(pb), h)
	mesh.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.52, 0.54)
	m.metallic = 0.7
	m.roughness = 0.4
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _chain_link()
	m.uv1_scale = Vector3(pa.distance_to(pb) / 0.6, h / 0.6, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mesh.material_override = m
	var dir := (pb - pa).normalized()
	mesh.transform = Transform3D(Basis(dir, Vector3.UP, dir.cross(Vector3.UP)), (pa + pb) * 0.5 + Vector3(0.0, h * 0.5, 0.0))
	root.add_child(mesh)
	return root


static var _chain: ImageTexture


## A chain-link fence's diamond, one tile: wire where |x| + |y| is near a multiple of the cell.
static func _chain_link() -> ImageTexture:
	if _chain != null:
		return _chain
	var n := 32
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := float(x) / n
			var v := float(y) / n
			var d := minf(absf(fposmod(u + v, 1.0) - 0.5), absf(fposmod(u - v, 1.0) - 0.5))
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if d > 0.44 else 0.0))
	img.generate_mipmaps()
	_chain = ImageTexture.create_from_image(img)
	return _chain
