"""Gun aim poses drawn as skeletons, animated by PixelLab with no weapon in the prompt.

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
# (aim blend, kick 0-1) per frame after the raise.
REST = [(1, 0), (1, 0), (1, 0), (1, 1), (1, 0.45), (1, 0), (1, 1), (1, 0.45), (1, 0.1), (1, 0)]


def char(n: int) -> dict:
	return {c["n"]: c for c in json.load(open(POOL, encoding="utf-8"))["characters"]}[n]


def lerp(a, b, t):
	return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def ease(t):
	return t * t * (3 - 2 * t)


def poses(base: dict, size: int, facing: str) -> list:
	"""base: label -> (x, y) in source pixels. Returns frames of label -> (x, y) in canvas pixels."""
	pad = (CANVAS - size) / 2.0
	b = {k: (v[0] + pad, v[1] + pad) for k, v in base.items()}
	sh, el, wr = b["RIGHT SHOULDER"], b["RIGHT ELBOW"], b["RIGHT ARM"]
	upper = math.dist(sh, el)
	fore = math.dist(el, wr)
	ax, ay = AIM[facing]
	ln = math.hypot(ax, ay)
	ax, ay = ax / ln, ay / ln
	reach = (upper + fore) * 1.15
	wr_aim = (sh[0] + ax * reach, sh[1] + ay * reach - 1.5)
	el_aim = (sh[0] + ax * reach * 0.5, sh[1] + ay * reach * 0.5)
	# Kick: hand up 3 px and back 2 px toward the shoulder; elbow bends a little.
	wr_kick = (wr_aim[0] - ax * 2.0, wr_aim[1] - ay * 2.0 - 3.0)
	el_kick = (el_aim[0] - ax * 1.0, el_aim[1] - 1.0)
	out = []
	seq = [(t, 0.0) for t in RAISE] + REST
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


def preview(n: int, facing: str, out: str) -> None:
	from PIL import Image, ImageDraw
	c, d, base, w, png = load(n, facing)
	frames = poses(base, w, facing)
	k = 4
	spr = Image.open(io.BytesIO(padded(png, w))).convert("RGBA").resize((CANVAS * k, CANVAS * k), Image.NEAREST)
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


def go(n: int, facing: str, out_dir: str) -> None:
	c, d, base, w, png = load(n, facing)
	frames = poses(base, w, facing)
	pad = (CANVAS - w) / 2.0
	first = to_kp({k: (v[0] + pad, v[1] + pad) for k, v in base.items()})
	body = {"description": "%s, empty hands, holding nothing" % d.get("prompt", "character").strip(),
		"action": "aim and fire", "direction": DIRS[facing], "view": d.get("view", "high top-down"),
		"first_frame": pilot.b64(padded(png, w)), "first_frame_keypoints": first,
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
	json.dump({"character": n, "facing": facing, "canvas": CANVAS, "hand_r": hands,
		"raise": [0, 4], "hold": [5, 7], "fire": [8, 14], "job": job}, open(os.path.join(out_dir, "aim.json"), "w"), indent="\t")
	print("saved", len(imgs), "frames to", out_dir)


REST_TILT_MAX = 65.0  # a lowered gun points down-forward, not into the leg


def forearm_deg(f: dict) -> float:
	el, wr = f["RIGHT ELBOW"], f["RIGHT ARM"]
	return math.degrees(math.atan2(wr[1] - el[1], wr[0] - el[0]))


def rig(n: int, facing: str, count: int = 8) -> None:
	"""Writes aim_<facing> hand_r [x, y, z, angle] and elbow_r per frame, plus the
	still pose's forearm angle, into the unit's rig.json. Angle 0 = the aimed
	forearm (gun art is drawn aimed); positive turns clockwise, toward down."""
	c, d, base, w, png = load(n, facing)
	frames = poses(base, w, facing)[:count]
	aim = forearm_deg(frames[-1])
	sign = 1.0 if facing.endswith("E") else -1.0
	def tilt(f):
		a = (forearm_deg(f) - aim) * sign
		return round(max(-REST_TILT_MAX, min(REST_TILT_MAX, a)) * sign, 1)
	rp = os.path.join("assets", "units", "pool_%03d" % n, "rig.json")
	r = json.load(open(rp, encoding="utf-8"))
	pts = r["points"]
	z = 1 if facing in ("SE", "NE", "E", "S") else -1
	pts["hand_r"].setdefault("anims", {})["aim_" + facing] = [[round(f["RIGHT ARM"][0]), round(f["RIGHT ARM"][1]), z, tilt(f)] for f in frames]
	pts.setdefault("elbow_r", {"facing": {}, "anims": {}}).setdefault("anims", {})["aim_" + facing] = [[round(f["RIGHT ELBOW"][0]), round(f["RIGHT ELBOW"][1]), z] for f in frames]
	# Still pose (60 px cell): same lowered angle as frame 0.
	still = pts["hand_r"]["facing"].get(facing)
	if still:
		pts["hand_r"]["facing"][facing] = still[:3] + [tilt(frames[0])]
	with open(rp, "w", encoding="utf-8") as fh:
		json.dump(r, fh, indent="\t")
		fh.write("\n")
	print("rig", rp, [a[3] for a in pts["hand_r"]["anims"]["aim_" + facing]])


if __name__ == "__main__":
	cmd, n, facing = sys.argv[1], int(sys.argv[2]), sys.argv[3]
	if cmd == "preview":
		preview(n, facing, sys.argv[4])
	elif cmd == "plan":
		print("#%d %s pistol aim: 15 frames, 1 facing = 4 generations" % (n, facing))
	elif cmd == "rig":
		rig(n, facing, int(sys.argv[4]) if len(sys.argv) > 4 else 8)
	elif cmd == "go":
		go(n, facing, sys.argv[4])
