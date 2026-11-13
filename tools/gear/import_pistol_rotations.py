"""Put the PixelLab-drawn back views of the sheet pistols into the game sets. Free.

    python3 -I tools/gear/import_pistol_rotations.py [neon_pistol_01 ...]   # default: every one drawn

Source: assets/gear/source/pistol_rotations/<name>/b/NW.png (tools/pixellab/rotate_gun.py b,
Brian's pick 2026-11-13). Writes assets/gear/weapons/<name>/NW.png (the drawing) and NE.png
(its mirror), and their axis + grip in attach.json, fitted like the SW drawing
(import_pistol_sheet.meta: barrel from the slide's top edge, grip at the handle top).
SW/SE are untouched.
"""
import glob
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_pistol_sheet import meta  # noqa: E402

SRC = os.path.join("assets", "gear", "source", "pistol_rotations")
DST = os.path.join("assets", "gear", "weapons")


def main() -> None:
	names = sys.argv[1:] or sorted(os.path.basename(os.path.dirname(os.path.dirname(p)))
		for p in glob.glob(os.path.join(SRC, "*", "b", "NW.png")))
	for n in names:
		im = Image.open(os.path.join(SRC, n, "b", "NW.png")).convert("RGBA")
		im = im.crop(im.getbbox())
		m = meta(im)
		g, a = m["grip"], m["axis"]
		mir = im.transpose(Image.FLIP_LEFT_RIGHT)
		gm = [im.width - 1 - g[0], g[1]]
		d = os.path.join(DST, n)
		im.save(os.path.join(d, "NW.png"))
		mir.save(os.path.join(d, "NE.png"))
		p = os.path.join(d, "attach.json")
		j = json.load(open(p))
		j["grips"]["NW"], j["grips"]["NE"] = g, gm
		j["axis"]["NW"], j["axis"]["NE"] = a, round(180 - a, 1)
		j["source"] = j["source"].split(" | ")[0] + " | NW drawn by PixelLab rotate from the SW drawing, NE its mirror (tools/gear/import_pistol_rotations.py)"
		json.dump(j, open(p, "w"), indent="\t")
		print(n, "NW axis", a, "grip", g)


if __name__ == "__main__":
	main()
