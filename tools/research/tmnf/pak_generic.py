"""Decrypt any zlib+Blowfish TMF pak entry: emulate TmForever's reader (256-byte zlib input blocks,
1024-byte output blocks) and the IV re-keys: every node read (parent class id, from classmap.json),
CSceneVehicleTuning names (first 4 bytes) and CPlugSurfaceGeom boxes (X - X2). Adler-32 validates.
usage: pak_generic.py classmap.json PACKS PAK HASHNAME OUT"""
import sys, os, struct, zlib, re, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nadeopak

CM = {int(k, 16): (v[0], int(v[1], 16) if v[1] else 0x01001000) for k, v in json.load(open(sys.argv[1])).items()}
def ancestors(c):
    out = []
    while c in CM and c not in out:
        out.append(c); c = CM[c][1]
    out.append(0x01001000)
    return out

class Scanner:
    """Finds the IV re-key events in decompressed GBX bytes: node reads (indexed or inline: class id
    followed by a chunk of its class family), tuning names and CPlugSurfaceGeom boxes."""
    def __init__(self, nnodes, root_cls, body):
        self.nnodes = nnodes; self.root = (root_cls, body); self.nodes = {}; self.done = 0
    def scan(self, out):
        start = max(0, self.done - 128)
        self.nodes = {q: c for q, c in self.nodes.items() if q < start + 4}
        n = len(out)
        for p in range(max(4, start), n - 3):
            cid = struct.unpack_from('<I', out, p)[0]
            if cid not in CM or (cid & 0xFFF): continue
            if p + 8 <= n:
                ch = struct.unpack_from('<I', out, p + 4)[0]
                if (ch & 0xFFFFF000) not in ancestors(cid) and ch != 0xFACADE01: continue
            else:  # chunk id not decompressed yet: accept only an indexed ref, re-verified next scan
                if p + 4 > n: continue
                idx = struct.unpack_from('<I', out, p - 4)[0]
                if not (0 < idx <= self.nnodes): continue
            self.nodes[p + 4] = struct.pack('<I', CM[cid][1])
        self.done = n
        calls = dict(self.nodes)
        if self.root[1] <= n and self.root[0] in CM:
            calls[self.root[1]] = struct.pack('<I', CM[self.root[0]][1])
        names = []
        # CSceneVehicleTuning chunk 0x0A02E000: name id, curve node, float, then name[0:4]
        for m in re.finditer(rb'\x00\xe0\x02\x0a', out):
            q = m.end()
            if q + 8 > n: break
            v = struct.unpack_from('<I', out, q)[0]
            if v == 3: q += 4; v = struct.unpack_from('<I', out, q)[0]
            q += 4
            if v == 0x40000000:
                k = struct.unpack_from('<I', out, q)[0]; q += 4
                if q + k > n: break
                name = out[q:q + k]; q += k
                if name not in names: names.append(name)
            elif v & 0x40000000 and 0 < (v & 0xFFFFFF) <= len(names):
                name = names[(v & 0xFFFFFF) - 1]
            else: continue
            e = out.find(b'\x01\xde\xca\xfa', q)
            if e < 0 or e + 8 > n: break
            calls[e + 8] = name[:4]
        # CPlugSurfaceGeom chunk 0x0900F004: id, box(6 floats), then (X - X2) float bytes
        for m in re.finditer(rb'\x04\xf0\x00\x09', out):
            q = m.end()
            if q + 8 > n: break
            v = struct.unpack_from('<I', out, q)[0]
            if v in (2, 3): q += 4; v = struct.unpack_from('<I', out, q)[0]
            q += 4
            if v == 0x40000000:
                q += 4 + struct.unpack_from('<I', out, q)[0]
            if q + 24 > n: break
            x, y, z, x2, y2, z2 = struct.unpack_from('<6f', out, q)
            calls[q + 24] = struct.pack('<f', x - x2)
        return sorted(calls.items())

def run(packs, pak, want, nout=1024, inblk=256):
    d, key, hdr, folders, files = nadeopak.open_pak(packs, pak)
    f = next(f for f in files if f['name'].upper() == want.upper())
    s, enc = nadeopak.file_stream(d, key, hdr, f)
    comp = bool(f['flags'] & 0x3C)
    total = f['csize'] if comp else f['usize']
    dobj = zlib.decompressobj() if comp else None
    out = b''; folded = 0; consumed = 0; sc = None
    while consumed < total:
        if sc is None and len(out) >= 21 and out[:3] == b'GBX':
            uds = struct.unpack_from('<I', out, 13)[0]
            if len(out) >= 21 + uds:
                sc = Scanner(struct.unpack_from('<I', out, 17 + uds)[0], struct.unpack_from('<I', out, 9)[0], 25 + uds)
        calls = sc.scan(out) if sc else []
        limit = (len(out) // nout) * nout if (comp and consumed) else len(out)
        todo = [c for p, c in calls[folded:] if p <= limit]
        s.ivxor = 0
        for c in todo: s.initialize(c, 0, 4)
        folded += len(todo)
        n = min(inblk, total - consumed)
        chunk = s.read(n); consumed += n
        try:
            out += dobj.decompress(chunk) if comp else chunk
        except zlib.error as e:
            return None, f'zlib error near cipher {consumed}, out {len(out)}: {e}'
    if comp:
        try: out += dobj.flush()
        except zlib.error as e: return None, f'flush error {e}'
        if not dobj.eof or len(out) != f['usize']:
            return None, f'incomplete eof={dobj.eof} len={len(out)}'
    return out, f'OK {len(out)} bytes, folded {folded}, compressed={comp}'

if __name__ == '__main__':
    out, msg = run(*sys.argv[2:5])
    print(msg)
    if out: open(sys.argv[5], 'wb').write(out)
