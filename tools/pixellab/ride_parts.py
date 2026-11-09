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
ORDER_RIGHT_NEAR = ["shin_l", "thigh_l", "upper_arm_l", "forearm_l", "shin_r", "thigh_r", "torso", "upper_arm_r", "forearm_r", "head", "held"]
ORDER_LEFT_NEAR = ["shin_r", "thigh_r", "upper_arm_r", "forearm_r", "shin_l", "thigh_l", "torso", "upper_arm_l", "forearm_l", "head", "held"]


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
			part = min(bones["bones"], key=lambda n: seg_dist((x, y), j[bones["bones"][n][0]], j[bones["bones"][n][1]]))
			if part not in ramps:
				continue
			lum = (0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2] - 90) / 165.0
			r = ramps[part]
			c = r[max(0, min(len(r) - 1, int(lum * len(r))))]
			px[x, y] = (c[0], c[1], c[2], 255)
	return out


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
	frames = []
	for i, n in enumerate(names):
		base = Image.open(io.BytesIO(z.read(n))).convert("RGBA")
		W, H = base.size
		j = frame_joints(skel["frames"][i])
		img = base.copy()
		for part in order:
			pp = os.path.join(parts_dir, "%s_%s.png" % (facing, part))
			if not os.path.exists(pp):
				continue
			im = Image.open(pp).convert("RGBA")
			pad = ((W - im.width) / 2.0, (H - im.height) / 2.0)
			if part == "held":
				bone = bones["bones"]["forearm_r"]
			else:
				bone = bones["bones"][part]
			# Standing joints are in the 60 px standing canvas; frames are padded around it.
			sa = (stand[bone[0]][0] + pad[0], stand[bone[0]][1] + pad[1])
			sb = (stand[bone[1]][0] + pad[0], stand[bone[1]][1] + pad[1])
			big = Image.new("RGBA", (W, H))
			big.alpha_composite(im, (int(pad[0]), int(pad[1])))
			img.alpha_composite(place(big, sa, sb, j[bone[0]], j[bone[1]], (W, H)))
		if "--lining" in a:
			img = lining(img, base, j, bones, facing, parts_dir)
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
