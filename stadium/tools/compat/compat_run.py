#!/usr/bin/env python3
"""Checks ManiaPark's whole catalogue against the game, a batch at a time: lists every asset of a
kind (texture mods; TMNF/TMUF car models and skins), downloads a batch into WORK/batch, runs the
game's compatibility test on it (tests/test_compat_mods / test_compat_cars), records each item's
result, then deletes the batch (or moves it to --keep=DIR: your own private copy, e.g. on your PC).
Resumable: items already in the results are skipped. The downloads never go in the repo (they are
their authors' works); the results do: stadium/tools/compat/results/<kind>.tsv (ids, names,
authors, checksums, what the game made of each).

    python3 -I stadium/tools/compat/compat_run.py mods WORK [--batch=40] [--keep=DIR] [--limit=N]
    python3 -I stadium/tools/compat/compat_run.py cars WORK [--batch=60] [--keep=DIR] [--limit=N]
    python3 -I stadium/tools/compat/compat_run.py tsv WORK mods|cars     # rewrite the TSV only

mods: ManiaPark's texture mods for TMNF/TMUF (game 0) and ManiaPlanet (game 1); cars: TMNF/TMUF car
models and skins (game 0). Needs Godot (GODOT=... or `godot` on PATH) like stadium/tools/run.sh.
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request

API = "https://maniapark.com/api/search"
SITE = "https://maniapark.com"
UA = "SpeedFestStadium-compat/1.0 (+https://github.com/khanhonthetrack/speedfest)"
HERE = os.path.dirname(os.path.abspath(__file__))
STADIUM = os.path.dirname(os.path.dirname(HERE))
# kind -> [(asset type, game, download path word, label)]: ManiaPark's asset types: 0 texture mods,
# 1 car models, 2 car skins; games: 0 TrackMania (TMNF/TMUF/...), 1 ManiaPlanet
KINDS = {
    "mods": [(0, 0, "mod", "tm1"), (0, 1, "mod", "maniaplanet")],
    "cars": [(1, 0, "model", "model"), (2, 0, "skin", "skin")],
}
TESTS = {"mods": "res://tests/test_compat_mods.tscn", "cars": "res://tests/test_compat_cars.tscn"}
COLUMNS = {
    "mods": ["id", "game", "name", "author", "bytes", "sha256", "ok", "environment", "textures", "wearable", "keys", "why"],
    "cars": ["id", "kind", "name", "author", "bytes", "sha256", "ok", "skin_only", "triangles", "wheels", "textures", "why"],
}


def get(url, tries=4, timeout=180):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read(), r.headers.get("content-type", "")
        except Exception as e:  # network hiccups: back off and retry
            if i == tries - 1:
                print(f"  failed {url}: {e}", file=sys.stderr)
                return None, ""
            time.sleep(2 ** (i + 1))


def catalogue(work, kind):
    """Every asset of the kind (metadata only), cached in WORK/catalogue_<kind>.json."""
    path = os.path.join(work, f"catalogue_{kind}.json")
    if os.path.exists(path):
        return json.load(open(path))
    items = []
    for asset, game, word, label in KINDS[kind]:
        after = None
        while True:
            q = {"asset": asset, "game": game, "count": 100}
            if after:
                q["after"] = after
            raw, _ = get(f"{API}?{urllib.parse.urlencode(q)}")
            if not raw:
                break
            d = json.loads(raw)
            res = d.get("Results", [])
            for r in res:
                items.append({"id": r["AssetId"], "word": word, "label": label, "name": r.get("Name", ""),
                              "author": (r.get("User") or {}).get("Name", ""), "downloads": r.get("DownloadCount", 0)})
            if not d.get("More") or not res:
                break
            after = res[-1]["AssetId"]
            time.sleep(0.4)
        print(f"{kind}: {label}: {sum(1 for i in items if i['label'] == label)} listed")
    with open(path, "w") as f:
        json.dump(items, f, indent=0)
    return items


def godot_test(kind, batch, results):
    cmd = [os.path.join(STADIUM, "tools", "run.sh"), TESTS[kind], "--headless", "--timeout", "3000", "--",
           f"--dir={batch}", f"--index={os.path.join(batch, 'index.json')}", f"--results={results}"]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=3300)
    tail = [l for l in out.stdout.splitlines() if l.startswith(("MODS", "CARS", "TEST_"))]
    print("   " + "\n   ".join(tail[-6:]))
    try:
        return json.load(open(results))
    except Exception:
        return {}


def run(kind, work, batch_size, keep, limit):
    items = catalogue(work, kind)
    res_path = os.path.join(work, f"results_{kind}.json")
    results = json.load(open(res_path)) if os.path.exists(res_path) else {}
    todo = [i for i in items if i["id"] not in results]
    if limit:
        todo = todo[:limit]
    print(f"{kind}: {len(items)} listed, {len(results)} done, {len(todo)} to do")
    batch = os.path.join(work, "batch")
    for start in range(0, len(todo), batch_size):
        chunk = todo[start:start + batch_size]
        shutil.rmtree(batch, ignore_errors=True)
        os.makedirs(batch)
        index, meta = {}, {}
        for it in chunk:
            raw, ctype = get(f"{SITE}/{it['word']}/{it['id']}/download")
            m = {"id": it["id"], "name": it["name"], "author": it["author"], "kind": it["label"], "game": it["label"],
                 "bytes": len(raw) if raw else 0, "sha256": hashlib.sha256(raw).hexdigest() if raw else ""}
            if not raw:
                m.update(ok=False, why="download failed")
                results[it["id"]] = m
                continue
            if not raw.startswith(b"PK"):
                kind_of = "RAR" if raw.startswith(b"Rar!") else "7z" if raw.startswith(b"7z\xbc\xaf") else ctype or "unknown"
                m.update(ok=False, why=f"not a zip ({kind_of})")
                results[it["id"]] = m
                continue
            fname = f"{it['label']}_{it['id']}.zip"
            with open(os.path.join(batch, fname), "wb") as f:
                f.write(raw)
            index[fname] = {"name": it["name"], "game": it["label"]}
            meta[fname] = m
            time.sleep(0.3)
        with open(os.path.join(batch, "index.json"), "w") as f:
            json.dump(index, f)
        got = godot_test(kind, batch, os.path.join(work, "batch_results.json")) if index else {}
        for fname, m in meta.items():
            r = got.get(fname)
            if r is None:
                m.update(ok=False, why="the test didn't report it (crashed?)")
            else:
                m.update(r)
            results[m["id"]] = m
        if keep:
            os.makedirs(keep, exist_ok=True)
            for fname in index:
                shutil.move(os.path.join(batch, fname), os.path.join(keep, fname))
        shutil.rmtree(batch, ignore_errors=True)
        with open(res_path, "w") as f:
            json.dump(results, f, indent=0)
        bad = sum(1 for r in results.values() if not r.get("ok"))
        print(f"{kind}: {len(results)}/{len(items)} done, {bad} not ok")
    write_tsv(kind, work)


def write_tsv(kind, work):
    results = json.load(open(os.path.join(work, f"results_{kind}.json")))
    out_dir = os.path.join(HERE, "results")
    os.makedirs(out_dir, exist_ok=True)
    cols = COLUMNS[kind]
    rows = sorted(results.values(), key=lambda r: (str(r.get("game", r.get("kind", ""))), str(r.get("name", "")).lower()))
    with open(os.path.join(out_dir, f"maniapark_{kind}.tsv"), "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            vals = []
            for c in cols:
                v = r.get(c, "")
                if isinstance(v, bool):
                    v = "yes" if v else "no"
                vals.append(str(v).replace("\t", " ").replace("\n", " ").replace("\r", " "))
            f.write("\t".join(vals) + "\n")
    print(f"wrote {os.path.join(out_dir, f'maniapark_{kind}.tsv')} ({len(rows)} rows)")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if len(args) < 2 or args[0] not in ("mods", "cars", "tsv"):
        print(__doc__)
        sys.exit(2)
    if args[0] == "tsv":
        write_tsv(args[2], args[1])
        return
    kind, work = args[0], args[1]
    os.makedirs(work, exist_ok=True)
    run(kind, work, int(opts.get("batch", 40 if kind == "mods" else 60)), opts.get("keep", ""), int(opts.get("limit", 0)))


if __name__ == "__main__":
    main()
