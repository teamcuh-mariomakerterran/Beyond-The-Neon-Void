"""Animate pool characters with PixelLab's skeleton templates and bring them in.

    python3 tools/pixellab/pool_anims.py 5                 # plan + cost (free)
    python3 tools/pixellab/pool_anims.py 5 9 19 --go       # animate, export, rig
    python3 tools/pixellab/pool_anims.py 5 --export-only   # re-download, no credits

Set per character (data below): walk, attack, hurt, death, jump, drawn in
all 4 battle diagonals; only characters that look the same flipped
(pool.json mirror_ok, Brian's rule) get SE + NE and are mirrored for SW and
NW by the game (LatticeClip.resolve). Idle
comes from the 8 still rotations, and cast falls back to attack. Animation
names carry the keywords PixelLab units use to pick actions
(src/vfx/pixel_lab.gd). Template mode costs about 1 generation per
direction under ~100 px canvases. Each character's spend is logged in
tools/pixellab/pool_runs.json. Afterwards the export goes to
assets/units/pool_<n>/ with rig.json (pool_rigs.py, free).
"""
import argparse
import io
import json
import os
import sys
import time
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot  # noqa: E402
import pool_rigs  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
# action name -> PixelLab template id (seen on Brian's own characters).
SET = {"walk": "walking", "attack": "cross-punch", "hurt": "taking-punch", "death": "falling-back-death", "jump": "two-footed-jump"}
DIAGONALS = ["south-east", "north-east", "south-west", "north-west"]
MIRRORED = ["south-east", "north-east"]
RUNS = os.path.join(HERE, "pool_runs.json")


def load_runs() -> dict:
	return json.load(open(RUNS, encoding="utf-8")) if os.path.exists(RUNS) else {"runs": {}}


def save_runs(r: dict) -> None:
	with open(RUNS, "w", encoding="utf-8") as f:
		json.dump(r, f, indent="\t")
		f.write("\n")


def directions_for(c: dict) -> list:
	"""All 4 battle diagonals, unless Brian's check says the character looks the
	same flipped (pool.json mirror_ok): then SE + NE, mirrored for SW + NW."""
	return MIRRORED if c.get("mirror_ok") else DIAGONALS


def animate(c: dict, runs: dict) -> None:
	"""Adds whatever is missing: whole animations, or facings of ones that
	exist (same animation group, so they move the same way)."""
	key = str(c["n"])
	done = runs["runs"].setdefault(key, {"anims": {}, "generations_used": 0.0})
	want = directions_for(c)
	have = {}
	for an in pilot.call("GET", "/characters/%s" % c["character_id"]).get("animations") or []:
		have.setdefault(an.get("animation_type"), (an.get("animation_group_id"), {d["direction"] for d in an.get("directions") or []}))
	before = pilot.generations()
	jobs = []
	for action, template in SET.items():
		group, dirs = have.get(template, (None, set()))
		missing = [d for d in want if d not in dirs]
		if not missing:
			continue
		req = {"character_id": c["character_id"], "mode": "template", "template_animation_id": template,
			"animation_name": action, "directions": missing}
		if group:
			req["animation_group_id"] = group
		r = pilot.call("POST", "/characters/animations", req)
		jobs.append((action, missing, r.get("background_job_ids") or []))
	for action, missing, ids in jobs:
		for j in ids:
			pilot.wait(j)
		prev = done["anims"].get(action, {}).get("directions", [])
		done["anims"][action] = {"template": SET[action], "directions": sorted(set(prev) | set(missing))}
	time.sleep(2)
	# PixelLab reports no per-job usage on a subscription, so this is the
	# balance drop; it also counts anything Brian generates meanwhile.
	drop = round(before - pilot.generations(), 2)
	done["generations_used"] = round(done["generations_used"] + drop, 2)
	done["at"] = time.strftime("%Y-%m-%d %H:%M")
	runs["total_generations_used"] = round(sum(v["generations_used"] for v in runs["runs"].values()), 2)
	save_runs(runs)
	print("#%d: %d jobs, %.2f generations (batch total %.2f)" % (c["n"], sum(len(m) for _, m, _ in jobs), drop, runs["total_generations_used"]))


def usage(r: dict) -> float:
	u = (r or {}).get("usage") or {}
	return float(u.get("generations") or 0)


def export(c: dict) -> None:
	out = os.path.join("assets", "units", "pool_%03d" % c["n"])
	os.makedirs(out, exist_ok=True)
	data = pilot.call("GET", "/characters/%s/zip" % c["character_id"], raw=True)
	zipfile.ZipFile(io.BytesIO(data))
	for f in os.listdir(out):
		if f.endswith(".zip"):
			os.remove(os.path.join(out, f))
	with open(os.path.join(out, "pool_%03d.zip" % c["n"]), "wb") as f:
		f.write(data)
	# The game unpacks once; clear the old unpack so new animations show.
	ext = os.path.join(out, "extracted")
	if os.path.isdir(ext):
		import shutil
		shutil.rmtree(ext)
	rig = pool_rigs.rig_from_detail(pilot.call("GET", "/characters/%s" % c["character_id"]))
	with open(os.path.join(out, "rig.json"), "w", encoding="utf-8") as f:
		json.dump(rig, f, indent="\t")
		f.write("\n")
	print("#%d -> %s" % (c["n"], out))


def main() -> None:
	p = argparse.ArgumentParser()
	p.add_argument("numbers", nargs="+", type=int)
	p.add_argument("--go", action="store_true")
	p.add_argument("--export-only", action="store_true")
	a = p.parse_args()
	pool = {c["n"]: c for c in json.load(open(os.path.join(HERE, "pool.json"), encoding="utf-8"))["characters"]}
	todo = [pool[n] for n in a.numbers if n in pool and pool[n]["status"] == "keep"]
	print("%d characters, ~%d generations at most (%d anims x 2 or 4 facings)" % (len(todo), sum(len(SET) * len(directions_for(c)) for c in todo), len(SET)))
	if not (a.go or a.export_only):
		return
	runs = load_runs()
	for c in todo:
		if a.go:
			animate(c, runs)
		export(c)


if __name__ == "__main__":
	main()
