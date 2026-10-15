#!/usr/bin/env python3
"""Fetch SpeedFest's PBR texture sets from ambientCG (CC0) and convert them to the game's layout.

Writes seamless maps to game/assets/textures/<name>/ (1K, shipped everywhere, incl. web) and,
with --hd, to game/assets/hd/textures/<name>/ (2K, desktop only; the Web preset excludes
assets/hd/*):
  <name>_albedo.jpg   sRGB base color
  <name>_normal.png   tangent-space normal map (OpenGL / Godot convention, +Y up: ambientCG NormalGL;
                      .jpg for the 2K sets: the scans are JPEG anyway and PNG would triple the size)
  <name>_rough.jpg    roughness (grayscale)

Calibration: the materials were tuned against the generated sets (tools/textures/gen_textures.py,
kept as the offline fallback), so each albedo is scaled per channel to the same mean color and
each roughness map to the same mean. The scans bring the detail, the look stays as tuned.
Fine scans (asphalt, metal) read flat at driving distance, so their albedo contrast and normal
strength are boosted to at least the generated sets' level.

usage: python3 tools/textures/fetch_cc0.py [--hd] [name ...]     (then tools/godot_import.sh)
needs: numpy, Pillow, network access to ambientcg.com
"""
import argparse
import io
import os
import urllib.request
import zipfile

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# name -> (ambientCG asset id, target albedo mean RGB, target roughness mean,
#          albedo contrast factor, normal strength factor)
SETS = {
    "asphalt": ("Asphalt031", (0.289, 0.287, 0.289), 0.833, 1.6, 2.0),
    "concrete": ("Concrete034", (0.710, 0.706, 0.690), 0.854, 1.0, 1.0),
    "metal": ("Metal038", (0.376, 0.380, 0.400), 0.417, 2.0, 2.5),
    "rock": ("Rock022", (0.651, 0.600, 0.541), 0.875, 1.0, 1.0),
}


def fetch(asset, res):
    url = "https://ambientcg.com/get?file=%s_%s-JPG.zip" % (asset, res)
    req = urllib.request.Request(url, headers={"User-Agent": "speedfest-texture-fetch"})
    with urllib.request.urlopen(req, timeout=120) as r:
        z = zipfile.ZipFile(io.BytesIO(r.read()))
    def img(suffix):
        name = "%s_%s-JPG_%s.jpg" % (asset, res, suffix)
        return Image.open(io.BytesIO(z.read(name)))
    return img("Color"), img("NormalGL"), img("Roughness")


def calibrate_albedo(im, target, contrast):
    a = np.asarray(im.convert("RGB"), dtype=np.float64) / 255.0
    mean = a.reshape(-1, 3).mean(0)
    a = mean + (a - mean) * contrast
    a *= np.asarray(target) / np.maximum(mean, 1e-4)
    return Image.fromarray((np.clip(a, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8))


def scale_normal(im, strength):
    n = np.asarray(im.convert("RGB"), dtype=np.float64) / 255.0 * 2.0 - 1.0
    xy = n[..., :2] * strength
    xy /= np.maximum(np.linalg.norm(xy, axis=-1, keepdims=True), 1.0)
    z = np.sqrt(np.clip(1.0 - np.sum(xy * xy, axis=-1, keepdims=True), 0.0, 1.0))
    n = np.concatenate([xy, z], axis=-1)
    return Image.fromarray(((n * 0.5 + 0.5) * 255.0 + 0.5).astype(np.uint8))


def calibrate_rough(im, target):
    r = np.asarray(im.convert("L"), dtype=np.float64) / 255.0
    r *= target / max(r.mean(), 1e-4)
    return Image.fromarray((np.clip(r, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8))


def build(name, res, size, out_dir, normal_ext):
    asset, alb_mean, rough_mean, contrast, strength = SETS[name]
    color, normal, rough = fetch(asset, res)
    d = os.path.join(out_dir, name)
    os.makedirs(d, exist_ok=True)
    fit = lambda im: im if im.size == (size, size) else im.resize((size, size), Image.LANCZOS)
    calibrate_albedo(fit(color), alb_mean, contrast).save(os.path.join(d, name + "_albedo.jpg"), quality=90)
    nrm = fit(normal.convert("RGB"))
    if strength != 1.0:
        nrm = scale_normal(nrm, strength)
    if normal_ext == "png":
        nrm.save(os.path.join(d, name + "_normal.png"), optimize=True)
    else:
        nrm.save(os.path.join(d, name + "_normal.jpg"), quality=95)
    calibrate_rough(fit(rough), rough_mean).save(os.path.join(d, name + "_rough.jpg"), quality=90)
    print("%-9s %s %s -> %s" % (name, asset, res, os.path.relpath(d, ROOT)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*", default=list(SETS))
    ap.add_argument("--hd", action="store_true", help="also write the 2K desktop sets to assets/hd/")
    args = ap.parse_args()
    for name in args.names:
        build(name, "1K", 1024, os.path.join(ROOT, "game", "assets", "textures"), "png")
        if args.hd:
            build(name, "2K", 2048, os.path.join(ROOT, "game", "assets", "hd", "textures"), "jpg")


if __name__ == "__main__":
    main()
