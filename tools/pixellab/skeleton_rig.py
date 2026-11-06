"""Hand / elbow / head points from PixelLab's skeleton estimate, into rig.json.

    godot --headless --path . -s res://tools/rig/make_rig.gd -- <body folder> --dump <dump dir> [--anims idle_SE,idle_NE] [--first]
    python3 tools/pixellab/skeleton_rig.py <dump dir> [--go] [--preview out.png]

Costs 0.1 generation per frame (POST /estimate-skeleton). Without --go it
only counts frames and prints the cost. Points go into the body's rig.json
per frame (anims.<anim>[frame]); frames not estimated keep their earlier
points. Skeleton keypoints are fractions 0-1 of the picture; PixelLab's
"RIGHT ARM" / "LEFT ARM" are the wrists. z is +1 when the wrist draws above
the neck (its z_index), -1 when it draws below (behind the body).
Raw responses are kept in <dump dir>/<unit>/skeleton.json.

Reads PIXELLAB_API_KEY (or the session proxy's saved credential; then set
PIXELLAB_API_KEY=proxy-injected).
"""
import argparse
import base64
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot  # noqa: E402  (call, generations)

COST_PER_FRAME = 0.1
POINTS = {"hand_r": "RIGHT ARM", "hand_l": "LEFT ARM", "elbow_r": "RIGHT ELBOW", "elbow_l": "LEFT ELBOW", "head": "NOSE"}


def frames(dump: str) -> list:
	out = []
	for unit in sorted(os.listdir(dump)):
		d = os.path.join(dump, unit)
		if not os.path.isdir(d):
			continue
		for f in sorted(os.listdir(d)):
			if f.endswith(".png") and "__" in f:
				anim, idx = f[:-4].rsplit("__", 1)
				out.append((unit, anim, int(idx), os.path.join(d, f)))
	return out


def to_points(kps: list, w: int, h: int) -> dict:
	by = {k["label"]: k for k in kps}
	neck_z = float((by.get("NECK") or {}).get("z_index", 0))
	out = {}
	for name, label in POINTS.items():
		k = by.get(label)
		if not k:
			continue
		z = 1 if float(k.get("z_index", 0)) >= neck_z else -1
		out[name] = [int(round(k["x"] * (w - 1))), int(round(k["y"] * (h - 1))), z]
	return out


def main() -> None:
	from PIL import Image
	p = argparse.ArgumentParser()
	p.add_argument("dump")
	p.add_argument("--go", action="store_true")
	p.add_argument("--preview", default="")
	a = p.parse_args()
	index = json.load(open(os.path.join(a.dump, "index.json"), encoding="utf-8"))
	todo = frames(a.dump)
	print("%d frames, %.1f generations" % (len(todo), len(todo) * COST_PER_FRAME))
	if not a.go:
		return
	before = pilot.generations()
	results = {}
	for unit, anim, idx, path in todo:
		img = open(path, "rb").read()
		r = pilot.call("POST", "/estimate-skeleton", {"image": pilot.b64(img)})
		w, h = Image.open(path).size
		results.setdefault(unit, {}).setdefault(anim, {})[idx] = {"raw": r.get("keypoints", []), "points": to_points(r.get("keypoints", []), w, h)}
	for unit, anims in results.items():
		with open(os.path.join(a.dump, unit, "skeleton.json"), "w", encoding="utf-8") as f:
			json.dump(anims, f, indent="\t")
		body = index[unit].replace("res://", "")
		rp = os.path.join(body, "rig.json")
		rig = json.load(open(rp, encoding="utf-8")) if os.path.exists(rp) else {"points": {}}
		rig["source"] = "PixelLab skeleton where estimated, RigEstimate elsewhere"
		for anim, fr in anims.items():
			for idx, d in fr.items():
				for name, v in d["points"].items():
					pt = rig["points"].setdefault(name, {"facing": {}, "anims": {}})
					arr = pt.setdefault("anims", {}).setdefault(anim, [])
					while len(arr) <= idx:
						arr.append(arr[-1] if arr else v)
					arr[idx] = v
					if idx == 0 and anim.startswith("idle_"):
						pt.setdefault("facing", {})[anim.split("_")[-1]] = v
		with open(rp, "w", encoding="utf-8") as f:
			json.dump(rig, f, indent="\t")
			f.write("\n")
		print("updated", rp)
	print("used %.2f generations" % (before - pilot.generations()))
	if a.preview:
		preview(a.dump, results, a.preview)


def preview(dump: str, results: dict, out: str) -> None:
	from PIL import Image, ImageDraw
	tiles = []
	for unit, anims in results.items():
		for anim, fr in anims.items():
			for idx, d in fr.items():
				im = Image.open(os.path.join(dump, unit, "%s__%d.png" % (anim, idx))).convert("RGBA")
				k = 5
				big = Image.new("RGBA", im.size, (14, 12, 26, 255))
				big.alpha_composite(im)
				big = big.resize((im.width * k, im.height * k), Image.NEAREST)
				dr = ImageDraw.Draw(big)
				for name, v in d["points"].items():
					col = {"hand_r": (0, 255, 0), "hand_l": (255, 200, 0), "elbow_r": (0, 160, 255), "elbow_l": (255, 120, 0), "head": (255, 0, 255)}[name]
					x, y = v[0] * k + k // 2, v[1] * k + k // 2
					dr.ellipse((x - 6, y - 6, x + 6, y + 6), outline=col, width=3)
				dr.text((6, 6), "%s %s" % (unit, anim), fill=(255, 255, 255))
				tiles.append(big)
	w = sum(t.width for t in tiles)
	h = max(t.height for t in tiles)
	o = Image.new("RGBA", (w, h), (14, 12, 26, 255))
	x = 0
	for t in tiles:
		o.paste(t, (x, 0))
		x += t.width
	o.save(out)
	print("preview", out)


if __name__ == "__main__":
	main()
