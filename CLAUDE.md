# Beyond: The Neon Void: notes for Claude

Cyberpunk turn-based tactics RPG, a spiritual successor to Final Fantasy Tactics, set in the world of **The Black Doctrine**. Godot **4.7.2** standard, GDScript only.

## The look (Brian's call, non-negotiable)
- Blade Runner-esque: dark, wet, lit by neon diffused through fog and smoke, with bloom and glow.
- **Tilt-shift stays everywhere, in every zone.** It's a core design choice. HD detail and tilt-shift together, never one or the other.
- Improving the current look is welcome (detail, ambient effects, juice, menus that pop). **Any change that alters the look needs a before/after screenshot for Brian before it's committed.** Bug fixes that restore the intended look are fine.
- Later zones can look different; the starting area is the noir neon city.

## Always
- Load the `neon-void-architect` skill first (`.claude/skills/`), then the specialist skill for the task (its routing table).
- Run `python3 .claude/skills/neon-void-architect/scripts/repo_facts.py .` (Windows: `py -3`) at session start. Trust it over memory.
- **Data first:** content is JSON in `data/`, loaded by `ContentDB` into `GameResource` subclasses; Neon Forge (F1) edits the same files. New field means an `@export` var (it becomes loadable, saveable and Forge-editable automatically).
- **EventBus** (`src/autoload/event_bus.gd`) is the contract between systems. Rules emit signals or `Cues.fire(...)` names; they never call tweens, camera, sfx or `Engine.time_scale` directly.
- **Headless-safe:** respect `CombatManager.animate`. Tests run battles with `animate=false, autobattle=true`.
- Persistent state goes in `GameManager.story_flags` (namespaced keys) or in SaveManager with a round-trip test.
- Static typing, tabs, `##` file headers, `class_name` on everything except autoloads.
- Every feature gets a `test_<feature>()` in `tests/test_world.gd` or `tests/test_suite.gd`.
- Brian prefers our own systems over third-party ones.

## Verify before saying done
`bash .claude/skills/godot-verify/scripts/verify.sh .` (Windows: `powershell -ExecutionPolicy Bypass -File .claude/skills/godot-verify/scripts/verify.ps1`).
Gates: preflight, import, data (`validate_data.py`), compile (`tests/compile_all.gd`), tests (`tests/run_tests.gd`), replay (seeded determinism + win rates).

## PixelLab spending (Brian's rule, 2026-11-06)
- Every PixelLab batch starts with ONE character: generate, then look at the full animations frame by frame against the character's standing poses (outfit, weapons, head, silhouette) and send Brian the GIFs. Nothing more is generated until he approves.
- Every batch has a credit ceiling Brian sets; stop and report before going over it.
- Never delete a PixelLab take (keep them as a kit; pin the preferred take per facing).
- Report real credit use (balance before/after) after every step.

## Never
- TileMap, a second grid, a second currency, `.tres` saves, `class_name` on autoloads.
- New `RandomNumberGenerator.new()` in rules code (use `CombatManager.rng`).
- Moving, renaming or editing anything in the shared Black Doctrine asset folders: copy only.
- Editing `legacy/original_gd/` (reference only, `.gdignore`d).
- Inventing canon names or lore. Mark proposals `[BNV PROPOSAL]`; canon lives in `docs/lore/LORE_DIGEST.md`.

## Paid generation (PixelLab, ElevenLabs): Brian's credits
- **Nothing that spends credits runs without Brian's go for that exact step,** with the cost shown first. No batches or loops.
- **One at a time:** generate one character / animation / facing, then **look at every frame yourself** (open the images, a contact sheet beside the previous facings) for identity, proportions, offset and pose consistency. Show Brian the sheet. Only then ask for the next step.
- **Stop on the first bad result** and report it. Never retry or "fill in" automatically.
- Log the real cost from the account balance before and after each step.

## Settled (Brian's calls)
- Tiles stay **128×64** (v2 maps); 64×32 art is upscaled by the renderer.
- **Veil** (not Viel). Veil: a public republic over a hidden monarchy. High Oracle Nyra: the Doctrine's hidden dream-writer. The managed war is canon. Kade is the shared family name of the Lantern Wards.
- Overworld mounts ride on world maps only unless a map opts in.
- No separate diorama art style for scenes: staged moments are built in-engine (maps, cutscenes, our interface). The tilt-shift HD-2D look stays.
- The interface look lives in `data/ui_theme.json` (NeonTheme reads it; Lattice edits it). Change values there, not in code.

## ASK BRIAN (open decisions; do not pick)
Facings (cardinal in code vs 4 diagonals in art) · Lattice `holds` unit · progression model (`unlocks_mission_ids` vs `GameData.mission_sequence`) · AI using both AP (balance) · sleep breaking on damage · `difficulty_modifier` meaning · defeat in a street battle · XP for KO'd units.

## Docs to read before design work
`docs/design/ROADMAP.md` · `BIG_IDEAS.md` · `WORLD_FORMAT.md` · `TACTICAL_MASKS.md` · `docs/lore/LORE_DIGEST.md` · `docs/WHILE_YOU_WERE_OUT.md`.
