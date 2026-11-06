"""Bring pool characters into the game with free rig points.

    python3 tools/pixellab/pool_rigs.py 5 12 40        # these sheet numbers
    python3 tools/pixellab/pool_rigs.py --focus        # every focus character in pool.json
    python3 tools/pixellab/pool_rigs.py 5 --rig-only   # rewrite rig.json, keep the art

For each one it downloads the PixelLab export ZIP into assets/units/pool_<n>/
(the game unpacks it; see src/vfx/pixel_lab.gd) and writes rig.json from the
2D skeletons PixelLab keeps for all 8 rotations (GET /characters/{id},
`skeletons.2d_references`). Both calls are free. Points go in as each
facing's still pose (rig "facing" defaults), which every animation frame
without its own points falls back to. Per-frame points for animations come
from tools/pixellab/skeleton_rig.py (0.1 generation a frame).

PixelLab's "RIGHT ARM" / "LEFT ARM" are the wrists. z (in front of / behind
the body) follows GearAttach.RIGHT_HAND_FRONT; the far hand gets the opposite.
Set PIXELLAB_API_KEY (or PIXELLAB_API_KEY=proxy-injected when the session's
proxy holds the key).
"""
import argparse
import io
import json
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot  # noqa: E402

DIRS = pilot.DIRS
POINTS = {"hand_r": "RIGHT ARM", "hand_l": "LEFT ARM", "elbow_r": "RIGHT ELBOW", "elbow_l": "LEFT ELBOW", "head": "NOSE"}
# Mirrors GearAttach.RIGHT_HAND_FRONT (src/vfx/gear_attach.gd).
RIGHT_HAND_FRONT = {"S": 1, "SE": 1, "E": 1, "NE": 1, "N": -1, "NW": -1, "W": -1, "SW": -1}
POOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pool.json")


def rig_from_detail(detail: dict) -> dict:
	w = int(detail["size"]["width"])
	h = int(detail["size"]["height"])
	refs = (detail.get("skeletons") or {}).get("2d_references") or {}
	pts = {k: {"facing": {}, "anims": {}} for k in POINTS}
	for d, ref in refs.items():
		facing = DIRS.get(d)
		kp = ref.get("keypoints") or {}
		if not facing:
			continue
		zr = RIGHT_HAND_FRONT[facing]
		for name, label in POINTS.items():
			k = kp.get(label)
			if not k:
				continue
			z = zr if name.endswith("_r") else (-zr if name.endswith("_l") else 1)
			pts[name]["facing"][facing] = [int(round(k["x"] * (w - 1))), int(round(k["y"] * (h - 1))), z]
	return {"source": "PixelLab 2D skeletons (rotations), tools/pixellab/pool_rigs.py", "cell": w, "points": pts}


def main() -> None:
	p = argparse.ArgumentParser()
	p.add_argument("numbers", nargs="*", type=int)
	p.add_argument("--focus", action="store_true")
	p.add_argument("--rig-only", action="store_true")
	a = p.parse_args()
	pool = {c["n"]: c for c in json.load(open(POOL, encoding="utf-8"))["characters"]}
	todo = [n for n, c in pool.items() if c["focus"]] if a.focus else a.numbers
	for n in todo:
		c = pool.get(n)
		if not c or c["status"] != "keep":
			print("#%d: not kept, skipped" % n)
			continue
		out = os.path.join("assets", "units", "pool_%03d" % n)
		os.makedirs(out, exist_ok=True)
		if not a.rig_only:
			data = pilot.call("GET", "/characters/%s/zip" % c["character_id"], raw=True)
			zipfile.ZipFile(io.BytesIO(data))  # refuses a broken download
			with open(os.path.join(out, "pool_%03d.zip" % n), "wb") as f:
				f.write(data)
		rig = rig_from_detail(pilot.call("GET", "/characters/%s" % c["character_id"]))
		with open(os.path.join(out, "rig.json"), "w", encoding="utf-8") as f:
			json.dump(rig, f, indent="\t")
			f.write("\n")
		print("#%d -> %s (%d facings)" % (n, out, len(rig["points"]["hand_r"]["facing"])))


if __name__ == "__main__":
	main()
