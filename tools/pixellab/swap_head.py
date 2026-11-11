"""Put another character's head (face and hair) on an animation, frame by
frame. The donor must be drawn in the same view (high top-down). Free.

    python3 -I tools/pixellab/swap_head.py <frames_dir> <skeleton.json> <FACING> <donor.zip> <donor_detail.json> <out_dir>

The donor's head is everything above its neck line in its standing rotation
for that facing; it is lined up on each frame by the eyes' midpoint (or the
nose when the eyes are missing) and pasted after the frame's own head is
cleared above the frame's neck line. Neck-line gaps are closed by the
outline pass.
"""
import glob
import io
import json
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ride_parts import drop_islands, frame_joints, outline  # noqa: E402

DIRS = {"SE": "south-east", "SW": "south-west", "NE": "north-east", "NW": "north-west", "S": "south", "N": "north", "E": "east", "W": "west"}


def anchor(kp: dict) -> tuple:
	if "LEFT EYE" in kp and "RIGHT EYE" in kp:
		return ((kp["LEFT EYE"][0] + kp["RIGHT EYE"][0]) / 2, (kp["LEFT EYE"][1] + kp["RIGHT EYE"][1]) / 2)
	return kp["NOSE"]


def donor_head(zpath: str, detail: dict, facing: str):
	"""(head image cut above the neck, its anchor, its neck y) in donor canvas pixels."""
	from PIL import Image
	z = zipfile.ZipFile(zpath)
	name = [n for n in z.namelist() if n.endswith("rotations/%s.png" % DIRS[facing])][0]
	im = Image.open(io.BytesIO(z.read(name))).convert("RGBA")
	w, h = im.size
	kp = {k: (v["x"] * (w - 1), v["y"] * (h - 1)) for k, v in detail["skeletons"]["2d_references"][DIRS[facing]]["keypoints"].items()}
	cut = int(kp["NECK"][1]) - 1
	src = im.load()
	# Only the piece joined to the face: a staff or blade held up beside
	# the head is not part of it.
	ax, ay = anchor(kp)
	seed = min(((x, y) for y in range(cut) for x in range(w) if src[x, y][3] >= 128),
		key=lambda q: (q[0] - ax) ** 2 + (q[1] - ay) ** 2)
	keep, todo = {seed}, [seed]
	while todo:
		x, y = todo.pop()
		for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
			if q not in keep and 0 <= q[0] < w and 0 <= q[1] < cut and src[q[0], q[1]][3] >= 128:
				keep.add(q)
				todo.append(q)
	head = Image.new("RGBA", im.size)
	px = head.load()
	for x, y in keep:
		px[x, y] = src[x, y]
	return head, anchor(kp), cut


def main() -> None:
	from PIL import Image
	a = sys.argv[1:]
	frames_dir, skel_p, facing, zpath, det_p, out = a[:6]
	os.makedirs(out, exist_ok=True)
	head, dh, dcut = donor_head(zpath, json.load(open(det_p)), facing)
	frames = json.load(open(skel_p))["frames"]
	for i, p in enumerate(sorted(glob.glob(os.path.join(frames_dir, "frame_*.png")))):
		img = Image.open(p).convert("RGBA")
		W, H = img.size
		j = frame_joints(frames[i])
		fa = anchor(j)
		line = int(j["NECK"][1]) - 1
		px = img.load()
		for y in range(0, max(0, line)):
			for x in range(W):
				px[x, y] = (0, 0, 0, 0)
		dx, dy = int(round(fa[0] - dh[0])), int(round(fa[1] - dh[1]))
		lay = Image.new("RGBA", (W, H))
		lay.paste(head, (dx, dy), head)
		# Keep the donor's head above the frame's own neck line, so its
		# chin meets the collar without its own collar hanging over it.
		lp = lay.load()
		for y in range(min(H, line + 1), H):
			for x in range(W):
				lp[x, y] = (0, 0, 0, 0)
		# A row or two of gap between the donor's chin and the collar (the
		# heads bob differently) is filled with the donor's neck, or the
		# outline pass would draw a black line across the collar.
		ip = img.load()
		for x in range(W):
			yd = max((y for y in range(H) if lp[x, y][3] >= 128), default=None)
			if yd is None:
				continue
			yf = next((y for y in range(yd + 1, H) if ip[x, y][3] >= 128), None)
			if yf is None or not (1 <= yf - yd - 1 <= 2):
				continue
			src_y = yd
			while src_y > 0 and lp[x, src_y][3] >= 128 and 0.3 * lp[x, src_y][0] + 0.59 * lp[x, src_y][1] + 0.11 * lp[x, src_y][2] < 40:
				src_y -= 1
			c = lp[x, src_y] if lp[x, src_y][3] >= 128 else lp[x, yd]
			for y in range(yd + 1, yf):
				lp[x, y] = c
		img.alpha_composite(lay)
		img = outline(drop_islands(img))
		img.save(os.path.join(out, "frame_%03d.png" % i))
	print("head swapped on", len(frames), "frames ->", out)


if __name__ == "__main__":
	main()
