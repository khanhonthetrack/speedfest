"""Extract the 7z archive inside a 7-Zip SFX .exe with py7zr (no 7z binary needed).
usage: sfx7z.py SFX.exe OUTDIR"""
import io, mmap, os, sys
import py7zr

class Window(io.RawIOBase):
    def __init__(self, f, base):
        self.f, self.base = f, base
        f.seek(0, 2); self.size = f.tell() - base; f.seek(base)
    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.f.tell() - self.base
    def seek(self, off, whence=0):
        if whence == 0: self.f.seek(self.base + off)
        elif whence == 1: self.f.seek(off, 1)
        else: self.f.seek(self.base + self.size + off)
        return self.tell()
    def readinto(self, b):
        d = self.f.read(len(b)); b[:len(d)] = d; return len(d)
    def read(self, n=-1): return self.f.read(n)

src, out = sys.argv[1], sys.argv[2]
f = open(src, 'rb')
m = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
sig = b'7z\xbc\xaf\x27\x1c'
i = m.find(sig)
while i >= 0:
    try:
        z = py7zr.SevenZipFile(io.BufferedReader(Window(f, i)))
        print('archive at', i, z.getnames()[:20])
        os.makedirs(out, exist_ok=True)
        z.extractall(out)
        print('extracted to', out)
        break
    except Exception as e:
        print('not at', i, type(e).__name__, e)
    i = m.find(sig, i + 1)
