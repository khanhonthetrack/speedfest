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
    python3 -I stadium/tools/compat/compat_run.py tracks WORK [--batch=1000] [--keep=DIR] [--scale=1.0]
    python3 -I stadium/tools/compat/compat_run.py tsv WORK mods|cars|tracks     # rewrite the TSV only

mods: ManiaPark's texture mods for TMNF/TMUF (game 0) and ManiaPlanet (game 1); cars: TMNF/TMUF car
models and skins (game 0); tracks: a large sample of TrackMania Exchange's Stadium tracks (TMNF-X:
the most awarded, most downloaded, newest, oldest, each type and tag; TMUF-X's Stadium ones), each
read, built from our blocks and checked for a start and a finish (tests/test_compat_tracks --build);
--scale multiplies the set sizes. Needs Godot (GODOT=... or `godot` on PATH) like stadium/tools/run.sh.
"""
import concurrent.futures
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
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
TESTS = {"mods": "res://tests/test_compat_mods.tscn", "cars": "res://tests/test_compat_cars.tscn",
         "tracks": "res://tests/test_compat_tracks.tscn"}
TMX = {"tmnf": "https://tmnf.exchange", "tmuf": "https://tmuf.exchange"}
TMX_FIELDS = "TrackId,TrackName,Uploader.Name,UploadedAt,Awards,PrimaryType,Environment"
TMUF_STADIUM = 6          # TMUF-X's environment filter for Stadium (its listings say Environment 7)
COLUMNS = {
    "mods": ["id", "game", "name", "author", "bytes", "sha256", "ok", "environment", "textures", "wearable", "keys", "why"],
    "cars": ["id", "kind", "name", "author", "bytes", "sha256", "ok", "skin_only", "triangles", "wheels", "textures", "why"],
    "tracks": ["id", "site", "name", "author", "uploaded", "awards", "bytes", "sha256", "ok", "environment", "modded", "built",
               "raceable", "why"],
}


def get(url, tries=4, timeout=600):
    """(bytes, content type), or (None, why): 'http 404' (the site has no file), or the error."""
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read(), r.headers.get("content-type", "")
        except urllib.error.HTTPError as e:
            if e.code in (403, 404, 410) or i == tries - 1:
                return None, f"http {e.code}"
            time.sleep(2 ** (i + 1))
        except Exception as e:  # network hiccups: back off and retry
            if i == tries - 1:
                print(f"  failed {url}: {e}", file=sys.stderr)
                return None, str(e)[:80]
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
    extra = ["--build"] if kind == "tracks" else []
    # (on Windows the script runs through Git Bash's bash)
    cmd = (["bash"] if os.name == "nt" else []) + [os.path.join(STADIUM, "tools", "run.sh"), TESTS[kind], "--headless", "--timeout", "7000", "--",
           f"--dir={batch}", f"--index={os.path.join(batch, 'index.json')}", f"--results={results}"] + extra
    if os.path.exists(results):
        os.remove(results)
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=7300)
    tail = [l for l in out.stdout.splitlines() if l.startswith(("MODS ", "CARS ", "COMPAT ", "TEST_"))]
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
    chunks = [todo[i:i + batch_size] for i in range(0, len(todo), batch_size)]
    # four downloads at a time (ManiaPark serves each at a few MB/s); the next batch downloads
    # while the game tests this one
    pool = concurrent.futures.ThreadPoolExecutor(4)
    fetch = lambda chunk: [pool.submit(get, f"{SITE}/{it['word']}/{it['id']}/download") for it in chunk]
    pending = fetch(chunks[0]) if chunks else []
    for n, chunk in enumerate(chunks):
        fetched = [f.result() for f in pending]
        pending = fetch(chunks[n + 1]) if n + 1 < len(chunks) else []
        shutil.rmtree(batch, ignore_errors=True)
        os.makedirs(batch)
        index, meta = {}, {}
        for it, (raw, ctype) in zip(chunk, fetched):
            m = {"id": it["id"], "name": it["name"], "author": it["author"], "kind": it["label"], "game": it["label"],
                 "bytes": len(raw) if raw else 0, "sha256": hashlib.sha256(raw).hexdigest() if raw else ""}
            if not raw:
                m.update(ok=False, why="ManiaPark has no file for it (404)" if ctype == "http 404" else f"download failed ({ctype})")
                results[it["id"]] = m
                continue
            if not raw.startswith(b"PK"):
                kind_of = ("RAR" if raw.startswith(b"Rar!") else "7z" if raw.startswith(b"7z\xbc\xaf")
                           else "a ManiaPlanet .Pack.Gbx, Nadeo's encrypted format" if raw.startswith(b"NadeoPak") else ctype or "unknown")
                m.update(ok=False, why=f"not a zip ({kind_of})")
                results[it["id"]] = m
                continue
            fname = f"{it['label']}_{it['id']}.zip"
            with open(os.path.join(batch, fname), "wb") as f:
                f.write(raw)
            index[fname] = {"name": it["name"], "game": it["label"]}
            meta[fname] = m
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
    pool.shutdown()
    write_tsv(kind, work)


def tmx_catalogue(work, scale):
    """The track sample's listing (metadata only), cached in WORK/catalogue_tracks.json."""
    path = os.path.join(work, "catalogue_tracks.json")
    if os.path.exists(path):
        return json.load(open(path))
    n = lambda c: max(1, int(c * scale))
    sets = [("tmnf", "awards", {"order1": 6}, n(6000)), ("tmnf", "downloads", {"order1": 18}, n(4000)),
            ("tmnf", "newest", {"order1": 2}, n(5000)), ("tmnf", "oldest", {"order1": 1}, n(2000))]
    for t, name in enumerate(["race", "puzzle", "platform", "stunts"]):
        sets.append(("tmnf", f"type:{name}", {"primarytype": t, "order1": 6}, n(500)))
    raw, _ = get(f"{TMX['tmnf']}/api/meta/tags")
    for tag in json.loads(raw or b"[]"):
        sets.append(("tmnf", f"tag:{tag['Name']}", {"tag": tag["Id"], "order1": 6}, n(200)))
    for name, order in [("awards", 6), ("newest", 2), ("downloads", 18)]:
        sets.append(("tmuf", name, {"order1": order, "environment": TMUF_STADIUM}, n(2000)))
    items, seen = [], set()
    for site, name, params, count in sets:
        got, after = 0, None
        while got < count:
            q = dict(params, fields=TMX_FIELDS, count=min(100, count - got))
            if after is not None:
                q["after"] = after
            raw, _ = get(f"{TMX[site]}/api/tracks?{urllib.parse.urlencode(q)}")
            if not raw:
                break
            d = json.loads(raw)
            res = d.get("Results", [])
            for t in res:
                if site == "tmuf" and t.get("Environment") != 7:
                    continue
                key = ("u" if site == "tmuf" else "") + str(t["TrackId"])
                if key in seen:
                    continue
                seen.add(key)
                items.append({"id": key, "tmx": t["TrackId"], "site": site, "set": name, "name": t.get("TrackName", ""),
                              "author": (t.get("Uploader") or {}).get("Name", ""), "uploaded": t.get("UploadedAt", ""),
                              "awards": t.get("Awards", 0)})
            got += len(res)
            if not d.get("More") or not res:
                break
            after = res[-1]["TrackId"]
            time.sleep(0.3)
        print(f"tracks: {site} {name}: {len(items)} listed so far")
    with open(path, "w") as f:
        json.dump(items, f, indent=0)
    return items


def run_tracks(work, batch_size, keep, scale):
    items = tmx_catalogue(work, scale)
    res_path = os.path.join(work, "results_tracks.json")
    results = json.load(open(res_path)) if os.path.exists(res_path) else {}
    todo = [i for i in items if i["id"] not in results]
    print(f"tracks: {len(items)} listed, {len(results)} done, {len(todo)} to do")
    batch = os.path.join(work, "batch")
    for start in range(0, len(todo), batch_size):
        chunk = todo[start:start + batch_size]
        shutil.rmtree(batch, ignore_errors=True)
        os.makedirs(batch)
        meta = {}

        def fetch(it):
            time.sleep(0.15)          # two at a time, politely
            return get(f"{TMX[it['site']]}/trackgbx/{it['tmx']}")
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            fetched = list(pool.map(fetch, chunk))
        for it, (raw, _) in zip(chunk, fetched):
            m = {k: it[k] for k in ("id", "site", "name", "author", "uploaded", "awards")}
            m.update(bytes=len(raw) if raw else 0, sha256=hashlib.sha256(raw).hexdigest() if raw else "")
            if not raw or not raw.startswith(b"GBX"):
                m.update(ok=False, why="download failed" if not raw else "not a GBX file")
                results[it["id"]] = m
                continue
            fname = f"{it['id']}.Challenge.Gbx"
            with open(os.path.join(batch, fname), "wb") as f:
                f.write(raw)
            meta[fname] = m
        with open(os.path.join(batch, "index.json"), "w") as f:
            json.dump({}, f)
        got = godot_test("tracks", batch, os.path.join(work, "batch_results.json")) if meta else {}
        for fname, m in meta.items():
            r = got.get(fname)
            if r is None:
                m.update(ok=False, why="the test didn't report it (crashed?)")
            else:
                r = dict(r)
                r.pop("name", None)          # TMX's name (with its colour codes) stays
                m.update(r)
            results[m["id"]] = m
        if keep:
            os.makedirs(keep, exist_ok=True)
            for fname in meta:
                if os.path.exists(os.path.join(batch, fname)):
                    shutil.move(os.path.join(batch, fname), os.path.join(keep, fname))
        shutil.rmtree(batch, ignore_errors=True)
        with open(res_path, "w") as f:
            json.dump(results, f, indent=0)
        bad = sum(1 for r in results.values() if not r.get("ok"))
        print(f"tracks: {len(results)}/{len(items)} done, {bad} not ok")
    write_tsv("tracks", work)


def write_tsv(kind, work):
    results = json.load(open(os.path.join(work, f"results_{kind}.json")))
    out_dir = os.path.join(HERE, "results")
    os.makedirs(out_dir, exist_ok=True)
    cols = COLUMNS[kind]
    rows = sorted(results.values(), key=lambda r: (str(r.get("game", r.get("kind", r.get("site", "")))), str(r.get("name", "")).lower()))
    name = "tmx_tracks" if kind == "tracks" else f"maniapark_{kind}"
    with open(os.path.join(out_dir, f"{name}.tsv"), "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            vals = []
            for c in cols:
                v = r.get(c, "")
                if isinstance(v, bool):
                    v = "yes" if v else "no"
                vals.append(str(v).replace("\t", " ").replace("\n", " ").replace("\r", " "))
            f.write("\t".join(vals) + "\n")
    print(f"wrote {os.path.join(out_dir, name + '.tsv')} ({len(rows)} rows)")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if len(args) < 2 or args[0] not in ("mods", "cars", "tracks", "tsv"):
        print(__doc__)
        sys.exit(2)
    if args[0] == "tsv":
        write_tsv(args[2], args[1])
        return
    kind, work = args[0], args[1]
    os.makedirs(work, exist_ok=True)
    if kind == "tracks":
        run_tracks(work, int(opts.get("batch", 1000)), opts.get("keep", ""), float(opts.get("scale", 1.0)))
        return
    run(kind, work, int(opts.get("batch", 40 if kind == "mods" else 60)), opts.get("keep", ""), int(opts.get("limit", 0)))


if __name__ == "__main__":
    main()
