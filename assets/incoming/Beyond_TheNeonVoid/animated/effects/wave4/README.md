# Effects wave 4

Fire / smoke / combat projectiles / utility FX (burn, smoke, plasma, laser, orbital, mine, oil, shield_up, cloak, pickup).

| id | Lattice gen | frames | fps | loop | use |
|----|-------------|--------|-----|------|-----|
| `fire_burn` | `fx.fire_burn` | 10 | 10 | true | loopable burning flame tongues + embers |
| `smoke_screen` | `fx.smoke_screen` | 12 | 10 | false | grey billowing smoke cover cloud |
| `plasma_bolt` | `fx.plasma_bolt` | 8 | 14 | false | magenta/cyan plasma projectile streak |
| `laser_hit` | `fx.laser_hit` | 8 | 14 | false | thin red laser beam + impact star |
| `orbital_strike` | `fx.orbital_strike` | 12 | 12 | false | reticle warn then orbital column blast |
| `landmine_blast` | `fx.landmine_blast` | 10 | 12 | false | low ground mine blast + dirt clods |
| `oil_splatter` | `fx.oil_splatter` | 8 | 12 | false | dark oil droplets + sparks (mech hurt) |
| `shield_up` | `fx.shield_up` | 10 | 12 | false | hex shield bubble assembling upward |
| `cloak_shimmer` | `fx.cloak_shimmer` | 10 | 12 | false | cloak dissolve scanline shimmer |
| `resource_pickup` | `fx.resource_pickup` | 8 | 12 | false | gold/cyan resource chip pickup pop |

Each ships `*_strip.png` + `*_clip.json` (`lattice.clip` v1). `fire_burn` is loop:true (ambient); others fx loop:false.

Author in Lattice: **Effects** → pick the gen → tweak params/seed → **Export → Clip**.

Also mirrored into `samples/map_ambient/map_fx/` (PACK.json updated).
Baker: `scripts/bake_effects_wave4.py`.
