"""Assembly via the REA bridge.  usage: asm.py SOCK ADDR"""
import json, subprocess, sys, os
here = os.path.dirname(os.path.abspath(__file__))
raw = subprocess.run([sys.executable, '-I', os.path.join(here, 'reacall.py'), sys.argv[1], 'procedure_assembly',
                      json.dumps({'procedure': sys.argv[2]})], capture_output=True, text=True).stdout
sc = json.loads(raw)['result']['structuredContent']
print(sc.get('raw_result', {}).get('value'))
