#!/usr/bin/env python3
"""TMNF's acceleration against speed, measured from its own runs (M10): over every ghost of every
campaign replay, the samples (100 ms apart) where the car drives straight on full throttle, all
four wheels on the ground on one surface, no turbo, level (little vertical speed): dv/dt by speed.
Prints the median per speed bin for each surface. Numbers only.

usage: python3 -I accel_curve.py <TMNF>/GameData/Tracks/Campaigns/Nations [--bin=10] [--surface=16]
       [--coast] (no gas, no brake) [--brake]
"""
import collections
import glob
import math
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ghost_dump as gd  # noqa: E402


def speed(s):
    return math.sqrt(sum(c * c for c in s['vel']))


def main():
    root = [a for a in sys.argv[1:] if not a.startswith('--')][0]
    opt = {a.split('=')[0][2:]: (a.split('=')[1] if '=' in a else '1') for a in sys.argv[1:] if a.startswith('--')}
    width = float(opt.get('bin', 10))
    mode = 'coast' if 'coast' in opt else 'brake' if 'brake' in opt else 'gas'
    bins = collections.defaultdict(lambda: collections.defaultdict(list))
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
                ok = True
                for s in (a, b, c):
                    w = s.get('wheels', [])
                    if len(w) != 4 or not all(x.get('ground') for x in w) or (mode != 'brake' and any(x.get('sliding') for x in w)):
                        ok = False
                        break
                    if abs(s.get('steer', 1)) > 0.01 or s.get('turbo', 1) > 0.01:
                        ok = False
                        break
                    if mode == 'gas' and (s.get('gas', 0) < 0.99 or s.get('brake', 1) > 0.01):
                        ok = False
                        break
                    if mode == 'coast' and (s.get('gas', 1) > 0.01 or s.get('brake', 1) > 0.01):
                        ok = False
                        break
                    if mode == 'brake' and s.get('brake', 0) < 0.99:
                        ok = False
                        break
                    if abs(s['vel'][1]) > 0.3:
                        ok = False
                        break
                if not ok:
                    continue
                surfs = {x['surface'] for s in (a, b, c) for x in s['wheels']}
                if len(surfs) != 1:
                    continue
                v = speed(b) * 3.6
                acc = (speed(c) - speed(a)) / ((c['t'] - a['t']) / 1000.0)
                bins[surfs.pop()][int(v // width)].append(acc)
    want = opt.get('surface')
    for surf in sorted(bins):
        if want is not None and str(surf) != want:
            continue
        print('surface %s (%s): %s, median dv/dt (m/s2) by speed' % (surf, gd.SURFACES.get(surf), mode))
        for k in sorted(bins[surf]):
            xs = bins[surf][k]
            if len(xs) < 3:
                continue
            print('  %5.0f-%-5.0f km/h  n %4d  median %7.2f  p25 %7.2f  p75 %7.2f' % (
                k * width, (k + 1) * width, len(xs), statistics.median(xs),
                statistics.quantiles(xs, n=4)[0], statistics.quantiles(xs, n=4)[2]))


if __name__ == '__main__':
    main()
