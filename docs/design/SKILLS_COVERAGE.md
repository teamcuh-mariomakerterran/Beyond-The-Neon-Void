# Grok's skills (batch 1) vs the game: coverage

Installed in `.claude/skills/` (9 skills). Every item they describe, and where it stands.
**HAVE** = in the game · **NEW** = built 2026-10-16 from the skills · **BRIAN** = waiting on a decision · **ART** = waiting on assets · **NEXT** = planned.

## neon-void-architect (architecture, EventBus, data, conventions)
| Item | Status |
|---|---|
| Autoload map, EventBus contract, data pipeline, conventions | HAVE (followed) |
| Known gaps list | NEW: status section at the top (what's fixed since the snapshot) |
| CLAUDE.md for the repo | NEW (with the look rule and settled decisions) |
| Open EventBus hooks with no listener | NEW: character_leveled, class_unlocked, ability_unlocked now drive toasts; ability_charging drives cast markers |

## godot-verify (the gate)
| Item | Status |
|---|---|
| verify.sh / verify.ps1: preflight, import, data, compile, tests, replay | NEW, green (accepts `legacy/.gdignore`) |
| validate_data.py + campaign validator | NEW: 0 errors (found the spawn overlap, an unreachable mission, silent music) |
| Seeded replay determinism | NEW: 0 mismatches across all missions |

## open-world-tactics
| Item | Status |
|---|---|
| Chunk streaming, lazy grids, big-map stubs | HAVE |
| Return to the same map/cell after battles, saved | HAVE |
| In-game entry to exploration | HAVE (hub STREETS tab) |
| Visible vs random encounters | NEW: visible roaming threats by default (wander, chase, respawn on the world clock); random kept per region |
| Encounter missions for zones | NEW: enc_doctrine_patrol, enc_marsh_wraiths; Neon Expanse has The Wilds and Glow Marsh |
| Vehicles | HAVE (mounts: hoverbike, submarine) · ART (8-direction mount animations) |
| Fog of war, fast travel, day/night from world_clock | NEXT |
| Defeat in a street battle | BRIAN |

## mission-architect
| Item | Status |
|---|---|
| Unlock graph: every mission reachable | NEW: Shift Change → Relay District |
| Story-gated rumours, news echoes | HAVE (+ News Reacts) |
| Campaign outline / chapters / economy curve | BRIAN (you're writing the story) |
| Mission spec template, Vault Breach as the model | HAVE (templates in the skill) |

## tactics-combat-core
| Item | Status |
|---|---|
| Formulas (hit, crit, damage, cover, height, CT) | HAVE (match the reference) |
| Enemy level growth | HAVE |
| Seeded RNG in rules | HAVE |
| Statuses with no effect | HAVE: verified working (stat_flat / multipliers) |
| Battle log | NEW (user://logs/last_battle.json, `battlelog`) |
| Side-hit damage, AoE height, sleep wakes on hit, XP for KO'd | BRIAN |
| Rules awaiting presentation (#8) | NEXT (refactor) |

## job-ability-system
| Item | Status |
|---|---|
| 49 classes / 201 abilities / passives / cards | HAVE |
| Reaction passives silent | NEW: reaction cue + floating passive name |
| Level / job / ability unlock moments | NEW: milestone toasts |
| `sfx_id` | HAVE (read by Sfx.ability_sound) |
| Docs drift (CLASS_ORDER comment, Sync Blade in CLASSES.md) | NEXT |

## tactics-ai
| Item | Status |
|---|---|
| Utility scorer + 4 presets | HAVE |
| Dodge telegraphed casts | HAVE |
| Sims see the world (anchors, traps headless) | NEW (Layer 0) |
| Use anchors: terminals, sequences, devices, medstations | NEW (Layer 1): Vault Breach sims 0/3 → 3/3 |
| Don't double up on a doomed target | NEW |
| Enemy anchor use, second action, boss phases, difficulty | BRIAN |

## godot-shader-forge
| Item | Status |
|---|---|
| Double-colour bug in status_look | HAVE (fixed with before/after) |
| Same bug in the fog sheet | BRIAN (fixing it thickens all fog; needs a before/after) |
| Glow outside battle | HAVE |
| Recipes: energy shield, cloak refraction, neon outline, holo scan, shard dissolve | NEXT as before/after proposals (look changes) |
| Lint / compile check | NEW: run; 0 failing shaders |

## godot-vfx-forge
| Item | Status |
|---|---|
| Data-driven effects, mapping chain | HAVE |
| Charge telegraph | HAVE |
| Lattice FX flipbook part | NEW: `{"type": "clip", "path": …}`, hit frame drives damage timing |
| Lattice / custom effects for the 88 generic abilities | ART (Lattice library) + NEXT (custom ones for gaps) |
| Anticipation beat, slash primitive | NEXT (look change: before/after) |

## Plugins checked (license-safe)
GodotSteam (MIT): at release. Controller Icons (MIT/CC0): with the controls screen. Input Helper (MIT): maybe. Not needed (we have our own): Phantom Camera, LimboAI, Dialogic/Dialogue Manager, GUT/gdUnit4.
