"""The cast's licence gate (PLAN M20-9): reads every MakeHuman asset in the pack zips -- clothes, hair,
eyebrows, eyelashes, eyes, teeth, skins, proxies, targets -- and says which licence it is under,
from the asset's OWN header and from its pack's list, the stricter of the two winning. The pack lists
are not to be trusted alone: hair01's list calls every hair CC0 while some of their .mhclo headers say
AGPL3 (found by the survey, 24 Oct). CC0 and CC BY pass (CC BY with a credit line); AGPL, GPL, other
and unknown fail, unless an asset is in allow.json with the reason it was reviewed.

usage: python3 -I licences.py <zips dir> [--json out.json] [--show ASSET]
       python3 -I licences.py <zips dir> --check kind/asset ...   (exit 1 if any fails)
"""
import json
import os
import re
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
KINDS = ("clothes", "hair", "eyebrows", "eyelashes", "eyes", "teeth", "tongue", "skins", "proxymeshes")


def norm(text):
    """A licence string as one of: CC0, CC-BY-3.0, CC-BY-4.0, CC-BY (no version), AGPL, GPL, OTHER, ''."""
    t = (text or "").strip().lower().replace("_", " ").replace("-", " ")
    if not t:
        return ""
    if "agpl" in t or "affero" in t:
        return "AGPL"
    if re.search(r"\bgpl\b", t) or "gnu general" in t:
        return "GPL"
    if "cc0" in t or re.search(r"\bcc\s+0\b", t) or "public domain" in t or "commons zero" in t:
        return "CC0"
    m = re.search(r"cc\s*by\s*(\d\.\d)?", t)
    if m and "sa" not in t.split("by", 1)[1][:6] and "nc" not in t:
        return "CC-BY-%s" % m.group(1) if m.group(1) else "CC-BY"
    return "OTHER"


def rank(lic):
    """How strict a licence is: higher fails sooner."""
    return {"CC0": 0, "CC-BY-4.0": 1, "CC-BY-3.0": 1, "CC-BY": 1, "": 2, "OTHER": 3, "GPL": 4, "AGPL": 5}[lic]


def header(text):
    """(licence, author) from a MakeHuman asset file's header."""
    lic, author = "", ""
    for line in text.splitlines()[:40]:
        s = line.strip()
        low = s.lower()
        if "released as cc0" in low:
            lic = lic or "CC0"
        elif "license" in low and not lic:
            # "# license CC_by", "# license: CC-BY", "# Original model by RodAlln License CC-BY", ...
            lic = norm(s[low.index("license") + 7:].lstrip(" :"))
        if (low.startswith("# author") or low.startswith("author ")) and not author:
            author = s.split("uthor", 1)[1].split(" License")[0].strip()
        elif low.startswith("# copyright") and not author:
            author = s[1:].strip()
    return lic, author


def scan(zips_dir):
    """{kind/asset: {pack, zip, kind, asset, header, author, listed, licence, files}}."""
    out = {}
    listed = {}
    for z in sorted(os.listdir(zips_dir)):
        if not z.endswith(".zip") or z.startswith("add-on-mpfb"):
            continue
        zf = zipfile.ZipFile(os.path.join(zips_dir, z))
        pack = z[:-4]
        for n in zf.namelist():
            if n.startswith("packs/") and n.endswith(".json"):
                try:
                    pj = json.loads(zf.read(n))
                except ValueError:
                    continue
                # a dict of asset name -> {author, license, source, ...} (older packs: a list of dicts)
                items = pj.items() if isinstance(pj, dict) else [(a.get("name", ""), a) for a in pj if isinstance(a, dict)]
                for key, a in items:
                    if isinstance(a, dict) and "license" in a:
                        listed[key] = {"licence": norm(str(a.get("license", ""))), "author": a.get("author", ""),
                                       "source": a.get("source", "")}
        for n in zf.namelist():
            parts = n.split("/")
            if len(parts) < 3 or parts[0] not in KINDS or not parts[2]:
                continue
            key = "%s/%s" % (parts[0], parts[1])
            e = out.setdefault(key, {"pack": pack, "zip": z, "kind": parts[0], "asset": parts[1], "header": "",
                                     "author": "", "files": []})
            e["files"].append(n)
            if n.endswith((".mhclo", ".mhmat", ".proxy")) and (not e["header"] or n.endswith(".mhclo")):
                lic, author = header(zf.read(n).decode("utf8", "replace"))
                if lic or n.endswith(".mhclo"):
                    e["header"], e["author"] = lic, author or e["author"]
    allow = json.load(open(os.path.join(HERE, "allow.json"))) if os.path.exists(os.path.join(HERE, "allow.json")) else {}
    for key, e in out.items():
        info = listed.get(e["asset"], {})
        e["listed"] = info.get("licence", "")
        e["source"] = info.get("source", "")
        e["author"] = e["author"] or info.get("author", "")
        lics = [l for l in (e["header"], e["listed"]) if l != ""]
        lic = max(lics, key=rank) if lics else ""
        if e["header"] == "" and key in allow and not key.startswith("_"):
            lic = allow[key]["licence"]
            e["allowed_because"] = allow[key]["why"]
        e["licence"] = lic
        e["ok"] = rank(lic) <= 1
    return out


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(2)
    table = scan(args[0])
    if "--json" in args:
        json.dump(table, open(args[args.index("--json") + 1], "w"), indent=1, sort_keys=True)
    if "--check" in args:
        bad = []
        for key in args[args.index("--check") + 1:]:
            e = table.get(key)
            if e is None or not e["ok"]:
                bad.append("%s: %s" % (key, "not in any pack" if e is None else e["licence"] or "no licence"))
        for b in bad:
            print("LICENCE_FAIL " + b)
        print("LICENCE_CHECK %s" % ("FAIL" if bad else "PASS"))
        sys.exit(1 if bad else 0)
    if "--show" in args:
        print(json.dumps(table.get(args[args.index("--show") + 1]), indent=1))
        return
    counts = {}
    for e in table.values():
        counts[(e["kind"], e["licence"] or "?")] = counts.get((e["kind"], e["licence"] or "?"), 0) + 1
    for (kind, lic), n in sorted(counts.items()):
        print("%-12s %-10s %4d" % (kind, lic, n))
    for key, e in sorted(table.items()):
        if e["header"] and e["listed"] and e["header"] != e["listed"]:
            print("DISAGREE %-50s header %-9s list %-9s -> %s" % (key, e["header"], e["listed"], e["licence"]))


if __name__ == "__main__":
    main()
