#!/usr/bin/env python3
import os, re, sys
from PIL import Image
import numpy as np
from scipy import ndimage

# reuse helpers from heal_magenta
import importlib.util
spec = importlib.util.spec_from_file_location("hm", "/home/workdir/artifacts/iso_chars/heal_magenta.py")
hm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hm)

MASTERS = hm.MASTERS
CELLS = hm.CELLS
FRONT = hm.FRONT

files = sorted(f for f in os.listdir(MASTERS) if f.endswith(".png") and "MAGENTA" not in f)
changed = 0
for f in files:
    rest = f.replace("BD_iso256_", "")
    num = rest.split("_")[0]
    try:
        n = int(num)
    except ValueError:
        n = 999
    if n < 36:
        continue
    path = os.path.join(MASTERS, f)
    try:
        im = Image.open(path)
        im.load()
    except Exception as e:
        print("SKIP", f, e, flush=True)
        continue
    healed, stats = hm.heal(im)
    if stats["holes"] or stats["specks"] or stats["shadow"]:
        healed.save(path)
        hm.on_magenta(healed, *healed.size).save(path.replace(".png", "_MAGENTA.png"))
        numi, name, facing = hm.parse_name(f)
        if facing == "se" and numi is not None and name:
            hm.fit(healed, 128, 192, 4).save(os.path.join(CELLS, f"BD_iso128x192_{numi}_{name}_se.png"))
            front = hm.fit(healed, 512, 640, 24)
            hm.on_magenta(front, 512, 640).save(os.path.join(FRONT, f"BD_iso_{numi}_{name}_FRONT_SHEET.png"))
        print("healed", f, stats, flush=True)
        changed += 1
    else:
        print("clean ", f, flush=True)
print("CHANGED", changed, flush=True)
