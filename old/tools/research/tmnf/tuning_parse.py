"""Parse a decrypted TMF StadiumCar.VehicleTunings.Gbx (CSceneVehicleTunings / CSceneVehicleCarTuning).
Chunk op lists transcribed from CSceneVehicleCarTuning::Chunk (TmForever 2.11.26).
usage: python3 tuning_parse.py FILE.gbx OUT.json"""
import struct, sys, json

# op: R=float, N=u32, B=bool, D=node ref, F=float buffer (count+floats); '-' = discarded/legacy
CAR = {
 0x00: 'R- R6c R70 R2c R114 R118 R11c R120 R124 R12c R3c R128', 0x01: 'I-', 0x02: 'R130 R144 R148',
 0x03: 'R- Ra4 R-', 0x04: 'B190', 0x05: 'R160', 0x06: 'R- R- R- R-', 0x07: 'R94', 0x08: 'R30 Rf0',
 0x09: 'R40', 0x0a: 'R154 R158', 0x0b: 'R134 R138 R13c R140', 0x0c: 'B-', 0x0d: 'N16c', 0x0e: 'N350',
 0x0f: 'R-', 0x10: 'N354 R98', 0x11: 'R- R- R- R- R- R- R- R- R-', 0x12: 'R388 R390 R394 R28',
 0x13: 'R- R- R- R- R- R- R- R- R- R- R- R-', 0x14: 'R- R-', 0x15: 'R388 R390 R38c R394 R28',
 0x16: 'R- R-', 0x17: 'R3a4 R3a8 R37c R- R- R- R- R-', 0x18: 'R154 R158 R15c',
 0x19: 'R170 R174 R178 R17c R180 R184 R188 R18c', 0x1a: 'R54', 0x1b: 'R-',
 0x1c: 'R38 R- Rb0 R50 R58 R194', 0x1d: 'R164 Rc0', 0x1e: 'N364', 0x1f: 'R- R- R-',
 0x20: 'Rc4 Rc8 Rcc Rd0', 0x21: 'R-', 0x22: 'R- R-', 0x23: 'Rec R74', 0x24: 'D34', 0x25: 'R- Ra8 R100',
 0x26: 'Rd4 Rd8 Rdc Re0', 0x27: 'R9c Rb4', 0x28: 'R38 Dac Rb0 R50 R58 R194', 0x29: 'Ra4 Db8', 0x2a: 'D68',
 0x2b: 'D78 Ra8 R100 N88', 0x2c: 'Dbc R368 R44 R48 R4c R5c', 0x2d: 'N8c', 0x2e: 'R7c R-', 0x2f: 'Nf8',
 0x30: 'Da0', 0x31: 'R60 R64', 0x32: 'R388 R390 R38c R394 R398 R39c R28 R3a0', 0x33: 'R14c', 0x34: 'R150',
 0x35: 'B80', 0x36: 'R19c R1a0 R1a8 D1b4', 0x37: 'D1c4', 0x38: 'R1c8 D1bc R1c0 R1b8', 0x39: 'R1a4 R1ac',
 0x3a: 'R1cc R1d0', 0x3b: 'R1b0', 0x3c: 'R1dc', 0x3d: 'D1e0', 0x3e: 'N1e8', 0x3f: 'D1ec', 0x40: 'D1f0',
 0x41: 'R1f4 N1f8', 0x42: 'N1fc', 0x43: 'N84', 0x44: 'R200', 0x45: 'R204 R- R- R208 R-',
 0x46: 'R204 R208 R20c D214 D218 D210', 0x47: 'R21c', 0x48: 'D24', 0x49: 'D224', 0x4a: 'R- R228',
 0x4b: 'R- R22c D230', 0x4c: '', 0x4d: 'R234', 0x4e: 'R238 R23c', 0x4f: 'R254 D25c',
 0x51: 'R2a0', 0x52: 'D250', 0x53: 'R27c', 0x54: 'F- F- F- F-', 0x55: 'F-', 0x56: 'R2ec R2f0 R2f4', 0x57: 'F-',
 0x58: 'R31c', 0x59: 'R320 R32c R324 R328', 0x5a: 'R334 R330 R338', 0x5b: 'D380 R384', 0x5c: 'R248 R24c',
 0x5d: 'R228 R22c D230 D260 R264 R258 R268 R278 R280 R284 R26c R270 R240 N298 R29c R2ac N2a8 R244 R2c0 '
       'R2b4 R2b0 D2a4 D288 R28c R2bc R290 R294 R2b8 R2d0 Fbuf0 Fbuf1 Fbuf2 N90',
 0x5e: 'D36c', 0x5f: 'R220', 0x60: 'R30 Rf0 Rf4 Nf8 Nfc', 0x61: 'D378', 0x62: 'R33c', 0x63: 'R340',
 0x64: 'R344', 0x65: 'R348', 0x66: 'R34c', 0x67: 'R-', 0x68: 'R-', 0x69: 'R-',
}

class Reader:
    def __init__(self, d, p=0): self.d, self.p = d, p; self.ids = []; self.idver = None; self.nodes = {}
    def u32(self): v = struct.unpack_from('<I', self.d, self.p)[0]; self.p += 4; return v
    def f32(self): v = struct.unpack_from('<f', self.d, self.p)[0]; self.p += 4; return v
    def string(self): n = self.u32(); s = self.d[self.p:self.p + n].decode('latin-1'); self.p += n; return s
    def floats(self): n = self.u32(); return [self.f32() for _ in range(n)]
    def mwid(self):
        if self.idver is None: self.idver = self.u32()
        v = self.u32()
        if v == 0xFFFFFFFF: return ''
        if v & 0xC0000000 and (v & 0x3FFFFFFF) == 0:
            s = self.string(); self.ids.append(s); return s
        if v & 0xC0000000: return self.ids[(v & 0x3FFFFFFF) - 1]
        return f'#{v}'
    def noderef(self):
        idx = self.u32()
        if idx == 0xFFFFFFFF: return None
        if idx in self.nodes: return {'ref': idx}
        cls = self.u32()
        node = {'idx': idx, 'cls': f'{cls:08X}'}
        self.nodes[idx] = node
        self.node_body(cls, node)
        return node
    def node_body(self, cls, node):
        while True:
            cid = self.u32()
            if cid == 0xFACADE01: return
            self.chunk(cls, cid, node)
    def chunk(self, cls, cid, node):
        if cid == 0x0A030000:
            node['bufver'] = self.u32(); n = self.u32()
            node['tunings'] = [self.noderef() for _ in range(n)]
            node['selected'] = self.u32()
        elif cid == 0x0A02E000:
            node['name'] = self.mwid(); node['curve_28_base'] = self.noderef(); node['f28'] = self.f32()
        elif cid == 0x0501A000:
            node['values'] = self.floats()
        elif cid == 0x0501A001:
            node['values'] = self.floats(); node['interp'] = self.u32()
        elif cid == 0x05002000:
            node['name'] = self.string()
        elif cid == 0x05002001:
            node['times'] = self.floats()
        elif cid == 0x05002002:
            node['range'] = [self.f32(), self.f32()]
        elif cid == 0x05002003:
            node['id'] = self.mwid()
        elif (cid & 0xFFFFF000) == 0x0A029000:
            ops = CAR[cid & 0xFFF]
            node.setdefault('chunks', []).append(f'{cid & 0xFFF:02x}')
            for op in ops.split():
                k, off = op[0], op[1:]
                if k == 'R': v = self.f32()
                elif k == 'N' or k == 'B': v = self.u32()
                elif k == 'D': v = self.noderef()
                elif k == 'F': v = self.floats()
                elif k == 'I': v = self.mwid()
                if off != '-':
                    node.setdefault('fields', {})[off if not off[0].isdigit() and off.startswith('buf') else f'0x{int(off, 16):03x}'] = v
                else:
                    node.setdefault('legacy', []).append((f'{cid & 0xFFF:02x}', k, v))
        else:
            raise ValueError(f'unknown chunk {cid:08X} in class {cls:08X} at {self.p - 4:#x}')

def parse(path):
    d = open(path, 'rb').read()
    assert d[:3] == b'GBX'
    r = Reader(d, 3)
    ver = struct.unpack_from('<H', d, 3)[0]; r.p = 5
    fmt = d[5:9]; r.p = 9
    cls = r.u32(); udsize = r.u32(); r.p += udsize
    nnodes = r.u32(); next_ = r.u32()
    assert next_ == 0, 'external refs not handled'
    root = {'cls': f'{cls:08X}', 'gbx': [ver, fmt.decode(), nnodes]}
    r.node_body(cls, root)
    assert r.p == len(d), (r.p, len(d))
    return root

if __name__ == '__main__':
    root = parse(sys.argv[1])
    json.dump(root, open(sys.argv[2], 'w'), indent=1, default=str)
    t = root['tunings']
    print('tunings', len(t), 'selected', root['selected'], 'bufver', root['bufver'])
    for i, n in enumerate(t):
        n = n if 'idx' in n else None
        print(i, n.get('name') if n else '?', 'chunks', len(n.get('chunks', [])) if n else '', 'fields', len(n.get('fields', {})) if n else '')
