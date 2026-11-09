"""PixelLab's skeleton estimate for each frame of one animation in an export.

    python3 -I tools/pixellab/estimate_frames.py <export.zip> <folder inside zip> <out.json>        # plan
    python3 -I tools/pixellab/estimate_frames.py <export.zip> <folder inside zip> <out.json> --go   # 0.1 a frame

<folder> is e.g. light_bodysuit/animations/walking/south-east. Writes
{"frames": [{label: [x, y], ...} per frame], "size": [w, h]} in canvas pixels,
plus the raw responses. Used to make modular parts ride their bones.
"""
import io
import json
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot  # noqa: E402


def main() -> None:
	a = sys.argv[1:]
	z = zipfile.ZipFile(a[0])
	names = sorted(n for n in z.namelist() if n.startswith(a[1].rstrip("/") + "/") and n.endswith(".png"))
	print("%d frames, %.1f generations" % (len(names), 0.1 * len(names)))
	if "--go" not in a:
		return
	from PIL import Image
	before = pilot.generations()
	frames, raw = [], []
	for n in names:
		data = z.read(n)
		w, h = Image.open(io.BytesIO(data)).size
		r = pilot.call("POST", "/estimate-skeleton", {"image": pilot.b64(data)})
		kps = r.get("keypoints", [])
		raw.append(r)
		frames.append({k["label"]: [round(k["x"] * (w - 1), 2), round(k["y"] * (h - 1), 2)] for k in kps})
	json.dump({"source": a[1], "size": [w, h], "frames": frames, "raw": raw}, open(a[2], "w"), indent="\t")
	print("saved", a[2], "balance drop", round(before - pilot.generations(), 2))


if __name__ == "__main__":
	main()
