#!/usr/bin/env python3
"""Statistics of TMNF's official campaign (numbers only), to give our own A-E campaign the same
shape: per track its kind, medal times, laps, checkpoints, block count, the driving surfaces
(road, platform, circuit, dirt road, tilt), stunts (loops, ramps, turbos), terrain (dirt hills,
water) and decoration, its height and the map area it spans; then the per-series averages.

usage: python3 -I campaign_stats.py <TMNF>/GameData/Tracks/Campaigns/Nations [--md]
(--md prints Markdown tables for docs/research/m9_campaign.md.)
"""
import collections
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gbx_challenge as g  # noqa: E402

SERIES = {'A': 'White', 'B': 'Green', 'C': 'Blue', 'D': 'Red', 'E': 'Black'}
# a block's group by its name (first match wins)
GROUPS = [
    ('gate', r'Checkpoint|StartLine|FinishLine|StartFinish|Multilap'),
    ('loop', r'Loop'),
    ('turbo', r'Turbo'),
    ('ramp', r'Ramp|Bump'),
    ('platform', r'^StadiumPlatform'),
    ('circuit', r'^StadiumCircuit'),
    ('dirtroad', r'^StadiumRoadDirt'),
    ('tilt', r'^StadiumRoadTilt'),
    ('road', r'^StadiumRoad|^StadiumStretch'),
    ('tuberoad', r'^StadiumTubeRoad'),
    ('pillar', r'^StadiumTube|^StadiumHolePillar'),
    ('dirt', r'^StadiumDirt|^StadiumGrass|^StadiumHole'),
    ('water', r'^StadiumPool|^StadiumWater'),
    ('deco', r'^StadiumInflatable|^StadiumFabric|^StadiumSculpt|^StadiumAirship|^StadiumControl'),
]
DRIVE = ['road', 'platform', 'circuit', 'dirtroad', 'tilt', 'tuberoad']


def group(name):
    for gname, rx in GROUPS:
        if re.search(rx, name):
            return gname
    return 'other'


def track(path):
    hdr, info, root, out = g.load(path)
    blocks = out['blocks']
    c = collections.Counter(group(b['name']) for b in blocks)
    cps = sum(1 for b in blocks if 'Checkpoint' in b['name'])
    lap = root.get('lap_race', info.get('laps', False))
    xs = [b['coord'][0] for b in blocks]
    zs = [b['coord'][2] for b in blocks]
    ys = [b['coord'][1] for b in blocks if group(b['name']) in DRIVE + ['gate', 'loop', 'turbo', 'ramp']]
    drive = sum(c[k] for k in DRIVE)
    return {
        'id': os.path.basename(path).split('-')[0],
        'kind': os.path.basename(path).split('-')[1].split('.')[0],
        'author': info.get('author_time', -1), 'gold': info.get('gold', -1),
        'silver': info.get('silver', -1), 'bronze': info.get('bronze', -1),
        'laps': int(root.get('nb_laps', 1)) if lap else 1, 'cps': cps, 'blocks': len(blocks),
        'groups': c, 'drive': drive,
        'mix': {k: round(c[k] / drive, 2) if drive else 0.0 for k in DRIVE},
        'top': max(ys) if ys else 0,
        'span': (max(xs) - min(xs) + 1, max(zs) - min(zs) + 1) if xs else (0, 0),
    }


def t(ms):
    return '%d:%05.2f' % (ms // 60000, (ms % 60000) / 1000.0) if ms >= 0 else '-'


def main():
    root = sys.argv[1]
    md = '--md' in sys.argv
    rows = sorted((track(f) for f in glob.glob(os.path.join(root, '*', '*.Challenge.Gbx'))), key=lambda r: r['id'])
    cols = ['id', 'kind', 'author', 'gold', 'laps', 'cps', 'blocks', 'top', 'span'] + DRIVE + \
        ['loop', 'turbo', 'ramp', 'dirt', 'water', 'deco']
    if md:
        print('| ' + ' | '.join(cols) + ' |')
        print('|' + '---|' * len(cols))
    for r in rows:
        vals = [r['id'], r['kind'], t(r['author']), t(r['gold']), r['laps'], r['cps'], r['blocks'], r['top'],
                '%dx%d' % r['span']] + [r['groups'][k] for k in DRIVE] + \
            [r['groups'][k] for k in ['loop', 'turbo', 'ramp', 'dirt', 'water', 'deco']]
        print(('| ' + ' | '.join(str(v) for v in vals) + ' |') if md else '  '.join('%-9s' % v for v in vals))
    print()
    head = ['series', 'tracks', 'author avg', 'author min-max', 'gold/author', 'laps>1', 'cps avg', 'top avg'] + \
        ['%s %%' % k for k in DRIVE] + ['loops', 'turbos', 'ramps']
    if md:
        print('| ' + ' | '.join(head) + ' |')
        print('|' + '---|' * len(head))
    for s, name in SERIES.items():
        rs = [r for r in rows if r['id'].startswith(s)]
        if not rs:
            continue
        n = len(rs)
        au = [r['author'] for r in rs]
        drive = sum(r['drive'] for r in rs)
        vals = [name, n, t(sum(au) // n), '%s-%s' % (t(min(au)), t(max(au))),
                '%.3f' % (sum(r['gold'] / r['author'] for r in rs) / n),
                sum(1 for r in rs if r['laps'] > 1), '%.1f' % (sum(r['cps'] for r in rs) / n),
                '%.1f' % (sum(r['top'] for r in rs) / n)] + \
            ['%d' % round(100 * sum(r['groups'][k] for r in rs) / drive) for k in DRIVE] + \
            [sum(r['groups'][k] for r in rs) for k in ['loop', 'turbo', 'ramp']]
        print(('| ' + ' | '.join(str(v) for v in vals) + ' |') if md else '  '.join('%-10s' % v for v in vals))


if __name__ == '__main__':
    main()
