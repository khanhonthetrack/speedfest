"""blockinfos.json (+ decrypted external mobils in raw/) -> the remake's block catalogue:
names, footprints, clip sides, spawn, waypoint and the mesh name per variant (no geometry).
usage: export_blockinfo.py blockinfos.json raw/ campaign_blocks.json out.json"""
import sys, os, json, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gbxnode
bi = json.load(open(sys.argv[1])); raw = sys.argv[2]; camp = json.load(open(sys.argv[3]))
KIND = {'03051000': 'classic', '03052000': 'road', '03053000': 'clip', '03054000': 'slope',
        '03055000': 'pylon', '03056000': 'rectasym', '0304F000': 'flat', '03050000': 'frontier'}
def mobil_solids(name):
    f = os.path.join(raw, os.path.basename(name))
    if not os.path.exists(f): return []
    d = open(f, 'rb').read()
    r = gbxnode.Reader(d)
    try:
        gbxnode.read_reftable(r, struct.unpack_from('<I', d, 13)[0])
        return [e.name for e in r.refs.values() if e.name.endswith('.Solid.Gbx')]
    except Exception:
        pass
    # fallback: the folder tree parses; find '<len><name>.Solid.Gbx' and its folder index
    p = 17 + struct.unpack_from('<I', d, 13)[0] + 8
    r.p = p + 4
    folders = []
    def fold(path):
        for _ in range(r.u32()):
            name = r.string(); folders.append(path + name + '/'); fold(path + name + '/')
    fold('')
    out = []
    q = 0
    while True:
        q = d.find(b'.Solid.Gbx', q)
        if q < 0: break
        for start in range(q - 1, max(0, q - 64), -1):
            n = struct.unpack_from('<I', d, start - 4)[0]
            if start + n == q + 10:
                fi = struct.unpack_from('<I', d, q + 10 + 8)[0]
                out.append((folders[fi - 1] if 0 < fi <= len(folders) else '') + d[start:q + 10].decode('latin1'))
                break
        q += 10
    return [o.split('Stadium/', 1)[-1] for o in out]
def solid_name(s):
    s = s.split('Media/Solid/', 1)[-1]
    return s[:-len('.Solid.Gbx')] if s.endswith('.Solid.Gbx') else s
# variants whose external mobil wasn't decryptable: the solid named by our measurements
FALLBACK = {('StadiumRoadDirtCheckpoint', 'ground'): 'Road/Dirt/RoadDirtCheckpoint/Ground',
            ('StadiumPlatformCheckpointUp', 'air'): 'Platform/Checkpoint/UpAir'}
out = {}
for fname, v in sorted(bi.items()):
    if 'error' in v or not v.get('id'): continue
    def units(us):
        return [[u['off'][0], u['off'][1], u['off'][2], [(c or '').replace('.TMEDClip.Gbx', '') for c in u['clips']]] for u in us]
    def mobils(ms):
        res = []
        for group in ms:
            g = []
            for m in group:
                if not m: g.append(''); continue
                if m.startswith('mobil:'):
                    sol = mobil_solids(m[6:])
                    g.append(solid_name(sol[0]) if sol else '')
                else:
                    g.append(solid_name(m))
            res.append(g)
        return res
    out[v['id']] = {'kind': KIND.get(v['cls'], v['cls']), 'waypoint': v['waypoint'],
        'pillar': bool(v['pillar']),
        'spawn': [round(x, 4) for x in v['spawn_air']] if v.get('spawn_air') else None,
        'spawn_ground': [round(x, 4) for x in v['spawn_ground']] if v.get('spawn_ground') else None,
        'ground': {'units': units(v['ground_units']), 'mobils': mobils(v['ground_mobils'])},
        'air': {'units': units(v['air_units']), 'mobils': mobils(v['air_mobils'])},
        'campaign_uses': camp.get(v['id'], [0])[0]}
    for vn in ('air', 'ground'):
        fb = FALLBACK.get((v['id'], vn))
        if fb and out[v['id']][vn]['mobils'] == [['']]:
            out[v['id']][vn]['mobils'] = [[fb]]
# the editor's pylon (ConstructionBlockInfoPylon: no units or mobils of its own; the blocks dump can't
# read its class chunk): one unit, 15 variants built by stadium/blocks/shapes/pylon.gd
out['PylonStadium'] = {'kind': 'pylon', 'waypoint': 3, 'pillar': False,
    'spawn': [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 16.0, 8.0, 16.0],
    'spawn_ground': [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 16.0, 8.0, 16.0],
    'ground': {'units': [[0, 0, 0, ['', '', '', '']]], 'mobils': [['Pylon/V%dGround' % k] for k in range(15)]},
    'air': {'units': [[0, 0, 0, ['', '', '', '']]], 'mobils': [['Pylon/V%dAir' % k] for k in range(15)]},
    'campaign_uses': 0}
json.dump(out, open(sys.argv[4], 'w'), indent=None, separators=(',', ':'), sort_keys=True)
print(len(out), 'blocks;', sum(1 for v in out.values() if v['campaign_uses']), 'used by the campaign')
