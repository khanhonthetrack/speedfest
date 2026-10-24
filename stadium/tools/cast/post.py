"""After gen_char.py (PLAN M20-9): a character's glTF and textures into the repo's cast folder.

    python3 -I post.py <gen_char out dir> <repo>/stadium/assets/cast [--max-normal 1024]
    python3 -I post.py --prune <repo>/stadium/assets/cast     # textures no glTF uses any more

- colour maps with no alpha worth keeping become JPEG (quality 88); maps whose alpha matters (hair,
  brows, lashes, or any map with see-through texels) stay PNG; normal maps stay PNG (JPEG's blocks
  show in the light), capped at --max-normal for everything but the skin;
- a material the sidecar marks "desaturate" (the spec's "desaturate": roles or assets) gets its
  colour map in greys, a little lighter, as <name>_grey (grey hair; the tint then colours it);
- every texture's .import is ours (VRAM compressed, mipmaps, normal maps flagged: texture_import);
- every texture goes to <cast>/tex/, named after its source and shared by the whole cast (the same
  eyes, teeth and boots are not stored twice; a different picture under a taken name gets a hash);
- the glTF, its .bin and the sidecar <id>.cast.json go to <cast>/<id>/, the glTF's image URIs
  rewritten to ../tex/; a new character gets its <id>.gltf.import (the retarget onto Godot's
  humanoid through bonemap.tres, cast_import.gd); an existing one keeps Godot's (and its uid).
Deterministic: the same input gives the same bytes (PIL's encoders, no timestamps).
"""
import hashlib
import io
import json
import os
import shutil
import sys

from PIL import Image, ImageFile

# some packs' PNGs carry an ancillary chunk with a bad checksum (elvs_50s_updo's iCCP): skip it
# (the picture is re-encoded without it anyway)
ImageFile.LOAD_TRUNCATED_IMAGES = True
ALPHA_ROLES = ("hair", "brow", "lash")


IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=true
meshes/generate_lods=false
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
import_script/path="res://assets/cast/cast_import.gd"
_subresources={
"nodes": {
"PATH:%(id)s/Skeleton3D": {
"retarget/bone_map": Resource("res://assets/cast/bonemap.tres"),
"retarget/bone_renamer/rename_bones": true,
"retarget/bone_renamer/unique_node/make_unique": true,
"retarget/bone_renamer/unique_node/skeleton_name": "GeneralSkeleton",
"retarget/remove_tracks/except_bone_transform": false,
"retarget/remove_tracks/unimportant_positions": true,
"retarget/remove_tracks/unmapped_bones": 1,
"retarget/rest_fixer/apply_node_transforms": true,
"retarget/rest_fixer/fix_silhouette/base_height_adjustment": 0.0,
"retarget/rest_fixer/fix_silhouette/enable": true,
"retarget/rest_fixer/fix_silhouette/filter": [&"LeftFoot", &"RightFoot", &"LeftToes", &"RightToes"],
"retarget/rest_fixer/fix_silhouette/threshold": 15.0,
"retarget/rest_fixer/keep_global_rest_on_leftovers": true,
"retarget/rest_fixer/normalize_position_tracks": true,
"retarget/rest_fixer/reset_all_bone_poses_after_import": true,
"retarget/rest_fixer/retarget_method": 1
}
}
}
gltf/naming_version=2
gltf/embedded_image_handling=1
gltf/texture_map_mode=1
"""


TEXTURE_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"
%(uid)s
[params]

compress/mode=2
compress/high_quality=true
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=%(normal)d
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def texture_import(path, normal):
    """The texture's import settings, written by us: Godot's headless import never sees it used in
    3D, so it would stay uncompressed without mipmaps (the spike: denim shimmered, brows stippled).
    VRAM compressed (BPTC on desktop), mipmapped, normal maps as normal maps; Godot's uid kept."""
    imp = path + ".import"
    uid = ""
    if os.path.exists(imp):
        uid = next((ln.strip() for ln in open(imp) if ln.startswith("uid=")), "")
    open(imp, "w").write(TEXTURE_IMPORT % {"uid": uid + "\n" if uid else "", "normal": 1 if normal else 2})


def prune(cast):
    """Deletes the shared textures (and their .import) that no character's glTF names."""
    used = set()
    for cid in sorted(os.listdir(cast)):
        g = os.path.join(cast, cid, cid + ".gltf")
        if os.path.isfile(g):
            used |= {os.path.basename(im["uri"]) for im in json.load(open(g)).get("images", [])}
    tex = os.path.join(cast, "tex")
    for f in sorted(os.listdir(tex)):
        if f.endswith(".import") or f in used:
            continue
        for gone in (f, f + ".import"):
            if os.path.exists(os.path.join(tex, gone)):
                os.remove(os.path.join(tex, gone))
        print("POST prune", f)


def main():
    if sys.argv[1] == "--prune":
        prune(sys.argv[2])
        return
    src, cast = sys.argv[1], sys.argv[2]
    max_normal = int(sys.argv[sys.argv.index("--max-normal") + 1]) if "--max-normal" in sys.argv else 1024
    gltf_name = [f for f in os.listdir(src) if f.endswith(".gltf")][0]
    cid = gltf_name[:-5]
    g = json.load(open(os.path.join(src, gltf_name)))
    meta = json.load(open(os.path.join(src, cid + ".cast.json")))
    # which images are colour / normal / other, and for which role
    use = {}
    grey = set()
    for m in g.get("materials", []):
        role = m.get("name", "cloth__").split("__")[0]
        if meta.get("materials", {}).get(m.get("name"), {}).get("desaturate"):
            ref = m.get("pbrMetallicRoughness", {}).get("baseColorTexture")
            if ref is not None:
                grey.add(g["textures"][ref["index"]]["source"])
        pbr = m.get("pbrMetallicRoughness", {})
        slots = [("color", pbr.get("baseColorTexture")), ("normal", m.get("normalTexture")),
                 ("orm", pbr.get("metallicRoughnessTexture")), ("orm", m.get("occlusionTexture")),
                 ("color", m.get("emissiveTexture"))]
        for kind, ref in slots:
            if ref is None:
                continue
            img = g["textures"][ref["index"]]["source"]
            use.setdefault(img, set()).add((kind, role))
    tex_dir = os.path.join(cast, "tex")
    os.makedirs(tex_dir, exist_ok=True)
    out_dir = os.path.join(cast, cid)
    os.makedirs(out_dir, exist_ok=True)
    report = []
    for i, image in enumerate(g.get("images", [])):
        path = os.path.join(src, image["uri"])
        im = Image.open(path)
        kinds = use.get(i, {("color", "cloth")})
        roles = {r for _, r in kinds}
        is_normal = any(k == "normal" for k, _ in kinds)
        has_alpha = im.mode in ("RGBA", "LA") and im.getchannel("A").getextrema()[0] < 250
        keep_alpha = has_alpha and bool(roles & set(ALPHA_ROLES + ("eye",)))
        base = os.path.splitext(os.path.basename(image["uri"]))[0]
        if i in grey:                     # the spec's "desaturate": greys, a little lighter (grey hair)
            alpha = im.getchannel("A") if im.mode in ("RGBA", "LA") else None
            im = im.convert("L").point(lambda x: min(255, int(x * 1.25 + 20))).convert("RGB")
            if alpha is not None:
                im.putalpha(alpha)
            base += "_grey"
        if is_normal:
            if "skin" not in roles and max(im.size) > max_normal:
                f = max_normal / max(im.size)
                im = im.resize((int(im.size[0] * f), int(im.size[1] * f)), Image.LANCZOS)
            data, ext, mime = encode(im.convert("RGB"), "PNG"), "png", "image/png"
        elif keep_alpha:
            data, ext, mime = encode(im.convert("RGBA"), "PNG"), "png", "image/png"
        else:
            data, ext, mime = encode(im.convert("RGB"), "JPEG"), "jpg", "image/jpeg"
        name = "%s.%s" % (base, ext)
        dest = os.path.join(tex_dir, name)
        if os.path.exists(dest) and open(dest, "rb").read() != data:
            name = "%s_%s.%s" % (base, hashlib.sha256(data).hexdigest()[:8], ext)
            dest = os.path.join(tex_dir, name)
        if not os.path.exists(dest):
            open(dest, "wb").write(data)
        texture_import(dest, is_normal)
        image["uri"] = "../tex/" + name
        image["mimeType"] = mime
        report.append("%-44s %-4s %5d KB  %s" % (name, ext, len(data) // 1024, ",".join(sorted("%s:%s" % k for k in kinds))))
    json.dump(g, open(os.path.join(out_dir, cid + ".gltf"), "w"), indent=1)
    for buf in g.get("buffers", []):
        shutil.copyfile(os.path.join(src, buf["uri"]), os.path.join(out_dir, buf["uri"]))
    json.dump(meta, open(os.path.join(out_dir, cid + ".cast.json"), "w"), indent=1, sort_keys=True)
    imp = os.path.join(out_dir, cid + ".gltf.import")
    if not os.path.exists(imp):
        open(imp, "w").write(IMPORT % {"id": cid})
    for r in report:
        print("POST", cid, r)
    size = sum(os.path.getsize(os.path.join(out_dir, f)) for f in os.listdir(out_dir))
    print("POST %s: %d KB in %s (+ shared textures)" % (cid, size // 1024, out_dir))


def encode(im, fmt):
    buf = io.BytesIO()
    if fmt == "JPEG":
        im.save(buf, "JPEG", quality=88, optimize=True, progressive=False, subsampling=0)
    else:
        im.save(buf, "PNG", optimize=True)
    return buf.getvalue()


if __name__ == "__main__":
    main()
