"""Make a new state of a PixelLab character by a text edit of all its rotations
(POST /create-character-state), then download the export (free).

    python3 -I tools/pixellab/make_state.py <character_id> "<edit>" <state name> <out.zip>          # plan
    python3 -I tools/pixellab/make_state.py <character_id> "<edit>" <state name> <out.zip> --go     # ~10 generations

Used for the modular base bodies: a light neutral bodysuit cuts cleanly
against dark and coloured gear (tools/pixellab/cut_parts.py).
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pilot  # noqa: E402


def main() -> None:
	a = sys.argv[1:]
	cid, edit, name, out = a[0], a[1], a[2], a[3]
	print("state of %s: %r as %r, ~10 generations" % (cid[:8], edit, name))
	if "--go" not in a:
		return
	before = pilot.generations()
	r = pilot.call("POST", "/create-character-state", {"character_id": cid, "edit_description": edit, "state_name": name,
		"use_color_palette_from_reference": False, "no_background": True})
	pilot.wait(r["background_job_id"])
	new_id = r.get("character_id")
	time.sleep(3)
	used = round(before - pilot.generations(), 2)
	data = pilot.call("GET", "/characters/%s/zip" % new_id, raw=True)
	os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
	open(out, "wb").write(data)
	json.dump(pilot.call("GET", "/characters/%s" % new_id), open(out[:-4] + "_detail.json", "w"), indent="\t")
	print("state", new_id, "saved", out, "balance drop", used)


if __name__ == "__main__":
	main()
