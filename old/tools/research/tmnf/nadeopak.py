"""Minimal TMF NadeoPak reader (format per GBX.NET.PAK, reimplemented for research).
usage: python3 -I nadeopak.py list PACKS_DIR PAKNAME [hashes.txt]
       python3 -I nadeopak.py extract PACKS_DIR PAKNAME HASHNAME OUTFILE [--raw]"""
import hashlib, struct, sys, os, zlib
from Crypto.Cipher import Blowfish

NAME_SALT = "6611992868945B0B59536FC3226F3FD0"
KEYSTR_SALT = "B97C1205648A66E04F86A1B5D5AF9862"
M64 = (1 << 64) - 1

def md5(s): return hashlib.md5(s.encode('ascii') if isinstance(s, str) else s).digest()

def parse_packlist(path):
    d = open(path, 'rb').read()
    ver, n = d[0], d[1]
    crc, salt = struct.unpack_from('<II', d, 2)
    name_key = md5(NAME_SALT + str(salt))
    p, out = 10, {}
    for _ in range(n):
        flags, ln = d[p], d[p + 1]; p += 2
        name = bytes(b ^ name_key[i % 16] for i, b in enumerate(d[p:p + ln])).decode('ascii'); p += ln
        k = md5(name + str(salt) + KEYSTR_SALT)
        keystr = bytes(b ^ k[i % 16] for i, b in enumerate(d[p:p + 32])).decode('ascii'); p += 32
        out[name.lower()] = (name, bytes.fromhex(keystr), flags)
    return out

def swap32(b):  # byte-reverse each 32-bit word (GBX.NET "LittleEndian" Blowfish == standard BF on swapped words)
    return b''.join(b[i:i + 4][::-1] for i in range(0, len(b), 4))

class BFStream:
    """CBC-like Nadeo stream cipher: iv' = (iv>>47) ^ (iv*9) ^ C (version >= 12) else iv' = C.
    ivxor (from Initialize) is folded into iv at stream start and every 0x100 bytes."""
    def __init__(self, data, pos, key, iv, version):
        self.ecb = Blowfish.new(swap32(key), Blowfish.MODE_ECB)
        self.d, self.pos, self.iv, self.ivxor, self.ver = data, pos, iv, 0, version
        self.bidx = 0; self.total = 0; self.buf = b''
    def initialize(self, data, off, count):
        for i in range(count):
            lo = self.ivxor & 0xFFFFFFFF; hi = self.ivxor >> 32
            lo = ((data[off + i] | 0xAA) ^ (((lo << 13) | (hi >> 19)) & 0xFFFFFFFF)) & 0xFFFFFFFF
            hi = ((self.ivxor << 13) & M64) >> 32
            self.ivxor = (hi << 32) | lo
    def read(self, n):
        out = bytearray()
        if self.total == 0:
            self.iv ^= self.ivxor; self.ivxor = 0
        for _ in range(n):
            if self.bidx % 8 == 0:
                if self.bidx == 0x100:
                    self.iv ^= self.ivxor; self.ivxor = 0; self.bidx = 0
                c = self.d[self.pos:self.pos + 8]; self.pos += 8
                if len(c) < 8: break
                nextiv = struct.unpack('<Q', c)[0]
                blk = struct.unpack('<Q', swap32(self.ecb.decrypt(swap32(c))))[0] ^ self.iv
                self.buf = struct.pack('<Q', blk)
                self.iv = (((self.iv >> 0x2f) ^ (self.iv * 9) ^ nextiv) & M64) if self.ver >= 12 else nextiv
            out.append(self.buf[self.bidx & 7]); self.bidx += 1; self.total += 1
        return bytes(out)

class R:
    def __init__(self, s): self.s = s
    def u8(self): return self.s.read(1)[0]
    def i32(self): return struct.unpack('<i', self.s.read(4))[0]
    def u32(self): return struct.unpack('<I', self.s.read(4))[0]
    def u64(self): return struct.unpack('<Q', self.s.read(8))[0]
    def bytes(self, n): return self.s.read(n)
    def string(self):
        n = self.i32(); return self.s.read(n).decode('utf-8', 'replace') if n else ''

class Plain:
    def __init__(self, d, p): self.d, self.p = d, p
    def read(self, n): b = self.d[self.p:self.p + n]; self.p += n; return b

def open_pak(packs_dir, pakname):
    keys = parse_packlist(os.path.join(packs_dir, 'packlist.dat'))
    name, basekey, flags = keys[pakname.lower()]
    key = md5(basekey.hex().upper() + 'NadeoPak')
    fn = next(x for x in os.listdir(packs_dir) if x.lower() == name.lower() + '.pak')
    d = open(os.path.join(packs_dir, fn), 'rb').read()
    assert d[:8] == b'NadeoPak', d[:8]
    version = struct.unpack_from('<i', d, 8)[0]
    p = 12
    if version >= 6:
        p += 32
    iv = struct.unpack_from('<Q', d, p)[0]; p += 8
    bs = BFStream(d, p, key, iv, version)
    r = R(bs)
    hdr = {'version': version}
    hdr['md5'] = r.bytes(16)
    hdr['gbx_headers_start'] = r.u32()
    if version < 15: hdr['data_start'] = r.i32()
    if version >= 2: hdr['gbx_headers_size'] = r.i32(); hdr['gbx_headers_compr'] = r.i32()
    if version >= 14:
        r.bytes(16)
        if version >= 16: r.u32()
    if version >= 3: r.bytes(16)
    hdr['flags'] = r.u32()
    nf = r.i32(); folders = []
    for _ in range(nf):
        parent = r.i32(); nm = r.string()
        if not nm.endswith('\\'): nm += '\\'
        folders.append((nm, parent))
    if len(folders) > 2 and len(folders[2][0]) > 4:
        bs.initialize(folders[2][0].encode('utf-16-le'), 4, 4)
    files = []
    n = r.i32()
    for _ in range(n):
        fi = r.i32(); nm = r.string(); u01 = r.i32(); usize = r.i32(); csize = r.i32(); off = r.u32(); cls = r.u32()
        size = r.i32() if version >= 17 else None
        r.bytes(16) if version >= 14 else None
        fl = r.u64()
        parts, k = [], fi
        while k != -1:
            parts.append(folders[k][0].rstrip('\\')); k = folders[k][1]
        files.append(dict(path='\\'.join(reversed(parts + [])) + '\\' + nm if parts else nm, name=nm,
                          usize=usize, csize=csize, off=off, cls=cls, flags=fl))
    return d, key, hdr, folders, files

def file_stream(d, key, hdr, f):
    p = hdr['data_start'] + f['off']
    enc = not (f['flags'] & 0x4000000000000) and not (f['flags'] & 0x2000000000000)
    if enc:
        iv = struct.unpack_from('<Q', d, p)[0]
        return BFStream(d, p + 8, key, iv, hdr['version']), enc
    return Plain(d, p), enc

if __name__ == '__main__':
    cmd = sys.argv[1]
    d, key, hdr, folders, files = open_pak(sys.argv[2], sys.argv[3])
    if cmd == 'list':
        hashes = {}
        if len(sys.argv) > 4:
            for line in open(sys.argv[4], encoding='utf-8', errors='replace'):
                parts = line.rstrip('\n').split(' ', 1)
                if len(parts) == 2: hashes[parts[0].upper()] = parts[1]
        print('#', hdr, len(folders), 'folders', len(files), 'files')
        for f in files:
            print(f"{f['cls']:08X} {f['usize']:9d} {f['csize']:9d} {f['flags']:016X} {f['path']} {hashes.get(f['name'].upper(), '')}")
    elif cmd == 'extract':
        want, outp = sys.argv[4].upper(), sys.argv[5]
        f = next(f for f in files if f['name'].upper() == want or f['path'].upper().endswith(want))
        s, enc = file_stream(d, key, hdr, f)
        compressed = bool(f['flags'] & 0x3C)
        raw = s.read(f['csize'] if compressed else f['usize'])
        out = zlib.decompress(raw) if (compressed and '--raw' not in sys.argv) else raw
        open(outp, 'wb').write(out)
        print('extracted', f['path'], 'enc', enc, 'compressed', compressed, len(raw), '->', len(out))
