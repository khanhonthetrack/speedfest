#!/usr/bin/env python3
"""Our car against a TMNF ghost, sample by sample (M10): the same run's inputs drove our car
(race.tscn --inputs=... --trace=...), this prints where the two part: position apart, speeds,
heights, which wheels touch and slide on which surface, every `step` ms. Godot = TMNF with x
negated. Numbers only.

usage: python3 -I ghost_compare.py <X.Replay.Gbx> <trace.jsonl> [--ghost=0] [--step=500] [--until=ms]
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ghost_dump as gd  # noqa: E402

SHORT = {0: 'Co', 1: 'Pa', 2: 'Gr', 3: 'Ic', 4: 'Me', 5: 'Sa', 6: 'Di', 7: 'Tu', 8: 'DR', 9: 'Ru', 14: 'Wo',
         16: 'As', 26: 'T2'}


def wheels_tm(s):
    out = []
    for w in s.get('wheels', []):
        if not w.get('ground', True):
            out.append('..')
        else:
            out.append(SHORT.get(w['surface'], '%02d' % w['surface']) + ('*' if w.get('sliding') else ''))
    return ' '.join('%-3s' % x for x in out)


def wheels_ours(s):
    out = []
    # ours: FL FR RL RR? TmTuning.WHEELS order is front left, front right, rear left, rear right;
    # TMNF's samples: FL FR RR RL
    order = [0, 1, 3, 2]
    for k in order:
        c, surf, sl = s['wheels'][k]
        out.append('..' if not c else SHORT.get(surf, '%02d' % surf) + ('*' if sl else ''))
    return ' '.join('%-3s' % x for x in out)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    opt = {a.split('=')[0][2:]: a.split('=')[1] for a in sys.argv[1:] if a.startswith('--') and '=' in a}
    _, ghosts = gd.load(args[0])
    gh = ghosts[int(opt.get('ghost', 0))]
    tm = {s['t']: s for s in gh['record']['samples']}
    ours = {}
    for line in open(args[1]):
        s = json.loads(line)
        ours[int(s['t'])] = s
    step = int(opt.get('step', 500))
    until = int(opt.get('until', 10 ** 9))
    print('    t   apart(m)  TMNF km/h  ours km/h   TMNF y   ours y   TMNF wheels        ours wheels')
    for t in sorted(tm):
        if t % step or t > until or t not in ours:
            continue
        a = tm[t]
        b = ours[t]
        pa = (-a['pos'][0], a['pos'][1], a['pos'][2])
        pb = b['pos']
        apart = math.dist(pa, pb)
        va = math.sqrt(sum(c * c for c in a['vel'])) * 3.6
        vb = math.sqrt(sum(c * c for c in b['vel'])) * 3.6
        print('%6d %8.2f %10.1f %10.1f %8.2f %8.2f   %-18s %s' % (t, apart, va, vb, pa[1], pb[1], wheels_tm(a), wheels_ours(b)))


if __name__ == '__main__':
    main()
