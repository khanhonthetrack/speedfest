"""Visual meshes of a decrypted .Solid.Gbx (the stadium surround, decorations): walks the solid's
tree (children, locations), reads each indexed triangle visual (vertices, triangles) with its
material's name, and the lights hung in the tree, all in solid space -> JSON (local measurements,
never committed). Layouts follow GBX.NET's chunk descriptions (format knowledge only).
usage: python3 -I visual_mesh.py SOLID.Gbx OUT.json [--uv]   (--uv: texture coordinates and normals too)"""
import sys, os, json, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gbxnode
from gbxnode import chunk, Ext
WANT_UV = '--uv' in sys.argv   # also texture coordinates (2 sets) and normals, for reference renders


# --- CPlugTree 0x0904F000 (and CPlugTreeVisualMip 0x09015000, CPlugTreeLight 0x09062000)
@chunk(0x0904F006)
def _(r, n): r.u32(); n['children'] = [r.noderef() for _ in range(r.u32())]
@chunk(0x0904F00D)
def _(r, n): n['name'] = r.ident(); r.ident()
@chunk(0x0904F011)
def _(r, n): n['func'] = r.noderef()
@chunk(0x0904F016)
def _(r, n):
    n['visual'] = r.noderef(); n['shader'] = r.noderef(); n['surface'] = r.noderef(); n['gen'] = r.noderef()
@chunk(0x0904F01A)
def _(r, n):
    fl = r.u32(); n['tflags'] = fl
    if fl & 4: n['loc'] = r.iso4()
@chunk(0x09015002)
def _(r, n): n['levels'] = [(r.f32(), r.noderef()) for _ in range(r.u32())]
@chunk(0x09062004)
def _(r, n): n['light'] = r.noderef()


# --- CPlugVisual 0x09006000, CPlugVisual3D 0x0902C000, CPlugVisualIndexed 0x0906A000
def chunk_flags(c):
    f = c & 15
    f |= (c << 1) & 0x20; f |= (c << 2) & 0x80; f |= (c << 2) & 0x100
    f |= (c << 13) & 0x100000; f |= (c << 13) & 0x200000; f |= (c << 13) & 0x400000
    return f
@chunk(0x09006001)
def _(r, n): r.ident()
@chunk(0x09006004)
def _(r, n): r.noderef()
@chunk(0x09006005)
def _(r, n): n['subvisuals'] = [(r.i32(), r.i32(), r.i32()) for _ in range(r.u32())]
@chunk(0x09006009)
def _(r, n): r.f32()
@chunk(0x0900600B)
def _(r, n): n['splits'] = [(r.i32(), r.i32(), r.vec(6)) for _ in range(r.u32())]
@chunk(0x0900600E)
def _(r, n):
    n['flags'] = chunk_flags(r.i32())
    ntc = r.i32(); n['count'] = cnt = r.i32()
    n['streams'] = [r.noderef() for _ in range(r.u32())]
    n['uvs'] = []
    for _ in range(ntc):
        v = r.i32()
        if v >= 3:
            assert r.i32() == cnt; fl = r.i32()
        stride = 8 + (4 if v >= 1 else 0) + (4 if v >= 2 else 0) if v < 3 else 8
        if WANT_UV and len(n['uvs']) < 2:   # u, v lead each texcoord vertex
            n['uvs'].append([struct.unpack_from('<2f', r.d, r.p + i * stride) for i in range(cnt)])
        r.p += cnt * stride
        if v >= 3: r.p += 4 * ((cnt * fl) & 0xFF)
    if n['flags'] & 7: raise ValueError('skinned visual')
    n['box'] = r.vec(6)
    k = r.u32(); r.p += 20 * k   # BitmapElemToPacks (read k first: r.p += f(r) loses f's advance)
@chunk(0x0902C002)
def _(r, n): r.noderef()
@chunk(0x0902C004)
def _(r, n):
    fl = n.get('flags', 0); bit = lambda b: fl & (1 << b)
    has_n = not bit(22) or bit(7); has_c = not bit(22) or bit(8)
    if not n.get('streams'):
        stride = 12 + ((4 if bit(20) else 12) if has_n else 0) + ((4 if bit(21) else 16) if has_c else 0)
        verts = []; norms = []
        for i in range(n['count']):
            verts.append(struct.unpack_from('<3f', r.d, r.p + i * stride))
            if WANT_UV and has_n and not bit(20):
                norms.append(struct.unpack_from('<3f', r.d, r.p + i * stride + 12))
        r.p += stride * n['count']
        n['verts'] = verts
        if norms: n['norms'] = norms
    per = (~((fl >> 17) & 0xFF) & 8) | 4
    for _ in range(2):
        k = r.i32(); r.p += k * per
@chunk(0x0906A001)
def _(r, n):
    if r.boolean():
        ib = gbxnode.Node(cls='09057000'); r.node_body(0x09057000, ib); n['indices'] = ib.get('indices', [])
@chunk(0x09057000)
def _(r, n):
    r.u32(); k = r.i32(); n['indices'] = list(struct.unpack_from('<%dH' % k, r.d, r.p)); r.p += 2 * k
@chunk(0x09057001)
def _(r, n):
    r.u32(); k = r.i32(); cur = 0; out = []
    for d in struct.unpack_from('<%dh' % k, r.d, r.p):
        cur += d; out.append(cur)
    r.p += 2 * k; n['indices'] = out


# --- CPlugSurface 0x0900C000 / CPlugSurfaceGeom 0x0900F000 (collision; read past it)
@chunk(0x0900C000)
def _(r, n):
    n['geom'] = r.noderef()
    for _ in range(r.u32()):
        if r.boolean(): r.noderef()
        else: r.i16()
@chunk(0x0900F004)
def _(r, n):
    r.ident(); r.vec(6); kind = r.i32()
    if kind == 0: r.f32()          # sphere: radius
    elif kind == 1: r.vec(3)       # ellipsoid: half axes
    elif kind == 6: r.vec(6)       # box
    elif kind == 7:                # mesh
        r.i32(); nv = r.u32(); r.p += 12 * nv
        nt = r.u32(); r.p += nt * (16 + 12 + 4)
        r.i32(); nc = r.u32(); r.p += nc * 32
    else: raise ValueError('surface kind %d' % kind)
    r.i16()


def mul(a, b):
    """a after b (iso4: 3x3 rows then translation)."""
    R = [[a[3 * i + 0] * b[0 + j] + a[3 * i + 1] * b[3 + j] + a[3 * i + 2] * b[6 + j] for j in range(3)] for i in range(3)]
    t = [a[3 * i] * b[9] + a[3 * i + 1] * b[10] + a[3 * i + 2] * b[11] + a[9 + i] for i in range(3)]
    return tuple(R[0] + R[1] + R[2] + t)
def apply(m, v):
    return (m[0] * v[0] + m[1] * v[1] + m[2] * v[2] + m[9], m[3] * v[0] + m[4] * v[1] + m[5] * v[2] + m[10],
            m[6] * v[0] + m[7] * v[1] + m[8] * v[2] + m[11])
ID = (1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
def short(ref):
    if isinstance(ref, Ext): return ref.name.split('/')[-1].split('.')[0]
    return None if ref is None else ref.get('cls')


def walk(tree, m, path, out, lights):
    if tree is None or isinstance(tree, Ext): return
    m = mul(m, tree['loc']) if 'loc' in tree else m
    name = path + '/' + str(tree.get('name', ''))
    v = tree.get('visual')
    if isinstance(v, gbxnode.Node) and v.get('verts') and v.get('indices'):
        idx = v['indices']
        o = dict(name=name, mat=short(tree.get('shader')),
                 verts=[[round(c, 3) for c in apply(m, p)] for p in v['verts']],
                 tris=[idx[i:i + 3] for i in range(0, len(idx) - 2, 3)])
        if WANT_UV:
            R = m[:9] + (0, 0, 0)
            if v.get('norms'): o['norms'] = [[round(c, 4) for c in apply(R, q)] for q in v['norms']]
            o['uvs'] = [[[round(c, 5) for c in t] for t in uv] for uv in v.get('uvs', [])]
        out.append(o)
    if 'light' in tree:
        lights.append(dict(name=name, light=short(tree['light']), loc=[round(c, 4) for c in m]))
    for c in tree.get('children', []) or []:
        walk(c, m, name, out, lights)
    for _, c in tree.get('levels', [])[:1]:   # the nearest level of detail only
        walk(c, m, name, out, lights)


if __name__ == '__main__':
    sys.argv = [a for a in sys.argv if a != '--uv']
    root, r = gbxnode.load(sys.argv[1])
    out, lights = [], []
    walk(root.get('tree'), ID, '', out, lights)
    json.dump(dict(meshes=out, lights=lights), open(sys.argv[2], 'w'))
    print('meshes', len(out), 'vertices', sum(len(o['verts']) for o in out), 'triangles',
          sum(len(o['tris']) for o in out), 'lights', len(lights))
