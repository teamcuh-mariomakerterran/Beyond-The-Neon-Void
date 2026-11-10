"""Mix gear slots between outfits animated on the same poses: the chest
(torso, arms, hands, head) from one animation and the legs from another,
frame by frame. Free.

    python3 -I tools/pixellab/mix_slots.py <chest_frames_dir> <legs_frames_dir> <skeleton.json> <out_dir>

Both frame folders must come from the same walk poses (aim_pose.py, same
clip and facing), so the bodies line up. Each frame is cut by the skeleton:
legs are the pixels nearest a thigh or shin below the hips, the chest is
the rest; the legs go down first, the chest over them (the jacket hangs over
the belt line), then the outline is closed.
"""
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from split_parts import BONES, seg_dist  # noqa: E402
from ride_parts import drop_islands, frame_joints, outline  # noqa: E402
from cut_parts import skinlike  # noqa: E402

LEGS = ("thigh_r", "thigh_l", "shin_r", "shin_l")


def owner(x: int, y: int, j: dict) -> str:
	names = [n for n in BONES if n != "head"]
	return min(names, key=lambda n: seg_dist((x, y), j[BONES[n][0]], j[BONES[n][1]]))


def split(img, j: dict, belt: float = 2.0):
	"""(chest, legs) layers of one frame."""
	from PIL import Image
	w, h = img.size
	px = img.load()
	chest, legs = Image.new("RGBA", img.size), Image.new("RGBA", img.size)
	cp, lp = chest.load(), legs.load()
	hip = j["HIP_MID"][1]
	for y in range(h):
		for x in range(w):
			p = px[x, y]
			if p[3] < 128:
				continue
			o = owner(x, y, j)
			if o in LEGS and y > hip - 1:
				if not skinlike(p):  # a hand hanging by the hip is the chest's
					lp[x, y] = p
			elif o.startswith(("upper_arm", "forearm")) or y <= hip + belt:
				cp[x, y] = p
			elif not skinlike(p):
				lp[x, y] = p
	return chest, legs


def main() -> None:
	from PIL import Image
	a = sys.argv[1:]
	chest_dir, legs_dir, skel_p, out = a[:4]
	os.makedirs(out, exist_ok=True)
	frames = json.load(open(skel_p))["frames"]
	cs = sorted(glob.glob(os.path.join(chest_dir, "frame_*.png")))
	ls = sorted(glob.glob(os.path.join(legs_dir, "frame_*.png")))
	for i, (c, l) in enumerate(zip(cs, ls)):
		j = frame_joints(frames[i])
		ci, li = Image.open(c).convert("RGBA"), Image.open(l).convert("RGBA")
		chest, _ = split(ci, j)
		_, legs = split(li, j)
		img = Image.new("RGBA", ci.size)
		img.alpha_composite(legs)
		img.alpha_composite(chest)
		img = outline(drop_islands(img))
		img.save(os.path.join(out, "frame_%03d.png" % i))
	print("mixed", len(cs), "frames ->", out)


if __name__ == "__main__":
	main()
