"""Split an outfit layer (tools/pixellab/cut_parts.py) into parts along the
base body's skeleton, per facing: head (hair, masks, eye pieces), torso,
upper and lower arms, thighs, shins (with the shoes) and held items.

    python3 -I tools/pixellab/split_parts.py <layer_dir> <base_detail.json> <base.zip>:<state> [--sheet out.png]

Writes <layer_dir>/parts/<FACING>_<part>.png and <layer_dir>/parts/bones.json
(the standing skeleton the parts were cut on, canvas pixels), so a part can
later ride its bone in any animation frame. Free.

Each layer pixel goes to the nearest bone; pixels outside the base body that
form a long thin shape away from the body (a cane, a weapon) are a held item.
"""
import io
import json
import math
import os
import sys
import zipfile

DIRS = {"south-east": "SE", "south-west": "SW", "north-east": "NE", "north-west": "NW", "south": "S", "north": "N", "east": "E", "west": "W"}
BONES = {
	"torso": ("NECK", "HIP_MID"),
	"upper_arm_r": ("RIGHT SHOULDER", "RIGHT ELBOW"), "forearm_r": ("RIGHT ELBOW", "RIGHT ARM"),
	"upper_arm_l": ("LEFT SHOULDER", "LEFT ELBOW"), "forearm_l": ("LEFT ELBOW", "LEFT ARM"),
	"thigh_r": ("RIGHT HIP", "RIGHT KNEE"), "shin_r": ("RIGHT KNEE", "RIGHT LEG"),
	"thigh_l": ("LEFT HIP", "LEFT KNEE"), "shin_l": ("LEFT KNEE", "LEFT LEG"),
	"head": ("NECK", "HEAD_TOP"),
}
COLOURS = {"head": (255, 220, 60), "torso": (90, 200, 255), "upper_arm_r": (255, 90, 90), "forearm_r": (255, 160, 160),
	"upper_arm_l": (90, 255, 120), "forearm_l": (170, 255, 190), "thigh_r": (200, 90, 255), "shin_r": (230, 170, 255),
	"thigh_l": (255, 150, 40), "shin_l": (255, 200, 130), "held": (255, 255, 255), "foot_r": (120, 120, 255), "foot_l": (60, 200, 200), "skirt": (255, 120, 200)}


def seg_dist(p, a, b):
	ax, ay = a
	bx, by = b
	dx, dy = bx - ax, by - ay
	L = dx * dx + dy * dy
	t = 0.0 if L == 0 else max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / L))
	return math.hypot(p[0] - (ax + t * dx), p[1] - (ay + t * dy))


def joints(detail: dict, d: str, w: int, h: int) -> dict:
	kp = detail["skeletons"]["2d_references"][d]["keypoints"]
	j = {k: (v["x"] * (w - 1), v["y"] * (h - 1)) for k, v in kp.items()}
	j["HIP_MID"] = ((j["RIGHT HIP"][0] + j["LEFT HIP"][0]) / 2, (j["RIGHT HIP"][1] + j["LEFT HIP"][1]) / 2)
	# Top of the head: from the neck through the nose, about twice as far.
	n, s = j["NECK"], j["NOSE"]
	j["HEAD_TOP"] = (n[0] + (s[0] - n[0]) * 2.2, n[1] + (s[1] - n[1]) * 2.2)
	return j


def held_mask(layer, base):
	"""Long thin pieces of the layer outside the base body (cane, weapon)."""
	w, h = layer.size
	lp, bp = layer.load(), base.load()
	near = set()
	for y in range(h):
		for x in range(w):
			if bp[x, y][3] >= 128:
				for dy in (-2, -1, 0, 1, 2):
					for dx in (-2, -1, 0, 1, 2):
						near.add((x + dx, y + dy))
	out = set((x, y) for y in range(h) for x in range(w) if lp[x, y][3] >= 128 and (x, y) not in near)
	held, seen = set(), set()
	for s0 in out:
		if s0 in seen:
			continue
		blob, todo = [], [s0]
		seen.add(s0)
		while todo:
			x, y = todo.pop()
			blob.append((x, y))
			for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1), (x + 1, y + 1), (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1)):
				if (nx, ny) in out and (nx, ny) not in seen:
					seen.add((nx, ny))
					todo.append((nx, ny))
		xs = [p[0] for p in blob]
		ys = [p[1] for p in blob]
		span = max(max(xs) - min(xs), max(ys) - min(ys))
		if len(blob) >= 6 and span >= 8 and len(blob) <= span * 3:
			held.update(blob)
	return held


def cane_like(layer, j) -> set:
	"""Light neutral-grey shafts below the neck (cane, blade, staff), with
	the dark outline and coloured tips touching them: long thin pieces that
	can pass in front of the body, where held_mask can't see them."""
	px = layer.load()
	w, h = layer.size
	def light(p):
		return p[3] >= 128 and abs(p[0] - p[1]) < 20 and abs(p[1] - p[2]) < 24 and p[0] >= 140
	cand = set((x, y) for y in range(int(j["NECK"][1]) + 4, h) for x in range(w) if light(px[x, y]))
	held, seen = set(), set()
	for s0 in cand:
		if s0 in seen:
			continue
		blob, todo = [], [s0]
		seen.add(s0)
		while todo:
			x, y = todo.pop()
			blob.append((x, y))
			for dx in (-1, 0, 1):
				for dy in (-1, 0, 1):
					q = (x + dx, y + dy)
					if q in cand and q not in seen:
						seen.add(q)
						todo.append(q)
		xs = [p[0] for p in blob]
		ys = [p[1] for p in blob]
		span = max(max(xs) - min(xs), max(ys) - min(ys))
		if span >= 6 and len(blob) <= span * 2:
			held.update(blob)
	# Grow by one pixel into the dark outline and coloured tips around the shaft.
	ring = set()
	for x, y in held:
		for dx in (-1, 0, 1):
			for dy in (-1, 0, 1):
				q = (x + dx, y + dy)
				if 0 <= q[0] < w and 0 <= q[1] < h and q not in held and px[q[0], q[1]][3] >= 128:
					p = px[q[0], q[1]]
					if 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2] < 40 or (p[0] > 150 and p[1] < 80):
						ring.add(q)
	return held | ring


def skirt_px(base, x: int, y: int) -> bool:
	"""Outside the base body below the hips: 2+ px clear of it, or in the gap
	between the legs (body on both sides in the same row)."""
	bp = base.load()
	w, h = base.size
	if bp[x, y][3] >= 128:
		return False
	near = any(0 <= x + dx < w and 0 <= y + dy < h and bp[x + dx, y + dy][3] >= 128 for dx in (-1, 0, 1) for dy in (-1, 0, 1))
	if not near:
		return True
	left = any(0 <= x - d < w and bp[x - d, y][3] >= 128 for d in range(1, 6))
	right = any(0 <= x + d < w and bp[x + d, y][3] >= 128 for d in range(1, 6))
	return left and right


def main() -> None:
	from PIL import Image, ImageDraw
	a = sys.argv[1:]
	layer_dir, detail = a[0], json.load(open(a[1]))
	zpath, state = a[2].rsplit(":", 1)
	z = zipfile.ZipFile(zpath)
	out = os.path.join(layer_dir, "parts")
	os.makedirs(out, exist_ok=True)
	bones_out, sheet_rows = {}, []
	for d, f in DIRS.items():
		lp = os.path.join(layer_dir, f + ".png")
		if not os.path.exists(lp):
			continue
		layer = Image.open(lp).convert("RGBA")
		base = Image.open(io.BytesIO(z.read("%s/rotations/%s.png" % (state, d)))).convert("RGBA")
		w, h = layer.size
		j = joints(detail, d, w, h)
		bones_out[f] = {k: [round(v[0], 2), round(v[1], 2)] for k, v in j.items()}
		held = held_mask(layer, base) | cane_like(layer, j)
		far = "_l" if f in ("SE", "NE", "E", "S") else "_r"
		parts = {name: Image.new("RGBA", (w, h)) for name in list(BONES) + ["held", "foot_r", "foot_l", "skirt"]}
		seg = Image.new("RGBA", (w, h))
		px = layer.load()
		for y in range(h):
			for x in range(w):
				p = px[x, y]
				if p[3] < 128:
					continue
				bone_d = min(seg_dist((x, y), j[BONES[n][0]], j[BONES[n][1]]) for n in BONES if n != "head")
				knee_y = min(j["RIGHT KNEE"][1], j["LEFT KNEE"][1])
				if y <= knee_y and ((x, y) in held or (base.getpixel((x, y))[3] < 128 and bone_d > 6 and y > j["NECK"][1] + 4)):
					# Off the body and away from every limb, above the knees (below
					# them it's a wider boot): a held item (cane, weapon).
					name = "held"
				elif y < j["NECK"][1] - 2:
					# Above the neck is all head: the hair's back edge sits nearer
					# the shoulder bone than the head's, but must not ride the arm.
					name = "head"
				else:
					# The far arm hangs behind the torso: near-ties go to the torso,
					# so the chest's far side doesn't ride the far arm.
					name = min(BONES, key=lambda n: seg_dist((x, y), j[BONES[n][0]], j[BONES[n][1]]) + (1.5 if n == "head" and y > j["NECK"][1] else 0)
						+ (2.0 if n in ("upper_arm" + far, "forearm" + far) else 0))
				if name in ("shin_r", "shin_l"):
					ank = j["RIGHT LEG" if name == "shin_r" else "LEFT LEG"]
					if y >= ank[1] - 1:
						name = "foot_" + name[-1]
				if name.startswith(("thigh_", "shin_")) and y > j["HIP_MID"][1] + 1 and skirt_px(base, x, y):
					# A coat's tails: hanging clear of the legs, or across the gap
					# between them. They swing with the hips, not with one leg.
					name = "skirt"
				parts[name].putpixel((x, y), p)
				seg.putpixel((x, y), COLOURS[name] + (255,))
		# A long coat: below the hips the outfit spreads 3+ px past the base's
		# legs on 6+ rows. Then everything from the hips down to the coat's
		# hem is one piece (the skirt), so the coat doesn't tear between legs.
		lpx, bpx0 = layer.load(), base.load()
		hip_y = int(j["HIP_MID"][1]) + 1
		wide = []
		for y in range(hip_y, h):
			bx = [x for x in range(w) if bpx0[x, y][3] >= 128]
			lx = [x for x in range(w) if lpx[x, y][3] >= 128]
			if bx and lx and (min(bx) - min(lx) >= 3 or max(lx) - max(bx) >= 3):
				wide.append(y)
		# Armour on the legs spreads 2-3 px on a row or two; a coat 3-5 px on
		# nine or more (a backpack at the hip in a side view, five).
		if len(wide) >= 6:
			hem = max(wide)
			for name in ("thigh_r", "thigh_l", "shin_r", "shin_l"):
				q = parts[name].load()
				for y in range(hip_y, hem + 1):
					for x in range(w):
						if q[x, y][3] >= 128:
							parts["skirt"].putpixel((x, y), q[x, y])
							q[x, y] = (0, 0, 0, 0)
							seg.putpixel((x, y), COLOURS["skirt"] + (255,))
			print(f, "long coat: hips to row", hem)
		# The coat stays in one piece: thigh/shin pixels outside the base body
		# that join the skirt go with the skirt.
		sk, bpx = parts["skirt"].load(), base.load()
		grew = True
		while grew:
			grew = False
			for name in ("thigh_r", "thigh_l", "shin_r", "shin_l"):
				q = parts[name].load()
				for y in range(h):
					for x in range(w):
						if q[x, y][3] < 128 or bpx[x, y][3] >= 128:
							continue
						if any(0 <= x + dx < w and 0 <= y + dy < h and sk[x + dx, y + dy][3] >= 128 for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
							sk[x, y] = q[x, y]
							q[x, y] = (0, 0, 0, 0)
							seg.putpixel((x, y), COLOURS["skirt"] + (255,))
							grew = True
		for name, im in parts.items():
			stale = os.path.join(out, "%s_%s.png" % (f, name))
			if os.path.exists(stale):
				os.remove(stale)  # a part this split no longer has must not ride on
			if im.getbbox():
				im.save(os.path.join(out, "%s_%s.png" % (f, name)))
		sheet_rows.append((f, layer, seg, parts))
	json.dump({"bones": BONES, "facings": bones_out}, open(os.path.join(out, "bones.json"), "w"), indent="\t")
	print("parts for", [r[0] for r in sheet_rows])
	if "--sheet" in a:
		k, C = 5, 60 * 5
		rows = [r for r in sheet_rows if r[0] in ("SE", "SW", "NE", "NW")]
		o = Image.new("RGBA", (3 * C, len(rows) * C + 20), (28, 30, 40, 255))
		dr = ImageDraw.Draw(o)
		for i, t in enumerate(["outfit layer", "parts (colour = part)", "parts pulled apart"]):
			dr.text((i * C + 4, 4), t, fill=(230, 230, 240))
		for r, (f, layer, seg, parts) in enumerate(rows):
			o.alpha_composite(layer.resize((C, C), Image.NEAREST), (0, 20 + r * C))
			o.alpha_composite(seg.resize((C, C), Image.NEAREST), (C, 20 + r * C))
			# exploded view: each part nudged away from the body centre
			ex = Image.new("RGBA", (60, 60))
			cx, cy = 30, 32
			for name, im in parts.items():
				bb = im.getbbox()
				if not bb:
					continue
				mx, my = (bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2
				ox, oy = int(round((mx - cx) * 0.25)), int(round((my - cy) * 0.25))
				ex.alpha_composite(im, (ox, oy)) if ox >= 0 and oy >= 0 else ex.paste(im, (ox, oy), im)
			o.alpha_composite(ex.resize((C, C), Image.NEAREST), (2 * C, 20 + r * C))
		o.save(a[a.index("--sheet") + 1])


if __name__ == "__main__":
	main()
