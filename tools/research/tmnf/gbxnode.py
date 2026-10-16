"""Minimal TMF GBX body reader for decrypted pack files (block infos, mobils): node refs, external
refs, lookback ids, skippable chunks, and readers for the chunks block infos use. Layouts follow
GBX.NET's chunk descriptions (format knowledge only)."""
import struct, sys
FACADE = 0xFACADE01; PIKS = 0x534B4950

class Ext:
    def __init__(self, name): self.name = name
    def __repr__(self): return f'Ext({self.name})'

class Node(dict):
    pass

class Reader:
    def __init__(self, data):
        self.d = data; self.p = 0
        self.ids = []; self.idver = None
        self.nodes = {}; self.refs = {}
        self.unknown = []
    def u8(self): v = self.d[self.p]; self.p += 1; return v
    def u16(self): v = struct.unpack_from('<H', self.d, self.p)[0]; self.p += 2; return v
    def i16(self): v = struct.unpack_from('<h', self.d, self.p)[0]; self.p += 2; return v
    def u32(self): v = struct.unpack_from('<I', self.d, self.p)[0]; self.p += 4; return v
    def i32(self): v = struct.unpack_from('<i', self.d, self.p)[0]; self.p += 4; return v
    def f32(self): v = struct.unpack_from('<f', self.d, self.p)[0]; self.p += 4; return v
    def vec(self, n): v = struct.unpack_from('<%df' % n, self.d, self.p); self.p += 4 * n; return v
    def boolean(self): return self.u32() != 0
    def string(self):
        n = self.u32(); s = self.d[self.p:self.p + n].decode('latin1'); self.p += n; return s
    def peek(self): return struct.unpack_from('<I', self.d, self.p)[0]
    def ident(self):
        if self.idver is None:
            self.idver = self.u32()
        v = self.u32()
        if v == 0xFFFFFFFF: return ''
        if v & 0xC0000000 in (0x40000000, 0x80000000):
            if v & 0x3FFFFFFF == 0:
                s = self.string(); self.ids.append(s); return s
            k = (v & 0x3FFFFFFF) - 1
            return self.ids[k] if k < len(self.ids) else '?%d' % k
        if v == 0: s = self.string(); self.ids.append(s); return s
        return f'#{v}'
    def iso4(self): return self.vec(12)
    def noderef(self):
        idx = self.i32()
        if idx == -1: return None
        if idx in self.refs: return self.refs[idx]
        if idx in self.nodes: return self.nodes[idx]
        cls = self.u32()
        node = Node(cls='%08X' % cls)
        self.nodes[idx] = node
        self.node_body(cls, node)
        return node
    def node_body(self, cls, node):
        while True:
            cid = self.u32()
            if cid == FACADE: return
            fn = CHUNKS.get(cid)
            if self.p + 8 <= len(self.d) and self.peek() == PIKS:
                self.p += 4; size = self.u32()
                if fn:
                    end = self.p + size
                    fn(self, node); self.p = end
                else:
                    node.setdefault('skipped', []).append('%08X' % cid); self.p += size
                continue
            if fn is None:
                raise ValueError('unknown chunk %08X at %d in %s' % (cid, self.p - 4, node.get('cls')))
            fn(self, node)

def read_reftable(r, uds):
    p = 17 + uds
    r.p = p
    nn = r.u32(); ne = r.u32()
    folders = []
    def fold(path):
        n = r.u32()
        for _ in range(n):
            name = r.string(); folders.append(path + name + '/'); fold(path + name + '/')
    if ne:
        r.u32()
        fold('')
        for _ in range(ne):
            flags = r.u32()
            name = r.string() if (flags & 4) == 0 else 'res#%d' % r.u32()
            idx = r.u32(); r.u32()
            fi = r.u32() if (flags & 4) == 0 else 0   # folder index only for named refs
            r.refs[idx - 1 if False else idx] = Ext((folders[fi - 1] if 0 < fi <= len(folders) else '') + name)
    return nn

def load(path):
    d = open(path, 'rb').read()
    r = Reader(d)
    cls = struct.unpack_from('<I', d, 9)[0]
    uds = struct.unpack_from('<I', d, 13)[0]
    read_reftable(r, uds)
    # node indices are 1-based in refs; nodes use the index written in the stream
    r.refs = {k: v for k, v in r.refs.items()}
    root = Node(cls='%08X' % cls)
    r.nodes[0] = root
    r.node_body(cls, root)
    return root, r

def arr_noderef(r):
    return [r.noderef() for _ in range(r.u32())]

CHUNKS = {}
def chunk(cid):
    def deco(f): CHUNKS[cid] = f; return f
    return deco

# --- CGameCtnCollector 0x0301A000 (TMF body chunks)
@chunk(0x0301A006)
def _(r, n): n['skin_kind'] = r.i32()
@chunk(0x0301A007)
def _(r, n):
    n['internal'] = r.boolean(); r.boolean(); n['catalog_pos'] = r.i32(); r.i32(); r.i32(); r.i32()
@chunk(0x0301A009)
def _(r, n):
    n['page'] = r.string()
    if r.boolean(): n['icon'] = r.noderef()
    n['parent_collector'] = r.ident()
@chunk(0x0301A00A)
def _(r, n): r.ident()
@chunk(0x0301A00B)
def _(r, n): n['ident'] = (r.ident(), r.ident(), r.ident())

# --- CGameCtnBlockInfo 0x0304E000
@chunk(0x0304E005)
def _(r, n):
    n['id'] = r.ident(); r.i32(); r.i32(); r.i32()
    n['is_pillar'] = r.boolean(); n['selection'] = r.i32(); r.i32()
    n['pillar'] = r.noderef()
    n['ground_units'] = arr_noderef(r)
    n['air_units'] = arr_noderef(r)
    n['ground_mobils'] = [arr_noderef(r) for _ in range(r.u32())]
    n['air_mobils'] = [arr_noderef(r) for _ in range(r.u32())]
    r.u8(); r.i32(); r.i16(); r.i16()
@chunk(0x0304E009)
def _(r, n): n['is_pillar2'] = r.boolean()
@chunk(0x0304E00C)
def _(r, n):
    n['spawn_ground'] = r.iso4(); n['spawn_air'] = r.iso4()
@chunk(0x0304E00D)
def _(r, n): n['is_replacement'] = r.boolean()
@chunk(0x0304E00E)
def _(r, n):
    n['waypoint'] = r.i32(); n['ground_helper'] = r.noderef(); n['air_helper'] = r.noderef(); n['constr_helper'] = r.noderef()
@chunk(0x0304E00F)
def _(r, n): n['no_respawn'] = r.boolean()
@chunk(0x03052000)
def _(r, n): n['slope'] = r.noderef()

# --- CGameCtnBlockUnitInfo 0x03036000
@chunk(0x03036000)
def _(r, n):
    n['place_pylons'] = r.i32(); r.boolean(); r.boolean()
    n['offset'] = (r.i32(), r.i32(), r.i32())
    n['clips'] = arr_noderef(r)
@chunk(0x03036001)
def _(r, n):
    n['surface'] = r.ident(); n['frontier'] = r.i32(); n['dir'] = r.i32()
@chunk(0x03036002)
def _(r, n): n['underground'] = r.boolean()
@chunk(0x03036003)
def _(r, n):
    n['replacement'] = r.noderef(); n['repl_id'] = r.ident(); r.i32(); r.i32()
@chunk(0x03036004)
def _(r, n): n['accept_pylons'] = r.i32()
@chunk(0x03036005)
def _(r, n): n['terrain_modifier'] = r.ident()

# --- CSceneObject / CSceneMobil / CHmsItem
@chunk(0x0A005001)
def _(r, n): n['name'] = r.ident()
@chunk(0x0A005003)
def _(r, n): r.noderef()
@chunk(0x0A011003)
def _(r, n): n['links'] = arr_noderef(r)
@chunk(0x0A011005)
def _(r, n):
    item = Node(cls='06003000'); r.node_body(0x06003000, item); n['item'] = item
@chunk(0x0A011006)
def _(r, n): r.noderef()
@chunk(0x06003001)
def _(r, n): n['solid'] = r.noderef()
@chunk(0x06003011)
def _(r, n):  # ulong flags, short
    n['flags11'] = (r.u32(), r.u32()); r.i16()

# --- CPlugSolid 0x09005000 (the mobil's solid points to the external tree/solid file)
@chunk(0x09005000)
def _(r, n): n['type_index'] = r.i32()
@chunk(0x0900500E)
def _(r, n): n['mass'] = r.vec(4); n['iso'] = r.iso4()
@chunk(0x09005010)
def _(r, n): r.noderef()
@chunk(0x09005011)
def _(r, n):
    r.boolean(); has = r.boolean()
    if has: r.boolean()
    n['tree'] = r.noderef()
@chunk(0x09005012)
def _(r, n): r.u8()

# --- CGameCtnBlockInfoClip 0x03053000
@chunk(0x03053002)
def _(r, n): n['asym_clip'] = r.ident()
@chunk(0x03053004)
def _(r, n): n['full_free'] = r.boolean(); r.boolean()
@chunk(0x03053005)
def _(r, n): n['clip_type'] = r.i32()
@chunk(0x03053006)
def _(r, n):
    v = r.u32(); r.boolean()
    if v >= 1: r.i32()
    for k in range(2, 5):
        if v >= k: r.u8()
@chunk(0x03053007)
def _(r, n):
    r.u32()
    if r.boolean(): n['passing_point'] = r.vec(2) + r.vec(2)
