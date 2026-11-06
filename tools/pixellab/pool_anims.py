"""Animate pool characters with PixelLab's skeleton templates and bring them in.

    python3 tools/pixellab/pool_anims.py 5                 # plan + cost (free)
    python3 tools/pixellab/pool_anims.py 5 9 19 --go       # animate, export, rig
    python3 tools/pixellab/pool_anims.py 5 --export-only   # re-download, no credits

Set per character (data below): walk, attack, hurt, death, jump, drawn in
all 4 battle diagonals (front facings by template, back facings by
skeleton-v3, which keeps the character's look); only characters that look the same flipped
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
import threading
import time
from concurrent.futures import ThreadPoolExecutor
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot  # noqa: E402
import pool_rigs  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
# action name -> PixelLab template id (seen on Brian's own characters).
SET = {"walk": "walking", "attack": "cross-punch", "hurt": "taking-punch", "death": "falling-back-death", "jump": "two-footed-jump"}
# Brian's pick B (2026-11-06): templates on the front facings, which keep the
# character; skeleton-v3 on the back ones, where templates fell back to a
# plain mannequin (docs/screenshots/pool_template_vs_skeleton.png).
FRONT = ["south-east", "south-west"]
BACK = ["north-east", "north-west"]
RUNS = os.path.join(HERE, "pool_runs.json")


def load_runs() -> dict:
	return json.load(open(RUNS, encoding="utf-8")) if os.path.exists(RUNS) else {"runs": {}}


def save_runs(r: dict) -> None:
	with open(RUNS, "w", encoding="utf-8") as f:
		json.dump(r, f, indent="\t")
		f.write("\n")


def directions_for(c: dict) -> tuple:
	"""(template facings, skeleton-v3 facings). Characters that look the same
	flipped (pool.json mirror_ok) draw one of each and are mirrored."""
	if c.get("mirror_ok"):
		return FRONT[:1], BACK[:1]
	return FRONT, BACK


LOCK = threading.Lock()


def animate(c: dict, runs: dict) -> None:
	"""Adds whatever is missing and never deletes (Brian keeps every take as a
	kit). Front facings: template, in the action's existing group. Back
	facings: skeleton-v3 in a group of their own, recorded in pool_runs.json
	so the export can pin them (pixellab.json) over any older take."""
	key = str(c["n"])
	with LOCK:
		done = runs["runs"].setdefault(key, {"anims": {}, "generations_used": 0.0})
	front, back = directions_for(c)
	have = {}
	for an in pilot.call("GET", "/characters/%s" % c["character_id"]).get("animations") or []:
		g = have.setdefault(an.get("animation_type"), {})
		g[an.get("animation_group_id")] = {d["direction"] for d in an.get("directions") or []}
	waits = []
	n_jobs = 0
	for action, template in SET.items():
		with LOCK:
			rec = done["anims"].setdefault(action, {"template": template, "directions": []})
		v3_groups: dict = rec.setdefault("v3_groups", {})
		v3_dirs = {d for ds in v3_groups.values() for d in ds} | set(rec.get("skeleton_v3", []))
		groups = have.get(template, {})
		front_have = {d for gid, ds in groups.items() if gid not in v3_groups for d in ds}
		front_group = next((gid for gid in groups if gid not in v3_groups), None)
		todo_front = [d for d in front if d not in front_have]
		todo_back = [d for d in back if d not in v3_dirs]
		if todo_front:
			req = {"character_id": c["character_id"], "mode": "template", "template_animation_id": template,
				"animation_name": action, "directions": todo_front}
			if front_group:
				req["animation_group_id"] = front_group
			r = pilot.call("POST", "/characters/animations", req, allow=(409,))
			if r.get("_status") == 409:
				print("#%d %s: front facing already there or generating, skipped" % (c["n"], action), flush=True)
			else:
				waits += [(j, None, None) for j in r.get("background_job_ids") or []]
				n_jobs += len(todo_front)
		if todo_back:
			r = pilot.call("POST", "/characters/animations", {"character_id": c["character_id"], "mode": "skeleton-v3",
				"template_animation_id": template, "animation_name": action, "directions": todo_back})
			gid = r.get("animation_group_id") or "unknown"
			v3_groups[gid] = todo_back
			# one job per direction, in request order: a failure un-records it
			waits += [(j, v3_groups[gid], d) for j, d in zip(r.get("background_job_ids") or [], list(todo_back))]
			n_jobs += len(todo_back)
		rec["directions"] = sorted(set(rec["directions"]) | set(front) | set(back))
		with LOCK:
			save_runs(runs)
	for j, rec_dirs, d in waits:
		res = pilot.wait(j, limit=3600, fatal=False)
		if res.get("status") == "failed":
			n_jobs -= 1
			if rec_dirs is not None and d in rec_dirs:
				rec_dirs.remove(d)  # skeleton-v3 facing: redo it next pass
			print("#%d: a job failed on PixelLab's side; the next pass retries it" % c["n"], flush=True)
	with LOCK:
		done["at"] = time.strftime("%Y-%m-%d %H:%M")
		done["facings_made"] = done.get("facings_made", 0) + n_jobs
		save_runs(runs)
	print("#%d: %d facings made" % (c["n"], n_jobs), flush=True)


# Folder name PixelLab's export gives each template (seen in exports).
FOLDER = {"walking": "walking", "cross-punch": "cross_punch_attack", "taking-punch": "taking_a_punch",
	"falling-back-death": "falling_backward", "two-footed-jump": "two_footed_jump"}
GAME_ACTION = {"walk": "walk", "attack": "attack", "hurt": "hit", "death": "death", "jump": "jump"}


def pin_back_facings(c: dict, runs: dict, out: str, data: bytes) -> None:
	"""pixellab.json: back facings come from the skeleton-v3 takes. Of two
	same-named animations the export suffixes one "<name>-<group id prefix>";
	a suffix matching a v3 group marks that take, a suffix matching any other
	group marks the unsuffixed folder as the v3 take."""
	rec = runs["runs"].get(str(c["n"]), {}).get("anims", {})
	z = zipfile.ZipFile(io.BytesIO(data))
	meta = json.loads(z.read([n for n in z.namelist() if n.endswith("metadata.json")][0]))
	pins = {}
	for stt in meta.get("states", []):
		state = stt.get("folder", "")
		anims = (stt.get("frames") or {}).get("animations") or {}
		for action, r in rec.items():
			groups = r.get("v3_groups", {})
			if not groups:
				continue
			base = FOLDER.get(r.get("template", SET.get(action, "")), "")
			cands = [f for f in anims if f.partition("-")[0] == base]
			if len(cands) < 2:
				continue  # one take only: nothing to choose
			for gid, dirs in groups.items():
				pick = next((f for f in cands if f.partition("-")[2] and gid.startswith(f.partition("-")[2])), None)
				if pick is None:
					plain = [f for f in cands if not f.partition("-")[2]]
					pick = plain[0] if len(plain) == 1 else None
				if pick is None:
					print("#%d %s: couldn't tell which take is skeleton-v3; no pin" % (c["n"], action))
					continue
				for d in dirs:
					if d in anims[pick]:
						pins["%s_%s" % (GAME_ACTION[action], pilot.DIRS[d])] = "%s/%s" % (state, pick)
	conf_p = os.path.join(out, "pixellab.json")
	conf = json.load(open(conf_p, encoding="utf-8")) if os.path.exists(conf_p) else {}
	conf["actions"] = pins
	conf["_about"] = "Back facings pinned to the skeleton-v3 takes (tools/pixellab/pool_anims.py); older takes stay in the export as a kit."
	with open(conf_p, "w", encoding="utf-8") as f:
		json.dump(conf, f, indent="\t")
		f.write("\n")


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
	pin_back_facings(c, load_runs(), out, data)
	print("#%d -> %s" % (c["n"], out))


def main() -> None:
	p = argparse.ArgumentParser()
	p.add_argument("numbers", nargs="+", type=int)
	p.add_argument("--go", action="store_true")
	p.add_argument("--export-only", action="store_true")
	p.add_argument("--parallel", type=int, default=4)
	a = p.parse_args()
	pool = {c["n"]: c for c in json.load(open(os.path.join(HERE, "pool.json"), encoding="utf-8"))["characters"]}
	todo = [pool[n] for n in a.numbers if n in pool and pool[n]["status"] == "keep"]
	est = sum(len(SET) * (len(directions_for(c)[0]) + 3 * len(directions_for(c)[1])) for c in todo)
	print("%d characters, ~%d generations at most (templates 1 a facing, skeleton-v3 about 3)" % (len(todo), est))
	if not (a.go or a.export_only):
		return
	runs = load_runs()
	if a.go:
		# Several characters at once (PixelLab runs jobs in parallel); spend is
		# the balance drop over the whole run, since jobs report no usage.
		before = pilot.generations()
		with ThreadPoolExecutor(a.parallel) as ex:
			list(ex.map(lambda c: animate(c, runs), todo))
		time.sleep(3)
		drop = round(before - pilot.generations(), 2)
		runs.setdefault("batches", []).append({"at": time.strftime("%Y-%m-%d %H:%M"), "characters": [c["n"] for c in todo], "generations_used": drop})
		runs["total_generations_used"] = round(sum(b["generations_used"] for b in runs["batches"]) + sum(v.get("generations_used", 0) for v in runs["runs"].values()), 2)
		save_runs(runs)
		print("batch: %.2f generations (balance drop; includes anything else spent meanwhile)" % drop, flush=True)
	for c in todo:
		export(c)


if __name__ == "__main__":
	main()
