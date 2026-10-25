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
from bl_ext.user_default.mpfb.services import AssetService, HumanService, ExportService, ObjectService, TargetService  # noqa: E402
from bl_ext.user_default.mpfb.services.faceservice import FaceService  # noqa: E402
from bl_ext.user_default.mpfb.entities.objectproperties import GeneralObjectProperties  # noqa: E402

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


def alternative_materials():
    """The spec's "materials" ({part or garment: its .mhmat, relative to the part's folder, e.g.
    "eyes": "materials/brownlight.mhmat"}) as MPFB wants them: keyed by the asset's uuid."""
    out = {}
    for key, mhmat in SPEC.get("materials", {}).items():
        if key in ("eyes", "eyebrows", "eyelashes", "teeth", "tongue", "hair"):
            subdir, ref = key, SPEC[key]
        else:
            subdir, ref = "clothes", next(c for c in SPEC.get("clothes", []) if c.split("/")[0] == key)
        path = AssetService.find_asset_absolute_path(ref, asset_subdir=subdir)
        uuid = next((ln.split()[1] for ln in open(path, encoding="utf-8", errors="replace") if ln.startswith("uuid ")), None)
        if uuid is None or AssetService.find_asset_absolute_path(mhmat, asset_subdir=subdir) is None:
            raise ValueError("no material %s for %s" % (mhmat, key))
        out[uuid] = mhmat
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
        info["alternative_materials"] = alternative_materials()
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


def vest(basemesh, rig, spec):
    """A garment no pack has (Gus's hi-vis vest): the body's torso -- its vertices weighted to the
    spine, clavicles and pelvis above the belt, not to the arms or the neck, so it has armholes and a
    neckline -- pushed out along its normals until it clears the outermost garment (raycasts, the
    distances smoothed so it hangs, not clings), given thickness, its weights the body's, and a
    texture painted by height (spec "colour", the reflective "bands" as [from, to] fractions of
    its height). Its role is "hivis" (cast_import.gd: a faint fluorescent glow)."""
    import bmesh
    from mathutils.bvhtree import BVHTree
    deps = bpy.context.evaluated_depsgraph_get()
    trees = []
    for g in rig.children:
        if g.type == 'MESH' and ObjectService.get_object_type(g) == "Clothes" and not any(
                k in g.name.lower() for k in ("boot", "shoe", "sneaker")):
            b = bmesh.new()
            b.from_object(g, deps)
            b.transform(g.matrix_world)
            trees.append(BVHTree.FromBMesh(b))
            b.free()
    names = {g.index: g.name for g in basemesh.vertex_groups}
    torso, arms, neck = ("spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r", "pelvis"), \
        ("upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"), ("neck_01", "head")
    hem = (rig.matrix_world @ rig.data.bones["pelvis"].head_local).z + float(spec.get("hem", 0.05))
    mw = basemesh.matrix_world
    keep = set()
    for v in basemesh.data.vertices:
        w = {names[g.group]: g.weight for g in v.groups if g.group in names}
        if "body" not in w or (mw @ v.co).z < hem:
            continue
        if sum(w.get(n, 0.0) for n in torso) >= 0.6 and sum(w.get(n, 0.0) for n in arms) < 0.2 \
                and sum(w.get(n, 0.0) for n in neck) < 0.25:
            keep.add(v.index)
    obj = basemesh.copy()
    obj.data = basemesh.data.copy()
    obj.name = "%s.hivis_vest" % CID
    bpy.context.collection.objects.link(obj)
    for m in list(obj.modifiers):
        if m.type != 'ARMATURE':
            obj.modifiers.remove(m)
    GeneralObjectProperties.set_value("object_type", "Clothes", entity_reference=obj)
    obj["cast_role"] = "hivis"
    b = bmesh.new()
    b.from_mesh(obj.data)
    b.verts.ensure_lookup_table()
    bmesh.ops.delete(b, geom=[f for f in b.faces if not all(v.index in keep for v in f.verts)], context='FACES')
    bmesh.ops.delete(b, geom=[v for v in b.verts if not v.link_faces], context='VERTS')
    # the outline (armholes, neckline, hem) follows whole quads: relax it along itself
    edge = {v: [e.other_vert(v) for e in v.link_edges if e.is_boundary] for v in b.verts if v.is_boundary}
    for _ in range(int(spec.get("relax", 6))):
        moved = {v: v.co * 0.5 + (ns[0].co + ns[1].co) * 0.25 for v, ns in edge.items() if len(ns) == 2}
        for v, co in moved.items():
            v.co = co
    b.normal_update()
    # how far out each vertex must go: past the farthest garment along its normal, then smoothed
    out = {}
    for v in b.verts:
        p, n = mw @ v.co, (mw.to_3x3() @ v.normal).normalized()
        far = 0.0
        for t in trees:
            # through every layer (one garment can be a shirt under a jacket): a ray stops at the first
            # -- but only the stack of layers on the body (pockets too): a gap over 4.5 cm means the ray left
            # the clothes and found something else (a sleeve, from the torso's sides)
            start = at = p - n * 0.002
            for _ in range(8):
                hit = t.ray_cast(at, n, 0.1 - (at - start).length)
                if hit[0] is None or (hit[0] - at).length > 0.045 and far > 0.0:
                    break
                far = max(far, (hit[0] - start).length)
                at = hit[0] + n * 0.0005
        out[v] = far + 0.007 if far > 0.0 else 0.010
    need = dict(out)                       # never inside a garment: smoothing only lets it hang further out
    for _ in range(6):
        out = {v: max(need[v], 0.5 * (out[v] + sum(out[e.other_vert(v)] for e in v.link_edges) / max(1, len(v.link_edges))))
               for v in b.verts}
    for v in b.verts:
        v.co += v.normal * out[v]
    bmesh.ops.solidify(b, geom=list(b.faces), thickness=-0.004)
    # solidify adds its rim faces in an order that changes from run to run: sort them (deterministic)
    b.verts.index_update()
    rank = {f: n for n, f in enumerate(sorted(b.faces, key=lambda f: sorted(v.index for v in f.verts)))}
    b.faces.sort(key=lambda f: rank[f])
    b.faces.index_update()
    # painted by height: one column of texels; u is the same everywhere
    zs = [(mw @ v.co).z for v in b.verts]
    z0, z1 = min(zs), max(zs)
    uv = b.loops.layers.uv.active or b.loops.layers.uv.new()
    for f in b.faces:
        for lp in f.loops:
            lp[uv].uv = (0.5, ((mw @ lp.vert.co).z - z0) / (z1 - z0))
    b.to_mesh(obj.data)
    b.free()
    while len(obj.data.uv_layers) > 1:
        obj.data.uv_layers.remove(obj.data.uv_layers[0] if obj.data.uv_layers[0] != obj.data.uv_layers.active else obj.data.uv_layers[1])
    if obj.data.shape_keys:
        obj.shape_key_clear()
    base = [int(spec.get("colour", "#cbff1f").lstrip("#")[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    img = bpy.data.images.new("hivis_vest", 4, 256)
    px = []
    for row in range(256):
        f = (row + 0.5) / 256.0
        band = any(a <= f <= c for a, c in spec.get("bands", [[0.16, 0.24], [0.5, 0.58]]))
        px += ([0.72, 0.74, 0.76] if band else base) + [1.0]
    img.pixels = [c for row in range(256) for c in px[row * 4:row * 4 + 4] * 4]
    mat = bpy.data.materials.new("hivis_vest")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.parent = rig
    obj.matrix_parent_inverse = basemesh.matrix_parent_inverse.copy()
    log("vest: %d faces, %.3f-%.3f m" % (len(obj.data.polygons), z0, z1))
    return obj


def hair_veil(basemesh, rig, spec):
    """The hair let down over the face (the passenger in the mirror): the hair turned about the
    skull's vertical axis (spec "turn", degrees: 180 brings a long back down over the face and the
    chest), whatever then lies inside the body or on it pushed out to "clear" m off the skin (the
    distances smoothed along the hair, never less than measured, so the strands hang rather than
    kink), and weighted again from the nearest body vertex: over the face it follows the head, over
    the chest the chest."""
    import bmesh
    from mathutils import Matrix, Vector
    from mathutils.bvhtree import BVHTree
    from mathutils.kdtree import KDTree
    hair = next((g for g in rig.children if g.type == 'MESH' and ObjectService.get_object_type(g) == "Hair"), None)
    body = basemesh.vertex_groups.get("body")
    if hair is None or body is None:
        return
    mw = basemesh.matrix_world
    # the body's skin only (the basemesh also holds MakeHuman's helper meshes)
    b = bmesh.new()
    b.from_mesh(basemesh.data)
    dl = b.verts.layers.deform.active
    b.transform(mw)
    bmesh.ops.delete(b, geom=[f for f in b.faces if not all(body.index in v[dl] for v in f.verts)], context='FACES')
    bmesh.ops.delete(b, geom=[v for v in b.verts if not v.link_faces], context='VERTS')
    b.normal_update()
    skin = BVHTree.FromBMesh(b)
    b.free()
    # the turn, about the vertical through the middle of the hair's cap (what lies above the head bone)
    hw = hair.matrix_world
    top = (rig.matrix_world @ rig.data.bones["head"].head_local).z + 0.08
    cap = [hw @ v.co for v in hair.data.vertices if (hw @ v.co).z > top] or [hw @ v.co for v in hair.data.vertices]
    pivot = Vector((sum(p.x for p in cap) / len(cap), sum(p.y for p in cap) / len(cap), 0.0))
    turn = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(float(spec.get("turn", 180.0))), 4, 'Z') \
        @ Matrix.Translation(-pivot)
    hb = bmesh.new()
    hb.from_mesh(hair.data)
    hb.transform(turn @ hw)
    clear = float(spec.get("clear", 0.012))
    need = {}
    for v in hb.verts:
        loc, n, _i, dist = skin.find_nearest(v.co, 0.15)
        if loc is None:
            need[v] = 0.0
            continue
        need[v] = max(0.0, clear - (v.co - loc).dot(n))
    out = dict(need)
    for _ in range(int(spec.get("smooth", 4))):
        out = {v: max(need[v], 0.5 * (out[v] + sum(out[e.other_vert(v)] for e in v.link_edges) / max(1, len(v.link_edges))))
               for v in hb.verts}
    moved = 0
    for v in hb.verts:
        if out[v] > 0.0:
            loc, n, _i, _d = skin.find_nearest(v.co, 0.15)
            if loc is not None:
                v.co += n * out[v]
                moved += 1
    hb.transform(hw.inverted())
    hb.to_mesh(hair.data)
    hb.free()
    hair.data.update()
    # weighted again from the nearest body vertex (its bones only)
    bones = set(rig.data.bones.keys())
    names = {g.index: g.name for g in basemesh.vertex_groups}
    verts = [v for v in basemesh.data.vertices if any(g.group == body.index for g in v.groups)]
    kd = KDTree(len(verts))
    for k, v in enumerate(verts):
        kd.insert(mw @ v.co, k)
    kd.balance()
    for g in list(hair.vertex_groups):
        if g.name in bones:
            hair.vertex_groups.remove(g)
    groups = {}
    for hv in hair.data.vertices:
        _co, k, _d = kd.find(hw @ hv.co)
        for g in verts[k].groups:
            name = names.get(g.group)
            if name in bones and g.weight > 0.0:
                if name not in groups:
                    groups[name] = hair.vertex_groups.new(name=name)
                groups[name].add([hv.index], g.weight, 'REPLACE')
    log("hair veil: turned %.0f degrees, %d of %d vertices pushed off the skin, weights from %d bones" % (
        float(spec.get("turn", 180.0)), moved, len(hair.data.vertices), len(groups)))


def cover_mask(basemesh, rig, reach):
    """Hides the body wherever a garment covers it closely (within `reach` m along the body's
    normal): some garments hide nothing (the hoodie, cortu's cargo pants: no delete_verts), and a
    hidden body costs triangles and pokes through when the clothes bend. Each opening keeps a
    ring of body (only vertices whose neighbours are all covered are hidden), so no cuff or collar
    shows a gap. A Mask modifier, baked with MPFB's own."""
    import bmesh
    from mathutils.bvhtree import BVHTree
    deps = bpy.context.evaluated_depsgraph_get()
    trees = []
    for g in rig.children:
        if g.type == 'MESH' and ObjectService.get_object_type(g) == "Clothes":
            b = bmesh.new()
            b.from_object(g, deps)
            b.transform(g.matrix_world)
            trees.append(BVHTree.FromBMesh(b))
            b.free()
    body = basemesh.vertex_groups.get("body")
    if not trees or body is None:
        return 0
    mw, nm = basemesh.matrix_world, basemesh.matrix_world.to_3x3()
    covered = set()
    for v in basemesh.data.vertices:
        if not any(g.group == body.index for g in v.groups):
            continue
        p, n = mw @ v.co, (nm @ v.normal).normalized()
        if any(t.ray_cast(p, n, reach)[0] is not None for t in trees):
            covered.add(v.index)
    near = {i: set() for i in covered}
    for e in basemesh.data.edges:
        a, b = e.vertices
        if a in near:
            near[a].add(b)
        if b in near:
            near[b].add(a)
    hide = sorted(i for i in covered if near[i] <= covered)
    group = basemesh.vertex_groups.new(name="cast_covered")
    group.add(hide, 1.0, 'REPLACE')
    m = basemesh.modifiers.new("cast covered", 'MASK')
    m.vertex_group = group.name
    m.invert_vertex_group = True
    log("cover mask: %d body vertices hidden" % len(hide))
    return len(hide)


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
if SPEC.get("vest"):
    vest(basemesh, rig, SPEC["vest"])
if SPEC.get("hair_veil"):
    hair_veil(basemesh, rig, SPEC["hair_veil"])
if SPEC.get("cover_mask", True):
    cover_mask(basemesh, rig, float(SPEC.get("cover_reach", 0.04)))

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
# a crowd seen from afar wears no normal maps (they are the biggest files after the hair)
normal_maps = bool(SPEC.get("normal_maps", SPEC.get("tier", "lead") != "crowd"))
materials = {}
for child in sorted(rig.children, key=lambda c: c.name):
    if child.type != 'MESH':
        continue
    otype = ObjectService.get_object_type(child)
    role = child.get("cast_role", ROLES.get(otype, "cloth"))
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
        if not normal_maps and m.use_nodes:
            for node in [n for n in m.node_tree.nodes if n.type == 'NORMAL_MAP']:
                for link in node.inputs["Color"].links:
                    m.node_tree.nodes.remove(link.from_node)
                m.node_tree.nodes.remove(node)
        for node in (m.node_tree.nodes if m.use_nodes else []):
            img = getattr(node, "image", None)
            if img is not None and max(img.size) > tex_max:
                f = tex_max / max(img.size)
                img.scale(max(1, int(img.size[0] * f)), max(1, int(img.size[1] * f)))
    child.name = "%s__%s" % (role, asset.lower())

meta = {"id": CID, "name": SPEC.get("name", CID), "materials": {}, "blender": bpy.app.version_string,
        "spec": os.path.basename(argv[0]), "tier": SPEC.get("tier", "lead")}
# what it is made of (licences.py checks them and writes their credits; test_cast_models matches them)
PARTS = {"eyes": "eyes", "eyebrows": "eyebrows", "eyelashes": "eyelashes", "teeth": "teeth", "tongue": "tongue",
         "hair": "hair", "skin": "skins", "proxy": "proxymeshes"}
meta["assets"] = sorted(["%s/%s" % (kind, SPEC[k].split("/")[0]) for k, kind in PARTS.items() if SPEC.get(k)]
                        + ["clothes/" + c.split("/")[0] for c in SPEC.get("clothes", [])])
for name in sorted(materials):
    role, base = name.split("__", 1)
    tint = "#ffffff"
    for key, value in tints.items():
        if key == role or key in base:
            tint = value
    meta["materials"][name] = {"role": role, "tint": tint}
    if role in SPEC.get("desaturate", []) or base in SPEC.get("desaturate", []):   # exactly: "eye" is in "eyebrow011"
        meta["materials"][name]["desaturate"] = True       # post.py: its colour map in greys (grey hair)
    if any(base == a or base.startswith(a + "_") for a in SPEC.get("loose", [])):
        meta["materials"][name]["loose"] = True            # hangs free (a long coat): not what it sits on

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
