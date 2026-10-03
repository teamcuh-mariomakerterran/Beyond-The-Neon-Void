# Effects wave 7

Combat / map utility FX (gap-fill vs waves 5–6).

| id | gen | frames | fps | loop | use |
|----|-----|--------|-----|------|-----|
| `medkit_burst` | `fx.medkit_burst` | 10 | 12 | false | medkit cross pop + heal motes |
| `overshield_shatter` | `fx.overshield_shatter` | 12 | 12 | false | gold overshield crack then shards |
| `smoke_grenade` | `fx.smoke_grenade` | 12 | 10 | false | canister pop + rising smoke plume |
| `flashbang_whiteout` | `fx.flashbang_whiteout` | 10 | 12 | false | flashbang white disc + star spikes |
| `sticky_bomb_blink` | `fx.sticky_bomb_blink` | 12 | 12 | false | sticky bomb LED blink then pop |
| `concussion_ring` | `fx.concussion_ring` | 10 | 12 | false | soft expanding concussion air ring |
| `tracer_ricochet` | `fx.tracer_ricochet` | 10 | 14 | false | tracer streak + ricochet sparks |
| `alarm_strobe` | `fx.alarm_strobe` | 10 | 8 | true | building alarm strobe loop |
| `dust_kick` | `fx.dust_kick` | 10 | 12 | false | footstep / vehicle dust kick |
| `drone_scout_ping` | `fx.drone_scout_ping` | 12 | 12 | false | drone sonar ping + scan wedge |

Baker: `scripts/bake_effects_wave7.py`.

Skipped duplicates: heal_bloom/nanite, shield_break/up, emp_pulse/burst, smoke_screen, teleport/spawn_warp, oil_splatter, shockwave (concussion is softer air ring), gore blood packs.
