"""Brian's pistol sheet -> one gear folder per pistol. Free (no PixelLab).

    python3 -I tools/gear/import_pistol_sheet.py assets/gear/source/pistols_sheet_49.png [scale] [prefix]

The sheet is pixel art scaled up (4x for the 49-pistol sheet): it is sampled
back to native size, each pistol cut out by its outline (lasers and holograms
kept with the nearest gun), and written as assets/gear/weapons/<prefix>_NN/.
Every pistol is drawn once, pointing down-left (SW); SE/NE use the mirror,
NW the drawing, and the game turns it onto the aim. The barrel angle is a fit
of the slide's top edge (within ~2 degrees of Brian's marks on the older
pistols); the grip is the top of the handle. Both go in attach.json.
"""
import json
import math
import os
import sys

from PIL import Image


def cut(sheet: str, scale: int):
	src = Image.open(sheet).convert("RGB")
	n = src.resize((src.width // scale, src.height // scale), Image.NEAREST)
	px = n.load()
	W, H = n.size
	solid = lambda p: not (p[0] > 245 and p[1] > 245 and p[2] > 245)
	seen, blobs = set(), []
	for y in range(H):
		for x in range(W):
			if (x, y) in seen or not solid(px[x, y]):
				continue
			st, b = [(x, y)], []
			seen.add((x, y))
			while st:
				q = st.pop()
				b.append(q)
				for dx in (-1, 0, 1):
					for dy in (-1, 0, 1):
						r = (q[0] + dx, q[1] + dy)
						if 0 <= r[0] < W and 0 <= r[1] < H and r not in seen and solid(px[r[0], r[1]]):
							seen.add(r)
							st.append(r)
			blobs.append(b)
	cen = lambda b: (sum(p[0] for p in b) / len(b), sum(p[1] for p in b) / len(b))
	big = [list(b) for b in blobs if len(b) >= 60]
	# reading order of the sheet's grid: row (floor of the centre over the cell height), then x
	cell = H / max(1, round(len(big) ** 0.5))
	big.sort(key=lambda b: (int(cen(b)[1] // cell), cen(b)[0]))
	for b in blobs:
		if len(b) >= 60:
			continue
		cx, cy = cen(b)
		def dist(g):
			xs = [p[0] for p in g]
			ys = [p[1] for p in g]
			return max(min(xs) - cx, 0, cx - max(xs)) + max(min(ys) - cy, 0, cy - max(ys))
		k = min(range(len(big)), key=lambda i: dist(big[i]))
		if dist(big[k]) < 8:
			big[k] += b
	out = []
	for g in big:
		xs = [p[0] for p in g]
		ys = [p[1] for p in g]
		im = Image.new("RGBA", (max(xs) - min(xs) + 1, max(ys) - min(ys) + 1))
		p2 = im.load()
		for x, y in g:
			p2[x - min(xs), y - min(ys)] = px[x, y] + (255,)
		out.append(im)
	return out


def meta(im) -> dict:
	px = im.load()
	W, H = im.size
	S = [(x, y) for y in range(H) for x in range(W) if px[x, y][3] > 127]
	cols = {}
	for x, y in S:
		cols.setdefault(x, []).append(y)
	xm = min(x for x, ys in cols.items() if len(ys) >= 3)
	top = [(x, y) for x, y in S if y <= min(y for _, y in S) + H * 0.25]
	rear = max(top, key=lambda q: q[0])
	tops = [(x, min(cols[x])) for x in range(xm, rear[0] + 1) if x in cols]
	n = len(tops)
	mx = sum(x for x, _ in tops) / n
	my = sum(y for _, y in tops) / n
	k = sum((x - mx) * (y - my) for x, y in tops) / max(1e-6, sum((x - mx) ** 2 for x, _ in tops))
	axis = math.degrees(math.atan2(-k, -1.0))
	low = [(x, y) for x, y in S if y >= H * 0.65 and x >= W * 0.5]
	return {"axis": round(axis, 1), "grip": [round(sum(x for x, _ in low) / len(low)), round(H * 0.62)]}


def main() -> None:
	sheet = sys.argv[1]
	scale = int(sys.argv[2]) if len(sys.argv) > 2 else 4
	prefix = sys.argv[3] if len(sys.argv) > 3 else "neon_pistol"
	for i, im in enumerate(cut(sheet, scale), 1):
		d = os.path.join("assets", "gear", "weapons", "%s_%02d" % (prefix, i))
		os.makedirs(d, exist_ok=True)
		m = meta(im)
		mir = im.transpose(Image.FLIP_LEFT_RIGHT)
		im.save(os.path.join(d, "SW.png"))
		im.save(os.path.join(d, "NW.png"))
		mir.save(os.path.join(d, "SE.png"))
		mir.save(os.path.join(d, "NE.png"))
		g, a = m["grip"], m["axis"]
		gm = [im.width - 1 - g[0], g[1]]
		json.dump({"point": "hand_r", "grip": g, "grips": {"SW": g, "NW": g, "SE": gm, "NE": gm},
			"z": {}, "rotate": True, "order": 0, "cover": 2,
			"axis": {"SW": a, "NW": a, "SE": round(180 - a, 1), "NE": round(180 - a, 1)},
			"source": "Brian's pistol sheet %s #%d, drawn SW (SE/NE mirrored), axis fit + grip at the handle top, tools/gear/import_pistol_sheet.py" % (os.path.basename(sheet), i)},
			open(os.path.join(d, "attach.json"), "w"), indent="\t")
	print("imported", i, "pistols as", prefix + "_01..%02d" % i)


if __name__ == "__main__":
	main()
