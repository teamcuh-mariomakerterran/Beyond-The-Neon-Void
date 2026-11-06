"""PixelLab pilot for the modular character system: one base body, one
animation in 8 directions, one armour layer, one weapon.

    python3 tools/pixellab/pilot.py plan                 # what it would do + cost estimate (free)
    python3 tools/pixellab/pilot.py balance              # generations left (free)
    python3 tools/pixellab/pilot.py body    --go         # base body, 8 rotations
    python3 tools/pixellab/pilot.py animate --go         # walk on all 8 directions (skeleton template)
    python3 tools/pixellab/pilot.py armor   --go         # armour layer from transfer-outfit, per direction
    python3 tools/pixellab/pilot.py weapon  --go         # one weapon picture (optional; placeholder art is free)
    python3 tools/pixellab/pilot.py export               # zip -> PixelMatrix folder (free)
    python3 tools/pixellab/pilot.py layers               # armour frames -> limb layer strips (free)
    python3 tools/pixellab/pilot.py state   --go [--dirs SW,NE,...]  # cheaper armour: dressed state + same walk template
    python3 tools/pixellab/pilot.py state_layers [--dirs ...]          # dressed state walk -> vest layers (free)

Nothing that spends credits runs without --go. Every paid step logs the
balance before and after into <out>/pilot.json, so the credit cost is known
exactly. Reads PIXELLAB_API_KEY from the environment (never printed).

Endpoints are the v2 API as documented at https://api.pixellab.ai/v2/llms.txt
(checked 2026-11-05): /balance, /create-character-v3, /characters/animations
(mode "template" = skeleton-driven, so every body moves through the same
poses), /background-jobs/{id}, /characters/{id}/zip, /transfer-outfit-v2,
/create-image-pixflux.

Output: assets/units/base_body_a/ in PixelMatrix layout (<anim>/<FACING>.png
strips, pm.json) and assets/gear/armor/pilot_vest/<anim>/<FACING>_Torso.png,
which PixelMatrix stacks over the body per facing. Run
tools/rig/make_rig.gd on the body afterwards for weapon hand points.
"""
import argparse
import base64
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request
import zipfile

API = "https://api.pixellab.ai/v2"
DIRS = {"south": "S", "south-east": "SE", "east": "E", "north-east": "NE",
	"north": "N", "north-west": "NW", "west": "W", "south-west": "SW"}
BODY_PROMPT = ("plain androgynous human base body, grey bodysuit, bald, no hair, "
	"empty hands, neutral standing pose, isometric 2:1 perspective, black 1 pixel outline")
ARMOR_PROMPT = "dark armoured tactical vest with neon magenta trim, cyberpunk, pixel art"
WEAPON_PROMPT = "cyberpunk katana with cyan neon edge, held by the grip, pixel art, transparent background"
SIZE = 64

# Generations per step, from the endpoint docs (estimates for the plan).
COST = {
	"body": 1 + (SIZE * SIZE * 8 + 65535) // 65536,  # pixen sprite + v3 rotations
	"animate": 8,                                     # template mode: 1 / direction
	"armor": 8 + 1,                                   # ~1 per direction (<=15 frames at 64 px) + reference image
	"weapon": 1,                                      # pixflux image
}


def key() -> str:
	k = os.environ.get("PIXELLAB_API_KEY", "").strip()
	if not k:
		sys.exit("PIXELLAB_API_KEY is not set: paid steps can't run (plan / export / layers still work).")
	return k


def call(method: str, path: str, body: dict = None, raw: bool = False, allow: tuple = ()):
	req = urllib.request.Request(API + path, method=method,
		data=json.dumps(body).encode() if body is not None else None,
		headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
	for attempt in range(60):
		try:
			with urllib.request.urlopen(req, timeout=120) as r:
				data = r.read()
			break
		except urllib.error.HTTPError as e:
			body = e.read()[:600].decode("utf-8", "replace")
			# All concurrent job slots busy: wait for some to finish.
			if e.code == 429 and attempt < 59:
				time.sleep(30)
				continue
			if e.code in allow:  # caller handles it (e.g. 409: that facing exists or is generating)
				return {"_status": e.code, "_detail": body}
			sys.exit("%s %s -> %d %s" % (method, path, e.code, body))
	return data if raw else json.loads(data)


def generations() -> float:
	b = call("GET", "/balance")
	sub = b.get("subscription") or {}
	return float(sub.get("generations") or 0)


def wait(job_id: str, every: int = 8, limit: int = 1800) -> dict:
	t = 0
	while t < limit:
		j = call("GET", "/background-jobs/" + job_id)
		st = j.get("status")
		if st == "completed":
			return j
		if st == "failed":
			sys.exit("job %s failed: %s" % (job_id, json.dumps(j.get("last_response"))[:600]))
		time.sleep(every)
		t += every
	sys.exit("job %s still running after %ds; re-run the step later" % (job_id, limit))


def b64(img_bytes: bytes) -> dict:
	return {"type": "base64", "base64": base64.b64encode(img_bytes).decode(), "format": "png"}


class State:
	def __init__(self, out: str):
		self.path = os.path.join(out, "pilot.json")
		self.d = json.load(open(self.path, encoding="utf-8")) if os.path.exists(self.path) else {"steps": {}}

	def save(self) -> None:
		os.makedirs(os.path.dirname(self.path), exist_ok=True)
		with open(self.path, "w", encoding="utf-8") as f:
			json.dump(self.d, f, indent="\t")
			f.write("\n")

	def log(self, step: str, before: float, after: float, extra: dict) -> None:
		self.d["steps"][step] = dict(extra, generations_used=round(before - after, 2), at=time.strftime("%Y-%m-%d %H:%M"))
		self.d["total_generations_used"] = round(sum(s.get("generations_used", 0) for s in self.d["steps"].values()), 2)
		self.save()
		print("%s: used %.2f generations (pilot total %.2f)" % (step, before - after, self.d["total_generations_used"]))


def step_body(st: State, a) -> None:
	before = generations()
	r = call("POST", "/create-character-v3", {"description": a.body_prompt, "image_size": {"width": SIZE, "height": SIZE},
		"view": "high top-down", "n_directions": 8, "template_id": "mannequin", "no_background": True, "seed": a.seed})
	wait(r["background_job_id"])
	st.d["character_id"] = r["character_id"]
	st.log("body", before, generations(), {"character_id": r["character_id"]})


def step_animate(st: State, a) -> None:
	cid = st.d.get("character_id") or sys.exit("run `body` first")
	before = generations()
	req = {"character_id": cid, "mode": a.mode, "template_animation_id": a.template, "animation_name": "walk",
		"directions": list(DIRS.keys()), "seed": a.seed}
	r = call("POST", "/characters/animations", req)
	jobs = r.get("background_job_ids") or ([r["background_job_id"]] if r.get("background_job_id") else [])
	for j in jobs:
		wait(j)
	st.d["animation_group_id"] = r.get("animation_group_id", "")
	st.log("animate", before, generations(), {"template": a.template, "mode": a.mode, "jobs": len(jobs)})


def fetch_zip(st: State) -> zipfile.ZipFile:
	cid = st.d.get("character_id") or sys.exit("run `body` first")
	return zipfile.ZipFile(io.BytesIO(call("GET", "/characters/%s/zip" % cid, raw=True)))


def walk_frames(z: zipfile.ZipFile, state: str = "") -> dict:
	"""{direction: [png bytes per frame]} for the walk in the zip. A state's
	zip holds the whole group (the base body's folder too), so `state` picks
	one state's folder; empty takes the first folder found."""
	out = {}
	names = sorted(z.namelist())
	if not state:
		first = next((n for n in names if "/animations/" in n and n.endswith(".png")), "")
		state = first.split("/")[0] if "/" in first else ""
	for n in names:
		parts = n.split("/")
		if parts[0] == state and "animations" in parts and n.endswith(".png"):
			d = parts[-2]
			if d in DIRS:
				out.setdefault(d, []).append(z.read(n))
	return out


def step_export(st: State, a) -> None:
	from PIL import Image
	z = zipfile.ZipFile(a.zip) if a.zip else fetch_zip(st)
	frames = walk_frames(z)
	if not frames:
		sys.exit("no animation frames in the zip")
	os.makedirs(os.path.join(a.out, "walk"), exist_ok=True)
	for d, pngs in frames.items():
		ims = [Image.open(io.BytesIO(p)).convert("RGBA") for p in pngs]
		w, h = ims[0].size
		strip = Image.new("RGBA", (w * len(ims), h))
		for i, im in enumerate(ims):
			strip.paste(im, (i * w, 0))
		strip.save(os.path.join(a.out, "walk", DIRS[d] + ".png"))
	# The first walk frame stands in as idle until the idle is animated.
	os.makedirs(os.path.join(a.out, "idle"), exist_ok=True)
	for d, pngs in frames.items():
		Image.open(io.BytesIO(pngs[0])).convert("RGBA").save(os.path.join(a.out, "idle", DIRS[d] + ".png"))
	meta = metadata_keypoints(z)
	with open(os.path.join(a.out, "pm.json"), "w", encoding="utf-8") as f:
		json.dump({"fps": 10, "scale_note": "PixelLab base body, %dpx" % SIZE}, f, indent="\t")
		f.write("\n")
	if meta:
		with open(os.path.join(a.out, "keypoints.json"), "w", encoding="utf-8") as f:
			json.dump(meta, f, indent="\t")
	print("exported %d directions to %s%s" % (len(frames), a.out, " (+ keypoints)" if meta else ""))


def metadata_keypoints(z: zipfile.ZipFile) -> dict:
	"""Whatever keypoint data the export's metadata.json carries (kept raw)."""
	for n in z.namelist():
		if n.endswith("metadata.json"):
			d = json.loads(z.read(n))
			s = json.dumps(d)
			if "keypoint" in s.lower():
				return d
	return {}


def step_armor(st: State, a) -> None:
	z = fetch_zip(st)
	frames = walk_frames(z)
	before = generations()
	if not st.d.get("armor_ref"):
		r = call("POST", "/create-image-pixflux", {"description": a.armor_prompt, "image_size": {"width": SIZE, "height": SIZE},
			"no_background": True, "seed": a.seed})
		img = (r.get("image") or {}).get("base64") or sys.exit("no reference image returned: %s" % str(r)[:300])
		st.d["armor_ref"] = img
	ref = {"image": {"type": "base64", "base64": st.d["armor_ref"], "format": "png"}, "size": {"width": SIZE, "height": SIZE}}
	outdir = os.path.join(a.gear, "_raw")
	os.makedirs(outdir, exist_ok=True)
	only = [x for x in a.dirs.split(",") if x]
	for d, pngs in frames.items():
		if only and DIRS[d] not in only:
			continue
		r = call("POST", "/transfer-outfit-v2", {"reference_image": ref, "image_size": {"width": SIZE, "height": SIZE},
			"frames": [{"image": b64(p), "size": {"width": SIZE, "height": SIZE}} for p in pngs[:15]],
			"no_background": True, "seed": a.seed})
		j = wait(r["background_job_id"])
		imgs = (j.get("last_response") or {}).get("images") or []
		for i, im in enumerate(imgs):
			data = im.get("base64") if isinstance(im, dict) else im
			with open(os.path.join(outdir, "%s_%03d.png" % (DIRS[d], i)), "wb") as f:
				f.write(base64.b64decode(data))
	st.log("armor" + ("_" + "_".join(only) if only else ""), before, generations(), {"directions": only or list(DIRS.values())})


def step_layers(st: State, a) -> None:
	"""Armour layer = outfit frame minus base frame (pixels that changed)."""
	from PIL import Image
	raw = os.path.join(a.gear, "_raw")
	if not os.path.isdir(raw):
		sys.exit("run `armor` first")
	os.makedirs(os.path.join(a.gear, "walk"), exist_ok=True)
	for facing in DIRS.values():
		base_p = os.path.join(a.out, "walk", facing + ".png")
		names = sorted(f for f in os.listdir(raw) if f.startswith(facing + "_"))
		if not os.path.exists(base_p) or not names:
			continue
		base = Image.open(base_p).convert("RGBA")
		h = base.height
		strip = Image.new("RGBA", (h * len(names), h))
		for i, n in enumerate(names):
			dressed = Image.open(os.path.join(raw, n)).convert("RGBA").resize((h, h), Image.NEAREST)
			cell = base.crop((i * h, 0, (i + 1) * h, h))
			strip.paste(diff_layer(cell, dressed), (i * h, 0))
		strip.save(os.path.join(a.gear, "walk", facing + "_Torso.png"))
	print("layers written to", a.gear)


def diff_layer(base, dressed, tol: int = 60, min_blob: int = 12):
	"""Pixels of `dressed` that differ from `base` (colour distance > tol),
	minus specks: transfer-outfit lightly reshades the whole body, so only
	connected patches of at least `min_blob` pixels count as the garment."""
	from PIL import Image
	w, h = base.size
	bp, dp = base.load(), dressed.load()
	keep = set()
	for y in range(h):
		for x in range(w):
			b, d = bp[x, y], dp[x, y]
			if d[3] >= 128 and (b[3] < 128 or sum(abs(b[i] - d[i]) for i in range(3)) > tol):
				keep.add((x, y))
	out = Image.new("RGBA", base.size)
	op = out.load()
	seen = set()
	for start in keep:
		if start in seen:
			continue
		blob, todo = [], [start]
		seen.add(start)
		while todo:
			x, y = todo.pop()
			blob.append((x, y))
			for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
				if (nx, ny) in keep and (nx, ny) not in seen:
					seen.add((nx, ny))
					todo.append((nx, ny))
		if len(blob) >= min_blob:
			for x, y in blob:
				op[x, y] = dp[x, y]
	return out


def step_state(st: State, a) -> None:
	"""Cheaper armour route: one edit dresses all 8 rotations, then the same
	walk template animates the dressed state, so its poses match the base."""
	cid = st.d.get("character_id") or sys.exit("run `body` first")
	only = [x for x in a.dirs.split(",") if x]
	dirs = [d for d, f in DIRS.items() if not only or f in only]
	before = generations()
	if not st.d.get("armor_state_id"):
		r = call("POST", "/create-character-state", {"character_id": cid, "edit_description": a.state_edit,
			"state_name": "pilot vest", "use_color_palette_from_reference": True, "seed": a.seed})
		wait(r["background_job_id"])
		st.d["armor_state_id"] = r["character_id"]
		st.save()
		mid = generations()
		print("state edit: %.2f generations" % (before - mid))
	r = call("POST", "/characters/animations", {"character_id": st.d["armor_state_id"], "mode": a.mode,
		"template_animation_id": a.template, "animation_name": "walk", "directions": dirs, "seed": a.seed})
	for j in r.get("background_job_ids") or []:
		wait(j)
	st.log("armor_state", before, generations(), {"directions": [DIRS[d] for d in dirs], "state_id": st.d["armor_state_id"]})


def step_state_layers(st: State, a) -> None:
	"""Vest layer per direction = dressed state's walk minus the base walk."""
	from PIL import Image
	sid = st.d.get("armor_state_id") or sys.exit("run `state` first")
	z = zipfile.ZipFile(io.BytesIO(call("GET", "/characters/%s/zip" % sid, raw=True)))
	frames = walk_frames(z, "pilot_vest")
	raw = os.path.join(a.gear, "_raw_state")
	os.makedirs(raw, exist_ok=True)
	os.makedirs(os.path.join(a.gear, "walk"), exist_ok=True)
	only = [x for x in a.dirs.split(",") if x]
	for d, pngs in frames.items():
		facing = DIRS[d]
		if only and facing not in only:
			continue
		base_p = os.path.join(a.out, "walk", facing + ".png")
		if not os.path.exists(base_p):
			continue
		base = Image.open(base_p).convert("RGBA")
		h = base.height
		strip = Image.new("RGBA", (h * len(pngs), h))
		for i, png in enumerate(pngs):
			with open(os.path.join(raw, "%s_%03d.png" % (facing, i)), "wb") as f:
				f.write(png)
			dressed = Image.open(io.BytesIO(png)).convert("RGBA").resize((h, h), Image.NEAREST)
			strip.paste(diff_layer(base.crop((i * h, 0, (i + 1) * h, h)), dressed), (i * h, 0))
		strip.save(os.path.join(a.gear, "walk", facing + "_Torso.png"))
		print("layer", facing, len(pngs), "frames")


def step_weapon(st: State, a) -> None:
	before = generations()
	r = call("POST", "/create-image-pixflux", {"description": a.weapon_prompt, "image_size": {"width": 48, "height": 48},
		"no_background": True, "seed": a.seed})
	img = (r.get("image") or {}).get("base64") or sys.exit("no image returned")
	d = os.path.join("assets", "gear", "weapons", "pilot_blade_pl")
	os.makedirs(d, exist_ok=True)
	with open(os.path.join(d, "SE.png"), "wb") as f:
		f.write(base64.b64decode(img))
	print("wrote", d, "(set its grip in attach.json)")
	st.log("weapon", before, generations(), {"path": d})


def main() -> None:
	p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	p.add_argument("step", choices=["plan", "balance", "body", "animate", "armor", "layers", "state", "state_layers", "weapon", "export"])
	p.add_argument("--go", action="store_true", help="actually spend credits")
	p.add_argument("--out", default="assets/units/base_body_a")
	p.add_argument("--gear", default="assets/gear/armor/pilot_vest")
	p.add_argument("--zip", default="", help="export from a local zip instead of downloading")
	p.add_argument("--template", default="walking", help="skeleton animation template id")
	p.add_argument("--mode", default="template", choices=["template", "skeleton-v3"])
	p.add_argument("--seed", type=int, default=1337)
	p.add_argument("--dirs", default="", help="armor: only these facings, e.g. SE (measure cost first)")
	p.add_argument("--body-prompt", default=BODY_PROMPT)
	p.add_argument("--armor-prompt", default=ARMOR_PROMPT)
	p.add_argument("--weapon-prompt", default=WEAPON_PROMPT)
	p.add_argument("--state-edit", default="wearing a dark armoured tactical vest with neon magenta trim over the bodysuit")
	a = p.parse_args()
	st = State(a.out)
	if a.step == "plan":
		total = 0
		for k in ("body", "animate", "armor", "weapon"):
			print("  %-8s ~%d generations" % (k, COST[k]))
			total += COST[k]
		print("  pilot total ~%d (weapon optional; template mode 'skeleton-v3' costs 2-4 per direction instead of 1)" % total)
		return
	if a.step == "balance":
		print("generations left: %.1f" % generations())
		return
	COST["state"] = 2 + 8
	if a.step in ("body", "animate", "armor", "state", "weapon") and not a.go:
		sys.exit("%s spends ~%d generations: add --go to run it" % (a.step, COST[a.step]))
	{"body": step_body, "animate": step_animate, "armor": step_armor, "layers": step_layers,
		"weapon": step_weapon, "export": step_export, "state": step_state, "state_layers": step_state_layers}[a.step](st, a)


if __name__ == "__main__":
	main()
