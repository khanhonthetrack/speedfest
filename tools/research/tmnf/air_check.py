#!/usr/bin/env python3
"""TMNF in the air, measured from its own runs (M10-4): over every ghost of every campaign replay,
the samples (100 ms apart) where no wheel touches for three samples running and the car is not
near anything (its speed changes smoothly): the vertical acceleration (gravity), the horizontal
deceleration against speed (air drag), and how the angular speed decays (angular drag, by rate).
Numbers only.

usage: python3 -I air_check.py <TMNF>/GameData/Tracks/Campaigns/Nations [--bin=50]
"""
import collections
import glob
import math
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ghost_dump as gd  # noqa: E402


def norm(v):
    return math.sqrt(sum(c * c for c in v))


def airborne(s):
    w = s.get('wheels', [])
    return len(w) == 4 and not any(x.get('ground') for x in w)


def q(xs, k):
    return statistics.quantiles(xs, n=4)[k] if len(xs) >= 4 else float('nan')


def main():
    root = [a for a in sys.argv[1:] if not a.startswith('--')][0]
    opt = {a.split('=')[0][2:]: (a.split('=')[1] if '=' in a else '1') for a in sys.argv[1:] if a.startswith('--')}
    width = float(opt.get('bin', 50))
    ay = []                                         # vertical acceleration, m/s2
    drag = collections.defaultdict(list)            # horizontal speed bin -> dv/dt
    spin = collections.defaultdict(list)            # angular speed bin (0.5 rad/s) -> d|w|/dt
    yaw = collections.defaultdict(list)             # yaw-rate bin -> d|wy|/dt (steer inputs mixed in)
    files = sorted(glob.glob(os.path.join(root, '*', '*.Replay.gbx')))
    for f in files:
        try:
            _, ghosts = gd.load(f)
        except Exception as e:
            print('skip', os.path.basename(f), e)
            continue
        for gh in ghosts:
            ss = gh.get('record', {}).get('samples', [])
            for i in range(1, len(ss) - 1):
                a, b, c = ss[i - 1], ss[i], ss[i + 1]
                if not (airborne(a) and airborne(b) and airborne(c)):
                    continue
                if b.get('turbo', 0) > 0.01:
                    continue
                dt = (c['t'] - a['t']) / 1000.0
                ay.append((c['vel'][1] - a['vel'][1]) / dt)
                ha = math.hypot(a['vel'][0], a['vel'][2])
                hc = math.hypot(c['vel'][0], c['vel'][2])
                hb = math.hypot(b['vel'][0], b['vel'][2])
                drag[int(hb * 3.6 // width)].append((hc - ha) / dt)
                wa, wb, wc = norm(a['angvel']), norm(b['angvel']), norm(c['angvel'])
                spin[int(wb // 0.5)].append((wc - wa) / dt)
                yaw[int(abs(b['angvel'][1]) // 0.5)].append((abs(c['angvel'][1]) - abs(a['angvel'][1])) / dt)
    print('airborne samples: %d' % len(ay))
    if ay:
        print('vertical acceleration (m/s2): median %.2f  p25 %.2f  p75 %.2f' % (statistics.median(ay), q(ay, 0), q(ay, 2)))
    print('horizontal dv/dt by horizontal speed:')
    for k in sorted(drag):
        xs = drag[k]
        if len(xs) >= 5:
            print('  %4.0f-%-4.0f km/h  n %5d  median %7.3f  p25 %7.3f  p75 %7.3f' % (
                k * width, (k + 1) * width, len(xs), statistics.median(xs), q(xs, 0), q(xs, 2)))
    print('d|w|/dt by |w| (rad/s):')
    for k in sorted(spin):
        xs = spin[k]
        if len(xs) >= 5:
            print('  %4.1f-%-4.1f  n %5d  median %7.3f  p25 %7.3f  p75 %7.3f' % (
                k * 0.5, (k + 1) * 0.5, len(xs), statistics.median(xs), q(xs, 0), q(xs, 2)))
    print('d|yaw rate|/dt by |yaw rate| (rad/s):')
    for k in sorted(yaw):
        xs = yaw[k]
        if len(xs) >= 5:
            print('  %4.1f-%-4.1f  n %5d  median %7.3f  p25 %7.3f  p75 %7.3f' % (
                k * 0.5, (k + 1) * 0.5, len(xs), statistics.median(xs), q(xs, 0), q(xs, 2)))


if __name__ == '__main__':
    main()
