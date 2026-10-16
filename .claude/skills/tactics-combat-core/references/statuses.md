# Statuses (`data/status_effects.json` → `StatusEffect`, behaviour in `unit.gd` + code hooks)

Fields: `type (BUFF|DEBUFF|NEUTRAL), duration_turns, is_permanent, stat_multipliers{}, stat_flat{}, damage_per_turn, damage_per_turn_pct (negative = regen), max_stacks, prevents_action, prevents_move, deferred_damage_key, tags[]`.
- **Ticking:** on the unit's own turn, inside `begin_turn`. DoT is applied first, then durations drop by 1.
- **Reapplying:** `turns_left = max(old, duration)`, `stacks + 1` (≤ max_stacks), payload merged.
- `Passives.blocks_debuff` (Firewall) can stop a DEBUFF.
- Visuals come from `data/status_looks.json` (StatusLook shader). Cue `status.<id>` if one is defined.

| id | type | dur | data effect | code hook | gap |
|---|---|---|---|---|---|
| stun | D | 1 | no action | — | |
| knockdown | D | 1 | no action | terrain/time abilities, deferred-damage payload | |
| stop | D | 2 | no act/move | — | |
| slow | D | 2 | speed ×0.6 | hazard `static` | |
| haste | B | 3 | speed ×1.5 | — | |
| fortified | B | 2 | def ×1.4 res ×1.25 | — | |
| inspired | B | 2 | atk/mag ×1.25 | — | |
| focused | B | 2 | **none** | icon only | **no effect** |
| exposed | D | 2 | eva ×0.5 def ×0.8 | — | |
| short_circuit | D | 2 | def/res ×0.7 | — | |
| demoralized | D | 2 | atk/mag ×0.75 | — | |
| blinded | D | 2 | **none** | applied by terrain ability | **no accuracy effect** |
| identity_loss | D | 2 | **none** | — | **no effect** |
| shocked | D | 2 | speed ×0.75 | Vault Breach trap | |
| regen | B | 3 | −10%/turn (heal) | — | |
| burning | D | 2 | 6%/turn | — | |
| essence_bleed | D | 3 | 5%/turn | — | |
| fading | N | perm | 12%/turn | echoes (`reanimate`) | |
| unstable | D | 3 | — | kinetic repulse ×2 impact | |
| delay_thread | D | 1 | — | time ability | |
| stitched | D | 3 | — | `_run_unit_turn` gives linked ally CT | |
| rewind_anchor | B | 2 | — | `take_damage` lethal → rewind | |
| charging | N | perm | — | charged casts | |
| hidden | B | 1 | — | Interactions `reveal`, renderer | **no hit-chance effect** (only the `cloaked` tag counts) |
| dualcast | B | 2 | **none** | — | **no effect** |
| berserk | B | 3 | atk ×1.5 def ×0.7 | — | no forced-attack AI |
| buzzed | B | 2 | atk ×1.15 | — | |
| poisoned | D | 3 | 6%/turn | — | |
| asleep | D | 2 | no act/move | — | **doesn't wake on damage** |
| petrified | D | 3 | no act/move, tag `stone` (×1.5 dmg taken) | — | |
| banished | D | 2 | no act/move, tag `untouchable` | — | |
| shielded | B | perm | tag `untouchable` | Interactions `unshield` | |
| cloaked | B | perm | tag `cloaked` | Interactions `reveal` | |

## Adding a status
1. Copy `templates/status_effect.template.jsonc` into `data/status_effects.json`.
2. If its effect isn't expressible in data (multipliers, flat, DoT, prevents, tags), add **one** hook in rules code:
   - a tag check in `DamageCalculator`, or
   - a branch in `Unit.begin_turn`/`take_damage`.

   Don't scatter `has_status("x")` across UI and AI.
3. Add a look in `data/status_looks.json` (godot-shader-forge) and an icon (`ui_icons.gd`).
4. Add a test: apply → tick → expire, plus the effect.
5. Run godot-verify.
