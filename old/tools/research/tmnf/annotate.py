"""Annotate decompiled CSceneVehicleCar code: tuning field reads -> T[off]{value of 20juin2006}.
usage: annotate.py tunings.json IN.c OUT.c"""
import json, re, sys
root = json.load(open(sys.argv[1])); t = root['tunings'][root['selected']]
nodes = {}
def walk(n):
    if isinstance(n, dict):
        if 'idx' in n: nodes[n['idx']] = n
        for v in n.values(): walk(v)
    elif isinstance(n, list):
        for v in n: walk(v)
walk(root)
def val(off):
    v = t['fields'].get(f'0x{off:03x}')
    if v is None: return '?'
    if isinstance(v, dict):
        c = nodes[v['ref']] if 'ref' in v else v
        return 'curve' + str([(round(a, 3), round(b, 3)) for a, b in zip(c.get('times', []), c.get('values', []))])
    if isinstance(v, float): return f'{v:.6g}'
    return str(v)
src = open(sys.argv[2]).read()
src = re.sub(r'__A__CFastBuffer_PBVCMwClassInfo____QAEAAPBVCMwClassInfo__K_Z', 'TUNING_AT', src)
src = re.sub(r'__A__CFastBuffer_USSimulationWheel_CSceneVehicleCar____QBEABUSSimulationWheel_CSceneVehicleCar__K_Z', 'WHEEL', src)
src = re.sub(r'_GetCount___CFastBuffer_USPolyGroup_CPlugModelMesh____QBEKXZ', 'WHEELCOUNT', src)
src = re.sub(r'_([A-Za-z0-9]+)_CSceneVehicleCar(Tuning)?__[A-Za-z0-9_]*', lambda m: m.group(1), src)
src = re.sub(r'\s*\(\s*\*\(undefined4 \*\)\(\*\(int \*\)\(in_ECX \+ 100\) \+ 0x24\)\)', '()', src)
src = re.sub(r'\(\*\(undefined4 \*\)\((iVar\d+|in_ECX\[0x19\]) \+ 0x24\)\)', '()', src)
tv = set(re.findall(r'(\w+) = \(int \*\)\s*TUNING_AT\s*\(\)', src))
src = re.sub(r'\n\s*(\w+) = \(int \*\)\s*TUNING_AT\s*\(\);', '', src)
src = re.sub(r'\n\s*TUNING_AT\s*\(\);', '', src)
def rep(m):
    var, off = m.group(2), m.group(3)
    if var not in tv: return m.group(0)
    o = int(off, 16) if off.startswith('0x') else int(off)
    return f'T[0x{o:x}]{{{val(o)}}}'
src = re.sub(r'\*\((float|int|uint|undefined4) \*\)\(\*(\w+) \+ (0x[0-9a-f]+|\d+)\)', rep, src)
open(sys.argv[3], 'w').write(src)
print(sys.argv[3], len(src.splitlines()))
