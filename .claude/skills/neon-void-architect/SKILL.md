---
name: neon-void-architect
description: >-
  Root skill for Beyond The Neon Void (Godot 4.7.2 cyberpunk FFT-style tactics
  RPG). Use when starting any work in this repo, adding or changing a system,
  autoload, EventBus signal, content type, JSON field, save data or scene flow,
  or when unsure which Neon Void skill applies. Gives the architecture, the
  EventBus contract, the data pipeline, house conventions, known gaps, and
  routes to the specialist skills.
---

# Neon Void Architect

The map of the game and the rules for changing it. Load this skill first in any
Beyond The Neon Void session, then load the specialist skill the task needs (see
**Routing** below).

This repo already has strong conventions, and Claude has followed them for
weeks. Your job is to extend them, not to reinvent them.

Load as needed:
- `references/architecture.md`: every autoload, what it owns, and the scene flow
- `references/eventbus-contract.md`: all 36 signals with emitters and listeners (from the audit script)
- `references/data-pipeline.md`: JSON → ContentDB → GameResource → Neon Forge, and how to add a field or a content type end to end
- `references/conventions.md`: the code, data, test and doc habits to copy
- `references/known-gaps.md`: confirmed bugs and gaps; **its top section says which are fixed** (do not re-discover them)
- `templates/CLAUDE.md.snippet.md`: paste into the repo root `CLAUDE.md`
- `templates/change-plan.md`: the plan format for any multi-file change
- `scripts/repo_facts.py`: prints live facts (autoload order, data counts, maps, mission graph)
- `scripts/eventbus_audit.py`: prints signal → emitters/listeners and flags undeclared uses

---

## When to run

- First action in any Neon Void session: run `python scripts/repo_facts.py <repo>` (Windows: `py -3 …`) and trust its output over memory.
- Adding or changing an autoload, an EventBus signal, a content bucket, a Resource `@export`, save data, or a scene transition.
- Any change touching more than 2 systems: write `templates/change-plan.md` first.
- You don't know where something lives, or which skill owns it.

Do **not** use this skill as the place for deep combat, world, mission or VFX
rules. Route to the specialist skill.

---

## The game in one screen

- **Engine:** Godot **4.7.2** standard (not .NET), GDScript only, Forward+, `viewport/hdr_2d=true` (neon glow comes from colours above 1.0), `default_texture_filter=0` (nearest), 1920×1080 `canvas_items`/`expand`. **No TileMap**: `WorldRenderer` draws tiles.
- **Loop:** title (`scenes/main.tscn`) → hub (`scenes/hub/hub.tscn`, `src/world/hub_menu.gd`) → battle (`scenes/battle/battle.tscn`, `src/grid/battle_map.gd`) → rewards → hub. Exploration: `scenes/world/explore.tscn` (`src/world/explore_scene.gd`). Editor: Neon Forge (F1, `scenes/editor/neon_forge.tscn`).
- **Pattern:** autoload singletons orchestrate; the global `EventBus` decouples systems. Pure rules and data helpers are `RefCounted`/static; nodes only for things that draw or own time.
- **Content:** every piece of content is JSON in `data/`, loaded by `ContentDB` into typed `GameResource` subclasses. The Neon Forge edits the same JSON, so every edit is a git diff.

### Autoloads (order from `project.godot`; order matters)
1. EventBus
2. ContentDB
3. ClassLibrary
4. GameManager
5. SaveManager
6. CampaignManager
7. QuestManager
8. SceneManager
9. TransitionLayer
10. CameraManager
11. Cues
12. AudioManager
13. CombatManager
14. DispatchManager
15. ForgeManager
16. VendorSystem
17. UIManager
18. DevConsole

Autoloads have **no `class_name`** (Godot 4.7 rule, `docs/MIGRATION.md`). Input actions are registered in code (`src/core/input_actions.gd`, `InputActions.register()` from `GameManager._enter_tree`), not in `project.godot`.

---

## Routing: which skill to load

| Work | Load |
|---|---|
| World maps, exploration, chunk streaming, regions, encounters, explore↔battle, world saves | `open-world-tactics` (+ `iso-tactics-grid` for grid math) |
| Missions, quests, NPC stages, dispatch, campaign graph, chapter pacing | `mission-architect` (+ `franchise-bible` for names and lore) |
| Running tests, headless checks, JSON validation, determinism, "did I break it" | `godot-verify` |
| CT turn order, damage/hit/crit, statuses, passives, battle loop, RNG, replay | `tactics-combat-core` |
| Classes, abilities, jobs, secondary jobs, cards, microchips, blue magic, progression | `job-ability-system` |
| Enemy behaviour, AI weights, bosses, AI-vs-AI balance | `tactics-ai` |
| Pathing, LoS, cover, heights, projection, facings, `to_grid()` | `iso-tactics-grid` |
| `.gdshader`, status looks, HD-2D post, signage screens | `godot-shader-forge` |
| `vfx.json`, `particles.json`, ability effects, Lattice FX clips | `godot-vfx-forge` |
| `cues.json`, hitstop, camera punch, damage text, juice | `game-feel-polish` |
| Fog of war compute, threaded streaming, GDExtension, profiling budgets | `godot-frontier` |
| Lore, names, factions, Black Doctrine canon and cameo rules | `franchise-bible` |
| Engine-neutral contracts for the Black Doctrine custom engine | `engine-port-contracts` |
| Neon Forge editor panels, ForgeForm widgets, asset intake | `neon-forge-tooling` |
| Lattice clips, PixelMatrix units, emitter lights | `lattice-in-game` |
| UI screen craft and premium look (shared skill) | `design-juice` (shared workflow; do not duplicate it) |
| SFX packages for Godot, audio naming (shared skill) | `godot-sfx-package`, `iso-anim-sfx-sync` (shared workflows) |

---

## Hard rules

1. **Read before you write.** Open the real file and its `##` header (they document schemas) before changing it. Never assume a function signature; grep for it.
2. **Data first.** New content means JSON in `data/` plus `@export` fields on the matching `GameResource`. Never hardcode content ids, numbers or text in scripts when a JSON field could hold them.
3. **One field, every layer.** A new `@export` is automatically loaded (`apply_dict`), saved (`to_dict`) and editable in Neon Forge (`ForgeForm`). Name it to hit ForgeForm's patterns: `*_id` / `*_ids` (`class_id`, `status_ids`, `map_id`, `vfx_id`…) become pickers; `*_path` becomes a file field with preview (see `references/data-pipeline.md`).
4. **EventBus is a contract.** Add a signal only when 2+ systems need it. Use typed parameters, add a comment group, and document it in `references/eventbus-contract.md`. Never emit a signal declared elsewhere by a different name. Run `scripts/eventbus_audit.py` after changing signals; it must report no undeclared uses.
5. **Rules don't call presentation.** New rules code emits EventBus signals or Cues names (`Cues` autoload, `data/cues.json`) and never calls tweens, camera, `hit_flash`, sfx or `Engine.time_scale` directly. Existing violations are listed in `references/known-gaps.md`; don't copy them.
6. **Headless-safe.** Anything that animates checks `CombatManager.animate` (false in tests and autobattle) or lives in a presentation node. Tests run whole battles with `CombatManager.animate = false; CombatManager.autobattle = true`.
7. **Story state is flags.** Persistent narrative and world state goes in `GameManager.story_flags` with namespaced keys (`npc:<id>:met`, `found_<trigger>`, `trig:<map>:<region>:<i>`, `ixstate:<map>`, `<mission>_done`). If you add state outside flags, add it to `SaveManager` (`game`/`campaign`/`dispatch`/`quests` blocks) **and** to the save round-trip test.
8. **4.7 rules:**
   - `FileAccess.store_*` returns bool; check it.
   - `@abstract` is allowed (`GameResource`).
   - Commit `.uid` files.
   - No `class_name` on autoloads.
   - Saves are JSON, never `.tres`.
9. **Static typing everywhere:** `var x := …`, `Array[String]`, `for c: Dictionary in …`, return types on every func. Tabs. `##` header doc on every new file.
10. **Every feature ships with a test:** a `test_<feature>()` in `tests/test_world.gd` or `tests/test_suite.gd` using `check(cond, msg)`. Then run the `godot-verify` gate.
11. **Never move originals:** assets are copied and indexed (`ForgeStore.import_file`, `AssetRefs.rename`). Never write into the shared Black Doctrine asset folders.
12. **Decisions belong to Brian.** If a choice changes design canon (names, facings, tile scale, formulas, tone), write `ASK BRIAN:` with the options and stop that branch. Brian's calls are logged in `docs/design/ROADMAP.md`; check there first.

---

## Open decisions (ASK BRIAN; never pick silently)

- **Facings:** code is cardinal (`IsometricGrid.DIRECTIONS`, `Unit` facing). ROADMAP and art say 4 diagonals (Black Doctrine uses NW/NE/SE/SW).
- ~~**Tile scale**~~ **SETTLED:** stay 128×64; 64×32 art is upscaled by the renderer.
- ~~**Veil vs Viel**~~ **SETTLED:** "Veil".
- **The look (Brian, non-negotiable):** tilt-shift everywhere, dark wet neon through fog and bloom. Any look change ships only after Brian sees a before/after.
- **Lattice `holds` unit:** game reads values >10 as ms; `docs/design/LATTICE_CLIP_FORMAT_GUIDE.md` says tick multipliers.
- **Progression model:** `unlocks_mission_ids` graph (used) vs `GameData.mission_sequence` (exists, unused).
- **Black Doctrine's current tech stack:** the Lattice guide cites TypeScript paths (`src/game/entity-layer.ts`), which suggests a web build. Confirm before writing port contracts.

---

## Workflow for any change

1. Run `scripts/repo_facts.py`; skim `references/known-gaps.md`.
2. Identify the owning system(s) with the routing table and load that skill.
3. For more than 2 files or any new signal/field/save key, fill `templates/change-plan.md` (what, where, data, signals, save, tests, ASK BRIAN items).
4. Implement data first (JSON + `@export`), then rules, then presentation (cues/vfx), then Forge exposure if needed.
5. Add or extend the test.
6. Run the `godot-verify` gate (`compile_all.gd` → `run_tests.gd` → `validate_data.py`).
7. Update docs: the owning `docs/design/*.md` section, the README test count if it changed, and `ROADMAP.md` "Built <date>" if it's a roadmap item.

---

## Anti-patterns (seen or tempting here)

- Adding a TileMap, a second grid class, or a second currency (MIGRATION.md documents why the originals were rewritten: three incompatible grids, three currencies).
- `class_name` on an autoload. Autoloads calling each other in `_init` (order dependence).
- Calling `Engine.time_scale = …` (Cues owns time; see `game-feel-polish`).
- New RNG: `RandomNumberGenerator.new()` or `randf()` inside rules. Use the battle rng (`CombatManager.rng`); see `tactics-combat-core`.
- Saving with `ResourceSaver`/`.tres`.
- Logic only reachable from UI buttons. `hub_menu.gd` tabs call the same systems ("nothing here is throwaway logic"); keep it that way.
- Editing `legacy/original_gd/` (ignored by Godot via `.gdignore`; reference only).
- Inventing canon names. Load `franchise-bible`.
- Treating a "planned" idea in `BIG_IDEAS.md` as built. Check its status tag (BUILT / HOOKED / NEW / seed).

---

## Done checklist

- [ ] `repo_facts.py` was run this session; facts in the plan match it
- [ ] Data in `data/*.json` and `@export` fields; no hardcoded content
- [ ] New/changed signals documented; `eventbus_audit.py` clean (exit 0)
- [ ] Rules emit signals/cues; no direct presentation calls in rules
- [ ] New persistent state is in flags or in SaveManager with a round-trip test
- [ ] Static types, tabs, `##` headers, `class_name` (non-autoload)
- [ ] Test added; `godot-verify` gate green (or failures explained as missing-art only)
- [ ] Docs updated (design doc section, README count, ROADMAP)
- [ ] Every design-canon choice surfaced as `ASK BRIAN`
