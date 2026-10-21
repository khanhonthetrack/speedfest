class_name TmAirshipOrbit
extends Node3D
## A City map's airship (M14, owner: "on the freaking balloon if there is one": City maps had none):
## TMNF's airship (blocks/shapes/sculpt.gd, our livery; on City maps its belly's neon line, TmNeon)
## circling high round the Stadium, nose first, once every few minutes. No collision (it flies far
## above anything a car reaches). This node turns about the Stadium's centre; the airship sits on
## its rim.

const RADIUS := 640.0             ## m from the Stadium's centre
const ALTITUDE := 235.0           ## m over the field
const LAP_S := 260.0              ## s per lap
const AIRSHIP_MID := Vector3(16.04, 37.0, 116.0)   ## the model's middle (TMNF block frame; sculpt.gd)

var speed := TAU / LAP_S


## The orbit with the airship on it, or null when the airship shape isn't there.
static func make(night: bool) -> TmAirshipOrbit:
	var lib := TmBlockLib.new()
	var ship := lib.make("Other/Airship", TmBlockCatalogue.info("StadiumAirship"), false)
	if ship == null:
		return null
	_strip_collision(ship)
	var orbit := TmAirshipOrbit.new()
	orbit.name = "Airship"
	orbit.position = TmGeo.g(TmStadiumBuild.CENTRE) + Vector3(0.0, ALTITUDE, 0.0)
	orbit.rotation.y = 0.7
	# its long axis (z) along the orbit's tangent at (RADIUS, 0, 0); Godot x is TMNF's negated
	ship.position = Vector3(RADIUS + AIRSHIP_MID.x, -AIRSHIP_MID.y, -AIRSHIP_MID.z)
	orbit.add_child(ship)
	if night:
		# its gondola lights the envelope's underside a little
		var l := OmniLight3D.new()
		l.light_color = TmNeon.COLOURS[TmNeon.CYAN]
		l.light_energy = 3.0
		l.omni_range = 60.0
		l.shadow_enabled = false
		l.position = Vector3(RADIUS, -18.0, 0.0)
		orbit.add_child(l)
	return orbit


static func _strip_collision(n: Node) -> void:
	for c in n.get_children():
		if c is CollisionObject3D:
			n.remove_child(c)
			c.free()
		else:
			_strip_collision(c)


func _process(delta: float) -> void:
	rotation.y += speed * delta
