#!/usr/bin/env python3
"""A minimal reader for binary FBX files (our own code, no SDK).

The animation packs the owner bought ship as .fbx, which neither Godot nor this container can open
without Blender or FBX2glTF. Everything we need to catalogue a pack -- bone names, clip
length, frame rate, units, up axis and root motion -- sits in the file's node tree, so we read it
directly.

Binary FBX is a tree of records:
    EndOffset, NumProperties, PropertyListLen (uint32, or uint64 from version 7500),
    NameLen (uint8), Name, properties, nested records, a null record.
Properties are tagged by one letter: Y/C/I/F/D/L scalars, f/d/l/i/b arrays (optionally deflated),
S strings, R raw bytes.

usage: python3 tools/anim/fbx_reader.py <file.fbx>      (prints the header, objects and bones)
"""
import os
import struct
import sys
import zlib

KTIME = 46186158000.0  # FBX time units per second

# FBX TimeMode enum -> frames per second (only the modes the packs use are named).
TIME_MODES = {0: 0.0, 1: 120.0, 2: 100.0, 3: 60.0, 4: 50.0, 5: 48.0, 6: 30.0, 7: 30.0,
              8: 29.97, 9: 29.97, 10: 25.0, 11: 24.0, 12: 1000.0, 13: 23.976, 14: 0.0,
              15: 96.0, 16: 72.0, 17: 59.94}


class _Reader:
    def __init__(self, data: bytes):
        self.b = data
        self.p = 0

    def take(self, size: int, fmt: str):
        value = struct.unpack_from(fmt, self.b, self.p)[0]
        self.p += size
        return value


def _property(r: _Reader):
    tag = chr(r.take(1, "<B"))
    if tag == "Y":
        return r.take(2, "<h")
    if tag == "C":
        return bool(r.take(1, "<B"))
    if tag == "I":
        return r.take(4, "<i")
    if tag == "F":
        return r.take(4, "<f")
    if tag == "D":
        return r.take(8, "<d")
    if tag == "L":
        return r.take(8, "<q")
    if tag in "fdlib":
        count, encoding, packed = r.take(4, "<I"), r.take(4, "<I"), r.take(4, "<I")
        raw = r.b[r.p:r.p + packed]
        r.p += packed
        if encoding == 1:
            raw = zlib.decompress(raw)
        code = {"f": "f", "d": "d", "l": "q", "i": "i", "b": "b"}[tag]
        width = struct.calcsize("<" + code)
        count = min(count, len(raw) // width)
        return list(struct.unpack("<%d%s" % (count, code), raw[:count * width]))
    if tag in "SR":
        size = r.take(4, "<I")
        raw = r.b[r.p:r.p + size]
        r.p += size
        return raw.decode("utf-8", "replace") if tag == "S" else raw
    raise ValueError("unknown FBX property tag %r at byte %d" % (tag, r.p))


def _record(r: _Reader, wide: bool):
    if wide:
        end, nprops = r.take(8, "<Q"), r.take(8, "<Q")
        r.take(8, "<Q")
    else:
        end, nprops = r.take(4, "<I"), r.take(4, "<I")
        r.take(4, "<I")
    name_len = r.take(1, "<B")
    if end == 0:  # the null record that closes a list
        return None
    name = r.b[r.p:r.p + name_len].decode("utf-8", "replace")
    r.p += name_len
    props = [_property(r) for _ in range(nprops)]
    children = []
    while r.p < end:
        child = _record(r, wide)
        if child is None:
            break
        children.append(child)
    r.p = end
    return (name, props, children)


def parse(path: str):
    """Return (version, [root records]). A record is (name, properties, children)."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:20] != b"Kaydara FBX Binary  ":
        raise ValueError("%s is not a binary FBX" % os.path.basename(path))
    version = struct.unpack_from("<I", data, 23)[0]
    r = _Reader(data)
    r.p = 27
    wide = version >= 7500
    roots = []
    while r.p < len(data) - (25 if wide else 13):
        record = _record(r, wide)
        if record is None:
            break
        roots.append(record)
    return version, roots


def walk(record):
    """Yield every record in the subtree, depth first."""
    yield record
    for child in record[2]:
        yield from walk(child)


def settings(roots) -> dict:
    """UpAxis, UnitScaleFactor, TimeMode ... from GlobalSettings."""
    out = {}
    for root in roots:
        if root[0] != "GlobalSettings":
            continue
        for record in walk(root):
            if record[0] == "P" and len(record[1]) > 4:
                out[record[1][0]] = record[1][4]
    return out


def objects(roots):
    """{id: (class, name, record)} and the connection list from the file's Objects/Connections."""
    objs, conns = {}, []
    for root in roots:
        if root[0] == "Objects":
            for child in root[2]:
                name = child[1][1].split("\x00")[0] if len(child[1]) > 1 else ""
                objs[child[1][0]] = (child[0], name, child)
        elif root[0] == "Connections":
            conns.extend(child[1] for child in root[2])
    return objs, conns


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        version, roots = parse(arg)
        objs, conns = objects(roots)
        gs = settings(roots)
        kinds = {}
        for cls, _name, _rec in objs.values():
            kinds[cls] = kinds.get(cls, 0) + 1
        print("%s  FBX %d  %d bytes" % (os.path.basename(arg), version, os.path.getsize(arg)))
        print("  up axis %s  unit scale %s  time mode %s (%s fps)" % (
            gs.get("UpAxis"), gs.get("UnitScaleFactor"), gs.get("TimeMode"),
            TIME_MODES.get(gs.get("TimeMode"), "?")))
        print("  objects: %s" % kinds)
        bones = [name for cls, name, _r in objs.values() if cls == "Model"]
        print("  models (%d): %s" % (len(bones), ", ".join(bones)))
