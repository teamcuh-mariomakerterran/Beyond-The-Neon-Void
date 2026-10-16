---
name: job-ability-system
description: >-
  Use when adding or changing Beyond The Neon Void jobs (classes), abilities,
  passives (reaction/support/movement), cards and decks, Additions, class
  unlock trees, class XP/levels, microchip costs, data-disk abilities, blue
  learning, secondary jobs, or when asked for a balance sheet / "is every
  ability wired" / "design a new FFT-style job". Covers data/classes.json,
  abilities.json, passives.json, cards.json, job_handler.gd,
  progression_system.gd and docs/design/CLASSES.md + ABILITY_LIST.md.
---

# Job & Ability System

BTNV's FFT job system is big and **data-driven**: 37 playable classes, 195
abilities, 19 passives and 15 cards, all JSON loaded by ContentDB and
auto-edited by the Neon Forge. This skill keeps every job distinct, every
ability wired end to end (data → rules → AI-usable → looks and sounds right),
and the docs in sync.

Load as needed:
- `references/class-and-progression.md`: counts, ClassResource fields, XP and class levels, unlocks, learning, blue magic, command list, decks, passives, Additions
- `references/ability-schema.md`: every Ability field, the full **specials table with params**, the script subclass rule, VFX/icon/sound resolution
- `references/design-guide.md`: identity, kit shape, numbers anchored to data, voice, new-class checklist
- `scripts/ability_audit.py`: cross-checks plus a per-class summary; `--sheet out.csv` writes one row per ability; `--class <id>`
- `templates/class.template.jsonc`, `ability.template.jsonc`, `passive.template.jsonc`

Related skills:
- Rules and formulas: `tactics-combat-core` (use its `forecast_matrix.gd` for numbers).
- The AI using new abilities: `tactics-ai`.
- Looks: `godot-vfx-forge`, `godot-shader-forge` (status looks).
- Sounds: shared `godot-sfx-package` and `iso-anim-sfx-sync`.
- Feel: `game-feel-polish`.
- Editor exposure: `neon-forge-tooling`.

---

## When to run
- Edits to `data/classes.json`, `abilities.json`, `passives.json`, `cards.json`, `src/combat/job_handler.gd`, `src/progression/progression_system.gd`, `src/combat/abilities/*`, `ClassLibrary.CLASS_ORDER`, or `docs/design/CLASSES.md`/`ABILITY_LIST.md`.
- "New job", "rework X", "add a summon", "balance pass on mages", "which abilities have no VFX".

---

## Ground truth (`python scripts/ability_audit.py <repo>`: 0 errors, 0 warnings on the snapshot)
- **Counts:** 49 classes (37 playable + 12 enemy/chassis), 195 abilities, 27 with charge time, 20 using `script` (terrain 9, kinetic 6, time 5), 6 Additions (Sync Blade).
- **Docs drift:** the `CLASS_ORDER` comment says 35. `CLASSES.md` says 36 and has **no Sync Blade section**. `ABILITY_LIST.md` has Sync Blade.
- **Presentation coverage:**
  - 107/195 abilities have a specific VFX; 88 use their damage-type fallback.
  - 0 set `icon_path` (pack lookup by id; the pack isn't in the snapshot).
  - **`Ability.sfx_id` is never read.**
  - Reaction cues `reaction.<id>` don't exist in `cues.json`, so reactions are silent.
- **Progression:**
  - Class XP goes only to the current class (×0.8 of mission XP); class level cap 8.
  - Chips buy learnables (1–5). Data disks gate the Daemon Caller summons.
  - Secondary job: learned learnables only, no innates.
- **Gaps:**
  - Passives are missing from Neon Forge `SECTIONS`.
  - `class_unlocked`, `ability_unlocked` and `character_leveled` have no listeners (no UI moment for unlocks).
  - Enemy classes don't scale with level (tactics-combat-core).
  - The AI never casts `charge_ticks > 12` (none today).

---

## Hard rules
1. **Data first, code only for new mechanics.** A new ability is a JSON entry. New code is justified only for a new `special` (one branch in `Ability._resolve_special` or a script subclass), a new passive `effect` (in `passives.gd`), or a new status hook (tactics-combat-core rule 6).
2. **Ownership is two-way.** An ability's `class_id` must list it (`innate_ability_ids` or `learnable_ability_ids`), and a class must only list abilities that exist. `ContentDB.validate()` and `ability_audit.py` enforce this.
3. **`kinetic.*`, `time.*` and `terrain.*` specials need the matching `"script"`.** Without it, `Ability.resolve` silently ignores the special.
4. **Only ATTACK and MAGIC deal damage.** Don't give a DEBUFF `power` and expect damage. Use `kind: "ATTACK"` with `status_ids` instead.
5. **Respect the AI's limits.** Keep `charge_ticks` ≤ 12, and make the targeting expressible (the AI reads `get_targetable_cells` and `forecast`). If the AI can't use it, say so and file it for `tactics-ai`.
6. **Every new ability ships with its presentation:**
   - VFX: a `vfx.json` `abilities` entry or a deliberate fallback.
   - Icon: pack name or `icon_path`.
   - Status look and icon for any new status.
   - A cue for any reaction passive.
   - Sound via VFX parts or cues. Don't rely on `sfx_id` until it's wired.
7. **Numbers are measured.** Run `forecast_matrix.gd --classes=<id>` (tactics-combat-core) and the `godot-verify` replay gate. Compare against neighbours in `--sheet`. Final bands are **ASK BRIAN**.
8. **Keep the docs true.** `CLASS_ORDER` + comment, `docs/design/CLASSES.md` section, `ABILITY_LIST.md` entry. Same PR.
9. **Voice:** one dry, specific line per description. No lore claims about Doctrine bodies without `franchise-bible`.
10. **Don't decide these alone (ASK BRIAN):**
    - new class concepts and secret-class unlock flags
    - JP-style spillover (currently class XP only)
    - secondary-innates rule changes
    - deck size (10)
    - enabling `sfx_id`
    - Brave/Faith-like stats

---

## Workflow: new ability
1. Read the class in `classes.json`, and run `ability_audit.py --class <id>` to see its kit.
2. Copy `templates/ability.template.jsonc`. Pick `kind`/`target`/`shape`. For a special, check the params table in `references/ability-schema.md`.
3. Add the id to the class's `innate_ability_ids` or `learnable_ability_ids`. For learnables, set `chip_cost` (or a key item or class level gate).
4. Presentation: add a `vfx.json` `abilities.<id>` entry (godot-vfx-forge) and an icon, plus a status look or cue if needed.
5. Docs: add the line to `ABILITY_LIST.md` and the Innate/Learnable line in `CLASSES.md`.
6. Run `python scripts/ability_audit.py .` and get 0 errors. Run `forecast_matrix.gd -- --classes=<class>` and check hits-to-kill.
7. Run the `godot-verify` full gate. If the ability is a new special, add a test in `test_suite.gd` (resolve on a small grid, assert the effect).

## Workflow: new class (job)
1. Write the identity block (fantasy, verb, weakness, combo partner) and show it. Unlock requirements are a design call, so **ASK BRIAN** for secret ones.
2. Add the class (`templates/class.template.jsonc`), 2 innates and 2–6 learnables (abilities workflow), and optionally a passive.
3. Add it to `ClassLibrary.CLASS_ORDER` in tier order and fix the count comment.
4. Write the `docs/design/CLASSES.md` section in the existing format, plus the `ABILITY_LIST.md` block.
5. Presentation for every ability; sprites and Lattice clips per `lattice-in-game`.
6. Run the audit, the forecast matrix vs. a same-tier class, the `godot-verify` gate, and the replay gate (`verify.ps1 -Only replay -Rosters suite`; add the class to a roster in `godot-verify/scripts/gd/replay_body.gd` SUITE_ROSTERS if you want it simulated).

## Workflow: balance pass
1. `python scripts/ability_audit.py . --sheet C:/temp/abilities.csv` (power, costs, range, charge, statuses per ability).
2. `forecast_matrix.gd -- --abilities=all --out=C:/temp/before.csv`.
3. Make data-only changes. Re-run step 2 into `after.csv` and diff.
4. Run `verify.ps1 -Only replay -Rosters suite -Seeds 3` and report the win-rate delta. **ASK BRIAN** for target bands.

---

## Anti-patterns
- An ability whose `class_id` points at a class that doesn't list it, or the reverse.
- `"special": "terrain.hazard"` without `"script": "terrain"`.
- A DEBUFF with `power` expecting damage.
- `charge_ticks: 20` "for drama" (the AI never uses it).
- Copy-pasting a whole kit with renamed ids (jobs must feel different).
- Setting `sfx_id` and thinking you added a sound.
- Free (`chip_cost: 0`) learnables with no gate.
- Updating JSON but not `CLASSES.md`/`ABILITY_LIST.md`/`CLASS_ORDER`.
- Inventing Doctrine lore in descriptions.

---

## Done checklist
- [ ] `ability_audit.py` 0 errors (new warnings explained)
- [ ] Ownership two-way; script/special consistent; statuses exist
- [ ] VFX entry or deliberate fallback; icon; status looks; reaction cues
- [ ] `forecast_matrix` numbers checked against neighbours; deltas reported
- [ ] `CLASS_ORDER` (+ comment), `CLASSES.md`, `ABILITY_LIST.md` updated
- [ ] New special/effect has a test; `godot-verify` gate green; replay 0 mismatches
- [ ] ASK-BRIAN items listed
