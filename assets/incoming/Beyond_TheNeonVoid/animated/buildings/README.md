# building_life — ambient idle loops for battle-map buildings (v2)

**150 buildings / 300 clips** (14 unchanged from v1, 11 weak-spot fixes incl. 1 padded variant, 125 new in v2).

Subtle, seamless idle loops for Black Doctrine battle-map buildings, made only from each building's **own painted lit spots** (bright + saturated pixels, contrast-checked against the surrounding body) plus added FX (dish pings, steam/smoke, beacons, landing-light chases, screen scanlines, glass sweeps, star glints). The building body is never recoloured.

* 24 frames @ 100 ms (10 fps), loop = 2.4 s, seamless (every effect has a period that divides 24).
* Every clip keeps the **exact canvas size** of the source sprite; `anchor` = bottom-centre of the building footprint `[cx, bottom]`, `depthKey: share_base`.
  Exception: `bl_026_03_padded` adds 40 px of the art's own background on top (`padding.top=40`, `anchorInSourceCanvas` recorded; exact-canvas `bl_026_03` also ships).
* Two clips per building: `bl_<id>` (full drop-in frames) and `bl_<id>_overlay` (FX only, hard alpha; overlay-over-static == full frame, verified for every frame of every v2 clip).
* Emitter points live in each clip JSON under `emitters` (beacons, pointLights, windows; neon/core bboxes; vents; pings; screens; glints; addedBeacons; padTop).
* **Phase variety:** every v2 clip seeds its phases from a CRC of its id (`phaseSeed` in the clip JSON), so neighbouring buildings never pulse in sync.
* Each clip JSON carries `qaGrade` and `qaNote`; PACK.json entries carry `qaGrade` and `batch` (`v2_fix` / `v2_new`; v1 entries have none).

## v2 weak-spot fixes (replaced in place, same ids; v1 copies kept in `_backup_building_life_v1_20261001` at the handoff root, outside animations/)

| clip | grade (v1 -> v2) | fix |
|---|---|---|
| `bl_030_03` | B -> B+ | 3 dish pings, bigger/brighter 3-arc pings + window/beacon blink |
| `bl_021_03` | B -> B+ | 3 dish pings (bigger/brighter) + neon/doorway pulse |
| `bl_017_02` | B -> B+ | dish ping (bigger/brighter) + tower neon ring pulse |
| `bl_011_05` | A- -> A- | dish ping (bigger/brighter) + orange/cyan ring pulse |
| `bl_036_06` | B -> B+ | 4 fuller cyan-tinted soft steam plumes (12-puff, dithered edge) + cyan band pulse |
| `bl_020_04` | C+ -> B | cab scanner sweep (3px) + 4 helipad amber landing-light chases + tower beacons |
| `bl_026_03` | C -> B | exact canvas: tall-stack smoke bends sideways under the canvas top (no clipping) + chimney smoke + band pulse |
| `bl_026_03_padded` | new -> B+ | padded +40px top: tall-stack smoke rises freely; anchor offset recorded |
| `bl_025_14` | C+ -> B | slanted scanline bands following each screen face (parallelogram, 0.5 slope) + sign blink |
| `bl_004_02` | B -> B+ | lit-glass specular band sweeps each dome once per loop + subtle glow pulse |
| `bl_028_02` | skipped -> B | overlay-only star glints on awning tips/sign corners + sign flicker; body untouched |

## v2 new buildings (125): grades A- 15, B+ 48, B 62

| clip | grade | what moves / look |
|---|---|---|
| `bl_009_07` | A- | dark drum tower, cyan/magenta ring bands (dim-neon mode) |
| `bl_017_07` | A- | dark tower block, cyan/magenta window grid |
| `bl_017_11` | A- | dark cluster, magenta/cyan window grid |
| `bl_017_12` | A- | dark block, banded cyan/magenta strips |
| `bl_019_03` | A- | amber + cyan window towers |
| `bl_019_05` | A- | dark block cluster, amber + cyan windows |
| `bl_020_06` | A- | dark city block, amber window strips |
| `bl_021_05` | A- | dark tower cluster, magenta/cyan window grid |
| `bl_021_08` | A- | spire hub, cyan cab + magenta core, pad lights |
| `bl_021_09` | A- | inverted dark tower, magenta/cyan bands |
| `bl_021_10` | A- | dark twin towers + skybridge, magenta/cyan windows |
| `bl_021_12` | A- | dark depot, cyan trim and magenta panels |
| `bl_021_13` | A- | dark tower, magenta/cyan neon frames and window strips |
| `bl_022_11` | A- | dark tower cluster, cyan/magenta windows |
| `bl_025_15` | A- | twin cyan-ringed silos, magenta window rows, dish tops |
| `bl_001_08` | B+ | dark twin block, cyan sign + strips (dim-neon) |
| `bl_002_05` | B+ | dark market grid, magenta lit stalls (dim-neon) |
| `bl_009_02` | B+ | twin dark towers, cyan and magenta window grids |
| `bl_009_03` | B+ | dark block with dishes, cyan bands (dim-neon) |
| `bl_009_05` | B+ | dark stepped block, cyan/magenta bands (dim-neon) |
| `bl_009_08` | B+ | dark stacked tower, cyan edge strips |
| `bl_009_09` | B+ | dark twin block, magenta sign + cyan strips (dim-neon) |
| `bl_017_03` | B+ | dark cluster, magenta/cyan windows |
| `bl_017_04` | B+ | dark long hall, magenta/cyan bands + lit door (dim-neon) |
| `bl_017_05` | B+ | dark stepped tower, magenta/cyan windows (dim-neon) |
| `bl_017_06` | B+ | dark tower, cyan/magenta window grid |
| `bl_017_08` | B+ | dark stepped block, cyan/magenta window grid (dim-neon) |
| `bl_017_09` | B+ | dark cross tower, cyan/magenta strips |
| `bl_017_10` | B+ | dark block, cyan/magenta frame strips |
| `bl_018_01` | B+ | dark tower block ring, cyan/magenta windows (dim-neon) |
| `bl_018_07` | B+ | dark ziggurat, cyan/magenta terraces |
| `bl_019_02` | B+ | dark tower, amber/cyan windows + lit door |
| `bl_019_09` | B+ | dark cluster, amber + cyan windows |
| `bl_019_10` | B+ | dark block, amber window bands + cyan corners |
| `bl_019_11` | B+ | pad hub, amber tower bands |
| `bl_020_01` | B+ | dark pyramid, cyan + amber terraces |
| `bl_020_02` | B+ | command hub variant, pad rings + cab |
| `bl_021_01` | B+ | slim dark tower, magenta window column |
| `bl_021_02` | B+ | dark block, cyan windows + magenta frame |
| `bl_021_04` | B+ | dark stepped pyramid, cyan terraces |
| `bl_021_06` | B+ | dark obelisk, magenta/cyan strips |
| `bl_021_07` | B+ | dark cross tower, cyan strips + emblem |
| `bl_021_15` | B+ | roof-garden terraces, cyan trim |
| `bl_021_16` | B+ | twin silo hub, cyan rings + pad lights |
| `bl_022_01` | B+ | dark triple tower, magenta/cyan frames |
| `bl_022_02` | B+ | dark complex, magenta/cyan signage |
| `bl_022_03` | B+ | dark plant, cyan pipe trim + magenta vats |
| `bl_022_04` | B+ | neon compound, cyan/magenta signs |
| `bl_022_05` | B+ | dark cluster, cyan/magenta windows |
| `bl_022_09` | B+ | garden ziggurat, magenta/cyan windows (dim-neon) |
| `bl_022_10` | B+ | dark citadel, cyan trim |
| `bl_022_12` | B+ | cross complex, cyan runway strips |
| `bl_025_05` | B+ | dark tower cluster, cyan/magenta strips |
| `bl_025_07` | B+ | dark drum tower, magenta/cyan rings |
| `bl_025_08` | B+ | inverted dark tower, cyan/magenta bands (dim-neon) |
| `bl_025_10` | B+ | dark stepped tower, cyan strips (dim-neon) |
| `bl_027_01` | B+ | dark tower over magenta-lit annex, cyan base glow (dim-neon) |
| `bl_027_09` | B+ | dark block, magenta windows + cyan frame + sign |
| `bl_035_03` | B+ | two-tone block, amber window grid + vertical sign |
| `bl_036_01` | B+ | dark triple tower, magenta/cyan window grid |
| `bl_036_04` | B+ | dark courtyard block, magenta/amber plaza lights + billboard (dim-neon) |
| `bl_036_07` | B+ | dark pad complex, cyan/magenta trim + tower (dim-neon) |
| `bl_036_09` | B+ | dark circuit pyramid, magenta trace lines (dim-neon) |
| `bl_001_01` | B | dark twin block, cyan/magenta strips (dim-neon) |
| `bl_001_02` | B | dark twin block, magenta strips (dim-neon) |
| `bl_001_03` | B | dark twin block, magenta strips (dim-neon) |
| `bl_001_04` | B | dark factory with stacks, magenta strips (dim-neon) |
| `bl_001_05` | B | dark twin block, magenta sign (dim-neon) |
| `bl_001_06` | B | dark twin block, magenta strips (dim-neon) |
| `bl_001_07` | B | dark twin block, magenta strips (dim-neon) |
| `bl_001_09` | B | dark twin tower + bridge, magenta sign (dim-neon) |
| `bl_001_10` | B | dark twin block, magenta sign (dim-neon) |
| `bl_001_11` | B | dark twin block, magenta strips (dim-neon) |
| `bl_001_12` | B | dark twin block, cyan sign + magenta strips (dim-neon) |
| `bl_003_07` | B | dark tower, orange sign + cyan strips |
| `bl_009_01` | B | dark twin block, cyan strips (dim-neon) |
| `bl_009_04` | B | dark tower pair, magenta/cyan strips (dim-neon) |
| `bl_009_06` | B | dark long block with dishes, cyan bands (dim-neon) |
| `bl_011_03` | B | dark twin block, magenta/cyan strips (dim-neon) |
| `bl_011_04` | B | dark block, cyan light bands |
| `bl_017_01` | B | needle tower, cyan stripes (thin at 1x) |
| `bl_018_02` | B | dark pad hub, cyan cab + pad glyphs (dim-neon) |
| `bl_018_03` | B | dark tower over magenta-lit base (dim-neon) |
| `bl_018_04` | B | dark pad hub, cyan cab + magenta trim (dim-neon) |
| `bl_018_05` | B | dark arch gate, magenta window strips + cyan beacon tops (dim-neon) |
| `bl_019_06` | B | light cross-wings, cyan strips |
| `bl_019_08` | B | orange-framed block, cyan strips + sign |
| `bl_020_05` | B | dark ziggurat hub, amber/cyan lights |
| `bl_020_07` | B | orange cross-arm tower, cyan strips + emblem |
| `bl_020_08` | B | dark compound, amber windows + cyan orbs |
| `bl_023_01` | B | light triple tower, amber window strips |
| `bl_024_02` | B | light office, orange window flicker + cyan edge |
| `bl_024_09` | B | inverted tower, cyan band glints |
| `bl_025_01` | B | dark slab tower, magenta/cyan strips |
| `bl_025_02` | B | dark office block, cyan/magenta window flicker |
| `bl_025_03` | B | dark tower, magenta sign + cyan windows |
| `bl_025_04` | B | dark ziggurat, cyan edge trim (dim-neon) |
| `bl_025_09` | B | dark twin towers + bridge, magenta/cyan strips |
| `bl_025_11` | B | dark twin block, magenta sign + cyan strips (dim-neon) |
| `bl_025_13` | B | dark twin block, cyan/magenta strips (dim-neon) |
| `bl_026_01` | B | white twin towers, cyan window strips |
| `bl_026_02` | B | light plant, lit window strips (some pipe trim) |
| `bl_026_04` | B | light courtyard compound, amber windows |
| `bl_026_05` | B | tower cluster, lit window slots |
| `bl_026_09` | B | hab pyramid, amber window slots |
| `bl_027_02` | B | dark twin block, magenta strips (dim-neon) |
| `bl_027_03` | B | dark twin block, magenta/cyan strips + base glow (dim-neon) |
| `bl_027_04` | B | dark twin block, magenta strips + cyan base glow (dim-neon) |
| `bl_027_05` | B | dark needle, cyan base glow + strips |
| `bl_027_06` | B | dark twin block, magenta strips + cyan base glow (dim-neon) |
| `bl_027_07` | B | dark twin block, magenta sign + cyan base glow (dim-neon) |
| `bl_027_08` | B | dark tower cluster, magenta windows + cyan base glow (dim-neon) |
| `bl_028_03` | B | dark low blocks, magenta doors + cyan trim (dim-neon) |
| `bl_029_03` | B | white pillar cluster, orange/cyan trim lights |
| `bl_029_07` | B | light twin block, orange sign + cyan glazing |
| `bl_030_05` | B | tower over lit crate stalls, amber/cyan windows |
| `bl_035_02` | B | white tower, cyan/orange strips |
| `bl_035_05` | B | white cluster, cyan light strips |
| `bl_035_07` | B | white tower, cyan stripes |
| `bl_035_09` | B | light wedge tower, lit window slots |
| `bl_035_10` | B | white block, orange sign + cyan glazing |
| `bl_035_16` | B | roof-garden blocks, cyan trim + lit doors |
| `bl_036_02` | B | dark compound, cyan/magenta trim |
| `bl_036_03` | B | dark plant with stacks, cyan/magenta trim (dim-neon) |
| `bl_036_05` | B | dark dish cluster, magenta/cyan strips (dim-neon) |

## Dropped in v2 (67, below B): B- 52, C+ 9, C 6

| source | grade | why |
|---|---|---|
| `bsheet_029_05_2.png` | B- | thin tan spire; few lit pixels, mostly body trim |
| `bsheet_035_06_2.png` | B- | thin light spire, tiny lit area |
| `bsheet_035_11_2.png` | B- | light body; few strips, mostly static |
| `bsheet_011_01_2.png` | B- | dark spire, faint orange trim only |
| `bsheet_024_03_2.png` | B- | tan outline trim touched (paint, not light) |
| `bsheet_026_11_2.png` | B- | light complex; sparse lit bits, reads mostly static |
| `bsheet_035_12_2.png` | B- | light tower; sparse, mostly static |
| `bsheet_035_14_2.png` | B- | light tower; sparse, mostly static |
| `bsheet_029_02_2.png` | B- | light twin block; sparse |
| `bsheet_035_15_2.png` | B- | light tower; sparse |
| `bsheet_029_04_2.png` | B- | light twin block; sparse |
| `bsheet_011_07_2.png` | B- | orange-plated body; lit strips weak against paint |
| `bsheet_035_04_2.png` | B- | tan stepped pyramid; after paint filter only sparse cyan windows |
| `bsheet_029_06_2.png` | B- | light twin tower; sparse |
| `bsheet_023_07_2.png` | B- | light citadel; few lit slots |
| `bsheet_003_05_2.png` | B- | light tower; sparse |
| `bsheet_011_02_2.png` | B- | orange-plated towers; sparse |
| `bsheet_030_02_2.png` | B- | light twin tower; sparse |
| `bsheet_024_16_2.png` | C+ | white cross tower; almost nothing lit |
| `bsheet_035_01_2.png` | B- | light spire; sparse |
| `bsheet_024_13_2.png` | B- | grey tower; sparse orange slots |
| `bsheet_003_08_2.png` | B- | light twin tower; sparse |
| `bsheet_030_01_2.png` | B- | light twin tower; sparse |
| `bsheet_029_01_2.png` | B- | light twin tower; sparse |
| `bsheet_026_07_2.png` | B- | grey depot; sparse |
| `bsheet_025_06_2.png` | B- | slim dark tower; very sparse at 1x |
| `bsheet_030_04_2.png` | B- | light tower complex; sparse |
| `bsheet_004_01_2.png` | B- | light tower cluster; sparse |
| `bsheet_023_05_2.png` | B- | white citadel; sparse |
| `bsheet_026_08_2.png` | C+ | stone fortress; almost nothing lit |
| `bsheet_003_06_2.png` | B- | light twin tower; sparse |
| `bsheet_012_05_2.png` | C | bronze stone grid; touched pixels are painted outline, not light |
| `bsheet_003_04_2.png` | B- | light twin block; sparse |
| `bsheet_012_06_2.png` | C+ | bronze bridge towers; mostly painted outline touched |
| `bsheet_030_06_2.png` | B- | stone fortress with panels; orange base trim mostly paint |
| `bsheet_003_02_2.png` | B- | two-tone twin tower; sparse |
| `bsheet_012_04_2.png` | C | stone castle; touched pixels are painted gold trim |
| `bsheet_002_01_2.png` | B- | dark spire cluster; sparse at 1x |
| `bsheet_002_03_2.png` | B- | dark low compound; sparse |
| `bsheet_002_06_2.png` | B- | very dark cluster; scattered specks |
| `bsheet_022_08_2.png` | B- | dark cathedral; dome lattice touched reads as texture noise |
| `bsheet_002_02_2.png` | B- | dark dome cluster; sparse |
| `bsheet_004_04_2.png` | B- | dark compound, faint orange slots |
| `bsheet_003_03_2.png` | B- | light factory; lights sparse (stack smoke would be needed) |
| `bsheet_028_01_2.png` | B- | dark twin block; sparse |
| `bsheet_010_04_2.png` | B- | very dark citadel; specks only |
| `bsheet_010_02_2.png` | B- | very dark citadel; magenta specks only |
| `bsheet_028_05_2.png` | B- | dark tower cluster; sparse specks |
| `bsheet_010_05_2.png` | B- | dark bridge; faint cable glints |
| `bsheet_012_02_2.png` | B- | bronze ziggurat; sparse slots |
| `bsheet_011_06_2.png` | B- | orange-banded tower; orange is paint, only a few cyan slots move |
| `bsheet_012_03_2.png` | B- | bronze courtyard fort; sparse |
| `bsheet_002_04_2.png` | B- | dark tower block; sparse magenta |
| `bsheet_004_03_2.png` | B- | grey compound; sparse slots |
| `bsheet_012_01_2.png` | C+ | star fort; orange arms are painted trim |
| `bsheet_028_04_2.png` | B- | dark tower cluster; sparse magenta |
| `bsheet_036_08_2.png` | B- | dark fortress, cyan slits; faint |
| `bsheet_028_06_2.png` | B- | dark dish block; sparse |
| `bsheet_010_01_2.png` | C+ | dark ziggurat; specks only |
| `bsheet_004_06_2.png` | C+ | bronze spires; nothing lit reads |
| `bsheet_004_05_2.png` | C | orange crate yard; orange is paint, nothing lit left after filter |
| `bsheet_023_02_2.png` | C+ | white/orange complex; orange is paint |
| `bsheet_019_07_2.png` | C+ | bronze spire; tiny base light only |
| `bsheet_020_03_2.png` | C+ | orange bridge; tiny lit hub only |
| `bsheet_010_03_2.png` | C | near-black ziggurat; nothing reads |
| `bsheet_010_06_2.png` | C | near-black star; nothing reads |
| `bsheet_hq_var_001_2.png` | C | HQ variant: no lit pixels detected |

## How v2 new buildings were made
* All 192 remaining unique battle buildings were auto-configured: emissive = bright + saturated pixels that out-shine the ring of body pixels around them; solid painted panels and
  warm body-hue trim (tan/orange plating) are excluded so painted walls never pulse. Dark neon art (89 buildings) got an adaptive threshold (`dimneon`: vmin from the 97th-percentile
  saturated brightness, clamped 0.30-0.45) and a stronger pulse so their lights register.
* Auto beacons (red/amber strobe, 1-2 px) were added at the top antenna tips.
* Every building was reviewed by eye (frame 0 / busiest frame / every-pixel-touched map, with zoom crops on borderline ones) and graded; B or better ships.

## Unchanged from v1

`bl_026_06` (B+), `bl_022_06` (B), `bl_023_03` (B-), `bl_003_01` (B+), `bl_025_12` (B+), `bl_021_14` (A-), `bl_035_13` (B+), `bl_019_01` (A-), `bl_022_07` (A-), `bl_024_01` (B+), `bl_018_06` (B), `bl_021_11` (B+), `bl_019_04` (B), `bl_035_08` (B+)


QA: `samples/ui/qa_building_life/bl_<id>.gif` (1x, global 256-colour palette so GIF colours band slightly; the PNG strips are exact), contact sheet `samples/ui/qa_building_life.png`,
map vignette `samples/ui/qa_building_life_vignette.gif` (12 animated buildings on 64x32 `tile_cyber_conduit` ground, game layout at 3x zoom: tile 192x96, building width = 1.06 x tile).

## Notes / limits
* In game the 1x1 buildings draw ~68 px wide (3-7x downscale), so single-pixel flicker averages out; the strongest reads at game size are steam, pings, pad chases, scanlines and big neon pulses.
* Source sprites are fully opaque with their own near-black background (~rgb 11,12,16). Full clips keep it; use the overlay clips if the engine needs the building on transparent.
* Only painted-lit pixels change (plus added FX); brightened lit pixels introduce new lighter/darker shades of existing lit colours only. No moving parts (single painted view).
* Exact canvas means smoke from stacks touching the top edge is shaped sideways (026_03) or needs the padded variant.
* Selection = the battle placement library; no map data names which buildings appear where.
* Source art is read-only; built from box copies of bd_battle_sorted.
