"""Cut a character's gear out against a base body (same character, stripped
state): dressed minus base, per rotation, without the body's own skin.

    python3 -I tools/pixellab/cut_parts.py <dressed.zip>:<state> <base.zip>:<state> <out_dir> [--detail <base_detail.json>] [--sheet out.png]

Writes <out_dir>/<facing>.png (the whole outfit layer per rotation). Free.
pilot.diff_layer keeps every pixel that differs from the base, which also
keeps the dressed character's own skin wherever its face, neck or hands sit
a pixel off the base's; those would show as seams on a recoloured body. So
pixels whose colour is within reach of the base's skin colours are dropped.
"""
import io
import json
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot  # noqa: E402

DIRS = {"south": "S", "south-east": "SE", "east": "E", "north-east": "NE", "north": "N", "north-west": "NW", "west": "W", "south-west": "SW"}
FACING_NAME = {v: k for k, v in DIRS.items()}


def load(spec: str) -> dict:
	from PIL import Image
	path, state = spec.rsplit(":", 1)
	z = zipfile.ZipFile(path)
	return {f: Image.open(io.BytesIO(z.read("%s/rotations/%s.png" % (state, d)))).convert("RGBA") for d, f in DIRS.items()
		if "%s/rotations/%s.png" % (state, d) in z.namelist()}


def skinlike(p) -> bool:
	r, g, b = p[0], p[1], p[2]
	return r >= 110 and r > g > b and g >= 0.55 * r and b >= 0.35 * r


def skin_palette(base: dict) -> list:
	cols = set()
	for im in base.values():
		for p in (im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()):
			if p[3] >= 128 and skinlike(p):
				cols.add(p[:3])
	return list(cols)


def blendlike(p) -> bool:
	"""Light, warm, greyish halfway shades an artist uses between skin and
	hair or outline (e.g. 148,129,131)."""
	r, g, b = p[0], p[1], p[2]
	return r >= 110 and r >= g and r >= b and max(r, g, b) - min(r, g, b) <= 45


def strip_skin(layer, palette: list, reach: int = 45, dressed=None):
	px = layer.load()
	w, h = layer.size
	removed = set()
	for y in range(h):
		for x in range(w):
			p = px[x, y]
			if p[3] < 128 or not skinlike(p):
				continue
			if any(abs(p[0] - c[0]) + abs(p[1] - c[1]) + abs(p[2] - c[2]) < reach * 2 for c in palette):
				px[x, y] = (0, 0, 0, 0)
				removed.add((x, y))
	# Blend shades touching removed skin (or the face hole) go too.
	for y in range(h):
		for x in range(w):
			p = px[x, y]
			if p[3] < 128 or not blendlike(p):
				continue
			def hole(q):
				# A gap inside the dressed figure: skin the cut left to the base.
				return 0 <= q[0] < w and 0 <= q[1] < h and px[q[0], q[1]][3] < 128 and (dressed is None or dressed.getpixel(q)[3] >= 128)
			if any((x + dx, y + dy) in removed or hole((x + dx, y + dy)) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
				px[x, y] = (0, 0, 0, 0)
	return layer


def keep_outline(layer, dressed):
	"""Dark outline pixels of the dressed character that border its gear stay
	with the gear even where the base has outline in the same spot (else the
	hair's back edge goes missing and the base scalp shows there)."""
	px, dp = layer.load(), dressed.load()
	w, h = layer.size
	add = []
	for y in range(h):
		for x in range(w):
			p = dp[x, y]
			if px[x, y][3] >= 128 or p[3] < 128 or 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2] >= 40:
				continue
			# Only the figure's outer outline (next to empty space), not inner
			# lines like the eyes and mouth.
			if not any(not (0 <= x + dx < w and 0 <= y + dy < h) or dp[x + dx, y + dy][3] < 128 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
				continue
			if any(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] >= 128 and 0.3 * px[x + dx, y + dy][0] + 0.59 * px[x + dx, y + dy][1] + 0.11 * px[x + dx, y + dy][2] >= 25
				for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
				add.append((x, y))
	for x, y in add:
		px[x, y] = dp[x, y]
	return layer


def keep_eyes(layer, dressed, base, eyes: list):
	"""The dressed character's eyes come over whole: outline, whites, glint
	and iris. A plain diff drops the pixels that match the base's own eye
	and leaves the base's eye showing around the new iris (a red blob).
	Inside a small box round each eye every dressed pixel is kept; where the
	dressed face is skin but the base has eye there, the base's skin is laid
	over it so the base eye doesn't peek out. Eye whites only stay where
	the base has a white too. An eye under gear (visor, mask) takes the
	outfit's art whole instead."""
	px, dp, bp = layer.load(), dressed.load(), base.load()
	w, h = layer.size
	for ex, ey in eyes:
		x0, x1, y0, y1 = int(round(ex)) - 3, int(round(ex)) + 3, int(round(ey)) - 2, int(round(ey)) + 2
		box = [(x, y) for y in range(max(0, y0), min(h, y1 + 1)) for x in range(max(0, x0), min(w, x1 + 1))]
		skins = [bp[x, y] for x, y in box if bp[x, y][3] >= 128 and skinlike(bp[x, y])]
		if not skins:
			continue
		skin = max(set(skins), key=skins.count)
		drawn = [dp[x, y] for x, y in box if dp[x, y][3] >= 128]
		if drawn and sum(1 for d in drawn if skinlike(d)) < 0.5 * len(drawn):
			# Gear over the eye (visor, mask, lens): the outfit's art there
			# comes over whole, even its skin-toned pixels (a pink lens).
			for x, y in box:
				d, b = dp[x, y], bp[x, y]
				if d[3] >= 128 and (b[3] < 128 or sum(abs(d[i] - b[i]) for i in range(3)) > 30):
					px[x, y] = d
			continue
		for x, y in box:
			d = dp[x, y]
			if d[3] < 128:
				continue
			b = bp[x, y]
			white = d[0] >= 220 and d[1] >= 220 and d[2] >= 220
			if white and not (b[3] >= 128 and min(b[:3]) >= 200):
				# Eye whites follow the base (one white pixel per eye, not two).
				px[x, y] = b if b[3] >= 128 and skinlike(b) else skin
			elif y >= int(round(ey)) and b[3] >= 128 and sum(abs(b[i] - skin[i]) for i in range(3)) < 50:
				# Below the eye's middle the shape follows the base: where the
				# base face is plain skin, no extra iris or lid pixels.
				px[x, y] = b
			elif not skinlike(d):
				px[x, y] = d
			elif not skinlike(bp[x, y]):
				px[x, y] = skin
	return layer


def main() -> None:
	from PIL import Image, ImageDraw
	a = sys.argv[1:]
	dressed, base, out = load(a[0]), load(a[1]), a[2]
	os.makedirs(out, exist_ok=True)
	pal = skin_palette(base)
	detail = json.load(open(a[a.index("--detail") + 1])) if "--detail" in a else None
	layers = {}
	for f in dressed:
		lay = strip_skin(pilot.diff_layer(base[f], dressed[f]), pal, dressed=dressed[f])
		lay = keep_outline(lay, dressed[f])
		if detail:
			kp = detail["skeletons"]["2d_references"][FACING_NAME[f]]["keypoints"]
			w, h = lay.size
			eyes = [(kp[k]["x"] * (w - 1), kp[k]["y"] * (h - 1)) for k in ("LEFT EYE", "RIGHT EYE") if k in kp]
			lay = keep_eyes(lay, dressed[f], base[f], eyes)
		lay.save(os.path.join(out, f + ".png"))
		# The dressed silhouette: head parts clip the base head to it, so no
		# base ear or scalp shows where the dressed character had hair.
		mask = dressed[f].getchannel("A").point(lambda v: 255 if v >= 128 else 0)
		mask.save(os.path.join(out, f + "_mask.png"))
		layers[f] = lay
	print("skin colours", len(pal), "layers", sorted(layers))
	if "--sheet" in a:
		k, C = 5, 60 * 5
		order = ["SE", "SW", "NE", "NW"]
		o = Image.new("RGBA", (4 * C, len(order) * C + 20), (28, 30, 40, 255))
		d = ImageDraw.Draw(o)
		for i, t in enumerate(["dressed", "base", "cut layer", "base + layer"]):
			d.text((i * C + 4, 4), t, fill=(230, 230, 240))
		for r, f in enumerate(order):
			re = base[f].copy()
			re.alpha_composite(layers[f])
			for c, im in enumerate([dressed[f], base[f], layers[f], re]):
				o.alpha_composite(im.resize((C, C), Image.NEAREST), (c * C, 20 + r * C))
		o.save(a[a.index("--sheet") + 1])


if __name__ == "__main__":
	main()
