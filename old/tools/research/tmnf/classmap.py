"""Build {class_id: (name, parent_id)} for TmForever from GetMwClassId bodies + ModTMNF's ClassHierarchy.txt.
usage: classmap.py TmForever.exe seeds.tsv ClassHierarchy.txt out.json"""
import sys, re, json, struct
sys.path.insert(0, __import__('os').path.dirname(__file__))
import pe
p = pe.PE(sys.argv[1])
ids = {}
for line in open(sys.argv[2]):
    m = re.match(r'0x([0-9a-f]+)\tfunction\t\?GetMwClassId@(\w+)@@UBEKXZ', line)
    if m:
        b = p.read(int(m.group(1), 16), 6)
        if b[0] == 0xB8 and b[5] == 0xC3:
            ids[m.group(2)] = struct.unpack('<I', b[1:5])[0]
parent = {}
stack = []
for line in open(sys.argv[3], encoding='utf-8', errors='replace'):
    line = line.rstrip('\r\n')
    if not line.strip() or line.startswith('Class hierarchy'): continue
    depth = len(line) - len(line.lstrip(' '))
    name = line.strip()
    stack = stack[:depth]
    parent[name] = stack[-1] if stack else 'CMwNod'
    stack.append(name)
out = {}
for name, cid in ids.items():
    par = parent.get(name)
    out[f'{cid:08X}'] = [name, f'{ids[par]:08X}' if par in ids else None]
json.dump(out, open(sys.argv[4], 'w'), indent=0)
print(len(ids), 'class ids,', sum(1 for v in out.values() if v[1]), 'with parent ids')
for k in ('0A029000', '0A030000', '0501A000', '09005000', '0A039000', '0A02B000'):
    print(k, out.get(k))
