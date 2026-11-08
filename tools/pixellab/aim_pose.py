"""Gun aim poses drawn as skeletons, animated by PixelLab with no weapon in the prompt.

    add --clip pistol (raise + hold, 8 frames, 3) or --clip rifle (two hands, 8 frames, 3)
    python3 -I tools/pixellab/aim_pose.py preview <n> <facing> <out.png>   # free: poses over the sprite
    python3 -I tools/pixellab/aim_pose.py plan <n> <facing>                # cost only
    python3 -I tools/pixellab/aim_pose.py go <n> <facing> <out_dir>        # spends (~4 for 15 frames)
    python3 -I tools/pixellab/aim_pose.py rig <n> <facing> [frames]        # free: hand, elbow, forearm angle into rig.json

The clip (pistol, one hand): frames 0-4 raise the right arm to aim, 5-7 hold,
8-14 fire twice (the hand kicks up and back, then settles). Poses start from
the character's own stored 2D skeleton (GET /characters/{id}, free), so the
body keeps its build; only the arms move. The sprite is padded to CANVAS so
the reach has room. Because the motion is joints and the description says
empty hands, nothing is drawn in the hand: game weapons attach to the hand
points, which are known exactly (we wrote them) and saved next to the frames.
"""
import base64
import io
import json
import math
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot  # noqa: E402

CANVAS = 96
DIRS = {v: k for k, v in pilot.DIRS.items()}  # "SE" -> "south-east"
POOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pool.json")
# Aim direction on screen per facing (2:1 isometric), x right, y down.
AIM = {"SE": (1.0, 0.4), "SW": (-1.0, 0.4), "NE": (1.0, -0.4), "NW": (-1.0, -0.4)}
RAISE = [0.0, 0.2, 0.5, 0.8, 1.0]
# Facings whose held gun points along the aim line rather than the drawn
# forearm (NW: the hand is low at the collar, so the forearm angles down;
# Brian's mark, 2026-11-08). The rest follow the arm as drawn.
GUN_ALONG_AIM = {"NW"}
# Aimed hand moved by hand (canvas px): NW sits at the collar, out past the head (Brian's marks, 2026-11-08).
AIM_NUDGE = {"NW": (-2.0, 3.0)}
# (aim blend, kick 0-1) per frame after the raise.
REST = [(1, 0), (1, 0), (1, 0), (1, 1), (1, 0.45), (1, 0), (1, 1), (1, 0.45), (1, 0.1), (1, 0)]


def char(n: int) -> dict:
	return {c["n"]: c for c in json.load(open(POOL, encoding="utf-8"))["characters"]}[n]


def lerp(a, b, t):
	return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def ease(t):
	return t * t * (3 - 2 * t)


# Clips: "pistol15" is the first test (raise, hold, two kicks; the kicks grew a
# gun). "pistol" and "rifle" are raise + hold only (8 frames, 3 generations);
# the kick is done in the engine (GearAttach.fire_kick).
CLIPS = {"pistol15": "aim", "pistol": "aim", "rifle": "aim_rifle", "rifle_rest": "rest_rifle", "rifle_raise": "aim_rifle", "kick": "kick"}
ACTION = {"pistol15": "aim and fire", "pistol": "raise right arm forward", "rifle": "raise both arms forward",
	"rifle_rest": "standing with both hands at the waist", "rifle_raise": "raise both arms forward", "kick": "right wrist jerks up and back"}
# Clips that start from another take's frame instead of the standing pose:
# clip -> (kit folder of the start take, its frame, the clip whose pose that frame is).
CHAIN = {"rifle_raise": ("aim_rifle_rest_%s", 0, "rifle_rest"), "kick": ("aim_pistol_%s", 7, "pistol")}
KICK = [1.0, 0.45, 0.1, 0.0]  # per frame, after the held aim


def poses(base: dict, size: int, facing: str, clip: str = "pistol15") -> list:
	"""base: label -> (x, y) in source pixels. Returns frames of label -> (x, y) in canvas pixels."""
	if clip == "rifle":
		return rifle_poses(base, size, facing)
	if clip == "rifle_rest":
		return rest_poses(base, size, facing)
	if clip == "rifle_raise":
		rest = rest_poses(base, size, facing)[0]
		aim = rifle_poses(base, size, facing)[-1]
		out = []
		for t in RAISE + [1.0] * 3:
			e = ease(t)
			out.append({k: lerp(rest[k], aim[k], e) for k in rest})
		return out
	if clip == "kick":
		hold = poses(base, size, facing, "pistol")[-1]
		pad = (CANVAS - size) / 2.0
		sh = (base["RIGHT SHOULDER"][0] + pad, base["RIGHT SHOULDER"][1] + pad)
		ax, ay = AIM[facing]
		ln = math.hypot(ax, ay)
		ax, ay = ax / ln, ay / ln
		out = []
		for k in KICK:
			f = dict(hold)
			# Wrist snaps up 3 px and back 2 px, the elbow folds a little, the shoulder gives.
			f["RIGHT ARM"] = (hold["RIGHT ARM"][0] - ax * 2.0 * k, hold["RIGHT ARM"][1] - ay * 2.0 * k - 3.0 * k)
			f["RIGHT ELBOW"] = (hold["RIGHT ELBOW"][0] - ax * 1.0 * k, hold["RIGHT ELBOW"][1] + 0.5 * k)
			f["RIGHT SHOULDER"] = (sh[0] - ax * 0.6 * k, sh[1] - ay * 0.6 * k)
			out.append(f)
		return out
	pad = (CANVAS - size) / 2.0
	b = {k: (v[0] + pad, v[1] + pad) for k, v in base.items()}
	sh, el, wr = b["RIGHT SHOULDER"], b["RIGHT ELBOW"], b["RIGHT ARM"]
	upper = math.dist(sh, el)
	fore = math.dist(el, wr)
	ax, ay = AIM[facing]
	ln = math.hypot(ax, ay)
	ax, ay = ax / ln, ay / ln
	# Facings where the aimed arm crosses the body (SE, NW) read short, so reach a bit further.
	reach = (upper + fore) * (1.15 if facing in ("SE", "NW") else 0.95)
	nx, ny = AIM_NUDGE.get(facing, (0.0, 0.0))
	wr_aim = (sh[0] + ax * reach + nx, sh[1] + ay * reach - 1.5 + ny)
	el_aim = (sh[0] + ax * reach * 0.5, sh[1] + ay * reach * 0.5)
	# Kick: hand up 3 px and back 2 px toward the shoulder; elbow bends a little.
	wr_kick = (wr_aim[0] - ax * 2.0, wr_aim[1] - ay * 2.0 - 3.0)
	el_kick = (el_aim[0] - ax * 1.0, el_aim[1] - 1.0)
	out = []
	seq = [(t, 0.0) for t in RAISE] + (REST if clip == "pistol15" else [(1, 0)] * 3)
	for t, kick in seq:
		f = dict(b)
		e = ease(t)
		# Raise: the elbow leads, the wrist follows a little behind.
		f["RIGHT ELBOW"] = lerp(el, el_aim, min(1.0, e * 1.15))
		f["RIGHT ARM"] = lerp(wr, wr_aim, e)
		if kick:
			f["RIGHT ARM"] = lerp(f["RIGHT ARM"], wr_kick, kick)
			f["RIGHT ELBOW"] = lerp(f["RIGHT ELBOW"], el_kick, kick)
			f["RIGHT SHOULDER"] = (sh[0] - ax * 0.6 * kick, sh[1] - ay * 0.6 * kick)
		out.append(f)
	return out


def rifle_poses(base: dict, size: int, facing: str) -> list:
	"""Two hands on a long gun: stock at the right shoulder, right hand on the
	grip just in front of it, left hand out on the barrel, both on the aim line."""
	pad = (CANVAS - size) / 2.0
	b = {k: (v[0] + pad, v[1] + pad) for k, v in base.items()}
	shr, elr, wrr = b["RIGHT SHOULDER"], b["RIGHT ELBOW"], b["RIGHT ARM"]
	shl, ell, wrl = b["LEFT SHOULDER"], b["LEFT ELBOW"], b["LEFT ARM"]
	arm = math.dist(shr, elr) + math.dist(elr, wrr)
	ax, ay = AIM[facing]
	ln = math.hypot(ax, ay)
	ax, ay = ax / ln, ay / ln
	# The gun line starts at the right shoulder, a little low.
	o = (shr[0], shr[1] + 1.0)
	wrr_aim = (o[0] + ax * arm * 0.5, o[1] + ay * arm * 0.5 + 0.5)
	wrl_aim = (o[0] + ax * arm * 1.5, o[1] + ay * arm * 1.5 - 0.5)
	elr_aim = ((shr[0] + wrr_aim[0]) / 2 - ax * 1.5, max(shr[1], wrr_aim[1]) + 3.0)
	ell_aim = ((shl[0] + wrl_aim[0]) / 2, (shl[1] + wrl_aim[1]) / 2 + 2.5)
	out = []
	for t in RAISE + [1.0] * 3:
		f = dict(b)
		e = ease(t)
		f["RIGHT ELBOW"] = lerp(elr, elr_aim, min(1.0, e * 1.15))
		f["RIGHT ARM"] = lerp(wrr, wrr_aim, e)
		f["LEFT ELBOW"] = lerp(ell, ell_aim, min(1.0, e * 1.15))
		f["LEFT ARM"] = lerp(wrl, wrl_aim, e)
		out.append(f)
	return out


def rest_poses(base: dict, size: int, facing: str) -> list:
	"""Long gun at rest (Brian's reference): carried level at the waist in both
	hands, barrel forward; three frames of breathing."""
	pad = (CANVAS - size) / 2.0
	b = {k: (v[0] + pad, v[1] + pad) for k, v in base.items()}
	shr, shl = b["RIGHT SHOULDER"], b["LEFT SHOULDER"]
	hr, hl = b["RIGHT HIP"], b["LEFT HIP"]
	arm = math.dist(shr, b["RIGHT ELBOW"]) + math.dist(b["RIGHT ELBOW"], b["RIGHT ARM"])
	ax, ay = AIM[facing]
	ln = math.hypot(ax, ay)
	ax, ay = ax / ln, ay / ln
	waist = ((hr[0] + hl[0]) / 2, min(hr[1], hl[1]) - 2.0)
	# Grip hand at the hip on the gun side, support hand forward along the aim, level.
	wr = (hr[0] + ax * 2.0, waist[1])
	wl = (wr[0] + ax * arm * 0.85, wr[1] + ay * arm * 0.25)
	er = ((shr[0] + wr[0]) / 2 - ax * 2.0, (shr[1] + wr[1]) / 2 + 1.0)
	el = ((shl[0] + wl[0]) / 2, (shl[1] + wl[1]) / 2 + 2.0)
	out = []
	for breath in (0.0, 0.5, 0.0):
		f = dict(b)
		f["RIGHT ARM"], f["LEFT ARM"], f["RIGHT ELBOW"], f["LEFT ELBOW"] = wr, wl, er, el
		for k in ("NECK", "NOSE", "LEFT EYE", "RIGHT EYE", "LEFT EAR", "RIGHT EAR", "LEFT SHOULDER", "RIGHT SHOULDER"):
			f[k] = (b[k][0], b[k][1] + breath)
		out.append(f)
	return out


def start(n: int, facing: str, clip: str, base: dict, w: int, png: bytes):
	"""The first frame PixelLab redraws from, and the pose it is in (canvas px)."""
	if clip in CHAIN:
		folder, fi, src_clip = CHAIN[clip]
		path = os.path.join("assets", "kit", "pool_%03d" % n, folder % facing, "frame_%03d.png" % fi)
		first = poses(base, w, facing, src_clip)[fi]
		return open(path, "rb").read(), first
	pad = (CANVAS - w) / 2.0
	return padded(png, w), {k: (v[0] + pad, v[1] + pad) for k, v in base.items()}


def load(n: int, facing: str):
	c = char(n)
	d = pilot.call("GET", "/characters/%s" % c["character_id"])
	kp = d["skeletons"]["2d_references"][DIRS[facing]]["keypoints"]
	w, h = int(d["size"]["width"]), int(d["size"]["height"])
	base = {k: (v["x"] * (w - 1), v["y"] * (h - 1)) for k, v in kp.items()}
	z = zipfile.ZipFile(os.path.join("assets", "units", "pool_%03d" % n, "pool_%03d.zip" % n))
	png = z.read([x for x in z.namelist() if x.endswith("rotations/%s.png" % DIRS[facing])][0])
	return c, d, base, w, png


def padded(png: bytes, size: int) -> bytes:
	from PIL import Image
	im = Image.open(io.BytesIO(png)).convert("RGBA")
	c = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
	p = (CANVAS - size) // 2
	c.paste(im, (p, p))
	buf = io.BytesIO()
	c.save(buf, "PNG")
	return buf.getvalue()


def to_kp(f: dict) -> list:
	return [{"label": k, "x": round(min(max(v[0] / (CANVAS - 1), 0), 1), 4), "y": round(min(max(v[1] / (CANVAS - 1), 0), 1), 4)} for k, v in f.items()]


def preview(n: int, facing: str, out: str, clip: str = "pistol15") -> None:
	from PIL import Image, ImageDraw
	c, d, base, w, png = load(n, facing)
	frames = poses(base, w, facing, clip)
	k = 4
	first_png, _ = start(n, facing, clip, base, w, png)
	spr = Image.open(io.BytesIO(first_png)).convert("RGBA").resize((CANVAS * k, CANVAS * k), Image.NEAREST)
	sheet = Image.new("RGBA", (CANVAS * k * 5, CANVAS * k * 3), (28, 30, 40, 255))
	bones = [("RIGHT SHOULDER", "RIGHT ELBOW"), ("RIGHT ELBOW", "RIGHT ARM"), ("LEFT SHOULDER", "LEFT ELBOW"), ("LEFT ELBOW", "LEFT ARM"),
		("RIGHT SHOULDER", "LEFT SHOULDER"), ("NECK", "NOSE"), ("RIGHT HIP", "RIGHT KNEE"), ("RIGHT KNEE", "RIGHT LEG"), ("LEFT HIP", "LEFT KNEE"), ("LEFT KNEE", "LEFT LEG")]
	for i, f in enumerate(frames):
		x0, y0 = (i % 5) * CANVAS * k, (i // 5) * CANVAS * k
		cell = spr.copy()
		cell.putalpha(cell.getchannel("A").point(lambda a: a * 0.45))
		sheet.alpha_composite(cell, (x0, y0))
		dr = ImageDraw.Draw(sheet)
		for a, b2 in bones:
			col = (255, 80, 200) if a.startswith("RIGHT") and b2 != "LEFT SHOULDER" and "HIP" not in a and "KNEE" not in a else (90, 255, 240)
			dr.line([(x0 + f[a][0] * k, y0 + f[a][1] * k), (x0 + f[b2][0] * k, y0 + f[b2][1] * k)], fill=col, width=3)
		dr.text((x0 + 6, y0 + 6), "frame %d" % (i + 1), fill=(230, 230, 240))
	sheet.save(out)
	print("preview", out, len(frames), "frames")


def go(n: int, facing: str, out_dir: str, clip: str = "pistol15") -> None:
	c, d, base, w, png = load(n, facing)
	frames = poses(base, w, facing, clip)
	first_png, first_pose = start(n, facing, clip, base, w, png)
	first = to_kp(first_pose)
	body = {"description": "%s, empty hands, holding nothing" % d.get("prompt", "character").strip(),
		"action": ACTION[clip], "direction": DIRS[facing], "view": d.get("view", "high top-down"),
		"first_frame": pilot.b64(first_png), "first_frame_keypoints": first,
		"keypoints": [to_kp(f) for f in frames], "template_id": "mannequin", "no_background": True}
	r = pilot.call("POST", "/animate-with-skeleton-v3", body)
	job = r.get("background_job_id") or sys.exit("no job: %s" % str(r)[:400])
	print("job", job)
	res = pilot.wait(job)
	os.makedirs(out_dir, exist_ok=True)
	imgs = (res.get("last_response") or {}).get("images") or []
	for i, im in enumerate(imgs):
		data = im.get("base64") if isinstance(im, dict) else im
		with open(os.path.join(out_dir, "frame_%03d.png" % i), "wb") as f:
			f.write(base64.b64decode(data))
	hands = [[round(f["RIGHT ARM"][0], 1), round(f["RIGHT ARM"][1], 1)] for f in frames]
	hands_l = [[round(f["LEFT ARM"][0], 1), round(f["LEFT ARM"][1], 1)] for f in frames]
	json.dump({"character": n, "facing": facing, "clip": clip, "canvas": CANVAS, "hand_r": hands, "hand_l": hands_l,
		"raise": [0, 4], "hold": [5, 7], "fire": [8, 14] if clip == "pistol15" else None, "job": job}, open(os.path.join(out_dir, "aim.json"), "w"), indent="\t")
	print("saved", len(imgs), "frames to", out_dir)


REST_TILT_MAX = 65.0  # a lowered gun points down-forward, not into the leg


def forearm_deg(f: dict) -> float:
	el, wr = f["RIGHT ELBOW"], f["RIGHT ARM"]
	return math.degrees(math.atan2(wr[1] - el[1], wr[0] - el[0]))


def gun_deg(f: dict, clip: str) -> float:
	"""Screen angle of the held gun: the forearm, or for a rifle the line from
	the grip hand to the barrel hand."""
	if clip in ("rifle", "rifle_raise", "rifle_rest"):
		a, b = f["RIGHT ARM"], f["LEFT ARM"]
		return math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
	return forearm_deg(f)


def rig(n: int, facing: str, count: int = 8, clip: str = "pistol") -> None:
	"""Writes aim_<facing> hand_r [x, y, z, angle] and elbow_r per frame, plus the
	still pose's forearm angle, into the unit's rig.json. Angle 0 = the aimed
	forearm (gun art is drawn aimed); positive turns clockwise, toward down."""
	c, d, base, w, png = load(n, facing)
	frames = poses(base, w, facing, clip)[:count]
	aim = gun_deg(frames[-1], clip)
	anim = CLIPS[clip] + "_" + facing
	sign = 1.0 if facing.endswith("E") else -1.0
	def tilt(f):
		a = ((gun_deg(f, clip) - aim + 180.0) % 360.0 - 180.0) * sign
		return round(max(-REST_TILT_MAX, min(REST_TILT_MAX, a)) * sign, 1)
	rp = os.path.join("assets", "units", "pool_%03d" % n, "rig.json")
	r = json.load(open(rp, encoding="utf-8"))
	pts = r["points"]
	# An aimed hand is out in front: over the body on the front facings, behind it on the back ones.
	z = 1 if facing.startswith("S") else -1
	pts["hand_r"].setdefault("anims", {})[anim] = [[round(f["RIGHT ARM"][0]), round(f["RIGHT ARM"][1]), z, tilt(f)] for f in frames]
	pts.setdefault("elbow_r", {"facing": {}, "anims": {}}).setdefault("anims", {})[anim] = [[round(f["RIGHT ELBOW"][0]), round(f["RIGHT ELBOW"][1]), z] for f in frames]
	# Still pose (60 px cell): same lowered angle as frame 0.
	still = pts["hand_r"]["facing"].get(facing)
	if still and clip in ("pistol", "pistol15"):
		pts["hand_r"]["facing"][facing] = still[:3] + [tilt(frames[0])]
	# gun_r: the held gun's screen angle per frame. Raising, it follows the
	# forearm; held, it points along the aim (the forearm can sit off the aim,
	# e.g. NW where the hand is low at the collar); a kick adds the forearm's lift.
	gun_anims = pts.setdefault("gun_r", {"facing": {}, "anims": {}}).setdefault("anims", {})
	gun_anims.pop(anim, None)
	if clip in ("pistol", "pistol15", "kick") and facing in GUN_ALONG_AIM:
		aim_deg = math.degrees(math.atan2(AIM[facing][1], AIM[facing][0]))
		hold_fa = forearm_deg(poses(base, w, facing, "pistol")[-1])
		def wrap(d):
			return (d + 180.0) % 360.0 - 180.0
		seq = (RAISE + [1.0] * (len(frames) - len(RAISE))) if clip != "kick" else [1.0] * len(frames)
		gun = []
		for f, t in zip(frames, seq):
			fa = forearm_deg(f)
			if clip == "kick":
				gun.append([round(aim_deg + wrap(fa - hold_fa), 1), 0, 0])
			else:
				e = ease(t)
				gun.append([round(fa + wrap(aim_deg - fa) * e, 1), 0, 0])
		gun_anims[anim] = gun
	if clip in ("rifle", "rifle_raise", "rifle_rest"):
		pts.setdefault("shoulder_r", {"facing": {}, "anims": {}}).setdefault("anims", {})[anim] = [[round(f["RIGHT SHOULDER"][0]), round(f["RIGHT SHOULDER"][1]), z] for f in frames]
		pts.setdefault("hand_l", {"facing": {}, "anims": {}}).setdefault("anims", {})[anim] = [[round(f["LEFT ARM"][0]), round(f["LEFT ARM"][1]), z] for f in frames]
	with open(rp, "w", encoding="utf-8") as fh:
		json.dump(r, fh, indent="\t")
		fh.write("\n")
	print("rig", rp, anim, [a[3] for a in pts["hand_r"]["anims"][anim]])


if __name__ == "__main__":
	clip = "pistol15"
	if "--clip" in sys.argv:
		i = sys.argv.index("--clip")
		clip = sys.argv[i + 1]
		del sys.argv[i:i + 2]
	cmd, n, facing = sys.argv[1], int(sys.argv[2]), sys.argv[3]
	if cmd == "preview":
		preview(n, facing, sys.argv[4], clip)
	elif cmd == "plan":
		print("#%d %s %s: %d frames, 1 facing = %d generations" % (n, facing, clip, 15 if clip == "pistol15" else 8, 4 if clip == "pistol15" else 3))
	elif cmd == "rig":
		rig(n, facing, int(sys.argv[4]) if len(sys.argv) > 4 else 8, "pistol" if clip == "pistol15" else clip)
	elif cmd == "go":
		go(n, facing, sys.argv[4], clip)
