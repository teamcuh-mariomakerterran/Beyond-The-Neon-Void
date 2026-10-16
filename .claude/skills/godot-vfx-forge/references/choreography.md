# Battle choreography: how an ability is staged today, and the target beat model

## Today (`BattleMap.play_ability_fx`, called from `CombatManager._execute` when `animate`)
1. **Cutscene** (optional): `ability.cutscene` plays with `ATTACKER/TARGET/ABILITY/DAMAGE` vars. DAMAGE comes from `DamageCalculator.forecast`.
2. **Plan:** `VFX.plan_for_ability(ability, ranged)`. Ranged means distance > 1 and not a self-cast.
3. The caster plays its `"attack"` animation (Lattice: `cast` falls back to `attack`).
4. **Cast** effect at the caster, if the plan has one (today only `blink`).
5. **Travel:** if ranged and mode `point`, spawn the travel effect with `to`, then wait `VFX.impact_time(travel)` (at least 0.05 s). **Lunge:** if melee and offensive, a tween of 0.07 s out and 0.1 s back.
6. **Impact:** `_spawn_impact_vfx` by mode (point/multi/arc/stream/chain), with `floor_z = draw_order(cell)*2`.
7. **Tile flash:** every affected tile is modulated to `_fx_color(ability)` and tweens back to white over 0.3 s.
8. Wait 0.12 s ("let the impact peak"), then resolution and damage numbers continue in CombatManager.
9. **Global hooks** (connected on first use): `unit_damaged` with a crit spawns `crit_hit`; `unit_died` spawns `death_dissolve` (team colour ×1.6); `unit_moved` spawns landing dust or water splash.
10. **Cues** (`data/cues.json`) fire separately on `hit`, `hurt`, `kill`, `status.X` and so on: shake, hit-stop, slow-mo, zoom, flash, `vfx{id}`, `sfx{id}`.

Presentation is skipped entirely when `CombatManager.animate == false` (headless sims), so VFX can never affect rules or determinism. Keep it that way.

## Gaps in the staging
- **No anticipation beat.** Nothing plays between "unit is chosen" and the release, except the `attack` animation. Charged casts (`ability_charging`) have no VFX, no ground marker and no listener (known-gaps #36).
- **No residue beat** as a concept. Some effects linger (decals, embers), but there's no deliberate after-image or scorch layer per element.
- **Melee is a 10 px lunge**, with no slash-arc primitive and no impact frame on the attacker.
- **Element signature is uneven.** Physical (49 abilities) all share tracer + impact_physical, so the most common attacks are the least distinctive.
- **No flipbook part.** Lattice `kind:"fx"` clips can't be spawned as VFX parts.

## Target beat model (use for every new or reworked look)
| Beat | Purpose | Duration | Data hook (no code needed) | Code needed? |
|---|---|---|---|---|
| **Anticipation** | Read the intent: gather, charge glyph, weapon glint | 0.12–0.35 s (longer for `big`) | `cast` in an `abilities`, `types` or `specials` row | No. `play_ability_fx` already spawns `plan.cast`. A per-element `cast` in `types` would give every element a wind-up at once. |
| **Release / travel** | Direction and speed | 0.08–0.3 s | `travel` (a `trail` part sets `impact_time`) | No |
| **Impact** | The hit frame: brightest, sharpest, shortest | 0.05–0.15 s peak; hit-stop 0.03–0.08 s (crit/kill longer via Cues) | `impact`, `aoe`, `big` | No |
| **Residue** | What's left: scorch, frost, static, ink | 0.4–1.5 s, low intensity, no HDR > 1.3 | `decal` and slow `sim` parts with `fade: late` in the impact effect | No |
| **Charge telegraph** | FFT-style "this cell gets hit in N ticks" | Until resolution | — | **Yes:** listen to `EventBus.ability_charging(unit, ability, cell, ticks)`, mark `ability.get_affected_cells(grid, caster.cell, cell)` until the cast resolves (pending casts are in `CombatManager.turn_queue.pending_casts`). |

Rules of thumb:
- Escalate in three tiers using the existing switch: `impact` (single), `aoe` (radius ≥ 1), `big` (radius ≥ 2 or charge ≥ 2). Players should read tier from size and duration alone.
- The impact frame is the only moment allowed to be very bright (HDR core ×2–2.5). Anticipation and residue stay below ×1.5.
- Keep a melee impact's total effect under 0.6 s and a big spell's under 1.6 s. With 20+ turns per battle, longer stops feeling good. `SettingsFlags.fast_battles` is declared but **read nowhere** (known-gaps #37), so wiring it (e.g. skip anticipation, halve residue, `Engine.time_scale` during FX) is the cheap win before adding beats.
- Sync numbers to impact: if you add a long anticipation, damage numbers still wait for `impact_time`/`impacted`, not a fixed timer.
