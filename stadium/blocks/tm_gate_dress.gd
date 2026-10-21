class_name TmGateDress
extends RefCounted
## What a gate adds beyond its block's faces (the arch, with the gate's word on its faces and
## TMNF's atlas strips on its top and underside, the gate block's curbs, and the road's paint: TMNF's line
## across it and its start / finish roads, are in blocks/shapes/road.gd _gate): an LED screen in
## the crown and a spotlight in the kind's colour (`crown`, TmGateScreen). Visual only. Built in
## TMNF block-local coordinates like the block, then sheared with it (sloped and banked
## checkpoints).

const KINDS := {
	"start": [Color(0.30, 1.00, 0.45), "START"],
	"finish": [Color(1.00, 0.22, 0.18), "FINISH"],
	"cp": [Color(0.25, 0.82, 1.00), "CHECKPOINT"],
	"lap": [Color(1.00, 0.22, 0.18), "FINISH"],      # a start/finish line: where our races end
}


## The gate's kind for a road shape name ("" if it has no gate).
static func kind_of(rest: String) -> String:
	if rest.begins_with("Start/"):
		return "start"
	if rest.begins_with("Finish/"):
		return "finish"
	if rest.begins_with("MultiLap/"):
		return "lap"
	return "cp"


## Adds a gate's dress at zc under `root`, sheared like the block (TmGeo.sheared: kx, kz, dy in
## TMNF coordinates).
static func dress(root: Node3D, kind: String, zc: float, shear := Vector3.ZERO) -> void:
	crown(root, kind, zc, shear, true)


## The gate's crown screen and spotlight (TmGateScreen) under `root` (already sheared like the
## block, or pass `shear` for a holder of its own, and `size` for a gate resized about its centre
## line and zc: TmGeo.scale_move, the dirt roads' gates).
static func crown(root: Node3D, kind: String, zc: float, shear := Vector3.ZERO, own_holder := false,
		size := Vector3.ONE) -> void:
	var holder := root
	if own_holder:
		holder = Node3D.new()
		holder.name = "GateCrown"
		var sh := Basis(Vector3(1, -shear.x, 0), Vector3(0, 1, 0), Vector3(0, shear.y, 1))
		var k := Basis.from_scale(size)
		var c := Vector3(-16.0, 0.0, zc)        # the centre line (Godot's x is TMNF's negated)
		holder.transform = Transform3D(sh * k, Vector3(0, shear.z, 0) + sh * (c - k * c))
		root.add_child(holder)
	var spec: Array = KINDS.get(kind, KINDS["cp"])
	TmGateScreen.add(holder, "finish" if kind == "lap" else kind, zc, spec[0])


## The arch's inner (underside) line, from one foot to the other (the "metal" points of GATE_ARCH).
static func _arch_inner() -> Array:
	var out := []
	for q: Array in load("res://blocks/shapes/road.gd").GATE_ARCH:
		if String(q[2]) == "metal" or (out.size() > 0 and String(q[2]) == "structure" and int(q[3]) == 4 and float(q[1]) < 4.0):
			out.append(Vector2(float(q[0]), float(q[1])))
	return out
