extends RefCounted
## Stadium "Pylon" blocks (PylonStadium, the editor's pylons that some older tracks keep as blocks):
## thin octagonal posts (measured: Pylon/Straight 0.85 x 1.64 m, 8 m a level; Pylon/Start a 2 m
## foot on the ground). TMNF builds them from those pieces; the block's variant (0..14) reads as a
## mask (variant + 1) of four posts, one by each side of the block, 2.8 m in from its edge (our
## reading of the 15 variants and the pieces' offset; the block info keeps no geometry).
## Shapes: "Pylon/V<variant>Ground", "Pylon/V<variant>Air" (blocks/data/block_catalogue.json).

const S_METAL := 4
const POST_X := 2.825           ## the post's centre, in from the block's -x side (TMNF x)
const POST := [[0.425, 0.0], [0.375, 0.6], [0.0, 0.82], [-0.375, 0.6], [-0.425, 0.0], [-0.375, -0.6],
	[0.0, -0.82], [0.375, -0.6]]   ## octagon (x, z) about the centre
const FOOT_SCALE := 1.12        ## the foot (Pylon/Start) is a little wider, 2 m tall


func handles(shape: String) -> bool:
	if not shape.begins_with("Pylon/V"):
		return false
	var v := int(shape.trim_prefix("Pylon/V").trim_suffix("Ground").trim_suffix("Air"))
	return v >= 0 and v <= 14


func make(shape: String, _entry: Dictionary, _ground: bool) -> Node3D:
	var mask := int(shape.trim_prefix("Pylon/V").trim_suffix("Ground").trim_suffix("Air")) + 1
	var ground := shape.ends_with("Ground")
	var geo := TmGeo.new()
	for k in 4:
		if mask & (1 << k) == 0:
			continue
		var post := TmGeo.new()
		_prism(post, 1.0, 0.0, 8.0)
		if ground:
			_prism(post, FOOT_SCALE, 0.0, 2.0)
		post.turn_y(k, Vector2(16, 16))
		geo.merge(post)
	return geo.build()


## An octagonal prism about (POST_X, 16), scaled, from y0 to y1, with its top.
func _prism(geo: TmGeo, scale: float, y0: float, y1: float) -> void:
	var n := POST.size()
	for i in n:
		var a: Array = POST[i]
		var b: Array = POST[(i + 1) % n]
		var pa := Vector3(POST_X + float(a[0]) * scale, 0, 16.0 + float(a[1]) * scale)
		var pb := Vector3(POST_X + float(b[0]) * scale, 0, 16.0 + float(b[1]) * scale)
		geo.quad(Vector3(pa.x, y0, pa.z), Vector3(pa.x, y1, pa.z), Vector3(pb.x, y1, pb.z), Vector3(pb.x, y0, pb.z), "structure", S_METAL)
		geo.tri(Vector3(POST_X, y1, 16.0), Vector3(pb.x, y1, pb.z), Vector3(pa.x, y1, pa.z), "structure", S_METAL)
