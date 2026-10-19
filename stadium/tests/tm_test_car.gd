class_name TmTestCar
extends RefCounted
## Test helper: a small TMNF car model of our own, written as TMNF's exporters write a CPlugSolid
## (binary, or the old text format), and a car pack around it like a ManiaPark one (a folder in a
## zip: MainBody.Solid.Gbx, a DXT1 Diffuse.dds with old exporters' header quirks, Details.png,
## EngineIdle.wav, a readme). Used by tests/test_car_pack and tests/test_online.

const CLASS_SOLID := 0x09005000
const CLASS_TREE := 0x0904F000
const CLASS_VISUAL := 0x0901E000
const FACADE := 0xFACADE01
## TMNF's car frame, which is ours (x left, FL at +x): [name, centre, half size].
const PARTS := [
	["sBody", Vector3(0.0, 0.6, 0.0), Vector3(0.8, 0.3, 2.0)],
	["dBody", Vector3(0.0, 1.0, -0.3), Vector3(0.5, 0.15, 0.8)],
	["dFLWheel", Vector3(0.8, 0.36, 1.4), Vector3(0.15, 0.36, 0.36)],
	["dFRWheel", Vector3(-0.8, 0.36, 1.4), Vector3(0.15, 0.36, 0.36)],
	["dRLWheel", Vector3(0.8, 0.36, -1.3), Vector3(0.15, 0.36, 0.36)],
	["dRRWheel", Vector3(-0.8, 0.36, -1.3), Vector3(0.15, 0.36, 0.36)],
	["ProjShad", Vector3(0.0, 0.01, 0.0), Vector3(1.0, 0.0, 2.2)],
]
const LAMP := ["LightRL", Vector3(0.6, 0.9, -2.0)]

var _text := false
var _out := PackedByteArray()
var _ids_written := false
var _next_node := 1




## The pack as zip bytes' file at path (an absolute path).
static func write_pack(path: String) -> void:
	var w := TmTestCar.new()
	w.zip(path, w.solid(false))


func zip(path: String, model: PackedByteArray) -> void:
	zip_files(path, {"MyCar/MainBody.Solid.Gbx": model, "MyCar/Diffuse.dds": _dds(), "MyCar/Details.png": _png(),
		"MyCar/EngineIdle.wav": _wav(), "MyCar/readme.txt": "a test car".to_utf8_buffer()})


## A zip of {name: bytes}; "diffuse" / "png" / "wav" as a value: that test file.
func zip_files(path: String, files: Dictionary) -> void:
	var z := ZIPPacker.new()
	z.open(path)
	for name: String in files:
		if files[name] is String:
			files[name] = {"diffuse": _dds(), "png": _png(), "wav": _wav()}[files[name]]
	for name: String in files:
		z.start_file(name)
		z.write_file(files[name])
		z.close_file()
	z.close()


## An 8 x 8 DXT1 image, levels 8, 4 and 2 (no 1 x 1), its header's linear size wrong.
func _dds() -> PackedByteArray:
	var d := PackedByteArray()
	d.resize(128)
	d.encode_u32(0, 0x20534444)        # "DDS "
	d.encode_u32(4, 124)
	d.encode_u32(8, 0xA1007)           # caps, height, width, pixel format, mipmap count, linear size
	d.encode_u32(12, 8)
	d.encode_u32(16, 8)
	d.encode_u32(20, 999)              # wrong (8 x 8 DXT1 is 32 bytes)
	d.encode_u32(28, 3)
	d.encode_u32(76, 32)
	d.encode_u32(80, 4)                # FOURCC
	d.encode_u32(84, 0x31545844)       # "DXT1"
	d.encode_u32(108, 0x401008)
	for i in 6:                        # 4 + 1 + 1 blocks, all red
		var b := PackedByteArray()
		b.resize(8)
		b.encode_u16(0, 0xF800)
		b.encode_u16(2, 0xF800)
		d.append_array(b)
	return d


func _png() -> PackedByteArray:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.25))
	return img.save_png_to_buffer()


func _wav() -> PackedByteArray:
	var n := 400
	var w := PackedByteArray()
	w.append_array("RIFF".to_ascii_buffer())
	var head := PackedByteArray()
	head.resize(4)
	head.encode_u32(0, 36 + 2 * n)
	w.append_array(head)
	w.append_array("WAVEfmt ".to_ascii_buffer())
	var fmt := PackedByteArray()
	fmt.resize(20)
	fmt.encode_u32(0, 16)
	fmt.encode_u16(4, 1)
	fmt.encode_u16(6, 1)
	fmt.encode_u32(8, 22050)
	fmt.encode_u32(12, 44100)
	fmt.encode_u16(16, 2)
	fmt.encode_u16(18, 16)
	w.append_array(fmt)
	w.append_array("data".to_ascii_buffer())
	var data := PackedByteArray()
	data.resize(4 + 2 * n)
	data.encode_u32(0, 2 * n)
	for i in n:
		data.encode_s16(4 + 2 * i, int(8000.0 * sin(i * 0.3)))
	w.append_array(data)
	return w


## The model as a GBX file: a tree with one part per PARTS entry (a box each, placed by its
## location) and a lamp marker; binary (uncompressed body) or text.
func solid(text: bool) -> PackedByteArray:
	_text = text
	_out = PackedByteArray()
	_ids_written = false
	_next_node = 1
	_out.append_array("GBX".to_ascii_buffer())
	_out.append_array(PackedByteArray([6, 0]))
	_out.append_array(("TUUE" if text else "BUUR").to_ascii_buffer())
	_hex(CLASS_SOLID)
	_u32(0)                 # header chunks
	_u32(16)                # nodes
	_u32(0)                 # external references
	_hex(0x09005011)
	_b(false)
	_b(false)
	_node_start(CLASS_TREE)
	_hex(0x0904F006)
	_u32(10)
	_u32(PARTS.size() + 1)
	for p: Array in PARTS:
		_part(String(p[0]), p[1], p[2])
	_node_start(CLASS_TREE)
	_name(String(LAMP[0]))
	_location(LAMP[1])
	_hex(FACADE)
	_hex(FACADE)            # the tree
	_hex(FACADE)            # the solid
	return _out


func _part(name: String, centre: Vector3, half: Vector3) -> void:
	_node_start(CLASS_TREE)
	_name(name)
	_location(centre)
	_hex(0x0904F016)
	_node_start(CLASS_VISUAL)
	var verts: Array[Vector3] = []
	for k in 8:
		verts.append(Vector3(half.x * (1 if k & 1 else -1), half.y * (1 if k & 2 else -1), half.z * (1 if k & 4 else -1)))
	if name.contains("Wheel"):
		verts[7] += Vector3(-1.2, 1.0, 0.0)   # a stray vertex, as some exporters leave: the axle stays the origin
	_hex(0x0900600D)
	_i32(0)                 # flags: normals and colours as floats
	_i32(1)                 # one UV set
	_i32(8)
	_u32(0)                 # no vertex streams
	_i32(0)                 # UV set version 0: raw (u, v)
	for v in verts:
		_raw_f32(v.x * 0.5 + 0.5)
		_raw_f32(v.z * 0.25 + 0.5)
	for f: float in [-half.x, -half.y, -half.z, half.x, half.y, half.z]:
		_f32(f)
	_hex(0x0902C004)
	for v in verts:
		for f: float in [v.x, v.y, v.z]:
			_f32(f)
		var n := v.normalized()
		for f: float in [n.x, n.y, n.z, 1.0, 1.0, 1.0, 1.0]:
			_f32(f)
	_u32(0)
	_u32(0)
	_hex(0x0906A001)
	_b(true)
	_hex(0x09057000)
	_data32(0)
	# the box's 12 triangles, counter-clockwise about their outward normals (TMNF's winding)
	var quads := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	var idx := PackedInt32Array()
	for q: Array in quads:
		idx.append_array([q[0], q[1], q[2], q[0], q[2], q[3]])
	_i32(idx.size())
	for k in idx:
		var b := PackedByteArray([0, 0])
		b.encode_u16(0, k)
		_out.append_array(b)
	_hex(FACADE)            # the index buffer
	_hex(FACADE)            # the visual
	_u32(0xFFFFFFFF)        # shader, surface, generator: none
	_u32(0xFFFFFFFF)
	_u32(0xFFFFFFFF)
	_hex(FACADE)            # the part


func _node_start(cls: int) -> void:
	_u32(_next_node)
	_next_node += 1
	_hex(cls)


func _name(name: String) -> void:
	_hex(0x0904F00D)
	if not _ids_written:
		_ids_written = true
		_u32(3)
	_hex(0x40000000)
	if _text:
		_line(name)
	else:
		_u32(name.length())
		_out.append_array(name.to_ascii_buffer())
	_hex(0xFFFFFFFF)


func _location(at: Vector3) -> void:
	_hex(0x0904F01A)
	_data32(4)
	for f: float in [1, 0, 0, 0, 1, 0, 0, 0, 1, at.x, at.y, at.z]:
		_f32(f)


func _line(s: String) -> void:
	_out.append_array((s + "\r\n").to_ascii_buffer())


func _u32(v: int) -> void:
	if _text:
		_line(str(v & 0xFFFFFFFF))
	else:
		_data32(v)


func _i32(v: int) -> void:
	_u32(v & 0xFFFFFFFF)


func _hex(v: int) -> void:
	if _text:
		_line("%x" % (v & 0xFFFFFFFF))
	else:
		_data32(v)


func _b(v: bool) -> void:
	if _text:
		_line("True" if v else "False")
	else:
		_data32(1 if v else 0)


func _f32(f: float) -> void:
	if _text:
		_line("%f" % f)
	else:
		_raw_f32(f)


func _raw_f32(f: float) -> void:
	var b := PackedByteArray([0, 0, 0, 0])
	b.encode_float(0, f)
	_out.append_array(b)


func _data32(v: int) -> void:
	var b := PackedByteArray([0, 0, 0, 0])
	b.encode_u32(0, v & 0xFFFFFFFF)
	_out.append_array(b)
