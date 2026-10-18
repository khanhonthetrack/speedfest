"""Local reference renders of TMNF's own look: every decrypted solid's visual meshes with texture
coordinates (visual_mesh.py --uv), each material's textures (diffuse/normal/specular names read
from its .Material.Gbx), and the install's .dds images as PNG. The remake's map viewer and race
draw blocks with them when started with --ref=OUT (stadium/blocks/tm_ref_visuals.gd), so ours
and the original can be compared at the same camera. Everything lands in OUT, outside the repo:
it is Nadeo's data, NEVER commit it.
usage: python3 -I ref_visuals.py WORK OUT        (WORK as for setup_measurements.sh)
  OUT/vis/<Shape>.json   (shape name with / as __, as in WORK/blocks/raw)
  OUT/materials.json     material -> {"D": texture, "N": ..., "S": ..., ...}
  OUT/tex/<Texture>.png"""
import sys, os, re, json, glob, subprocess
from PIL import Image

T = os.path.dirname(os.path.abspath(__file__))
work, out = sys.argv[1], sys.argv[2]
raw = os.path.join(work, 'blocks', 'raw')
os.makedirs(os.path.join(out, 'vis'), exist_ok=True)
os.makedirs(os.path.join(out, 'tex'), exist_ok=True)

# materials -> texture names by role (the name's last capital: D diffuse, N normal, S specular,
# O occlusion, L light, or the whole name for single-texture materials)
mats = {}
for f in sorted(glob.glob(os.path.join(raw, '*.Material.Gbx'))):
    name = os.path.basename(f)[:-len('.Material.Gbx')]
    texs = re.findall(rb'([A-Za-z0-9_]+)\.Texture\.gbx', open(f, 'rb').read(), re.I)
    roles = {}
    for t in dict.fromkeys(x.decode() for x in texs):
        if t.startswith(('Default', 'Fresnel', 'Env', 'Specular', 'Amb')):
            continue
        m = re.match(r'(.*?)(D|N|S|O|L|O2|L2|Glow)$', t)
        role = m.group(2) if m and m.group(1) else 'D'
        roles.setdefault(role, t)
    if roles:
        mats[name] = roles
json.dump(mats, open(os.path.join(out, 'materials.json'), 'w'), indent=0, sort_keys=True)
print('materials', len(mats))

# textures
app = os.path.join(work, 'tmnf', 'app', 'GameData')
done = set(os.path.splitext(x)[0] for x in os.listdir(os.path.join(out, 'tex')))
nt = 0
for root, _, files in os.walk(app):
    for f in files:
        if not f.lower().endswith('.dds'):
            continue
        n = os.path.splitext(f)[0]
        if n in done:
            continue
        try:
            im = Image.open(os.path.join(root, f)); im.load()
            im.save(os.path.join(out, 'tex', n + '.png')); done.add(n); nt += 1
        except Exception as e:
            print('texture', f, e)
print('textures', nt)

# visual meshes
ok = bad = 0
for f in sorted(glob.glob(os.path.join(raw, '*.Solid.Gbx'))):
    shape = os.path.basename(f)[:-len('.Solid.Gbx')]
    dst = os.path.join(out, 'vis', shape + '.json')
    if os.path.exists(dst):
        continue
    r = subprocess.run([sys.executable, '-I', os.path.join(T, 'visual_mesh.py'), f, dst, '--uv'],
                       capture_output=True, text=True)
    if r.returncode == 0:
        ok += 1
    else:
        bad += 1
        print('solid', shape, (r.stderr.strip().splitlines() or ['?'])[-1][:100])
print('solids', ok, 'failed', bad)
