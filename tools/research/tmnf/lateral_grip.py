#!/usr/bin/env python3
"""TMNF's sideways grip per surface, from its own runs (M10): the acceleration across the car's
path (horizontal, perpendicular to its velocity) in samples where all four wheels are on the ground
on one surface, split by whether TMNF flags them sliding (a sliding wheel is at its grip's cap).
Percentiles by speed. Numbers only.

usage: python3 -I lateral_grip.py <TMNF>/GameData/Tracks/Campaigns/Nations [--bin=50]
"""
import collections
import glob
import math
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ghost_dump as gd  # noqa: E402


def main():
    root = [a for a in sys.argv[1:] if not a.startswith('--')][0]
    opt = {a.split('=')[0][2:]: (a.split('=')[1] if '=' in a else '1') for a in sys.argv[1:] if a.startswith('--')}
    width = float(opt.get('bin', 50))
    bins = collections.defaultdict(list)
    for f in sorted(glob.glob(os.path.join(root, '*', '*.Replay.gbx'))):
        try:
            _, ghosts = gd.load(f)
        except Exception:
            continue
        for gh in ghosts:
            ss = gh.get('record', {}).get('samples', [])
            for i in range(1, len(ss) - 1):
                a, b, c = ss[i - 1], ss[i], ss[i + 1]
                ws = [s.get('wheels', []) for s in (a, b, c)]
                if any(len(w) != 4 or not all(x.get('ground') for x in w) for w in ws):
                    continue
                surfs = {x['surface'] for w in ws for x in w}
                if len(surfs) != 1:
                    continue
                slide = all(x.get('sliding') for x in b['wheels'])
                grip = not any(x.get('sliding') for w in ws for x in w)
                if not slide and not grip:
                    continue
                v = b['vel']
                vh = math.hypot(v[0], v[2])
                if vh < 3.0 or abs(v[1]) > 1.0:
                    continue
                dt = (c['t'] - a['t']) / 1000.0
                acc = [(c['vel'][k] - a['vel'][k]) / dt for k in range(3)]
                ux, uz = v[0] / vh, v[2] / vh
                lat = abs(acc[0] * -uz + acc[2] * ux)
                bins[(surfs.pop(), 'slide' if slide else 'grip', int(vh * 3.6 // width))].append(lat)
    for key in sorted(bins):
        xs = bins[key]
        if len(xs) < 5:
            continue
        q = statistics.quantiles(xs, n=10)
        print('surface %-10s %-5s %4.0f-%-4.0f km/h  n %4d  median %6.1f  p90 %6.1f  max %6.1f' % (
            gd.SURFACES.get(key[0]), key[1], key[2] * width, (key[2] + 1) * width, len(xs), statistics.median(xs), q[8], max(xs)))


if __name__ == '__main__':
    main()
