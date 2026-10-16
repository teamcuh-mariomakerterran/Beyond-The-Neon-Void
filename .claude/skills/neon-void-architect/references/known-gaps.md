# Known gaps and bugs

## Status as of 2026-10-16 (read this first)

The table further down is Grok's 2026-10-07 snapshot. Since then:

**FIXED** (don't re-fix; the code has moved on):
- #1 region music trigger (AudioManager takes paths) · #2/#3 battles from explore return to the same map/cell, saved · #4 vendor stock saved · #5 RNG leaks (loot, passives, Interactions in battle on CombatManager.rng) · #6 enemy level applies class growth
- #7 one time-scale owner (VFX.hit_stop pushes onto the Cues stack) · #9 find_loot targets can be objects/anchors · #10 chunk streaming (32×32 chunks, LOD, lazy grids, big-map stubs) · #11 explore backdrop is a screen-sized layer
- #12 AI: dodges telegraphed casts (threat map), **uses anchors** (AIAnchors: terminals, sequences, devices, medstations; player-side AI; enemy use behind CombatManager.enemy_anchor_use) · Vault Breach sims 0/3 → 3/3
- #15 partly: hub has a STREETS tab (#21), Neon Expanse has visible encounter zones · #16/#30 sims build format-2 grids with copy_from + Interactions.for_battle (anchors, traps)
- #17 passives in Forge · #20 rumours have required_flag / hidden_flag · #21 hub STREETS tab · #22 battle Interactions on CombatManager.rng (explore keeps its own) · #23 explore objects + loot anchors emit loot_discovered
- #24 mission enemy/guest `ai` and guest `statuses` honoured (spawn facing still hard-coded: facings are ASK BRIAN) · #26 story_chapter advances via mission `ends_chapter`
- #29 steal pays at battle end (CombatManager.spoils, shown on results) · #33 Foreman Grisk is_boss · #34 status_look texture×COLOR fixed (fog sheet's copy left on purpose: fixing it doubles fog density; Brian decides with a before/after)
- #35 exploration gets the battle glow (NeonTheme.glow_environment) · #36 charged-cast footprints shown on the map (HighlightManager sticky layers) · #37 fast battles + #39 settings screen and persistence (SettingsFlags.save/load_saved)
- #38 vault relay double cue · #40 battle grid copy (IsometricGrid.copy_from)
- Also: battle music ids resolve through data/music.json (they matched no file); reaction passives have a cue; level/job/ability milestones have toasts; Ability.sfx_id IS read (Sfx.ability_sound); statuses focused/blinded/identity_loss/hidden/dualcast/berserk DO work through stat_flat / stat_multipliers (verified).

**STILL OPEN:** #8 rules→presentation awaits · #13 AoE height / side damage (ASK) · #14 campaign content (Brian is writing it) · #18 facings (ASK) · #19 Lattice holds unit (ASK) · #25 difficulty_modifier (ASK what it scales) · #27 XP for KO'd units (ASK) · #28 asleep doesn't wake on damage (ASK) · #31 AI second action (ASK for enemies) · #32 anchor-only turn CT discount (ASK).

---

## Grok's 2026-10-07 snapshot

Fix them when you touch the area, or route around them. Don't re-discover them. Each gap names the skill that owns the fix.

| # | Gap | Where | Owner skill |
|---|---|---|---|
| 1 | Region `music` trigger passes an `AudioStream` to `AudioManager.play_music(music_id: String, …)`, a type error at runtime | `src/world/explore_scene.gd` `run_trigger("music")` vs `src/autoload/audio_manager.gd:41` | open-world-tactics |
| 2 | Battles started from exploration (random encounter, region `battle` trigger) always return to the **hub** via `CampaignManager.return_to_hub()` | `campaign_manager.gd`, `battle_map.gd` results | open-world-tactics |
| 3 | `CampaignManager.current_explore` is not saved (`get_campaign_data` omits it) | `campaign_manager.gd` | open-world-tactics |
| 4 | `VendorSystem.stock_left` is not saved | `vendor_system.gd`, `save_manager.gd` | neon-void-architect / mission-architect |
| 5 | RNG leaks: `Passives._roll` falls back to `RandomNumberGenerator.new()`; `CampaignManager.process_mission_completion` loot uses an unseeded RNG | `passives.gd`, `campaign_manager.gd` | tactics-combat-core |
| 6 | Mission enemy `level` override doesn't apply class growth (only HP/MP scale) | `unit.gd` `setup` | tactics-combat-core |
| 7 | Two time-scale owners: `VFX.hit_stop` writes `Engine.time_scale` directly; Cues has its own override stack | `src/vfx/vfx.gd`, `src/autoload/cues.gd` | game-feel-polish |
| 8 | Rules await presentation: `CombatManager._execute` awaits `map_node.play_ability_fx`; `Unit.take_damage` calls `hit_flash`; kinetic/terrain abilities emit `camera_shake`/`play_sfx` | `combat_manager.gd`, `unit.gd`, `abilities/*` | tactics-combat-core |
| 9 | `ContentDB._map_prop_exists` only checks v1 `props`, not v2 `objects`/`anchors` | `content_db.gd` | mission-architect |
| 10 | No chunk streaming: `WorldRenderer.rebuild()` builds all StripViews/objects/particles at once; largest map 28×28 | `world_renderer.gd` | open-world-tactics |
| 11 | 60,000×60,000 px `ColorRect` backdrop | `explore_scene.gd:45-47` | open-world-tactics |
| 12 | AI: no charged-cast (CT) prediction, ignores anchors, no team coordination, skips abilities with `charge_ticks > 12` | `ai_behavior.gd` | tactics-ai |
| 13 | AoE footprint ignores height; side hits give no damage bonus (only hit chance) | `ability.gd`, `damage_calculator.gd` | tactics-combat-core (ASK BRIAN before changing) |
| 14 | Campaign content thin: 3 missions, m02 unlocks nothing; `GameData.mission_sequence` unused | `data/missions.json`, `src/data/game_data.gd` | mission-architect |
| 15 | Hub locations in `neo_kowloon_hub` have empty `target_map`; `neon_expanse` "Dead Server Farm" has no target | `data/maps/*.json` | open-world-tactics |
| 16 | Battle tests only cover v1 maps (`supply_works_dock`, `gutter_alley`) | `tests/test_suite.gd::test_battles` | godot-verify |
| 17 | `passives` bucket is not in Neon Forge `SECTIONS` (not editable in the Forge UI) | `src/tools/neon_forge.gd` | neon-forge-tooling |
| 18 | Facings cardinal in code vs diagonal in art and ROADMAP | `isometric_grid.gd`, `unit.gd` | iso-tactics-grid (ASK BRIAN) |
| 19 | Lattice `holds` unit ambiguity (ms vs tick multiplier) | `lattice_clip.gd`, `LATTICE_CLIP_FORMAT_GUIDE.md` | lattice-in-game (ASK BRIAN) |
| 20 | Rumours have no `required_flag` (News Reacts needs it) | `data/rumors.json` | mission-architect |
| 21 | **No in-game entry to exploration.** `CampaignManager.explore(...)` is only called from the Forge ("Play here"), the dev console `tp`, and `explore_scene.gd` itself. The hub menu and title screen never open a world map | `hub_menu.gd`, `main_menu.gd` | open-world-tactics |
| 22 | More unseeded RNGs: `Interactions.rng := RandomNumberGenerator.new()` (trap disarm rolls), `ExploreScene._rng` (encounters) | `interactions.gd`, `explore_scene.gd` | tactics-combat-core / open-world-tactics |
| 23 | `find_loot` quest objectives only progress from battle-map `props` with a `loot_item_id` (`InteractionTrigger` emits `loot_discovered`). Explore `objects` set `looted:<map>:<id>` and anchor `loot` emits nothing, so a `find_loot` pointing at either never completes | `quest_manager.gd`, `interaction_trigger.gd`, `explore_scene.gd` | mission-architect |
| 24 | Per-enemy `ai` in `missions.json` (and the Forge `ai` dropdown) is ignored. `battle_map._spawn_units` never reads it, so the AI comes from `CharacterData.ai_behavior`. Guest `statuses` are also ignored. Spawn facing is hard-coded: enemies face (-1,0), players (1,0) | `battle_map.gd:197-230` | tactics-ai / mission-architect |
| 25 | `MissionResource.difficulty_modifier` is declared but never read | `mission_resource.gd` | tactics-combat-core |
| 26 | `GameManager.story_chapter` is never advanced (only reset/load), so quest `min_chapter > 1` can never unlock. Mission `chapter` is metadata only | `game_manager.gd`, `quest_manager.gd:62` | mission-architect |
| 27 | `conclude_battle` treats every valid PLAYER unit as a survivor, so KO'd units get XP too | `combat_manager.gd:492` | tactics-combat-core (ASK BRIAN) |
| 28 | Statuses with no mechanical effect: `focused`, `blinded`, `identity_loss`, `dualcast`. `hidden` doesn't affect hit chance, `asleep` doesn't wake on damage, `berserk` doesn't force attacks | `status_effects.json`, `damage_calculator.gd`, `unit.gd` | tactics-combat-core |
| 29 | `steal_chip`/`steal_coins` specials pay `GameManager` immediately, mid-battle and in headless sims | `ability.gd _resolve_special` | tactics-combat-core |
| 30 | Headless battle sims skip the world layer. The suite's `_run_battle` loads format-2 maps with raw `load_dict` (flat grid, walls lost), and no sim creates `Interactions`, so anchors, doors and traps don't exist and AI-vs-AI can't finish anchor-gated missions | `tests/test_suite.gd:_run_battle`, `battle_map.gd:_build_grid` | godot-verify, tactics-ai |
| 31 | AI takes one action per turn. With `max_ap` 2, about 1 AP per AI turn goes unused, while a human can act twice | `combat_manager.gd:_ai_turn`, `ai_behavior.gd:plan_turn` | tactics-ai |
| 32 | `Interactions.interact` spends AP but doesn't set `has_acted`. An anchor-only turn is charged CT as "no action" (80/60 instead of 100) | `interactions.gd:interact`, `turn_queue.gd:ct_cost` | tactics-combat-core (ASK BRIAN: intended discount?) |
| 33 | No character sets `is_boss: true` (including `foreman_grisk`). `@boss` anchor targets and any boss-aware logic hit nobody | `data/characters.json`, `interactions.gd:_targets` | mission-architect, tactics-ai |
| 34 | `texture(TEXTURE, uv) * COLOR` in canvas_item fragments applies the texture twice (Godot 4 fragment `COLOR` already includes it), so rgb and alpha get squared. Units darken and lose soft alpha from their first status for the rest of the battle (`Unit` keeps the material); fog alpha is squared | `status_look.gdshader:67,70,71`, `particle_factory.gd:949` (FogSheet) | godot-shader-forge |
| 35 | Only `BattleMap` creates the HDR glow `WorldEnvironment`. Exploration and the World Painter have no bloom, so neon looks different outside battle and the painter preview misleads | `battle_map.gd:_setup_environment`, `explore_scene.gd`, `forge_world_painter.gd` | godot-shader-forge |
| 36 | Charged casts have no on-map telegraph. Nothing listens to `EventBus.ability_charging`, and the target cells of `pending_casts` aren't marked. Players see only the caster's `charging` pulse and an icon in the HUD turn strip | `battle_hud.gd:325`, `battle_map.gd` | godot-vfx-forge, game-feel-polish, tactics-ai |
| 37 | `SettingsFlags.fast_battles` is declared but never read, so there's no battle-speed option despite the flag | `src/core/settings_flags.gd` | game-feel-polish, godot-vfx-forge |
| 38 | Vault Breach relay 4 (`anc_vault_breach_demo_4`) has `unshield` **and** an explicit `cue shield.down`. `unshield` already fires the cue, so it plays twice, and the second headline names the player who flipped the switch ("ROOK DANNICK: SHIELD DOWN"). Box-verified | `data/maps/vault_breach_demo.json`, `interactions.gd:371` | game-feel-polish, mission-architect |
| 39 | Nothing ever writes `SettingsFlags` (`reduce_motion`, `fast_battles`, `auto_additions`, `icon_style`). There's no settings screen or persistence, so the existing reduce-motion gating is unreachable | `src/core/settings_flags.gd` | game-feel-polish |
| 40 | Format-2 battle grids are built by a `to_dict()`→`load_dict()` round trip that re-applies terrain defaults. A painted override that sets a value back to the code default is lost in battle (for example a walkable bridge over `water`, or `cover:0`/`cost:1` on `rubble`). Latent: no shipped map hits it. Box-verified with a candidate map; fix in `iso-tactics-grid/templates/battle_grid_copy_from.diff` | `battle_map.gd:139`, `isometric_grid.gd load_dict` | iso-tactics-grid |

Note on #33: the `boss.intro` and `kill.boss` cues (`cues.gd:131-142`) are wired, so setting `is_boss` lights them up immediately.

Box-run evidence (Godot 4.7.2 headless on a copy of the snapshot, 2026-10-07):
- `compile_all.gd`: 135 files, 0 failures. This needs `legacy/original_gd/.gdignore` present; without it the legacy `UnitStats` class collides and the autoloads fail to compile.
- `run_tests.gd` core suite: **641 passed, 0 failed**; AI-vs-AI player side won 19/36.
- `run_tests.gd` world suite: **334 passed, 9 failed**. All 9 failures are missing art in the snapshot (icons, Lattice strips, demo world art), not logic.
