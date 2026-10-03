# map_ambient smoke-test pack

Scaffold sample for Lattice **map / tile ambient** overlays (see `../../MAP_AMBIENT.md`).

## Files

| File | Role |
|---|---|
| `bd_map_smoke_vent_strip.png` | Smoke loop strip · **64×64** · **12** frames · horizontal · **768×64** |
| `bd_map_smoke_vent_clip.json` | `lattice.clip.v1` · `kind: ambient` · `loop: true` · fps 7 |
| `building_base_coolingtower.png` | Static base · from `bsheet_040_14_2.png` · 128×157 |
| `qa_smoke_on_building.png` | QA: base + smoke frame 0 + full strip |
| `bd_map_drone_orbit_strip.png` | Optional placeholder drone · 32×32 · 8f |
| `bd_map_drone_orbit_clip.json` | Same ambient schema · procedural |

## Asset choices

- **Smoke (required):** `cutscene/assets/fx/smoke roll 001.png`. That file (and 002–005) is a **4×3 sheet of 384×384 cells**, not a single frame. Pack extracts all **12 cells** row-major → NEAREST-scaled to 64×64, bottom-centered (vent `anchor`). Sibling sheets 002–005 not packed (same layout; swap later if art direction prefers).
- **Building:** `cutscene/assets/props/bsheet_040_14_2.png` — cooling-tower industrial. Near-black → alpha; downscaled to 128px wide. Chosen over `building_sheet_*` because vents read under smoke.
- **Drone (optional):** procedural cyan orbit dots. Replace with authored mini-drone later.

## Iso / sort

Facing-agnostic. `anchor` + `sortBias` + `depthKey: "share_base"` so overlays sort with the building. Tile contract: 64×32 / `elevationStep` 16 (Lattice STATUS / HANDOFF).

## Honest limits

Placeholder from existing FX/prop crops — not final Map Workshop authored ambient. Smoke is one sheet's cells, not a bespoke vent-sized loop.
