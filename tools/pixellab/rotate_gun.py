"""Draw the missing angles of one of Brian's sheet pistols (only the SW view is
drawn) with PixelLab, two ways, to compare (Brian, 2026-11-13):

  a: /generate-8-rotations-v3 - the SW drawing in, 8 views out (one call)
  b: /rotate                  - SW drawing in, NW out (one call); NE is its mirror

    python3 -I tools/pixellab/rotate_gun.py <a|b> neon_pistol_01          # plan + input picture (free)
    python3 -I tools/pixellab/rotate_gun.py <a|b> neon_pistol_01 --go     # spends

Input: assets/gear/weapons/<name>/SW.png centred on a 32x32 canvas (native size,
so the result is drawn at the size it's shown in a hand). Output:
assets/gear/source/pistol_rotations/<name>/<a|b>/ with the input, every picture
returned and log.json (balance before/after). Nothing is imported into the game.
"""
import base64
import io
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot  # noqa: E402

SIZE = 32
DIRS8 = ["south", "south-west", "west", "north-west", "north", "north-east", "east", "south-east"]


def picture(name: str) -> bytes:
	from PIL import Image
	im = Image.open(os.path.join("assets", "gear", "weapons", name, "SW.png")).convert("RGBA")
	im = im.crop(im.getbbox())
	c = Image.new("RGBA", (SIZE, SIZE))
	c.alpha_composite(im, ((SIZE - im.width) // 2, (SIZE - im.height) // 2))
	buf = io.BytesIO()
	c.save(buf, "PNG")
	return buf.getvalue()


def save_b64(s: str, path: str) -> None:
	if "," in s[:40]:
		s = s.split(",", 1)[1]
	open(path, "wb").write(base64.b64decode(s))


def main() -> None:
	a = sys.argv[1:]
	mode, name = a[0], a[1]
	out = os.path.join("assets", "gear", "source", "pistol_rotations", name, mode)
	os.makedirs(out, exist_ok=True)
	src = picture(name)
	open(os.path.join(out, "input_SW.png"), "wb").write(src)
	print("%s mode %s, input %s" % (name, mode, os.path.join(out, "input_SW.png")))
	if "--go" not in a:
		return
	before = pilot.generations()
	log = {"name": name, "mode": mode, "size": SIZE, "balance_before": before}
	if mode == "a":
		r = pilot.call("POST", "/generate-8-rotations-v3", {
			"first_frame": pilot.b64(src), "no_background": True,
			"description": "small sci-fi pistol, side view, barrel pointing to the left"})
		j = pilot.wait(r["background_job_id"], every=5, fatal=False)
		imgs = (j.get("last_response") or {}).get("images") or []
		log["job"] = r["background_job_id"]
		for i, im in enumerate(imgs):
			b = im.get("base64") if isinstance(im, dict) else im
			save_b64(b, os.path.join(out, "%d_%s.png" % (i, DIRS8[i] if i < 8 else "x")))
		log["files"] = len(imgs)
	else:
		r = pilot.call("POST", "/rotate", {
			"image_size": {"width": SIZE, "height": SIZE}, "from_image": pilot.b64(src),
			"from_view": "low top-down", "to_view": "low top-down",
			"from_direction": "south-west", "to_direction": "north-west"})
		save_b64(r["image"]["base64"], os.path.join(out, "NW.png"))
		log["usage"] = r.get("usage")
	time.sleep(3)
	log["balance_after"] = pilot.generations()
	log["balance_drop"] = round(before - log["balance_after"], 2)
	log["at"] = time.strftime("%Y-%m-%d %H:%M")
	json.dump(log, open(os.path.join(out, "log.json"), "w"), indent="\t")
	print(json.dumps(log))


if __name__ == "__main__":
	main()
