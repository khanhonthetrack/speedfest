"""After gen_char.py (PLAN M20-9): a character's glTF and textures into the repo's cast folder.

    python3 -I post.py <gen_char out dir> <repo>/stadium/assets/cast [--max-normal 1024]

- colour maps with no alpha worth keeping become JPEG (quality 88); maps whose alpha matters (hair,
  brows, lashes, or any map with see-through texels) stay PNG; normal maps stay PNG (JPEG's blocks
  show in the light), capped at --max-normal for everything but the skin;
- every texture goes to <cast>/tex/, named after its source and shared by the whole cast (the same
  eyes, teeth and boots are not stored twice; a different picture under a taken name gets a hash);
- the glTF, its .bin and the sidecar <id>.cast.json go to <cast>/<id>/, the glTF's image URIs
  rewritten to ../tex/.
Deterministic: the same input gives the same bytes (PIL's encoders, no timestamps).
"""
import hashlib
import io
import json
import os
import shutil
import sys

from PIL import Image

ALPHA_ROLES = ("hair", "brow", "lash")


def main():
    src, cast = sys.argv[1], sys.argv[2]
    max_normal = int(sys.argv[sys.argv.index("--max-normal") + 1]) if "--max-normal" in sys.argv else 1024
    gltf_name = [f for f in os.listdir(src) if f.endswith(".gltf")][0]
    cid = gltf_name[:-5]
    g = json.load(open(os.path.join(src, gltf_name)))
    meta = json.load(open(os.path.join(src, cid + ".cast.json")))
    # which images are colour / normal / other, and for which role
    use = {}
    for m in g.get("materials", []):
        role = m.get("name", "cloth__").split("__")[0]
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
        image["uri"] = "../tex/" + name
        image["mimeType"] = mime
        report.append("%-44s %-4s %5d KB  %s" % (name, ext, len(data) // 1024, ",".join(sorted("%s:%s" % k for k in kinds))))
    json.dump(g, open(os.path.join(out_dir, cid + ".gltf"), "w"), indent=1)
    for buf in g.get("buffers", []):
        shutil.copyfile(os.path.join(src, buf["uri"]), os.path.join(out_dir, buf["uri"]))
    json.dump(meta, open(os.path.join(out_dir, cid + ".cast.json"), "w"), indent=1, sort_keys=True)
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
