#!/usr/bin/env python3
from PIL import Image
import numpy as np, os
from collections import deque

IMAGINE = "/home/workdir/artifacts/imagine_images"
OUT = "/home/workdir/artifacts/iso_chars"
os.makedirs(os.path.join(OUT, "masters256"), exist_ok=True)
os.makedirs(os.path.join(OUT, "cells128x192"), exist_ok=True)
os.makedirs(os.path.join(OUT, "front_sheets"), exist_ok=True)

CAST = [
    (99, "axle",   "s2rmO"),
    (100,"ink",    "vLQ8C"),
    (101,"reel",   "FkeCy"),
    (102,"grid",   "K0idZ"),
    (103,"rook",   "bwIRn"),
    (104,"glitch", "vlFTO"),
    (105,"dusk",   "gDqbL"),
    (106,"crate",  "6wAbx"),
]

def load(iid):
    for ext in (".jpg", ".png"):
        p = os.path.join(IMAGINE, iid + ext)
        if os.path.exists(p):
            return Image.open(p).convert("RGBA")
    raise FileNotFoundError(iid)

def is_bg(r, g, b):
    r = r.astype(int); g = g.astype(int); b = b.astype(int)
    hot = (r >= 180) & (g <= 70) & (b >= 70) & ((r - g) >= 90)
    dark = (np.maximum(np.maximum(r, g), b) <= 12)
    return hot | dark

def extract(im):
    arr = np.array(im.convert("RGBA"))
    bg = is_bg(arr[:,:,0], arr[:,:,1], arr[:,:,2])
    arr[:,:,3] = np.where(bg, 0, 255).astype(np.uint8)
    ys, xs = np.where(arr[:,:,3] > 0)
    if xs.size == 0:
        return Image.new("RGBA", (8,8), (0,0,0,0))
    pad = 8
    x0, y0 = max(0, xs.min()-pad), max(0, ys.min()-pad)
    x1, y1 = min(arr.shape[1], xs.max()+1+pad), min(arr.shape[0], ys.max()+1+pad)
    return Image.fromarray(arr[y0:y1, x0:x1])

def fit(im, W, H, baseline=8):
    im = im.convert("RGBA")
    bbox = im.getbbox()
    if not bbox:
        return Image.new("RGBA", (W, H), (0,0,0,0))
    crop = im.crop(bbox)
    cw, ch = crop.size
    scale = min((W-16)/cw, (H-baseline-12)/ch)
    nw = max(1, int(round(cw*scale))); nh = max(1, int(round(ch*scale)))
    crop = crop.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", (W, H), (0,0,0,0))
    canvas.paste(crop, ((W-nw)//2, H-nh-baseline), crop)
    return canvas

def on_magenta(im, W, H):
    base = Image.new("RGB", (W, H), (255, 0, 170))
    base.paste(im.convert("RGB"), mask=im.split()[-1])
    return base

def main():
    for num, name, iid in CAST:
        src = extract(load(iid))
        m256 = fit(src, 256, 256, 6)
        c128 = fit(src, 128, 192, 4)
        front = fit(src, 512, 640, 24)
        m256.save(os.path.join(OUT, "masters256", f"BD_iso256_{num:02d}_{name}_se.png"))
        on_magenta(m256, 256, 256).save(os.path.join(OUT, "masters256", f"BD_iso256_{num:02d}_{name}_se_MAGENTA.png"))
        c128.save(os.path.join(OUT, "cells128x192", f"BD_iso128x192_{num:02d}_{name}_se.png"))
        on_magenta(front, 512, 640).save(os.path.join(OUT, "front_sheets", f"BD_iso_{num:02d}_{name}_FRONT_SHEET.png"))
        print("packed", num, name, "bbox", src.size, flush=True)

if __name__ == "__main__":
    main()
