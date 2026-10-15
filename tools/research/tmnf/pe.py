"""Tiny PE32 reader: VA -> bytes."""
import struct
class PE:
    def __init__(self, path):
        self.d = open(path, 'rb').read()
        pe = struct.unpack_from('<I', self.d, 0x3c)[0]
        n = struct.unpack_from('<H', self.d, pe + 6)[0]; opt = struct.unpack_from('<H', self.d, pe + 20)[0]
        self.base = struct.unpack_from('<I', self.d, pe + 24 + 28)[0]
        self.secs = []
        for i in range(n):
            name, vs, va, rs, ro = struct.unpack_from('<8sIIII', self.d, pe + 24 + opt + i * 40)
            self.secs.append((name.rstrip(b'\0'), self.base + va, vs, ro, rs))
    def off(self, va):
        for name, sva, vs, ro, rs in self.secs:
            if sva <= va < sva + max(vs, rs):
                return ro + (va - sva) if va - sva < rs else None
        return None
    def read(self, va, n):
        o = self.off(va); return self.d[o:o + n] if o is not None else b'\0' * n
    def u32(self, va): return struct.unpack('<I', self.read(va, 4))[0]
    def i32(self, va): return struct.unpack('<i', self.read(va, 4))[0]
    def f32(self, va): return struct.unpack('<f', self.read(va, 4))[0]
    def cstr(self, va, n=200):
        b = self.read(va, n); return b.split(b'\0')[0].decode('latin-1')
