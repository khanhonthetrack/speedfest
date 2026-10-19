"""Reference model of the TrackMania Nations Forever Stadium car on flat ground (our reconstruction).

Written from our own reading of TmForever 2.11.26 (CSceneVehicleCar::ComputeForcesModel6 and helpers)
and the StadiumCar tuning "20juin2006". See docs/research/tmnf_physics.md for the derivation; no game
code is reproduced here. Planar model: forward/lateral velocity + yaw, all four wheels on asphalt,
100 Hz ticks, mass 1 (every force below is an acceleration). Used to derive the numeric targets for
SpeedFest's handling lab.

usage: python3 tmnf_model.py            # prints the behaviour table
"""
import math

DT = 0.01                      # TMNF simulates at 100 Hz
WHEELBASE = 1.782 + 1.2055     # FLSurf/RLSurf z positions in StadiumCar.Solid
LEVER = WHEELBASE * 0.5
YAW_INERTIA = 5.0 / 12.0 * (1.0 ** 2 + 2.0 ** 2)   # box inertia, mass 5, 1 x 1 x 2 m


def step_curve(keys, x):
    """CFuncKeysReal with interpolation 1 (step): value of the last key <= x."""
    v = keys[0][1]
    for kx, kv in keys:
        if x >= kx:
            v = kv
    return v


def lin_curve(keys, x):
    """CFuncKeysReal with interpolation 0 (linear, clamped)."""
    if x <= keys[0][0]:
        return keys[0][1]
    for (x0, y0), (x1, y1) in zip(keys, keys[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return keys[-1][1]


ACCEL = [(-1000, 1), (-102, 2), (-80, 6), (-35, 12), (0, 16), (101, 11), (201, 7), (401, 5.5), (801, 1)]
SLIP_ACCEL = 10.0
STEER_TORQUE = [(-100, 7), (0, 16), (50, 10.4), (100, 8.5), (150, 6.8), (200, 5.5), (300, 4.25),
                (400, 4.0), (500, 3.75), (600, 3.75)]
MAX_SIDE_FRICTION = [(0, 80), (100, 80), (200, 75), (300, 67), (400, 60), (500, 55)]
LATERAL_STIFFNESS = 40.0 * 0.5   # per wheel, per m/s of sideways speed
SLIDE_GRIP = 0.35                # grip multiplier while a wheel is flagged sliding
SLIDE_BRAKE_GRIP = 0.2           # extra multiplier while sliding and braking
SLIDE_BLEND = 0.018              # over the cap: F = cap*(1-k) + F*k
YAW_FROM_GRIP = 0.08
BRAKE_A, BRAKE_B = 1.0, 1.75     # brake = (A + B*v) * input, per wheel-slide halving
BRAKE_CAP, BRAKE_CAP_SLIDING = 30.0, 60.0
COAST_CONST, COAST_LIN = 1.0, 0.3
STEER_RATE = 20.0                # input slew per second
MAX_KMH = 1000.0
GRAVITY_GROUND, GRAVITY_AIR = 30.0, 25.0


def steer_angle(v):
    return math.asin(min(1.0, 1.0 / (2.0 + 0.85 * abs(v))))


def steer_ramp(v):
    if v < 0.7:
        return 0.0
    return math.sin(0.5 * math.pi * v / 30.0) if v <= 30.0 else 1.0


class Car:
    def __init__(self, v=0.0):
        self.vz = v      # forward m/s (car frame)
        self.vx = 0.0    # lateral m/s (car frame, + = left)
        self.w = 0.0     # yaw rate rad/s (+ = left)
        self.steer = 0.0
        self.sliding = [False] * 4   # FL FR RL RR
        self.heading = 0.0
        self.x = self.z = 0.0

    def tick(self, gas=0.0, brake=0.0, steer_in=0.0):
        # steering input slews at 20/s; + = left
        d = steer_in - self.steer
        self.steer += max(-STEER_RATE * DT, min(STEER_RATE * DT, d))
        v = math.hypot(self.vx, self.vz)
        kmh = self.vz * 3.6
        delta = self.steer * steer_angle(self.vz)
        cap_base = lin_curve(MAX_SIDE_FRICTION, kmh)
        # 1) lateral grip per wheel, applied at the centre of mass (no torque)
        f_lat = 0.0
        any_slide = False
        for i in range(4):
            front = i < 2
            ang = delta if front else 0.0
            v_lat = self.vx * math.cos(ang) - self.vz * math.sin(ang)
            f = -LATERAL_STIFFNESS * v_lat
            cap = cap_base * (SLIDE_GRIP if self.sliding[i] else 1.0)
            if self.sliding[i] and brake > 0.1:
                cap *= SLIDE_BRAKE_GRIP
            if abs(f) <= cap:
                self.sliding[i] = False
            else:
                self.sliding[i] = True
                f = (1 - SLIDE_BLEND) * math.copysign(cap, f) + SLIDE_BLEND * f
            any_slide |= self.sliding[i]
            # force along the wheel's lateral axis -> car frame
            f_lat += f * math.cos(ang)
            self.vz_force_from_lat = getattr(self, 'vz_force_from_lat', 0.0)
        # 2) yaw torque: per-axle grip (scaled 0.08) + steering torque on the front axle
        torque = 0.0
        over, caps = 0.0, 0.0
        for i in range(4):
            front = i < 2
            lever = LEVER if front else -LEVER
            v_axle = self.vx + self.w * lever
            f = -LATERAL_STIFFNESS * v_axle
            if abs(f) > cap_base:
                over += abs(f); caps += cap_base
            t = YAW_FROM_GRIP * f
            if front:
                t += steer_ramp(v) * self.steer * lin_curve(STEER_TORQUE, kmh)
            torque += t * lever
        # 3) drive / brake
        slip = 1.0
        if caps > 0:
            slip = 1.0 - min(1.0, max(0.0, (over - caps) / caps))
        accel = (1 - slip) * SLIP_ACCEL + slip * step_curve(ACCEL, kmh)
        f_long = gas * accel
        if gas < 1e-5:   # coasting drag only without throttle
            f_long -= math.copysign(COAST_CONST, self.vz) + COAST_LIN * self.vz if abs(self.vz) > 1e-3 else 0.0
        if brake > 0 and self.vz > 0:
            halving = 0.5 ** sum(self.sliding)
            fb = (BRAKE_A + BRAKE_B * self.vz) * brake * halving
            cap = BRAKE_CAP_SLIDING if any_slide else BRAKE_CAP
            if fb > cap:
                fb = cap
                self.sliding = [True] * 4
            f_long -= fb
        if kmh > MAX_KMH:
            f_long -= 10.0
        # 4) integrate in the rotating car frame (semi-implicit Euler)
        self.vz += (f_long + self.w * self.vx) * DT
        self.vx += (f_lat - self.w * self.vz) * DT
        self.w += torque / YAW_INERTIA * DT
        self.heading += self.w * DT
        c, s = math.cos(self.heading), math.sin(self.heading)
        self.z += (self.vz * c - self.vx * s) * DT
        self.x += (self.vz * s + self.vx * c) * DT


def time_to(kmh_target, limit=60.0):
    car = Car(); t = 0.0
    while car.vz * 3.6 < kmh_target and t < limit:
        car.tick(gas=1.0); t += DT
    return t


def steady_turn(kmh, steer=1.0, secs=3.0, gas=True):
    car = Car(kmh / 3.6)
    for _ in range(int(secs / DT)):
        # hold speed: gas only while below the entry speed
        car.tick(gas=1.0 if (gas and car.vz * 3.6 < kmh) else 0.0, steer_in=steer)
    v = math.hypot(car.vx, car.vz)
    r = v / abs(car.w) if abs(car.w) > 1e-6 else float('inf')
    slip = math.degrees(math.atan2(abs(car.vx), car.vz))
    return v * 3.6, car.w, r, v * abs(car.w) / 9.81, slip, any(car.sliding)


def brake_tap_drift(kmh=200.0, tap=0.15, hold=1.5):
    car = Car(kmh / 3.6); max_slip = 0.0; t = 0.0
    while t < tap + hold:
        car.tick(gas=1.0 if t >= tap else 0.0, brake=1.0 if t < tap else 0.0, steer_in=1.0)
        max_slip = max(max_slip, math.degrees(math.atan2(abs(car.vx), max(car.vz, 1e-3))))
        t += DT
    return max_slip, math.degrees(car.heading), car.vz * 3.6


def brake_stop(kmh):
    car = Car(kmh / 3.6); t = 0.0; d = 0.0
    while car.vz > 0.05 and t < 30:
        car.tick(brake=1.0); t += DT; d = car.z
    return t, d


if __name__ == '__main__':
    print('TMNF Stadium car (reconstructed model, flat asphalt)')
    for k in (100, 200, 300, 400, 500, 800):
        print(f'  0-{k} km/h: {time_to(k):5.2f} s')
    print('  full-lock steady turn (speed held):')
    for k in (50, 100, 150, 200, 300, 400, 500):
        v, w, r, g, slip, sl = steady_turn(k)
        print(f'    {k:3d} km/h: yaw {w:5.2f} rad/s  radius {r:6.1f} m  lateral {g:4.1f} g  slip {slip:4.1f} deg  sliding={sl}')
    for k in (100, 200, 300):
        t, d = brake_stop(k)
        print(f'  brake from {k} km/h: {t:4.2f} s, {d:5.1f} m')
    s, h, v = brake_tap_drift()
    print(f'  brake tap 0.15 s + full lock from 200 km/h, 1.5 s: max slip {s:4.1f} deg, heading {h:5.1f} deg, exit {v:5.1f} km/h')
    print(f'  air: gravity {GRAVITY_AIR} m/s^2; 8 m drop takes {math.sqrt(2 * 8 / GRAVITY_AIR):.2f} s')
