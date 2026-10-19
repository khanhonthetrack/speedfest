"""Decompile via the REA bridge and print the pseudocode.  usage: dc.py SOCK ADDR_OR_NAME [OUTFILE]"""
import json, subprocess, sys, os
sock, proc = sys.argv[1], sys.argv[2]
here = os.path.dirname(os.path.abspath(__file__))
raw = subprocess.run([sys.executable, '-I', os.path.join(here, 'reacall.py'), sock, 'procedure_pseudo_code',
                      json.dumps({'procedure': proc})], capture_output=True, text=True).stdout
d = json.loads(raw)
sc = d.get('result', {}).get('structuredContent')
if not sc:
    print(json.dumps(d)[:2000]); sys.exit(1)
txt = sc.get('raw_result', {}).get('value') or json.dumps(sc.get('normalized_result'))[:5000]
if len(sys.argv) > 3:
    open(sys.argv[3], 'w').write(txt)
    print(sys.argv[3], len(txt.splitlines()), 'lines')
else:
    print(txt)
