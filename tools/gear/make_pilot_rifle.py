"""Placeholder rifle for the two-hand aim test (not final art): SE and NE
pictures turned to the aimed rifle line, other facings borrow the mirror.
Grip pixel = where the fist closes on the pistol grip, just under the receiver,
so the barrel rests on the front hand and the stock tucks under the arm
(Brian's marks, 2026-11-08; the higher shoulder hold is pilot_launcher).

    python3 -I tools/gear/make_pilot_rifle.py
"""
import json
import os
from PIL import Image

OUT = os.path.join("assets", "gear", "weapons", "pilot_rifle")
COL = {"K": (12, 10, 14, 255), "D": (38, 40, 48, 255), "M": (70, 74, 86, 255), "L": (120, 126, 140, 255), "N": (90, 255, 240, 255), "B": (60, 44, 36, 255)}
# Side view, muzzle right: stock (B) left, receiver, long barrel.
ART = [
	"..........KKKKKKKK..............",
	"KKKKK....KLLLLLLLLKKKKKKKKKKKK..",
	"KBBBBKKKKKMMMMNMMMMMMMMMMMMMMMKK",
	"KBBBBBBBBKDDDDDDDDDDDDDDDDDDDDK.",
	".KBBBBBBBKDDDKKKDDKKKKKKKKKKKK..",
	"..KKKKKKKKDDK..KDDK.............",
	"..........KDDK..KK..............",
	"...........KDK..................",
	"...........KK...................",
]
LINE_DEG = 18  # SE rifle line in the aimed frames (aim_pose.py rifle poses on #5)


def side() -> Image.Image:
	im = Image.new("RGBA", (len(ART[0]), len(ART)), (0, 0, 0, 0))
	for y, row in enumerate(ART):
		for x, ch in enumerate(row):
			if ch in COL:
				im.putpixel((x, y), COL[ch])
	return im


def main() -> None:
	os.makedirs(OUT, exist_ok=True)
	s = side()
	grips = {}
	for name, deg in (("SE", -LINE_DEG), ("NE", LINE_DEG)):
		s.rotate(deg, resample=Image.NEAREST, expand=True).save(os.path.join(OUT, name + ".png"))
		probe = Image.new("L", s.size, 0)
		probe.putpixel((12, 4), 255)
		bb = probe.rotate(deg, resample=Image.NEAREST, expand=True).getbbox() or (0, 0, 1, 1)
		grips[name] = [bb[0], bb[1]]
	json.dump({"point": "hand_r", "grip": grips["SE"], "grips": grips, "z": {}, "rotate": True, "order": 0, "cover": 2, "cover_l": 2},
		open(os.path.join(OUT, "attach.json"), "w"), indent="\t")
	print("wrote", OUT)


if __name__ == "__main__":
	main()
