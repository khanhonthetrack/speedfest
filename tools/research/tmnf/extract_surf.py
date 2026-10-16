"""Collision mesh of each decrypted .Solid.Gbx -> meas/<name>.json (local measurements only):
materials (names from the reference table), vertices, triangles (indices, material), and the
location of the tree that holds the surface."""
import sys, os, glob, json, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gbxnode
os.makedirs('meas', exist_ok=True)
def surf(path):
    d = open(path, 'rb').read()
    r = gbxnode.Reader(d)
    uds = struct.unpack_from('<I', d, 13)[0]
    gbxnode.read_reftable(r, uds)
    p = d.find(b'\x04\xf0\x00\x09')
    if p < 0: return None
    r.p = p + 4
    r.idver = 3   # jumping into the body: the id version word was read long before
    v = struct.unpack_from('<I', d, r.p)[0]
    if v in (2, 3): r.p += 4
    r.ident(); box = r.vec(6); kind = r.i32()
    if kind != 7: return dict(kind=kind)
    ver = r.i32(); nv = r.u32()
    verts = [r.vec(3) for _ in range(nv)]
    nt = r.u32(); tris = []
    for _ in range(nt):
        pl = r.vec(4); a, b, c = r.i32(), r.i32(), r.i32(); si = r.i16(); r.u8(); r.u8()
        tris.append([a, b, c, si])
    octv = r.i32()
    nc = r.u32(); r.p += nc * 32
    sid = r.i16()
    fac = r.u32()
    mats = []
    if fac == 0xFACADE01:
        n = r.u32()
        for _ in range(n):
            if r.boolean():
                ref = r.noderef(); mats.append(ref.name.split('/')[-1].replace('.Material.Gbx', '') if isinstance(ref, gbxnode.Ext) else str(ref))
            else:
                mats.append('surf#%d' % r.i16())
    # the surface hangs in a tree's chunk 016; that tree's location chunk (0x0904F01A, its last
    # chunk) is the first one after the surface; the root tree's is the last one in the file
    def loc_at(q):
        fl = struct.unpack_from('<I', d, q + 4)[0]
        return struct.unpack_from('<12f', d, q + 8) if fl & 4 else (1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
    q1 = d.find(b'\x1a\xf0\x04\x09', r.p)
    qr = d.rfind(b'\x1a\xf0\x04\x09')
    mats_ = [loc_at(qr)] if qr >= 0 else []
    if 0 <= q1 < qr:
        mats_.insert(0, loc_at(q1))
    loc = mats_
    def apply(m, v):
        return (m[0] * v[0] + m[1] * v[1] + m[2] * v[2] + m[9], m[3] * v[0] + m[4] * v[1] + m[5] * v[2] + m[10],
                m[6] * v[0] + m[7] * v[1] + m[8] * v[2] + m[11])
    for m in mats_:
        verts = [apply(m, v) for v in verts]
    return dict(kind=7, mats=mats, verts=[[round(x, 4) for x in v] for v in verts], tris=tris, loc=loc)
n = 0
for f in sorted(glob.glob('raw/*.Solid.Gbx')):
    name = os.path.basename(f)[:-len('.Solid.Gbx')]
    out = 'meas/' + name + '.json'
    if os.path.exists(out): continue
    try:
        s = surf(f)
    except Exception as e:
        s = dict(error=str(e)[:200])
    json.dump(s, open(out, 'w')); n += 1
print('extracted', n)
