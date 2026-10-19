"""Look up function VAs + sizes from TmForever.map (MSVC linker map).
usage: python3 -I fnmap.py TmForever.map <name-substring> [...]"""
import sys, re
src = sys.argv[1]
pats = [p.lower() for p in sys.argv[2:]]
line_re = re.compile(r'^\s*([0-9a-f]{4}):([0-9a-f]{8})\s+(\S+)\s+([0-9a-f]{8})\s+(f\s+)?(i\s+)?(\S+)?', re.I)
funcs = {}
in_pub = False
for line in open(src, encoding='latin-1'):
    if 'Publics by Value' in line or 'Static symbols' in line:
        in_pub = True
        continue
    if not in_pub:
        continue
    m = line_re.match(line)
    if not m:
        continue
    name, va, is_f, sec = m.group(3), int(m.group(4), 16), bool(m.group(5)), m.group(1)
    if va < 0x401000 or len(name) > 2000:
        continue
    if is_f and sec == '0001':
        funcs.setdefault(va, name)
order = sorted(funcs)
# next function VA gives an upper bound on the size
nxt = {va: (order[i+1] if i+1 < len(order) else va + 0x400) for i, va in enumerate(order)}
hits = [(va, funcs[va]) for va in order if any(p in funcs[va].lower() for p in pats)]
for va, name in hits:
    print(f"0x{va:08x} 0x{nxt[va]:08x} size={nxt[va]-va:6d}  {name}")
print(f"-- {len(hits)} hit(s), {len(funcs)} functions in map", file=sys.stderr)
