# World format v2 — stacked tiles, details, particles, objects, links

Shared contract for the World Painter (Neon Forge), the renderer, battles and
overworld exploration. Maps written before v2 (flat `cells` + `h`) still load.

## Map file: `data/maps/<id>.json`

```jsonc
{
  "format": 2,
  "id": "rust_coast",              // unique, slug
  "name": "Rust Coast",
  "kind": "world",                 // world | city | hub | interior | encounter | event
  "tile_width": 128,               // screen px of a tile's top diamond (2:1)
  "tile_height": 64,
  "height_step": 32,               // screen px per stack layer
  "tiles": {                        // sparse: "x,y" -> stack, sorted by z ascending
    "3,4": [[0, "god_tiles/mountain/mountain_03"], [1, "god_tiles/grass/grass_01"]],
    "3,5": [[-2, "god_tiles/stone/stone_02"]]      // below world ground level is fine
  },
  "details": [                      // decals: sit ON a tile, never replace it; free-positioned
    {"id": "d1", "asset": "res://assets/details/crater_01.png", "pos": [3.4, 4.6], "z": 1,
     "scale": 1.0, "rot": 0.0, "flip": false, "tint": "#ffffff",
     "anim": {"frames": [], "hframes": 1, "vframes": 1, "fps": 8, "mode": "loop"}}
  ],
  "particles": {                    // painted like tiles: "x,y" -> [[z, preset_id], ...]
    "3,4": [[3, "fog"], [15, "storm_clouds"]]
  },
  "objects": [                      // props, structures, characters, locations
    {"id": "obj_rust_coast_1", "asset": "res://assets/structures/27_neon_bar.png",
     "cell": [5, 6], "z": 1, "offset": [0, 0], "scale": 1.0, "flip": false,
     "layer": 0,                    // manual draw-order bias inside the same cell
     "kind": "prop",                // prop | structure | character | location | loot | trigger
     "anim": null,                  // or the same anim dict as details
     "loot_item_id": "", "found_text": "", "empty_text": "",   // FF8/9 hidden loot
     "dialog_npc": "",              // NPC id → talk on confirm
     "character_id": "", "team": "neutral",                    // kind = character
     "location": null}              // see below
  ],
  "spawns": {"player": [[x, y], ...], "enemy": []},
  "gameplay": {"x,y": {"walkable": false, "cover": 2, "blocks_los": true}},  // overrides
  "props": []                       // legacy v1 hidden-loot props (still read)
}
```

### Locations (world map ↔ hub ↔ interior)
An object with `"kind": "location"` carries:
```jsonc
"location": {
  "type": "city",                 // city | poi | hub | building | event
  "name": "Neo Kowloon Sprawl",
  "target_map": "neo_kowloon_hub",// map id entered on confirm
  "target_spawn": 0,              // index into target map's spawns.player
  "intro_cutscene": "res://data/cutscenes/neo_kowloon_arrival.parallax.json", // first visit
  "discovered": false,            // false → "?" shown above until first visit
  "radius": 1.5                   // cells: how close the player must be for the label
}
```
Order of travel: **world** (cities, POIs) → **hub** (districts, inner POIs) →
**interior** (buildings) / **event** sets. Battles are their own trigger
(missions). A world-map location plays its intro cutscene on first visit;
inner levels only if `intro_cutscene` is set.

## Tile index: `data/tiles.json`
Built by scanning `assets/tiles/**` (the Forge rescans on demand); the id is the
path under `assets/tiles` without extension.
```jsonc
{
  "god_tiles/water/ocean_anim": {
    "texture": "res://assets/tiles/god_tiles/water/ocean_anim_1.png",
    "frames": ["...ocean_anim_1.png", "..._2.png", "..._3.png", "..._4.png"], // animated if >1
    "fps": 6,
    "group": "god_tiles/water",    // palette section = sub folder
    "terrain": "water",            // gameplay rules from data/terrain.json
    "fit": {"top": 0, "width": 0}  // auto-fit override in source px, 0 = auto-detect
  }
}
```
**Auto-fit:** the renderer finds each image's opaque bounding box, scales it so
the opaque width equals `tile_width`, and pins the opaque top to the diamond's
north point. Slightly-off art snaps to the world angle without edits.

**Animated sequences:** files whose names differ only by a trailing number
(`ocean_1…4`, `river_a_f1…f4`, `water-anim-01…04`) collapse into one tile with
`frames`. Same rule for details (river overlays).

## Particle presets: `data/particles.json`
`id -> {name, kind (rain|storm_clouds|fog|snow|embers|sparks|dust|smoke|ash|steam|neon_rain|custom), color, amount, speed, size, ...}`.
Painted per cell + stack layer; the renderer merges neighbouring cells of the
same preset/layer into one emitter.

## Assets index: `data/asset_index.json`
Filled by the drag-and-drop intake wizard: `id -> {path, type, name, role, ...}`.
