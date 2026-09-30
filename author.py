#!/usr/bin/env python3
"""PARALLAX .parallax.json authoring helpers for Cutscene Director."""
from __future__ import annotations
import re
import base64, json, random, string, io
from pathlib import Path
from typing import Any

ROOT = Path('/workspace/bd-tools/cutscene')
ASSETS = ROOT / 'assets'
PROJECTS = ROOT / 'projects'

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False


def uid(n: int = 7) -> str:
    alphabet = string.ascii_lowercase + string.digits
    return ''.join(random.choice(alphabet) for _ in range(n))


def data_url(path: Path, max_w: int | None = 640) -> tuple[str, int, int]:
    raw = path.read_bytes()
    mime = 'image/png'
    suf = path.suffix.lower()
    if suf in ('.jpg', '.jpeg'):
        mime = 'image/jpeg'
    elif suf == '.gif':
        mime = 'image/gif'
    w = h = 0
    if HAS_PIL and suf in ('.png', '.jpg', '.jpeg', '.webp'):
        im = Image.open(io.BytesIO(raw))
        w, h = im.size
        if max_w and w > max_w:
            nh = max(1, int(h * (max_w / w)))
            im = im.convert('RGBA') if suf == '.png' else im.convert('RGB')
            im = im.resize((max_w, nh), Image.Resampling.NEAREST)
            buf = io.BytesIO()
            if suf in ('.jpg', '.jpeg'):
                im.save(buf, format='JPEG', quality=85)
                mime = 'image/jpeg'
            else:
                im.save(buf, format='PNG')
                mime = 'image/png'
            raw = buf.getvalue()
            w, h = im.size
    b64 = base64.b64encode(raw).decode('ascii')
    return f'data:{mime};base64,{b64}', w, h


def load_asset(path: Path | str, name: str | None = None, max_w: int | None = 640) -> dict:
    path = Path(path)
    src, w, h = data_url(path, max_w=max_w)
    return {'id': uid(), 'name': name or path.name, 'src': src, 'gif': None, '_w': w, '_h': h}


def new_cam(**over) -> dict:
    cam = {
        'panX': 0, 'panY': 0, 'zoom0': 1, 'zoom1': 1, 'ease': 'out',
        'shake': 0, 'shakeFreq': 22, 'shakeDecay': True,
        'follow': None, 'followAmt': 1, 'followX': 0.5, 'followY': 0.6, 'k': None,
    }
    cam.update(over)
    return cam


def new_fx(**over) -> dict:
    fx = {
        'bright': 1, 'contrast': 1, 'sat': 1, 'hue': 0,
        'flash': 0, 'flashColor': '#ffffff', 'flashDur': 0.18,
        'vignette': 0, 'scan': 0, 'grain': 0, 'bars': 0,
        'tint': '#3ee0d8', 'tintAmt': 0, 'chroma': 0, 'k': None,
    }
    fx.update(over)
    return fx


def new_tin(type: str = 'fade', dur: float = 0.4, color: str = '#000000') -> dict:
    return {'type': type, 'dur': dur, 'color': color}


def new_layer(kind: str = 'image', **over) -> dict:
    L = {
        'id': uid(), 'kind': kind,
        'name': over.pop('name', kind.title()),
        'assetId': None, 'slot': None, 'action': 'idle', 'palette': None, 'k': None,
        'visible': True, 'attach': None, 'group': None,
        'maskLayer': None, 'maskInvert': False, 'maskSource': False,
        'x': 0, 'y': 0, 'scale': 1, 'opacity': 1, 'anchor': 'bottom',
        'flipH': False, 'flipV': False,
        'speedX': 0, 'speedY': 0, 'parallax': 1, 'tileX': False, 'tileY': False,
        'bobAmp': 0, 'bobSpeed': 1,
        'tint': '#ff4fa3', 'tintAmt': 0, 'bright': 1, 'sat': 1, 'contrast': 1, 'hue': 0, 'blur': 0,
        'blend': 'source-over', 'color': '#1a1030',
        'frameW': 32, 'frameH': 32, 'frameCount': 0, 'fps': 12, 'loop': True, 'pingpong': False,
        'delay': 0, 'hideBefore': True, 'holdLast': True, 'startFrame': 0,
        'stopScale': 0, 'mblur': 0, 'mblurSamples': 5,
        'insL': 8, 'insR': 8, 'insT': 8, 'insB': 8, 'boxW': 200, 'boxH': 64, 'edgeMode': 'stretch',
        'fxMode': 'shimmer', 'amp': 3, 'freq': 6, 'speed': 2, 'band': 1, 'fxW': 160, 'fxH': 90, 'falloff': 1,
        'wrap': False, 'wrapW': 200, 'lineH': 1.35, 'reveal': 0, 'revealDelay': 0,
        'text': 'TEXT', 'fontMode': 'system', 'fontFam': 'monospace', 'fontSize': 16,
        'textColor': '#ffffff', 'outline': 1, 'outlineColor': '#000000',
        'align': 'center', 'tracking': 0, 'glyphW': 8, 'glyphH': 8,
        'charset': " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    }
    L.update(over)
    return L


def new_shot(**over) -> dict:
    S = {
        'id': uid(), 'name': 'Shot', 'dur': 2, 'bg': '#05060e',
        'layers': [], 'groups': [], 'stops': [], 'audio': [], 'events': [],
        'markers': [], 'branch': [], 'next': None,
        'tin': new_tin('cut', 0.3),
        'cam': new_cam(),
        'fx': new_fx(),
    }
    S.update(over)
    if 'cam' in over and isinstance(over['cam'], dict):
        S['cam'] = new_cam(**over['cam']) if not all(k in over['cam'] for k in ('panX', 'zoom0')) else {**new_cam(), **over['cam']}
    if 'fx' in over and isinstance(over['fx'], dict):
        S['fx'] = {**new_fx(), **over['fx']}
    return S


def new_project(name: str, **over) -> dict:
    P = {
        'name': name, 'w': 320, 'h': 180, 'fps': 30,
        'units': [], 'slots': [], 'palettes': [], 'vars': {},
        'shots': [],
    }
    P.update(over)
    return P


def write_project(path: Path | str, project: dict, assets: list[dict], sounds: list | None = None) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    clean_assets = [{'id': a['id'], 'name': a['name'], 'src': a['src'], 'gif': a.get('gif')} for a in assets]
    data = {'version': 1, 'project': project, 'assets': clean_assets, 'sounds': sounds or []}
    path.write_text(json.dumps(data, separators=(',', ':')))
    return path


def find_solo(char_dir_name: str) -> Path | None:
    d = ASSETS / 'characters' / 'hires' / char_dir_name / '05_solo_sheet'
    if not d.is_dir():
        return None
    sheets = list(d.glob('*.png'))
    return sheets[0] if sheets else None


def pick_bg(*globs: str) -> Path | None:
    bg = ASSETS / 'backgrounds'
    for g in globs:
        hits = sorted(bg.glob(g))
        if hits:
            return hits[0]
    return None


def key_magenta(im, tol: int = 48):
    """Convert near-magenta chroma key to transparent RGBA (fast)."""
    from PIL import Image, ImageOps
    im = im.convert('RGBA')
    datas = list(im.getdata())
    out = []
    for r, g, b, a in datas:
        if r >= 255 - tol and b >= 150 - tol and g <= tol + 10:
            out.append((r, g, b, 0))
        else:
            out.append((r, g, b, a))
    im.putdata(out)
    return im



def _is_magentaish(r, g, b, a=255):
    """True for chroma-key leftovers (magenta / hot-pink), not skin or orange straps."""
    if a < 8:
        return True
    # Classic key magenta
    if r >= 200 and b >= 140 and g <= 90:
        return True
    if r > 150 and b > 80 and g < 80:
        return True
    # HSV hue near magenta (approx 280–330°) with enough saturation
    mx = max(r, g, b); mn = min(r, g, b)
    if mx < 40:
        return False
    sat = (mx - mn) / mx
    if sat < 0.35:
        return False
    # hue in degrees
    if mx == mn:
        return False
    if mx == r:
        h = 60 * (((g - b) / (mx - mn)) % 6)
    elif mx == g:
        h = 60 * (((b - r) / (mx - mn)) + 2)
    else:
        h = 60 * (((r - g) / (mx - mn)) + 4)
    if h < 0:
        h += 360
    # magenta / hot pink band; exclude red-orange skin (< 20°) and blue
    if 270 <= h <= 350 and sat > 0.35 and mx > 80:
        return True
    if 290 <= h <= 345 and sat > 0.25 and mx > 60:
        return True
    return False


def defringe_rgba(im, edge_px: int = 2):
    """Remove magenta fringe after chroma key.

    Any remaining magenta-ish pixel, especially within `edge_px` of an alpha edge,
    is either made transparent or recoloured to the nearest non-fringe opaque neighbour
    (preferring a dark outline if none found nearby). Run on full-res BEFORE downscale
    and again AFTER downscale.
    """
    import numpy as np
    from PIL import Image
    im = im.convert('RGBA')
    arr = np.array(im, dtype=np.uint8)
    H, W = arr.shape[:2]
    rgb = arr[:, :, :3].astype(np.int16)
    a = arr[:, :, 3]
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    # Vectorized magenta / hot-pink (approx HSV 280–340), exclude peach/orange
    mx = np.maximum(np.maximum(r, g), b).astype(np.float32)
    mn = np.minimum(np.minimum(r, g), b).astype(np.float32)
    rng = np.maximum(mx - mn, 1e-6)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0)
    # hue degrees
    hue = np.zeros_like(mx)
    rm = (mx == r); gm = (mx == g) & ~rm; bm = ~rm & ~gm
    hue[rm] = 60 * (((g[rm] - b[rm]) / rng[rm]) % 6)
    hue[gm] = 60 * (((b[gm] - r[gm]) / rng[gm]) + 2)
    hue[bm] = 60 * (((r[bm] - g[bm]) / rng[bm]) + 4)
    hue = np.mod(hue, 360)
    mag = (
        ((r >= 200) & (b >= 140) & (g <= 90))
        | ((r > 150) & (b > 80) & (g < 80))
        # Classic chroma leftovers: high R+B, mid G (e.g. 181,95,187)
        | ((r > 160) & (b > 160) & (g < 110) & ((r - g) > 50) & ((b - g) > 50))
        | ((hue >= 270) & (hue <= 350) & (sat > 0.35) & (mx > 80))
        | ((hue >= 290) & (hue <= 345) & (sat > 0.25) & (mx > 60))
    ) & (a > 0)

    if not mag.any():
        return im

    # Alpha edge: opaque pixel with a transparent neighbour in 3x3
    opaque = a > 32
    from numpy.lib.stride_tricks import sliding_window_view
    # pad for edge detect
    pad = np.pad(opaque.astype(np.uint8), 1, mode='constant', constant_values=0)
    wins = sliding_window_view(pad, (3, 3))
    near_clear = opaque & (wins.min(axis=(-1, -2)) == 0)

    # Dilate near_clear by edge_px
    edge_zone = near_clear.copy()
    for _ in range(max(0, edge_px - 1)):
        p2 = np.pad(edge_zone.astype(np.uint8), 1, mode='constant')
        w2 = sliding_window_view(p2, (3, 3))
        edge_zone = w2.max(axis=(-1, -2)).astype(bool)

    # Kill ALL magenta-ish pixels (edge-preferred for recolour; interior key leftovers too).
    kill = mag.copy()

    # Recolour vs transparent: prefer nearest non-fringe opaque neighbour;
    # else transparent. Edge zone prefers dark outline.
    out = arr.copy()
    ys, xs = np.where(kill)
    # Two-pass: first mark kill; then fill from already-cleaned neighbours using original as source
    src = arr.copy()
    for y, x in zip(ys.tolist(), xs.tolist()):
        samples = []
        for rad in (1, 2, 3, 4):
            for dy in range(-rad, rad + 1):
                for dx in range(-rad, rad + 1):
                    if abs(dx) != rad and abs(dy) != rad:
                        continue
                    ny, nx = y + dy, x + dx
                    if ny < 0 or nx < 0 or ny >= H or nx >= W:
                        continue
                    rr, gg, bb, aa = int(src[ny, nx, 0]), int(src[ny, nx, 1]), int(src[ny, nx, 2]), int(src[ny, nx, 3])
                    if aa < 32:
                        continue
                    if _is_magentaish(rr, gg, bb, aa):
                        continue
                    samples.append((rr, gg, bb, dx * dx + dy * dy))
            if samples:
                break
        if samples:
            # nearest first; among them prefer darker (outline)
            samples.sort(key=lambda c: (c[3], 0.3 * c[0] + 0.6 * c[1] + 0.1 * c[2]))
            out[y, x, 0] = samples[0][0]
            out[y, x, 1] = samples[0][1]
            out[y, x, 2] = samples[0][2]
            # On true alpha edge, darken slightly into an outline
            if edge_zone[y, x]:
                out[y, x, 0] = max(0, samples[0][0] * 2 // 3)
                out[y, x, 1] = max(0, samples[0][1] * 2 // 3)
                out[y, x, 2] = max(0, samples[0][2] * 2 // 3)
            out[y, x, 3] = 255
        else:
            out[y, x, 3] = 0
    return Image.fromarray(out, 'RGBA')


def crop_content(im, pad: int = 2):
    """Crop to non-transparent bbox."""
    from PIL import Image
    if im.mode != 'RGBA':
        im = im.convert('RGBA')
    bbox = im.split()[-1].getbbox()
    if not bbox:
        return im
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad); y1 = min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


def load_char(char_dir_name: str, prefer: str = 'front', max_h: int = 140, name: str | None = None) -> dict | None:
    """Load FRONT/SE character only (never full solo SE|NW sheet)."""
    from PIL import Image
    base = ASSETS / 'characters' / 'hires' / char_dir_name
    path = None
    d = base / '03_front_se'
    if d.is_dir():
        sheets = list(d.glob('*.png'))
        if sheets:
            path = sheets[0]
    if path is None and prefer != 'front':
        path = find_solo(char_dir_name)
    if path is None:
        return None
    im = Image.open(path)
    im = key_magenta(im, tol=32)
    if 'solo' in path.name.lower() or '05_solo' in str(path):
        im = im.crop((0, 0, im.width // 2, im.height))
    im = crop_content(im)
    if im.height > max_h:
        nw = max(1, int(im.width * (max_h / im.height)))
        im = im.resize((nw, max_h), Image.Resampling.NEAREST)
    buf = io.BytesIO()
    im.save(buf, format='PNG')
    b64 = base64.b64encode(buf.getvalue()).decode('ascii')
    return {
        'id': uid(),
        'name': name or char_dir_name,
        'src': f'data:image/png;base64,{b64}',
        'gif': None,
        '_w': im.width,
        '_h': im.height,
    }


def load_sound(path: Path | str, name: str | None = None) -> dict:
    path = Path(path)
    raw = path.read_bytes()
    suf = path.suffix.lower()
    mime = 'audio/wav' if suf == '.wav' else ('audio/mpeg' if suf in ('.mp3', '.mpeg') else 'application/octet-stream')
    b64 = base64.b64encode(raw).decode('ascii')
    return {'id': uid(), 'name': name or path.name, 'src': f'data:{mime};base64,{b64}'}


def pick_sound(*names: str) -> Path | None:
    audio = ASSETS / 'audio'
    for n in names:
        p = audio / n
        if p.is_file():
            return p
        hits = list(audio.glob(n))
        if hits:
            return hits[0]
    return None


def text_layer(text: str, **over) -> dict:
    defaults = dict(
        kind='text', name='Text', text=text, fontSize=10, textColor='#e8f4ff',
        outline=1, outlineColor='#05060e', align='center', anchor='center',
        parallax=0, x=0, y=-40, scale=1, opacity=1, wrap=True, wrapW=280,
        reveal=0.6, revealDelay=0.15,
    )
    defaults.update(over)
    return new_layer(**defaults)


def solid_layer(color: str = '#05060e', **over) -> dict:
    defaults = dict(kind='solid', name='Solid', color=color, anchor='center',
                    parallax=0, x=0, y=0, scale=1, opacity=1)
    defaults.update(over)
    # solid uses box via scale? Builder solids fill via color + size from scale?
    # Looking at render: solids use color with frame sized by... actually solids draw a rect.
    # Keep simple — full frame overlay with opacity.
    return new_layer(**defaults)


def img_layer(asset: dict, **over) -> dict:
    defaults = dict(
        kind='image', name=asset.get('name', 'Image'), assetId=asset['id'],
        anchor='bottom', parallax=1, x=0, y=0, scale=1, opacity=1,
    )
    defaults.update(over)
    return new_layer(**defaults)


def parallax_stack(asset_list: list[dict], parallax_vals: list[float] | None = None, y_vals: list[float] | None = None) -> list[dict]:
    """Build front-first layer list from back→front asset list (sky last in input = back).
    asset_list should be [fg, ..., sky] matching front-first order, OR we reverse.
    Convention here: pass [sky, far, mid, near, fg] back-to-front; we reverse to front-first.
    """
    n = len(asset_list)
    if parallax_vals is None:
        # front 1.6 → sky 0.05
        if n == 1:
            parallax_vals = [0.3]
        else:
            parallax_vals = [0.05 + (1.55 * i / (n - 1)) for i in range(n)]
            parallax_vals = list(reversed(parallax_vals))  # will reverse assets too
    # Input is back-to-front (sky first); convert to front-first
    ordered = list(reversed(list(zip(asset_list, parallax_vals if len(parallax_vals) == n else [0.5]*n))))
    layers = []
    for i, (a, px) in enumerate(ordered):
        y = 0
        if y_vals and len(y_vals) == n:
            y = list(reversed(y_vals))[i]
        # Scale so ~320 wide art fills frame
        sc = 1.0
        if a.get('_w') and a['_w'] > 0:
            sc = max(0.35, min(1.4, 320 / a['_w']))
        layers.append(img_layer(a, name=a['name'], parallax=px, y=y, scale=sc, anchor='center', x=0))
    return layers


def cue(t: float, sound: dict, vol: float = 0.7) -> dict:
    return {'t': t, 'auId': sound['id'], 'vol': vol}


def load_sound_compact(path: Path | str, name: str | None = None, max_sec: float = 4.0) -> dict:
    """Embed audio as compact mono 22kHz wav (ffmpeg) to keep projects small."""
    import subprocess, tempfile
    path = Path(path)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        out = Path(tmp.name)
    try:
        subprocess.run([
            'ffmpeg', '-y', '-i', str(path),
            '-ac', '1', '-ar', '22050', '-sample_fmt', 's16',
            '-t', str(max_sec), str(out)
        ], check=True, capture_output=True)
        raw = out.read_bytes()
    except Exception:
        raw = path.read_bytes()
    finally:
        try: out.unlink()
        except Exception: pass
    b64 = base64.b64encode(raw).decode('ascii')
    return {'id': uid(), 'name': name or path.name, 'src': f'data:audio/wav;base64,{b64}'}


def pick_dialog() -> Path | None:
    d = ASSETS / 'audio' / 'dialog_lines'
    if not d.is_dir():
        return None
    files = sorted(d.glob('Say_the_following_di_*.wav'), key=lambda p: p.stat().st_size)
    return files[0] if files else None


def dialog_pool(n: int = 8) -> list[Path]:
    d = ASSETS / 'audio' / 'dialog_lines'
    if not d.is_dir():
        return []
    files = sorted(d.glob('Say_the_following_di_*.wav'), key=lambda p: p.stat().st_size)
    # unique-ish by size buckets then take first n mid-short
    return files[:n]


def fx_pool(pattern: str = '*', n: int = 4) -> list[Path]:
    d = ASSETS / 'audio' / 'newest_fx'
    base = ASSETS / 'audio'
    hits = []
    if d.is_dir():
        hits = sorted(d.glob(pattern), key=lambda p: p.stat().st_size)
    if not hits:
        hits = sorted(base.glob(pattern), key=lambda p: p.stat().st_size)
    return hits[:n]


# ═══════════════════════════════════════════════════════════════
# v2 authoring — depth-correct stacks, camera recipes, timing
# Keep v1 helpers above; callers default to v2.
# See ../DIRECTION.md
# ═══════════════════════════════════════════════════════════════

DEPTH_PARALLAX = {
    'sky': 0.08,
    'far': 0.32,
    'mid': 0.58,
    'near': 0.82,
    'char': 1.0,
    'fg': 1.38,
}

CAM_MOVES = {
    'hold': dict(panX=0, panY=0, zoom0=1.0, zoom1=1.0, ease='out'),
    'truck_right': dict(panX=56, panY=-3, zoom0=1.02, zoom1=1.02, ease='inout'),
    'truck_left': dict(panX=-56, panY=2, zoom0=1.02, zoom1=1.02, ease='inout'),
    'push_in': dict(panX=10, panY=0, zoom0=1.0, zoom1=1.12, ease='out'),
    'push_creep': dict(panX=4, panY=-1, zoom0=1.05, zoom1=1.14, ease='in'),
    'pull_back': dict(panX=18, panY=4, zoom0=1.22, zoom1=1.0, ease='inout'),
    'crane_down': dict(panX=32, panY=20, zoom0=1.14, zoom1=1.0, ease='inout'),
    'crane_up': dict(panX=-24, panY=-18, zoom0=1.0, zoom1=1.08, ease='inout'),
    'tilt_up': dict(panX=6, panY=-22, zoom0=1.04, zoom1=1.04, ease='inout'),
    'tilt_down': dict(panX=8, panY=22, zoom0=1.06, zoom1=1.0, ease='inout'),
    'impact': dict(panX=0, panY=0, zoom0=1.18, zoom1=1.05, ease='out', shake=5, shakeFreq=32, shakeDecay=True),
    'whip_settle': dict(panX=-40, panY=0, zoom0=1.08, zoom1=1.0, ease='out'),
}


def cam_move(name: str, **over) -> dict:
    base = CAM_MOVES.get(name, CAM_MOVES['hold']).copy()
    base.update(over)
    return new_cam(**base)


def dialog_dur(text: str, cps: float = 20.0, reveal: float = 26.0, vo_sec: float | None = None, beat: float = 0.7) -> float:
    """Shot duration for a dialogue line: typewriter + reading hold + beat; VO wins if longer."""
    n = max(1, len(text))
    type_t = n / max(1.0, reveal) + 0.35
    read_t = n / max(1.0, cps) + beat
    hold = max(type_t, read_t, 2.2)
    if vo_sec:
        hold = max(hold, vo_sec + 0.4)
    return round(hold, 2)


def alpha_coverage(path: Path, opaque_thresh: int = 200) -> tuple[float, float]:
    """Return (opaque_frac, transparent_frac) for an image path."""
    from PIL import Image
    im = Image.open(path).convert('RGBA')
    a = im.split()[-1]
    hist = a.histogram()
    total = im.width * im.height
    opaque = sum(hist[opaque_thresh:]) / total
    transp = sum(hist[:32]) / total
    return opaque, transp


def is_opaque_fullframe(path: Path | str, opaque_min: float = 0.90) -> bool:
    path = Path(path)
    if not path.is_file():
        return False
    try:
        op, _ = alpha_coverage(path)
        return op >= opaque_min
    except Exception:
        return True


def slice_bands(path: Path | str, bands: list[tuple[float, float]] | None = None, max_w: int = 480) -> list[dict]:
    """Slice an opaque plate into horizontal bands on a transparent canvas (sky→ground).
    Returns assets back-to-front (sky first). Each band keeps full canvas size for easy stacking.
    """
    from PIL import Image
    path = Path(path)
    if bands is None:
        bands = [(0.0, 0.38), (0.32, 0.68), (0.60, 1.0)]  # slight overlap
    im = Image.open(path).convert('RGBA')
    if max_w and im.width > max_w:
        nh = max(1, int(im.height * (max_w / im.width)))
        im = im.resize((max_w, nh), Image.Resampling.NEAREST)
    w, h = im.size
    out = []
    labels = ['sky_band', 'horizon_band', 'ground_band', 'band']
    for i, (y0f, y1f) in enumerate(bands):
        y0, y1 = int(h * y0f), int(h * y1f)
        canvas = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        band = im.crop((0, y0, w, y1))
        canvas.paste(band, (0, y0))
        buf = io.BytesIO()
        canvas.save(buf, format='PNG', optimize=True)
        b64 = base64.b64encode(buf.getvalue()).decode('ascii')
        lab = labels[i] if i < len(labels) else f'band{i}'
        out.append({
            'id': uid(), 'name': f'{path.stem[:18]}_{lab}', 'src': f'data:image/png;base64,{b64}',
            'gif': None, '_w': w, '_h': h, '_band': (y0f, y1f), '_opaque_full': False,
        })
    return out


def load_asset_keyed(path: Path | str, name: str | None = None, max_w: int | None = 480,
                     darken: float | None = None, opacity_mul: float = 1.0) -> dict:
    """Load PNG/JPG; optional darken for FG silhouettes. Magenta key if near-key detected."""
    from PIL import Image, ImageEnhance
    path = Path(path)
    im = Image.open(path).convert('RGBA')
    # light magenta key for character-like sheets
    if path.suffix.lower() == '.png':
        # cheap sample: if corner is near magenta, key whole image
        corners = [im.getpixel((1, 1)), im.getpixel((im.width - 2, 1))]
        if any(r > 200 and g < 60 and b > 140 for r, g, b, a in corners):
            im = key_magenta(im, tol=48)
    if darken is not None and darken < 1.0:
        rgb = im.convert('RGB')
        rgb = ImageEnhance.Brightness(rgb).enhance(darken)
        im = Image.merge('RGBA', (*rgb.split(), im.split()[-1]))
    if max_w and im.width > max_w:
        nh = max(1, int(im.height * (max_w / im.width)))
        im = im.resize((max_w, nh), Image.Resampling.NEAREST)
    buf = io.BytesIO()
    im.save(buf, format='PNG', optimize=True)
    b64 = base64.b64encode(buf.getvalue()).decode('ascii')
    return {'id': uid(), 'name': name or path.stem[:28], 'src': f'data:image/png;base64,{b64}',
            'gif': None, '_w': im.width, '_h': im.height, '_opacity_mul': opacity_mul}


def scale_to_frame(asset: dict, fill: float = 1.05) -> float:
    w = asset.get('_w') or 320
    return max(0.25, min(2.2, (320 * fill) / max(1, w)))


def depth_stack_v2(
    backdrop: dict,
    *,
    far: list[dict] | None = None,
    mid: list[dict] | None = None,
    near: list[dict] | None = None,
    fg: list[dict] | None = None,
    legacy: bool = False,
) -> list[dict]:
    """Build a FRONT-FIRST layer list with backdrop at the BACK.

    backdrop: the only full-frame opaque (or sky). Placed last.
    far/mid/near/fg: cutouts, transparent plates, or band-slices (tagged _band).
    Band-slices share backdrop scale + center anchor so they recompose.
    Opaque full-frame assets passed into far/mid/near are rejected (logged via name prefix skip:).
    """
    if legacy:
        plates = [backdrop] + list(far or []) + list(mid or []) + list(near or []) + list(fg or [])
        return parallax_stack(plates)

    back_to_front: list[dict] = []
    sc_bd = scale_to_frame(backdrop, fill=1.28)  # oversize for pan/parallax coverage

    def is_band(a: dict) -> bool:
        return bool(a.get('_band'))

    def reject_opaque(a: dict, role: str) -> bool:
        """True if asset looks like a full opaque plate and is NOT a band slice."""
        if is_band(a):
            return False
        # Heuristic: if previous load marked it, or name suggests plate without alpha
        if a.get('_opaque_full'):
            return True
        return False

    back_to_front.append(img_layer(
        backdrop, name=f"sky:{backdrop.get('name','bg')}"[:32],
        parallax=DEPTH_PARALLAX['sky'], scale=sc_bd, anchor='center',
        bright=0.92, sat=0.9, x=0, y=0,
    ))

    for a in (far or []):
        if reject_opaque(a, 'far'):
            continue
        sc = sc_bd if (is_band(a) or a.get('_fullplane')) else scale_to_frame(a, 1.05)
        back_to_front.append(img_layer(
            a, name=f"far:{a.get('name','')}"[:32],
            parallax=DEPTH_PARALLAX['far'], scale=sc,
            anchor='center', x=a.get('_x', 0), y=a.get('_y', 0),
            bright=0.82, sat=0.85, tint='#6ec8ff', tintAmt=0.08,
            opacity=a.get('_opacity_mul', 0.95 if is_band(a) else 1.0),
        ))

    def is_fullplane(a: dict) -> bool:
        """Wide scene plates must cover the frame — not shrink like skyline cutouts."""
        if a.get('_fullplane') or a.get('_band'):
            return True
        # Heuristic: loaded near stage width and named like a scene layer
        w = a.get('_w') or 0
        n = str(a.get('name', '')).lower()
        if w >= 300 and any(k in n for k in ('scene_', 'ground', 'midground', 'farbackground', 'layer_')):
            return True
        return False

    for i, a in enumerate(mid or []):
        if reject_opaque(a, 'mid'):
            continue
        if is_band(a) or is_fullplane(a):
            sc, anc, x, y = sc_bd, 'center', a.get('_x', 0), a.get('_y', 0)
        else:
            # structure cutouts — modest, grounded on bottom
            sc = min(0.7, scale_to_frame(a, 0.55))
            anc, x, y = 'bottom', a.get('_x', (-60 if i % 2 == 0 else 70)), a.get('_y', 4)
        back_to_front.append(img_layer(
            a, name=f"mid:{a.get('name','')}"[:32],
            parallax=DEPTH_PARALLAX['mid'] + 0.03 * i,
            scale=sc, anchor=anc, x=x, y=y,
            bright=0.9, opacity=a.get('_opacity_mul', 1.0),
        ))

    for i, a in enumerate(near or []):
        if reject_opaque(a, 'near'):
            continue
        if is_fullplane(a):
            sc = sc_bd
            anc, x, y = 'center', a.get('_x', 0), a.get('_y', 0)
        else:
            sc = min(0.75, scale_to_frame(a, 0.6))
            anc, x, y = 'bottom', a.get('_x', (-40 if i == 0 else 50)), a.get('_y', 4)
        back_to_front.append(img_layer(
            a, name=f"near:{a.get('name','')}"[:32],
            parallax=DEPTH_PARALLAX['near'],
            scale=sc, anchor=anc, y=y, x=x,
            opacity=a.get('_opacity_mul', 0.95),
        ))

    for i, a in enumerate(fg or []):
        # FG framing — prefer side-weighted, not full wash
        sc = sc_bd * 1.05 if is_band(a) else scale_to_frame(a, 1.1)
        back_to_front.append(img_layer(
            a, name=f"fg:{a.get('name','')}"[:32],
            parallax=DEPTH_PARALLAX['fg'] + 0.05 * i,
            scale=sc, anchor='center', x=a.get('_x', 0), y=0,
            bright=0.4, sat=0.65, blur=1.0,
            opacity=min(0.55, a.get('_opacity_mul', 0.5)),
        ))

    return list(reversed(back_to_front))



def insert_characters(layers: list[dict], chars: list[tuple[dict, dict]], plane_parallax: float = 1.0,
                      *, behind_fg: bool = True) -> list[dict]:
    """Insert character layers into a front-first list.

    behind_fg=True (default): place characters *behind* fg:* framing (FG stays in front).
    behind_fg=False: place characters in front of everything (hero close-ups).
    """
    char_layers = []
    for asset, over in chars:
        defaults = dict(
            name=asset.get('name', 'Char'), parallax=plane_parallax,
            scale=1.0, anchor='bottom', y=6, x=0, opacity=1.0,
        )
        defaults.update(over)
        char_layers.append(img_layer(asset, **defaults))
    if not behind_fg:
        return char_layers + layers
    # Skip leading non-world overlays (text/distort already added by caller usually),
    # then skip fg:* block so chars sit just behind framing.
    i = 0
    while i < len(layers) and layers[i].get('kind') in ('text', 'panel', 'distort'):
        i += 1
    j = i
    while j < len(layers) and str(layers[j].get('name', '')).startswith('fg:'):
        j += 1
    return layers[:j] + char_layers + layers[j:]


def fog_layer(color: str = '#8ab4c8', opacity: float = 0.12, parallax: float = 0.7,
              speedX: float = -3, blend: str = 'screen', name: str = 'Fog') -> dict:
    return new_layer(
        kind='solid', name=name, color=color, opacity=opacity, parallax=parallax,
        speedX=speedX, blend=blend, anchor='center', x=0, y=-20, scale=1.0,
    )


def ensure_move_variety(moves: list[str]) -> list[str]:
    """Guarantee no two consecutive identical move names."""
    if not moves:
        return moves
    out = [moves[0]]
    alts = ['truck_left', 'truck_right', 'push_in', 'pull_back', 'crane_down', 'tilt_up', 'hold']
    for m in moves[1:]:
        if m == out[-1]:
            m = next((a for a in alts if a != out[-1]), 'hold')
        out.append(m)
    return out


def pick_erased_fg() -> Path | None:
    bg = ASSETS / 'backgrounds'
    for name in ('bg_5._erasedPNG.PNG', 'bg_8erased.PNG', 'bg_6_erased.PNG', 'mid_for_crt.PNG'):
        p = bg / name
        if p.is_file():
            return p
    return None


def pick_structure(*names: str) -> Path | None:
    d = ASSETS / 'props' / 'structures'
    if not d.is_dir():
        return None
    for n in names:
        p = d / n
        if p.is_file():
            return p
        hits = list(d.glob(n))
        if hits:
            return hits[0]
    # any
    allp = sorted(d.glob('*.png'))
    return allp[0] if allp else None


CAST_VIEWS_PATH = Path(__file__).resolve().parent / 'cast_views.json'
_CAST_VIEWS_CACHE: dict | None = None
_CAST_CELL_LOG: list[dict] = []


def load_cast_views() -> dict:
    """Load tools/cast_views.json (front / three-quarter cells only)."""
    global _CAST_VIEWS_CACHE
    if _CAST_VIEWS_CACHE is not None:
        return _CAST_VIEWS_CACHE
    if CAST_VIEWS_PATH.is_file():
        _CAST_VIEWS_CACHE = json.loads(CAST_VIEWS_PATH.read_text())
    else:
        _CAST_VIEWS_CACHE = {}
    return _CAST_VIEWS_CACHE


def cast_cell_log() -> list[dict]:
    """Cells chosen this process — for QA / generate logs."""
    return list(_CAST_CELL_LOG)


def _resolve_front_sheet(char_dir_name: str) -> Path | None:
    """Prefer 03_front_se. Solo sheets pack SE|NW on opaque black + header — never use whole solo."""
    base = ASSETS / 'characters' / 'hires' / char_dir_name
    views = load_cast_views().get(char_dir_name) or {}
    if views.get('sheet'):
        p = ROOT / views['sheet'] if not Path(views['sheet']).is_absolute() else Path(views['sheet'])
        # sheet paths in json are relative to cutscene root (assets/...)
        if not p.is_file():
            p = (Path(__file__).resolve().parent.parent / views['sheet'])
        if p.is_file():
            return p
    d = base / '03_front_se'
    if d.is_dir():
        sheets = list(d.glob('*.png'))
        if sheets:
            return sheets[0]
    # Fallback: left (SE) half of solo, strip near-black matte
    solo = find_solo(char_dir_name)
    return solo


def _extract_se_cell(im, from_solo: bool = False):
    """Return a single front/SE sprite. Solo sheets: left half only; key black matte."""
    from PIL import Image
    im = im.convert('RGBA')
    im = key_magenta(im, tol=28)  # tight — avoid eating white/cyan armor
    im = defringe_rgba(im)
    if from_solo:
        # SE left / NW right — keep left half only
        im = im.crop((0, 0, im.width // 2, im.height))
        # Key near-black matte (solo sheets are not magenta-keyed)
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if a < 8:
                    continue
                if r < 18 and g < 18 and b < 18:
                    px[x, y] = (0, 0, 0, 0)
                # strip yellow header text
                elif r > 180 and g > 140 and b < 90 and y < 40:
                    px[x, y] = (0, 0, 0, 0)
    return crop_content(im)


def load_char_mcu(char_dir_name: str, max_h: int = 150, scale_int: int = 2, name: str | None = None,
                  bust: bool = False) -> dict | None:
    """Load FRONT / three-quarter cell only (cast_views.json). Never back-view solo NW."""
    from PIL import Image
    path = _resolve_front_sheet(char_dir_name)
    if path is None:
        return load_char(char_dir_name, prefer='front', max_h=max_h, name=name)
    from_solo = '05_solo_sheet' in str(path) or 'SOLO' in path.name.upper()
    im = _extract_se_cell(Image.open(path), from_solo=from_solo)
    view_meta = load_cast_views().get(char_dir_name, {})
    cell_desc = view_meta.get('cell', 'front_se_cropped')
    view_name = view_meta.get('view', 'front_se_three_quarter')
    if scale_int and scale_int > 1:
        im = im.resize((im.width * scale_int, im.height * scale_int), Image.Resampling.NEAREST)
    if bust and im.height > max_h:
        im = im.crop((0, 0, im.width, min(im.height, int(max_h * 1.15))))
    if im.height > max_h:
        nw = max(1, int(im.width * (max_h / im.height)))
        im = im.resize((nw, max_h), Image.Resampling.NEAREST)
        im = defringe_rgba(im, edge_px=2)  # second pass after downscale
    else:
        im = defringe_rgba(im, edge_px=2)
    buf = io.BytesIO()
    im.save(buf, format='PNG')
    b64 = base64.b64encode(buf.getvalue()).decode('ascii')
    entry = {
        'id': uid(), 'name': name or char_dir_name, 'src': f'data:image/png;base64,{b64}',
        'gif': None, '_w': im.width, '_h': im.height,
        '_cast_view': view_name, '_cast_cell': cell_desc, '_cast_sheet': path.name,
    }
    _CAST_CELL_LOG.append({
        'char': char_dir_name, 'name': entry['name'], 'sheet': path.name,
        'view': view_name, 'cell': cell_desc, 'size': [im.width, im.height],
        'from_solo_fallback': from_solo,
    })
    print(f'  cast: {entry["name"]} ← {path.name} [{view_name}/{cell_desc}] {im.width}x{im.height}')
    return entry


def title_layers(place: str, region: str, y_place: int = 28, y_region: int = 48) -> list[dict]:
    """Cinematic title card text — large, lower-third friendly."""
    return [
        text_layer(place, name='Place', fontSize=20, y=y_place, textColor='#f4fbff',
                   reveal=8, revealDelay=0.35, outline=2, outlineColor='#05060e',
                   align='center', wrap=True, wrapW=300),
        text_layer(region, name='Region', fontSize=11, y=y_region, textColor='#8ad4ff',
                   reveal=6, revealDelay=1.1, outline=1, align='center'),
    ]



# ── Dialogue scene recipe (shot / reverse-shot) ─────────────────
STAGE_W, STAGE_H = 320, 180


def x_from_center(center_x: float, asset: dict | None, scale: float = 1.0) -> int:
    """Builder `x` is the sprite's LEFT edge. Convert a desired center-x to that."""
    w = 40
    if asset:
        w = int(asset.get('_w') or asset.get('w') or w)
    return int(round(center_x - (w * scale) / 2.0))


def dialogue_chrome(speaker: str, line: str, *, reveal: float = 24.0,
                    reveal_delay: float = 0.25, scrim_asset: dict | None = None) -> list[dict]:
    """Bottom-anchored speaker + line above letterbox, optional scrim behind text.

    Exact values that read on 320×180 with fx.bars≈0.14:
      scrim: anchor bottom, y=0, opacity 0.9
      speaker: anchor bottom, x=18, y=-50, fontSize 9
      line:    anchor bottom, x=18, y=-32, fontSize 11, reveal 22–26
    """
    layers = []
    # front-first: text above scrim
    layers.append(text_layer(
        speaker.upper(), name='Speaker', fontSize=9, textColor='#3ee0d8',
        outline=2, outlineColor='#05060e', align='left', anchor='bottom',
        x=28, y=-58, reveal=0, wrap=False, parallax=0,
    ))
    layers.append(text_layer(
        line, name='Line', fontSize=11, textColor='#e8f4ff',
        outline=2, outlineColor='#05060e', align='left', anchor='bottom',
        x=28, y=-40, reveal=reveal, revealDelay=reveal_delay,
        wrap=True, wrapW=280, parallax=0,
    ))
    if scrim_asset is not None:
        layers.append(img_layer(
            scrim_asset, name='dlg_scrim', anchor='bottom', y=0, x=0,
            scale=1, opacity=0.9, parallax=0,
        ))
    return layers


def ots_characters(
    focus: dict, other: dict, *, focus_name: str, other_name: str,
    side: str = 'left', focus_scale: float = 1.2, other_scale: float = 1.75,
    feet_y: int = -28, other_bright: float = 0.45, other_blur: float = 1.1,
) -> list[tuple[dict, dict]]:
    """Over-the-shoulder pair. `side` = focus character screen side.

    Focus: MCU on left or right third, fully lit, opacity 1.
    Other: large darkened blurred FG shoulder at opposite edge, opacity 1, partly cropped.
    Facing: left focus looks right (flipH False if art faces right); right focus flipH True.
    """
    if side == 'left':
        focus_cx, other_cx = 105, 275
        focus_flip, other_flip = False, True
    else:
        focus_cx, other_cx = 215, 45
        focus_flip, other_flip = True, False
    focus_over = dict(
        name=focus_name, x=x_from_center(focus_cx, focus, focus_scale), y=feet_y,
        scale=focus_scale, parallax=1.05, anchor='bottom', flipH=focus_flip,
        opacity=1.0, bright=1.0, blur=0,
    )
    other_over = dict(
        name=other_name, x=x_from_center(other_cx, other, other_scale), y=feet_y + 6,
        scale=other_scale, parallax=1.15, anchor='bottom', flipH=other_flip,
        opacity=1.0, bright=other_bright, blur=other_blur, sat=0.7,
    )
    # FG other first (front), then focus
    return [(other, other_over), (focus, focus_over)]


def two_shot_characters(
    left: dict, right: dict, *, left_name: str, right_name: str,
    scale: float = 0.92, feet_y: int = -30, left_cx: float = 95, right_cx: float = 225,
) -> list[tuple[dict, dict]]:
    """Wide two-shot: left faces right, right faces left (flipH)."""
    return [
        (left, dict(
            name=left_name, x=x_from_center(left_cx, left, scale), y=feet_y,
            scale=scale, parallax=1.05, anchor='bottom', flipH=False, opacity=1.0,
        )),
        (right, dict(
            name=right_name, x=x_from_center(right_cx, right, scale), y=feet_y,
            scale=scale, parallax=1.05, anchor='bottom', flipH=True, opacity=1.0,
        )),
    ]




# ── Visual-novel bust dialogue (reusable) ───────────────────────



def load_bust(path: Path | str, name: str | None = None,
              max_h: int | None = None, nn_scale: float | None = 0.375) -> dict:
    """Load a 256 bust for VN portraits.

    Full-res chroma key + defringe, crop content, then a clean nearest-neighbour
    scale (default 0.375 → ~92–104px content after crop; speaker ×1.12 ≈ 55–60% of stage).
    Pass max_h to force a pixel height instead of nn_scale.
    """
    from PIL import Image
    import io, base64
    import numpy as np
    path = Path(path)
    im = Image.open(path).convert('RGBA')
    im = Image.frombytes('RGBA', im.size, im.tobytes())
    im = key_magenta(im, tol=48)
    im = defringe_rgba(im, edge_px=4)
    im = Image.frombytes('RGBA', im.size, im.tobytes())
    # Kill near-black matte leftovers
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            if r < 12 and g < 12 and b < 12:
                px[x, y] = (0, 0, 0, 0)
    if 'crop_content' in globals():
        im = crop_content(im)
    elif 'crop_content' in globals():
        im = crop_content(im)
    # Clean NN downscale
    if max_h is not None and im.height > max_h:
        nw = max(1, int(round(im.width * (max_h / im.height))))
        im = im.resize((nw, max_h), Image.Resampling.NEAREST)
    elif nn_scale is not None and nn_scale < 1.0:
        nw = max(1, int(round(im.width * nn_scale)))
        nh = max(1, int(round(im.height * nn_scale)))
        im = im.resize((nw, nh), Image.Resampling.NEAREST)
    im = defringe_rgba(im, edge_px=3)
    # Final scrub: hot-pink / magenta leftovers (incl. hair-outline 180,20,100) → transparent
    arr = np.array(im)
    r, g, b, a = arr[:,:,0].astype(int), arr[:,:,1].astype(int), arr[:,:,2].astype(int), arr[:,:,3]
    fringe = (
        ((r > 140) & (b > 80) & (g < 120) & ((r - g) > 40) & (a > 0))
        | ((r > 160) & (b > 160) & (g < 110) & ((r - g) > 50) & ((b - g) > 50) & (a > 0))
        | ((r > 150) & (b > 100) & (g < 80) & (a > 0))
    )
    if fringe.any():
        # Kill ALL remaining hot-pink / magenta (edge or interior leftovers from key)
        arr = arr.copy()
        arr[:,:,3] = np.where(fringe, 0, arr[:,:,3])
        # Also zero RGB so resampling never resurrects them
        arr[:,:,0] = np.where(fringe, 0, arr[:,:,0])
        arr[:,:,1] = np.where(fringe, 0, arr[:,:,1])
        arr[:,:,2] = np.where(fringe, 0, arr[:,:,2])
        im = Image.fromarray(arr, 'RGBA')

    buf = io.BytesIO()
    im.save(buf, format='PNG')
    b64 = base64.b64encode(buf.getvalue()).decode('ascii')
    return {
        'id': uid(), 'name': name or path.stem,
        'src': f'data:image/png;base64,{b64}',
        'gif': None, '_w': im.width, '_h': im.height,
        '_src_path': str(path),
    }


def _kf(track) -> list[dict]:
    out = []
    for item in track:
        if len(item) == 2:
            tt, v = item
            e = 'inout'
        else:
            tt, v, e = item
        out.append({'t': float(tt), 'v': v, 'e': e})
    return out


def make_dialogue_panel_asset(w: int = 148, h: int = 46, name: str = 'dlg_panel') -> dict:
    """Semi-opaque dark panel for VN dialogue text (between busts)."""
    from PIL import Image, ImageDraw
    import io, base64
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # filled rounded-ish rect (pixel: chamfer corners)
    d.rectangle([1, 1, w - 2, h - 2], fill=(6, 8, 16, 210))
    d.rectangle([0, 2, w - 1, h - 3], fill=(6, 8, 16, 210))
    d.rectangle([2, 0, w - 3, h - 1], fill=(6, 8, 16, 210))
    # thin top edge highlight
    d.line([(3, 1), (w - 4, 1)], fill=(50, 70, 90, 160))
    buf = io.BytesIO()
    im.save(buf, format='PNG')
    b64 = base64.b64encode(buf.getvalue()).decode('ascii')
    return {
        'id': uid(), 'name': name,
        'src': f'data:image/png;base64,{b64}',
        'gif': None, '_w': w, '_h': h,
    }




def make_nameplate_asset(w: int = 52, h: int = 14, name: str = 'nameplate',
                         accent: tuple[int, int, int] = (95, 227, 255),
                         into: dict | None = None) -> dict:
    """Dark name plate with crisp 1px accent border (character colour).

    If `into` is given, overwrite its src/size in place (keeps the same id so
    already-registered project assets stay valid).
    """
    from PIL import Image, ImageDraw
    import io, base64
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, h - 1], fill=(8, 10, 18, 230))
    ar, ag, ab = accent
    d.rectangle([0, 0, w - 1, h - 1], outline=(ar, ag, ab, 255))
    buf = io.BytesIO()
    im.save(buf, format='PNG')
    b64 = base64.b64encode(buf.getvalue()).decode('ascii')
    src = f'data:image/png;base64,{b64}'
    if into is not None:
        into['src'] = src
        into['name'] = name or into.get('name') or 'nameplate'
        into['_w'] = w
        into['_h'] = h
        into['gif'] = None
        return into
    return {
        'id': uid(), 'name': name,
        'src': src,
        'gif': None, '_w': w, '_h': h,
    }


def measure_mono_wrap(text: str, font_size: int, wrap_w: int) -> list[str]:
    """Approximate monospace wrap matching the builder's layoutLines.

    Builder uses canvas measureText; monospace advance ≈ 0.60×N measured,
    but we use 0.70×font_size so wrap errs early and wrap=True is a safety net.
    """
    import re
    adv = max(1.0, font_size * 0.70)
    limit = max(8, wrap_w)
    out: list[str] = []
    for para in str(text).split('\n'):
        toks = re.split(r'(\s+)', para)
        line, w = '', 0.0
        for tok in toks:
            tw = len(tok) * adv
            if w + tw > limit and line.strip():
                out.append(line.rstrip())
                line = tok.lstrip()
                w = len(line) * adv
            else:
                line += tok
                w += tw
        out.append(line.rstrip())
    return out if out else ['']


def bust_dialogue(
    left_asset: dict,
    right_asset: dict,
    *,
    speaker: str,
    line: str,
    left_name: str = 'Klixx',
    right_name: str = 'P.1.7.Y.',
    dur: float = 3.5,
    speak_side: str = 'left',
    panel_asset: dict | None = None,
    nameplate_asset: dict | None = None,
    appear: float = 0.28,
    settle_scale: float = 1.0,
    speak_scale: float = 1.12,
    listen_scale: float = 1.00,
    listen_bright: float = 1.0,
    listen_opacity: float = 0.88,
    listen_sat: float = 0.88,
    base_scale: float = 1.0,
    stage_w: int = 320,
    bust_y: int = 0,
    left_margin: int = 2,
    right_margin: int = 2,
    fade_out_at: float | None = None,
    panel_w: int = 152,
    panel_h: int = 56,
    font_size: int = 10,
) -> tuple[list[dict], dict]:
    """VN bust pair + bottom dialogue panel for one line.

    Layout (320×180, set fx.bars=0 so letterbox does not crop busts):
      Bust height ≈ asset_h × base_scale × speak/listen (~104×1.12 ≈ 116px speaker ≈ 64% → with 0.375 NN ≈ 55–60%).
      Left bust flush bottom-left; right flush bottom-right (flipH).
      Speaker ×1.12 full bright; listener ×1.00 @ bright=1.0 / sat~0.88 / opacity~0.88 (alpha dim, not RGB crush).
      Dark panel centered between busts; nameplate ATTACHED to panel top (accent border; Klixx cyan / Pity orange);
      line left-aligned + word-wrapped INSIDE panel — every character visible.

    Returns (layers_front_first, panel_asset_used).
    """
    import re
    layers: list[dict] = []
    speaker_label = left_name if speak_side == 'left' else right_name
    left_is_speaker = speak_side == 'left'

    lw = int(left_asset.get('_w') or 74)
    rw = int(right_asset.get('_w') or 74)
    sc_speak = base_scale * speak_scale * settle_scale
    sc_listen = base_scale * listen_scale * settle_scale
    left_sc = sc_speak if left_is_speaker else sc_listen
    right_sc = sc_speak if not left_is_speaker else sc_listen
    left_dw = int(round(lw * left_sc))
    right_dw = int(round(rw * right_sc))
    left_x = left_margin
    right_x = stage_w - right_margin - right_dw

    # Panel centered on stage, sized to sit between bust midpoints
    pw = panel_w
    panel_x = int(round((stage_w - pw) / 2))
    # Keep panel from covering bust faces: stay clear of outer thirds
    panel_x = max(panel_x, left_x + left_dw - 12)
    if panel_x + pw > right_x + 12:
        panel_x = right_x + 12 - pw
    panel_x = max(left_margin + 4, min(panel_x, stage_w - right_margin - pw - 4))

    pad = 8
    wrap_w = pw - pad * 2
    wrapped_lines = measure_mono_wrap(line, font_size, wrap_w)
    wrapped_line = '\n'.join(wrapped_lines)
    # Character-preservation check
    if re.sub(r'\s+', '', wrapped_line) != re.sub(r'\s+', '', line):
        wrapped_line = line  # fall back; enable wrap in layer

    # Nameplate ATTACHED to panel top edge (not floating over the body).
    # Bottom-anchored: plate bottom at y=-(panel_h) = panel top; text sits inside plate.
    # Accent by speaker: Klixx cyan #5fe3ff, Pity orange #ff8a3d
    if speak_side == 'left':
        # Near-white with a cyan lean — full brightness, high contrast on dark plate
        name_color = '#e8fbff'
        accent_rgb = (95, 227, 255)
    else:
        name_color = '#fff0e4'
        accent_rgb = (255, 138, 61)

    label_u = speaker_label.upper()
    plate_w = max(44, int(len(label_u) * 6.2) + 14)
    plate_h = 16
    if nameplate_asset is None:
        nameplate_asset = make_nameplate_asset(
            plate_w, plate_h, name=f'nameplate_{speak_side}', accent=accent_rgb,
        )
    else:
        # Mutate in place so the project-registered asset id stays valid
        npw = max(plate_w, int(nameplate_asset.get('_w') or plate_w))
        nph = max(16, int(nameplate_asset.get('_h') or plate_h))
        make_nameplate_asset(
            npw, nph,
            name=nameplate_asset.get('name') or f'nameplate_{speak_side}',
            accent=accent_rgb, into=nameplate_asset,
        )
        plate_w = npw
        plate_h = nph

    plate_y = -panel_h          # flush with dialogue panel top
    text_y = -panel_h - 2       # baseline a few px up into the plate
    if speak_side == 'left':
        plate_x = panel_x
        name_x = plate_x + 6
    else:
        plate_x = panel_x + pw - plate_w
        name_x = plate_x + 6

    # Dialogue text bottom-anchored inside panel with bottom padding;
    # keep top of wrapped block below panel top (panel_h - 2*pad budget).
    line_y = -pad

    if panel_asset is None:
        panel_asset = make_dialogue_panel_asset(pw, panel_h)

    # Front-first: nameplate + name, line, panel, busts
    layers.append(img_layer(
        nameplate_asset, name='dlg_nameplate', anchor='bottom', parallax=0,
        x=plate_x, y=plate_y, scale=1.0, opacity=1.0,
    ))
    layers.append(text_layer(
        label_u, name='Speaker', fontSize=11, textColor=name_color,
        color=name_color,  # some builder paths read `color`; keep in sync
        outline=1, outlineColor='#000000', align='left', anchor='bottom',
        x=name_x, y=text_y, reveal=0, wrap=False, parallax=0,
    ))
    layers.append(text_layer(
        wrapped_line, name='Line', fontSize=font_size, textColor='#e8f4ff',
        outline=2, outlineColor='#05060e', align='left', anchor='bottom',
        x=panel_x + pad, y=line_y,
        reveal=26, revealDelay=0.10,
        wrap=True, wrapW=wrap_w, parallax=0,
    ))
    layers.append(img_layer(
        panel_asset, name='dlg_panel', anchor='bottom', parallax=0,
        x=panel_x, y=0, scale=1.0, opacity=1.0,
    ))

    fo = fade_out_at

    def one_bust(asset, *, name, x_rest, flip, is_speaker, sc_end):
        sc_start = sc_end * 0.92
        op_end = 1.0 if is_speaker else listen_opacity
        br_end = 1.0 if is_speaker else listen_bright
        sat_end = 1.0 if is_speaker else listen_sat
        x_start = x_rest + (16 if flip else -16)
        op_keys = [(0.0, 0.0, 'linear'), (appear, op_end, 'out')]
        sc_keys = [(0.0, sc_start, 'linear'), (appear, sc_end, 'out')]
        x_keys = [(0.0, x_start, 'linear'), (appear, x_rest, 'out')]
        br_keys = [(0.0, br_end * 0.9, 'linear'), (appear, br_end, 'out')]
        if fo is not None:
            op_keys += [(fo, op_end, 'linear'), (dur, 0.0, 'in')]
            sc_keys += [(fo, sc_end, 'linear'), (dur, sc_end * 0.96, 'in')]
        else:
            op_keys += [(dur, op_end, 'linear')]
            sc_keys += [(dur, sc_end, 'linear')]
        x_keys += [(dur, x_rest, 'linear')]
        br_keys += [(dur, br_end, 'linear')]
        return img_layer(
            asset, name=name, anchor='bottom', parallax=0,
            x=x_rest, y=bust_y, scale=sc_end, opacity=op_end,
            flipH=flip, bright=br_end, sat=sat_end, blur=0,
            k={
                'opacity': _kf(op_keys),
                'scale': _kf(sc_keys),
                'x': _kf(x_keys),
                'bright': _kf(br_keys),
            },
        )

    left_bust = one_bust(
        left_asset, name=f'bust:{left_name}', x_rest=left_x, flip=False,
        is_speaker=left_is_speaker, sc_end=left_sc,
    )
    right_bust = one_bust(
        right_asset, name=f'bust:{right_name}', x_rest=right_x, flip=True,
        is_speaker=not left_is_speaker, sc_end=right_sc,
    )
    # Front-first order: name, line, busts (above panel), panel (behind busts)
    # Rebuild so the panel does NOT cover bust chests.
    # Front-first: Speaker+Line above nameplate (plate must not cover bright name text)
    by_name = {L.get('name'): L for L in layers}
    ui_text = [by_name[n] for n in ('Speaker', 'Line', 'dlg_nameplate') if n in by_name]
    if left_is_speaker:
        busts = [right_bust, left_bust]
    else:
        busts = [left_bust, right_bust]
    panel_layer = img_layer(
        panel_asset, name='dlg_panel', anchor='bottom', parallax=0,
        x=panel_x, y=0, scale=1.0, opacity=1.0,
    )
    layers = ui_text + busts + [panel_layer]
    return layers, panel_asset


def apply_set_focus(layers: list[dict], *, blur: float = 1.15, body_dim: float = 0.72,
                    fade: float = 0.28, hold_blur: bool = True,
                    already: bool = False) -> list[dict]:
    """Blur set layers + gently dim full-body cast during VN dialogue."""
    out = []
    skip_names = {'Speaker', 'Line', 'dlg_scrim', 'dlg_panel', 'fade_black', 'station_light'}
    for L in layers:
        L = dict(L)
        name = str(L.get('name', ''))
        kind = L.get('kind')
        if name.startswith('bust:') or name in skip_names or kind == 'text':
            out.append(L)
            continue
        is_body = name in ('Klixx', 'Pity', 'KlixxMCU', 'PityMCU') or name.startswith('cast:')
        prev_k = dict(L.get('k') or {})
        if is_body:
            if not hold_blur:
                prev_k['bright'] = _kf([(0.0, body_dim, 'linear'), (fade, 1.0, 'out')])
                prev_k['opacity'] = _kf([(0.0, 0.85, 'linear'), (fade, 1.0, 'out')])
            elif already:
                prev_k['bright'] = _kf([(0.0, body_dim, 'linear'), (fade, body_dim, 'linear')])
                prev_k['opacity'] = _kf([(0.0, 0.85, 'linear'), (fade, 0.85, 'linear')])
            else:
                prev_k['bright'] = _kf([(0.0, 1.0, 'linear'), (fade, body_dim, 'out')])
                prev_k['opacity'] = _kf([(0.0, 1.0, 'linear'), (fade, 0.85, 'out')])
        else:
            if not hold_blur:
                prev_k['blur'] = _kf([(0.0, blur, 'linear'), (fade, 0.0, 'out')])
            elif already:
                prev_k['blur'] = _kf([(0.0, blur, 'linear'), (fade, blur, 'linear')])
            else:
                prev_k['blur'] = _kf([(0.0, 0.0, 'linear'), (fade, blur, 'out')])
        L['k'] = prev_k
        out.append(L)
    return out



def build_dialogue_scene(
    *,
    title: str,
    set_builder,
    cast: dict,
    lines: list[tuple[str, str]],
    shot_plan: list[dict],
    sounds: list | None = None,
    assets_extra: list | None = None,
    out_path: Path | str | None = None,
    grade_fx: dict | None = None,
) -> Path:
    """Reusable dialogue cutscene assembler.

    cast: { 'Klixx': asset, 'Pity': asset }
    lines: [(speaker, text), ...] matched by shot_plan entries with kind 'line' + line_index
    shot_plan entry keys:
      name, dur, tin, cam, kind: 'establish'|'ots'|'push'|'hold'|'custom',
      focus: speaker name for ots/push, line_index: int|None,
      layers_hook: optional callable(base_layers)->layers,
      audio: optional cue list, pull_back: bool for establish wider
    set_builder(): returns (assets:list, base_layers:list) front-first without characters/dialogue
    """
    assets, base = set_builder()
    if assets_extra:
        assets.extend(assets_extra)
    sounds = list(sounds or [])
    shots = []
    for spec in shot_plan:
        kind = spec.get('kind', 'custom')
        layers = [dict(L) for L in base]  # shallow copy per shot
        # re-clone nested k if present
        layers = __import__('copy').deepcopy(base)

        chars = []
        focus = spec.get('focus')
        if kind == 'establish' or kind == 'hold':
            names = list(cast.keys())
            chars = two_shot_characters(
                cast[names[0]], cast[names[1]],
                left_name=names[0], right_name=names[1],
                scale=spec.get('scale', 0.9 if kind == 'hold' else 0.92),
                feet_y=spec.get('feet_y', -30),
                left_cx=spec.get('left_cx', 90 if kind == 'hold' else 95),
                right_cx=spec.get('right_cx', 230 if kind == 'hold' else 225),
            )
        elif kind in ('ots', 'push'):
            other = [n for n in cast if n != focus][0]
            side = 'left' if focus == list(cast.keys())[0] else 'right'
            chars = ots_characters(
                cast[focus], cast[other],
                focus_name=focus, other_name=other,
                side=side,
                focus_scale=spec.get('focus_scale', 1.35 if kind == 'push' else 1.2),
                other_scale=spec.get('other_scale', 1.7),
                feet_y=spec.get('feet_y', -20 if kind == 'push' else -28),
            )
        if chars:
            layers = insert_characters(layers, chars, behind_fg=True)

        li = spec.get('line_index')
        if li is not None and 0 <= li < len(lines):
            spk, txt = lines[li]
            scrim = spec.get('scrim')
            chrome = dialogue_chrome(spk, txt, reveal=spec.get('reveal', 24),
                                     scrim_asset=scrim)
            layers = chrome + layers

        if spec.get('layers_hook'):
            layers = spec['layers_hook'](layers)

        fx = dict(grade_fx or {})
        fx.update(spec.get('fx') or {})
        shots.append(new_shot(
            name=spec.get('name', kind),
            dur=float(spec.get('dur', 3.0)),
            bg=spec.get('bg', '#0a0c14'),
            tin=spec.get('tin') or new_tin('cut', 0.1),
            cam=spec.get('cam') or cam_move('hold'),
            fx=fx,
            layers=layers,
            audio=spec.get('audio') or [],
        ))

    P = new_project(title)
    P['shots'] = shots
    path = Path(out_path) if out_path else (PROJECTS / f'{title.lower().replace(" ", "_")}.parallax.json')
    write_project(path, P, assets, sounds)
    return path
