# Ability schema (`src/data/ability.gd`; JSON keys = @export names; enums as names)

| group | field | notes |
|---|---|---|
| identity | `id, display_name, description, icon_path, class_id` | `class_id` must list it in innate/learnable (`ContentDB.validate` checks this) |
| | `kind` | ATTACK, MAGIC, HEAL, BUFF, DEBUFF, UTILITY, SPECIAL. **Only ATTACK/MAGIC roll hit and deal damage.** HEAL heals; the rest only apply statuses and specials |
| | `target` | ENEMY, ALLY, SELF, ANY_UNIT, TILE |
| costs | `ap_cost` (1), `mp_cost`, `hp_cost_pct`, `chip_cost` (**terminal price, not a battle cost**), `charge_ticks` (CT ticks; >12 = the AI never casts it), `required_class_level` (≤ 8), `requires_item_id` (key item / data disk) | |
| targeting | `range_min, range_max, uses_weapon_range` (max(weapon, range_max) + `range_plus`), `vertical_tolerance` (3), `requires_los` (auto when the weapon range is > 1), `shape` (SINGLE / DIAMOND / LINE / CROSS), `aoe_radius`, `friendly_fire` | the AoE footprint ignores height |
| effect | `power` (×stat), `scaling_stat` (attack/magic/…), `damage_type` (physical, kinetic, tech, void, essence, electric, plasma, cryo; the last six are magical and use resistance), `accuracy_bonus`, `ignores_cover`, `crit_bonus`, `status_ids[]`, `status_chance`, `special`, `blue_learnable`, `addition{}`, `absorb_only`, `params{}` | |
| presentation | `vfx_id`, `cutscene` (PARALLAX doc, played by `BattleMap` for the attacker), `sfx_id` (**never read in src**), `flavor_text` | |
| subclass | `script`: `kinetic` / `time` / `terrain` → `ContentDB.ABILITY_SCRIPTS` | **required** for `kinetic.*`, `time.*`, `terrain.*` specials |

## Specials
| special | where | params |
|---|---|---|
| cleanse | Ability | — (debuffs on allies in the area) |
| restore_mp | Ability | `mp` (20) |
| blink | Ability | — (TILE, empty walkable) |
| summon / summon_droid | Ability | `character_id`, `max_active` (3/2) |
| revive | Ability | `hp_pct` (0.3), target = allied corpse |
| reanimate | Ability | `hp_pct` (0.5), echo + `fading` |
| echo | Ability | — (repeats the team's last action) |
| steal_chip | Ability | `chance` (0.5): **pays GameManager mid-battle** |
| steal_coins | Ability | `coins` (40): same |
| kinetic.charge | kinetic | +0.2 power per straight tile, max ×2 |
| kinetic.pull | kinetic | `reach` (3), `pull` (2) |
| kinetic.repulse | kinetic | `distance` (2), `impact` (12, ×2 if `unstable`) |
| time.delay_thread | time | `mult` (1.5): deferred magic damage + knockdown |
| time.stitch_turn | time | `ct_gain` (50) |
| time.rewind | time | — (`rewind_anchor`) |
| time.ct_shift | time | `ct` (−50) |
| terrain.fault_line | terrain | `height_delta` (2) |
| terrain.elevate | terrain | `rise` (2) |
| terrain.warp | terrain | — |
| terrain.hazard | terrain | `hazard` (neon_fire / static / essence_leak), `turns` (3) |
| terrain.geomancy | terrain | uses the terrain under the target. Table: metal_grate→electric+shocked, coolant→cryo+slow, neon_sign→plasma+burning, essence_pool→essence+essence_bleed, rubble→kinetic+knockdown, glass→plasma+blinded |

A new special is a code change in one place:
- `Ability._resolve_special`, or the matching script subclass
- plus its `vfx.json` `specials` entry and a test.

## Presentation resolution (what the player sees and hears)
- **VFX (`VFX.plan_for_ability`):** `vfx_id` (if `vfx.json.effects` has it) → `vfx.json.abilities[id]` → `specials[special or head]` → `kinds[KIND]` (non-attack, physical or HEAL) → `types[damage_type]` → `impact_physical`.
  - Snapshot: 107/195 abilities have a specific look; 88 use their damage-type look. None set `vfx_id`.
- **Icon:** `icon_path`, else the UiIcons pack lookup by id or type. 0/195 set `icon_path`, and the icon pack isn't in the snapshot.
- **Sound:** `Ability.sfx_id` is unused. Sounds come from VFX parts and cues (godot-sfx-package / game-feel-polish).
