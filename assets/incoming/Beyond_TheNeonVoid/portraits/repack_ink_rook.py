#!/usr/bin/env python3
from PIL import Image
import numpy as np
from collections import deque
from scipy import ndimage
import os

IMAGINE = "/home/workdir/artifacts/imagine_images"
OUT = "/home/workdir/artifacts/iso_chars"
CAST = [(100, "ink", "zfuuK"), (103, "rook", "V7BlA")]

def load(iid):
    for ext in (".jpg", ".png"):
        p = os.path.join(IMAGINE, iid + ext)
        if os.path.exists(p):
            return Image.open(p).convert("RGBA")
    raise FileNotFoundError(iid)

def is_key(r, g, b):
    r = r.astype(int); g = g.astype(int); b = b.astype(int)
    hot = (r >= 175) & (g <= 85) & (b >= 70) & ((r - g) >= 80)
    dark = (np.maximum(np.maximum(r, g), b) <= 10)
    return hot | dark

def flood_key(arr):
    h, w = arr.shape[:2]
    seed = is_key(arr[:,:,0], arr[:,:,1], arr[:,:,2])
    vis = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h-1))
    for y in range(h):
        q.append((0, y)); q.append((w-1, y))
    bg = np.zeros((h, w), dtype=bool)
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or vis[y, x]:
            continue
        vis[y, x] = True
        if not seed[y, x]:
            continue
        bg[y, x] = True
        q.append((x+1, y)); q.append((x-1, y))
        q.append((x, y+1)); q.append((x, y-1))
    # close pinholes inside the subject
    subject = ~bg
    subject = ndimage.binary_closing(subject, structure=np.ones((5, 5)))
    subject = ndimage.binary_fill_holes(subject)
    arr[:,:,3] = subject.astype(np.uint8) * 255
    # recolor any leftover magenta-ish pixels that survived inside the subject
    r, g, b = arr[:,:,0].astype(int), arr[:,:,1].astype(int), arr[:,:,2].astype(int)
    leftover = subject & (r >= 170) & (g <= 95) & (b >= 70) & ((r - g) >= 70)
    if leftover.any():
        # replace with local dark charcoal so they don't flash on magenta sheets
        arr[:,:,0][leftover] = 28
        arr[:,:,1][leftover] = 24
        arr[:,:,2][leftover] = 30
    return arr

def extract(im):
    arr = flood_key(np.array(im.convert("RGBA")))
    ys, xs = np.where(arr[:,:,3] > 0)
    if xs.size == 0:
        return Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    pad = 8
    x0, y0 = max(0, xs.min()-pad), max(0, ys.min()-pad)
    x1, y1 = min(arr.shape[1], xs.max()+1+pad), min(arr.shape[0], ys.max()+1+pad)
    return Image.fromarray(arr[y0:y1, x0:x1])

def fit(im, W, H, baseline=8):
    bbox = im.getbbox()
    if not bbox:
        return Image.new("RGBA", (W, H), (0, 0, 0, 0))
    crop = im.crop(bbox)
    cw, ch = crop.size
    scale = min((W-16)/cw, (H-baseline-12)/ch)
    nw, nh = max(1, int(round(cw*scale))), max(1, int(round(ch*scale)))
    crop = crop.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
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
        m256.save(os.path.join(OUT, "masters256", f"BD_iso256_{num}_{name}_se.png"))
        on_magenta(m256, 256, 256).save(os.path.join(OUT, "masters256", f"BD_iso256_{num}_{name}_se_MAGENTA.png"))
        c128.save(os.path.join(OUT, "cells128x192", f"BD_iso128x192_{num}_{name}_se.png"))
        on_magenta(front, 512, 640).save(os.path.join(OUT, "front_sheets", f"BD_iso_{num}_{name}_FRONT_SHEET.png"))
        print("repacked", num, name, "bbox", src.size, flush=True)

if __name__ == "__main__":
    main()
