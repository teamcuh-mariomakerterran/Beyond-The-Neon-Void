"""Placeholder pistol for the aim test (not final art): SE and NE pictures,
the other facings borrow the mirror. Grip pixel = middle of the handle.

    python3 -I tools/gear/make_pilot_pistol.py
"""
import json
import os
from PIL import Image

OUT = os.path.join("assets", "gear", "weapons", "pilot_pistol")
K, D, M, L, N = (12, 10, 14, 255), (38, 40, 48, 255), (70, 74, 86, 255), (120, 126, 140, 255), (90, 255, 240, 255)
# Side view, muzzle right. Rows top to bottom.
ART = [
	"..KKKKKKKKKKKK..",
	".KLLLLLLLLLLLLK.",
	".KMMMMMMMMNMMMMK",
	".KDDDDDDDDDDDDK.",
	".KDDKKKKKKKKKK..",
	".KDDK.KK........",
	"KDDDK..K........",
	"KDDK..K.........",
	"KDDK............",
	"KKK.............",
]
COL = {"K": K, "D": D, "M": M, "L": L, "N": N}


def side() -> Image.Image:
	im = Image.new("RGBA", (16, 10), (0, 0, 0, 0))
	for y, row in enumerate(ART):
		for x, ch in enumerate(row):
			if ch in COL:
				im.putpixel((x, y), COL[ch])
	return im


def main() -> None:
	os.makedirs(OUT, exist_ok=True)
	s = side()
	# 2:1 isometric: SE points down-right, NE up-right (turned, nearest pixel).
	grips = {}
	for name, deg in (("SE", -20), ("NE", 20)):
		im = s.rotate(deg, resample=Image.NEAREST, expand=True)
		im.save(os.path.join(OUT, name + ".png"))
		# Find where the handle pixel (2, 7) of the side view went.
		probe = Image.new("L", s.size, 0)
		probe.putpixel((2, 7), 255)
		pr = probe.rotate(deg, resample=Image.NEAREST, expand=True)
		bb = pr.getbbox() or (0, 0, 1, 1)
		grips[name] = [bb[0], bb[1]]
	json.dump({"point": "hand_r", "grip": grips["SE"], "grips": grips, "z": {}, "rotate": False, "order": 0, "cover": 2},
		open(os.path.join(OUT, "attach.json"), "w"), indent="\t")
	print("wrote", OUT)


if __name__ == "__main__":
	main()
