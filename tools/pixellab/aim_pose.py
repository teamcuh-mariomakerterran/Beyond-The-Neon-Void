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
GUN_ALONG_AIM = {"NW", "SW", "SE", "NE"}  # every facing (Brian, 2026-11-13: a held pistol level with the forearm read as aiming west)
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
# A character outside the pool (e.g. the modular base bodies): --id <character id> --zip <export.zip>:<state> [--desc "..."]
# [--chain <frames dir>] (rifle_raise / kick: the unit's own rifle_rest / pistol take to start from).
SOURCE = {}
CLIPS = {"hit": "hit", "death": "death", "jump": "jump", "use_item": "use_item", "throw": "throw", "walk": "walk", "walk2": "walk", "pistol15": "aim", "pistol": "aim", "rifle": "aim_rifle", "rifle_rest": "rest_rifle", "rifle_raise": "aim_rifle", "kick": "kick"}
ACTION = {"hit": "flinching back from a hit", "death": "falling backward to the ground, dead", "jump": "two-footed jump straight up and landing",
	"use_item": "dipping at the knees, then raising one empty hand up over the head", "throw": "overhand throwing motion with an empty hand, stepping forward",
	"walk": "walking forward", "walk2": "walking forward, natural stride, arms swinging", "pistol15": "aim and fire", "pistol": "raise right arm forward", "rifle": "raise both arms forward",
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
	if clip == "walk":
		return walk_poses(base, size, facing)
	if clip == "walk2":
		return gait_poses(base, size, facing)
	if clip in ("hit", "death", "jump", "use_item", "throw"):
		return action_poses(base, size, facing, clip)
	if clip == "rifle_raise":
		rest = rest_poses(base, size, facing)[0]
		aim = rifle_poses(base, size, facing)[-1]
		out = []
		pad = (CANVAS - size) / 2.0
		b = {k: (v[0] + pad, v[1] + pad) for k, v in base.items()}
		up, fo = _bones(b)
		_, S_ = gun_sides(b, facing)
		for t in RAISE + [1.0] * 3:
			e = ease(t)
			f = {k: lerp(rest[k], aim[k], e) for k in rest}
			if facing.startswith("N"):
				# From behind the near hand rides the barrel as it rises (Brian's marks).
				G_ = "LEFT" if S_ == "RIGHT" else "RIGHT"
				f[S_ + " ELBOW"], f[S_ + " ARM"] = back_gun_support(b, facing, t, up, fo, f[G_ + " ARM"])
			out.append(f)
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
	# The pistol is always in the right hand (the game attaches it there).
	sh, el, wr = b["RIGHT SHOULDER"], b["RIGHT ELBOW"], b["RIGHT ARM"]
	# A hidden far arm can be labelled on top of the near one (both elbows and
	# hands on one spot), which makes its upper arm read twice as long: take
	# the shorter side's bones.
	upper = min(math.dist(sh, el), math.dist(b["LEFT SHOULDER"], b["LEFT ELBOW"]))
	fore = min(math.dist(el, wr), math.dist(b["LEFT ELBOW"], b["LEFT ARM"]))
	ax, ay = AIM[facing]
	ln = math.hypot(ax, ay)
	ax, ay = ax / ln, ay / ln
	# Facings where the aimed arm crosses the body (SE, NW) read short, so reach a bit further.
	reach = (upper + fore) * (1.15 if facing in ("SE", "NW") else 0.95)
	nx, ny = AIM_NUDGE.get(facing, (0.0, 0.0))
	if SOURCE.get("nudge"):  # --nudge dx,dy: per-unit hand offset (e.g. clear a wide hairdo facing NW)
		nx, ny = (float(v) for v in SOURCE["nudge"].split(","))
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


def _bones(b: dict) -> tuple:
	"""(upper, fore) arm length: the shorter side's, because a hidden far arm
	is sometimes labelled on top of the near one and reads too long."""
	up = min(math.dist(b[s + " SHOULDER"], b[s + " ELBOW"]) for s in ("RIGHT", "LEFT"))
	fo = min(math.dist(b[s + " ELBOW"], b[s + " ARM"]) for s in ("RIGHT", "LEFT"))
	return up, fo


def _ik(sh, hand, up: float, fo: float, aim: tuple, reach: float = 0.92, out: float = 0.0):
	"""Hand pulled in to reach * arm length, and the elbow for it with the real
	bone lengths, bent down and away from the aim (never a locked, punching arm).
	out (+1 / -1, screen x): prefer the elbow flared out to that side and down,
	as seen from behind (back facings, Brian 2026-11-13: an inward elbow made
	the near arm read as shoved straight up)."""
	d = math.dist(sh, hand)
	lim = (up + fo) * reach
	if d > lim:
		hand = (sh[0] + (hand[0] - sh[0]) * lim / d, sh[1] + (hand[1] - sh[1]) * lim / d)
		d = lim
	d = max(d, abs(up - fo) + 0.01)
	ux, uy = (hand[0] - sh[0]) / d, (hand[1] - sh[1]) / d
	ca = max(-1.0, min(1.0, (up * up + d * d - fo * fo) / (2 * up * d)))
	sa = math.sqrt(1 - ca * ca)
	cands = [(sh[0] + up * (ux * ca - uy * sa * sg), sh[1] + up * (uy * ca + ux * sa * sg)) for sg in (1, -1)]
	if out:
		elbow = max(cands, key=lambda e: e[1] + (e[0] - sh[0]) * out * 1.5)
	else:
		elbow = max(cands, key=lambda e: e[1] - (e[0] * aim[0] + e[1] * aim[1]) * 0.5)
	return hand, elbow


def gun_sides(b: dict, facing: str) -> tuple:
	"""(grip side, support side) for a long gun: the trigger hand and stock go
	to the shoulder further back along the aim, the support hand to the one in
	front. SE/NW that is right-handed; SW/NE it mirrors (left hand on the grip),
	as a mirrored sprite would, so neither arm reaches across the chest
	(Brian's sketch, 2026-11-13)."""
	ax, ay = AIM[facing]
	r = b["RIGHT SHOULDER"][0] * ax + b["RIGHT SHOULDER"][1] * ay
	l = b["LEFT SHOULDER"][0] * ax + b["LEFT SHOULDER"][1] * ay
	return ("RIGHT", "LEFT") if r <= l else ("LEFT", "RIGHT")


def _two_hands(b: dict, facing: str, grip: tuple, spacing: float, droop: float = 0.0):
	"""Grip hand at `grip`; support hand ahead of it along the aim by `spacing`
	arm lengths (about the gun's two grips apart), only as far as the support
	arm reaches. Returns {side: (hand, elbow)}."""
	up, fo = _bones(b)
	L = up + fo
	ax, ay = AIM[facing]
	ln = math.hypot(ax, ay)
	ax, ay = ax / ln, ay / ln
	G_, S_ = gun_sides(b, facing)
	# Back facings: elbows flare out to their own side (seen from behind).
	back = facing.startswith("N")
	def side_out(sd: str) -> float:
		return (1.0 if b[sd + " SHOULDER"][0] >= b["NECK"][0] else -1.0) if back else 0.0
	wg, eg = _ik(b[G_ + " SHOULDER"], grip, up, fo, (ax, ay), out=side_out(G_))
	# droop: the barrel angled down by that many degrees (a low carry).
	if droop:
		r = math.radians(droop) * (1 if ax >= 0 else -1)
		ax, ay = ax * math.cos(r) - ay * math.sin(r), ax * math.sin(r) + ay * math.cos(r)
	s = spacing * L
	while s > 0.15 * L and math.dist(b[S_ + " SHOULDER"], (wg[0] + ax * s, wg[1] + ay * s + 0.6)) > 0.92 * L:
		s -= 0.25
	ws, es = _ik(b[S_ + " SHOULDER"], (wg[0] + ax * s, wg[1] + ay * s + 0.6), up, fo, (ax, ay), out=side_out(S_))
	return {G_: (wg, eg), S_: (ws, es), "spacing": math.dist(wg, ws)}


def back_support_arm(b: dict, facing: str, t: float, up: float, fo: float) -> tuple:
	"""(elbow, hand) of the support arm seen from behind (NE/NW), raising the
	rifle (Brian's marks, 2026-11-13): it hangs at the outer side holding the
	gun low (t 0-0.2), the elbow stays down while the forearm swings up into a
	V (0.5), the upper arm lifts out to the side (0.8), then the L at the
	barrel (1.0). t is the raise's own blend."""
	_, S_ = gun_sides(b, facing)
	sh = b[S_ + " SHOULDER"]
	o = -1.0 if AIM[facing][0] < 0 else 1.0
	keys = [
		(0.0, (0.2, 0.95), (0.1, 0.95)),     # hanging at the side
		(0.2, (0.2, 0.95), (0.1, 0.95)),
		(0.5, (0.45, 0.85), (0.6, -0.8)),    # V: elbow down, forearm up and out
		(0.8, (0.85, 0.4), (0.1, -0.98)),
		(1.0, (0.95, 0.15), (-0.05, -0.98)), # the L
	]
	for (t0, e0, h0), (t1, e1, h1) in zip(keys, keys[1:]):
		if t <= t1:
			k = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
			e_ = (e0[0] + (e1[0] - e0[0]) * k, e0[1] + (e1[1] - e0[1]) * k)
			h_ = (h0[0] + (h1[0] - h0[0]) * k, h0[1] + (h1[1] - h0[1]) * k)
			break
	else:
		e_, h_ = keys[-1][1], keys[-1][2]
	elbow = (sh[0] + o * e_[0] * up, sh[1] + e_[1] * up)
	return elbow, (elbow[0] + o * h_[0] * fo, elbow[1] + h_[1] * fo)


def back_gun_support(b: dict, facing: str, t: float, up: float, fo: float, grip: tuple) -> tuple:
	"""(elbow, hand) of the support arm seen from behind (NE/NW) for the raise
	at blend t, with the hand ON the barrel (Brian's marks, 2026-11-13): the
	gun points forward out past the near arm, its barrel rising from aimed
	down (t 0) through level to the aim (t 0.8+), the arm hanging at the side,
	then the V, then the L. grip: the trigger hand this frame."""
	_, S_ = gun_sides(b, facing)
	sh = b[S_ + " SHOULDER"]
	L = up + fo
	sx = -1.0 if AIM[facing][0] < 0 else 1.0
	aim_el = math.degrees(math.atan2(-AIM[facing][1], abs(AIM[facing][0])))
	keys = [(0.0, -15.0), (0.2, -10.0), (0.5, 15.0), (0.8, aim_el), (1.0, aim_el)]
	el = keys[-1][1]
	for (t0, a0), (t1, a1) in zip(keys, keys[1:]):
		if t <= t1:
			el = a0 + (a1 - a0) * ((t - t0) / (t1 - t0) if t1 > t0 else 0.0)
			break
	r = math.radians(el)
	dx, dy = sx * math.cos(r), -math.sin(r)
	d = 0.95 * L
	while d > 0.45 * L and math.dist(sh, (grip[0] + dx * d, grip[1] + dy * d)) > 0.93 * L:
		d -= 0.25
	hand = (grip[0] + dx * d, grip[1] + dy * d)
	if t < 0.35:
		# Low carry from behind: the arm reaches forward into the screen, so
		# it reads as hanging nearly straight, the elbow on the line from the
		# shoulder to the hand and a touch in toward the body. An IK elbow out
		# to the side read as the arm bent backwards (Brian, 2026-11-13).
		k = up / (up + fo)
		elbow = (sh[0] + (hand[0] - sh[0]) * k - sx * 0.6, sh[1] + (hand[1] - sh[1]) * k)
		return elbow, hand
	return _ik(sh, hand, up, fo, AIM[facing], out=sx)[::-1]


def rifle_poses(base: dict, size: int, facing: str) -> list:
	"""Two hands on a long gun, shouldered: the end pose is built in 3D from
	reference photos and projected into the facing (pose3d.py, Brian
	2026-11-13); the frames ease into it from standing, elbows leading."""
	import pose3d
	pad = (CANVAS - size) / 2.0
	b = {k: (v[0] + pad, v[1] + pad) for k, v in base.items()}
	up, fo = _bones(b)
	G_, S_ = gun_sides(b, facing)
	end = dict(b)
	end.update({k: v for k, v in pose3d.rifle(b, facing, "rifle_raise", AIM[facing], up, fo, G_).items() if not k.startswith("_")})
	if facing.startswith("N"):
		# Seen from behind (Brian's marks, 2026-11-13): the rifle runs from the
		# trigger shoulder out past the far side of the body along the aim.
		# Support arm (outer side, toward the aim): an L, the upper arm straight
		# out to the side to the elbow, the forearm straight up to the barrel.
		# Trigger arm: a V, the elbow down and in from its shoulder, the hand
		# back up at the gun beside the neck. Never longer than the bones.
		shs, shg = end[S_ + " SHOULDER"], end[G_ + " SHOULDER"]
		o = -1.0 if AIM[facing][0] < 0 else 1.0  # screen side the aim (and support arm) is on
		es = (shs[0] + o * 0.95 * up, shs[1] + 0.15 * up)
		ws = (es[0] - o * 0.05 * fo, es[1] - 0.98 * fo)
		eg = (shg[0] + o * 0.7 * up, shg[1] + 0.55 * up)
		wg = (eg[0] + o * 0.7 * fo, eg[1] - 0.7 * fo)
		end.update({S_ + " ELBOW": es, S_ + " ARM": ws, G_ + " ELBOW": eg, G_ + " ARM": wg})
	out = []
	for t in RAISE + [1.0] * 3:
		e = ease(t)
		f = {}
		for k in b:
			lead = min(1.0, e * 1.15) if k.endswith("ELBOW") else e
			f[k] = lerp(b[k], end[k], lead)
		if facing.startswith("N"):
			f[S_ + " ELBOW"], f[S_ + " ARM"] = back_support_arm(b, facing, t, up, fo)
		out.append(f)
	return out


def walk_poses(base: dict, size: int, facing: str, n: int = 8) -> list:
	"""An 8-frame walk built on the standing skeleton: feet step along the
	facing's ground direction and never drop below the standing feet, the
	lifted foot rises 2 px, knees bend forward, arms swing against the legs,
	the body bobs 1 px. The head rides the neck unchanged, so the facing
	can't drift."""
	pad = (CANVAS - size) / 2.0
	b = {k: (v[0] + pad, v[1] + pad) for k, v in base.items()}
	ax, ay = AIM[facing]
	ln = math.hypot(ax, ay)
	ax, ay = ax / ln, ay / ln
	stride, lift, swing = 4.5, 2.5, 2.6
	out = []
	for i in range(n):
		ph = 2 * math.pi * i / n
		f = dict(b)
		bob = -0.8 * abs(math.sin(ph))
		for k in ("NECK", "NOSE", "LEFT EYE", "RIGHT EYE", "LEFT EAR", "RIGHT EAR", "LEFT SHOULDER", "RIGHT SHOULDER", "LEFT HIP", "RIGHT HIP"):
			f[k] = (b[k][0], b[k][1] + bob)
		for side, sgn in (("RIGHT", 1.0), ("LEFT", -1.0)):
			c = math.cos(ph) * sgn
			up = max(0.0, math.sin(ph) * sgn) * lift
			ank = b[side + " LEG"]
			f[side + " LEG"] = (ank[0] + ax * stride * c, ank[1] + ay * stride * c - up)
			hip, a2 = f[side + " HIP"], f[side + " LEG"]
			mid = ((hip[0] + a2[0]) / 2, (hip[1] + a2[1]) / 2)
			bend = 0.8 + up * 0.6
			f[side + " KNEE"] = (mid[0] + ax * bend, mid[1] + ay * bend - up * 0.3)
			# Arms swing against the leg on the same side.
			wr, el = b[side + " ARM"], b[side + " ELBOW"]
			f[side + " ARM"] = (wr[0] - ax * swing * c, wr[1] - ay * swing * c + bob)
			f[side + " ELBOW"] = (el[0] - ax * swing * 0.5 * c, el[1] - ay * swing * 0.5 * c + bob)
		out.append(f)
	return out


def _knee(hip, ank, l1, l2, fwd):
	"""Two-bone leg: thigh and shin keep their standing lengths, the knee
	bends toward `fwd`. An ankle out of reach is pulled in to the hip."""
	dx, dy = ank[0] - hip[0], ank[1] - hip[1]
	d = math.hypot(dx, dy)
	if d >= (l1 + l2) * 0.995:
		k = (l1 + l2) * 0.995 / d
		ank = (hip[0] + dx * k, hip[1] + dy * k)
		dx, dy, d = dx * k, dy * k, (l1 + l2) * 0.995
	a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
	h = math.sqrt(max(0.0, l1 * l1 - a * a))
	mx, my = hip[0] + dx * a / d, hip[1] + dy * a / d
	px, py = -dy / d, dx / d
	c1, c2 = (mx + px * h, my + py * h), (mx - px * h, my - py * h)
	pick = c1 if (c1[0] - mx) * fwd[0] + (c1[1] - my) * fwd[1] >= (c2[0] - mx) * fwd[0] + (c2[1] - my) * fwd[1] else c2
	return pick, ank


def gait_poses(base: dict, size: int, facing: str, n: int = 8) -> list:
	"""A walk with real gait phases (contact, down, passing, up per step):
	the stance foot stays planted and slides back at an even pace, the swing
	foot lifts highest as it passes the other leg, knees bend on a two-bone
	leg (no stretching), arms swing wide and opposite, shoulders and hips
	counter-turn and the body dips after each contact."""
	pad = (CANVAS - size) / 2.0
	b = {k: (v[0] + pad, v[1] + pad) for k, v in base.items()}
	ax, ay = AIM[facing]
	ln = math.hypot(ax, ay)
	ax, ay = ax / ln, ay / ln
	stride, lift, swing = 4.0, 2.6, 4.0
	# Knees bend forward on the ground, which reads as forward and up on screen.
	fwd = (ax, ay - 0.6)
	L = {s: (math.dist(b[s + " HIP"], b[s + " KNEE"]), math.dist(b[s + " KNEE"], b[s + " LEG"])) for s in ("RIGHT", "LEFT")}
	# Per half-step: contact, down, passing, up (y down is positive).
	bob = [0.0, 1.0, -0.6, -0.3]
	out = []
	for i in range(n):
		f = dict(b)
		bb = bob[i % 4]
		# Which leg leads: right leg in front on frame 0, left on frame 4.
		turn = math.cos(2 * math.pi * i / n)
		for k in ("NECK", "NOSE", "LEFT EYE", "RIGHT EYE", "LEFT EAR", "RIGHT EAR"):
			f[k] = (b[k][0] + ax * 0.4, b[k][1] + bb)
		for side, sgn in (("RIGHT", 1.0), ("LEFT", -1.0)):
			# Hips turn with the leading leg, shoulders against it.
			f[side + " HIP"] = (b[side + " HIP"][0] + ax * 0.5 * turn * sgn, b[side + " HIP"][1] + ay * 0.5 * turn * sgn + bb)
			f[side + " SHOULDER"] = (b[side + " SHOULDER"][0] - ax * 0.6 * turn * sgn + ax * 0.3, b[side + " SHOULDER"][1] - ay * 0.6 * turn * sgn + bb)
		for side, ph0 in (("RIGHT", 0.0), ("LEFT", 0.5)):
			p = (i / n + ph0) % 1.0
			if p < 0.5:
				# Stance: planted, slides back evenly from front to back.
				t, up = p / 0.5, 0.0
				u = 1.0 - 2.0 * t
			else:
				# Swing: eased forward, highest at the pass.
				t = (p - 0.5) / 0.5
				u = -math.cos(math.pi * t)
				up = math.sin(math.pi * t) * lift
			ank0 = b[side + " LEG"]
			ank = (ank0[0] + ax * stride * u, ank0[1] + ay * stride * u - up)
			hip = f[side + " HIP"]
			l1, l2 = L[side]
			if up > 0:
				# Lift the knee as well: pull the ankle a little toward the hip.
				ank = (ank[0] + (hip[0] - ank[0]) * 0.045 * up, ank[1] + (hip[1] - ank[1]) * 0.045 * up)
			knee, ank = _knee(hip, ank, l1, l2, fwd)
			f[side + " KNEE"], f[side + " LEG"] = knee, ank
			# The arm on this side swings against this leg.
			c = math.cos(2 * math.pi * p)
			sh = f[side + " SHOULDER"]
			wr0, el0, s0 = b[side + " ARM"], b[side + " ELBOW"], b[side + " SHOULDER"]
			fw = max(0.0, -c)
			f[side + " ELBOW"] = (el0[0] + (sh[0] - s0[0]) - ax * swing * 0.45 * c, el0[1] + (sh[1] - s0[1]) - ay * swing * 0.45 * c)
			f[side + " ARM"] = (wr0[0] + (sh[0] - s0[0]) - ax * swing * c, wr0[1] + (sh[1] - s0[1]) - ay * swing * c - 1.2 * fw)
		out.append(f)
	return out


def action_poses(base: dict, size: int, facing: str, clip: str) -> list:
	"""Hit, death, jump, use item and throw, built on the standing skeleton so
	every outfit animated from them moves the same (slots stay mixable).
	`fwd` is the facing's ground direction on screen, up is -y."""
	pad = (CANVAS - size) / 2.0
	b = {k: (v[0] + pad, v[1] + pad) for k, v in base.items()}
	ax, ay = AIM[facing]
	ln = math.hypot(ax, ay)
	ax, ay = ax / ln, ay / ln
	UPPER = ("NECK", "NOSE", "LEFT EYE", "RIGHT EYE", "LEFT EAR", "RIGHT EAR", "LEFT SHOULDER", "RIGHT SHOULDER", "LEFT ELBOW", "RIGHT ELBOW", "LEFT ARM", "RIGHT ARM")
	HEAD = ("NOSE", "LEFT EYE", "RIGHT EYE", "LEFT EAR", "RIGHT EAR")

	def shift(f, keys, dx, dy):
		for k in keys:
			f[k] = (f[k][0] + dx, f[k][1] + dy)

	def legs_bend(f, down, fwd_knee=1.0):
		# Hips drop, knees go forward: a crouch.
		shift(f, UPPER + ("LEFT HIP", "RIGHT HIP"), 0, down)
		for s_ in ("LEFT", "RIGHT"):
			k = f[s_ + " KNEE"]
			f[s_ + " KNEE"] = (k[0] + ax * fwd_knee * down, k[1] + ay * fwd_knee * down + down * 0.5)

	out = []
	if clip == "hit":
		for t in (0.0, 1.0, 0.85, 0.55, 0.25, 0.0):
			f = dict(b)
			# Knocked back: upper body leans back, head snaps back more, arms fly out.
			shift(f, UPPER, -ax * 2.5 * t, -ay * 2.5 * t)
			shift(f, HEAD, -ax * 1.0 * t, -ay * 1.0 * t - 0.8 * t)
			for s_, sg in (("LEFT", -1), ("RIGHT", 1)):
				w = f[s_ + " ARM"]
				f[s_ + " ARM"] = (w[0] - ax * 2.0 * t, w[1] - ay * 2.0 * t - 1.5 * t)
			legs_bend(f, 1.0 * t)
			out.append(f)
		return out
	if clip == "death":
		feet = ((b["LEFT LEG"][0] + b["RIGHT LEG"][0]) / 2, (b["LEFT LEG"][1] + b["RIGHT LEG"][1]) / 2)

		def tip(x, y, deg):
			# Tip backward about the feet: height turns into distance behind.
			r = math.radians(deg)
			h = feet[1] - y
			# The lying body is a little shorter than standing height (seen
			# at an angle) and slides a few px toward the feet, so the head
			# lands well inside the canvas (PixelLab draws heads bigger than
			# the skeleton; at 0.95 and no slide they ran off the edge).
			k = math.sin(r)
			return (x - ax * h * k * 0.72 + ax * 5.0 * k, feet[1] - ay * h * k * 0.72 + ay * 5.0 * k - h * math.cos(r))

		# (body tip, knee buckle, arm lag, arm lift): the arms are left a beat
		# behind as the body goes back (they tip less than the body, floating a
		# little forward and up), then catch up and land along the sides.
		steps = ((0.0, 0.0, 0, 0.0), (8, 1.0, 4, 0.1), (20, 2.5, 10, 0.2), (40, 3.0, 18, 0.3),
			(62, 2.0, 22, 0.3), (80, 0.5, 12, 0.15), (85, 0.0, 3, 0.05), (85, 0.0, 0, 0.0))
		for th, buckle, lag, lift in steps:
			f = {k_: tip(x, y, th) for k_, (x, y) in b.items()}
			for s_ in ("LEFT", "RIGHT"):
				shp, elp, wrp = b[s_ + " SHOULDER"], b[s_ + " ELBOW"], b[s_ + " ARM"]
				arm_len = math.dist(shp, elp) + math.dist(elp, wrp)
				# Arms float a little forward and up from hanging (not overhead).
				e2 = (elp[0] + ax * arm_len * 0.2 * lift, elp[1] - arm_len * 0.25 * lift)
				w2 = (wrp[0] + ax * arm_len * 0.45 * lift, wrp[1] - arm_len * 0.55 * lift)
				# Tipped by a smaller angle than the body (they lag), hung from
				# where the body's shoulder actually is.
				s_lag = tip(shp[0], shp[1], th - lag)
				s_body = f[s_ + " SHOULDER"]
				for key, pnt in ((" ELBOW", e2), (" ARM", w2)):
					q = tip(pnt[0], pnt[1], th - lag)
					f[s_ + key] = (q[0] - s_lag[0] + s_body[0], q[1] - s_lag[1] + s_body[1])
			if buckle:
				legs_bend(f, buckle)
			out.append(f)
		return out
	if clip == "jump":
		for down, lift, tuck in ((0, 0, 0), (3, 0, 0), (1, 3, 0), (0, 7, 2), (0, 9, 3), (0, 6, 1.5), (3, 0, 0), (1, 0, 0)):
			f = dict(b)
			legs_bend(f, down)
			for k in f:
				f[k] = (f[k][0], f[k][1] - lift)
			if tuck:
				# Feet come up under the body in the air.
				for s_ in ("LEFT", "RIGHT"):
					a_ = f[s_ + " LEG"]
					f[s_ + " LEG"] = (a_[0] - ax * tuck * 0.5, a_[1] - tuck)
					k_ = f[s_ + " KNEE"]
					f[s_ + " KNEE"] = (k_[0] + ax * tuck * 0.6, k_[1] + ay * tuck * 0.6 - tuck * 0.4)
			# Arms swing up on the way up, down on landing.
			arm_up = lift * 0.5
			for s_ in ("LEFT", "RIGHT"):
				w, e = f[s_ + " ARM"], f[s_ + " ELBOW"]
				f[s_ + " ARM"] = (w[0] + ax * arm_up * 0.3, w[1] - arm_up)
				f[s_ + " ELBOW"] = (e[0], e[1] - arm_up * 0.5)
			out.append(f)
		return out
	# The camera-side hand does the toss or throw, so the arm is never hidden
	# behind the body: right facing SE/NE, left facing SW/NW.
	H_ = "RIGHT" if facing in ("SE", "NE", "E", "S") else "LEFT"
	O_ = "LEFT" if H_ == "RIGHT" else "RIGHT"
	sh, el, wr = b[H_ + " SHOULDER"], b[H_ + " ELBOW"], b[H_ + " ARM"]
	upper = math.dist(sh, el)
	fore = math.dist(el, wr)
	if clip == "use_item":
		# Right hand comes up to the chest, then straight up over the head
		# (the toss), holds, and comes back down; the head tips up to watch.
		# (crouch px, hand to chest, hand up): dip at the knees with the hand
		# at the chest, then rise and toss as the body comes up.
		keys = [(0.0, 0.0, 0.0), (1.5, 0.5, 0.0), (2.5, 0.9, 0.1), (0.5, 1.0, 0.75), (0.0, 1.0, 1.0), (0.0, 0.8, 0.6), (0.0, 0.4, 0.2), (0.0, 0.0, 0.0)]
		for crouch, chest, up in keys:
			f = dict(b)
			if crouch:
				legs_bend(f, crouch)
			# Up and a little out from the shoulder (away from the neck), so
			# the raised arm clears the head instead of hiding behind it.
			nk = b["NECK"]
			ox, oy = sh[0] - nk[0], 0.0
			ol = abs(ox) or 1.0
			out_x = ox / ol
			top = (sh[0] + out_x * 3.5 + ax * 1.0, sh[1] - (upper + fore) * 1.0)
			mid_chest = (sh[0] + ax * 3.0, sh[1] + 3.0)
			drop = crouch  # the arm comes down with the body in the dip
			hand = lerp(lerp(wr, mid_chest, chest), top, up)
			hand = (hand[0], hand[1] + drop)
			f[H_ + " ARM"] = hand
			e_ = lerp(lerp(el, (sh[0] + ax * 2.5, sh[1] + 4.0), chest), (sh[0] + out_x * 2.5 + ax * 1.5, sh[1] - upper * 0.8), up)
			f[H_ + " ELBOW"] = (e_[0], e_[1] + drop)
			shift(f, HEAD, 0, -0.8 * up)
			out.append(f)
		return out
	if clip == "throw":
		# Overhand: wind up behind the head, step in with the left foot,
		# release forward and up, follow through across, recover.
		back_hi = (sh[0] - ax * 4.0, sh[1] - upper * 0.9)
		release = (sh[0] + ax * (upper + fore) * 0.9, sh[1] - 3.0)
		follow = (sh[0] + ax * 3.0, sh[1] + upper)
		seq = [(wr, el, 0.0), (lerp(wr, back_hi, 0.6), None, 0.2), (back_hi, None, 0.5), (back_hi, None, 1.0),
			(release, None, 1.0), (follow, None, 0.8), (lerp(follow, wr, 0.5), None, 0.4), (wr, el, 0.0)]
		for hand, elbow, step in seq:
			f = dict(b)
			f[H_ + " ARM"] = hand
			f[H_ + " ELBOW"] = elbow if elbow else ((sh[0] + hand[0]) / 2 - ax * 1.0, (sh[1] + hand[1]) / 2 + 1.5)
			# Step in: the left foot moves forward, body leans into it.
			la, lk = b[O_ + " LEG"], b[O_ + " KNEE"]
			f[O_ + " LEG"] = (la[0] + ax * 3.0 * step, la[1] + ay * 3.0 * step)
			f[O_ + " KNEE"] = (lk[0] + ax * 2.2 * step, lk[1] + ay * 2.2 * step)
			lean = 1.2 * step if hand is release or hand is follow else -0.6 * step
			shift(f, ("NECK", "LEFT SHOULDER", "RIGHT SHOULDER", O_ + " ELBOW", O_ + " ARM") + HEAD, ax * lean, ay * lean)
			out.append(f)
		return out
	raise ValueError(clip)


def rest_poses(base: dict, size: int, facing: str) -> list:
	"""Long gun at rest (Brian's reference): carried low and level across the
	belly in both hands, barrel forward; three frames of breathing. Built in
	3D and projected (pose3d.py)."""
	import pose3d
	pad = (CANVAS - size) / 2.0
	b = {k: (v[0] + pad, v[1] + pad) for k, v in base.items()}
	up, fo = _bones(b)
	G_, S_ = gun_sides(b, facing)
	pose = dict(b)
	pose.update({k: v for k, v in pose3d.rifle(b, facing, "rifle_rest", AIM[facing], up, fo, G_).items() if not k.startswith("_")})
	if facing.startswith("N"):
		pose[S_ + " ELBOW"], pose[S_ + " ARM"] = back_gun_support(b, facing, 0.0, up, fo, pose[G_ + " ARM"])
	out = []
	for breath in (0.0, 0.5, 0.0):
		f = dict(pose)
		for k in ("NECK", "NOSE", "LEFT EYE", "RIGHT EYE", "LEFT EAR", "RIGHT EAR", "LEFT SHOULDER", "RIGHT SHOULDER"):
			f[k] = (pose[k][0], pose[k][1] + breath)
		out.append(f)
	return out


def start(n: int, facing: str, clip: str, base: dict, w: int, png: bytes):
	"""The first frame PixelLab redraws from, and the pose it is in (canvas px)."""
	if clip in CHAIN:
		folder, fi, src_clip = CHAIN[clip]
		# A unit outside the pool chains from its own take: --chain <dir> (its folder).
		if SOURCE.get("chain"):
			path = os.path.join(SOURCE["chain"], "frame_%03d.png" % fi)
		else:
			path = os.path.join("assets", "kit", "pool_%03d" % n, folder % facing, "frame_%03d.png" % fi)
		first = poses(base, w, facing, src_clip)[fi]
		return open(path, "rb").read(), first
	pad = (CANVAS - w) / 2.0
	return padded(png, w), {k: (v[0] + pad, v[1] + pad) for k, v in base.items()}


def load(n: int, facing: str):
	if SOURCE:
		d = pilot.call("GET", "/characters/%s" % SOURCE["id"])
		kp = d["skeletons"]["2d_references"][DIRS[facing]]["keypoints"]
		w, h = int(d["size"]["width"]), int(d["size"]["height"])
		base = {k: (v["x"] * (w - 1), v["y"] * (h - 1)) for k, v in kp.items()}
		zp, state = SOURCE["zip"].rsplit(":", 1)
		png = zipfile.ZipFile(zp).read("%s/rotations/%s.png" % (state, DIRS[facing]))
		return {"n": 0, "character_id": SOURCE["id"]}, d, base, w, png
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
	desc = SOURCE.get("desc") or "%s, empty hands, holding nothing" % d.get("prompt", "character").strip()
	body = {"description": desc,
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
	json.dump({"character": n or SOURCE.get("id"), "facing": facing, "clip": clip, "canvas": CANVAS, "hand_r": hands, "hand_l": hands_l,
		"joints": [{k: [round(v[0], 2), round(v[1], 2)] for k, v in f.items()} for f in frames],
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
		g_, s_ = f.get("_sides", ("RIGHT", "LEFT"))
		a, b = f[g_ + " ARM"], f[s_ + " ARM"]
		return math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
	return forearm_deg(f)


def rig(n: int, facing: str, count: int = 8, clip: str = "pistol") -> None:
	"""Writes aim_<facing> hand_r [x, y, z, angle] and elbow_r per frame, plus the
	still pose's forearm angle, into the unit's rig.json. Angle 0 = the aimed
	forearm (gun art is drawn aimed); positive turns clockwise, toward down."""
	c, d, base, w, png = load(n, facing)
	frames = poses(base, w, facing, clip)[:count]
	if clip in ("rifle", "rifle_raise", "rifle_rest"):
		# The game's hand_r is the gun's grip: on SW/NE that is the left hand.
		pad = (CANVAS - w) / 2.0
		g_, s_ = gun_sides({k: (v[0] + pad, v[1] + pad) for k, v in base.items()}, facing)
		frames = [dict(f, **{"_sides": (g_, s_), "RIGHT ARM": f[g_ + " ARM"], "RIGHT ELBOW": f[g_ + " ELBOW"],
			"RIGHT SHOULDER": f[g_ + " SHOULDER"], "LEFT ARM": f[s_ + " ARM"]}) for f in frames]
		for f in frames:
			f["_sides"] = ("RIGHT", "LEFT")
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
	for opt in ("--id", "--zip", "--desc", "--chain", "--nudge"):
		if opt in sys.argv:
			i = sys.argv.index(opt)
			SOURCE[opt[2:]] = sys.argv[i + 1]
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
