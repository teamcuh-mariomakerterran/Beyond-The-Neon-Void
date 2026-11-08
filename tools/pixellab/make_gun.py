"""Redraw one of Brian's gun objects at hand size: a new 8-direction PixelLab
object made from a reference picture (the gun's side view shrunk onto a
<size> canvas), so every pixel is drawn for the size it's shown at.

    python3 -I tools/pixellab/make_gun.py <slug> <size>          # plan + reference picture (free)
    python3 -I tools/pixellab/make_gun.py <slug> <size> --go     # spends (10-25 generations)

The source is assets/gear/source/pixellab_guns/<slug> (Brian's object). The
result goes to assets/gear/source/pixellab_guns_small/<slug>/ (sheet, layout,
object details, reference.png) and its cost into that folder's log.json.
A style reference (style_object_id) can't be used: PixelLab won't make the
new object smaller than the style object's sprites.
"""
import base64
import io
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SRC = os.path.join("assets", "gear", "source", "pixellab_guns")
OUT = os.path.join("assets", "gear", "source", "pixellab_guns_small")


def reference(slug: str, size: int) -> bytes:
	from PIL import Image
	d = os.path.join(SRC, slug)
	m = json.load(open(os.path.join(d, slug + ".json")))["spritesheet"]
	cw, ch = m["cell_size"]["width"], m["cell_size"]["height"]
	i = m["rows"][0]["directions"].index("east")
	im = Image.open(os.path.join(d, slug + ".png")).convert("RGBA").crop((i * cw, 0, (i + 1) * cw, ch))
	im = im.crop(im.getbbox())
	s = (size - 4) / max(im.width, im.height)
	r = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.BOX)
	r.putalpha(r.getchannel("A").point(lambda v: 255 if v > 100 else 0))
	c = Image.new("RGBA", (size, size))
	c.alpha_composite(r, ((size - r.width) // 2, (size - r.height) // 2))
	buf = io.BytesIO()
	c.save(buf, "PNG")
	return buf.getvalue()


def main() -> None:
	a = sys.argv[1:]
	slug, size = a[0], int(a[1])
	det = json.load(open(os.path.join(SRC, slug, "object.json")))
	prompt = (det.get("prompt") or slug.replace("_", " ")).strip()
	ref = reference(slug, size)
	out = os.path.join(OUT, slug)
	os.makedirs(out, exist_ok=True)
	open(os.path.join(out, "reference.png"), "wb").write(ref)
	print("%s at %d px, reference %s, ~10-25 generations" % (slug, size, os.path.join(out, "reference.png")))
	if "--go" not in a:
		return
	before = pilot.generations()
	body = {"description": prompt + ", small, 1 pixel wide black outline", "view": "low top-down",
		"reference_image": {"type": "base64", "base64": base64.b64encode(ref).decode(), "format": "png"}}
	r = pilot.call("POST", "/create-8-direction-object", body)
	oid = r.get("object_id") or sys.exit("no object: %s" % str(r)[:400])
	if r.get("background_job_id"):
		pilot.wait(r["background_job_id"], fatal=False)
	for _ in range(120):
		o = pilot.call("GET", "/objects/%s" % oid)
		if o.get("status") in ("completed", "failed"):
			break
		time.sleep(8)
	if o.get("status") != "completed":
		sys.exit("object %s: %s" % (oid, o.get("status")))
	import zipfile
	data = pilot.call("GET", "/objects/%s/spritesheet" % oid, raw=True)
	z = zipfile.ZipFile(io.BytesIO(data))
	for n in z.namelist():
		open(os.path.join(out, os.path.basename(n)), "wb").write(z.read(n))
	json.dump(o, open(os.path.join(out, "object.json"), "w"), indent="\t")
	time.sleep(3)
	used = round(before - pilot.generations(), 2)
	log = {"slug": slug, "size": size, "object_id": oid, "files": z.namelist(), "balance_drop": used, "at": time.strftime("%Y-%m-%d %H:%M")}
	json.dump(log, open(os.path.join(out, "log.json"), "w"), indent="\t")
	print("object", oid, "files", z.namelist(), "balance drop", used)


if __name__ == "__main__":
	main()
