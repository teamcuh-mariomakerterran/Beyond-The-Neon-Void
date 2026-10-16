# Mission spec: <id> "<Display Name>"
> Fill this in BEFORE writing JSON. One page. Mark unknowns **ASK BRIAN**.

## 1. Purpose
- Story beat (1 line):
- Mechanic it teaches or tests (1 line):
- Emotional note (awkward humour / dread / payoff):

## 2. Place
- Map id (existing or new):        Size:        Post preset:
- Entry: anchor `battle <id>` on map ___ at (x,y) / NPC `fight_mission_id` / quest unlock
- Player spawns (west side, ≥ party size):

## 3. Opposition
| unit (character id) | lvl | cell | statuses | role |
|---|---|---|---|---|

## 4. Win / lose
- win_condition / win_param:
- lose_condition / lose_param:
- CT pressure (rounds expected):

## 5. Anchors (map layer)
| # | kind | cell | label | actions | fail_actions | hidden/once |
|---|---|---|---|---|---|---|

## 6. Tells (how the world hints the answer)
- NPC line (who, where):
- Briefing sentence:
- Visual (anchor glyph / light / prop):

## 7. Echoes
- story_flags_on_win:
- News / rumour lines triggered:
- NPC dialogue that reacts (`requires_flag`):
- Unlocks:

## 8. Rewards
coins / xp / chips / loot table, with a justification relative to neighbours (`references/campaign-pacing.md`).

## 9. Done
- [ ] validate_campaign.py 0 errors   - [ ] godot-verify green   - [ ] seeded battle sim win-rate noted
