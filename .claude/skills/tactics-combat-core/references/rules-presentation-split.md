# Rules ↔ presentation split (prerequisite for replays, the Lying HUD and the Black Doctrine engine port)

## Where rules touch presentation today
| Coupling | Location | Headless today because |
|---|---|---|
| `await map_node.play_ability_fx(...)` | `CombatManager._execute` | `animate = false` skips it |
| `await get_tree().create_timer(0.25/0.3)` | `_execute`, `_ai_turn` | `animate = false` |
| `await unit.move_along(path, animate)` | `request_move` | animate flag |
| `map_node.on_unit_path` (traps/anchors) | `request_move` | `map_node == null` in tests |
| `Unit.take_damage` → `hit_flash(...)` | `unit.gd:243` | tween is a no-op outside the tree |
| abilities emit `camera_shake` / `play_sfx` themselves | kinetic/terrain/time abilities | signals with no listener |
| `AdditionWidget` interactive timing | `_run_addition` | not interactive when headless or AI |
| `VFX.hit_stop` writes `Engine.time_scale` | vfx | outside the Cues override stack (game-feel-polish) |

## Target shape (incremental; never a big-bang rewrite)
1. **Rules emit, presentation listens.**
   - New rules code emits EventBus signals or `Cues.fire(id, ctx)` and never calls nodes.
   - Presentation (BattleMap, Unit visuals, VFX, Cues) subscribes.
   - Existing awaits stay until each one is replaced.
2. **One RNG.** All rules rolls use `CombatManager.rng` (or an RNG passed in via `Ability.Context.rng`). Fix in this order (`scripts/rng_audit.py`):
   1. the `Passives._roll` fallback
   2. `Interactions.rng` in battle
   3. mission loot (seed from the mission and a save seed)
3. **Battle log.** `templates/battle_log.gd` (proposed `BattleLog`) records header + events from EventBus. It's tested on the box: m01, seed 7 → 187 events, saved to `user://logs/`. Next steps:
   - save the last battle log automatically in debug builds
   - add a dev-console `replay <file>` that re-runs with the same seed and compares hashes.
4. **Presentation awaits become "beats".** The rules step finishes instantly and pushes a beat list. BattleMap plays the beats and only then lets the loop continue (an `await presentation_done` with one owner). This keeps `animate` as one switch.
5. **InfoFilter for the Lying HUD** (BIG_IDEAS, approved for one warped zone only):
   - a pure function `InfoFilter.apply(forecast_dict, viewer, zone) -> dict` sits between `DamageCalculator.forecast` and the HUD
   - **the AI and the rules never see the filtered values**
   - test: forecast unchanged, HUD values changed only inside the zone.

## Rules for new code
- No `await` on anything visual inside a rules function you add. Emit and return.
- No `get_tree()`, `create_tween()` or `Engine.time_scale` in `src/combat/` or the CombatManager rules paths.
- If you must touch an existing coupled spot, leave it no worse, and add a TODO with a link to this file.
