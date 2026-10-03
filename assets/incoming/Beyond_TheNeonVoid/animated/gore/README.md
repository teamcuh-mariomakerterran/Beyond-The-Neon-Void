# Gore pack

Blood / oil / xeno fluid FX for Black Doctrine combat. Group **Gore**.

- **Cell:** 96×96 generation pad (units are 84×84).
- **Spray dirs:** compass travel direction the spray flies (E/NE/N/NW/W/SW/S/SE). Not Forge DIR_ORDER.
- **Pool anchor:** `[48, 78]` = feet/ground center of an 84×84 unit centered in the 96 pad.
- **Fluids:** `blood` (full bake), `oil` / `xeno` (spray E, pool medium, one decal).

| id | gen | frames | fps | loop | notes |
|----|-----|--------|-----|------|-------|
| blood_spray_hit_{E..SE} | fx.blood_spray_hit | 8 | 12 | false | 8 compass dirs |
| blood_mist_headshot | fx.blood_mist_headshot | 8 | 12 | false | fine mist |
| gib_splatter_{A,B,C} | fx.gib_splatter | 10 | 12 | false | 3 variants |
| blood_pool_spread_{small,medium,large} | fx.blood_pool_spread | 12 | 10 | false | + final-frame decal |
| blood_splat_{drop,smear,spatter_ring,drag_trail,cluster,splash} | fx.blood_splat_decal | 1 | 1 | false | static decals |
| bleed_drip | fx.bleed_drip | 8 | 10 | true | wounded loop |
| oil_* / xeno_* | (same gens, fluid=) | — | — | — | subset variants |

Baker: `scripts/bake_gore.py`. Generators: `src/js/27_gore.js`.
