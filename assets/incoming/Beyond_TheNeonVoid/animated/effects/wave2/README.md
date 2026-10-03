# Effects wave 2

Procedural one-shot combat / status FX (muzzle, impact, shield, teleport, scrap, acid, ice, heal).

| id | Lattice gen | frames | fps | use |
|----|-------------|--------|-----|-----|
| `muzzle_flash` | `fx.muzzle_flash` | 8 | 12 | directional muzzle flash cone + sparks |
| `impact_hit` | `fx.impact_hit` | 10 | 12 | star burst impact hit one-shot |
| `shield_break` | `fx.shield_break` | 10 | 12 | cyan hex shield crack → shards |
| `teleport_out` | `fx.teleport_out` | 10 | 12 | vertical dissolve teleport out |
| `teleport_in` | `fx.teleport_in` | 10 | 12 | particle coalesce teleport in |
| `scrap_burst` | `fx.scrap_burst` | 10 | 12 | metallic scrap debris + sparks |
| `acid_spit` | `fx.acid_spit` | 10 | 12 | toxic green acid spray + drips |
| `ice_shatter` | `fx.ice_shatter` | 10 | 12 | crystalline ice shatter + frost ring |
| `heal_bloom` | `fx.heal_bloom` | 10 | 10 | soft green/gold heal bloom petals |

Each ships `*_strip.png` + `*_clip.json` (`lattice.clip` v1, kind=`fx`, loop=false).

Author in Lattice: **Effects** → pick the gen → tweak params/seed → **Export → Clip**.

Also mirrored into `samples/map_ambient/map_fx/` (PACK.json updated).
Baker: `scripts/bake_effects_wave2.py`.
