# Anchors and actions (schema from the `src/world/interactions.gd` header)

```
{id, cell: [x, y], kind, label, hidden, scope: "both"|"battle"|"explore",
 ap: 1, reach: 1, once, enabled, requires_flag, requires_item, consume_item,
 sequence: "", step: 0,              # switches pressed in order 1, 2, 3…
 actions: [{do, arg}], fail_actions: [{do, arg}],
 npc_id,                             # kind "npc": runs NpcStages
 trap: {damage, status, hostile: "player"|"enemy", disarm: 0–1}}
```
Ids follow `anc_<map_id>_<n>` (World Painter MASKS tab).

## Kinds (`Interactions.KINDS`: name, glyph, verb)
terminal ▣ HACK · switch ⏻ FLIP · loot ✦ SEARCH · trap ⚠ DISARM · door ▯ OPEN · transition ⇲ ENTER · npc ☺ TALK · device ◎ ACTIVATE · medstation ✚ HEAL · intel ⌬ DOWNLOAD · examine ? EXAMINE

## Actions (`Interactions.ACTIONS` + `ACTION_HINT`)
| do | arg |
|---|---|
| open / close / toggle | mask group (door cells) |
| reveal | radius in cells (empty = whole map): strips `cloaked`/`hidden` |
| unshield | character id (empty = everyone shielded) |
| status | `status_id@self\|allies\|enemies\|all\|boss` |
| cleanse | `status_id@target` |
| give / take | `item_id` or `item_id:qty` |
| coins / chips | amount |
| damage / heal | amount or `25%` (to whoever used it) |
| ap | +AP for the user |
| spawn | `character_id@x,y[@enemy\|player]` |
| flag / unflag | story flag |
| enable / disable | anchor id |
| arm | trap anchor id (rewire: hostile to enemies) |
| toast | text |
| news | ticker line → `EventBus.broadcast_line("news", …)` |
| cue | cue id from `data/cues.json` (hierarchical fallback) |
| dialog | NPC id or a line of text |
| npc | NPC id (runs its stages) |
| cutscene | `res://data/cutscenes/….json` |
| battle | mission id |
| teleport | `map_id`, `map_id:spawn#`, or `x,y` on this map |
| music | `res://assets/music/….ogg` (explore path has a known type bug; see open-world-tactics) |

Cue ids that exist today: `hit`, `hit.heavy`, `hit.crit`, `hurt`, `hurt.heavy`, `hurt.crit`, `kill`, `kill.boss`, `ally_down`, `heal`, `boss.intro`, `victory`, `defeat`, `status.petrified`, `status.banished`, `status.stop`, `sequence.step`, `sequence.complete`, `sequence.fail`, `shield.down`, `trap.spring`, `door`.

## NPC stages (`src/world/npc_stages.gd`, NPCResource "Interaction stages")
`intro_lines` → `give_item_id`/`give_item_qty` → `after_talk` (none / shop / quest / chain / fetch / battle / cutscene) → `repeat_lines` → `closing_lines`.

| after_talk | Uses |
|---|---|
| quest | `offer_quest_id` |
| chain | `chain_quest_id`, `chain_requires[]`, `chain_locked_lines[]` |
| fetch | `fetch_items{item: qty}`, `fetch_reward_coins_each`, `fetch_reward_items_each`, `fetch_reward_coins_done`, `fetch_reward_chips_done`, `fetch_reward_items_done` |
| battle | `fight_mission_id` |
| cutscene | `stage_cutscene` |
| shop | `vendor_id` |

Flags: `npc:<id>:met`, `npc:<id>:gift`, `npc:<id>:fetch`, `npc:<id>:fetched`, `npc:<id>:repeat`.

Dialog graph (`dialog[]`): `{id, text, speaker, voice_path, requires_flag, sets_flag, next, choices[{text, next, correct, sets_flag}]}`. `eavesdrop_lines[{text, voice_path, requires_flag}]` appear in the hub Regulars tab (Eavesdrop).
