# Effects wave 3

Procedural one-shot status / weather / demolish FX (alert, stun, silence, lightning, rain, snow, demolish, EMP, poison, crit).

| id | Lattice gen | frames | fps | use |
|----|-------------|--------|-----|-----|
| `status_alert` | `fx.status_alert` | 8 | 12 | red/amber status alert badge pulse |
| `status_stun` | `fx.status_stun` | 10 | 12 | yellow/white stun stars orbit |
| `status_silence` | `fx.status_silence` | 8 | 12 | purple silence X + cancelled waves |
| `lightning_strike` | `fx.lightning_strike` | 10 | 12 | vertical lightning bolt + ground flash |
| `rain_splash` | `fx.rain_splash` | 8 | 10 | map weather rain splash rings |
| `snow_burst` | `fx.snow_burst` | 10 | 10 | soft snow flakes + chill puff |
| `building_demolish` | `fx.building_demolish` | 12 | 12 | dust mushroom + falling debris |
| `emp_pulse` | `fx.emp_pulse` | 10 | 12 | cyan hex EMP expanding pulse |
| `poison_cloud` | `fx.poison_cloud` | 10 | 10 | toxic green/purple poison billow |
| `crit_spark` | `fx.crit_spark` | 8 | 14 | white/gold crit slash + star burst |

Each ships `*_strip.png` + `*_clip.json` (`lattice.clip` v1, kind=`fx`, loop=false).

Author in Lattice: **Effects** → pick the gen → tweak params/seed → **Export → Clip**.

Also mirrored into `samples/map_ambient/map_fx/` (PACK.json updated).
Baker: `scripts/bake_effects_wave3.py`.
