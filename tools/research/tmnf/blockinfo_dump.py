import sys, json, glob, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gbxnode
def sol(m):
    if isinstance(m, gbxnode.Ext):
        return 'mobil:' + m.name
    s = ((m or {}).get('item') or {}).get('solid')
    t = (s or {}).get('tree')
    return t.name if isinstance(t, gbxnode.Ext) else (None if t is None else 'inline')
def units(us):
    return [dict(off=u['offset'], dir=u.get('dir'), surface=u.get('surface'), frontier=u.get('frontier'),
                 clips=[c.name.split('/')[-1] if isinstance(c, gbxnode.Ext) else None for c in u['clips']],
                 pylons=u.get('place_pylons'), accept=u.get('accept_pylons'), underground=u.get('underground'),
                 terrain=u.get('terrain_modifier')) for u in us]
out = {}
for f in sorted(glob.glob(sys.argv[1] + '/*.TMED*.Gbx')):
    name = os.path.basename(f).split('.')[0]
    try:
        root, r = gbxnode.load(f)
        out[name] = dict(cls=root['cls'], id=root.get('id'), page=root.get('page'), pillar=root.get('is_pillar'),
            waypoint=root.get('waypoint'), spawn_ground=root.get('spawn_ground'), spawn_air=root.get('spawn_air'),
            slope=(root['slope'].name if isinstance(root.get('slope'), gbxnode.Ext) else None),
            pillar_info=(root['pillar'].name if isinstance(root.get('pillar'), gbxnode.Ext) else None),
            ground_units=units(root.get('ground_units', [])), air_units=units(root.get('air_units', [])),
            ground_mobils=[[sol(m) for m in ms] for ms in root.get('ground_mobils', [])],
            air_mobils=[[sol(m) for m in ms] for ms in root.get('air_mobils', [])])
    except Exception as e:
        out[name] = dict(error=str(e)[:200])
json.dump(out, open(sys.argv[2], 'w'), indent=1)
bad = [k for k, v in out.items() if 'error' in v]
print(len(out), 'block infos,', len(bad), 'errors')
import collections
print(collections.Counter(v['error'][:60] for v in out.values() if 'error' in v).most_common(10))
