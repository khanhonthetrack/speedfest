#!/usr/bin/env python3
"""A TMNF track's blocks as ASCII maps, one per level (top view, x left to right as TMNF's x, z
down), to see how a campaign track lays out its surfaces: lane widths, borders, transitions.

usage: python3 -I track_ascii.py <X.Challenge.Gbx> [--levels=2,13] [--legend]
Characters: see LEGEND (first match of the block's name); '.' empty, '?' anything else.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gbx_challenge as g  # noqa: E402

LEGEND = [
    ('S', r'StartLine|StartFinish|Multilap'), ('F', r'FinishLine'), ('K', r'Checkpoint'),
    ('o', r'Loop'), ('t', r'Turbo'), ('^', r'Ramp|Bump'),
    ('c', r'^StadiumCircuitBorder'), ('/', r'^StadiumCircuitSlope'), ('C', r'^StadiumCircuit'),
    ('w', r'^StadiumPlatformWall'), ('p', r'^StadiumPlatformToRoad'), ('P', r'^StadiumPlatform'),
    ('d', r'^StadiumRoadDirt.*To'), ('D', r'^StadiumRoadDirt'), ('x', r'^StadiumRoadTilt'),
    ('R', r'^StadiumRoad'), ('T', r'^StadiumTubeRoad'), ('|', r'^StadiumTube|^StadiumHolePillar'),
    ('h', r'^StadiumDirtHill'), ('_', r'^StadiumDirt|^StadiumGrass|^StadiumHole'),
    ('~', r'^StadiumPool|^StadiumWater'), ('i', r'^StadiumInflatable'), ('f', r'^StadiumFabric'),
    ('s', r'^StadiumSculpt'), ('k', r'^StadiumControl'),
]


def ch(name):
    for c, rx in LEGEND:
        if re.search(rx, name):
            return c
    return '?'


def main():
    hdr, info, root, out = g.load(sys.argv[1])
    levels = None
    for a in sys.argv[2:]:
        if a.startswith('--levels='):
            levels = [int(v) for v in a[9:].split(',')]
        if a == '--legend':
            print('  '.join('%s %s' % (c, rx) for c, rx in LEGEND))
    grid = {}
    for b in out['blocks']:
        x, y, z = b['coord']
        k = (x, y, z)
        c = ch(b['name'])
        # the more telling character wins (gates over surfaces over decoration)
        if k not in grid or 'SFKotP^CRDTx'.find(c) >= 0:
            grid[k] = c
    ys = sorted({k[1] for k in grid})
    print('%s  author %d ms  levels %s' % (info.get('name'), info.get('author_time', -1), ys))
    for y in ys:
        if levels and y not in levels:
            continue
        cells = {(k[0], k[2]): v for k, v in grid.items() if k[1] == y}
        if not cells:
            continue
        print('level %d' % y)
        print('    ' + ''.join(str(x % 10) for x in range(32)))
        for z in range(32):
            row = ''.join(cells.get((x, z), '.') for x in range(32))
            if row.strip('.'):
                print('%3d %s' % (z, row))


if __name__ == '__main__':
    main()
