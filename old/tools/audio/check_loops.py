"""Check that every looping .ogg is seamless after Vorbis encoding.

For each loop, decodes the file and compares the sample-to-sample jump across the wrap point
(last sample -> first sample) with the jumps inside the file. A click at the seam would show up
as a wrap jump far above the in-file distribution.

usage: python3 tools/audio/check_loops.py      (exit code 1 on failure)
"""
from __future__ import annotations

import glob
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from fix_loops import GEN, is_loop  # noqa: E402


def decode(path: str) -> np.ndarray:
	out = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "f32le", "-"], capture_output=True, check=True).stdout
	ch = 2 if os.path.basename(path).startswith("music_") else 1
	return np.frombuffer(out, dtype="<f4").reshape(-1, ch).astype(float)


def main() -> int:
	bad = 0
	for path in sorted(glob.glob(os.path.join(GEN, "*.ogg"))):
		name = os.path.basename(path)
		if not is_loop(name):
			continue
		x = decode(path)
		d = np.abs(np.diff(x, axis=0))
		p999 = np.percentile(d, 99.9, axis=0)
		dmax = d.max(axis=0)
		wrap = np.abs(x[0] - x[-1])
		ok = bool(np.all(wrap <= np.maximum(p999 * 1.5, 1e-3)))
		print(f"{'OK  ' if ok else 'FAIL'} {name:24s} {x.shape[0] / 44100:6.2f}s wrap={np.max(wrap):.4f} p99.9={np.max(p999):.4f} max={np.max(dmax):.4f}")
		bad += 0 if ok else 1
	print(f"LOOP_CHECK_FAILURES={bad}")
	return 1 if bad else 0


if __name__ == "__main__":
	sys.exit(main())
