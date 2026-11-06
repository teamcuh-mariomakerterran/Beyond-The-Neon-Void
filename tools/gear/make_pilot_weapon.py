"""Draws the pilot weapon art set (a neon-edged blade) for GearAttach.

python3 tools/gear/make_pilot_weapon.py [out_dir]   (default assets/gear/weapons/pilot_blade)

Placeholder art for testing the hand-point system until PixelLab (or Brian)
supplies the real set. Writes SE.png and NE.png (SW / NW borrow them,
mirrored) plus attach.json with the grip pixel of each.
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


def draw(angle_deg: float) -> tuple:
	"""Blade from the grip along angle_deg (0 = screen right, 90 = down)."""
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

	body = []
	for t in range(-HILT, BLADE + 1):
		x, y = gx + dx * t, gy + dy * t
		if t < -HILT + 1:
			body.append((x, y, POMMEL, 0))
		elif t < 0:
			body.append((x, y, WRAP, 0))
		elif t <= 1:
			for s in (-2, -1, 0, 1, 2):
				body.append((x + nx * s, y + ny * s, GUARD, 0))
		else:
			body.append((x, y, STEEL, 0))
			body.append((x + nx, y + ny, EDGE if t < BLADE - 1 else STEEL, 0))
			body.append((x - nx * 0.6, y - ny * 0.6, STEEL_DARK, 0))
	# Outline first (one pixel round everything), then the fill.
	for x, y, _c, _ in body:
		for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			put(x + ox, y + oy, OUTLINE)
	for x, y, c, _ in body:
		put(x, y, c)
	# Held at the middle of the wrap, so the fist sits on the handle.
	mid = -(HILT - 1) / 2.0
	return img, (int(round(gx + dx * mid)), int(round(gy + dy * mid)))


def main() -> None:
	out = sys.argv[1] if len(sys.argv) > 1 else "assets/gear/weapons/pilot_blade"
	os.makedirs(out, exist_ok=True)
	grips = {}
	# SE: lowered, tip down and forward (toward the viewer's right).
	# NE: carried up and back over the shoulder side, away from the viewer.
	for facing, ang in (("SE", 62.0), ("NE", -58.0)):
		img, grip = draw(ang)
		img.save(os.path.join(out, facing + ".png"))
		grips[facing] = list(grip)
	meta = {"point": "hand_r", "grip": grips["SE"], "grips": grips, "z": {}, "rotate": False, "order": 0, "cover": 2}
	with open(os.path.join(out, "attach.json"), "w", encoding="utf-8") as f:
		json.dump(meta, f, indent="\t")
		f.write("\n")
	print("wrote", out)


if __name__ == "__main__":
	main()
