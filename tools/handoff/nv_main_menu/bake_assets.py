#!/usr/bin/env python3
"""Bake Neon Void main-menu PNGs from the same code as the mockup."""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw

ROOT = "/workspace/neon_void_logo"
OUT = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(OUT, "assets")

os.chdir(ROOT)
src = open("splash3.py").read().split("LOOP=[loop_frame")[0]
exec(src, globals())
os.chdir("press_start_font")
exec(open("render.py").read().split("if __name__")[0], globals())
os.chdir("..")

S3 = 3
logo3 = logo.resize((LW * S3, LH * S3), Image.NEAREST)
LX, LY = (SW - logo3.width) // 2, 22
GL = glow(logo3, 6, 0.9)
LOGO = Image.new("RGBA", (SW, SH))
LOGO.alpha_composite(GL, (LX, LY))
LOGO.alpha_composite(logo3, (LX, LY))

ITEMS = ["CONTINUE", "NEW GAME", "LOAD GAME", "OPTIONS", "CREDITS", "QUIT"]
IDS = ["continue", "new_game", "load", "options", "credits", "quit"]
Y0, STEP = 196, 24


def dim(m, col, sc=2):
    M = np.kron(m, np.ones((sc, sc), bool))
    a = np.zeros(M.shape + (4,), np.uint8)
    a[M] = col + (255,)
    return Image.fromarray(a)


ON = [screen(mask(t), 2) for t in ITEMS]
OFF = [dim(mask(t), (150, 120, 190)) for t in ITEMS]
DISABLED = dim(mask(ITEMS[0]), (70, 56, 88))

tri = np.zeros((9, 6), bool)
for y in range(9):
    w = min(y, 8 - y) + 1
    tri[y, :w] = True
ARW = Image.new("RGBA", (10, 13))
a = np.array(ARW)
from scipy.ndimage import binary_dilation as _bd
P = np.zeros((13, 10), bool)
P[2:11, 2:8] = tri
a[_bd(P, iterations=1)] = (2, 0, 11, 255)
a[P] = (76, 254, 236, 255)
ARW = Image.fromarray(a)

hint = white(mask("ENTER SELECT   ESC BACK"), 1)
ver = white(mask("V0.1"), 1)
hs = Image.fromarray((np.array(hint) * np.array([0.55, 0.55, 0.7, 1])).astype(np.uint8))

# panel and bar as PNG layers
panel = Image.new("RGBA", (SW, SH))
ImageDraw.Draw(panel).rectangle(
    [SW // 2 - 110, Y0 - 10, SW // 2 + 110, Y0 + STEP * len(ITEMS) - 4],
    fill=(6, 4, 16, 170),
    outline=(110, 30, 130, 255),
)
bar_full = Image.new("RGBA", (SW, SH))
# baked at sel row 0; Godot will blit the crop at the right y
ImageDraw.Draw(bar_full).rectangle(
    [SW // 2 - 104, Y0 - 6, SW // 2 + 104, Y0 + 16],
    fill=(254, 4, 137, 40),
)
bx0, by0, bx1, by1 = SW // 2 - 104, Y0 - 6, SW // 2 + 104, Y0 + 16
bar = bar_full.crop((bx0, by0, bx1 + 1, by1 + 1))

# chrome = bg(t) + logo + panel + hint + ver  (no items, no CRT)
os.makedirs(os.path.join(ASSETS, "chrome"), exist_ok=True)
os.makedirs(os.path.join(ASSETS, "items"), exist_ok=True)
for t in range(32):
    c = bg(t)
    c.alpha_composite(LOGO)
    c.alpha_composite(panel)
    c.alpha_composite(hs, ((SW - hint.width) // 2, SH - 14))
    c.alpha_composite(ver, (SW - ver.width - 6, SH - 12))
    c.save(os.path.join(ASSETS, "chrome", "%02d.png" % t))

for i, iid in enumerate(IDS):
    ON[i].save(os.path.join(ASSETS, "items", iid + "_on.png"))
    OFF[i].save(os.path.join(ASSETS, "items", iid + "_off.png"))
DISABLED.save(os.path.join(ASSETS, "items", "continue_disabled.png"))
ARW.save(os.path.join(ASSETS, "cursor.png"))
bar.save(os.path.join(ASSETS, "bar.png"))

item_meta = []
for i, iid in enumerate(IDS):
    im = ON[i]
    item_meta.append({
        "id": iid,
        "label": ITEMS[i],
        "x": (SW - im.width) // 2,
        "w": im.width,
        "h": im.height,
        "off_w": OFF[i].width,
        "off_h": OFF[i].height,
        "off_x": (SW - OFF[i].width) // 2,
    })

lut = (np.arange(256) * 0.85).astype(np.uint8).tolist()
layout = {
    "width": SW,
    "height": SH,
    "fps": 12,
    "loop": 32,
    "y0": Y0,
    "step": STEP,
    "logo": [LX, LY, logo3.width, logo3.height],
    "hint": [(SW - hint.width) // 2, SH - 14, hint.width, hint.height],
    "ver": [SW - ver.width - 6, SH - 12, ver.width, ver.height],
    "panel": [SW // 2 - 110, Y0 - 10, SW // 2 + 110, Y0 + STEP * len(ITEMS) - 4],
    "bar": {"x": bx0, "dy": -6, "w": bar.width, "h": bar.height},
    "cursor": {"w": ARW.width, "h": ARW.height, "gap": 6},
    "items": item_meta,
    "lut85": lut,
}
json.dump(layout, open(os.path.join(ASSETS, "layout.json"), "w"), indent=1)
print("layout", json.dumps({k: layout[k] for k in layout if k != "lut85"}, indent=2))
print("bar", bar.size, "cursor", ARW.size, "items", [(m["id"], m["x"], m["w"], m["h"], m["off_x"], m["off_w"]) for m in item_meta])

# reference full frames (with CRT) for verify
expect_dir = "/tmp/nv_menu_expect"
os.makedirs(expect_dir, exist_ok=True)


def frame(t, sel, has_save=True):
    c = bg(t)
    c.alpha_composite(LOGO)
    c.alpha_composite(panel)
    for i in range(len(ITEMS)):
        if not has_save and i == 0:
            im = DISABLED
        elif i == sel:
            im = ON[i]
        else:
            im = OFF[i]
        x = (SW - im.width) // 2
        y = Y0 + i * STEP - (4 if i == sel else 0)
        if i == sel:
            bar_i = Image.new("RGBA", (SW, SH))
            ImageDraw.Draw(bar_i).rectangle(
                [SW // 2 - 104, Y0 + i * STEP - 6, SW // 2 + 104, Y0 + i * STEP + 16],
                fill=(254, 4, 137, 40),
            )
            c.alpha_composite(bar_i)
            bob = (t // 3) % 2
            c.alpha_composite(ARW, (x - ARW.width - 6 + bob, y))
        c.alpha_composite(im, (x, y))
    c.alpha_composite(hs, ((SW - hint.width) // 2, SH - 14))
    c.alpha_composite(ver, (SW - ver.width - 6, SH - 12))
    return crt(c)


# mock.gif set + a few extras including t%32 wrap and disabled
pairs = []
for sel in range(6):
    for t in range(10):
        pairs.append((sel * 10 + t, sel, True))
for t, sel in [(0, 0), (4, 1), (7, 2), (31, 5), (32, 0), (8, 3)]:
    pairs.append((t, sel, True))
pairs += [(4, 1, False), (0, 1, False), (9, 5, False)]

written = set()
for t, sel, hs_ in pairs:
    name = "t%02d_s%d_%s.png" % (t % 32 if False else t, sel, "save" if hs_ else "nosave")
    # keep t as used in frame() (bg uses t%32 already via t%=L in bg? bg does t%=L at start)
    # Use raw t like the mockup (frame(sel*10+t, sel))
    key = (t, sel, hs_)
    if key in written:
        continue
    written.add(key)
    frame(t, sel, hs_).convert("RGBA").save(os.path.join(expect_dir, "t%d_s%d_%s.png" % (t, sel, "save" if hs_ else "nosave")))

# also dump the official mock still
frame(4, 1).convert("RGBA").save(os.path.join(expect_dir, "mock_t4_s1.png"))
print("expect", len(written), "ok")
