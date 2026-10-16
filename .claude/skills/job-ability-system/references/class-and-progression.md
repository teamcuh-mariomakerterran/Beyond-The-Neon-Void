# Classes and progression (data + `class_library.gd` + `progression_system.gd` + `job_handler.gd`)

## Counts (snapshot)
- `data/classes.json`: **49** classes. **37 playable** (`playable: true`); 12 enemy/chassis classes have `playable: false`.
- `ClassLibrary.CLASS_ORDER`: **37** ids, the menu order. Its comment says "35", and `docs/design/CLASSES.md` says "36 playable" and has no Sync Blade section. **Docs drift: fix the comment and the doc when touching classes.**
- Tiers: 1 starters, 2 advanced, 3 elite, 4 secret (`unlock_flag` `secret_<id>`). Sync Blade is unlocked by flag `found_stardust` (key item `key_stardust`).

## ClassResource fields
| group | fields |
|---|---|
| identity | `id, display_name, description, role (MELEE/RANGED/SUPPORT/UTILITY/TANK/SPECIAL), tier, icon_path, is_hidden, playable, element_modifiers{type: mult}, uses_deck` |
| base stats | `base_hp, base_mp, hp_growth, mp_growth, base_speed, move, jump, max_ap` |
| scaling | `multipliers{strength, agility, intelligence, vitality}` (× raw primaries), `growth{…}` (+ per level-up) |
| equipment | `weapon_types[], specialty_weapon_types[]` (×1.15 and `SPECIALTY_XP_MULT`), `armor_types[]` |
| abilities | `innate_ability_ids[]` (always available in this job), `learnable_ability_ids[]` (bought at terminals) |
| unlocking | `unlock_requirements{class_id: class_level}`, `unlock_flag` |

## Progression
- **Character XP:** `ProgressionSystem.add_xp`, where `xp_to_next(L) = 100 + 20(L−1) + 2(L−1)²`. Each level calls `UnitStats.level_up(cls)`, which adds the **current** class's `growth` to the primaries. Emits `character_leveled` (no listener yet).
- **Class XP:** `add_class_xp(character, amount)` credits only the **current `class_id`**. Mission completion gives `xp_reward × 0.8`.
  - Thresholds `[0, 0, 200, 400, 700, 1100, 1600, 2200, 3000]` by level, so `CLASS_LEVEL_MAX = 8`.
  - On a level-up, `_check_class_unlocks` unlocks any class whose requirements are met (`class_unlocked` signal, no listener).
- **Learning:** `learn_ability(character, id)`:
  - Fails for `absorb_only` abilities, an unlocked class requirement, `required_class_level`, or a missing `requires_item_id` (data disks).
  - Otherwise spends `chip_cost` microchips.
  - Passives use `learn_passive` (`chip_cost` on the passive, default 3). `equip_passive(slot)` sets `reaction_id`/`support_id`/`movement_id`.
- **Blue learning:** in battle, a hit by a `blue_learnable` ability teaches it to a target whose class lists it (`_try_blue_learn`), and writes it to the roster too.
- **Command list (`JobHandler.get_ability_list`):**
  1. Basic attack, or the deck's playable cards for `uses_deck` classes.
  2. Primary innates.
  3. Learned primary learnables.
  4. Learned **secondary** learnables. **Secondary innates are not allowed.**
- **Specialty weapons:** each unit combines `weapon_specialties` (character) with the class `specialty_weapon_types`.

## Cards and decks (Deck Stacker)
- `data/cards.json` holds `CardResource`, which extends Ability. It adds `rarity (COMMON…LEGENDARY), card_art_path, is_late_game, crafting_materials{}, price`.
- `DeckResource`: `pool` (owned, duplicates allowed), `active` (max 10). **Each copy is playable once per battle** (`spend`, `reset_for_battle`).

## Passives (`data/passives.json`, `src/combat/passives.gd`)
- **Slots:** reaction 6, support 7, movement 6.
- **Fields:** `slot, class_id, icon_path, effect, trigger, chance, params, stat_flat, stat_multipliers, chip_cost`.
- **Effects handled in code:** `counter, nullify_debuff, patch, step_away, overwatch, adrenaline` (reactions); `mp_discount, ap_discount, damage_taken_mult, damage_dealt_mult, range_plus` (support); `pass_through, move_heal` (movement). Plain stat passives use `stat_flat` (Move+1 etc.).
- **Reactions** fire the cue `reaction.<id>`. `data/cues.json` defines neither `reaction.<id>` nor `reaction`, so reactions are silent. Add cues (game-feel-polish).
- **Forge gap:** passives are missing from Neon Forge `SECTIONS` (neon-forge-tooling).

## Additions (Sync Blade)
`addition: {beats: [t0, t1, …], window, per_hit, finisher}`. See tactics-combat-core `formulas.md`. The interactive widget is `AdditionWidget`; AI and headless runs use `auto_hits` (~70%).
