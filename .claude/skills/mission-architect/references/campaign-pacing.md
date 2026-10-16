# Campaign pacing and economy (grounded in current data)

## What exists (numbers to scale from)
| Mission | Enemy levels | Coins | XP | Chips | Loot | Notes |
|---|---|---|---|---|---|---|
| m01 The Brew Plan | 2,2,2,2 (4 units) | 250 | 140 | 2 | loot_supply_works (3 rolls, 20–80 coins) | intro cutscene, unlocks m02 |
| m02 Shift Change | boss 5, others 3 (5 units) | 400 | 220 | 3 | loot_supply_works | defeat_target boss |
| demo Vault Breach | boss 3, others 2 (6 units) | 300 | 160 | 2 | loot_supply_works | puzzle mission |

- Party: 5 starting crew at level 2 (`STARTING_ROSTER`), 500 starting coins, `max_party_size` 5.
- Mission completion: XP to survivors, class XP ×0.8, `world_clock` +6 hours.
- **Known gap:** enemy `level` doesn't apply growth, so higher-level enemies only gain HP/MP. Don't rely on enemy level alone for difficulty until `tactics-combat-core` fixes it. Use composition, statuses (`shielded`, `cloaked`), terrain, and win/lose conditions. **`difficulty_modifier` is declared in `mission_resource.gd` but never read in `src/`**, so it does nothing today.
- AI-vs-AI baseline (box run): the player side wins 19/36 on m01/m02 with random rosters at level 6. Use the `godot-verify` balance sim for new missions.

## Structure Brian has hinted at (README brief, ROADMAP, LORE_DIGEST); confirm before locking
- **Act I, the heist:** the crew plan to blow up a Doctrine munitions Supply Works for 2 extra days off (m01). The Foreman follows them home (m02).
- **The turn:** they fall into a **human essence factory** feeding a Doctrine **digimancer** who wants to awaken the **Digital Queen (QN-0)**.
- **Tone:** "Cheers × cyberpunk × a hint of Fight Club": dark and mature, with awkward humour as the linchpin. "Everything has two truths… and both are likely wrong."
- **Canon guardrails:** Black Doctrine characters appear only as news, rumour or eavesdrop references, plus 1–2 cameos at most. The war stays unresolved. Kestral Omen-Six is the scapegoat for the explosion (`LORE_DIGEST.md`). Load `franchise-bible`.
- **Approved beats (ROADMAP):** Hangover Morning (yes), voice barks (yes), Lying HUD in **one** warped zone only, propaganda through NPC evidence.

## Pacing rules for drafting
1. **Every 3–4 missions, one mechanic-forward mission** in the Vault Breach mould (anchors, sequence, shield or cloak, NPC hint).
2. **Every mission sets a flag** (`story_flags_on_win`) that at least one thing reads: news, rumour, NPC line, quest, or next mission briefing.
3. **Vary win/lose conditions.** Unused today: `survive`, `reach_cell`, `leader_down`, `protect`, `time_limit`. Use them. Escort and protect missions need `guests`.
4. **Hub beat between missions:** a Regulars quest, eavesdrop line or dispatch unlock. The hub is the "Cheers bar". Downtime is where the Essence Ledger idea refills (BIG_IDEAS, HOOKED).
5. **Unlock graph, not a line:** after chapter 1, offer 2–3 parallel missions plus side quests. Keep the graph acyclic; the validator proves reachability.
6. **Economy curve:** grow coins about 1.3–1.6× per chapter and keep chips scarce (2–3 per main mission), since chips buy abilities at terminals. Proposed numbers only: **ASK BRIAN** before writing an economy table into data.
7. **One new enemy idea per chapter**, taken from the BIG_IDEAS proposals. Names marked "awaiting approval" stay proposals until Brian approves.

## Progression model (ASK BRIAN)
Today `unlocks_mission_ids` (missions and quests) drives everything; `GameData.mission_sequence` (`src/data/game_data.gd`) is unused. Options:
- (a) keep the graph and delete `GameData`
- (b) add a `data/campaign.json` with acts and chapters that *reference* missions (metadata only, for UI and pacing) while the graph stays authoritative
- (c) a linear sequence

The recommendation is **(b)**; it keeps the Forge workflow intact.
