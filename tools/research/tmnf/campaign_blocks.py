import os
import sys, glob, collections, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gbx_challenge as g
root = sys.argv[1]
cnt = collections.Counter(); maps = collections.defaultdict(set); ground = collections.Counter()
for f in sorted(glob.glob(root + '/*/*.Challenge.Gbx')):
    hdr, info, r, out = g.load(f)
    for b in out['blocks']:
        cnt[b['name']] += 1
        maps[b['name']].add(os.path.basename(f)[:3])
        if b['flags'] != 0xFFFFFFFF and b['flags'] & 0x1000:
            ground[b['name']] += 1
json.dump({k: [v, ground[k], sorted(maps[k])] for k, v in cnt.items()}, open(sys.argv[2], 'w'), indent=0)
for k, v in cnt.most_common():
    print(f"{v:6d} {ground[k]:6d} {len(maps[k]):3d}  {k}")
