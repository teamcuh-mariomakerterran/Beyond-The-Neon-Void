"""Draws the pilot weapon art set (a neon-edged blade) for GearAttach.

python3 tools/gear/make_pilot_weapon.py [out_dir]   (default assets/gear/weapons/pilot_blade)

Placeholder art for testing the hand-point system until PixelLab (or Brian)
supplies the real set. Every facing's picture is one 3D pose (POSE) turned
with the body and projected 2:1 isometric, so the blade's angle stays
consistent as the unit turns. Writes all 8 facings plus attach.json with
each picture's grip pixel.
"""
import json
import math
import os
import sys

from PIL import Image

OUTLINE = (12, 10, 22, 255)
STEEL = (196, 210, 228, 255)
STEEL_DARK = (120, 134, 160, 255)
EDGE = (90, 255, 240, 255)      # cyan neon edge
GUARD = (255, 176, 60, 255)     # amber guard
WRAP = (220, 40, 150, 255)      # magenta grip wrap
POMMEL = (60, 56, 80, 255)

SIZE = 48
BLADE = 26
HILT = 7


def draw(angle_deg: float, scale: float = 1.0) -> tuple:
	"""Blade from the grip along angle_deg (0 = screen right, 90 = down),
	`scale` times its full length (foreshortening when it points into the
	screen)."""
	img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
	px = img.load()
	gx, gy = SIZE // 2, SIZE // 2
	a = math.radians(angle_deg)
	dx, dy = math.cos(a), math.sin(a)
	nx, ny = -dy, dx

	def put(x: float, y: float, c: tuple) -> None:
		ix, iy = int(round(x)), int(round(y))
		if 0 <= ix < SIZE and 0 <= iy < SIZE:
			px[ix, iy] = c

	blade = max(int(round(BLADE * scale)), 4)
	hilt = max(int(round(HILT * scale)), 3)
	body = []
	for t in range(-hilt, blade + 1):
		x, y = gx + dx * t, gy + dy * t
		if t < -hilt + 1:
			body.append((x, y, POMMEL, 0))
		elif t < 0:
			body.append((x, y, WRAP, 0))
		elif t <= 1:
			for s in (-2, -1, 0, 1, 2):
				body.append((x + nx * s, y + ny * s, GUARD, 0))
		else:
			body.append((x, y, STEEL, 0))
			body.append((x + nx, y + ny, EDGE if t < blade - 1 else STEEL, 0))
			body.append((x - nx * 0.6, y - ny * 0.6, STEEL_DARK, 0))
	# Outline first (one pixel round everything), then the fill.
	for x, y, _c, _ in body:
		for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			put(x + ox, y + oy, OUTLINE)
	for x, y, c, _ in body:
		put(x, y, c)
	# Held at the middle of the wrap, so the fist sits on the handle.
	mid = -(hilt - 1) / 2.0
	return img, (int(round(gx + dx * mid)), int(round(gy + dy * mid)))


# One held pose for every facing, in the character's own frame:
# (forward, right, up). Low ready: tip forward and down, slightly out to the
# sword hand's side. Each facing's picture is this pose turned with the body
# and projected, so the blade can't point down one way and up the other.
POSE = (0.75, 0.25, -0.6)
# Ground directions of each facing in grid space (+x is screen down-right).
FACING_DIRS = {"SE": (1, 0), "SW": (0, 1), "NW": (-1, 0), "NE": (0, -1),
	"S": (0.7071, 0.7071), "W": (-0.7071, 0.7071), "N": (-0.7071, -0.7071), "E": (0.7071, -0.7071)}
# 2:1 isometric: screen x = gx - gy, screen y = (gx + gy) / 2 - height.
UP_SCALE = 1.0


def project(pose: tuple, facing: str) -> tuple:
	"""Screen angle (degrees) and length factor of the pose for one facing."""
	fx, fy = FACING_DIRS[facing]
	rx, ry = -fy, fx  # the character's right, seen from above
	f, r, u = pose
	gx = f * fx + r * rx
	gy = f * fy + r * ry
	sx = gx - gy
	sy = (gx + gy) / 2.0 - u * UP_SCALE
	full = math.sqrt(sum(c * c for c in pose))
	# Length on screen relative to the same blade lying flat across the view.
	return math.degrees(math.atan2(sy, sx)), min(math.hypot(sx, sy) / (full * 1.0), 1.0)


def project_all(pose: tuple) -> dict:
	return {f: project(pose, f) for f in FACING_DIRS}


def main() -> None:
	out = sys.argv[1] if len(sys.argv) > 1 else "assets/gear/weapons/pilot_blade"
	os.makedirs(out, exist_ok=True)
	grips = {}
	for facing, (ang, scale) in project_all(POSE).items():
		img, grip = draw(ang, scale)
		img.save(os.path.join(out, facing + ".png"))
		grips[facing] = list(grip)
	meta = {"point": "hand_r", "grip": grips["SE"], "grips": grips, "z": {}, "rotate": False, "order": 0, "cover": 2}
	with open(os.path.join(out, "attach.json"), "w", encoding="utf-8") as f:
		json.dump(meta, f, indent="\t")
		f.write("\n")
	print("wrote", out)


if __name__ == "__main__":
	main()
