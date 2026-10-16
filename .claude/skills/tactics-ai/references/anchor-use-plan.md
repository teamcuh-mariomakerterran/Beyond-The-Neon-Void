# Plan: AI that uses anchors (terminals, switches, medstations, devices, traps)

**Goal:** an AI that can finish Vault Breach (`demo_vault_breach`) on its own and fights *around* the world layer: it opens doors, breaks shields, reveals cloakers, heals at stations, and disarms or avoids traps. This is the most valuable AI change because cohesive missions (`mission-architect`) are built from anchors.

## The facts this plan rests on

- `Interactions` (`src/world/interactions.gd`) is created only by `BattleMap._build_grid`, and only for format-2 maps with anchors (`ix = Interactions.new().setup(world_map, grid, self, "battle")`). `CombatManager.map_node` is null when headless, so **sims have no anchors**.
- It works without a host. `_units()` falls back to `CombatManager.units`, `_toast` falls back to `EventBus.log_message`, and `_changed` checks `host` first. So `Interactions.new().setup(WorldMap.from_dict(map), grid, null, "battle")` is valid headless.
- API: `usable_from(from, actor)` returns anchors in reach that `blocker` returns "" for, nearest first. Also `blocker(a, actor)` ("Offline.", "Already used.", "Not here.", "Locked.", "Needs X.", "Not enough AP."), `ap_cost(a)` (default 1 in battle), `in_reach(a, from)` (Manhattan ≤ `reach`, default 1), `is_visible`, `is_lit`, `sequence_length(seq)`, `progress[seq]` (the next step expected, starting at 1), and `interact(a, actor, verb)` → `{ok, text}`.
- `interact` spends AP but **doesn't set `has_acted`** (known-gaps #32). Wrong sequence order resets `progress[seq]=1` and runs `fail_actions`. Traps take the verbs `"disarm"` / `"rewire"`.
- Actions an AI should value: `open`/`close`/`toggle` (mask groups, i.e. doors), `unshield <char_id>`, `reveal <radius>` (strips `cloaked`/`hidden`), `heal N|N%`, `ap +N`, `status id@who`, `cleanse`, `damage`, `spawn`. Ignore for AI: `give`, `take`, `coins`, `chips`, `flag`, `news`, `toast`, `cue`, `dialog`, `npc`, `cutscene`, `battle`, `teleport`, `music` (story and economy belong to the player).
- Vault Breach (`data/maps/vault_breach_demo.json`, 9 anchors):
  - `anc_..._1` terminal [8,9]: `open vault_door`.
  - `core` sequence: switches `_2` [3,1] step 1, `_3` [5,12] step 2, `_4` [8,1] step 3 (`unshield foreman_grisk`).
  - `_5` device [1,6]: reveal.
  - `_6` hidden trap [6,7].
  - `_7` hidden loot.
  - `_8` medstation [0,1]: heal 40%.
  - `_9` intel: chips and flag.
  - Grisk starts `shielded`, and two `choir_enforcer` start `cloaked`.
- Probe on the real grid: player 0/3, 2 of 3 runs hit the 600-turn cap, player moves/turn 0.14, idle 59%. The crew is stuck behind the shut vault door, buffing forever.

## Design (three layers, ship in order)

### Layer 0: make sims see the world (prerequisite, small)
1. Give `CombatManager` an `ix: Interactions` (null by default) and set it in `start_battle` from `map_node.ix` when present. Add an optional `start_battle(..., ix)` argument (or a setter) so headless runners can pass one.
2. Headless runners (`tests/test_suite.gd:_run_battle`, the `godot-verify` replay body, `ai_probe_body.gd`) build the grid via `WorldMap.to_grid()` for format ≥ 2 and create `Interactions` with `host=null`.
3. Move trap springing from `BattleMap.on_unit_path` (which only runs when there's a `map_node`) to `CombatManager.request_move` via `ix.on_enter`. Keep the float text in BattleMap through a hook. Otherwise sims never spring traps.
- **Done when** the replay gate still shows 0 mismatches and the m01/m02 win rates haven't moved (they have no anchors).

### Layer 1: anchors as candidate actions in `plan_turn`
- For each candidate cell `c` (already computed), call `ix.usable_from(c, unit)`. For each anchor, add a pseudo-action `{kind:"anchor", anchor:a, score:score_anchor(unit, a)}` next to the abilities in `_best_action_from`.
- `score_anchor` is a sum over `a.actions` of value per verb (start values; tune with the probe):
  - `unshield X`: if X is a foe, `kill_bonus * 1.5` (it unlocks the win); if X is an ally, negative.
  - `open G`: `approach_weight * (path length to nearest foe now − path length with G open)`. Compute by toggling the mask on a grid copy. Cache per plan.
  - `reveal`: `status_value * (number of cloaked/hidden foes)`.
  - `heal N%`: `min(heal, missing) * heal_weight` (scored like a heal ability on self).
  - `ap +N`: `status_value * N`.
  - `status id@enemies|allies|boss`: reuse the non-damaging status branch of `score_action`.
- **Sequences:** only score an anchor with `sequence` if `int(a.step) == int(ix.progress.get(seq, 1))`. A wrong step resets and runs `fail_actions`, which is a strong negative. Value a non-final step at `final_value * step / sequence_length(seq)` so the AI commits to the chain.
- **Multi-turn intent:** when no anchor is usable from any reachable cell but a high-value one exists, add `approach_weight * path_dist(c, anchor_cell)` toward the best anchor, the same way the approach penalty works for foes. Store it in a new per-unit field (e.g. `Unit.ai_memory["goal_anchor"]`, which doesn't exist yet) so it doesn't dither. Clear it on `blocker != ""`.
- **Traps:** the AI never knowingly paths over a *visible* trap hostile to its team. Add `hazard_penalty` to cells with a visible hostile trap anchor in `score_position`, and teach `reachable_cells` to avoid them only if Brian wants that for players too (ASK BRIAN). Disarming is an anchor action valued as `hazard_penalty` × the number of allies whose path crosses it.
- **Execution:** `_ai_turn` gets a third branch: `plan.anchor` → move, then `ix.interact(anchor, unit, verb)`, then `_check_battle_end()`. With Layer 2 the turn can continue into a second action if AP remains.

### Layer 2: second action (AP)
- After the first action resolves, if `unit.can_act()` and AP remains, re-plan with `can_move()` already false and take the best action if `score > threshold` (start at 1.0). This fixes known-gaps #31 for both abilities and anchors.
- **Done when** the probe's "AP unused/turn" drops below 0.5 for every team and replay determinism holds.

## Test plan
- Unit tests (add to `tests/test_suite.gd` or a new `tests/test_ai.gd`; see `godot-verify` templates):
  - On a 6×6 test world with a terminal that opens a door blocking the only path, a Tactical AI uses the terminal within 2 turns.
  - A 3-step sequence gets pressed in order and is never reset by the AI.
  - With a cloaked foe and a reveal device in reach, the AI uses the device before attacking empty cells.
  - A medstation is used only when missing HP ≥ 40% × max (no waste).
- Sim gate: `ai_probe.gd --missions=demo_vault_breach --seeds=10`. Target 0 stalemates and a player-side win rate within the balance band Brian picks (ASK BRIAN, see `mission-architect/references/campaign-pacing.md`).
- Regression: `verify -Only replay` 0 mismatches. m01/m02 win rates within ±1 run of the baseline.

## Open decisions (ASK BRIAN)
- Should *enemy* AI use anchors too (e.g. Doctrine re-closing the vault door, re-arming traps, enemy medstations)? That's a big difficulty lever.
- Should an anchor use count as an action for CT (known-gaps #32)?
- Should the player-side auto-battle use anchors (it affects the "auto" button and sims alike)?
- Should units, including the player's pathfinder, avoid visible hostile traps?
