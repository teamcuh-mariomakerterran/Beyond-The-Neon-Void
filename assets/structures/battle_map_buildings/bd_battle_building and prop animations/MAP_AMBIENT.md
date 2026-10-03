# Map / tile ambient animations (Lattice scaffold)

*Black Doctrine — facing-agnostic building/city life: smoke, steam, neon flicker, machine blink, mini-drone loops.*

Facing-agnostic. **Do not invent Forge character DIR_ORDER** here — that stays Art Director / Forge 84×84 territory.

---

## Layer model

```
┌─────────────────────────────────────┐
│  looping overlay strip(s)           │  smoke / flicker / drone  (ambient clip)
│  sortBias · anchor · depthKey       │
├─────────────────────────────────────┤
│  static base tile / building        │  prop sheet crop or Map Workshop tile
└─────────────────────────────────────┘
```

- **Base** — still art (iso building / tile). Owns the footprint and the shared **`depthKey`**.
- **Overlay(s)** — one or more `lattice.clip.v1` horizontal strips with `loop: true`. Drawn on top (or interleaved by `sortBias`) without flipping for facing.
- Multiple overlays per base are fine (vent smoke + neon flicker + rooftop drone).

---

## Clip kind: `ambient`

Extend `lattice.clip.v1` kinds with **`ambient`** (literal). Optional alias **`tile_loop`** for the same shape.

| Field | Ambient default | Notes |
|---|---|---|
| `kind` | `"ambient"` | Also accept `"tile_loop"`; `"fx"` remains generic FX |
| `loop` | `true` | Required for map life loops |
| `fps` | see timing | Strip playback rate |
| `holds` / `tickSequence` | optional | Neon flicker: irregular holds OK |
| `facing` / `dirs` | `null` | Facing-agnostic — leave null |
| `anchor` | `[cx, cy]` optional | Pivot in cell space (e.g. vent base) |
| `sortBias` | `0` optional | Integer nudge vs base / sibling overlays |
| `depthKey` | `"share_base"` | Overlays share the building’s iso depth key |
| `layout` | `"horizontal"` | Same as character clips |
| `cell` / `rects` / `frames` | required | Same rect contract as combat clips |

Export → Clip can tag `ambient` once `CLIP_KINDS` includes it (`src/js/29_clip.js`). Sample JSON may carry `loop` / `anchor` / `sortBias` / `depthKey` even if the Export UI does not yet edit those fields — consumers read them from the manifest.

---

## Timing defaults

| Effect | fps | Holds |
|---|---|---|
| Smoke / steam | **6–8** (scaffold uses 7) | usually even; soft loop |
| Neon / sign flicker | 4–12 | **irregular holds OK** (e.g. 3,1,1,4,1) |
| Machine blink / LED | 2–6 | long off, short on |
| Mini-drone orbit | 6–10 | even; ellipse reads as orbit |

Prefer **holds** over duplicating frames when flicker is irregular.

---

## Export shape (Map Workshop / Forge / cutscene)

Consumers get the same pair as combat clips:

1. **`*_strip.png`** — horizontal strip, cell `W×H`, `frames` cells wide.
2. **`*_clip.json`** — `lattice.clip.v1` with `kind: "ambient"`, `loop: true`, rects, fps, optional anchor/sortBias/depthKey.
3. **Base** — separate static PNG (or Map Workshop tile id). Manifest may reference it under `textures.base` for QA / packing hints; engines may bind overlay → building id externally.

Optional pack index (future): `lattice.ambient.pack.v1` listing `{ base, overlays: [clip,…] }` — **not required** for this scaffold.

Cutscene / Forge can Intake the strip like any other Lattice strip; kind tells runtime to loop without character facing logic.

---

## Iso awareness

From Lattice STATUS / HANDOFF (Neon Meridian / BD contract):

- Tile **64×32** (2:1 dimetric); correct diamond ≈ **1088** opaque px.
- **`elevationStep` 16**.
- Multi-tile buildings anchor at the far corner; overlays **inherit the base `depthKey`** so smoke does not pop in front of the wrong neighbour.

`anchor` is in **overlay cell pixels** (not world). Place the vent/chimney pivot there; map code offsets overlay to the building local attach point. `sortBias` breaks ties when two overlays share a depth key (e.g. drone above smoke: `sortBias: 2` vs `1`).

---

## Honest limits

| Placeholder (this scaffold) | Authored (later) |
|---|---|
| Cropped FX sheet cells + prop building | Map Workshop vent-sized loops, neon masks |
| Procedural drone dots | Real mini-drone / traffic sprites |
| Manual `textures.base` hint | Building id ↔ overlay bind table |
| No runtime map player in Lattice | Engine / Map Workshop playback |

Smoke-test pack under `samples/map_ambient/` proves the **manifest + strip** shape only — not final city art.

---

## Sample paths

```
samples/map_ambient/
  bd_map_smoke_vent_strip.png      # 12×64×64 → 768×64
  bd_map_smoke_vent_clip.json      # kind: ambient, loop, fps 7
  building_base_coolingtower.png  # static base (bsheet_040_14_2)
  qa_smoke_on_building.png        # base + frame 0 + strip
  bd_map_drone_orbit_strip.png    # optional placeholder
  bd_map_drone_orbit_clip.json
  README.md
```

See also `PLAYBOOK.md` § map ambient.
