# God Tiles — keeper floor textures

Canonical home for Brian-approved floor/terrain stamps (not structure art).

```
god_tiles/
  battle_map_textures/     # battle map floor keepers (from tile app / 07 cull)
  hub_floor_textures/
    outdoor/
      street/
      sidewalk/
      _unsorted/           # drop here first, sort later
    indoor/
      lab/
      store_vendor/
      warehouse_industrial/
      _unsorted/
```

**Workflow**
1. Drop cleaned PNG keepers into the matching folder (or `_unsorted`).
2. Indexing app (coming) will label / key / place leftovers.
3. Map Forge + suite should read from here once wired (after your hand sort).

**Related**
- Structure art → `public/assets/all_structures/`
- Legacy battle pack keepers still in `battle_pack/07_god_tiles/` until you finish migrating into `battle_map_textures/`.
- Floors in Interiors lab may later point at `hub_floor_textures/indoor/…`.
