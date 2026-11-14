"""Pose regression check: run before any paid batch. Free (reads stored skeletons only).

    python3 -I tools/pixellab/check_poses.py          # exit 1 if any approved pose moved

Rebuilds every clip's pose for the units Brian approved and compares it to the
pose saved next to their frames (aim.json). Any joint that moved more than
0.05 px means the pose code changed under approved work: stop and ask Brian
before generating anything (2026-11-14: a back-view change silently moved the
front rifle poses and the 8 new outfits lost their far arm).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import aim_pose  # noqa: E402
import pilot  # noqa: E402

SRC = os.path.join("assets", "units", "base_male_hi", "source")
# Approved units (id of the PixelLab state their clips were made from).
APPROVED = {
	"medic_buns": "d6e61da6-47db-40f7-892a-f0b9517a1212",
	"slicked20": "d99b6aeb-f70d-479f-8b5d-945e0590e801",
	"heavy40": "74b6e043-b79b-4435-a7f7-5e3a863585e9",
}
# Approved takes made before a deliberate fix, so they differ from the current poses on purpose.
KNOWN = {("medic_buns", "pistol", "SE"): "first pistol test (11-12 15:10), before the arm-length fix; approved as drawn"}
# Front rifle rest/raise: the support arm was moved out past the body's edge on purpose
# (Brian 2026-11-14, the far arm hid behind the torso); these takes are due to be redone.
for _u in ("medic_buns", "slicked20", "heavy40"):
	for _c in ("rifle_rest", "rifle_raise"):
		for _f in ("SE", "SW"):
			KNOWN[(_u, _c, _f)] = "front rifle far-arm fix (Brian 2026-11-14), to be redone"
CLIPS = ["walk2", "hit", "death", "jump", "use_item", "throw", "pistol", "rifle_rest", "rifle_raise"]
TOL = 0.05


def main() -> int:
	bad = 0
	for unit, cid in APPROVED.items():
		d = pilot.call("GET", "/characters/%s" % cid)
		w, h = int(d["size"]["width"]), int(d["size"]["height"])
		for F in ("SE", "SW", "NE", "NW"):
			kp = d["skeletons"]["2d_references"][aim_pose.DIRS[F]]["keypoints"]
			base = {k: (v["x"] * (w - 1), v["y"] * (h - 1) + (w - h) / 2.0) for k, v in kp.items()}
			for clip in CLIPS:
				p = os.path.join(SRC, "%s_%s_%s" % (unit, clip, F), "aim.json")
				if not os.path.exists(p):
					continue
				meta = json.load(open(p))
				saved = meta["joints"]
				if clip == "pistol" and F == "NW":
					aim_pose.AIM_NUDGE["NW"] = (-9.0, 3.0) if unit == "dragoon" else (-7.0, 3.0)
				mine = aim_pose.poses(base, w, F, clip)
				diff = max((abs(mine[i][k][j] - saved[i][k][j]) for i in range(min(len(mine), len(saved)))
					for k in saved[i] if k in mine[i] for j in (0, 1)), default=0.0)
				if (unit, clip, F) in KNOWN:
					continue
				if len(mine) != len(saved) or diff > TOL:
					bad += 1
					print("MOVED %s %s %s: %.2f px (frames %d vs %d saved)" % (unit, clip, F, diff, len(mine), len(saved)))
	print("pose check:", "OK, every approved pose unchanged" if not bad else "%d approved poses moved" % bad)
	return 1 if bad else 0


if __name__ == "__main__":
	sys.exit(main())
