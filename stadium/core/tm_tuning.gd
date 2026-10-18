class_name TmTuning
extends RefCounted
## The Stadium car's tuning, as reverse engineered from TMNF 2.11.26 (tuning "20juin2006").
## Source and meaning of every value: docs/research/tmnf_physics.md (offsets in brackets).
## All forces are accelerations: the car's mass is 1.
##
## Car frame (same as TMNF): +X left, +Y up, +Z forward, origin at the centre of mass.

# --- curves: [[x, y], ...]; x is km/h unless noted ---
## [0x34] engine acceleration (m/s^2), step curve
const ACCEL := [[-1000.0, 1.0], [-102.0, 2.0], [-80.0, 6.0], [-35.0, 12.0], [0.0, 16.0],
	[101.0, 11.0], [201.0, 7.0], [401.0, 5.5], [801.0, 1.0]]
## [0x1e0 x 0x1e4] acceleration while the wheels slide sideways (speedslide)
const SLIP_ACCEL := 10.0
## [0x230] reverse-gear acceleration vs km/h (linear)
const REVERSE_ACCEL := [[-150.0, 0.1], [-100.0, 1.5], [-50.0, 8.0], [0.0, 30.0]]
## [0xa0] steering yaw torque vs km/h (linear)
const STEER_TORQUE := [[-100.0, 7.0], [0.0, 16.0], [50.0, 10.4], [100.0, 8.5], [150.0, 6.8],
	[200.0, 5.5], [300.0, 4.25], [400.0, 4.0], [500.0, 3.75], [600.0, 3.75]]
## [0xac] max side force per wheel vs km/h (linear)
const MAX_SIDE_FRICTION := [[0.0, 80.0], [100.0, 80.0], [200.0, 75.0], [300.0, 67.0],
	[400.0, 60.0], [500.0, 55.0]]
## [0x68] slow-down after a wheel touched a wall, vs km/h (linear)
const WALL_SLOWDOWN := [[0.0, 0.0], [50.0, 12.0], [100.0, 24.0], [200.0, 48.0], [400.0, 70.0]]
## [0x78] steering slow-down vs km/h (only backwards)
const STEER_SLOWDOWN := [[-50.0, 1.0], [0.0, 0.0], [50.0, 0.0], [100.0, 0.0], [200.0, 0.0], [300.0, 0.0]]
## [0x224] side grip factor vs damper absorb ratio (1 - suspension length / 0.7): 1.0 at the static
## length, ~0.5 with the suspension fully extended (a light wheel grips less)
const DAMPER_GRIP := [[0.0, 0.1], [0.6, 0.3], [0.975, 1.0], [1.0, 1.0]]
## [0x250] roll torque vs side speed ratio
const ROLLOVER := [[0.0, 0.0], [1.0, 0.8], [10.0, 1.0], [20.0, 1.0], [30.0, 1.0]]

# --- steering ---
const STEER_A := 2.0                 ## [0x6c] steer angle = asin(1 / (A + B*|vz|))
const STEER_B := 0.85                ## [0x70]
const STEER_RAMP_SPEED := 30.0       ## [0x74] m/s: steering torque fades in below this speed
const STEER_MIN_SPEED := 0.7         ## no steering torque below this (m/s)
const STEER_RATE := 20.0             ## [0x94] input slew per second
const STEER_SLOWDOWN_SCALE := 0.5    ## [0x7c]
const YAW_FROM_GRIP := 0.08          ## [0x98] axle side force -> yaw torque
const STEER_TORQUE_SLIDING := 1.0    ## [0x9c]

# --- side grip ---
const SIDE_STIFFNESS := 40.0         ## [0xa4] per wheel: x0.5 per m/s of side speed
const SLIDE_GRIP := 0.35             ## [0xb0] grip of a sliding wheel
const SLIDE_BRAKE_GRIP := 0.2        ## [0x244] extra factor while sliding and braking
const SLIDE_BLEND := 0.018           ## [0xb4] over the cap: F = cap*(1-k) + F*k
const YAW_SLIDE_BLEND := 1.0         ## [0xe4] default: axle forces for yaw are never capped
const SLIP_BLEND_SCALE := 1.0        ## [0x200]

# --- drive, brake, drag ---
const BRAKE_A := 1.0                 ## [0x40] brake = (A + B*v) * input
const BRAKE_B := 1.75                ## [0x44]
const BRAKE_CAP := 30.0              ## [0x4c]
const BRAKE_CAP_SLIDING := 60.0      ## [0x48]
const REVERSE_BRAKE_CAP := 50.0      ## [0x24c]
const REVERSE_BRAKE_CAP_SLIDING := 100.0  ## [0x248]
const BRAKE_PER_SLIDING_WHEEL := 0.5 ## [0x240]
const COAST_CONST := 1.0             ## [0x58]
const COAST_LIN := 0.3               ## [0x5c]
const MAX_SPEED := 277.77780         ## [0x2c] m/s (1000 km/h)
const MAX_REVERSE_SPEED := 138.61111 ## [0x30]
const OVERSPEED_PUSH := 10.0         ## [0x60]
const REVERSE_SWITCH_SPEED := 2.0    ## m/s

# --- gravity, damping, air ---
const GRAVITY := 10.0                ## the race scene's gravity field (m/s^2)
const GRAVITY_GROUND := 3.0          ## [0x160]
const GRAVITY_AIR := 2.5             ## [0x164]
const AIR_LINEAR_DAMP := 0.03        ## [0x154]
const AIR_ANG_DAMP_LIN := 0.4        ## [0x158]
const AIR_ANG_DAMP_QUAD := 0.2       ## [0x15c]
const AIR_YAW_FLIP := 3.14           ## [0x368] rad/s

# --- slope adherence (share of gravity along the car's up axis) ---
const SLOPE_SIDE_MIN := 0.3          ## [0xd4]
const SLOPE_SIDE_FULL := 0.7         ## [0xd8]
const SLOPE_DRIVE_MIN := 0.4         ## [0xdc]
const SLOPE_DRIVE_FULL := 0.7        ## [0xe0]

# --- suspension (per wheel) ---
const SPRING := 40.0                 ## [0x114]
const DAMPER := 1.0                  ## [0x118]
const SUSP_REST := 0.2               ## [0x124] full extension
const SUSP_RELAX := 5.0              ## [0x194] 1/s
const SUSP_STATIC := 0.0125          ## length at rest under 3 g (where the wheels sit in the model)
const DAMPER_ABSORB_FULL := 0.0      ## [0x11c] suspension length that maps to ratio 1
const DAMPER_ABSORB_NONE := 0.7      ## [0x120] suspension length that maps to ratio 0

# --- load transfer: each wheel on the ground adds 0.05 x (contact point x the car's total force of
# the previous tick), pitch and roll only (nose up when accelerating, dive when braking, lean in turns)
const LOAD_DIV := 5.0                ## [0x228] the force is stored / 5 and read back x -5 (cancels)
const LOAD_MIN := 0.01               ## [0x234] no torque below this (stored) force
const LOAD_TORQUE_X := 0.05          ## [0x238] pitch
const LOAD_TORQUE_Z := 0.05          ## [0x23c] roll

# --- dirt (surface 6) slide forces ---
const DIRT_SIDE := -0.05             ## [0x33c]
const DIRT_SIDE_GAS := 0.05          ## [0x340]
const DIRT_PUSH := 90.0              ## [0x344]
const DIRT_PUSH_GAS := 1.0           ## [0x348]

# --- walls and contacts ---
const WALL_SLOWDOWN_MS := 500        ## [0x1e8]
const SIDE_CONTACT_SIN := 0.70710678 ## contact normal beyond 45 deg from up = wall
const BODY_FRICTION := 0.3           ## [0x170]
const BODY_FRICTION_METAL := 0.2     ## [0x174]
const BODY_KEEP := 0.5               ## [0x17c] impulse keeps this much of the approach speed
const WHEEL_SIDE_KEEP := 0.5         ## [0x178]
const WHEEL_GROUND_KEEP := 0.8       ## [0x184]
const SUBSTEP_DIST := 0.3            ## [0x168] max travel per collision sub-step (m)

# --- turbo ---
const TURBO_STRENGTH := 5.0          ## [0xf0] yellow pad
const TURBO_MS := 250                ## [0xf8]
const TURBO2_STRENGTH := 20.0        ## [0xf4] red pad
const TURBO2_MS := 100               ## [0xfc]
## The roulette pad (surface 30): the yellow pad's strength and time [0xf0, 0xf8] times a factor
## rolled when the car meets the pad, from where the run's clock is in a 1000 ms cycle
## (CSceneVehicleCar::GetRouletteValue01 (time - run start, 1000): 0 below 4/7, 0.5 below 6/7,
## else 1; the factor is 1 + that, so x1 for 571 ms, x1.5 for 286 ms, x2 for 143 ms).
const ROULETTE_PERIOD_MS := 1000
const ROULETTE_STEPS := [[4.0 / 7.0, 1.0], [6.0 / 7.0, 1.5], [1.0, 2.0]]

# --- body ---
const MASS := 1.0                    ## [0x130]
## [0x134..0x140] box inertia, mass 5, 1 x 1 x 2 m: (pitch, yaw, roll)
const INERTIA := Vector3(2.0833333, 2.0833333, 0.8333333)
const WHEEL_RADIUS := 0.364
const WHEEL_HALF_WIDTH := 0.182
## Wheel centres relative to the centre of mass, in the model pose (FL, FR, RL, RR).
## (StadiumCar.Solid FLSurf.. positions minus the centre of mass (0, 0.4385, 0.28825))
const WHEELS: Array[Vector3] = [Vector3(0.863, -0.086, 1.49385), Vector3(-0.863, -0.086, 1.49385),
	Vector3(0.885, -0.086, -1.49375), Vector3(-0.885, -0.086, -1.49375)]
const WHEELBASE := 2.9876
## Chassis collision ellipsoids [centre, half-axes, pitch (rad, nose up +)] relative to the
## centre of mass. The front wing's axes are already swapped into the car frame.
const BODY_ELLIPSOIDS := [
	[Vector3(0.0, 0.0328, -0.06915), Vector3(0.4391, 0.362, 1.9015), 0.0596],
	[Vector3(0.0, 0.0103, -0.49615), Vector3(0.9683, 0.3627, 1.6823), 0.0457],
	[Vector3(0.0, 0.2143, -1.18585), Vector3(1.0209, 0.5152, 1.038), 0.0469],
	[Vector3(-0.0155, -0.0752, 1.46535), Vector3(0.9053, 0.2834, 0.3848), 0.0],
]

# --- surfaces: id -> [top speed, accel, brake, grip] (StadiumVehicleMaterials) ---
enum Surface { CONCRETE = 0, PAVEMENT = 1, GRASS = 2, ICE = 3, METAL = 4, SAND = 5, DIRT = 6,
	TURBO = 7, DIRT_ROAD = 8, RUBBER = 9, ROCK = 12, WATER = 13, WOOD = 14, ASPHALT = 16,
	WET_DIRT_ROAD = 17, WET_PAVEMENT = 19, WET_GRASS = 20, SNOW = 21, TURBO2 = 26,
	FREE_WHEELING = 29, TURBO_ROULETTE = 30 }
const SURFACES := {
	0: [1.0, 1.0, 1.0, 1.0], 1: [1.0, 1.0, 1.0, 1.0], 2: [0.5, 0.15, 0.4, 0.05],
	3: [1.0, 0.0, 0.1, 0.0], 4: [1.0, 1.0, 1.0, 1.0], 5: [0.2, 0.5, 0.4, 1.0],
	6: [0.9, 0.25, 0.9, 0.4], 8: [0.7, 0.5, 1.0, 1.0], 14: [1.0, 1.0, 1.0, 1.0],
	16: [1.0, 1.0, 1.0, 1.0], 17: [0.9, 1.0, 1.0, 1.0], 19: [1.0, 0.85, 1.0, 0.85],
	20: [0.1, 0.5, 0.5, 1.0], 21: [0.2, 0.1, 0.6, 0.1],
}


static func surface_vals(id: int) -> Array:
	return SURFACES.get(id, SURFACES[0])


## Step curve (TMNF interpolation 1): value of the last key at or below x.
static func step(keys: Array, x: float) -> float:
	var v: float = keys[0][1]
	for k in keys:
		if x >= k[0]:
			v = k[1]
		else:
			break
	return v


## Linear curve (TMNF interpolation 0), clamped at both ends.
static func lin(keys: Array, x: float) -> float:
	if x <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		if x <= b[0]:
			return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])
	return keys[keys.size() - 1][1]


## Steer angle (rad) at full lock for a forward speed (m/s).
static func steer_angle(vz: float) -> float:
	return asin(minf(1.0, 1.0 / (STEER_A + STEER_B * absf(vz))))


## Side grip factor of a wheel from its suspension length (M6GetModulationFromDamperAbsorbVal).
static func damper_grip(susp_len: float) -> float:
	var r := (susp_len - DAMPER_ABSORB_NONE) / (DAMPER_ABSORB_FULL - DAMPER_ABSORB_NONE)
	return lin(DAMPER_GRIP, r)


## 0..1 smooth ramp used by the slope adherence.
static func smooth_ramp(x: float, lo: float, hi: float) -> float:
	if x < lo:
		return 0.0
	if x > hi:
		return 1.0
	return 1.0 - cos((x - lo) / (hi - lo) * PI * 0.5)
