"""Splits a Blender scene of buildings into one glTF (.glb) per building for the city (TmCityAssets).

The owner's Blend Swap scenes hold several buildings each (a skyscraper district, a hotel, twelve
small towers) with cameras, lights, ground planes and trees. This keeps the buildings: objects
whose footprints overlap or touch become one building; each is moved so its foot's centre is the
origin, scaled to metres, and exported without images (we dress them in our own materials by
their material names; --images keeps baked textures). A manifest (JSON) lists each building's
size, triangles and its source and licence, for TmCityAssets and the credits.

usage (Blender 4.x, scripts in the file not run):
  blender -b -Y SOURCE.blend --python stadium/tools/assets/blend_to_glb.py -- \
      --out stadium/assets/city --prefix sky --licence "CC0 1.0, Blend Swap #81908" \
      [--scale 1.0] [--min-height 20] [--images] [--skip leaf,trunk,tree] [--scene NAME] [--unique]
      [--max-tris 60000] [--realize] [--pad 0.5] [--max-image 512]
--realize makes collection instances real objects (scenes that place one model with empties);
--pad: how close (m) two objects' footprints may come and still be one building.
Each building is joined into one mesh (one draw per material) and, over --max-tris, decimated
(edges collapsed) to that budget.
--unique keeps one of each design (scenes that repeat their buildings in rows): the same triangle
count and size (to the metre) is a copy.
--by-collection buld,bulid: one building per collection whose name starts so (scenes of buildings
that touch, a street of terraced houses), not footprints that touch.
--image-format JPEG [--image-quality 85]: the textures as JPEG (--images; default: as they are).
--drop-image coffee: objects whose materials use an image whose name holds that are left out (a
stock image the scene's licence doesn't cover).
--own-materials: the manifest says the set keeps its own materials in the game (with --images:
TmCityAssets doesn't dress it in ours).
"""
import bpy
import json
import os
import sys

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def opt(name, default=None, flag=False):
    if flag:
        return ("--" + name) in argv
    if ("--" + name) in argv:
        return argv[argv.index("--" + name) + 1]
    return default


OUT = opt("out")
PREFIX = opt("prefix", "bld")
SCALE = float(opt("scale", "1.0"))
MIN_H = float(opt("min-height", "20"))
SKIP = [s for s in opt("skip", "leaf,trunk,tree,foglie,albero,person,car,auto").split(",") if s]
LICENCE = opt("licence", "")
SOURCE = os.path.basename(bpy.data.filepath)
if opt("scene"):
    bpy.context.window.scene = bpy.data.scenes[opt("scene")]
scene = bpy.context.scene
os.makedirs(OUT, exist_ok=True)


def mesh_name_hit(o):
    names = [o.name.lower()] + [(s.material.name.lower() if s.material else "") for s in getattr(o, "material_slots", [])]
    return any(k in n for k in SKIP for n in names)


# collection instances (one model placed by empties) made real objects where they stand; the
# originals and anything else outside the view layer (hidden variants, excluded collections) out
if opt("realize", flag=True):
    bpy.ops.object.select_all(action="DESELECT")
    for o in scene.objects:
        if o.instance_type == "COLLECTION" and o.instance_collection and o.name in bpy.context.view_layer.objects:
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
    if bpy.context.selected_objects:
        bpy.ops.object.duplicates_make_real(use_base_parent=False, use_hierarchy=False)
for o in list(scene.objects):
    if o.name not in bpy.context.view_layer.objects:
        bpy.data.objects.remove(o, do_unlink=True)

# objects whose materials use an image left out (--drop-image)
DROP = [s.lower() for s in opt("drop-image", "").split(",") if s]
def uses_dropped(o):
    for slot in getattr(o, "material_slots", []):
        m = slot.material
        if m and m.use_nodes:
            for nd in m.node_tree.nodes:
                if nd.type == "TEX_IMAGE" and nd.image and any(k in nd.image.name.lower() for k in DROP):
                    return True
    return False
if DROP:
    for o in list(scene.objects):
        if o.type == "MESH" and uses_dropped(o):
            print("DROPPED", o.name)
            bpy.data.objects.remove(o, do_unlink=True)
# each object's collection (--by-collection), before anything is unparented
BYC = [s.lower() for s in opt("by-collection", "").split(",") if s]
coll_of = {}
if BYC:
    def walk(c, top):
        for o in c.objects:
            coll_of.setdefault(o.name, top)
        for ch in c.children:
            walk(ch, top)
    for c in bpy.data.collections:
        if any(c.name.lower().startswith(k) for k in BYC):
            walk(c, c.name)

# what isn't a building: cameras, lights, volumes, ground planes, trees and people
for o in list(scene.objects):
    flat = o.type == "MESH" and o.dimensions.z < 0.05 * SCALE ** 0 and max(o.dimensions.x, o.dimensions.y) > 30.0 / SCALE
    if o.type in ("CAMERA", "LIGHT", "LIGHT_PROBE", "SPEAKER", "EMPTY") and not o.children:
        bpy.data.objects.remove(o, do_unlink=True)
    elif o.type in ("CAMERA", "LIGHT", "LIGHT_PROBE", "SPEAKER") or "volume" in o.name.lower() or "fog" in o.name.lower() or flat \
            or (o.type == "MESH" and mesh_name_hit(o)):
        bpy.data.objects.remove(o, do_unlink=True)
# meshes only, unparented in place, hidden ones shown
bpy.ops.object.select_all(action="DESELECT")
for o in scene.objects:
    o.hide_set(False)
    o.hide_viewport = False
    o.hide_render = False
    o.select_set(o.type in ("CURVE", "FONT", "SURFACE", "META"))
    if o.select_get():
        bpy.context.view_layer.objects.active = o
if bpy.context.selected_objects:
    bpy.ops.object.convert(target="MESH")
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
for o in list(scene.objects):
    if o.type != "MESH" or len(o.data.polygons) == 0:
        bpy.data.objects.remove(o, do_unlink=True)

# world bounds of each object (Blender: z up)
def bounds(o):
    cs = [o.matrix_world @ v.co for v in o.data.vertices]
    return [min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs), max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs)]

objs = list(scene.objects)
bb = {o.name: bounds(o) for o in objs}
# ground-like slabs (a plaza, a podium deck wider than any tower) don't join buildings together
def slab(b):
    return (b[5] - b[2]) < 1.0 / SCALE and max(b[3] - b[0], b[4] - b[1]) > 40.0 / SCALE

parent = {o.name: o.name for o in objs}
def find(a):
    while parent[a] != a:
        parent[a] = parent[parent[a]]
        a = parent[a]
    return a

pad = float(opt("pad", "0.5")) / SCALE
names = [o.name for o in objs if not slab(bb[o.name])]
for i, a in enumerate(names):
    A = bb[a]
    for b in names[i + 1:]:
        B = bb[b]
        if A[0] - pad <= B[3] and B[0] - pad <= A[3] and A[1] - pad <= B[4] and B[1] - pad <= A[4]:
            parent[find(a)] = find(b)
groups = {}
for n in names:
    groups.setdefault(find(n), []).append(n)
if BYC:
    groups = {}
    for o in objs:
        if o.name in coll_of:
            groups.setdefault(coll_of[o.name], []).append(o.name)

# images over --max-image px scaled down (props don't need 2048 px textures)
mi_px = int(opt("max-image", "0"))
if mi_px > 0:
    for im in bpy.data.images:
        if im.size[0] > mi_px or im.size[1] > mi_px:
            f = mi_px / max(im.size[0], im.size[1])
            im.scale(max(1, int(im.size[0] * f)), max(1, int(im.size[1] * f)))
            if im.packed_file:
                im.pack()

manifest = []
k = 0
seen = set()
for members in sorted(groups.values(), key=lambda m: -max(bb[n][5] for n in m)):
    lo = [min(bb[n][i] for n in members) for i in range(3)]
    hi = [max(bb[n][i + 3] for n in members) for i in range(3)]
    if (hi[2] - lo[2]) * SCALE < MIN_H:
        continue
    if opt("unique", flag=True):
        sig = (sum(len(bpy.data.objects[n].data.polygons) for n in members),
            tuple(sorted(round((hi[i] - lo[i]) * SCALE) for i in range(2))) + (round((hi[2] - lo[2]) * SCALE),))
        if sig in seen:
            continue
        seen.add(sig)
    k += 1
    name = "%s_%02d" % (PREFIX, k)
    cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
    # a copy of the building, joined into one mesh at the origin, in metres (the scene stays as it is)
    bpy.ops.object.select_all(action="DESELECT")
    copies = []
    for n in members:
        src = bpy.data.objects[n]
        c = src.copy()
        c.data = src.data.copy()
        scene.collection.objects.link(c)
        copies.append(c)
    bpy.context.view_layer.objects.active = copies[0]
    for c in copies:
        c.select_set(True)
    if len(copies) > 1:
        bpy.ops.object.join()
    b = bpy.context.view_layer.objects.active
    for m in list(b.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    b.location.x -= cx
    b.location.y -= cy
    b.location.z -= lo[2]
    b.location *= SCALE
    b.scale *= SCALE
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    tris = sum(len(p.vertices) - 2 for p in b.data.polygons)
    budget = int(opt("max-tris", "60000"))
    if tris > budget:
        d = b.modifiers.new("budget", "DECIMATE")
        d.ratio = budget / tris
        bpy.ops.object.modifier_apply(modifier="budget")
        tris = sum(len(p.vertices) - 2 for p in b.data.polygons)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
        export_yup=True, export_cameras=False, export_lights=False,
        export_image_format=(opt("image-format", "AUTO") if opt("images", flag=True) else "NONE"),
        export_image_quality=int(opt("image-quality", "85")))
    bpy.data.objects.remove(b, do_unlink=True)
    size = [(hi[0] - lo[0]) * SCALE, (hi[2] - lo[2]) * SCALE, (hi[1] - lo[1]) * SCALE]   # Godot x, y (up), z
    manifest.append({"name": name, "size": [round(v, 2) for v in size], "triangles": tris, "parts": len(members),
        "source": SOURCE, "licence": LICENCE})
    print("BUILDING %s %.0f x %.0f x %.0f m, %d triangles, %d parts" % (name, size[0], size[1], size[2], tris, len(members)))

mpath = os.path.join(OUT, PREFIX + ".json")
json.dump({"source": SOURCE, "licence": LICENCE, "scale": SCALE, "own_materials": opt("own-materials", flag=True),
    "buildings": manifest}, open(mpath, "w"), indent=1)
print("MANIFEST", mpath, len(manifest))
