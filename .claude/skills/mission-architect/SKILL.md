---
name: mission-architect
description: >-
  Use when designing, drafting or wiring Beyond The Neon Void campaign content:
  story or side missions (data/missions.json), quests and quest chains
  (quests.json), dispatch errands (dispatch_missions.json), rumours/news,
  NPC interaction stages and dialog that gate or hint missions, map anchors
  that start battles or form mission puzzles (Vault Breach style), campaign
  pacing, the unlock graph, story flags and rewards. Also use when asked "is
  every mission reachable", "draft act 1", or "make a mission like Vault Breach".
  Load neon-void-architect first; franchise-bible for canon and voice.
---

# Mission Architect

Brian is drafting the campaign now. This skill turns story beats into **cohesive
missions**: each one teaches or tests a mechanic, the world hints at it, the news
echoes it, and it unlocks the next. Every id it references has to exist.

The model is **Vault Breach** (`demo_vault_breach` on `vault_breach_demo`): a
shielded boss gated by a 3-relay sequence, cloaked ambushers countered by a smoke
generator, a hidden tripwire, a hidden stash, a greed objective, and an NPC in
the neighbouring block who hums the answer.

Load as needed:
- `references/vault-breach-anatomy.md`: the model mission, layer by layer, and the rules it teaches
- `references/schemas.md`: every field of missions, quests, dispatch, rumours, NPCs; flag naming; win/lose semantics
- `references/anchors-and-actions.md`: anchor kinds, the 30 action verbs + arg formats, cue ids, NPC stages, dialog graph
- `references/campaign-pacing.md`: current reward numbers, Brian's arc, pacing rules, progression model (ASK BRIAN)
- `templates/mission-spec.md`: one-page design brief per mission (fill this **before** JSON)
- `templates/campaign-outline.md`: act/chapter table, side content, unlock graph, franchise checks
- `templates/{mission,quest,dispatch,npc-stages}.template.jsonc`: commented entries that match the schemas
- `scripts/validate_campaign.py`: cross-reference + reachability validator (the gate for this skill)
- `scripts/unlock_graph.py`: Mermaid/DOT graph of missions, quests, maps, NPCs and flags
- `scripts/jsonc_append.py`: strip comments from a filled template and append it to a data array (refuses duplicate ids)

Cross-skill:
- Map painting, exploration and the return-to-world flow belong to `open-world-tactics`.
- Combat rules, statuses and win checks belong to `tactics-combat-core`.
- Enemy behaviour belongs to `tactics-ai`.
- Briefing and dialog voice, plus canon, come from `franchise-bible`.
- Mission SFX and cue sounds come from the shared `godot-sfx-package`, and boss intro and victory juice from `design-juice` and `game-feel-polish`.

---

## When to run
- Any edit to `data/missions.json`, `quests.json`, `dispatch_missions.json`, `rumors.json`, `npcs.json` dialog/stages, or map `anchors` that run `battle`/`flag`/`news`/`unshield`.
- Writing a campaign outline, a chapter, or a single mission or quest.
- "Why can't I start mission X", "this quest never completes", "what does m02 unlock".

Not for: painting terrain or streaming (`open-world-tactics`), new statuses or abilities (`tactics-combat-core`, `job-ability-system`), cutscene authoring (PARALLAX tool, out of scope).

---

## Ground truth (verify with `python scripts/validate_campaign.py <repo>`)
- **Content today:** 3 missions (`m01_the_brew_plan` → unlocks `m02_shift_change`; `demo_vault_breach` started by an anchor on `neon_block_demo`), 5 quests (Otto, Hic, Benno, Sly ×2 chain), 7 NPCs (Ma Rivet uses `fetch` stages), 6 dispatch errands with rumour ids. The validator reports 0 errors and 4 warnings on the snapshot.
- **Flow:** hub mission board → `CampaignManager.start_mission(id)` → `BattleMap` → `CombatManager._check_battle_end` → `CampaignManager.process_mission_completion` (rewards, flags, unlocks, clock +6 h, `mission_completed`) → `return_to_hub()`.
- **Gaps that bite mission design** (numbers refer to `neon-void-architect/references/known-gaps.md`):
  - #21 No in-game entry to exploration, so missions behind map anchors (Vault Breach) are reachable only through Forge/dev console today.
  - #23 `find_loot` objectives only progress from **battle-map `props` with `loot_item_id`**. Explore objects and anchors never count.
  - #24 Per-enemy `ai` is ignored, and so are guest `statuses`. Spawn facing is hard-coded (players face +x, enemies −x), so put players on the west.
  - #25 `difficulty_modifier` is unused. Enemy `level` adds HP/MP only (no stat growth).
  - #26 `GameManager.story_chapter` never advances, so `min_chapter > 1` quests lock forever.
  - #20 Rumours have no `required_flag`.
  - The loot roll in `process_mission_completion` is unseeded.
  - 3 mission music files are missing from `assets/music/`.

---

## Hard rules
1. **Spec first, JSON second.** Fill `templates/mission-spec.md` (purpose, mechanic, tells, echoes) and show it before writing data. A mission without a stated mechanic and a world tell is not done.
2. **Every reference must resolve:** map ids, character ids, item ids, status ids, loot tables, cutscene paths, music files, NPC ids, quest ids, anchor ids, cue ids. Run `validate_campaign.py` after every data edit. **0 errors** before you say done; explain every warning.
3. **Every mission is reachable** from the start (`m01_the_brew_plan`) through mission/quest unlocks, NPC `fight_mission_id`, or a map anchor `battle` action on a reachable map. `demo_*` missions are exempt but get flagged.
4. **Every flag that is read is set**, and every mission sets at least one flag in `story_flags_on_win` that something reads (news, NPC `requires_flag` line, quest gate, next briefing).
5. **Use the vocabulary that exists.** Win: `defeat_all | defeat_target | survive | reach_cell`. Lose: `party_wiped | leader_down | protect | time_limit`. Quest objective types: `complete_mission | collect_item | talk_to | find_loot | flag | defeat_character`. Anchor kinds and actions: only those in `Interactions.KINDS`/`ACTIONS`. A new verb is a code change in `src/world/interactions.gd` (and its `ACTION_HINT`) with a test, not just data.
6. **Design around the gaps, don't paper over them.** Use `flag` objectives instead of `find_loot` for anchors and explore objects. Don't rely on `ai`, `difficulty_modifier`, enemy level scaling or `min_chapter > 1` until the code is fixed. If the mission needs one of those, fix the code under the owning skill first.
7. **Generated maps are edited at the source.** `vault_breach_demo` comes from `tools/demo/make_tactics_demo.py`, so change the generator and re-run it. Never hand-edit its JSON.
8. **Puzzle missions must be fair and must not hard-lock:**
   - Every gate (shield, door, cloak) has a counter on the map.
   - Every counter has a tell (briefing, NPC line, glyph).
   - Wrong inputs cost HP or time, never the run.
   - `defeat_target` and `survive` also end on enemy wipe (engine behaviour).
9. **The party needs room:** `spawns.player` count ≥ `max_party_size`, on walkable cells, west side. `protect` and `leader_down` targets must actually deploy (guests, or a party member guaranteed to be in `active_party`).
10. **Voice and canon:**
    - Briefings and NPC lines use the house voice: short, deadpan, awkward humour, British spellings ("rumour", "authorisation").
    - Black Doctrine characters appear only as NEWS, RUMOR or EAVESDROP, with at most 1–2 cameos.
    - The war stays unresolved.
    - Load `franchise-bible`. New names avoid the surnames Vale, Voss, Sol, Quill and Mourn.
11. **Don't decide what Brian decides.** These are **ASK BRIAN** items; write the question into the spec and stop that branch:
    - the progression model
    - chapter structure
    - Veil vs Viel spelling
    - the defeat-from-world rule
    - economy curve numbers
    - new enemy concepts marked "awaiting approval"
    - cameo picks
12. **Never write test or scratch content into `data/`.** Use `user://content` (ContentDB override folder) or a temp copy for experiments.

---

## Workflow: one new mission
1. Read `references/vault-breach-anatomy.md` and the neighbouring missions in `data/missions.json` (rewards, levels).
2. Fill `templates/mission-spec.md`:
   - beat and mechanic
   - map (existing or new)
   - opposition table
   - win/lose
   - anchors
   - tells
   - echoes
   - rewards (justified against `campaign-pacing.md`)
3. Map:
   - **New map:** paint it in the World Painter (format 2), with anchors in the MASKS tab.
   - **Generated map:** extend the generator script.
   - Check spawns and cover masks.
   - Run `open-world-tactics/scripts/world_audit.py --map <id>`.
4. Copy `templates/mission.template.jsonc`, fill it, then run `python scripts/jsonc_append.py my_mission.jsonc <repo>/data/missions.json`.
5. Wire the entry point: an unlock from the previous mission or quest, an NPC `fight_mission_id`, or an anchor `battle <id>` on a reachable map.
6. Wire the echoes:
   - an NPC `dialog` line with `requires_flag: "<id>_done"`
   - an eavesdrop hint
   - a `news` action or rumour
7. Run `python scripts/validate_campaign.py <repo>` and get 0 errors.
8. Run `python scripts/unlock_graph.py <repo>` and paste the graph into the PR notes.
9. Run the `godot-verify` gate (compile, tests, `ContentDB.validate()`, the seeded battle sim on the new mission) and record the win rate.
10. Play it: in the Forge, select the map and press **F5** ("Play here"), or use the hub board if it's unlocked.

## Workflow: a quest or quest chain
1. Pick the giver from `npcs.json`. Add the quest id to the giver's `quest_ids`, or use stages (`after_talk: "quest"` + `offer_quest_id`).
2. Use `templates/quest.template.jsonc`. Chains share a `chain_id`, and each step sets `next_quest_id` plus `prerequisite_quest_ids`.
3. Choose objective types that progress with today's code (see rule 6).
4. Write `accept_text`, `progress_text` and `complete_text` as three beats of a joke that nudges the player.
5. Validate and graph.

## Workflow: a dispatch errand
1. Use `templates/dispatch.template.jsonc`.
2. Set `difficulty` relative to the existing errands (salvage 25). Success chance follows `dispatch_manager.gd:47`.
3. Link 1–3 rumour ids. Rumours are where the Black Doctrine war lives.
4. Validate.

## Workflow: drafting an act or chapter outline
1. Copy `templates/campaign-outline.md`. Seed it with the existing m01 and m02 rows.
2. Follow the pacing rules in `references/campaign-pacing.md`:
   - a mechanic mission every 3–4
   - varied win/lose conditions
   - a hub beat between missions
   - a graph, not a line
3. Mark every invented proper noun and every canon touch as **proposal**, and run the franchise checks.
4. Deliver the outline and the ASK BRIAN list. Only write data after Brian picks.

---

## Anti-patterns
- A mission whose only design is "defeat_all with more enemies".
- Puzzle answers that exist only in the briefing. Put the tell in the world (NPC, glyph, news).
- `find_loot` targeting an anchor or explore object (never progresses).
- Setting `ai: "cautious"` on an enemy and expecting it to matter.
- Raising enemy `level` as the difficulty knob.
- `min_chapter: 2` gates.
- Flags named ad hoc (`done2`, `flagA`). Follow `schemas.md` naming (`<mission>_done`, `<npc>_<fact>`).
- Unlocks that form a cycle or orphan a mission.
- Hand-editing generated map JSON.
- Briefings that explain UI ("press A to…") instead of speaking in-world.
- Black Doctrine heroes on the battlefield, or resolving the war.
- Inventing the Digital Queen's or the digimancer's plot details as canon. Mark them `[BNV PROPOSAL]`.
- Copying lore paragraphs into this skill. Point to `docs/lore/LORE_DIGEST.md` instead.

---

## Done checklist
- [ ] `templates/mission-spec.md` (or outline) filled; ASK BRIAN items listed
- [ ] `validate_campaign.py` → 0 errors; every warning explained
- [ ] New mission reachable (shown in "missions reachable") and graph pasted
- [ ] Every new flag both set and read; every mission sets ≥1 flag that something reads
- [ ] Spawns ≥ party size on the west side; protect and leader targets actually deploy
- [ ] Puzzle gates each have a counter and a tell; wrong input never hard-locks
- [ ] Voice and canon checked against `franchise-bible`; proposals tagged
- [ ] `godot-verify` gate green (compile, tests, `ContentDB.validate()`, seeded sim win rate noted)
- [ ] Played once via Forge F5 or the hub board
