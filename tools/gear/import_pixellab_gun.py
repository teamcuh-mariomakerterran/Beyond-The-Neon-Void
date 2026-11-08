"""Turn a PixelLab 8-rotation gun object (assets/gear/source/pixellab_guns/<slug>)
into a game art set (assets/gear/weapons/<slug>): the four diagonal pictures,
scaled to fit a unit's hand, plus attach.json.

    python3 -I tools/gear/import_pixellab_gun.py <slug> <scale> [--grip SE:x,y ...] [--sheet out.png]
    python3 -I tools/gear/import_pixellab_gun.py <slug> <scale> --side x,y [--deg 20] [--two-hand]

--side uses only the side view (E), scaled, with the grip pixel x,y in it, and
turns it to the aim line for SE / NE (W facings borrow the mirror), the same
one-picture projection as the placeholders. --two-hand also redraws the
front fist over the barrel (cover_l).

Scale is nearest-neighbour (keeps the black outline). Grips are pixels in the
scaled picture, per facing; --sheet draws the scaled pictures on a grid with
the grips marked so they can be checked and moved. Source objects come from
GET /objects/{id}/spritesheet (free).
"""
import json
import os
import sys
from PIL import Image, ImageDraw

SRC = os.path.join("assets", "gear", "source", "pixellab_guns")
OUT = os.path.join("assets", "gear", "weapons")
FACE = {"south-east": "SE", "north-east": "NE", "south-west": "SW", "north-west": "NW",
	"south": "S", "north": "N", "east": "E", "west": "W"}


def cells(slug: str) -> dict:
	d = os.path.join(SRC, slug)
	m = json.load(open(os.path.join(d, slug + ".json")))["spritesheet"]
	cw, ch = m["cell_size"]["width"], m["cell_size"]["height"]
	sh = Image.open(os.path.join(d, slug + ".png")).convert("RGBA")
	return {FACE[n]: sh.crop((i * cw, 0, (i + 1) * cw, ch)) for i, n in enumerate(m["rows"][0]["directions"])}


def scaled(im: Image.Image, s: float) -> Image.Image:
	im = im.crop(im.getbbox())
	if s == 1.0:
		return im
	return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.NEAREST)


def turn(p: Image.Image, deg: float, up: int = 8) -> Image.Image:
	"""Turns pixel art without shredding it: enlarge, turn, sample each pixel's middle."""
	b = p.resize((p.width * up, p.height * up), Image.NEAREST).rotate(deg, resample=Image.NEAREST, expand=True)
	w, h = b.width // up, b.height // up
	out = Image.new("RGBA", (w, h))
	for y in range(h):
		for x in range(w):
			out.putpixel((x, y), b.getpixel((x * up + up // 2, y * up + up // 2)))
	return out


def side(slug: str, s: float, grip: list, deg: float, two_hand: bool) -> None:
	p = scaled(cells(slug)["E"], s)
	d = os.path.join(OUT, slug)
	os.makedirs(d, exist_ok=True)
	grips = {}
	for f, r in (("SE", -deg), ("NE", deg)):
		turn(p, r).save(os.path.join(d, f + ".png"))
		probe = Image.new("RGBA", p.size, (0, 0, 0, 0))
		probe.putpixel((grip[0], grip[1]), (255, 255, 255, 255))
		bb = turn(probe, r).getbbox() or (0, 0, 1, 1)
		grips[f] = [bb[0], bb[1]]
	meta = {"point": "hand_r", "grip": grips["SE"], "grips": grips, "z": {}, "rotate": True, "order": 0, "cover": 2,
		"source": "PixelLab object %s, side view x%.2f turned %d deg, tools/gear/import_pixellab_gun.py" % (slug, s, deg)}
	if two_hand:
		meta["cover_l"] = 2
	json.dump(meta, open(os.path.join(d, "attach.json"), "w"), indent="\t")
	print("wrote", d, grips)


def main() -> None:
	a = sys.argv[1:]
	if "--side" in a:
		g = [int(v) for v in a[a.index("--side") + 1].split(",")]
		deg = float(a[a.index("--deg") + 1]) if "--deg" in a else 20.0
		side(a[0], float(a[1]), g, deg, "--two-hand" in a)
		return
	slug, s = a[0], float(a[1])
	grips, sheet = {}, ""
	i = 2
	while i < len(a):
		if a[i] == "--grip":
			f, xy = a[i + 1].split(":")
			grips[f] = [int(v) for v in xy.split(",")]
			i += 2
		elif a[i] == "--sheet":
			sheet = a[i + 1]
			i += 2
		else:
			i += 1
	c = cells(slug)
	pics = {f: scaled(c[f], s) for f in ("SE", "NE", "SW", "NW")}
	if sheet:
		k = 16
		W = sum(p.width * k + 40 for p in pics.values())
		H = max(p.height for p in pics.values()) * k + 40
		o = Image.new("RGBA", (W, H), (28, 30, 40, 255))
		dr = ImageDraw.Draw(o)
		x0 = 0
		for f, p in pics.items():
			o.alpha_composite(p.resize((p.width * k, p.height * k), Image.NEAREST), (x0, 30))
			for gx in range(p.width + 1):
				dr.line([(x0 + gx * k, 30), (x0 + gx * k, 30 + p.height * k)], fill=(55, 55, 75))
			for gy in range(p.height + 1):
				dr.line([(x0, 30 + gy * k), (x0 + p.width * k, 30 + gy * k)], fill=(55, 55, 75))
			for gx in range(0, p.width, 2):
				dr.text((x0 + gx * k + 2, 18), str(gx), fill=(200, 200, 0))
			for gy in range(0, p.height, 2):
				dr.text((x0 + p.width * k + 2, 30 + gy * k + 2), str(gy), fill=(200, 200, 0))
			dr.text((x0 + 2, 2), "%s %dx%d" % (f, p.width, p.height), fill=(230, 230, 240))
			if f in grips:
				gx, gy = grips[f]
				dr.ellipse((x0 + gx * k + 2, 30 + gy * k + 2, x0 + gx * k + k - 2, 30 + gy * k + k - 2), outline=(0, 255, 0), width=3)
			x0 += p.width * k + 40
		o.save(sheet)
		print("sheet", sheet)
	if len(grips) == 4:
		d = os.path.join(OUT, slug)
		os.makedirs(d, exist_ok=True)
		for f, p in pics.items():
			p.save(os.path.join(d, f + ".png"))
		json.dump({"point": "hand_r", "grip": grips["SE"], "grips": grips, "z": {}, "rotate": True, "order": 0, "cover": 2,
			"source": "PixelLab object (%s), scale %.2f, tools/gear/import_pixellab_gun.py" % (slug, s)},
			open(os.path.join(d, "attach.json"), "w"), indent="\t")
		print("wrote", d)


if __name__ == "__main__":
	main()
