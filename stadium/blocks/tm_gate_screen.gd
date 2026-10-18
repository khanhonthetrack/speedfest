class_name TmGateScreen
extends Node3D
## A gate's LED screen in the crown of its arch, on both faces (the review's gate option B: no sign
## boards on top), and a spotlight in the gate's colour on the road under it. The screen shows the
## gate's word (START / CHECKPOINT / FINISH); when the car passes, the race (race.gd) puts its time
## there with the difference to the record, as TM2020's checkpoints do. Built in TMNF block-local
## coordinates under the gate's sheared holder (TmGateDress). One SubViewport per gate, redrawn
## only when its text changes. Blocks are built once per shape and duplicated (TmBlockLib), so the
## node keeps only its settings (exported, copied by duplicate()) and builds itself in _ready.

const RoadShapes := preload("res://blocks/shapes/road.gd")
const X0 := 10.8                    ## the screen's ends along the arch (TMNF x)
const X1 := 21.2
const INSET_TOP := 0.14             ## below the arch's outer line, above its inner line (m)
const INSET_BOTTOM := 0.16
const PROUD := 0.025                ## in front of the arch's face (m)
const SEGMENTS := 24
const PIXELS := Vector2i(1024, 112)
const GROUP := "tm_gate_screens"
const WORDS := {"start": "START", "cp": "CHECKPOINT", "finish": "FINISH", "lap": "FINISH"}
const LIGHT_ENERGY := 5.0

@export var kind := "cp"
@export var colour := Color.WHITE
@export var zc := 16.0                ## the gate's centre along the block (TMNF z)
var _view: SubViewport
var _main: Label
var _side: Label
var _mat: ShaderMaterial


## Adds the screen and the spotlight of a gate at zc under `holder` (TMNF block-local, sheared).
static func add(holder: Node3D, gate_kind: String, zc: float, gate_colour: Color) -> TmGateScreen:
	var s := TmGateScreen.new()
	s.name = "GateScreen"
	s.kind = gate_kind
	s.colour = gate_colour
	s.zc = zc
	holder.add_child(s)
	return s


func _ready() -> void:
	_build()
	# drawn once now that it is in the tree, then again only when the text changes
	_mat.set_shader_parameter("screen_tex", _view.get_texture())
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _build() -> void:
	_view = SubViewport.new()
	_view.size = PIXELS
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_view)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0)
	bg.size = Vector2(PIXELS)
	_view.add_child(bg)
	for y: int in [6, PIXELS.y - 10]:
		var rule := ColorRect.new()
		rule.color = colour * 0.55
		rule.position = Vector2(24, y)
		rule.size = Vector2(PIXELS.x - 48, 4)
		_view.add_child(rule)
	_main = _label(78, HORIZONTAL_ALIGNMENT_CENTER)
	_side = _label(64, HORIZONTAL_ALIGNMENT_RIGHT)
	show_word()
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://blocks/tm_led_screen.gdshader")
	for face: float in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = _band(zc + face * (2.1 + PROUD), face)
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	var lamp := SpotLight3D.new()
	lamp.light_color = colour
	lamp.light_energy = LIGHT_ENERGY
	lamp.spot_range = 13.0
	lamp.spot_angle = 52.0
	lamp.spot_attenuation = 0.6
	lamp.shadow_enabled = false
	lamp.light_volumetric_fog_energy = 0.0
	lamp.position = TmGeo.g(Vector3(16.0, 6.9, zc))
	lamp.basis = Basis(Vector3.RIGHT, -PI * 0.5)    # pointing down
	add_child(lamp)
	add_to_group(GROUP)


func _label(px: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", TmUi.font(TmUi.TITLE, 4))
	l.add_theme_font_size_override("font_size", px)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(40, 8)
	l.size = Vector2(PIXELS.x - 80, PIXELS.y - 16)
	_view.add_child(l)
	return l


## The gate's word in its colour (also after a restart).
func show_word() -> void:
	_show(String(WORDS.get(kind, "CHECKPOINT")), colour.lightened(0.15), "", Color.WHITE)


## The car's time at this gate, and the difference to the record (blue ahead, red behind).
func show_time(time_text: String, delta_text := "", delta_colour := Color.WHITE) -> void:
	_show(time_text, Color(0.96, 0.97, 1.0), delta_text, delta_colour)


func _show(main: String, main_colour: Color, side: String, side_colour: Color) -> void:
	_main.text = main
	_main.add_theme_color_override("font_color", main_colour)
	_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if side.is_empty() else HORIZONTAL_ALIGNMENT_LEFT
	_side.text = side
	_side.add_theme_color_override("font_color", side_colour)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE


## The screens of the gate the car is passing (within a few metres of `at`, horizontally).
static func near(tree: SceneTree, at: Vector3, reach := 12.0) -> Array[TmGateScreen]:
	var out: Array[TmGateScreen] = []
	for n in tree.get_nodes_in_group(GROUP):
		var s := n as TmGateScreen
		var d := s.global_transform * TmGeo.g(Vector3(16.0, 8.0, s.zc)) - at
		if Vector2(d.x, d.z).length() < reach and absf(d.y) < 20.0:
			out.append(s)
	return out


## Every gate back to its word (a restart).
static func reset_all(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group(GROUP):
		(n as TmGateScreen).show_word()


## The screen: a strip across the arch's crown between its outer and inner lines, at z (TMNF),
## facing -z (face -1) or +z (face 1); u reads left to right from in front of that face.
func _band(z: float, face: float) -> ArrayMesh:
	var lines: Array = RoadShapes._arch_lines()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nrm := Vector3(0, 0, face)
	var rows := []
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var x := lerpf(X0, X1, t)
		var top := _y_at(lines[0], x) - INSET_TOP
		var bot := _y_at(lines[1], x) + INSET_BOTTOM
		var u := t if face < 0.0 else 1.0 - t
		rows.append([TmGeo.g(Vector3(x, top, z)), TmGeo.g(Vector3(x, bot, z)), u])
	for i in SEGMENTS:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		var quad := [[a[0], Vector2(a[2], 0.0)], [b[0], Vector2(b[2], 0.0)], [b[1], Vector2(b[2], 1.0)], [a[1], Vector2(a[2], 1.0)]]
		# clockwise as seen from the face's side (Godot's front faces)
		var order := [0, 1, 2, 0, 2, 3] if face < 0.0 else [0, 2, 1, 0, 3, 2]
		for k: int in order:
			st.set_normal(nrm)
			st.set_uv(quad[k][1])
			st.add_vertex(quad[k][0])
	return st.commit()


## y of a polyline running left to right in x, at x.
static func _y_at(line: Array, x: float) -> float:
	for i in line.size() - 1:
		var p: Vector2 = line[i]
		var q: Vector2 = line[i + 1]
		if x >= p.x and x <= q.x and q.x > p.x:
			return lerpf(p.y, q.y, (x - p.x) / (q.x - p.x))
	return (line[0] as Vector2).y
