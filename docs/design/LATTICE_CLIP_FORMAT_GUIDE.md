# Lattice clip format guide (`lattice.clip` v1 + PNG strips)

This guide is for engine consumers (the Godot tactics game). Every statement here comes from the Lattice code
(`src/js/*`, `src/core_all.js`) or a scan of the shipped clip JSONs: **3,197 `lattice.clip` files** under
`animations/` and `samples/` (as of 2026-10-02). Where packs disagree, the guide names each pack and gives a
**canonical reading** that works for all of them.

---

## 0. TL;DR for a loader

```
frameMs   = clip.frameMs ?? 1000 / clip.fps        // ms per tick
frame i   = rects[i] (or x = i*cell[0], y = 0, w,h = cell)
duration  = (holds ? holds[i] : 1) * frameMs       // holds = integer tick multipliers, never ms
loop      = clip.loop === true                     // missing = false
origin    = anchor [x,y], in cell pixels, top-left origin, y down; it lands on the ground/tile point
overlay?  = kind ends in "_overlay" || overlay === true || overlayOf != null
blend     = normal alpha (source-over). No pack has a blend field.
```

---

## 1. `holds`: tick multipliers, not milliseconds

**Answer:** each `holds[i]` is an **integer count of ticks**, and one tick is `frameMs` (= `1000/fps`). Frame `i`
is shown for `holds[i] × frameMs` ms. `holds: null` (or missing) means every frame gets 1 tick.

How Lattice plays it:
- `src/js/28_audit.js` `frameHold(i)` (l.670): returns `Math.round(v)`, and any value below 1 becomes 1. The UI
  limits holds to integers from 1 to 8 (l.699). Its hint says: *"How many ticks each frame is held. A hold of 2
  means that frame lasts twice as long."*
- `src/js/28_audit.js` `timingSequence(n)` (l.681): expands the strip into a tick list by repeating frame `i`
  `hold` times.
- `src/core_all.js` `playTick(ts)` (l.4351): advances **one tick every `1000/fps` ms**. When holds are on, it walks
  the `timingSequence` list. Otherwise it steps one frame per tick.
- `src/js/29_clip.js` `clipHolds()` / `buildClipManifest()` (l.49, l.149): export writes `holds` (one per frame)
  and also writes `tickSequence`, the expanded list. When timing is off, both are `null`.

**Example** (shipped: `gold_vehicles/hero_cutscene/gv_g51_SW_fire_clip.json`): `fps:10, frameMs:100,
holds:[1,1,1,1,2,2,2,3,4]` gives per-frame times 100,100,100,100,200,200,200,300,400 ms, so **1700 ms total**.
The pack README says the same: "1.7 s at 10 fps". The damage-pack hero JSONs also state it in `layering`:
"holds = ticks per frame at 10fps".

Where holds appear: only **15 shipped clips** have non-null holds: the 6 hero fire clips (full + overlay for
g48/g50/g51) and the 9 hero death parts (`death_a/b/c` for each hero). All other `animations/` clips use
`holds:null`. In `samples/`, they appear in 15 `buildings_destroyed` clips (`[1,…,1,3]`) and 2 trooper-walk
samples. **No clip has `durationMs`.** Compute duration as `Σ(holds[i] or 1) × frameMs`.

Caveats in Lattice itself (not bugs in the data):
- When a clip JSON is loaded back into Lattice, `applyClipManifest` (`29_clip.js` l.106) reads `fps` but **not**
  `holds` or `tickSequence`.
- The **Packs** browser preview (`40_packs.js` `packsPlayer`, l.46) plays every frame at `1000/fps` and
  **ignores holds**, so hero clips preview faster than intended.
- `tickSequence` is `null` or missing in every shipped pack, even the hero clips that have holds. Treat `holds`
  as authoritative and `tickSequence` as optional.

`frameMs` vs `fps`: `frameMs` is present in all of building_life, interior_props_life, gold_vehicles,
gold_vehicles_damage, fx_impacts and fx_rocket_8dir. It's present in only **14 of 65** library_anims clips, and in
**no** `samples/` clips. It's a rounded integer (12 fps → 83, 14 fps → 71, 8 fps → 125). In all 2,752 clips
that carry both fields, `frameMs == round(1000/fps)`.
**Canonical:** use `frameMs` when present, else `1000/fps`.

---

## 2. Units and characters: actions and facings

**Short answer:** the layout is **one clip file per action per facing**. No pack uses frame ranges inside `dirs`.
**No shipped clip is a mirrored facing.** The one exception to one-file-per-facing is the older
**`dirs-rows`** character sheets, which hold one action with all 8 facings as rows.

### 2a. Layouts that exist
| layout | where | facings |
|---|---|---|
| `"horizontal"` (3,152 clips) | every `animations/` pack and most samples | one facing per file: `facing` is `"NW"` etc. or `null` (facing-agnostic) |
| `"dirs-rows"` (44 clips) | `samples/combat_clips/from_brians_packs/**`, `samples/combat_clips/shared_aim_fire_84x84_f11`, `samples/retargeted_walks/*`, unitkit fixtures | rows = directions in `dirOrder` (always `N,NE,E,SE,S,SW,W,NW`), columns = frames. Each rect is `{i, dir, frame, x, y, w, h}` with `x = frame*cellW`, `y = dirOrder.indexOf(dir)*cellH` (verified for all 44) |

`dirs` is **inconsistent**: Lattice's exporter writes `null` or `[facing]` (`29_clip.js` l.166). The dirs-rows
samples write the **integer 8**. Several packs leave it out. **Canonical:** ignore `dirs`. Use `facing` for
horizontal clips, and `rects[].dir` + `dirOrder` for dirs-rows.

Lattice's own Export → Clip writes **one facing per file** (`29_clip.js` header and `dirOrderNote`). The
"facing batch" export writes one `clip.v1` + strip per user-typed label, plus a `<base>_facing_batch.json` index
(`format:"lattice.clip.batch"`). Those labels are free text and **not** Forge order.

### 2b. Direction order
- Forge `SHEET_DIR_ORDER` = **N, NE, E, SE, S, SW, W, NW** (`pixel-forge-app/src/lib/sheetImport.js:26`). The
  `dirOrder` arrays in fx_rocket_8dir and dirs-rows clips copy it.
- fx_rocket_8dir also carries `dirIndex` (NE=1, SE=3, SW=5, NW=7).
- **Black Doctrine gameplay only uses NW / NE / SE / SW.** gold_vehicles, gold_vehicles_damage and fx_impacts
  ship only those 4. fx_rocket_8dir and the library crystal/gem/drone sets ship all 8, so pick the diagonals.
- In fx_impacts, `<dir>` is the direction the **incoming shot travels**, not a unit facing.

### 2c. gold_vehicles (unit idle + attack)
Files are `<group>/gv_<unit>_<FACING>_<idle|fire>[_overlay]_clip.json` + `_strip.png`. The groups are tanks,
launchers, light_vehicles, hover, air, mechs and hero_cutscene.
- `kind`: `idle` (loop) / `attack` (one-shot, file suffix `fire`) and `idle_overlay` / `attack_overlay`.
- **Cell size and anchor differ per facing.** For example, mech g00 is 73×84 at NW and 49×85 at NE. Read
  `cell`/`anchor` from each clip, never per unit.
- Timing: idle is 12 frames (mechs 16) at 100 ms. Tank fire is 14 frames, light burst 12, rocket salvo 22, all
  non-looping.
- Extra fields: `unit`, `unitType`, `group`, `emitters` (see §6), plus `overlayOf`/`overlayClip`.
- Missing painted views are **left out, not faked**: g40/g53/g55 have no SW. Heroes g48/g50/g51 are SW only
  (`paintedFacings`, `missingFacings`, `mirrorNote`: "A horizontal flip would give SE but mirrors
  decals/antenna side; not shipped"). g12 has no fire clip.

### 2d. gold_vehicles_damage (hit, damage, death)
Files are `<group>/gvd_<unit>_<FACING>_<dmg_light|dmg_heavy|dmg_burning|death|wreck>_clip.json`.
- `damage_overlay` (×3 stages, loop, `overlay:true`): FX only, drawn over the gold_vehicles idle/fire clip.
- `death` (22 frames at 12 fps, one-shot): `endsOn` points at the wreck clip, and
  `lastFrameEqualsWreckFrame0:true`.
- `wreck` (12 frames, loop).
- All 5 clips of a unit-facing share **one padded canvas** with the same ground anchor as gold_vehicles.
  `idleClipOffset` = where the gold_vehicles idle cell's top-left sits in this canvas.
- Heroes split death into `death_a → death_b → death_c` (chained by `next`, with `part`/`parts`) so each strip
  stays under 16384 px.

### 2e. Action names: what exists
| Claude's action | what ships |
|---|---|
| idle | `idle` (gold_vehicles; dirs-rows `idle_*` samples) |
| walk | `walk`: samples only (retargeted_walks dirs-rows 84×84 f9; trooper placeholder). **No vehicle or mech walks** (one painted pose per facing) |
| attack | `attack` (gold_vehicles) **and** `aim_fire` (library_anims, samples). Same meaning, see §4 |
| cast | not present (closest: dirs-rows `fx_digital_healing_96x96_f9`, kind `fx`) |
| hit | `hurt` (samples). For vehicles: `damage_overlay` stages |
| death | `death` (+ `wreck` rest loop for vehicles) |

### 2f. UnitKit (Pixel Forge `pixel-forge/unit-kit/1`, read by `src/js/39_unitkit.js`)
This is **not** `lattice.clip`. It's Forge's kit format, which Lattice only reads.
- The **only** source of direction order is `kit.facings`. It's cross-checked against every
  `sources.<state>.dirOrder`. A missing order or a conflict is an error; Lattice never guesses (`ukValidate`).
- `clips[]` holds one entry per **state × facing**: `{unitId, facing, state, frames:[[CelRef]], durationMs, frameMs?,
  loop, solver, landmarks{space:'content84', feet:[{x,y}]}}`. A CelRef is
  `{kind:'flat'|'slotted'|'override', sheet, frame{x,y,w,h}, z, pad?}`, and cels are composited by `z`.
- Timing (`ukTiming`): `durationMs` = **whole cycle**. `frameMs` wins when present, else `durationMs/frames`.
- Cels are cut at `contentSize` 84 and never scaled. Each built frame carries `ox,oy` relative to the centred 84
  anchor box, so feet stay planted.
- Kit facings are native and **never mirrored**: `ukSendToDistrict` sets `flipMirror=false`.

### 2g. Mirroring
- The only mirroring in Lattice is the District preview option **"Auto-flip mirror pad (W from E art)"**
  (`32_district.js` l.209/647, default on). It flips W/NW/SW from east-side art **on screen only**.
- No clip JSON has a mirror or flip flag. gold, library and fx packs state that no facing was mirrored or
  invented. If the game wants SE heroes, mirroring is its own decision (see `mirrorNote`).

---

## 3. FX packs: background, blending, impact frame

### Background / alpha (scanned every strip in `animations/`)
| pack | full clips | overlay clips |
|---|---|---|
| building_life | **150/150 fully opaque**, the art's own near-black bg (corner ≈ rgb 11,12,16, ±2). README: "use the overlay clips if the engine needs the building on transparent" | transparent, hard alpha (0/255) |
| interior_props_life | transparent bg, **keeps the source art's soft alpha edges** (all 244 have some 1–254 alpha) | transparent, hard alpha |
| gold_vehicles / _damage | transparent, hard alpha (except the 6 / 12 hero strips, which carry some semi-alpha) | transparent, hard alpha |
| fx_impacts, fx_rocket_8dir, library_anims | transparent, hard alpha | n/a |
| samples: effects waves 2–9, blasts, gore, combat shots, map_fx | transparent. Mostly hard alpha, with a little semi-alpha in map_ambient/map_fx/shots | n/a |

### Blending
**No clip or PACK has a `blend`/`additive`/`composite` field.** Glows are painted pixel colours.
- Overlays are documented and verified as **normal alpha compositing**: "overlay-over-static == full frame,
  verified for every frame of every clip" (building_life and interior_props_life READMEs).
- `17_states.js` l.204: "overlays are ordinary RGBA frames drawn on top at the same anchor".
- **Canonical: BLEND_MODE_MIX (normal).** Additive would change the look.

### Impact / event frame
**There is no `impactFrame`, `hitFrame` or `events` field in any pack.** What does exist:
| pack | field | meaning |
|---|---|---|
| fx_impacts `fx_impact_*` | (none needed) | **frame 0 = contact flash**: non-empty and smallest, then grows. Measured, not declared |
| fx_impacts burst | `hits:[{frame,x,y}]` | the 3 hits land at frames **0, 2, 4** |
| fx_impacts | `scorchFromFrame` (1 or 2) | scorch drawn under the blast from this frame |
| fx_impacts | `decal.startAtFrame` (= last frame) | lay the `scorch`/`crater` decal (loop) at the same ground point from here, then `*_fade` to remove it |
| fx_impacts | `impactCentre` | fireball centre at its peak (point only; the peak frame isn't recorded) |
| fx_rocket_8dir flight | `rocketPath[{frame,x,y,dist}]`, `rocketGoneFrame` (9) | nose position per frame (null once gone). Swap to `fx_rocket_inflight_<D>` at `rocketGoneFrame` for longer flights. Ignition is frame 0 |
| gold_vehicles attack | `emitters.recoilPx[]`, `muzzleTips[{frame,x,y,recoil_px}]` | the **shot frame = first frame with recoilPx > 0**: frame 1 for tanks, heroes and light vehicles (bursts at 1/3/5). The frame-0 overlay is empty |
| gold_vehicles launchers | `emitters.rocketHookup[{clip,startFrame,spawn,backblast{clip,startFrame,anchor}}]` | launch frames, e.g. 0 and 4 |
| gold_vehicles_damage death | `endsOn`, `lastFrameEqualsWreckFrame0` | switch to the wreck loop after the last frame |
| samples/combat/shoot | `flashPerFrame[{frame,strength,flashBBox}]` | muzzle-flash strength per frame |
| older samples/effects/blasts | none | frame 0 is **empty** (opaque px 0), so contact is frame 1. Measured |

**Canonical:** treat frame 0 as the hit for `fx_impact`, use `hits[]` when present, and use `recoilPx`,
`rocketHookup` or `startFrame` for attacker-side timing.

---

## 4. Every `kind` value

Counts are `lattice.clip` files under `animations/` + `samples/` (3,197 total).

| kind | count | packs | meaning |
|---|---|---|---|
| `damage_overlay` | 747 | gold_vehicles_damage | looping FX-only smoke/fire stage over a unit (`overlay:true`) |
| `ambient` | 503 | building_life 150, interior_props_life 244, library_anims 57, fx_rocket_8dir 8 (`inflight` loops), samples (effects 18, map_ambient 25, gore 1) | looping idle/ambient life, full frame or standalone FX |
| `ambient_overlay` | 394 | building_life 150, interior_props_life 244 | changed-pixels-only twin of an `ambient` clip (`overlayOf`) |
| `death` | 262 | gold_vehicles_damage 258, samples 4 | one-shot death |
| `idle` | 255 | gold_vehicles 252, samples 3 | looping unit idle |
| `wreck` | 252 | gold_vehicles_damage | looping wreck rest state after `death` |
| `fx` | 215 | fx_rocket_8dir 16 (flight/backblast), library_anims 1 (glitch skull), samples (effects 67, map_fx 73, gore 27, shots 30, combat_clips 1) | standalone effect, usually one-shot |
| `idle_overlay` | 131 | gold_vehicles | FX-only twin of a ground unit's idle |
| `attack` | 127 | gold_vehicles | one-shot fire (file suffix `fire`) |
| `attack_overlay` | 127 | gold_vehicles | FX-only twin of `attack`. The hull recoils by `recoilPx` along `-fireVector`, so offset the unit yourself or use the full clip |
| `aim_fire` | 80 | library_anims 7, samples (combat 65, combat_clips 6, ui fixtures 2) | Lattice/Forge combat kind for raise-and-fire |
| `walk` | 27 | samples only | walk cycle |
| `hurt` | 18 | samples only | hit reaction |
| `fx_impact` | 16 | fx_impacts | explosion at a ground point |
| `building_destroy` | 15 | samples/buildings_destroyed | building destruction one-shot (+ `states.destroyed` ruin texture) |
| `fx_decal` | 8 | fx_impacts | looping scorch/crater ground decal |
| `fx_decal_fade` | 8 | fx_impacts | one-shot decal fade-out |
| `custom` | 3 | samples (melee jab/punch, fixture) | anything else |
| `upgrading` | 3 | samples/map_ambient | building-state ambient (Lattice aliases it to `ambient`) |
| `research` | 1 | samples/map_ambient | building-state ambient (alias to `ambient`) |
| `combined` | 1 | animations/game_ready (demo) | District "save as single animation" (`33_game_ready.js`). **Its strip size doesn't match `cell×frames` and it has no `rects`, so ignore it** |
| *(missing)* | 4 | samples/buildings_destroyed (old) | pre-kind destroy clips |

Lattice's own list (`29_clip.js` `CLIP_KINDS`): `idle, walk, aim_fire, aim, fire, hurt, death, fx, ambient, tile_loop,
research, upgrading, building_destroy, destroying, destroyed, custom`, with these aliases on export:
- `aim`, `fire` → `aim_fire`
- `research`, `upgrading` → `ambient`
- `destroying`, `destroyed` → `building_destroy`

Unknown kinds become `custom` when re-imported into Lattice (`resolveClipKind`). `tile_loop` is defined but no
clip uses it.

**Inconsistency:** the pack kinds `attack`, `*_overlay`, `damage_overlay`, `wreck`, `fx_impact`, `fx_decal*` and
`combined` aren't in `CLIP_KINDS`. **Canonical:**
- base kind = `kind` with any `_overlay` suffix removed
- `attack ≡ aim_fire`
- `research`/`upgrading` ≡ `ambient`

---

## 5. `sourceArt.footprint`: Black Doctrine map tiles, copied from the game

**Answer:** **Yes, it's in tiles (map grid cells), not pixels.** It's `{w,h}` copied **verbatim** from the
game's placement library `public/assets/library/structure-placements.json`. Lattice doesn't measure it.
- Set by `/workspace/building_life/pack2.py:58` and `/workspace/interior_props/pack.py:41`
  (`footprint=P.get('footprint')`, where `P` is the placement entry).
- The game reads it as grid cells: `src/game/entity-layer.ts` `forgeBuildingAt` covers cells
  `x ≤ X < x+w`, `y ≤ Y < y+h`, and `battle-telemetry.ts` `cityIdsAt` does the same.
- One cell is the 64×32 dimetric battle tile.

Values: building_life `{1,1}` ×290 and `{2,1}` ×10. interior_props_life `{1,1}` ×414 and `{2,1}` ×74.

Other packs:
- gold_vehicles and gold_vehicles_damage: `sourceArt` exists, but `footprint` is `null`.
- library_anims: `sourceArt` is a plain string. Tile sizing is in the clip `name` (`_1tile/_2tile/_3tile`) and
  the `tiles` field, meaning base widths of 64/128/192 px.

**The footprint doesn't describe the strip's pixel size.** Building and prop canvases are the source art's native
size; for example, `bl_001_01` is 210×326 for a 1×1 footprint. Any downscale is the engine's choice.

Multi-tile placement in Lattice's own scene preview: a building anchors at the **far corner** cell
`(cx+fw-1, cy+fh-1)` (`LATTICE_HANDOFF.md` §5; `18_scene.js` l.89).

---

## 6. Field reference

| field | type | notes |
|---|---|---|
| `format`, `version` | `"lattice.clip"`, `1` | always |
| `name` | string | file stem. Strip = `textures.strip` |
| `cell` | `[w,h]` px | one frame. **Varies per clip and facing** |
| `frames` | int | frame count (`== rects.length` for horizontal) |
| `layout` | `"horizontal"` \| `"dirs-rows"` | see §2a |
| `rects` | `[{i,x,y,w,h}]` (+`dir`,`frame` for dirs-rows) | horizontal: `x=i*cell[0], y=0`. Verified for 3,152/3,152. Strip width = `cell[0]*frames` for every `animations/` clip except game_ready |
| `fps`, `frameMs` | number | §1 |
| `holds`, `tickSequence` | int[] \| null | §1 |
| `loop` | bool | missing in 15 sample clips. Treat missing as `false` (same as `40_packs.js` `packsNormalize`) |
| `facing` | `"NW"…` \| null | §2 |
| `dirOrder`, `dirIndex` | string[], int | fx_rocket_8dir, dirs-rows |
| `anchor` | `[x,y]` px | see below. Present in every `animations/` clip |
| `pivot` | **`[x,y]` or `{x,y}`** | library_anims: **artillery** = ground anchor (same as `anchor`); **dish spins** = rotation centre (dish centroid, ≠ anchor). dirs-rows samples: `{x,y}` feet pivot. Don't treat pivot as one concept |
| `mountPoint` | `[x,y]` | library dish spins: where the dish attaches (= `anchor`) |
| `feetByDir` / `feetPivots` | `{dir:y}` / `{dir:[x,y]}` | dirs-rows samples: per-direction ground contact |
| `textures.strip` | filename | same folder as the JSON |
| `overlayOf` / `overlayClip` | clip name \| null | building_life, interior_props_life, gold_vehicles pair full↔overlay |
| `overlay` | bool | gold_vehicles_damage only (no `overlayOf`; aligns by `anchor`/`idleClipOffset`) |
| `layering` | prose | how to draw it. Worth logging |
| `sortBias`, `depthKey` | int, string | `share_base` (buildings, props, library, effects) = use the base sprite's iso depth. `sortBias` breaks ties: full 0 / overlay 1 / library 2 / rocket 3 (`fx_over`). fx_impacts: `ground_point` (bias 2) and `ground_decal` (bias −5, draw under units). gold packs have none (`MAP_AMBIENT.md`) |
| `emitters` | object | attach points in **cell pixels** (top-left origin, y down). Shapes vary by pack: building `[[x,y]]` lists (beacons, pointLights, …); props `{x,y,warm}` objects + `panels{kind,bbox,slope}`; gold `muzzle [x,y]`, `muzzleTips[{frame,x,y,recoil_px}]`, `fireVector` (unit vector, screen space, y down), `recoilPx[]`, `exhaust`, `rocketHookup`; damage `emitters` + `emittersAll{core,top,engine}` |
| `spawn`, `travelVector`, `rangePx` | | fx_rocket_8dir: `spawn` (= `anchor`) goes on the launcher muzzle |
| `groundPoint`, `impactCentre`, `incomingVector`, `sprayVector`, `radius` | | fx_impacts |
| `qaGrade`, `qaNote`, `title`, `generator`, `source`, `phaseSeed`, `config`, `paletteCount` | | informational |

### Anchor convention
- `anchor = [x, y]` in **cell pixels**. It's the pixel that sits on the ground origin. Lattice's default is
  bottom-centre `(w>>1, h-1)` (`17_states.js` `stateAnchor`).
- The Lattice scene draws a sprite at `tileX + 32 − anchor.x`, `tileY + 31 − anchor.y`, so the anchor pixel lands
  on the **bottom vertex of the 64×32 diamond** (`18_scene.js` l.86).
- Measured on shipped strips, `anchor.y` = the **lowest opaque row** (inclusive) and `anchor.x` = the centre of
  the opaque bbox:
  - building_life: bottom-centre of the building footprint
  - interior_props_life: bottom-centre of the visible prop
  - gold_vehicles: ground contact under the hull. Because the cell is **padded asymmetrically** for FX, the
    anchor is often **not** the cell centre (e.g. `cell [136,63]`, `anchor [46,60]`)
  - fx_impacts: `groundPoint`
  - fx_rocket_8dir flight/backblast: `spawn` (muzzle / rear exhaust); inflight: the rocket nose
  - library dish spins: `mountPoint`
- `buildingBBox` / `propBBox` = `[x0,y0,x1,y1)` with an exclusive end.

### Padding
- building_life `bl_026_03_padded`: `padding{top:40,…}` + `anchorInSourceCanvas`. The anchor sits 40 px lower
  than in the exact-canvas `bl_026_03`.
- gold hero fire: `emitters.pad{left,top,right,bottom}`.
- library artillery v2: `padFromV1 [L,T,R,B]` + `v1Cell`.
- gold_vehicles_damage: `idleClipOffset`.
- Gore/kit_96 samples: `unitCell 84` vs `padCell`/`sheetCell 96` (pad canvas around 84-scale art).
- **The anchor always already includes the padding.** Just use `anchor`.

### Full vs overlay
- **Full** = drop-in replacement for the static sprite: same canvas and anchor as the art.
- **Overlay** = only the pixels that change, on transparent. Draw it over the static sprite (or the unit's
  idle/fire clip) with anchors aligned and normal alpha. For buildings and props, overlay-over-static equals the
  full frame exactly.
- Bobbing/breathing gold units (hover/air/mechs) have **no idle overlay**, because the body itself moves.

### Size limits
Every `animations/` strip is ≤ **15,840 px** wide. The hero death clips were split into a/b/c specifically to stay
under 16,384, a common GPU texture limit. 218 strips are over 8,192 px on one side (building_life 100, interior_props_life 94,
heroes 24). Some mobile/web GPUs cap textures at 8,192, so check them on the target.

---

## 7. Godot 4 loader (SpriteFrames, holds, anchor)

```gdscript
# lattice_clip.gd — Godot 4.x. Reads a lattice.clip JSON + its strip into a SpriteFrames animation.
class_name LatticeClip

static func load_json(path: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(d is Dictionary and d.get("format") == "lattice.clip", "not a lattice.clip: " + path)
	return d

static func frame_ms(c: Dictionary) -> float:
	var fm = c.get("frameMs")
	return float(fm) if fm != null else 1000.0 / float(c.get("fps", 10))

static func anchor_of(c: Dictionary) -> Vector2:
	var a = c.get("anchor")
	if a == null: a = c.get("pivot")                       # dirs-rows samples: {x,y}
	if a is Array: return Vector2(a[0], a[1])
	if a is Dictionary: return Vector2(a["x"], a["y"])
	var cell: Array = c["cell"]
	return Vector2(int(cell[0]) >> 1, int(cell[1]) - 1)    # Lattice default: bottom-centre

## Adds `anim` to `sf`. For dirs-rows clips pass dir ("NW"…). Returns the anchor (cell px).
static func add_anim(sf: SpriteFrames, anim: StringName, json_path: String, dir := "") -> Vector2:
	var c := load_json(json_path)
	var tex: Texture2D = load(json_path.get_base_dir().path_join(c["textures"]["strip"]))
	# (for files outside res:// use ImageTexture.create_from_image(Image.load_from_file(p)))
	if sf.has_animation(anim): sf.remove_animation(anim)
	sf.add_animation(anim)
	sf.set_animation_speed(anim, 1000.0 / frame_ms(c))      # 1 tick = frameMs
	sf.set_animation_loop(anim, c.get("loop", false) == true)
	var holds = c.get("holds")
	var cell: Array = c["cell"]
	var rects: Array = c.get("rects", [])
	if rects.is_empty():
		for i in int(c["frames"]):
			rects.append({"i": i, "x": i * int(cell[0]), "y": 0, "w": cell[0], "h": cell[1]})
	for r in rects:
		if r.has("dir") and r["dir"] != dir: continue
		var idx := int(r.get("frame", r.get("i", 0)))
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(r["x"], r["y"], r["w"], r["h"])
		var hold := 1.0
		if holds is Array and idx < holds.size(): hold = float(holds[idx])
		sf.add_frame(anim, at, hold)   # duration is relative: hold / animation_speed = hold × frameMs
	return anchor_of(c)
```

Usage. Anchors differ per clip and facing, so keep one offset per animation:
```gdscript
var sf := SpriteFrames.new()
var anchors := {}
anchors[&"idle_SE"] = LatticeClip.add_anim(sf, &"idle_SE", "res://anims/gold_vehicles/tanks/gv_g04_SE_idle_clip.json")
anchors[&"fire_SE"] = LatticeClip.add_anim(sf, &"fire_SE", "res://anims/gold_vehicles/tanks/gv_g04_SE_fire_clip.json")
var spr := $Unit as AnimatedSprite2D
spr.sprite_frames = sf
spr.centered = false
spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
spr.animation_changed.connect(func(): spr.offset = -anchors[spr.animation])
spr.play(&"idle_SE")   # node position = the tile's ground point (bottom vertex of the 64×32 diamond)
```

Notes:
- `offset = -anchor` puts the anchor pixel's top-left on the node origin, the same as Lattice's
  `tileX + 32 − anchor.x`, `tileY + 31 − anchor.y` placement (tile bitmap top-left = tileX, tileY).
- For multi-tile buildings, put the node on the bottom vertex of the **last** footprint cell.
- Overlays use the same offset with normal blending, on a sibling sprite drawn above.
- One-shots (`loop:false`) emit `animation_finished`. Chain `death → wreck` (`endsOn`) and the hero
  `death_a → b → c` (`next`) there.
- Import PNGs with filter **Nearest**, no mipmaps, and compression Lossless.

---

## 8. Inconsistencies (summary)

1. **`frameMs`** is missing in 51/65 library_anims clips and in all samples. Use `1000/fps`.
2. **`dirs`** is `null`, `[label]`, the integer `8`, or missing. Ignore it.
3. **`pivot`** is `[x,y]` in library_anims (ground anchor for artillery, rotation centre for dish spins) and
   `{x,y}` in dirs-rows samples.
4. **Overlay flag:** `overlayOf`/`overlayClip` plus a `*_overlay` kind (building_life, props, gold_vehicles),
   versus `overlay:true` and `damage_overlay` with no `overlayOf` (gold_vehicles_damage).
5. **Attack kind:** `attack` (gold_vehicles) vs `aim_fire` (library_anims, samples). Several pack kinds aren't in
   Lattice's `CLIP_KINDS`.
6. **Background:** building_life full clips are opaque (near-black bg). Every other full clip is transparent.
   interior_props full clips keep soft source alpha.
7. **`tickSequence`** is null or missing even when `holds` is set (hero clips). Lattice's Packs preview and clip
   re-import ignore holds.
8. **Emitter point shapes** vary: `[x,y]`, `{x,y}`, and `{frame,x,y}`.
9. **No machine-readable impact frame.** Use the per-pack fields in §3.
10. `animations/game_ready/demo_stage_combo_veil_E` is a demo with no rects and a strip that doesn't match
    `cell×frames`. Skip it.
11. `40_packs.js` `LATTICE_PACKS` lists `animations/map_ambient/map_fx/`, `animations/gore/` and
    `animations/combat/shots/`. On the box those clips live under `samples/` instead, so those entries show as
    "not reachable" unless the folders exist in the shipped tree.
