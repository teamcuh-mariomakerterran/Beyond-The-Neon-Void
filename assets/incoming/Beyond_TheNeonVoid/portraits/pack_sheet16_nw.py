#!/usr/bin/env python3
from PIL import Image
import numpy as np, os
from scipy import ndimage

IMAGINE = "/home/workdir/artifacts/imagine_images"
OUT = "/home/workdir/artifacts/iso_chars"
os.makedirs(os.path.join(OUT, "masters256"), exist_ok=True)
os.makedirs(os.path.join(OUT, "cells128x192"), exist_ok=True)
os.makedirs(os.path.join(OUT, "solo_sheets"), exist_ok=True)

CAST = [
    (123, "fuse",    "KJJ65"),
    (124, "gyro",    "FHKs5"),
    (125, "coil",    "Mv6mK"),
    (126, "ratchet", "KfSRn"),
    (127, "censer",  "eREEx"),
    (128, "marrow",  "Sldoh"),
    (129, "latch",   "GA4zO"),
    (130, "psalm",   "9frts"),
]

def load(iid):
    for ext in (".jpg", ".png"):
        p = os.path.join(IMAGINE, iid + ext)
        if os.path.exists(p):
            return Image.open(p).convert("RGBA")
    raise FileNotFoundError(iid)

def is_bg(r, g, b):
    r = r.astype(int); g = g.astype(int); b = b.astype(int)
    hot = (r >= 180) & (g <= 80) & (b >= 70) & ((r - g) >= 80)
    dark = (np.maximum(np.maximum(r, g), b) <= 12)
    return hot | dark

def extract(im):
    arr = np.array(im.convert("RGBA"))
    bg = is_bg(arr[:, :, 0], arr[:, :, 1], arr[:, :, 2])
    arr[:, :, 3] = np.where(bg, 0, 255).astype(np.uint8)
    # strip dirty magenta leftovers still marked opaque
    r, g, b, al = arr[:, :, 0].astype(int), arr[:, :, 1].astype(int), arr[:, :, 2].astype(int), arr[:, :, 3]
    dirty = (al > 0) & (r >= 100) & (g <= 55) & (b >= 55) & ((r - g) >= 50)
    arr[dirty, 3] = 0
    opaque = arr[:, :, 3] > 0
    filled = ndimage.binary_fill_holes(opaque)
    holes = filled & ~opaque
    if holes.any():
        for _ in range(8):
            if not (filled & (arr[:, :, 3] == 0)).any():
                break
            dil = ndimage.binary_dilation(arr[:, :, 3] > 0)
            ring = dil & filled & (arr[:, :, 3] == 0)
            ys, xs = np.where(ring)
            for y, x in zip(ys, xs):
                y0, y1 = max(0, y - 1), min(arr.shape[0], y + 2)
                x0, x1 = max(0, x - 1), min(arr.shape[1], x + 2)
                n = arr[y0:y1, x0:x1]
                m = n[:, :, 3] > 0
                if m.any():
                    arr[y, x, :3] = n[:, :, :3][m].mean(axis=0).astype(np.uint8)
                    arr[y, x, 3] = 255
        leftover = filled & (arr[:, :, 3] == 0)
        arr[leftover, 0] = 42
        arr[leftover, 1] = 36
        arr[leftover, 2] = 50
        arr[leftover, 3] = 255
    ys, xs = np.where(arr[:, :, 3] > 0)
    if xs.size == 0:
        return Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    pad = 8
    x0, y0 = max(0, xs.min() - pad), max(0, ys.min() - pad)
    x1, y1 = min(arr.shape[1], xs.max() + 1 + pad), min(arr.shape[0], ys.max() + 1 + pad)
    return Image.fromarray(arr[y0:y1, x0:x1])

def fit(im, W, H, baseline=8):
    im = im.convert("RGBA")
    bbox = im.getbbox()
    if not bbox:
        return Image.new("RGBA", (W, H), (0, 0, 0, 0))
    crop = im.crop(bbox)
    cw, ch = crop.size
    scale = min((W - 16) / cw, (H - baseline - 12) / ch)
    nw = max(1, int(round(cw * scale)))
    nh = max(1, int(round(ch * scale)))
    crop = crop.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.paste(crop, ((W - nw) // 2, H - nh - baseline), crop)
    return canvas

def on_magenta(im, W, H):
    base = Image.new("RGB", (W, H), (255, 0, 170))
    base.paste(im.convert("RGB"), mask=im.split()[-1])
    return base

def main():
    nw_previews = []
    for num, name, iid in CAST:
        src = extract(load(iid))
        m256 = fit(src, 256, 256, 6)
        c128 = fit(src, 128, 192, 4)
        m256.save(os.path.join(OUT, "masters256", f"BD_iso256_{num}_{name}_nw.png"))
        on_magenta(m256, 256, 256).save(os.path.join(OUT, "masters256", f"BD_iso256_{num}_{name}_nw_MAGENTA.png"))
        c128.save(os.path.join(OUT, "cells128x192", f"BD_iso128x192_{num}_{name}_nw.png"))
        print("packed NW", num, name, "bbox", src.size, flush=True)

        se = Image.open(os.path.join(OUT, "masters256", f"BD_iso256_{num}_{name}_se.png")).convert("RGBA")
        se_fit = fit(se, 380, 456, 8)
        nw_fit = fit(m256, 380, 456, 8)
        solo = Image.new("RGB", (800, 480), (255, 0, 170))
        solo.paste(se_fit.convert("RGB"), (10, 12), se_fit)
        solo.paste(nw_fit.convert("RGB"), (410, 12), nw_fit)
        solo.save(os.path.join(OUT, "solo_sheets", f"BD_iso_{num}_{name}_SOLO_SHEET.png"))
        nw_previews.append(m256)

    grid = Image.new("RGBA", (1024, 512), (0, 0, 0, 255))
    for i, im in enumerate(nw_previews):
        r, c = divmod(i, 4)
        bg = Image.new("RGBA", (256, 256), (0, 0, 0, 255))
        bg.paste(im, (0, 0), im)
        grid.paste(bg, (c * 256, r * 256))
    grid.save(os.path.join(OUT, "BD_iso256_sheet16_4x2_nw.png"))
    print("NW preview + solo sheets written", flush=True)

if __name__ == "__main__":
    main()
