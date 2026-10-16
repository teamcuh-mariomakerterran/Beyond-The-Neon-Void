---
name: godot-vfx-forge
description: >-
  Use when creating or reworking Beyond The Neon Void visual effects: ability
  VFX in data/vfx.json (palette + parts: sim, lightning, flash, streaks, ring,
  pillar, decal, tear, scan, shockwave, glitch, light, trail), the
  ability→effect mapping (vfx_id, abilities/specials/kinds/types tables, aoe/big
  escalation), battle choreography (cast, travel, lunge, impact, tile flash,
  crit/death hooks), charge telegraphs, angular/slash primitives, Lattice FX
  flipbooks, ambient particles and weather (particles.json), or "make abilities
  look insane". Shader code belongs to godot-shader-forge; hit-stop/shake/Cues
  timing to game-feel-polish.
---

# Godot VFX Forge

BTNV has a capable, **data-driven** VFX library: `VFX.spawn(parent, id, at, params)`
builds layered, self-freeing effects from `data/vfx.json` (29 effects, 14 part
types, HDR colours that bloom). Battles stage them through
`BattleMap.play_ability_fx` using `VFX.plan_for_ability`. The engine is ahead of
the content: 88 of 195 abilities still use a generic element look (49 of them
the plain physical tracer), there's no anticipation beat, no charge telegraph,
and no slash primitive. This skill fills that gap **in data first**, in Brian's
rigid, angular, "Blizzard/McFarlane" style, and proves every look with a render.

Load as needed:
- `references/vfx-schema.md`: effect keys, spawn params, all 14 part types with their keys, colours, textures, the mapping chain and escalation, coverage numbers
- `references/choreography.md`: what `play_ability_fx` does beat by beat, the gaps, and the target beat model (anticipation, release, impact, residue, telegraph) with durations
- `references/angular-library.md`: angular primitives that exist, missing ones (slash, flipbook, shard ring, hex), and the per-element signature proposal
- `references/particles-weather.md`: ParticleFactory presets, keys, GPU rules, budget
- `scripts/vfx_lint.py`: validates `vfx.json` against the **real part code** (scraped keys, so typos are caught), colours/palette refs, mapping tables and ability ids. `--coverage` gives bespoke/kind/element counts and an angular-vs-soft tally
- `scripts/vfx_upsert.py`: inserts or replaces one effect (and mapping rows) in vfx.json **in house style** (round-trip byte-identical on the snapshot); `--dry-run` diff
- `scripts/gd/vfx_shot.gd` (+ body): renders an effect frozen at chosen times on an iso floor with dummies. `--def=` previews a candidate without touching vfx.json; `--ability=` shows cast/travel/impact as a battle resolves them
- `templates/effect_impact.template.json`, `templates/effect_cast.template.json`: angular impact (+residue) and anticipation starters (strict JSON)
- `templates/charge_telegraph.gd`: ground marker for pending charged casts (known-gaps #36). Tested: renders from a real `TurnQueue`
- `templates/wiring.md`: draft → preview → upsert → lint → in-context render

Related: `godot-shader-forge` (screen shaders and status looks; the VFX `shockwave`/`glitch` parts use its shaders), `game-feel-polish` (Cues: shake, hit-stop, slow-mo, sfx; timing feel), `job-ability-system` (ability fields: `vfx_id`, `damage_type`, `aoe_radius`, `charge_ticks`, `special`), `lattice-in-game` (FX clips), `godot-verify`. The shared `godot-sfx-package` and `iso-anim-sfx-sync` workflows cover audio and syncing animation to SFX. Use them for sound and don't duplicate them here.

## When to run
- Requests like: "new effect for X", "make plasma hit harder", "every element needs a wind-up", "slash effect for melee", "boss super move", "charged spells should show where they land", "weather in this map", "VFX look generic".
- Any edit to `data/vfx.json`, `data/particles.json`, `src/vfx/vfx*.gd`, `particle_factory.gd`, or `BattleMap.play_ability_fx` and its hooks.

## Ground truth (box snapshot)
- **Library:**
  - `src/vfx/vfx.gd` (static API: `spawn`, `reload`, `has_effect`, `get_effect`, `effect_ids`, `impact_time`, `shake`, `hit_stop`, `plan_for_ability`, `parse_color`, `texture`).
  - Parts live in `vfx_sim.gd` (CPU, max 600, deterministic, steppable), `vfx_shape.gd`, `vfx_lightning.gd`, `vfx_screen.gd`, `vfx_light.gd` and `vfx_trail.gd`.
- **Data:** `data/vfx.json` is strict JSON (no comments), overridden by `user://content/vfx.json`. It has 29 effects plus mapping tables: `types` 8, `kinds` 4, `specials` 13, `abilities` 8.
- **Lint baseline:** `vfx_lint.py` gives 0 errors, 0 warnings, 0 info.
- **Coverage:** 43 bespoke, 64 by kind, 88 by element (physical 49, plasma 11, electric 9, tech 5, cryo 5, void 4, essence 3, kinetic 2).
- **Colours:** 220/335 part colours are HDR.
- **Part usage:** sim 55, light 27, flash 26, ring 22. `burst` (GPU) is unused.
- **Staging** (`battle_map.gd:669`): optional ability cutscene → caster `attack` anim → `cast` (only `blink` has one) → `travel` (ranged point) or 10 px lunge (melee) → impact by mode → tile flash 0.3 s → +0.12 s.
- **Hooks:** `crit_hit` on crit damage, `death_dissolve` (team colour), landing dust/splash. All of it is skipped when `CombatManager.animate` is false.
- **Gaps:**
  - #36: nothing listens to `ability_charging`, and there's no ground telegraph.
  - #37: `SettingsFlags.fast_battles` is read nowhere.
  - No flipbook part for Lattice `kind:"fx"` clips.
  - No slash primitive.
  - `ability.sfx_id` is unused.

## Hard rules
1. **Data first.** A new look is a `vfx.json` effect plus a mapping row. Write code only for a missing **primitive** (slash, flipbook) or **staging beat** (telegraph), and propose it first.
2. **Use the mapping chain; don't hard-code.**
   - Prefer, in order: `types.<element>` (a whole element), `specials`, `vfx.json abilities.<id>`, and only then `abilities.json vfx_id`.
   - `vfx_id` disables aoe/big escalation, so use it only for true one-offs.
   - Never spawn ability VFX by id from gameplay code.
3. **Presentation never touches rules.** VFX run only when `animate` is true. Never read `randf` for gameplay in VFX, and never change HP, statuses or turn order from a VFX callback. Sync numbers via `impact_time`/`impacted`, not by changing resolution order.
4. **Beat model.**
   - Anticipation stays under ×1.5 HDR, 0.12–0.35 s.
   - Impact is the only very bright frame (core ×2–2.5), peaking at 0.05–0.15 s.
   - Residue is low and lingering.
   - Escalate by tier (`impact` → `aoe` → `big`) through size and duration.
   - Melee totals ≤ 0.6 s, big spells ≤ 1.6 s.
5. **Angular by default.** Rays, streaks, shards, poly debris, dashed rings, lightning, tears and scans. Soft `puff`/`cloud` only for dust and smoke residue. Every effect needs a hot core and a saturated rim.
6. **Palette = element.** Effects use their element's colour language (`angular-library.md`), with `$main/$alt/$core` in parts so `params.color` and `params.palette` can recolour (death_dissolve uses team colour this way).
7. **Budget.** ≤ 600 particles per sim part (hard cap); aim for ≤ 150 total per effect, ≤ 2 `light` parts, ≤ 1 screen part (`shockwave`/`glitch`). Effects end within 12 s (hard cap), and most within 1.5 s.
8. **House-style edits.** Change `vfx.json` with `vfx_upsert.py` (or by hand in the same format: tabs, palette inline, one part per line) so diffs stay reviewable. Never re-serialise the whole file.
9. **Prove it.** `vfx_lint.py` 0 errors, a `vfx_shot` PNG (and `--ability=` in context) looked at, and `godot-verify -Quick`. Never claim a look you didn't render.
10. **Readability.** VFX must not hide unit silhouettes or HP at the impact moment for more than about 0.15 s. Ground-level parts use `floor_z` so they sit under units.

## Workflow: new or reworked ability look
1. `vfx_lint.py . --coverage` shows where the ability resolves today, and `vfx_shot.gd -- --ability=<id>` shows the current look.
2. Pick the scope: one ability, its special, or its whole element.
3. Draft from a template, preview with `--def=` (several times: `0.03,0.08,0.15,0.4`), iterate.
4. Run `vfx_upsert.py` with `--map=…` (dry-run first), then `vfx_lint.py`, then `vfx_shot --ability=` again.
5. If it's a `big` tier, check a charged and an AoE ability of that element.

## Workflow: element signature pass (high value)
1. **ASK BRIAN** to confirm the shape language per element (`angular-library.md` table).
2. For each element: a `cast` (anticipation), a refined `impact`, a distinct `aoe`/`big`, and residue parts.
3. Wire them via `--map=types:<element>:cast|impact|aoe|big`. One edit upgrades every ability of that element (88 abilities sit on the element table).
4. Physical needs a slash. Until the `slash` primitive exists, fake it with a 2–3-ray `flash`, directional `streaks` and line sparks.

## Workflow: charge telegraph (#36)
1. Copy `templates/charge_telegraph.gd` to `src/grid/charge_telegraph.gd` and add it under `BattleMap.world` with `grid` set.
2. Make `BattleMap._fx_color` public (or shared) so the colours stay in one place.
3. Add an anticipation effect on `EventBus.ability_charging` (spawn the element `cast` at the caster).
4. Check it with a charged ability in a real battle (animate on). The AI side (`tactics-ai`) relies on players seeing the same information.

## Workflow: new primitive (slash / flipbook)
Write a short proposal: the keys, which file (`vfx_shape.gd` new `_type`, or a new `VFXFlipbook` part registered in `VFXEffect._make_part`), and a data example. Get Brian's OK, then:
- Implement it with deterministic `rng` from `VFXPart` and `t`/`life` envelopes.
- Add the type to the `vfx.json` `_readme` and `references/vfx-schema.md`. `vfx_lint.py` picks up the new keys automatically once the type is in its `PART_FILES` table (one-line edit).
- Add a `vfx_shot` render and a `tests/vfx_showcase_body.gd` `SHOTS` entry.

## Anti-patterns
- `VFX.spawn(world, "my_fx", …)` sprinkled in gameplay code instead of a mapping row.
- Setting `vfx_id` on many abilities (it kills escalation, and the element look fragments).
- `//` comments in `vfx.json` (it breaks `JSON.parse_string` and every effect disappears).
- Soft puff explosions for a rigid style; full-screen white flashes on every hit.
- Long anticipations without wiring `fast_battles`.
- Particle counts in the hundreds per hit; more than one screen-reading part per effect.
- Re-dumping `vfx.json` with a JSON library (a whole-file diff).
- Judging a look from JSON alone, without a render.

## Done checklist
- [ ] `vfx_lint.py . --coverage`: 0 errors, coverage change stated (e.g. "physical 49 → 0 generic")
- [ ] `vfx_shot` PNGs at 3–4 times, plus `--ability=` in context, looked at
- [ ] Beat timings within the bands; impact is the brightest frame; residue present for big tiers
- [ ] Budget: ≤ 600 per sim part, about 150 per effect, ≤ 2 lights, ≤ 1 screen part, ends < 1.6 s (big)
- [ ] vfx.json diff touches only the intended effect and mapping lines
- [ ] No gameplay state touched by VFX; presentation still skipped when `animate` is false
- [ ] `godot-verify -Quick` green
- [ ] known-gaps updated (#36/#37 if addressed); ASK-BRIAN items listed (element shape language, slash vs flipbook priority)
