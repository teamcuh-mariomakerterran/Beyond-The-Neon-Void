# World map research: FF8 / FF9 feel for a huge fixed-iso overworld

Status: research + recommendations (not built). Read alongside
`docs/design/WORLD_FORMAT.md`, `src/world/world_renderer.gd`, `src/world/explore_scene.gd`.

---

## 1. What made the FF8 / FF9 world maps work

**One continuous, wrapping planet.** FF1 through FF9 wrap the overworld in both directions. Leave by the east edge and you come back in from the west; the same goes for north and south. That makes the world a torus, not a sphere, and players almost never notice. It's done because wrapping coordinates is trivial and spherical maths isn't worth it ([mscroggs](https://www.mscroggs.co.uk/blog/tags/games/start/10), [Tropedia](https://tropedia.fandom.com/wiki/Video_Game_Geography)). FF8's decompiled camera keeps coordinates inside ±64 × ±48 cells relative to the camera, so the loop is seamless ([ff8-decomp, DeepWiki](https://deepwiki.com/roengstrom/ff8-decomp/5.1-world-map-data-model-and-camera-system)). "Sailing around the world" works because the world has no edges.

**Chunked and streamed, with a sea fallback.** FF8's world is a grid of 32 × 24 *segments*, each holding 4 × 4 *blocks* (128 × 96 blocks in total). Every segment is a fixed 0x9000-byte record, and segments stream in around the camera. Each terrain triangle carries a **ground type**, and collision comes straight from those faces. Segments 769–835 are **story variants** (for example Balamb Garden's empty crater, or the map without Esthar) that get swapped in by story state. If a segment can't load in time, for example while the Ragnarok turns during landing, the engine draws a **fallback water block** in its place ([FF8 Modding wiki – wmx](https://hobbitdur.github.io/FF8ModdingWiki/technical-reference/worldmap/worldmap-wmx-file-format/), [wmsetxx](https://hobbitdur.github.io/FF8ModdingWiki/technical-reference/worldmap/worldmap-wmsetxx-file-format/), [Qhimm thread](https://forums.qhimm.com/index.php?topic=15979.0)). Most of the world is ocean, so most of it is cheap to draw.

**Encounters = region × terrain.** FF8 has a coarse 32 × 24 **region grid**, one byte per segment, and a table that maps `(region_id, ground_id)` to an encounter group. Each group holds **4 common, 2 medium and 2 rare** formations. Group flags mark roads and railways as *no encounters* and forests as a special class. There's even a second table that takes over after a story event (Lunar Cry) ([wmsetxx](https://hobbitdur.github.io/FF8ModdingWiki/technical-reference/worldmap/worldmap-wmsetxx-file-format/)). A danger counter climbs at a different rate per ground type. Vehicles and roads avoid fights. After you get out of a car or off a chocobo there are grace steps (the check counter is set to 226) ([Wikipedia: Random encounter](https://en.wikipedia.org/wiki/Random_encounter), [FF Wiki: Enc-None](https://finalfantasy.fandom.com/wiki/Enc-None_(Final_Fantasy_VIII))). FF9 also picks formations by terrain, so a forest can have enemies the plains don't. FF9 additionally has a few rare special encounters (Ragtimer, forest only) ([FF Wiki: Random encounter](https://finalfantasy.fandom.com/wiki/Random_encounter)).

**Mobility is the progression curve.** FF8 moves you on foot, then by rental car and train, then on the mobile Balamb Garden, then by chocobo, and finally on the Ragnarok, which can go almost anywhere ([FF8 world map overview](https://licm.mcgill.ca/Download_PDFS/G-pSVB/446205/Final%20Fantasy%20Viii%20World%20Map.pdf), [jegged](https://jegged.com/Games/Final-Fantasy-VIII/Walkthrough/Disc-4/36-Endgame-Side-Quests.html)). FF9 layers the gating on terrain rules:
- The **Blue Narciss** boat can only drop you off on beaches and shallows.
- **Hilda Garde III** can only land on grass.
- Early airships need the Mist to fly.
- **Choco** gains terrain abilities over the game: reef/shallows, then mountains, then ocean, then sky.
- Hidden treasure sits in mountain cracks and ocean dive spots, which only the matching ability reaches ([jegged](https://jegged.com/Games/Final-Fantasy-IX/Walkthrough/Disc-3/36-Lindblum-and-Hilda-Garde-III.html), [RPG Site chocobo guide](https://www.rpgsite.net/feature/10877-final-fantasy-ix-chocobo-guide-hot-cold-abilities-colors-and-how-to-reach-lagoon-air-garden-paradise), [jegged Hot & Cold](https://jegged.com/Games/Final-Fantasy-IX/Side-Quests/Chocobo-Hot-and-Cold.html)).

Each new vehicle reopens places you've already seen.

**Hidden spots everywhere.** Both games put things in the world that the main path never points at:
- Chocobo forests and chocobo footprints, where you summon a chocobo with Gysahl Greens.
- Bubbling sea spots and mountain cracks.
- Shadow circles on the ground that mark the flying Chocobo's Air Garden.
- Optional islands with no encounter-free terrain (FF8's Island Closest to Heaven/Hell, flagged 128 in the tables).

These give a huge, mostly empty world a reason to be explored ([FF Wiki: World map](https://finalfantasy.fandom.com/wiki/World_map), [wmsetxx](https://hobbitdur.github.io/FF8ModdingWiki/technical-reference/worldmap/worldmap-wmsetxx-file-format/)).

**Map UI and location reveal.** FF9 has a navigation map you toggle with SELECT, and it's needed because the 3D world is disorienting ([FF9 manual](https://docslib.org/doc/5842057/final-fantasy-ix-to-the-fullest-sort-of-like-a-mini-strategy-guide)). Place names come from the "World Map" key item, which starts as a *Continental Map* and later becomes the ancient full map of Gaia. On the airship you pick a dot on the map and it **autopilots** there ([Game8](https://game8.co/games/Final-Fantasy-IX/archives/280771), [FF Wiki: World map](https://finalfantasy.fandom.com/wiki/World_map), [gamerguides](https://www.gamerguides.com/final-fantasy-ix/guide/walkthrough/disc-3/side-questing-3)). FF8 draws its mini/full map HUD as a gradient panel that slides in ([ff8-decomp rendering](https://deepwiki.com/roengstrom/ff8-decomp/5.2-world-map-rendering:-particles-vram-and-color-zones)).

**Atmosphere is regional.** FF8 blends lighting and colour between **colour zones** depending on where you stand. It applies depth-cue fog to distant geometry and draws a star field at night ([ff8-decomp rendering](https://deepwiki.com/roengstrom/ff8-decomp/5.2-world-map-rendering:-particles-vram-and-color-zones)). The geometry rolls away toward the horizon, so tall landmarks (Gardens, Lunatic Pandora, the Iifa Tree) show up long before you reach them. "Horizon bending" is the standard name for this trick: deform a flat world so it reads as a sphere, which also caps how far you can see ([Kubisch & Abrahamsen 2009](https://exa.ai/library/publication/jwz8bngt2xc), [Godot curved-world notes](https://godotforums.org/d/18391-curved-world-shader-code-included)). Music changes with how you travel: the airship gets its own theme ("Ride On", "Aboard the Hilda Garde"), and the chocobo has its theme ([FF Wiki: Airship theme](https://finalfantasy.fandom.com/wiki/Airship_theme)).

**How other 2D and iso games handle overworlds:**
- **Sea of Stars** uses a fixed-iso, scaled-down overworld (a miniature) that links to detailed areas at full scale. This is the closest analogue to our world → hub → interior chain ([HandWiki](https://handwiki.org/wiki/Software:Sea_of_Stars)).
- **Chained Echoes** has no random encounters. Every enemy is visible, and fights happen in place ([Cliqist](https://cliqist.com/2019/02/22/kickstarter-game-of-the-week-chained-echoes/)).
- **Octopath** labels each region with a **danger level** that rises toward the edges of the map, and fast travel only goes to towns and ports ([Shacknews](https://shacknews.com/article/106090/what-are-danger-levels-in-octopath-traveler), [Attack of the Fanboy](https://attackofthefanboy.com/guides/where-and-how-to-fast-travel-in-octopath-traveler-2/)).
- **Triangle Strategy** skips free roaming entirely and uses a world map of story nodes ([Nintendo](https://www.nintendo.com/us/whatsnew/get-insight-and-tips-for-triangle-strategy-from-the-devs-themselves/)).
- FFT itself works the same way: a node map, with random battles only at certain nodes.

---

## 2. Recommendations for Beyond: The Neon Void

**The blocker today.** `WorldRenderer.rebuild()` makes one `ColumnView` node for every painted cell. A 512 × 512 map would need up to 262k nodes, which can't work. The 60 000 px background `ColorRect` in `explore_scene.gd` is also smaller than the map would be: a 512 × 512 map is about 65k px wide at 128 px tiles. Everything below assumes **chunks become the unit of rendering, loading and painting**.

### 2.1 Wrapping: yes, on both axes, as a per-map option
- Add `"wrap": "none" | "x" | "xy"`, with `xy` as the default for `kind: "world"`. On a fixed iso view the grid axes run diagonally across the screen, so wrapping only one axis leaves a visible diagonal edge. Wrapping both (the FF torus) has no edge anywhere.
- **How to implement it:** store the logical cell as `posmod(cell, size)`. Keep the avatar and camera in *unwrapped* coordinates and draw each chunk at `chunk_origin + k·world_size`, picking the copy nearest the camera. When the avatar gets more than half the world away from the origin, shift the origin back (a floating origin) so float precision stays bounded.
- Neighbour lookups (`can_step`, encounters, A* click-to-walk) must use `posmod`. The painter needs a toggle that shows the wrap seam.

### 2.2 Chunk streaming (512 × 512 cells, 32 × 32 chunks → 16 × 16 = 256 chunks)
- **Files:** `data/maps/<id>.json` becomes a *manifest* holding header, objects index, locations, zones and regions. Tiles move to `data/maps/<id>/chunks/<cx>_<cy>.json`, using the same `"x,y" -> stack` format with *local* coordinates. The painter saves only chunks it has changed. A chunk made entirely of default ocean has **no file**.
- **Ocean fill:** borrow FF8's sea fallback. A missing cell, or a missing chunk, renders as the map's `default_tile`, an animated deep-ocean tile. Draw it as one large repeating shader quad under everything else rather than one tile per cell. This alone removes most of the cells from a mostly-water planet.
- **Rendering per chunk:**
  - Draw the ground stacks into **one** `ChunkView` CanvasItem in draw order, with one `_draw` per chunk instead of one per cell. Optionally bake static chunks into a texture.
  - Animated tiles (rivers, shallows) use a `canvas_item` shader that picks the frame with `TIME`, so the chunk never needs a redraw.
  - Anything tall (structures, location objects, vehicles, the avatar) stays a y-sorted sprite on a shared layer, so the avatar can walk behind it.
- **Streaming policy:**
  - Keep the 3 × 3 chunks around the camera live, plus a ring of 5 × 5 that is prefetched on `WorkerThreadPool` (parse JSON off the main thread, build nodes on it).
  - Free chunks that drift outside a 7 × 7 ring.
  - Airship mode zooms out (about 0.35×), so its live radius grows to 5 × 5.
- **Story variants:** follow FF8's segments 769+. A chunk can list `variants`, for example `{ "flag": "kowloon_burned", "file": "12_9_burned.json" }`. The loader picks the variant whose story flag is set.
- **Overview image:** bake `overview.png` at 1 px per cell, coloured by terrain, whenever a chunk is saved. Use it for the mini-map, the full map, fog-of-war masking, and distant-horizon silhouettes.

### 2.3 Horizon / curvature fake for a fixed iso camera
In an iso view, the top of the screen is "far". Three layers, from cheapest to fanciest:
1. **Roll-off shader (S).** Render the world into a `SubViewport` and post-process it, or use a `canvas_item` shader on the chunk layer with the camera position as a uniform. Push pixels down by `k·max(0, d)²`, where `d` is the distance above the screen centre, and squeeze them slightly sideways. The top band falls away like a planet edge.
2. **Haze and sky band (S).** Blend toward a per-region fog colour by screen Y, put a gradient sky behind the top band, and add stars at night. These are FF8-style colour zones taken from the `regions` layer.
3. **Far landmarks (M).** Objects flagged `landmark` are listed in the manifest. When a landmark sits outside the loaded chunks but inside `seen_from` chunks, draw its silhouette sprite. Place it at the edge of the horizon band in the right compass direction, faded and scaled by distance. This is what lets players spot a megatower or crashed orbital from far away.

In airship mode, raise the curvature `k` and zoom out. That reads as "climbing" without needing camera rotation.

### 2.4 Vehicle system
- **Vehicle = object kind** (`"kind": "vehicle"`) whose behaviour comes from a definition in `data/vehicles.json`.
- **Terrain rules by mode:**

  | Vehicle | Can move on | Can board / exit |
  |---|---|---|
  | Submarine | `ocean`, `shallows` | Only at a `dock` object, or on `shallows` next to land (like the Blue Narciss) |
  | Land vehicle | `road`, `plains`, `sand` | Anywhere it can move |
  | Air vehicle | Anything | Only on terrain listed in `land_on` (like Hilda Garde's grass-only rule) |

- **Terrains need to be more specific:** `ocean` (deep), `shallows`, `reef`, `road`, `plains`, `mountain`, `forest`, `ruins`. Add `vehicle_tags` to `data/terrain.json` instead of hard-coding them.
- **Boarding and exiting:**
  - Press E next to a parked vehicle to board. The avatar sprite swaps for the vehicle sprite, and `can_step` switches to the vehicle's `move_on` list.
  - Exiting requires that the current cell is in `disembark_on` *and* that a walkable neighbour cell exists.
  - The vehicle stays parked on the map as an object with a saved cell and facing. Recall it with a "call" item, like summoning a chocobo with Greens.
- **Facings:** grid steps are ±x and ±y, which appear on screen as the four diagonals (NE, NW, SE, SW). Use the **diagonal frames of the 8-direction sheet** for grid movement. The cardinal frames are for turn-in-place blends and for a free-flying airship.
- **Submarine look:** the sprite is clipped at a waterline offset (`surface_y`) using a shader mask or a split sprite, with a wake particle preset. The **dive** toggle hides the sprite under a darker ripple. While dived there are no surface encounters, and the sub can reach dive spots with hidden loot (FF9 dive spots, FF8's Deep Sea Research Center).
- **Gating:**
  - A vehicle unlocks through a story flag.
  - Upgrades add terrains to `move_on`, the way FF9's Choco gains reef, mountain, ocean and sky abilities.
  - Each vehicle carries `encounter_mult`, `speed` (seconds per step) and `music`.

### 2.5 Encounters (tactics battles are long, so default to visible)
Random FF-style fights every few steps would hurt a game where each battle is a full tactics map. The recommended default is **visible roaming threats**: Chained Echoes and FF9's optional visible monsters. Two options are kept so the tuning can be decided later:
- **A. Visible (default).** Each active chunk spawns 0–N threat sprites picked from its zone's table. They wander within the zone. Touching one starts the battle mission, and the player can avoid them.
- **B. Classic random.** Use FF8's danger counter: each step adds the zone's `rate` × the terrain factor × the vehicle multiplier. Roads add zero. There are `grace_steps` after exiting a vehicle. Pick a formation from common/medium/rare weighted 4/2/2.

In both modes:
- **Zones are a painted layer**, sparse `"x,y" -> zone_id`, with a fallback zone per chunk. This is the equivalent of FF8's region grid crossed with ground type.
- Each zone carries a **danger level** (like Octopath) that the full map shows.
- Battle uses the zone's `battle_maps` list, falling back to a terrain-themed encounter map.

### 2.6 Landmarks, fog of war, map reveal, fast travel, music, day/night
- **Fog of war:** keep a revealed bitset per map, 512 × 512 bits (32 KB, saved compressed). It reveals a radius of about 6 cells around the player, 12 when flying. The mini-map is `overview.png` masked by that bitset. Locations still use the existing `discovered` flag and the "?" marker.
- **Map items:** like FF9's Continental → ancient map, a `map_item` can reveal a whole region's outline and names without exploring it.
- **Fast travel:** to discovered `transit` locations only (maglev stations, ports), the way Octopath limits it to towns and ports and FF8 used trains. Later the airship gets **autopilot** to any discovered dot on the full map, like FF9.
- **Music and atmosphere:** set per region (`regions` layer), and a vehicle's music overrides it. Crossfade on change. Day/night drives a `CanvasModulate` plus the region tint. At night the existing neon `rebuild_lighting()` pass lights up, which suits the cyberpunk setting. Weather particles can be set per region.

---

## 3. Data-format additions for `WORLD_FORMAT.md`

```jsonc
// data/maps/<id>.json  (manifest when "streaming" is present)
{
  "format": 3, "kind": "world", "width": 512, "depth": 512,
  "wrap": "xy",                                   // none | x | xy
  "streaming": {"chunk_size": 32, "dir": "data/maps/neon_expanse/chunks",
                "default_tile": "god_tiles/water/ocean_anim",
                "overview": "res://data/maps/neon_expanse/overview.png"},
  "chunks": {"12,9": {"variants": [{"flag": "kowloon_burned", "file": "12_9_burned.json"}]}},
  "regions": {"grid": 32, "cells": "base64 32x32 bytes",   // 16x16 cells per region tile
              "defs": {"1": {"name": "Rust Coast", "music": "res://audio/rust_coast.ogg",
                             "fog": "#2a1a3a", "tint_day": "#ffffff", "tint_night": "#6a5aff",
                             "weather": "neon_rain"}}},
  "encounter_zones": {"x,y": "zone_scrapyard"},  // sparse painted layer; chunk default below
  "zone_defaults": {"12,9": "zone_rust_shore"},
  "curvature": {"k": 0.00035, "k_air": 0.0009, "haze_start": 0.35}
}
// data/maps/<id>/chunks/<cx>_<cy>.json  — same stack format, local coords
{"chunk": [12, 9], "tiles": {"0,3": [[0, "god_tiles/sand/sand_01"]]}, "details": [], "particles": {}}
```

```jsonc
// objects[] additions
{"kind": "vehicle", "vehicle_id": "sub_nautilus", "cell": [40, 210], "facing": "se"},
{"kind": "location", "location": {"type": "dock", "vehicles": ["sub_nautilus"], "...": "..."}},
{"kind": "location", "location": {"type": "city", "transit": true, "...": "..."}},
{"kind": "structure", "landmark": {"seen_from": 4, "silhouette": "res://assets/landmarks/arcology_far.png"}},
{"kind": "trigger", "hidden": {"needs": "dive", "loot_item_id": "relic_core"}}   // dive spot / crack
```

```jsonc
// data/vehicles.json
{"sub_nautilus": {"name": "Nautilus", "frames": "res://assets/vehicles/sub_8dir.tres",
  "move_on": ["ocean", "shallows"], "board_on": ["dock", "shallows"], "disembark_on": ["dock", "shallows"],
  "dive": true, "surface_y": 0.45, "wake": "wake_small",
  "speed": 0.12, "encounter_mult": 0.5, "music": "res://audio/sub_theme.ogg",
  "unlock_flag": "got_nautilus", "upgrades": {"reef_drill": ["reef"]}},
 "hover_bike": {"move_on": ["road", "plains", "sand"], "disembark_on": ["road", "plains", "sand"], "speed": 0.08, "encounter_mult": 0.0},
 "skybarge":   {"move_on": ["*"], "land_on": ["plains", "road", "pad"], "free_move": true, "encounter_mult": 0.0, "zoom": 0.35}}

// data/terrain.json additions
"ocean": {"walkable": false, "vehicle_tags": ["ocean"]}, "shallows": {"walkable": false, "vehicle_tags": ["shallows"]},
"road":  {"move_cost": 1, "encounter_factor": 0.0}

// data/encounter_zones.json
{"zone_scrapyard": {"danger": 7, "mode": "visible", "max_threats": 3, "rate": 32, "grace_steps": 6,
  "common": ["scav_pack", "drone_swarm"], "medium": ["junk_golem"], "rare": ["rogue_mech"],
  "battle_maps": ["scrapyard_a", "scrapyard_b"], "night": {"common": ["ghoul_runners"]}}}
// save data: "world_reveal": {"neon_expanse": "zlib+base64 bitset"}, "vehicles": {"sub_nautilus": {"cell": [..], "facing": "se"}}
```

---

## 4. Phased build order

| # | Phase | Effort |
|---|---|---|
| 1 | `ChunkView` rendering: one CanvasItem per 32 × 32 chunk; tall stacks and objects y-sorted; animated tiles via shader `TIME` | **M** |
| 2 | Manifest + chunk files, async load/unload ring, ocean `default_tile` quad, migration script for existing maps | **M** |
| 3 | Painter support: chunk-dirty saves, overview.png bake, paint layers for `encounter_zones` and `regions` | **M** |
| 4 | Wrapping (`posmod` everywhere, chunk copies, floating origin, seam view in painter) | **M** |
| 5 | Mini-map + full map from overview, reveal bitset, `discovered` labels, map items | **S** |
| 6 | Horizon roll-off shader, haze/sky band, region fog/music crossfade, day/night modulate | **S** |
| 7 | Vehicle core: `vehicles.json`, board/exit, terrain rules, diagonal 8-dir facings, parked state in save | **M** |
| 8 | Submarine specifics: waterline clip, wake, dive toggle, docks, dive-spot loot | **S** |
| 9 | Encounter zones: visible threats (default) + optional danger-counter mode, 4/2/2 tables, mission hand-off | **M** |
| 10 | Far landmarks (silhouettes beyond loaded chunks), chunk story variants | **S** |
| 11 | Fast travel (transit locations) → airship free-move, zoom-out, autopilot to map dots | **L** |
| 12 | Land vehicle + upgrade-gated terrains, hidden spots (cracks, dive spots, "forests") | **S** |

Phases 1–2 must come first; everything else assumes chunks. Phases 5–6 give the biggest jump in "vastness" for the least work.
