"""Convert an MSVC linker .map (TmForever.map) into a REA Ghidra seed TSV.
usage: python3 -I map2seeds.py TmForever.map out.tsv"""
import sys, re
src, dst = sys.argv[1], sys.argv[2]
line_re = re.compile(r'^\s*([0-9a-f]{4}):([0-9a-f]{8})\s+(\S+)\s+([0-9a-f]{8})\s+(f\s+)?(i\s+)?(\S+)?', re.I)
funcs, labels = {}, {}
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
    sec, name, va, is_f = m.group(1), m.group(3), int(m.group(4), 16), bool(m.group(5))
    if va < 0x401000 or any(c.isspace() for c in name) or len(name) > 2000:
        continue
    if is_f and sec == '0001':
        # COMDAT folding puts several names on one address; keep the first (usually the real owner)
        funcs.setdefault(va, name)
    elif not is_f:
        labels.setdefault(va, name)
with open(dst, 'w') as out:
    out.write('# seeds generated from TmForever.map (Publics by Value + Static symbols)\n')
    for va in sorted(funcs):
        out.write(f'0x{va:x}\tfunction\t{funcs[va]}\n')
    for va in sorted(labels):
        if va in funcs:
            continue
        out.write(f'0x{va:x}\tlabel\t{labels[va]}\n')
print('functions', len(funcs), 'labels', len([v for v in labels if v not in funcs]))
