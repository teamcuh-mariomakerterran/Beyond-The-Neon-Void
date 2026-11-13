"""Rifle poses built in 3D and projected into a facing, instead of placing
each facing's joints by hand in 2D. Free (no PixelLab calls of its own).

The pose follows reference photos of standing rifle fire (Brian, 2026-11-13):
the stock in the trigger shoulder's pocket, the trigger elbow out to the side
about level with the shoulder, the support arm forward under the barrel with
its elbow underneath, the body bladed (support shoulder forward) and the
cheek down on the stock. The low carry (rest) holds the gun at the belly,
barrel angled down, both elbows down.

Projection: the sprites are drawn in a stylised three-quarter view, not true
isometry, so the camera is fitted per facing from the unit's own skeleton:
  right axis = the drawn shoulder line (right shoulder minus left), unit length
  up axis    = screen up
  forward    = the facing's aim direction on screen (aim_pose.AIM), shortened by
               FORE (depth reads shorter than width in these sprites).
Bone lengths are the unit's own (aim_pose._bones), and every arm is solved in
3D with its real lengths, so no arm can be stretched in any facing.

    python3 -I tools/pixellab/pose3d.py  (used through aim_pose.rifle_poses)
"""
import math

FORE = 0.7     # forward depth on screen per unit of 3D length
BLADE = 25.0   # degrees the shoulders turn, support shoulder forward


def _v(a, b, s=1.0):
	return (a[0] + b[0] * s, a[1] + b[1] * s, a[2] + b[2] * s)


def _sub(a, b):
	return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _dot(a, b):
	return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _len(a):
	return math.sqrt(_dot(a, a))


def _unit(a):
	n = _len(a) or 1.0
	return (a[0] / n, a[1] / n, a[2] / n)


def ik3(sh, hand, up: float, fo: float, pole, reach: float = 0.95):
	"""(hand, elbow) in 3D: the hand pulled in to `reach` of the arm, the elbow
	bent toward `pole` with the real bone lengths."""
	d_v = _sub(hand, sh)
	d = _len(d_v)
	lim = (up + fo) * reach
	if d > lim:
		hand = _v(sh, _unit(d_v), lim)
		d_v = _sub(hand, sh)
		d = lim
	d = max(d, abs(up - fo) + 0.01)
	n = _unit(d_v)
	x = (up * up - fo * fo + d * d) / (2 * d)
	h = math.sqrt(max(0.0, up * up - x * x))
	p = _sub(pole, tuple(n[i] * _dot(pole, n) for i in range(3)))
	p = _unit(p)
	return hand, _v(_v(sh, n, x), p, h)


class Camera:
	"""Maps body-frame 3D (right, forward, up) offsets to screen pixels."""

	def __init__(self, b: dict, aim: tuple):
		rs, ls = b["RIGHT SHOULDER"], b["LEFT SHOULDER"]
		dx, dy = rs[0] - ls[0], rs[1] - ls[1]
		self.w = math.hypot(dx, dy)
		self.R = (dx / self.w, dy / self.w)
		n = math.hypot(*aim)
		self.F = (aim[0] / n * FORE, aim[1] / n * FORE)
		self.U = (0.0, -1.0)
		self.M = ((rs[0] + ls[0]) / 2, (rs[1] + ls[1]) / 2)

	def __call__(self, p) -> tuple:
		return (self.M[0] + p[0] * self.R[0] + p[1] * self.F[0] + p[2] * self.U[0],
			self.M[1] + p[0] * self.R[1] + p[1] * self.F[1] + p[2] * self.U[1])


def rifle(b: dict, facing: str, clip: str, aim: tuple, up: float, fo: float, trigger: str) -> dict:
	"""Screen joints for the arms, shoulders and head of a rifle pose.
	b: base joints (canvas px). trigger: "RIGHT" or "LEFT" (the grip hand)."""
	cam = Camera(b, aim)
	L = up + fo
	w = cam.w
	h = 1.0 if trigger == "RIGHT" else -1.0  # +right axis is the trigger side
	support = "LEFT" if trigger == "RIGHT" else "RIGHT"
	bl = math.radians(BLADE if clip == "rifle_raise" else BLADE * 0.5)
	t_sh = (h * w / 2 * math.cos(bl), -w / 2 * math.sin(bl), 0.0)
	s_sh = (-h * w / 2 * math.cos(bl), w / 2 * math.sin(bl), 0.0)
	if clip == "rifle_raise":
		pocket = _v(t_sh, (-h * 0.12 * w, 0.03 * L, -0.06 * L))
		grip = _v(pocket, (0.0, 0.30 * L, -0.12 * L))
		gdir = (0.0, 1.0, 0.0)
		t_pole = (h * 1.0, -0.2, -0.25)       # trigger elbow out, about shoulder high
		s_pole = (-h * 0.15, 0.0, -1.0)       # support elbow under the gun
		head = (h * 0.08 * w, 0.05 * L, -0.12 * L)
	else:
		grip = _v(t_sh, (-h * 0.15 * w, 0.15 * L, -0.75 * L))
		a = math.radians(0.0)  # level in 3D: the facing already tips it down on screen in SE/SW
		gdir = (0.0, math.cos(a), -math.sin(a))
		t_pole = (h * 0.5, -0.5, -0.6)
		s_pole = (-h * 0.3, 0.0, -1.0)
		head = (0.0, 0.0, 0.0)
	wt, et = ik3(t_sh, grip, up, fo, t_pole)
	s = 0.9 * L
	while s > 0.2 * L and _len(_sub(_v(wt, gdir, s), s_sh)) > 0.95 * L:
		s -= 0.25
	ws, es = ik3(s_sh, _v(wt, gdir, s), up, fo, s_pole)
	out = {
		trigger + " SHOULDER": cam(t_sh), support + " SHOULDER": cam(s_sh),
		trigger + " ELBOW": cam(et), trigger + " ARM": cam(wt),
		support + " ELBOW": cam(es), support + " ARM": cam(ws),
		"_gun": (cam(wt), cam(_v(wt, gdir, 1.0))),
	}
	hx, hy = cam(head)[0] - cam.M[0], cam(head)[1] - cam.M[1]
	for k in ("NOSE", "LEFT EYE", "RIGHT EYE", "LEFT EAR", "RIGHT EAR"):
		if k in b:
			out[k] = (b[k][0] + hx, b[k][1] + hy)
	return out
