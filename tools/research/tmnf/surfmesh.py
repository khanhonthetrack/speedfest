"""Find CPlugSurfaceGeom (0x0900F004) collision meshes in a decrypted TMF .Solid.Gbx and print them.
usage: surfmesh.py FILE [--tris]"""
import sys, struct
d = open(sys.argv[1], 'rb').read()
def u32(p): return struct.unpack_from('<I', d, p)[0]
def i32(p): return struct.unpack_from('<i', d, p)[0]
names = []
def lookback(p):
    v = u32(p); p += 4
    if v == 3:
        v = u32(p); p += 4
    if v == 0x40000000 or v == 0:
        n = u32(p); p += 4; s = d[p:p + n].decode('latin1'); p += n
        names.append(s); return s, p
    if v & 0x40000000 and (v & 0xFFFFFF) <= len(names):
        return names[(v & 0xFFFFFF) - 1], p
    return f'?{v:08X}', p
out = []
p = 0
while True:
    p = d.find(b'\x04\xf0\x00\x09', p)
    if p < 0: break
    q = p + 4
    try:
        name, q = lookback(q)
        box = struct.unpack_from('<6f', d, q); q += 24
        sid = i32(q); q += 4
        if sid != 7:
            out.append(dict(at=p, name=name, box=box, kind=sid)); p += 4; continue
        ver = i32(q); q += 4
        nv = u32(q); q += 4
        verts = [struct.unpack_from('<3f', d, q + 12 * i) for i in range(nv)]; q += 12 * nv
        nt = u32(q); q += 4
        tris = []
        for i in range(nt):
            nx, ny, nz, dd, a, b, c, si, u4, u5 = struct.unpack_from('<4f3ihBB', d, q); q += 32
            tris.append(((a, b, c), si, (nx, ny, nz, dd)))
        out.append(dict(at=p, name=name, box=box, kind=7, ver=ver, verts=verts, tris=tris))
    except Exception as e:
        out.append(dict(at=p, err=str(e)))
    p += 4
for s in out:
    if 'err' in s: print('ERR', s); continue
    print(f"@{s['at']} geom {s['name']!r} box {tuple(round(x,3) for x in s['box'])} kind {s['kind']}", end='')
    if s['kind'] == 7:
        v = s['verts']
        lo = [min(x[i] for x in v) for i in range(3)]; hi = [max(x[i] for x in v) for i in range(3)]
        mats = sorted(set(t[1] for t in s['tris']))
        print(f" mesh v{s['ver']} {len(v)} verts {len(s['tris'])} tris bounds {[round(x,3) for x in lo]}..{[round(x,3) for x in hi]} mats {mats}")
        if '--tris' in sys.argv:
            for (a, b, c), si, pl in s['tris']:
                print('   ', [tuple(round(x, 3) for x in v[k]) for k in (a, b, c)], 'mat', si, 'n', tuple(round(x, 3) for x in pl[:3]))
    else:
        print()
