"""Disassemble a VA range of a PE32 with objdump and annotate call/const targets from the .map.
usage: python3 -I dis.py TmForever.exe TmForever.map 0xSTART 0xEND"""
import sys, re, subprocess, struct
exe, mapf, start, end = sys.argv[1], sys.argv[2], int(sys.argv[3], 16), int(sys.argv[4], 16)

line_re = re.compile(r'^\s*([0-9a-f]{4}):([0-9a-f]{8})\s+(\S+)\s+([0-9a-f]{8})\s+(f\s+)?(i\s+)?(\S+)?', re.I)
names = {}
in_pub = False
for line in open(mapf, encoding='latin-1'):
    if 'Publics by Value' in line or 'Static symbols' in line:
        in_pub = True; continue
    if not in_pub: continue
    m = line_re.match(line)
    if not m: continue
    nm, va = m.group(3), int(m.group(4), 16)
    if va >= 0x401000 and len(nm) <= 2000:
        names.setdefault(va, nm)

# PE: VA -> file offset, for reading float constants
d = open(exe, 'rb').read()
pe = struct.unpack_from('<I', d, 0x3c)[0]
nsec = struct.unpack_from('<H', d, pe + 6)[0]; optsz = struct.unpack_from('<H', d, pe + 20)[0]
base = struct.unpack_from('<I', d, pe + 24 + 28)[0]
secs = []
for i in range(nsec):
    nm, vs, va, rs, ro = struct.unpack_from('<8sIIII', d, pe + 24 + optsz + i * 40)
    secs.append((base + va, vs, ro, rs))
def off(va):
    for sva, vs, ro, rs in secs:
        if sva <= va < sva + max(vs, rs) and va - sva < rs:
            return ro + (va - sva)
    return None
def f32(va):
    o = off(va)
    return struct.unpack_from('<f', d, o)[0] if o is not None else None
def f64(va):
    o = off(va)
    return struct.unpack_from('<d', d, o)[0] if o is not None else None

out = subprocess.run(['objdump', '-d', '-b', 'pei-i386', '-m', 'i386',
                      f'--start-address=0x{start:x}', f'--stop-address=0x{end:x}',
                      '--no-show-raw-insn', exe], capture_output=True, text=True).stdout

hexre = re.compile(r'0x([0-9a-f]{6,8})\b')
for ln in out.splitlines():
    if not re.match(r'^\s*[0-9a-f]+:', ln):
        continue
    note = []
    # call/jmp targets
    m = re.search(r'(call|jmp)\s+0x([0-9a-f]+)', ln)
    if m:
        t = int(m.group(2), 16)
        if t in names: note.append(names[t])
    # float loads from .rdata
    for mm in re.finditer(r'(flds|fldl|fld|movss|mulss|comiss|ucomiss|addss|subss)\s+[^#\n]*?0x([0-9a-f]{6,8})', ln):
        t = int(mm.group(2), 16)
        v = f64(t) if mm.group(1) == 'fldl' else f32(t)
        if v is not None and (abs(v) < 1e8):
            nm = names.get(t, '')
            note.append(f"[{v:g}]{(' ' + nm) if nm else ''}")
    # any other known symbol reference
    for mm in hexre.finditer(ln):
        t = int(mm.group(1), 16)
        if t in names and names[t] not in note and not m:
            note.append(names[t])
    print(ln.rstrip() + ('    ; ' + ' | '.join(note) if note else ''))
