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

const CONTAINER := Vector3(2.44, 2.6, 12.2)      ## an ISO 40-foot box (m)
const RIBS := """shader_type spatial;
// a container's corrugated steel: vertical ribs along its length, paint worn to rust at the edges;
// one MultiMesh instance per box: INSTANCE_CUSTOM.rgb its paint, .a its own rust's seed
varying vec3 lp;
varying vec4 paint;
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 13758.5453); }
void vertex() { lp = VERTEX; paint = INSTANCE_CUSTOM; }
void fragment() {
	float along = abs(NORMAL.x) > 0.5 ? lp.z : lp.x;
	float rib = sin(along * 9.0);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(abs(NORMAL.x) > 0.5 ? vec3(0.0, 0.0, rib * 0.35) : vec3(rib * 0.35, 0.0, 0.0), 0.0)).xyz);
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
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 1))
	var pitch := Vector2(CONTAINER.x + float(gaps[0]), CONTAINER.z + float(gaps[1]))
	var boxes: Array = []
	for r in rows:
		for b in bays:
			var h := rng.randi_range(lo, hi)     # drawn for every stack, skipped or not: the rest stay put
			if [r, b] in skip:
				continue
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


## Moves what moves in a shot's props at its time (s into the shot): a train crosses its deck.
static func pose(parent: Node3D, local: float) -> void:
	for t: Node3D in parent.find_children("Train", "Node3D", true, false):
		var m: Array = t.get_meta("train", [0.0, 0.0])
		var run := (local - float(m[0])) * float(m[1])
		t.visible = run >= 0.0 and run < 260.0
		t.position.x = -120.0 + run
