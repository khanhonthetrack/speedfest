"""A member of the stylised cast (PLAN M20-9; the owner, 24 Oct: "show me both side by side first"):
parts of Quaternius' Ultimate Modular Women / Men (CC0: low poly, flat colours; setup.sh fetches them
into $CAST_CACHE/stylised/<pack>/) put on one skeleton, each recoloured on its own, sized, given what
no pack has (Kit's long hair), and exported like gen_char.py's people (glTF + sidecar <id>.cast.json)
for post.py; Godot retargets the Quaternius rig onto its humanoid through bonemap_quaternius.tres.

    source $CAST_CACHE/env.sh
    "$BLENDER" -b -P stadium/tools/cast/blender/gen_stylised.py -- <spec.json> <out dir>

Spec (tools/cast/specs/<id>.json with "style": "stylised"): "pack" ("women" | "men"), "parts"
([{"file", "mesh", "colours": {material: "#rrggbb"}, "drop": [material], "drop_behind": m (loose pieces whose middle is
that far behind the chest bone: a backpack and its straps)}]: one Head, Body, Legs and
Feet; parts of one pack share a skeleton), "height_m", "width" (x and depth, on top of the height's
scale), "hair" ({"length": m, "colour", "spread": degrees}: a panel hanging from the head's own hair),
"credits" (lines for CREDITS.md).
The rig: Quaternius ties the feet to Root (for IK) and adds pole bones; the clips we play need the
feet under the shins, so they move there and the poles go.
"""
import bmesh
import bpy
import json
import math
import os
import sys
import time
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
SPEC = json.load(open(argv[0]))
OUT = argv[1]
CID = SPEC["id"]
SRC = os.path.join(os.environ["CAST_CACHE"], "stylised", SPEC["pack"])
os.makedirs(OUT, exist_ok=True)
T0 = time.time()


def log(*a):
    print("CAST", CID, *a, flush=True)


def linear(hexc):
    """An sRGB '#rrggbb' as linear RGBA (Blender's colour values; glTF's baseColorFactor)."""
    c = [int(hexc.lstrip("#")[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c] + [1.0]


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.actions, bpy.data.images):
        for b in list(coll):
            coll.remove(b)


def imported(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


# 1. the parts on one skeleton (the first part's), the rest of each file thrown away
clear()
rig = None
parts = []
for spec in SPEC["parts"]:
    objs = imported(os.path.join(SRC, spec["file"]))
    arm = next(o for o in objs if o.type == 'ARMATURE')
    mesh = next(o for o in objs if o.type == 'MESH' and o.name.split(".")[0] == spec["mesh"])
    if rig is None:
        rig = arm
    else:
        mw = mesh.matrix_world.copy()
        mesh.parent = rig
        mesh.matrix_world = mw
        for m in mesh.modifiers:
            if m.type == 'ARMATURE':
                m.object = rig
    for o in objs:
        if o is not rig and o is not mesh:
            bpy.data.objects.remove(o, do_unlink=True)
    parts.append((mesh, spec))
for a in list(bpy.data.actions):          # Quaternius' own clips: we play UAL's
    bpy.data.actions.remove(a)
if rig.animation_data:
    rig.animation_data_clear()

# 2. each part's materials its own (the packs share names: "Black", "Skin"), recoloured; surfaces
# dropped (the King's crown)
materials = {}
for mesh, spec in parts:
    drop = set(spec.get("drop", []))
    if drop:
        b = bmesh.new()
        b.from_mesh(mesh.data)
        gone = [f for f in b.faces if mesh.data.materials[f.material_index].name.split(".")[0] in drop]
        bmesh.ops.delete(b, geom=gone, context='FACES')
        bmesh.ops.delete(b, geom=[v for v in b.verts if not v.link_faces], context='VERTS')
        b.to_mesh(mesh.data)
        b.free()
    for k, slot in enumerate(mesh.material_slots):
        src = slot.material
        base = src.name.split(".")[0]
        m = src.copy()
        m.name = "flat__%s_%s" % (spec["mesh"].lower(), base.lower())
        colour = spec.get("colours", {}).get(base)
        if colour and m.use_nodes:
            bsdf = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if bsdf is not None:
                bsdf.inputs["Base Color"].default_value = linear(colour)
        mesh.material_slots[k].material = m
        materials[m.name] = {"role": "flat", "tint": "#ffffff"}
    mesh.name = "flat__%s" % spec["mesh"].lower()

# loose pieces behind the torso dropped ("drop_behind": the Adventurer's backpack, where Kit's hair hangs)
for mesh, spec in parts:
    if not spec.get("drop_behind"):
        continue
    chest_y = (rig.matrix_world @ rig.data.bones["Chest"].head_local).y
    b = bmesh.new()
    b.from_mesh(mesh.data)
    b.faces.ensure_lookup_table()
    seen, gone = set(), []
    for f in b.faces:
        if f.index in seen:
            continue
        island, stack = [], [f]
        seen.add(f.index)
        while stack:
            g = stack.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        ys = [(mesh.matrix_world @ v.co).y for g in island for v in g.verts]
        if sum(ys) / len(ys) > chest_y + float(spec["drop_behind"]):     # the back is +y (it faces -y)
            gone += island
    bmesh.ops.delete(b, geom=gone, context='FACES')
    bmesh.ops.delete(b, geom=[v for v in b.verts if not v.link_faces], context='VERTS')
    b.to_mesh(mesh.data)
    b.free()
    log("%s: %d faces behind the torso dropped" % (spec["mesh"], len(gone)))

# 3. the rig: feet under the shins, no pole bones
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
eb = rig.data.edit_bones
for side in ("L", "R"):
    foot, shin = eb.get("Foot." + side), eb.get("LowerLeg." + side)
    if foot is not None and shin is not None:
        foot.use_connect = False
        foot.parent = shin
    pole = eb.get("PT." + side)
    if pole is not None:
        eb.remove(pole)
bpy.ops.object.mode_set(mode='OBJECT')
for mesh, _ in parts:
    for side in ("L", "R"):
        g = mesh.vertex_groups.get("PT." + side)
        if g is not None:
            mesh.vertex_groups.remove(g)


def top_and_bottom():
    zs = [(m.matrix_world @ v.co).z for m, _ in parts for v in m.data.vertices]
    return max(zs), min(zs)


# 4. size: the spec's height (head top, hair included: no pack shows a bare scalp), wider for a
# bigger body; scale applied to the rig and the meshes
top, bottom = top_and_bottom()
s = float(SPEC.get("height_m", top)) / (top - bottom)
w = float(SPEC.get("width", 1.0))
rig.scale = (s * w, s * w, s)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for m, _ in parts:
    m.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.context.view_layer.update()
top, bottom = top_and_bottom()
log("height %.3f m (scale %.3f, width %.2f)" % (top - bottom, s, w))


def bone_pos(name):
    b = rig.data.bones.get(name)
    return rig.matrix_world @ b.head_local if b else None


# 5. long hair (Kit): a panel hanging from the lower edge of the head's own hair, behind the head,
# down past the neck, over the back; low poly, flat shaded like the rest; kept off the clothes by
# raycasts; weighted to the head at the top, the neck, then the chest
def hanging_hair(spec):
    head = next(m for m, sp in parts if sp["mesh"].endswith("_Head"))
    hair_slots = {i for i, s in enumerate(head.material_slots) if "hair" in s.material.name.lower()}
    vmat = {}
    for p in head.data.polygons:
        if p.material_index in hair_slots:
            for vi in p.vertices:
                vmat[vi] = True
    hair = [head.matrix_world @ head.data.vertices[i].co for i in vmat]
    c = bone_pos("Head")
    chest = bone_pos("Chest")
    body = []
    for m, sp in parts:
        if not sp["mesh"].endswith("_Head"):
            b = bmesh.new()
            b.from_mesh(m.data)
            b.transform(m.matrix_world)
            body.append(BVHTree.FromBMesh(b))
            b.free()
    length = float(spec.get("length", 0.4))
    spread = math.radians(float(spec.get("spread", 80)))
    cols, rows = 11, 6
    # the character faces -y (glTF +z): its back is +y
    grid = []
    for ci in range(cols):
        th = -spread + 2 * spread * ci / (cols - 1)
        d = Vector((math.sin(th), math.cos(th), 0.0))
        near = [h for h in hair if (Vector((h.x - c.x, h.y - c.y, 0)).normalized().dot(d) > math.cos(math.radians(14)))]
        if not near:
            near = hair
        z0 = min(h.z for h in near)
        lowest = sorted(near, key=lambda h: h.z)[:6]
        r0 = sum(Vector((h.x - c.x, h.y - c.y, 0)).length for h in lowest) / len(lowest)
        col = []
        for ri in range(rows + 1):
            z = z0 + 0.03 - (length + 0.03) * ri / rows
            r = r0 - 0.012
            if ri > 0:
                axis = Vector((c.x, chest.y if z < c.z - 0.1 else c.y, z))
                hits = [t.ray_cast(axis, d, 0.5) for t in body]
                far = max([(h[0] - axis).length for h in hits if h[0] is not None] or [0.0])
                r = max(r, far + 0.025)
            tip = 0.0 if ri < rows else (0.03 if ci % 2 else -0.02)   # a ragged end
            col.append(Vector((c.x, c.y if z > chest.z else chest.y, 0)) + d * r + Vector((0, 0, z + tip)))
        grid.append(col)
    me = bpy.data.meshes.new("hair_long")
    b = bmesh.new()
    verts = [[b.verts.new(p) for p in col] for col in grid]
    for ci in range(cols - 1):
        for ri in range(rows):
            b.faces.new((verts[ci][ri], verts[ci + 1][ri], verts[ci + 1][ri + 1], verts[ci][ri + 1]))
    b.to_mesh(me)
    b.free()
    obj = bpy.data.objects.new("flat__hair_long", me)
    bpy.context.collection.objects.link(obj)
    obj.parent = rig
    groups = {n: obj.vertex_groups.new(name=n) for n in ("Head", "Neck", "Chest")}
    weights = [{"Head": 1.0}, {"Head": 0.5, "Neck": 0.5}, {"Neck": 0.4, "Chest": 0.6}]
    for ci in range(cols):
        for ri in range(rows + 1):
            for n, wgt in (weights[ri] if ri < len(weights) else {"Chest": 1.0}).items():
                groups[n].add([ci * (rows + 1) + ri], wgt, 'REPLACE')
    mod = obj.modifiers.new("Armature", 'ARMATURE')
    mod.object = rig
    src = next(s.material for s in head.material_slots if "hair" in s.material.name.lower())
    m = src.copy()
    m.name = "flat__hair_long"
    bsdf = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if bsdf is not None and spec.get("colour"):
        bsdf.inputs["Base Color"].default_value = linear(spec["colour"])
    me.materials.append(m)
    materials[m.name] = {"role": "flat", "tint": "#ffffff"}
    log("long hair: %.2f m below the head's, %d faces" % (length, len(me.polygons)))
    return obj


if SPEC.get("hair"):
    parts.append((hanging_hair(SPEC["hair"]), {"mesh": "hair_long"}))

# 6. the sidecar and the export (as gen_char.py: the rig named after the character)
tris = 0
for m, _ in parts:
    m.data.calc_loop_triangles()
    tris += len(m.data.loop_triangles)
meta = {"id": CID, "name": SPEC.get("name", CID), "style": "stylised", "materials": materials,
        "blender": bpy.app.version_string, "spec": os.path.basename(argv[0]),
        "bonemap": "res://assets/cast/bonemap_quaternius.tres",
        "height": round(top - bottom, 4), "head": round(bone_pos("Head").z, 4), "pelvis": round(bone_pos("Body").z, 4),
        "triangles": tris, "bones": len(rig.data.bones), "face_shapes": [], "assets": [],
        "credits": SPEC.get("credits", [])}
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for m, _ in parts:
    m.select_set(True)
bpy.context.view_layer.objects.active = rig
rig.name = CID
gltf = os.path.join(OUT, CID + ".gltf")
bpy.ops.export_scene.gltf(filepath=gltf, export_format='GLTF_SEPARATE', export_texture_dir="tex", use_selection=True,
                          export_animations=False, export_skins=True, export_all_influences=True, export_morph=False,
                          export_yup=True, export_extras=False, export_apply=False)
json.dump(meta, open(os.path.join(OUT, CID + ".cast.json"), "w"), indent=1, sort_keys=True)
log("built: %.3f m, %d tris, %d bones, %d materials in %.1f s" % (meta["height"], tris, meta["bones"], len(materials),
                                                                  time.time() - T0))
