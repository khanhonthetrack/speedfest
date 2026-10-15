"""Set loop=true in the .import files of every looping sound (engine/car loops and music).

Run after Godot has created the .import files (tools/godot_import.sh), then import again.
"""
from __future__ import annotations

import glob
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.abspath(os.path.join(HERE, "..", "..", "game", "audio", "generated"))

IMPORTED = os.path.abspath(os.path.join(GEN, "..", "..", ".godot", "imported"))

LOOP_PREFIXES = ("eng_", "music_", "amb_", "car_turbo", "car_nitro.", "car_squeal", "car_wind")


def is_loop(name: str) -> bool:
	return name.startswith(LOOP_PREFIXES)


def main() -> None:
	changed = 0
	for imp in sorted(glob.glob(os.path.join(GEN, "*.ogg.import"))):
		name = os.path.basename(imp)[: -len(".import")]
		want = "true" if is_loop(name) else "false"
		s = open(imp).read()
		s2 = re.sub(r"^loop=(true|false)$", f"loop={want}", s, flags=re.M)
		if s2 != s:
			open(imp, "w").write(s2)
			changed += 1
			# Godot does not notice a params-only change: drop the cached import to force it
			for f in glob.glob(os.path.join(IMPORTED, name + "-*")):
				os.remove(f)
	print(f"fix_loops: {changed} .import files updated")


if __name__ == "__main__":
	main()
