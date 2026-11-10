"""Cut one piece of gear (a backpack, jetpack, wings, a cape) out of an outfit:
the outfit with it minus the same outfit without it, per rotation.

    python3 -I tools/pixellab/cut_attachment.py <with.zip>:<state> <without.zip>:<state> <out_dir> [--sheet out.png]

Writes <out_dir>/<facing>.png (the piece alone, standing canvas) for the back
slot: ride_parts.py --back <out_dir> draws it riding the torso as one solid
piece, behind the body in the facings that look at the camera and over it in
the ones that look away. Free.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot  # noqa: E402
from cut_parts import load, keep_outline  # noqa: E402


def main() -> None:
	from PIL import Image, ImageDraw
	a = sys.argv[1:]
	with_, without, out = load(a[0]), load(a[1]), a[2]
	os.makedirs(out, exist_ok=True)
	done = []
	for f in with_:
		if f not in without:
			continue
		piece = keep_outline(pilot.diff_layer(without[f], with_[f]), with_[f])
		piece.save(os.path.join(out, f + ".png"))
		done.append(f)
	print("piece for", done)
	if "--sheet" in a:
		C = 60 * 4
		o = Image.new("RGBA", (3 * C, len(done) * C + 20), (28, 30, 40, 255))
		d = ImageDraw.Draw(o)
		for i, t in enumerate(["with", "without", "piece"]):
			d.text((i * C + 4, 4), t, fill=(230, 230, 240))
		for r, f in enumerate(done):
			for c, im in enumerate([with_[f], without[f], Image.open(os.path.join(out, f + ".png"))]):
				o.alpha_composite(im.convert("RGBA").resize((C, C), Image.NEAREST), (c * C, 20 + r * C))
		o.save(a[a.index("--sheet") + 1])


if __name__ == "__main__":
	main()
