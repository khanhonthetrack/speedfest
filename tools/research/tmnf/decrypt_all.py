"""Decrypt pack entries (block infos, solids) into raw/, the fast emulator first, the backtracking
search if that fails. usage: decrypt_all.py SP PATTERN [MAXSIZE]"""
import sys, os, re, subprocess
SP = sys.argv[1]; maxsize = int(sys.argv[3]) if len(sys.argv) > 3 else 10**9
if sys.argv[2].startswith('@'):   # a list file of names (path tails, '/' or '\\')
    tails = [l.strip().replace('/', '\\') for l in open(sys.argv[2][1:]) if l.strip()]
    tails = [t.split('Solid\\', 1)[-1] if t.startswith('Media\\Solid\\') else t for t in tails]
    pat = re.compile('|'.join(re.escape(t) + '$' for t in tails), re.I)
else:
    pat = re.compile(sys.argv[2], re.I)
sys.argv = ['x', SP + '/classmap.json']
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nadeopak
d, key, hdr, folders, files = nadeopak.open_pak(SP + '/tmnf/app/Packs', 'Stadium')
hashes = {}
for line in open(SP + '/pak_Stadium.txt'):
    parts = line.split()
    if len(parts) >= 6 and not line.startswith('#'):
        hashes[parts[4]] = parts[5]
T = os.path.dirname(os.path.abspath(__file__)) + '/'
ok = bad = 0
for f in files:
    nice = hashes.get(f['path'], f['path'].split('\\')[-1])
    if not (pat.search(nice) or pat.search(f['path'])) or f['usize'] > maxsize: continue
    out = 'raw/' + nice.replace('\\', '__')
    if os.path.exists(out): ok += 1; continue
    r = subprocess.run(['python3', '-I', T + 'pak_generic.py', SP + '/classmap.json', SP + '/tmnf/app/Packs', 'Stadium', f['name'], out], capture_output=True, text=True)
    if not os.path.exists(out):
        r = subprocess.run(['timeout', '60', 'python3', '-I', T + 'pak_search.py', SP + '/classmap.json', SP + '/tmnf/app/Packs', 'Stadium', f['name'], out], capture_output=True, text=True)
    if os.path.exists(out): ok += 1
    else: bad += 1; print('FAIL', nice, r.stdout.strip()[-120:], flush=True)
print('ok', ok, 'failed', bad)
