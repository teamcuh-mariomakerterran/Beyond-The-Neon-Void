"""Redo ONE animation facing of a pool character in skeleton-v3 (the method
that keeps outfits; cast audit 2026-11-07), then re-export and pin it.

    python3 -I tools/pixellab/redo_facing.py <n> <action> <SE|SW|NE|NW> [--group <id>] --go
    python3 -I tools/pixellab/redo_facing.py 0 <action> <facing> --id <character_id> --zip <out.zip> --go
      (any character by id, e.g. the modular base bodies: animate, then save its export)

action: walk, attack, hurt, death, jump. --group adds the facing to an
existing take (the other facing of the same redo) so they stay together.
Without --go it only prints the plan. About 3 generations a facing. Every
step needs Brian's go (CLAUDE.md); one facing per run, no loops.
The new take is pinned by group id (pixellab.json pins_by_group) and logged
in pool_runs.json redo_log with the balance drop.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot  # noqa: E402
import pool_anims  # noqa: E402

FACING = {"SE": "south-east", "SW": "south-west", "NE": "north-east", "NW": "north-west"}


def main() -> None:
	a = sys.argv[1:]
	n, action, facing = int(a[0]), a[1], a[2]
	group = a[a.index("--group") + 1] if "--group" in a else None
	if "--id" in a:
		c = {"n": 0, "character_id": a[a.index("--id") + 1]}
	else:
		pool = {c["n"]: c for c in json.load(open(os.path.join(pool_anims.HERE, "pool.json"), encoding="utf-8"))["characters"]}
		c = pool[n]
	template = pool_anims.SET[action]
	print("#%d %s %s: skeleton-v3, template %s, ~3 generations%s" % (n, action, facing, template, " (into group %s)" % group[:8] if group else ""))
	if "--go" not in a:
		return
	before = pilot.generations()
	body = {"character_id": c["character_id"], "mode": "skeleton-v3", "template_animation_id": template,
		"animation_name": action, "directions": [FACING[facing]]}
	if group:
		body["animation_group_id"] = group
	r = pilot.call("POST", "/characters/animations", body)
	gid = r.get("animation_group_id") or sys.exit("no group: %s" % str(r)[:300])
	for j in r.get("background_job_ids") or []:
		pilot.wait(j)
	time.sleep(3)
	used = round(before - pilot.generations(), 2)
	if "--id" in a:
		data = pilot.call("GET", "/characters/%s/zip" % c["character_id"], raw=True)
		out = a[a.index("--zip") + 1]
		open(out, "wb").write(data)
		json.dump(pilot.call("GET", "/characters/%s" % c["character_id"]), open(out[:-4] + "_detail.json", "w"), indent="\t")
		print("group", gid, "saved", out, "balance drop", used)
		return
	# Pin the new take for this facing, then export (free) so the game has it.
	conf_p = os.path.join("assets", "units", "pool_%03d" % n, "pixellab.json")
	conf = json.load(open(conf_p, encoding="utf-8")) if os.path.exists(conf_p) else {}
	conf.setdefault("pins_by_group", {})["%s_%s" % (pool_anims.GAME_ACTION[action], facing)] = gid
	with open(conf_p, "w", encoding="utf-8") as f:
		json.dump(conf, f, indent="\t")
		f.write("\n")
	pool_anims.export(c)
	runs = pool_anims.load_runs()
	runs.setdefault("redo_log", []).append({"at": time.strftime("%Y-%m-%d"), "n": n, "what": "%s %s" % (action, facing),
		"method": "skeleton-v3", "group": gid, "generations": used, "verdict": "pending review"})
	pool_anims.save_runs(runs)
	print("group", gid, "balance drop", used)


if __name__ == "__main__":
	main()
