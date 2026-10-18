#!/usr/bin/env python3
"""Download a sample of TrackMania (TMNF/TMUF) car models and skins from ManiaPark into a folder
OUTSIDE the repo, for the car compatibility test (tests/test_compat_cars: every pack must load
as the server repacks it, its mesh read, its textures decode and its wheels be found). Nothing
downloaded here is ever committed: the cars belong to their authors.

    python3 -I stadium/tools/compat/fetch_maniapark.py <out dir> [--models=N] [--skins=N]

Writes <out>/model_<AssetId>.zip and <out>/skin_<AssetId>.zip (the files as ManiaPark serves
them) and <out>/index.json ({file: {name, kind, id, author, downloads}}). Already downloaded packs
are kept (re-runs only fetch what is missing).
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

API = "https://maniapark.com/api/search"
UA = "SpeedFestStadium-compat/1.0 (+https://github.com/khanhonthetrack/speedfest)"
KINDS = {"model": 1, "skin": 2}


def get(url, tries=4):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except Exception as e:  # network hiccups: back off and retry
            if i == tries - 1:
                print(f"  failed {url}: {e}", file=sys.stderr)
                return None
            time.sleep(2 ** (i + 1))


def search(asset, count):
    """The first `count` TrackMania (game 0: TMNF/TMUF) assets of a kind, paged with `after`."""
    out = []
    after = None
    while len(out) < count:
        q = {"asset": asset, "game": 0, "count": min(40, count - len(out))}
        if after:
            q["after"] = after
        raw = get(f"{API}?{urllib.parse.urlencode(q)}")
        if not raw:
            break
        d = json.loads(raw)
        res = d.get("Results", [])
        out.extend(res)
        if not d.get("More") or not res:
            break
        after = res[-1]["AssetId"]
    return out


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    out = os.path.abspath(sys.argv[1])
    opts = dict(a[2:].split("=", 1) for a in sys.argv[2:] if a.startswith("--") and "=" in a)
    os.makedirs(out, exist_ok=True)
    index_path = os.path.join(out, "index.json")
    index = json.load(open(index_path)) if os.path.exists(index_path) else {}
    for kind, asset in KINDS.items():
        found = search(asset, int(opts.get(kind + "s", 60)))
        print(f"{kind}s: {len(found)}")
        for r in found:
            name = f"{kind}_{r['AssetId']}.zip"
            path = os.path.join(out, name)
            if not os.path.exists(path):
                data = get(f"https://maniapark.com/{kind}/{r['AssetId']}/download")
                if not data:
                    continue
                with open(path, "wb") as f:
                    f.write(data)
                time.sleep(0.5)  # be gentle with the site
            index[name] = {"name": r.get("Name", ""), "kind": kind, "id": r["AssetId"],
                           "author": (r.get("User") or {}).get("Name", ""), "downloads": r.get("DownloadCount", 0)}
    with open(index_path, "w") as f:
        json.dump(index, f, indent=1, sort_keys=True)
    print(f"{len(index)} packs in {out}")


if __name__ == "__main__":
    main()
