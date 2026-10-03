#!/usr/bin/env python3
from PIL import Image
import numpy as np, os
from scipy import ndimage

IMAGINE = "/home/workdir/artifacts/imagine_images"
OUT = "/home/workdir/artifacts/iso_chars"
os.makedirs(os.path.join(OUT, "masters256"), exist_ok=True)
os.makedirs(os.path.join(OUT, "cells128x192"), exist_ok=True)
os.makedirs(os.path.join(OUT, "front_sheets"), exist_ok=True)

CAST = [
    (123, "fuse",    "UzZrp"),
    (124, "gyro",    "U9yUY"),
    (125, "coil",    "U7l6G"),
    (126, "ratchet", "pbPwI"),
    (127, "censer",  "zh57p"),
    (128, "marrow",  "Cx9AI"),
    (129, "latch",   "RGbyG"),
    (130, "psalm",   "KUqmZ"),
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
    r, g, b, al = arr[:, :, 0].astype(int), arr[:, :, 1].astype(int), arr[:, :, 2].astype(int), arr[:, :, 3]
    dirty = (al > 0) & (r >= 100) & (g <= 55) & (b >= 55) & ((r - g) >= 50)
    arr[dirty, 3] = 0
    opaque = arr[:, :, 3] > 0
    filled = ndimage.binary_fill_holes(opaque)
    holes = filled & ~opaque
    if holes.any():
        # inpaint from nearest opaque neighbor colors
        for _ in range(8):
            if not holes.any():
                break
            dil = ndimage.binary_dilation(opaque)
            ring = dil & holes
            ys, xs = np.where(ring)
            for y, x in zip(ys, xs):
                y0, y1 = max(0, y - 1), min(arr.shape[0], y + 2)
                x0, x1 = max(0, x - 1), min(arr.shape[1], x + 2)
                neigh = arr[y0:y1, x0:x1]
                mask = neigh[:, :, 3] > 0
                if mask.any():
                    arr[y, x, :3] = neigh[:, :, :3][mask].mean(axis=0).astype(np.uint8)
                    arr[y, x, 3] = 255
            opaque = arr[:, :, 3] > 0
            holes = filled & ~opaque
        arr[holes, 3] = 255
        arr[holes, 0] = 40
        arr[holes, 1] = 30
        arr[holes, 2] = 50
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

def on_black(im, W, H):
    base = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    base.paste(im, (0, 0), im)
    return base

def main():
    thumbs = []
    for num, name, iid in CAST:
        src = extract(load(iid))
        m256 = fit(src, 256, 256, 6)
        c128 = fit(src, 128, 192, 4)
        front = fit(src, 512, 640, 24)
        m256.save(os.path.join(OUT, "masters256", f"BD_iso256_{num}_{name}_se.png"))
        on_magenta(m256, 256, 256).save(os.path.join(OUT, "masters256", f"BD_iso256_{num}_{name}_se_MAGENTA.png"))
        c128.save(os.path.join(OUT, "cells128x192", f"BD_iso128x192_{num}_{name}_se.png"))
        on_magenta(front, 512, 640).save(os.path.join(OUT, "front_sheets", f"BD_iso_{num}_{name}_FRONT_SHEET.png"))
        thumbs.append(on_black(m256, 256, 256))
        print("packed", num, name, "bbox", src.size, flush=True)

    grid = Image.new("RGBA", (1024, 512), (0, 0, 0, 255))
    mag = Image.new("RGB", (1024, 512), (255, 0, 170))
    for i, th in enumerate(thumbs):
        x, y = (i % 4) * 256, (i // 4) * 256
        grid.paste(th, (x, y))
        mag.paste(on_magenta(th, 256, 256), (x, y))
    grid.save(os.path.join(OUT, "BD_iso256_sheet16_4x2_se.png"))
    mag.save(os.path.join(OUT, "BD_iso256_sheet16_4x2_se_MAGENTA.png"))
    print("preview grid written", flush=True)

if __name__ == "__main__":
    main()
