#!/usr/bin/env python3
"""Catalogue a humanoid animation pack: every clip's length, its skeleton and its root motion.

The owner's packs arrive as .glb, .fbx or .bvh. This reads all three without Blender or an FBX SDK
(.fbx through tools/anim/fbx_reader.py, .glb through its JSON and binary chunks, .bvh as text) and
writes the manifest another agent needs to pick clips without opening them: clip name, seconds,
frames, frame rate, the bone list, and how far the root travels (so a walk cycle's speed is a
division, not a guess). Lengths come from the key times themselves, not a header that can lie.

usage: python3 tools/anim/inspect_packs.py <dir> --pack <id> [--json tools/anim/manifests/<id>.json]
       python3 tools/anim/inspect_packs.py <dir> --pack <id> --quiet     (manifest only)
needs: nothing but the standard library

The manifests under tools/anim/manifests/ are the committed inventories; docs/ANIMATIONS.md reads
them. Re-run after staging the packs (tools/anim/stage_packs.sh) to rebuild one.
"""
import argparse
import hashlib
import json
import math
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fbx_reader  # noqa: E402

# Bones a pack may use for its root motion, best first.
ROOT_BONES = ("root", "B-root", "Hips", "B-hips", "pelvis", "Armature")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


# ---------------------------------------------------------------- glTF binary

def read_glb(path):
    """The JSON chunk and the binary chunk of a .glb."""
    with open(path, "rb") as f:
        magic, _version, length = struct.unpack("<III", f.read(12))
        if magic != 0x46546C67:
            raise ValueError("%s is not a .glb" % os.path.basename(path))
        doc, blob = None, b""
        while f.tell() < length:
            size, kind = struct.unpack("<II", f.read(8))
            chunk = f.read(size)
            if kind == 0x4E4F534A:
                doc = json.loads(chunk.decode("utf-8"))
            elif kind == 0x004E4942:
                blob = chunk
        return doc, blob


# glTF component type -> struct code
GLTF_TYPES = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
GLTF_COUNTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_accessor(doc, blob, index):
    """An accessor's values as a list of tuples (plain buffer layouts only)."""
    acc = doc["accessors"][index]
    if "bufferView" not in acc:
        return []
    view = doc["bufferViews"][acc["bufferView"]]
    code = GLTF_TYPES[acc["componentType"]]
    size = GLTF_COUNTS[acc["type"]]
    width = struct.calcsize("<" + code)
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride") or width * size
    out = []
    for i in range(acc["count"]):
        at = start + i * stride
        out.append(struct.unpack_from("<%d%s" % (size, code), blob, at))
    return out


def scan_glb(path):
    doc, blob = read_glb(path)
    nodes = doc.get("nodes", [])
    accessors = doc.get("accessors", [])
    skins = doc.get("skins", [])
    bones = [nodes[j].get("name", "?") for j in skins[0].get("joints", [])] if skins else []
    root_nodes = {i for i, node in enumerate(nodes) if node.get("name") in ROOT_BONES}
    clips = []
    for anim in doc.get("animations", []):
        seconds, targets, moved = 0.0, set(), {}
        for channel in anim.get("channels", []):
            sampler = anim["samplers"][channel["sampler"]]
            end = (accessors[sampler["input"]].get("max") or [0.0])[0]
            seconds = max(seconds, end or 0.0)
            target = channel["target"].get("node")
            targets.add(target)
            if target in root_nodes and channel["target"].get("path") == "translation":
                values = read_accessor(doc, blob, sampler["output"])
                if values:
                    axes = list(zip(*values))
                    keys = ("x", "y", "z")
                    span = {k: round(max(v) - min(v), 3) for k, v in zip(keys, axes)}
                    net = {k: round(v[-1] - v[0], 3) for k, v in zip(keys, axes)}
                    moved[nodes[target].get("name")] = {
                        "bone": nodes[target].get("name"), "span": span, "net": net,
                        "distance": round(math.hypot(net["x"], net["z"]), 3)}
        # The skeleton's own root carries the travel; the hip bone under it only sways, so take
        # them in ROOT_BONES order rather than whichever channel came last.
        motion = next((moved[b] for b in ROOT_BONES if b in moved), {})
        clips.append({
            "name": anim.get("name", "?"),
            "seconds": round(seconds, 3),
            "channels": len(anim.get("channels", [])),
            "animated_bones": len(targets),
            "root_motion": motion,
        })
    meshes = []
    for mesh in doc.get("meshes", []):
        verts = tris = 0
        for prim in mesh.get("primitives", []):
            verts += accessors[prim["attributes"]["POSITION"]]["count"]
            if "indices" in prim:
                tris += accessors[prim["indices"]]["count"] // 3
        meshes.append({"name": mesh.get("name", "?"), "vertices": verts, "triangles": tris})
    return {"bones": bones, "clips": clips, "meshes": meshes,
            "generator": doc.get("asset", {}).get("generator", "")}


# ------------------------------------------------------------------ binary FBX

def scan_fbx(path):
    version, roots = fbx_reader.parse(path)
    objs, conns = fbx_reader.objects(roots)
    settings = fbx_reader.settings(roots)
    parents = {}
    for conn in conns:
        parents.setdefault(conn[1], []).append((conn[2], conn[3] if len(conn) > 3 else None))
    children = {}
    for conn in conns:
        children.setdefault(conn[2], []).append((conn[1], conn[3] if len(conn) > 3 else None))

    bones = [name for cls, name, _rec in objs.values() if cls == "Model"]
    by_name = {}
    for oid, (cls, name, _rec) in objs.items():
        if cls == "Model":
            by_name.setdefault(name, oid)

    def curve_data(curve_id, want):
        for node in fbx_reader.walk(objs[curve_id][2]):
            if node[0] == want and node[1]:
                return node[1][0]
        return None

    def curves_of(layer_id):
        """{(bone, property, axis): curve id} under one animation layer."""
        found = {}
        for curve_node, _p in children.get(layer_id, []):
            if objs.get(curve_node, ("",))[0] != "AnimationCurveNode":
                continue
            bone, prop = "", ""
            for target, name in parents.get(curve_node, []):
                if objs.get(target, ("",))[0] == "Model":
                    bone, prop = objs[target][1], name or ""
            for curve, axis in children.get(curve_node, []):
                if objs.get(curve, ("",))[0] == "AnimationCurve":
                    found[(bone, prop, axis)] = curve
        return found

    # One file can hold many takes (the Unity build of a library holds all of them), each an
    # AnimationStack over its own layer, so length and root motion are measured per stack.
    stacks = [(oid, name) for oid, (cls, name, _r) in objs.items() if cls == "AnimationStack"]
    fps = fbx_reader.TIME_MODES.get(settings.get("TimeMode"), 0.0)
    takes = []
    for stack_id, stack_name in sorted(stacks, key=lambda s: s[1]):
        layers = [lid for lid, _p in children.get(stack_id, [])
                  if objs.get(lid, ("",))[0] == "AnimationLayer"]
        curves = {}
        for layer in layers:
            curves.update(curves_of(layer))
        seconds, keys = 0.0, 0
        for curve in set(curves.values()):
            times = curve_data(curve, "KeyTime")
            if times:
                seconds = max(seconds, times[-1] / fbx_reader.KTIME)
                keys += len(times)
        motion = {}
        for bone in ROOT_BONES:
            axes = {axis: curve for (b, prop, axis), curve in curves.items()
                    if b == bone and prop == "Lcl Translation"}
            if not axes:
                continue
            span, net = {}, {}
            for axis, curve in sorted(axes.items()):
                values = curve_data(curve, "KeyValueFloat") or [0.0]
                key = axis[-1].lower()  # "d|X" -> "x"
                span[key] = round(max(values) - min(values), 2)
                net[key] = round(values[-1] - values[0], 2)
            # Up is Z in a Z-up file, Y in a Y-up one; travel is the other two axes.
            flat = ("x", "y") if settings.get("UpAxis") == 2 else ("x", "z")
            motion = {"bone": bone, "span": span, "net": net,
                      "distance": round(math.hypot(*[net.get(a, 0.0) for a in flat]), 2)}
            break
        takes.append({
            "name": stack_name.split("|")[-1],  # "Armature|Walk_Loop" -> "Walk_Loop"
            "seconds": round(seconds, 3),
            "frames": int(round(seconds * fps)) + 1 if fps else 0,
            "fps": fps,
            "keys": keys,
            "root_motion": motion,
        })

    meshes = []
    for cls, name, record in objs.values():
        if cls != "Geometry":
            continue
        verts = polys = 0
        for node in fbx_reader.walk(record):
            if node[0] == "Vertices" and node[1]:
                verts = len(node[1][0]) // 3
            elif node[0] == "PolygonVertexIndex" and node[1]:
                polys = sum(1 for i in node[1][0] if i < 0)  # a negative index closes a polygon
        if verts:
            meshes.append({"name": name, "vertices": verts, "polygons": polys})

    return {
        "format": "fbx%d" % version,
        "takes": takes,
        "bones": bones,
        "meshes": meshes,
        "up_axis": "XYZ"[int(settings.get("UpAxis", 1))],
        "unit_scale": settings.get("UnitScaleFactor"),
    }


# ------------------------------------------------------------------------ BVH

def scan_bvh(path):
    with open(path, "r", errors="replace") as f:
        text = f.read()
    header, _, motion = text.partition("MOTION")
    bones = [m.group(1) for m in re.finditer(r"(?:ROOT|JOINT)\s+(\S+)", header)]
    ends = len(re.findall(r"End Site", header))
    frames = int(re.search(r"Frames:\s*(\d+)", motion).group(1))
    frame_time = float(re.search(r"Frame Time:\s*([\d.eE+-]+)", motion).group(1))
    rows = [[float(v) for v in line.split()]
            for line in motion.splitlines()
            if line.strip() and not line.strip().startswith(("Frames", "Frame Time"))]
    span = net = {}
    if rows:
        xs, ys, zs = ([row[i] for row in rows] for i in range(3))
        span = {"x": round(max(xs) - min(xs), 2), "y": round(max(ys) - min(ys), 2),
                "z": round(max(zs) - min(zs), 2)}
        net = {"x": round(xs[-1] - xs[0], 2), "y": round(ys[-1] - ys[0], 2),
               "z": round(zs[-1] - zs[0], 2)}
    return {
        "format": "bvh",
        "bones": bones,
        "end_sites": ends,
        "takes": [{
            "name": os.path.basename(path)[:-4],
            "seconds": round(frames * frame_time, 3),
            "frames": frames,
            "fps": round(1.0 / frame_time, 2) if frame_time else 0.0,
            "root_motion": {"bone": bones[0] if bones else "", "span": span, "net": net,
                            "distance": round(math.hypot(net.get("x", 0.0), net.get("z", 0.0)), 2)},
        }],
    }


# ---------------------------------------------------------------------- walker

def scan(root):
    """Every readable file under root, as (relative path, record)."""
    out = []
    for base, dirs, names in os.walk(root):
        dirs.sort()
        for name in sorted(names):
            path = os.path.join(base, name)
            rel = os.path.relpath(path, root).replace(os.sep, "/")
            ext = name.rsplit(".", 1)[-1].lower()
            try:
                if ext == "glb":
                    record = scan_glb(path)
                    record["format"] = "glb"
                elif ext == "fbx":
                    record = scan_fbx(path)
                elif ext == "bvh":
                    record = scan_bvh(path)
                else:
                    continue
            except Exception as exc:  # a pack may ship a file we cannot read; say so, keep going
                out.append((rel, {"error": "%s: %s" % (type(exc).__name__, exc)}))
                continue
            record["bytes"] = os.path.getsize(path)
            record["sha256"] = sha256(path)[:16]
            out.append((rel, record))
    return out


def manifest(pack, files):
    skeletons = {}
    clips = []
    for rel, record in files:
        if "error" in record:
            clips.append({"file": rel, "error": record["error"]})
            continue
        bones = tuple(record.get("bones", []))
        if bones:
            skeletons.setdefault(bones, []).append(rel)
        if record["format"] == "glb":
            for clip in record["clips"]:
                clip = dict(clip)
                clip["file"] = rel
                clips.append(clip)
        else:
            # One take per file is the rule in these packs, and then the file name is the clip
            # name: the take inside is sometimes a generic "Take1", which an importer would
            # otherwise give to all of them. A file with several takes keeps their own names.
            stem = os.path.basename(rel).rsplit(".", 1)[0]
            takes = record["takes"]
            for take in takes:
                clip = {
                    "file": rel,
                    "name": take["name"] if len(takes) > 1 else stem,
                    "seconds": take["seconds"],
                    "frames": take["frames"],
                    "fps": take["fps"],
                    "root_motion": take["root_motion"],
                }
                if len(takes) == 1 and take["name"] and take["name"] != stem:
                    clip["take"] = take["name"]
                clips.append(clip)
    # Each format the pack ships in, with the space its numbers are in: an FBX unit scale of 1
    # means centimetres, 100 means metres, and glTF is always metres, Y up.
    spaces = {}
    for rel, record in files:
        if "error" in record:
            continue
        key = (record["format"], record.get("up_axis", "Y"), record.get("unit_scale", 100.0))
        spaces.setdefault(key, []).append(rel)
    return {
        "pack": pack,
        "files": len(files),
        "clips": len(clips),
        "seconds": round(sum(c.get("seconds", 0.0) for c in clips), 2),
        "formats": [{"format": f, "up_axis": up, "unit_scale": scale, "files": len(paths)}
                    for (f, up, scale), paths in sorted(spaces.items())],
        "skeletons": [{"bones": len(b), "files": len(f), "names": list(b)}
                      for b, f in sorted(skeletons.items(), key=lambda kv: -len(kv[1]))],
        "meshes": [dict(m, file=rel) for rel, r in files for m in r.get("meshes", [])],
        "clip_list": clips,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("dir", help="the staged pack directory")
    ap.add_argument("--pack", required=True, help="pack id, e.g. motifect_emotes_social")
    ap.add_argument("--json", help="write the manifest here")
    ap.add_argument("--quiet", action="store_true", help="no table, just write the manifest")
    args = ap.parse_args()

    files = scan(args.dir)
    if not files:
        sys.exit("no .glb, .fbx or .bvh under %s" % args.dir)
    data = manifest(args.pack, files)

    if not args.quiet:
        print("%s: %d files, %d clips, %.1f s" % (data["pack"], data["files"], data["clips"],
                                                  data["seconds"]))
        for skel in data["skeletons"]:
            print("  skeleton of %d bones in %d files: %s" % (
                skel["bones"], skel["files"], ", ".join(skel["names"][:8]) + " ..."))
        print("%-46s %8s %7s %6s  %s" % ("clip", "seconds", "frames", "fps", "root motion"))
        for clip in data["clip_list"]:
            if "error" in clip:
                print("%-46s %s" % (clip["file"][:46], clip["error"]))
                continue
            motion = clip.get("root_motion") or {}
            moved = motion.get("distance", 0.0)
            print("%-46s %8.2f %7s %6s  %s" % (
                clip["name"][:46], clip["seconds"], clip.get("frames", ""), clip.get("fps", ""),
                "%s moves %.1f" % (motion.get("bone", ""), moved) if moved else "in place"))

    if args.json:
        os.makedirs(os.path.dirname(os.path.abspath(args.json)), exist_ok=True)
        with open(args.json, "w") as f:
            json.dump(data, f, indent=1, sort_keys=False)
            f.write("\n")
        print("wrote %s" % args.json)


if __name__ == "__main__":
    main()
