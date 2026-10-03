#!/usr/bin/env python3
"""
Heal transparent iso masters:
- fill enclosed alpha holes by inpainting neighbor colors
- recolor small isolated key-color speckles inside the figure
- strip magenta contact shadows under the feet
Then rebuild SE front sheets + magenta 256 masters.
Does NOT recolor large intentional pink regions (e.g. Mother Hex hair).
"""
from PIL import Image
import numpy as np
from scipy import ndimage
import os, re

MASTERS = "/home/workdir/artifacts/iso_chars/masters256"
CELLS = "/home/workdir/artifacts/iso_chars/cells128x192"
FRONT = "/home/workdir/artifacts/iso_chars/front_sheets"
os.makedirs(FRONT, exist_ok=True)

KEY = np.array([255, 0, 170], dtype=np.int16)

def is_key(r, g, b, loose=False):
    r = r.astype(int); g = g.astype(int); b = b.astype(int)
    if loose:
        return (r >= 170) & (g <= 90) & (b >= 80) & ((r - g) >= 80)
    return (r >= 200) & (g <= 55) & (b >= 100) & ((r - g) >= 140) & (b > g + 40)

def inpaint(arr, mask, radius=4):
    """Fill mask pixels by repeated 3x3 dilation from neighboring opaque colors."""
    out = arr.copy()
    fill = mask.copy()
    known = (out[:,:,3] > 16) & ~fill
    kernel = np.ones((3, 3), dtype=bool)
    guard = 0
    while fill.any() and guard < 24:
        guard += 1
        grow = ndimage.binary_dilation(known, structure=kernel) & fill
        if not grow.any():
            break
        # mean of known neighbors per channel
        for c in range(3):
            acc = ndimage.convolve(out[:,:,c].astype(np.float32) * known, np.ones((3,3)), mode="constant")
            cnt = ndimage.convolve(known.astype(np.float32), np.ones((3,3)), mode="constant")
            pix = grow & (cnt > 0)
            out[:,:,c][pix] = (acc[pix] / np.maximum(cnt[pix], 1)).astype(np.uint8)
        out[:,:,3][grow] = 255
        known |= grow
        fill &= ~grow
    if fill.any():
        out[:,:,0][fill] = 28
        out[:,:,1][fill] = 24
        out[:,:,2][fill] = 30
        out[:,:,3][fill] = 255
    return out

def heal(im):
    arr = np.array(im.convert("RGBA"))
    alpha = arr[:,:,3] > 16
    stats = {"holes": 0, "specks": 0, "shadow": 0}

    # 1) enclosed alpha holes
    filled = ndimage.binary_fill_holes(alpha)
    holes = filled & ~alpha
    # ignore huge fills that would close legs-apart stances (crotch)
    # only fill hole regions under 400 px — crotch between planted feet can be larger
    lab, n = ndimage.label(holes)
    hole_mask = np.zeros_like(holes)
    for i in range(1, n+1):
        sl = lab == i
        sz = int(sl.sum())
        if 2 <= sz <= 400:
            hole_mask |= sl
            stats["holes"] += sz
    if hole_mask.any():
        arr = inpaint(arr, hole_mask, radius=3)
        alpha = arr[:,:,3] > 16

    # 2) small isolated key speckles in the core (not hair masses)
    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]
    key = is_key(r, g, b) & alpha
    core = ndimage.binary_erosion(alpha, iterations=2)
    spec = key & core
    lab, n = ndimage.label(spec)
    speck_mask = np.zeros_like(spec)
    for i in range(1, n+1):
        sl = lab == i
        sz = int(sl.sum())
        if sz <= 40:  # hair would be hundreds
            speck_mask |= sl
            stats["specks"] += sz
    if speck_mask.any():
        arr = inpaint(arr, speck_mask, radius=3)
        alpha = arr[:,:,3] > 16

    # 3) magenta contact shadow under feet
    # look at bottom 28% of subject bbox
    ys, xs = np.where(alpha)
    if ys.size:
        y0, y1 = ys.min(), ys.max()
        x0, x1 = xs.min(), xs.max()
        band_y = int(y0 + 0.72 * (y1 - y0))
        r, g, b = arr[:,:,0].astype(int), arr[:,:,1].astype(int), arr[:,:,2].astype(int)
        loose = is_key(arr[:,:,0], arr[:,:,1], arr[:,:,2], loose=True) & alpha
        # also darkened magenta (shadow): high R, low G, mid B, but darker
        shadowish = (r >= 120) & (g <= 80) & (b >= 60) & ((r - g) >= 50) & (b > g) & alpha
        band = np.zeros_like(alpha)
        band[band_y:y1+1, x0:x1+1] = True
        sh = (loose | shadowish) & band
        # keep only components that sit on the bottom and are relatively flat
        lab, n = ndimage.label(sh)
        sh_mask = np.zeros_like(sh)
        for i in range(1, n+1):
            sl = lab == i
            ys2, xs2 = np.where(sl)
            hgt = ys2.max() - ys2.min() + 1
            wid = xs2.max() - xs2.min() + 1
            # shadow is wide-ish and short, touches near bbox bottom
            if ys2.max() >= y1 - 4 and hgt <= max(18, int(0.22 * (y1 - y0))) and wid >= 8:
                sh_mask |= sl
                stats["shadow"] += int(sl.sum())
        if sh_mask.any():
            arr[:,:,3][sh_mask] = 0  # drop shadow to transparent
    return Image.fromarray(arr), stats

def fit(im, W, H, baseline=8):
    im = im.convert("RGBA")
    bbox = im.getbbox()
    if not bbox:
        return Image.new("RGBA", (W, H), (0, 0, 0, 0))
    crop = im.crop(bbox)
    cw, ch = crop.size
    scale = min((W - 16) / cw, (H - baseline - 12) / ch)
    nw, nh = max(1, int(round(cw * scale))), max(1, int(round(ch * scale)))
    crop = crop.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.paste(crop, ((W - nw) // 2, H - nh - baseline), crop)
    return canvas

def on_magenta(im, W, H):
    base = Image.new("RGB", (W, H), (255, 0, 170))
    base.paste(im.convert("RGB"), mask=im.split()[-1])
    return base

def parse_name(fname):
    # BD_iso256_107_rivet_se.png  or BD_iso256_orchid_se.png
    m = re.match(r"BD_iso256_(\d+)_([a-z0-9]+)_((?:se|nw))\.png", fname)
    if m:
        return int(m.group(1)), m.group(2), m.group(3)
    m = re.match(r"BD_iso256_([a-z0-9]+)_((?:se|nw))\.png", fname)
    if m:
        return None, m.group(1), m.group(2)
    return None, None, None

def main():
    files = sorted(f for f in os.listdir(MASTERS) if f.endswith(".png") and "MAGENTA" not in f)
    changed = []
    for f in files:
        path = os.path.join(MASTERS, f)
        im = Image.open(path)
        healed, stats = heal(im)
        if stats["holes"] or stats["specks"] or stats["shadow"]:
            healed.save(path)
            mag = path.replace(".png", "_MAGENTA.png")
            on_magenta(healed, *healed.size).save(mag)
            changed.append((f, stats))
            num, name, facing = parse_name(f)
            if facing == "se" and num is not None and name:
                cell = fit(healed, 128, 192, 4)
                cell.save(os.path.join(CELLS, f"BD_iso128x192_{num}_{name}_se.png"))
                front = fit(healed, 512, 640, 24)
                on_magenta(front, 512, 640).save(os.path.join(FRONT, f"BD_iso_{num}_{name}_FRONT_SHEET.png"))
            print(f"healed {f}  holes={stats['holes']} specks={stats['specks']} shadow={stats['shadow']}", flush=True)
        else:
            print(f"clean  {f}", flush=True)

    print("\nCHANGED", len(changed), "/", len(files), flush=True)
    # write summary
    with open("/home/workdir/artifacts/iso_chars/HEAL_LOG.txt", "w") as fh:
        fh.write(f"changed {len(changed)} / {len(files)}\n")
        for f, s in changed:
            fh.write(f"{f}  holes={s['holes']} specks={s['specks']} shadow={s['shadow']}\n")

if __name__ == "__main__":
    main()
