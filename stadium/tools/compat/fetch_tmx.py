#!/usr/bin/env python3
"""Download a sample of community tracks from TrackMania Exchange (TMNF-X, and optionally TMUF-X's
Stadium tracks) into a folder OUTSIDE the repo, for the compatibility test
(tests/test_compat_tracks: every track must read, build without placeholders and have a start
and a finish). Nothing downloaded here is ever committed: the tracks belong to their authors.

    python3 -I stadium/tools/compat/fetch_tmx.py <out dir> [--quick] [--united]

Sets (deduplicated): the most awarded, the most downloaded, the newest, the oldest, each track
type and each tag (by awards). --quick takes a few of each (about 120 tracks). Writes
<out>/<TrackId>.Challenge.Gbx and <out>/index.json ({id: {name, set, site, uploaded, awards}}).
Already downloaded tracks are kept (re-runs only fetch what is missing).
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

SITES = {"tmnf": "https://tmnf.exchange", "tmuf": "https://tmuf.exchange"}
FIELDS = "TrackId,TrackName,UploadedAt,Awards,PrimaryType,Tags,Environment"
UA = "SpeedFestStadium-compat/1.0 (+https://github.com/khanhonthetrack/speedfest)"


def get(url, tries=4):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read()
        except Exception as e:  # network hiccups: back off and retry
            if i == tries - 1:
                print(f"  failed {url}: {e}", file=sys.stderr)
                return None
            time.sleep(2 ** (i + 1))


def search(site, params, count):
    out = []
    after = None
    while len(out) < count:
        q = dict(params, fields=FIELDS, count=min(100, count - len(out)))
        if after is not None:
            q["after"] = after
        raw = get(f"{SITES[site]}/api/tracks?{urllib.parse.urlencode(q)}")
        if not raw:
            break
        d = json.loads(raw)
        res = d.get("Results", [])
        out += res
        if not d.get("More") or not res:
            break
        after = res[-1]["TrackId"]
    return out[:count]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        sys.exit(2)
    out_dir = args[0]
    quick = "--quick" in sys.argv
    united = "--united" in sys.argv
    os.makedirs(out_dir, exist_ok=True)
    n = (lambda big, small: small if quick else big)
    sets = [("awards", {"order1": 6}, n(400, 30)), ("downloads", {"order1": 18}, n(200, 15)),
            ("newest", {"order1": 2}, n(200, 20)), ("oldest", {"order1": 1}, n(150, 10))]
    for t, name in enumerate(["race", "puzzle", "platform", "stunts"]):
        sets.append((f"type:{name}", {"primarytype": t, "order1": 6}, n(60, 5)))
    tags = json.loads(get(f"{SITES['tmnf']}/api/meta/tags") or b"[]")
    for tag in tags:
        sets.append((f"tag:{tag['Name']}", {"tag": tag["Id"], "order1": 6}, n(30, 2)))
    index_path = os.path.join(out_dir, "index.json")
    index = json.load(open(index_path)) if os.path.exists(index_path) else {}
    sites = ["tmnf"] + (["tmuf"] if united else [])
    for site in sites:
        for name, params, count in sets:
            found = search(site, params, count)
            fresh = 0
            for t in found:
                if site == "tmuf" and t.get("Environment") != 7:
                    continue      # TMUF-X has every environment; the remake races Stadium
                key = f"{site}{t['TrackId']}" if site != "tmnf" else str(t["TrackId"])
                if key in index:
                    continue
                path = os.path.join(out_dir, f"{key}.Challenge.Gbx")
                if not os.path.exists(path):
                    raw = get(f"{SITES[site]}/trackgbx/{t['TrackId']}")
                    if not raw or not raw.startswith(b"GBX"):
                        continue
                    with open(path, "wb") as f:
                        f.write(raw)
                    time.sleep(0.15)
                index[key] = {"name": t.get("TrackName", ""), "set": f"{site}:{name}", "site": site,
                              "uploaded": t.get("UploadedAt", ""), "awards": t.get("Awards", 0)}
                fresh += 1
            print(f"{site} {name}: {len(found)} listed, {fresh} new (total {len(index)})")
            with open(index_path, "w") as f:
                json.dump(index, f, indent=0)
    print(f"TMX_FETCH_DONE {len(index)} tracks in {out_dir}")


if __name__ == "__main__":
    main()
