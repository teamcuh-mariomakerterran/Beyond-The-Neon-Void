"""Dress an animation of the base body with split parts: each part rides its
bone from the standing skeleton (parts/bones.json) to the frame's skeleton
(tools/pixellab/estimate_frames.py), turned about the bone's first joint.

    python3 -I tools/pixellab/ride_parts.py <parts_dir> <FACING> <export.zip> <anim folder> <frame_skeleton.json> <out_dir> [--gif out.gif]

Writes <out_dir>/frame_NNN.png (the dressed frames). Free. Parts are sampled
backwards (each output pixel looks up its source pixel) so turned pieces get
no holes; pixel art stays nearest-neighbour.
"""
import io
import json
import math
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Far side first, then torso, then the near side and the head (SE/NE: right side is near).
ORDER_RIGHT_NEAR = ["foot_l", "shin_l", "thigh_l", "upper_arm_l", "forearm_l", "foot_r", "shin_r", "thigh_r", "torso", "upper_arm_r", "forearm_r", "head", "held"]
ORDER_LEFT_NEAR = ["foot_r", "shin_r", "thigh_r", "upper_arm_r", "forearm_r", "foot_l", "shin_l", "thigh_l", "torso", "upper_arm_l", "forearm_l", "head", "held"]


def frame_joints(f: dict) -> dict:
	j = {k: tuple(v) for k, v in f.items()}
	j["HIP_MID"] = ((j["RIGHT HIP"][0] + j["LEFT HIP"][0]) / 2, (j["RIGHT HIP"][1] + j["LEFT HIP"][1]) / 2)
	n, s = j["NECK"], j["NOSE"]
	j["HEAD_TOP"] = (n[0] + (s[0] - n[0]) * 2.2, n[1] + (s[1] - n[1]) * 2.2)
	return j


def place(part, a, b, a2, b2, size):
	"""Part image (standing canvas) moved so bone a->b lands on a2->b2."""
	from PIL import Image
	ang = math.atan2(b2[1] - a2[1], b2[0] - a2[0]) - math.atan2(b[1] - a[1], b[0] - a[0])
	ca, sa = math.cos(-ang), math.sin(-ang)
	out = Image.new("RGBA", size)
	src = part.load()
	dst = out.load()
	w, h = part.size
	for y in range(size[1]):
		for x in range(size[0]):
			dx, dy = x - a2[0], y - a2[1]
			sx = a[0] + dx * ca - dy * sa
			sy = a[1] + dx * sa + dy * ca
			ix, iy = int(round(sx)), int(round(sy))
			if 0 <= ix < w and 0 <= iy < h:
				p = src[ix, iy]
				if p[3] >= 128:
					dst[x, y] = p
	return out


def skinlike(p) -> bool:
	r, g, b = p[0], p[1], p[2]
	return p[3] >= 128 and r >= 110 and r > g > b and g >= 0.55 * r and b >= 0.35 * r


def head_anchor(img, neck_y: float):
	"""Top-centre of the base's own head (its skin pixels above the neck):
	head parts lock to this, so hair never drifts off the bald head."""
	px = img.load()
	w, h = img.size
	pts = [(x, y) for y in range(min(h, int(neck_y) + 2)) for x in range(w) if skinlike(px[x, y])]
	if not pts:
		return None
	xs = [p[0] for p in pts]
	return ((min(xs) + max(xs)) / 2.0, float(min(p[1] for p in pts)))


def despeck(img):
	"""Drop lone pixels hanging off the figure (one or no neighbours of the
	eight): stray bits of a turned part, like the one beside the ear."""
	out = img.copy()
	px, src = out.load(), img.load()
	w, h = img.size
	for y in range(h):
		for x in range(w):
			if src[x, y][3] < 128:
				continue
			n = sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy) and 0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3] >= 128)
			if n <= 1:
				px[x, y] = (0, 0, 0, 0)
	return out


def outline(img, col=(4, 2, 1)):
	"""Edge pixels lighter than an outline get the outline colour (the game's
	restore_outline), so every finished frame has a whole black outline."""
	out = img.copy()
	px, src = out.load(), img.load()
	w, h = img.size
	for y in range(h):
		for x in range(w):
			p = src[x, y]
			if p[3] < 128:
				continue
			edge = any(not (0 <= x + dx < w and 0 <= y + dy < h) or src[x + dx, y + dy][3] < 128 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
			if edge and 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2] >= 40:
				px[x, y] = col + (255,)
	return out


def bodysuit(p) -> bool:
	return p[3] >= 128 and abs(p[0] - p[1]) < 14 and abs(p[1] - p[2]) < 14 and p[0] > 90


def ramp(im) -> list:
	"""The part's own colours from dark to light (outline-dark pixels left out)."""
	cols = {}
	for p in (im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()):
		if p[3] >= 128 and 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2] >= 30:
			cols[p[:3]] = cols.get(p[:3], 0) + 1
	top = sorted(cols, key=lambda c: -cols[c])[:4]
	return sorted(top, key=lambda c: 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2])


def lining(img, base, j, bones, facing, parts_dir):
	"""Bodysuit still showing on a clothed limb takes that limb's clothing
	colours (its own light-to-dark shading kept), so gaps read as lining."""
	from PIL import Image
	from split_parts import seg_dist
	ramps = {}
	for part, bone in bones["bones"].items():
		pp = os.path.join(parts_dir, "%s_%s.png" % (facing, part))
		if part != "head" and os.path.exists(pp):
			r = ramp(Image.open(pp).convert("RGBA"))
			if r:
				ramps[part] = r
	out = img.copy()
	px, bp = out.load(), base.load()
	W, H = out.size
	for y in range(H):
		for x in range(W):
			p = px[x, y]
			if not bodysuit(p) or p != bp[x, y]:
				continue
			cand = [n for n in bones["bones"] if n in ramps]
			if not cand:
				continue
			part = min(cand, key=lambda n: seg_dist((x, y), j[bones["bones"][n][0]], j[bones["bones"][n][1]]))
			lum = (0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2] - 90) / 165.0
			r = ramps[part]
			c = r[max(0, min(len(r) - 1, int(lum * len(r))))]
			px[x, y] = (c[0], c[1], c[2], 255)
	return out


def foot_bottom(img, x: float, y0: float, half: int = 2):
	"""Lowest drawn pixel of a foot: the bottom of the opaque pixels in a
	narrow column window round the ankle, below the ankle. None if empty."""
	px = img.load()
	W, H = img.size
	best = None
	for xx in range(max(0, int(round(x)) - half), min(W, int(round(x)) + half + 1)):
		for yy in range(H - 1, max(0, int(y0)) - 1, -1):
			if px[xx, yy][3] >= 128:
				best = yy if best is None else max(best, yy)
				break
	return best


def main() -> None:
	from PIL import Image
	a = sys.argv[1:]
	parts_dir, facing, zpath, folder, skel_p, out = a[:6]
	bones = json.load(open(os.path.join(parts_dir, "bones.json")))
	stand = {k: tuple(v) for k, v in bones["facings"][facing].items()}
	skel = json.load(open(skel_p))
	z = zipfile.ZipFile(zpath)
	names = sorted(n for n in z.namelist() if n.startswith(folder.rstrip("/") + "/") and n.endswith(".png"))
	os.makedirs(out, exist_ok=True)
	order = ORDER_RIGHT_NEAR if facing in ("SE", "NE", "E", "S") else ORDER_LEFT_NEAR
	# The standing base's own head, in the frames' padded canvas.
	stand_base = None
	for n0 in z.namelist():
		if n0.endswith("rotations/%s.png" % {"SE": "south-east", "SW": "south-west", "NE": "north-east", "NW": "north-west"}.get(facing, "")) and n0.split("/")[0] == folder.split("/")[0]:
			stand_base = Image.open(io.BytesIO(z.read(n0))).convert("RGBA")
	frames = []
	stand_head = None
	for i, n in enumerate(names):
		base = Image.open(io.BytesIO(z.read(n))).convert("RGBA")
		W, H = base.size
		if stand_head is None and stand_base is not None:
			sp = ((W - stand_base.width) / 2.0, (H - stand_base.height) / 2.0)
			sh = head_anchor(stand_base, stand["NECK"][1])
			stand_head = (sh[0] + sp[0], sh[1] + sp[1]) if sh else None
		j = frame_joints(skel["frames"][i])
		img = base.copy()
		# Swap the walking head for the standing head the hair was cut against,
		# moved to the same spot, so hair and head match exactly. Only above the
		# neck line, before any clothes go on.
		fa0 = head_anchor(base, j["NECK"][1])
		if fa0 is not None and stand_head is not None and stand_base is not None:
			dx, dy = int(round(fa0[0] - stand_head[0])), int(round(fa0[1] - stand_head[1]))
			sp = (int((W - stand_base.width) / 2), int((H - stand_base.height) / 2))
			cut = max(1, int(stand["NECK"][1]) - 1)
			head_src = stand_base.crop((0, 0, stand_base.width, cut))
			mp = os.path.join(os.path.dirname(parts_dir.rstrip("/")), "%s_mask.png" % facing)
			if os.path.exists(mp):
				# Only where the dressed character had something: no base ear past the hair.
				m = Image.open(mp).convert("L").crop((0, 0, stand_base.width, cut))
				head_src.putalpha(Image.composite(head_src.getchannel("A"), Image.new("L", head_src.size, 0), m))
			head_img = Image.new("RGBA", (W, H))
			head_img.paste(head_src, (sp[0] + dx, sp[1] + dy))
			hb = head_img.getbbox()
			if hb:
				line = sp[1] + dy + cut
				clear = img.load()
				# Clear a few pixels wider than the head: the walking head bobs past it.
				for yy in range(max(0, hb[1] - 3), min(H, line)):
					for xx in range(max(0, hb[0] - 3), min(W, hb[2] + 3)):
						clear[xx, yy] = (0, 0, 0, 0)
				img.alpha_composite(head_img)
		for part in order:
			pp = os.path.join(parts_dir, "%s_%s.png" % (facing, part))
			if not os.path.exists(pp):
				continue
			im = Image.open(pp).convert("RGBA")
			pad = ((W - im.width) / 2.0, (H - im.height) / 2.0)
			if "--paint-legs" in a and part.startswith(("thigh_", "shin_")):
				# Trousers: the base's own drawn legs take the trouser colours in
				# the lining pass, so they follow the frame exactly.
				continue
			if part.startswith("foot_"):
				# Feet slide with the ankle and don't turn: shoes stay flat.
				ank = "RIGHT LEG" if part.endswith("r") else "LEFT LEG"
				big = Image.new("RGBA", (W, H))
				big.alpha_composite(im, (int(pad[0]), int(pad[1])))
				dx = int(round(j[ank][0] - (stand[ank][0] + pad[0])))
				dy = int(round(j[ank][1] - (stand[ank][1] + pad[1])))
				# The drawn frame's feet can sit a few pixels off the skeleton's
				# ankles: put the sole on the base's drawn sole instead.
				if stand_base is not None:
					sb0 = Image.new("RGBA", (W, H))
					sb0.alpha_composite(stand_base, (int(pad[0]), int(pad[1])))
					yb_s = foot_bottom(sb0, stand[ank][0] + pad[0], stand[ank][1] + pad[1])
					yb_f = foot_bottom(base, j[ank][0], j[ank][1])
					if yb_s is not None and yb_f is not None and abs((yb_f - yb_s) - dy) <= 5:
						dy = yb_f - yb_s
				moved = Image.new("RGBA", (W, H))
				moved.paste(big, (dx, dy), big)
				img.alpha_composite(moved)
				continue
			if part == "held":
				bone = bones["bones"]["forearm_r"]
			else:
				bone = bones["bones"][part]
			# Standing joints are in the 60 px standing canvas; frames are padded around it.
			sa = (stand[bone[0]][0] + pad[0], stand[bone[0]][1] + pad[1])
			sb = (stand[bone[1]][0] + pad[0], stand[bone[1]][1] + pad[1])
			big = Image.new("RGBA", (W, H))
			big.alpha_composite(im, (int(pad[0]), int(pad[1])))
			if part == "head" and stand_head is not None:
				fa = head_anchor(base, j["NECK"][1])
				if fa is not None:
					shifted = Image.new("RGBA", (W, H))
					shifted.alpha_composite(big, (int(round(fa[0] - stand_head[0])), int(round(fa[1] - stand_head[1]))) if fa[0] >= stand_head[0] and fa[1] >= stand_head[1] else (0, 0))
					if not (fa[0] >= stand_head[0] and fa[1] >= stand_head[1]):
						shifted = Image.new("RGBA", (W, H))
						shifted.paste(big, (int(round(fa[0] - stand_head[0])), int(round(fa[1] - stand_head[1]))), big)
					img.alpha_composite(shifted)
					continue
			img.alpha_composite(place(big, sa, sb, j[bone[0]], j[bone[1]], (W, H)))
		if "--lining" in a:
			img = lining(img, base, j, bones, facing, parts_dir)
		img = outline(despeck(img))
		img.save(os.path.join(out, "frame_%03d.png" % i))
		frames.append((base, img))
	print("dressed", len(frames), "frames")
	if "--gif" in a:
		k = 4
		g = []
		for r in range(2):
			for base, img in frames:
				q = Image.new("RGB", (2 * W * k, H * k), (28, 30, 40))
				for c, im in enumerate((base, img)):
					b = im.resize((W * k, H * k), Image.NEAREST)
					q.paste(b, (c * W * k, 0), b)
				g.append(q)
		g[0].save(a[a.index("--gif") + 1], save_all=True, append_images=g[1:], duration=100, loop=0)


if __name__ == "__main__":
	main()
