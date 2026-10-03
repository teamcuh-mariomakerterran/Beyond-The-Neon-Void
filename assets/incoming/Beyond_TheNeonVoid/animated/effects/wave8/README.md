# Effects wave 8

Combat / map utility FX (gap-fill vs waves 5–7).

| id | gen | frames | fps | loop | use |
|----|-----|--------|-----|------|-----|
| `decoy_hologram` | `fx.decoy_hologram` | 12 | 12 | false | cyan decoy silhouette flicker then pop |
| `mine_arm_blink` | `fx.mine_arm_blink` | 12 | 12 | false | mine arming LED blink then click |
| `tripwire_snap` | `fx.tripwire_snap` | 10 | 12 | false | red tripwire laser then snap sparks |
| `breach_charge_spark` | `fx.breach_charge_spark` | 12 | 12 | false | breach charge countdown sparks |
| `poison_gas_plume` | `fx.poison_gas_plume` | 12 | 10 | false | toxic green rising gas plume |
| `ice_ground_crack` | `fx.ice_ground_crack` | 10 | 12 | false | ground freeze cracks + frost |
| `burn_ember_dot` | `fx.burn_ember_dot` | 10 | 10 | true | small burn DoT ember loop |
| `revive_spark` | `fx.revive_spark` | 12 | 12 | false | revive get-up flash + motes |
| `jammer_static` | `fx.jammer_static` | 10 | 10 | true | jammer static noise cloud loop |
| `enemy_mark_ping` | `fx.enemy_mark_ping` | 10 | 12 | false | red enemy mark diamond + warn rings |

Baker: `scripts/bake_effects_wave8.py`.

Skipped: rain_splash (exists), poison_cloud/smoke_grenade/radiation (poison_gas_plume is vertical green), fire_burn (burn_ember_dot is small DoT loop), drone_scout_ping (enemy_mark is red warn), landmine_blast (mine_arm is arming), supply/turret/muzzle/casing/exhaust left for later.
