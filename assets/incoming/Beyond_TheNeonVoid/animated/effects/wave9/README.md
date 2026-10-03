# Effects wave 9

Deferred w8 + fillers.

| id | gen | frames | fps | loop | use |
|----|-----|--------|-----|------|-----|
| `supply_crate_drop` | `fx.supply_crate_drop` | 12 | 12 | false | supply crate parachute drop + landing puff |
| `turret_deploy` | `fx.turret_deploy` | 12 | 12 | false | turret unfold + barrel snap flash |
| `muzzle_smoke` | `fx.muzzle_smoke` | 10 | 12 | false | small after-shot muzzle smoke puff |
| `casing_eject` | `fx.casing_eject` | 10 | 14 | false | brass casing eject arc + glint |
| `vehicle_exhaust` | `fx.vehicle_exhaust` | 10 | 10 | true | vehicle exhaust puff loop |
| `reload_click` | `fx.reload_click` | 10 | 12 | false | magazine seat click + spark |
| `heal_ground_aura` | `fx.heal_ground_aura` | 10 | 10 | false | flat green ground heal ring aura |
| `banner_capture_spin` | `fx.banner_capture_spin` | 12 | 10 | true | spinning capture banner on pole |
| `ally_mark_ping` | `fx.ally_mark_ping` | 10 | 12 | false | cyan ally mark diamond + rings |
| `fortify_plate` | `fx.fortify_plate` | 10 | 12 | false | armor plate fortify slam flash |

Baker: `scripts/bake_effects_wave9.py`.

Skipped dups: rain_splash, cloak_shimmer, heal_bloom/motes/medkit (heal_ground_aura is flat ring), capture_flag (banner spins), muzzle_flash (muzzle_smoke is after-shot grey).
