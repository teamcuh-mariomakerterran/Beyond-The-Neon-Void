# fx_rocket_8dir

Reusable rocket shot in all 8 directions, in the style of the library launcher/MLRS rockets.

**Direction order:** `N, NE, E, SE, S, SW, W, NW` — Forge `SHEET_DIR_ORDER` (`pixel-forge-app/src/lib/sheetImport.js`), the same order Lattice UnitKit reads from a kit's `facings`.

**Projection:** 2:1 dimetric battle plane (tile 64x32). N/S fly straight up/down the screen, E/W horizontal, diagonals follow tile edges (2:1). `travelVector` in each clip is the screen-space unit vector (y down).

## Files per direction `<D>`

| file | what | loop |
|---|---|---|
| `fx_rocket_flight_<D>` | ignition flash, rocket body, smoke trail that lingers and dissipates (18 frames @ 14 fps = 71 ms/frame) | no |
| `fx_rocket_inflight_<D>` | rocket + flame flicker + short trail stub, for engine-moved projectiles (6 frames) | yes |
| `fx_rocket_backblast_<D>` | optional rear FIRE cone + smoke cloud for the launcher (10 frames) | no |

Each is `<id>_strip.png` (horizontal) + `<id>_clip.json` (lattice.clip v1 + `spawn`, `travelVector`, `frameMs`, `dirOrder`, `dirIndex`).

## Hooking it to a launcher

1. Pick the launcher's firing facing `D` (Forge order above) and its muzzle tip in the unit/weapon cell (e.g. a library clip's `muzzleTips[frame]`).
2. Draw `fx_rocket_flight_<D>` with its `spawn` pixel on that muzzle tip, starting on the launcher's fire frame. It plays once.
3. The nose position per frame is in `rocketPath`; the rocket leaves at 110px (`rocketGoneFrame`). For longer flights, swap in `fx_rocket_inflight_<D>` there and move it along `travelVector`.
4. Optional: put `fx_rocket_backblast_<D>`'s anchor on the launcher's rear exhaust on the same frame.

Nothing touches the cell edges (checked per frame), so the clips can be placed without clipping.
