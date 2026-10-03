# Lattice clips in Beyond: The Neon Void

_Full format reference from Lattice: [LATTICE_CLIP_FORMAT_GUIDE.md](LATTICE_CLIP_FORMAT_GUIDE.md). The loader follows its canonical rules: holds are ticks, missing `loop` = false, anchor → pivot → bottom-centre, and overlays and `damage_overlay` are kept out of the palette._

_A handoff for the Lattice animator: how the game reads `lattice.clip` exports, and a few optional extras that would make them shine even more. Reader code: `src/vfx/lattice_clip.gd`. Renderer: `src/world/world_renderer.gd` (WorldSprite)._

## What the game uses today

| Field | How the game uses it |
|---|---|
| `format` = `"lattice.clip"` | Detects a clip. The JSON sits next to its strip. |
| `textures.strip` | The PNG strip, path relative to the JSON. Files are named `name_clip.json` + `name_strip.png`, and the overlay is `name_overlay_clip.json` + `name_overlay_strip.png`. |
| Opaque background | Handled. If all four corners of frame 0 are the same opaque colour, or `"bgKey": "#rrggbb"` is set, the game flood-fills that backdrop in from the frame edges. Dark pixels *inside* the building, such as a courtyard, survive. The cutout is applied to every frame and cached. `"bgKey": false` turns this off. |
| `cell`, `rects` (or `frames` + `layout`) | Frame regions. If `rects` is missing, the strip is sliced by `cell`. |
| `fps` / `frameMs` | Base frame time. |
| `holds` | Per-frame hold. Values over 10 are read as **ms**, otherwise as a **multiplier of frameMs**. *(Please confirm which you mean.)* |
| `tickSequence` | Custom frame order. If it's null, the game plays 0 to n-1. |
| `loop` | Loop, or stop on the last frame. |
| `anchor` [x, y] | The ground-contact pixel. It's pinned to the front of the object's footprint on the iso grid. |
| `sourceArt.footprint` {w, h} | The object's footprint in cells (the larger side). It drives draw order and blocks movement. |
| `buildingBBox` | Click / selection box, and auto-scaling on placement. |
| `phaseSeed` | Clock offset. The game also adds a per-instance offset, so copies never sync. |
| `overlayClip` | A second clip drawn on top, on the same canvas and anchor and on the same clock. |
| `emitters.beacons` + `emitters.windows` | Up to 5 **real game lights** (Godot PointLight2D) hung at these points, coloured from the strip pixel underneath. They spill onto the street and units at night. |
| `title` | Shown in the editor tooltip. |

Not used yet: `kind`, `holds` (until confirmed), `facing` / `dirs`, `depthKey`, `sortBias`, `emitters.neon` / `vents` / `pointLights` (85 per building is too many real lights), `screens`, `signs`, `pings`.

## Wishlist (all optional)

1. ~~Transparent background~~. This is handled now (see above). True alpha is still the cleanest option, because keyed edges keep a thin dark fringe.
2. **Light colour + strength per emitter**, e.g. `"beacons": [[x, y, "#3ff6ff", 0.8], …]`. Today the game samples the pixel colour, which works but can pick up dark edges.
3. **A light budget.** A short `"lights": [{x, y, color, radius, flicker}]` list (3–6 entries) marking the lights *you* think should glow onto the world. If it's present, the game uses it instead of guessing from beacons and windows.
4. **`facing` / `dirs` for units and vehicles.** For 8-direction characters (the submarine, tanks, bosses), list which frame range is which facing. Battles use the **4 diagonals** (screen NE, NW, SE, SW), and cutscenes use all 8.
5. **`kind`.** It already ships (`ambient`, `ambient_overlay`). If it could also say `building | prop | item | unit | vehicle | fx`, the game could file each clip in the right palette automatically.
6. **`eventFrames`.** Frames where something happens, e.g. `{"7": "door_open", "15": "steam_burst"}`. The game can play sounds or trigger effects on those frames.
7. **Footprint in game tiles.** `sourceArt.footprint` is `1×1` on bl_036_04, a full courtyard block, so it's placed about 1.4 tiles wide. If a building should cover more of our grid, a `"gameFootprint": {"w": 2, "h": 2}` would let us size it right. The painter can also override this per object.

## Where clips go
Upload clips with the intake bot into `E:\Beyond_TheNeonVoid\animated\...`. Keep each `.json` next to its `_strip.png`, and its `_overlay_clip.json` next to the overlay strip. In the World Painter they appear in the Objects palette with a ▶ icon.

## Requesting a specific animation from Lattice
Give Lattice these numbers along with the request:

- **Grid.** Build everything at **64×32**, the same tile your packs already use. Battle maps are 64×32. The bigger 128×64 world maps scale the art ×2 themselves. The `anchor` lands on the bottom tip of the tile diamond, as in Lattice's own scene.
- **Units and bosses.** Battles need the 4 diagonals (NE, NW, SE, SW), and cutscenes can use all 8. Keep your own layout: one file per action per facing, named `<unit>_<FACING>_<action>_clip.json`, or a `dirs-rows` sheet. Your kinds work as they are. The game maps `aim_fire`/`attack` → attack, `hurt` → hit, plus `idle`, `walk`, `death`, and `wreck` (via `endsOn`). `cast` falls back to attack until a cast clip exists. A missing diagonal is borrowed by flipping its pair (SE↔SW, NE↔NW).
- **FX** (spells, hits, summons). Use `kind: "fx"` with a transparent background and normal blending. The impact rule follows your guide: frame 0 for `fx_impact`, `hits[]` when present.
- **Status effects done by the game.** The game itself sinks the unit during **banish** and greys it out for full **petrify**, using the timing written in the clip files.
- **Props and items.** These follow the same rules as buildings. Loops should be seamless, and the game desyncs copies on its own.

Anything outside these rules is still fine. Send it over, and the game gets an importer for it.
