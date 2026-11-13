"""Brian's throwables sheet (7x7, 2026-11-13) -> grenade and land-mine art. Free.

    python3 -I tools/gear/import_throwables_sheet.py assets/gear/source/throwables_sheet_49.png

Rows 1-2 are grenades, rows 3-4 land mines (Brian). The sheet is 4x pixel art
on white; each item is cut at native size with the sheet's own drop shadow
taken off (the shadow is the flat lavender-grey reached from the white
outside the outline, so greys inside the item stay). Writes
assets/gear/throwables/<grenade|mine>_NN/:
  item.png    no shadow: in the hand, in flight, the inventory icon
  ground.png  mines only: as drawn for a mine placed on a tile (the sheet's mines
              have no drop shadow, so it matches item.png; the game draws one)
  attach.json grip = the item's centre on hand_r (thrown with one hand); for
              mines "ground_anchor" = the tile point (base centre)
Rows 5-7 (knives, stars, darts, vials, packs) are not cut yet.
"""
import json
import os
import sys

from PIL import Image

SCALE = 4
GRID = 7
ROWS = {0: "grenade", 1: "grenade", 2: "mine", 3: "mine"}
SHADOWS = [(122, 122, 136), (105, 114, 135)]  # the drop shadow and its darker rim


def near(p, c, tol=6):
	return abs(p[0] - c[0]) <= tol and abs(p[1] - c[1]) <= tol and abs(p[2] - c[2]) <= tol


def components(sheet: str):
	"""Per grid cell (row, col): (item pixels, shadow pixels) on the native sheet.
	Shadow = the shadow colour reached from the white outside (8-connected), so a
	grey inside an outline stays. Item = the rest that isn't white, grouped by
	outline (8-connected); a piece goes to the cell its centre is in, and a speck
	under 20 px joins the nearest big piece within 6 px or is dropped."""
	src = Image.open(sheet).convert("RGB")
	n = src.resize((src.width // SCALE, src.height // SCALE), Image.NEAREST)
	px = n.load()
	W, H = n.size
	white = lambda p: p[0] > 240 and p[1] > 240 and p[2] > 240
	N8 = [(dx, dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy]
	out, shadow = set(), set()
	st = [(x, y) for x in range(W) for y in (0, H - 1)] + [(x, y) for y in range(H) for x in (0, W - 1)]
	while st:
		q = st.pop()
		if q in out or q in shadow:
			continue
		p = px[q]
		if white(p):
			out.add(q)
		elif any(near(p, c) for c in SHADOWS):
			shadow.add(q)
		else:
			continue
		for d in N8:
			r = (q[0] + d[0], q[1] + d[1])
			if 0 <= r[0] < W and 0 <= r[1] < H:
				st.append(r)
	solid = lambda q: q not in out and q not in shadow
	seen, blobs = set(), []
	for y in range(H):
		for x in range(W):
			if (x, y) in seen or not solid((x, y)):
				continue
			b, st = [], [(x, y)]
			seen.add((x, y))
			while st:
				q = st.pop()
				b.append(q)
				for d in N8:
					r = (q[0] + d[0], q[1] + d[1])
					if 0 <= r[0] < W and 0 <= r[1] < H and r not in seen and solid(r):
						seen.add(r)
						st.append(r)
			blobs.append(b)
	cw = W / GRID
	cen = lambda b: (sum(p[0] for p in b) / len(b), sum(p[1] for p in b) / len(b))
	cell = lambda c: (int(c[1] // cw), int(c[0] // cw))
	big = {}
	for b in blobs:
		if len(b) >= 20:
			big.setdefault(cell(cen(b)), []).extend(b)
	for b in blobs:
		if len(b) >= 20:
			continue
		cx, cy = cen(b)
		best, bd = None, 7
		for k, g in big.items():
			d = min(abs(x - cx) + abs(y - cy) for x, y in g)
			if d < bd:
				best, bd = k, d
		if best:
			big[best].extend(b)
	# a shadow pixel belongs to the item it lies under (its column span, bottom
	# just above); the shadow of a row spills past the grid line into the next
	box = {k: (min(x for x, _ in g), max(x for x, _ in g), max(y for _, y in g)) for k, g in big.items()}
	sh = {}
	for q in shadow:
		best, bd = None, 9
		for k, (x0, x1, yb) in box.items():
			if x0 - 3 <= q[0] <= x1 + 3 and -3 <= q[1] - yb < bd:
				best, bd = k, q[1] - yb
		if best:
			sh.setdefault(best, []).append(q)
	return px, {k: (v, sh.get(k, [])) for k, v in big.items()}


def picture(px, pts):
	xs = [p[0] for p in pts]
	ys = [p[1] for p in pts]
	im = Image.new("RGBA", (max(xs) - min(xs) + 1, max(ys) - min(ys) + 1))
	ip = im.load()
	for x, y in pts:
		ip[x - min(xs), y - min(ys)] = px[x, y] + (255,)
	return im, (min(xs), min(ys))


def main() -> None:
	sheet = sys.argv[1]
	px, parts = components(sheet)
	count = {}
	for (r, c) in sorted(parts):
		if r not in ROWS:
			continue
		kind = ROWS[r]
		count[kind] = count.get(kind, 0) + 1
		item_pts, sh_pts = parts[(r, c)]
		item, _ = picture(px, item_pts)
		d = os.path.join("assets", "gear", "throwables", "%s_%02d" % (kind, count[kind]))
		os.makedirs(d, exist_ok=True)
		item.save(os.path.join(d, "item.png"))
		meta = {"kind": kind, "point": "hand_r", "grip": [item.width // 2, item.height // 2],
			"rotate": False, "cover": 2,
			"source": "Brian's throwables sheet %s, row %d col %d, tools/gear/import_throwables_sheet.py" % (os.path.basename(sheet), r + 1, c + 1)}
		if kind == "mine":
			full, o = picture(px, item_pts + sh_pts)
			full.save(os.path.join(d, "ground.png"))
			# the sheet's mines have no drop shadow: the tile point is the base's centre
			meta["ground_anchor"] = [full.width // 2, full.height - 3]
			if sh_pts:
				meta["ground_anchor"] = [round(sum(x for x, _ in sh_pts) / len(sh_pts)) - o[0], round(sum(y for _, y in sh_pts) / len(sh_pts)) - o[1]]
		json.dump(meta, open(os.path.join(d, "attach.json"), "w"), indent="\t")
		print(d, item.size)


if __name__ == "__main__":
	main()
