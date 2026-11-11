"""Clean an outfit animation PixelLab drew from the base's poses: remove
leftover bodysuit grey (a ghost of the base's foot or hand) wherever the
outfit's own standing art has no such grey, then close the outline. Writes
cleaned copies; the original take is kept as it came. Free.

    python3 -I tools/pixellab/clean_frames.py <frames_dir> <outfit.zip>:<state> <FACING> <out_dir>

Grey the outfit really has (visor glints, armour highlights) sits in bands
the standing art also uses, so only grey in rows of the figure where the
standing art has none counts as a ghost.
"""
import glob
import io
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ride_parts import bodysuit, outline  # noqa: E402

DIRS = {"SE": "south-east", "SW": "south-west", "NE": "north-east", "NW": "north-west", "S": "south", "N": "north", "E": "east", "W": "west"}


def main() -> None:
	from PIL import Image
	a = sys.argv[1:]
	frames_dir, spec, facing, out = a[:4]
	zp, state = spec.rsplit(":", 1)
	# A ghost is a light near-neutral grey (the base's bodysuit, ~140 and up):
	# armour mid-tones (blue-greys around 100-125) are never one. And only in
	# rows where the outfit's own standing art has no such grey (below).
	def ghost(q) -> bool:
		return bodysuit(q) and 0.3 * q[0] + 0.59 * q[1] + 0.11 * q[2] >= 130
	st = Image.open(io.BytesIO(zipfile.ZipFile(zp).read("%s/rotations/%s.png" % (state, DIRS[facing])))).convert("RGBA")
	sp = st.load()
	# Rows (relative to the figure's bottom) where the standing art has grey.
	sb = st.getbbox()
	grey_rows = {sb[3] - y for y in range(st.height) for x in range(st.width) if ghost(sp[x, y])}
	os.makedirs(out, exist_ok=True)
	for p in sorted(glob.glob(os.path.join(frames_dir, "frame_*.png"))):
		im = Image.open(p).convert("RGBA")
		px = im.load()
		bb = im.getbbox()
		removed = []
		# Peel from the outside in: a ghost hangs off the figure's edge, so a
		# grey pixel only goes when it touches empty space (or a ghost pixel
		# already peeled). Grey inside the figure (an armour highlight) stays.
		W, H = im.size
		changed = True
		while changed:
			changed = False
			for y in range(H):
				if any(abs((bb[3] - y) - r) <= 2 for r in grey_rows):
					continue
				for x in range(W):
					if not ghost(px[x, y]):
						continue
					if any(not (0 <= x + dx < W and 0 <= y + dy < H) or px[x + dx, y + dy][3] < 128
						for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
						px[x, y] = (0, 0, 0, 0)
						removed.append((x, y))
						changed = True
		gone = len(removed)
		if removed:
			# Close the outline only where the ghost was: PixelLab's own
			# light edges (glows, rims) elsewhere stay as drawn.
			done = outline(im)
			dp = done.load()
			near = {(x + dx, y + dy) for x, y in removed for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
			for x, y in near:
				if 0 <= x < im.width and 0 <= y < im.height:
					px[x, y] = dp[x, y]
		im.save(os.path.join(out, os.path.basename(p)))
		if gone:
			print(os.path.basename(p), "ghost grey removed:", gone)
	print("cleaned ->", out)


if __name__ == "__main__":
	main()
