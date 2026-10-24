"""One member of the story's cast (PLAN M20-9), built headless in Blender by MPFB 2 from a spec in
tools/cast/specs/<id>.json, exported as glTF with its textures beside it and a sidecar <id>.cast.json
(each material's role and tint, the body's measures) for Godot's import (assets/cast/cast_import.gd).

    source $CAST_CACHE/env.sh      # tools/cast/setup.sh
    "$BLENDER" -b -P stadium/tools/cast/blender/gen_char.py -- <spec.json> <out dir>

The order matters (found by the survey, 24 Oct): solve the height slider for the spec's metres; build;
refit the clothes; bake the body's shape into the mesh (it deletes every shape key); only then load
the face shapes (ARKit face units, Meta visemes) and interpolate them onto eyes, brows, lashes, teeth
and tongue; prune them to the ones the cutscenes drive; bake the modifiers (shape keys kept); rename
the rig's Root / head to the animation library's root / Head. Done the other way round, the exporter
writes the neutral body with the eyes fitted to the shaped one (the eyes end on the forehead).
"""
import bpy
import importlib
import json
import math
import os
import sys
import time

argv = sys.argv[sys.argv.index("--") + 1:]
SPEC = json.load(open(argv[0]))
OUT = argv[1]
CID = SPEC["id"]
os.makedirs(OUT, exist_ok=True)

importlib.import_module("bl_ext.user_default.mpfb")
from bl_ext.user_default.mpfb.services import HumanService, ExportService, ObjectService, TargetService  # noqa: E402
from bl_ext.user_default.mpfb.services.faceservice import FaceService  # noqa: E402

T0 = time.time()
ROLES = {"Basemesh": "skin", "Eyes": "eye", "Eyebrows": "brow", "Eyelashes": "lash", "Teeth": "teeth",
         "Tongue": "tongue", "Hair": "hair", "Clothes": "cloth", "Proxymeshes": "skin"}
# the face shapes the cutscenes drive (story_face.gd): blinks, gaze, the jaw, a smile, a frown, the
# visemes a line's text maps to; the rest of the 67 are left out (each costs a copy of the face)
FACE_DEFAULT = ["eyeBlinkLeft", "eyeBlinkRight", "eyeLookUpLeft", "eyeLookUpRight", "eyeLookDownLeft",
                "eyeLookDownRight", "eyeLookInLeft", "eyeLookInRight", "eyeLookOutLeft", "eyeLookOutRight",
                "eyeSquintLeft", "eyeSquintRight", "browInnerUp", "browDownLeft", "browDownRight", "jawOpen",
                "mouthClose", "mouthSmileLeft", "mouthSmileRight", "mouthFrownLeft", "mouthFrownRight",
                "viseme_aa", "viseme_E", "viseme_I", "viseme_O", "viseme_U", "viseme_PP", "viseme_FF",
                "viseme_TH", "viseme_DD", "viseme_kk", "viseme_CH", "viseme_SS", "viseme_nn", "viseme_RR"]


def log(*a):
    print("CAST", CID, *a, flush=True)


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.armatures):
        for b in list(coll):
            if b.users == 0:
                coll.remove(b)


def targets():
    """The spec's detail targets, a name with no file of its own standing for both sides' (the face's
    detail targets come as l-... and r-...); an unknown name fails the build."""
    out = []
    for t in SPEC.get("targets", []):
        name = t["target"]
        if TargetService.target_full_path(name):
            out.append({"target": name, "value": float(t["value"])})
        elif TargetService.target_full_path("l-" + name) and TargetService.target_full_path("r-" + name):
            out += [{"target": side + name, "value": float(t["value"])} for side in ("l-", "r-")]
        else:
            raise ValueError("no target %s" % name)
    return out


def info_dict(phenotype, parts=True):
    info = HumanService._create_default_human_info_dict()
    info["name"] = CID
    ph = dict(phenotype)
    race = ph.pop("race", None)
    info["phenotype"].update(ph)
    if race:
        info["phenotype"]["race"] = race
    info["rig"] = "game_engine"
    info["targets"] = targets()
    if parts:
        for k in ("eyes", "eyebrows", "eyelashes", "teeth", "tongue", "hair", "proxy"):
            if SPEC.get(k):
                info[k] = SPEC[k]
        info["clothes"] = list(SPEC.get("clothes", []))
        info["skin_mhmat"] = SPEC.get("skin", "")
        info["skin_material_type"] = "GAMEENGINE"
        info["eyes_material_type"] = "GAMEENGINE"
        info["clothes_material_type"] = "GAMEENGINE"
    return info


def build(phenotype, parts=True):
    clear()
    settings = HumanService.get_default_deserialization_settings()
    settings["subdiv_levels"] = 0
    return HumanService.deserialize_from_dict(info_dict(phenotype, parts), settings)


def body_top(basemesh):
    """The top of the head (no hair), metres, after the shape is baked."""
    return max((basemesh.matrix_world @ v.co).z for v in basemesh.data.vertices)


def solve_height(want):
    """The phenotype's height slider for a body `want` metres tall (the slider is steep and not
    linear: 0..1 spans 1.24..2.29 m for women and 1.37..2.43 m for men), by bisection on bare bodies."""
    lo, hi, mid, top = 0.0, 1.0, 0.5, 0.0
    for _ in range(9):
        mid = (lo + hi) * 0.5
        ph = dict(SPEC["phenotype"], height=mid)
        bm = build(ph, parts=False)
        TargetService.bake_targets(bm)
        top = body_top(bm)
        if top < want:
            lo = mid
        else:
            hi = mid
    log("height slider %.4f -> %.3f m (want %.3f)" % (mid, top, want))
    return mid


# 1. the body: its height solved, then built with everything it wears
phenotype = dict(SPEC["phenotype"])
if "height_m" in SPEC:
    phenotype["height"] = solve_height(float(SPEC["height_m"]))
basemesh = build(phenotype)
bpy.context.view_layer.update()
if SPEC.get("refit", True):
    HumanService.refit(basemesh)
rig = basemesh.parent
TargetService.bake_targets(basemesh)
HEIGHT = body_top(basemesh)               # before the masks take the scalp under the hair away

# 2. the face's shapes, after the bake, pruned to the ones we drive
keep = set(SPEC.get("face_shapes", FACE_DEFAULT))
if keep:
    FaceService.load_targets(basemesh, load_microsoft_visemes=False, load_meta_visemes=True, load_arkit_faceunits=True)
    FaceService.interpolate_targets(basemesh)
# and each part keeps only what moves it: hair and clothes none, the brows their own and the lids',
# the lashes the lids and the gaze, the eyes the gaze, the teeth and tongue the jaw and the visemes
PART_SHAPES = {"Eyebrows": ("brow", "eyeBlink", "eyeSquint"), "Eyelashes": ("eyeBlink", "eyeSquint", "eyeLook"),
               "Eyes": ("eyeLook",), "Teeth": ("jaw", "mouthClose", "viseme"), "Tongue": ("jaw", "mouthClose", "viseme")}
for child in rig.children:
    keys = child.data.shape_keys if child.type == 'MESH' else None
    if keys is None:
        continue
    otype = ObjectService.get_object_type(child)
    allowed = None if otype == "Basemesh" else PART_SHAPES.get(otype, ())
    for kb in list(keys.key_blocks):
        if kb.name == keys.reference_key.name:
            continue
        if kb.name not in keep or (allowed is not None and not kb.name.startswith(allowed)):
            child.shape_key_remove(kb)
    if len(child.data.shape_keys.key_blocks) <= 1:
        child.shape_key_clear()

# 3. modifiers baked (shape keys kept), helpers gone, the rig's names as the animation library's
ExportService.bake_modifiers_remove_helpers(basemesh, bake_masks=True, bake_subdiv=False, remove_helpers=True, also_proxy=True)
bpy.context.view_layer.update()
for old, new in (("Root", "root"), ("head", "Head")):
    if old in rig.data.bones:
        rig.data.bones[old].name = new
for o in list(bpy.data.objects):          # strays (bone shapes, empties) never export
    if o != rig and o.parent != rig:
        bpy.data.objects.remove(o, do_unlink=True)

# 4. materials named by role, textures capped; the roles and tints go to the sidecar
tints = SPEC.get("tint", {})
tex_max = int(SPEC.get("texture_max", 2048))
materials = {}
for child in sorted(rig.children, key=lambda c: c.name):
    if child.type != 'MESH':
        continue
    otype = ObjectService.get_object_type(child)
    role = ROLES.get(otype, "cloth")
    # MPFB names an asset's object "<human>.<asset>" and its material after the human: name both
    # after the asset, so two garments never share a material's name
    asset = (child.name.split(".", 1)[1] if "." in child.name else child.name).lower().replace(" ", "_")
    if role == "skin":
        asset = "body"
    for k, slot in enumerate(child.material_slots):
        m = slot.material
        if m is None or m.name in materials:
            continue
        name = "%s__%s%s" % (role, asset, "" if k == 0 else "_%d" % k)
        m.name = name
        materials[m.name] = name
        for node in (m.node_tree.nodes if m.use_nodes else []):
            img = getattr(node, "image", None)
            if img is not None and max(img.size) > tex_max:
                f = tex_max / max(img.size)
                img.scale(max(1, int(img.size[0] * f)), max(1, int(img.size[1] * f)))
    child.name = "%s__%s" % (role, asset.lower())

meta = {"id": CID, "name": SPEC.get("name", CID), "materials": {}, "blender": bpy.app.version_string,
        "spec": os.path.basename(argv[0])}
for name in sorted(materials):
    role, base = name.split("__", 1)
    tint = "#ffffff"
    for key, value in tints.items():
        if key == role or key in base:
            tint = value
    meta["materials"][name] = {"role": role, "tint": tint}

# 5. measures: standing height, the pelvis, the eyes (a seat and a camera need them)
def bone_z(name):
    b = rig.data.bones.get(name)
    return round((rig.matrix_world @ b.head_local).z, 4) if b else None


meta["height"] = round(HEIGHT, 4)
meta["pelvis"] = bone_z("pelvis")
meta["head"] = bone_z("Head")
eyes = [c for c in rig.children if c.name.startswith("eye__")]
if eyes:
    zs = [(eyes[0].matrix_world @ v.co).z for v in eyes[0].data.vertices]
    meta["eyes"] = round(sum(zs) / len(zs), 4)
tris = 0
for c in rig.children:
    if c.type == 'MESH':
        c.data.calc_loop_triangles()
        tris += len(c.data.loop_triangles)
meta["triangles"] = tris
meta["bones"] = len(rig.data.bones)
meta["face_shapes"] = sorted(keep & set(basemesh.data.shape_keys.key_blocks.keys())) if basemesh.data.shape_keys else []

# 6. export: glTF with its textures in tex/ (post.py converts and shares them)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for c in rig.children:
    c.select_set(True)
bpy.context.view_layer.objects.active = rig
rig.name = CID
gltf = os.path.join(OUT, CID + ".gltf")
bpy.ops.export_scene.gltf(filepath=gltf, export_format='GLTF_SEPARATE', export_texture_dir="tex", use_selection=True,
                          export_animations=False, export_skins=True, export_all_influences=True, export_morph=True,
                          export_morph_normal=False, export_try_sparse_sk=True, export_yup=True,
                          export_image_format='AUTO', export_extras=False, export_apply=False)
json.dump(meta, open(os.path.join(OUT, CID + ".cast.json"), "w"), indent=1, sort_keys=True)
log("built: %.3f m, %d tris, %d bones, %d face shapes, %d materials in %.1f s" % (
    meta["height"], tris, meta["bones"], len(meta["face_shapes"]), len(materials), time.time() - T0))
