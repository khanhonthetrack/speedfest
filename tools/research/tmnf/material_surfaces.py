"""Physics surface id of every decrypted material (raw/*.Material.Gbx from decrypt_all.py): the
id stored in the material's surface chunk 0x0907900E, or null when it has none. Writes
material_surfaces.json (numbers only). Ids follow TmTuning.Surface (0 Concrete, 2 Grass, 4 Metal,
6 Dirt, 7 Turbo, 9 Rubber, 16 Asphalt, ...).
usage (in the scratch blocks dir): material_surfaces.py [raw] [out.json]"""
import glob, struct, json, os, sys, collections

raw = sys.argv[1] if len(sys.argv) > 1 else 'raw'
outp = sys.argv[2] if len(sys.argv) > 2 else 'material_surfaces.json'
out = {}
for f in sorted(glob.glob(os.path.join(raw, '*.Material.Gbx'))):
    d = open(f, 'rb').read()
    p = d.find(b'\x0e\x90\x07\x09')
    name = os.path.basename(f)[:-len('.Material.Gbx')]
    out[name] = struct.unpack_from('<h', d, p + 4)[0] if p >= 0 else None
json.dump(out, open(outp, 'w'), indent=0, sort_keys=True)
print(len(out), 'materials;', dict(collections.Counter(out.values())))
