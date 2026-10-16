#!/usr/bin/env python3
"""Campaign validator for Beyond The Neon Void.

Checks that missions, quests, NPCs, dispatch errands, map triggers and anchors
reference real content, that encounters are placeable, that flags someone reads
are set by someone, and that every mission is REACHABLE in play.

Reachability graph (what can start a mission):
  start set   CampaignManager default unlocked (m01_the_brew_plan) [+ --start ids]
  mission  -> unlocks_mission_ids
  quest    -> unlocks_mission_ids (quest reachable if its giver NPC exists and prereqs are reachable)
  npc      -> fight_mission_id / after_talk "battle"
  map      -> region triggers {do: battle}, region encounter.missions, anchor actions {do: battle}
             (only for maps reachable from --entry-map ids; default: every world/hub/city map,
              followed through location target_map, teleport triggers/actions)
It also reports whether the game flow can reach exploration at all (who calls
CampaignManager.explore outside the Forge and dev console).

Usage:  python validate_campaign.py [repo_root] [--entry-map id ...] [--start id ...] [--strict] [--json]
Exit 1 on errors (--strict: also on warnings). Read-only.
"""
import json, os, re, sys

STATUS_PRIMARY = {"strength", "agility", "intelligence", "vitality"}
WIN = {"defeat_all", "defeat_target", "survive", "reach_cell"}
LOSE = {"party_wiped", "leader_down", "protect", "time_limit"}
OBJ = {"complete_mission", "collect_item", "talk_to", "find_loot", "flag", "defeat_character"}
AI = {"", "aggressive", "cautious", "tactical", "support"}
AFTER_TALK = {"none", "shop", "quest", "chain", "fetch", "battle", "cutscene", ""}

class Report:
    def __init__(self):
        self.items = []
    def err(self, where, msg):
        self.items.append(("ERROR", where, msg))
    def warn(self, where, msg):
        self.items.append(("warn", where, msg))


def _music_ok(root, mid, depth=0):
    """A track file, or a data/music.json alias (string or list) that leads to one.
    battle_* falls back to the "battle" pool, as AudioManager does."""
    if mid.startswith("res://"):
        return os.path.exists(os.path.join(root, mid[6:]))
    if any(os.path.exists(os.path.join(root, "assets", "music", mid + e)) for e in (".ogg", ".wav", ".mp3")):
        return True
    if depth > 3:
        return False
    try:
        aliases = json.load(open(os.path.join(root, "data", "music.json"), encoding="utf-8"))
    except Exception:
        return False
    v = aliases.get(mid, aliases.get("battle") if mid.startswith("battle_") else None)
    vals = v if isinstance(v, list) else ([v] if isinstance(v, str) else [])
    return bool(vals) and all(_music_ok(root, x, depth + 1) for x in vals)

def jload(p, default=None):
    try:
        with open(p, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return default
def listarg(args, name):
    out, i = [], 0
    while i < len(args):
        if args[i] == name and i + 1 < len(args):
            out.append(args[i + 1]); i += 2
        else:
            i += 1
    return out

def main() -> int:
    args = sys.argv[1:]
    pos = [a for i, a in enumerate(args) if not a.startswith("--") and (i == 0 or args[i - 1] not in ("--entry-map", "--start"))]
    root = os.path.abspath(pos[0] if pos else ".")
    D = os.path.join(root, "data")
    R = Report()
    missions = {m["id"]: m for m in jload(os.path.join(D, "missions.json"), [])}
    quests = {q["id"]: q for q in jload(os.path.join(D, "quests.json"), [])}
    npcs = {n["id"]: n for n in jload(os.path.join(D, "npcs.json"), [])}
    chars = {c["id"]: c for c in jload(os.path.join(D, "characters.json"), [])}
    items = {i["id"] for i in jload(os.path.join(D, "items.json"), [])}
    cards = {c["id"] for c in jload(os.path.join(D, "cards.json"), [])}
    statuses = {s["id"] for s in jload(os.path.join(D, "status_effects.json"), [])}
    classes = {c["id"] for c in jload(os.path.join(D, "classes.json"), [])}
    loot = {l["id"] for l in jload(os.path.join(D, "loot_tables.json"), [])}
    dispatch = jload(os.path.join(D, "dispatch_missions.json"), [])
    vendors = jload(os.path.join(D, "vendors.json"), {})
    rumors = jload(os.path.join(D, "rumors.json"), {})
    cues = {k for k in jload(os.path.join(D, "cues.json"), {}) if not k.startswith("_")}
    terrain = jload(os.path.join(D, "terrain.json"), {})
    tiles_db = jload(os.path.join(D, "tiles.json"), {})
    maps = {}
    for f in sorted(os.listdir(os.path.join(D, "maps"))):
        if f.endswith(".json"):
            m = jload(os.path.join(D, "maps", f), {})
            maps[m.get("id", f[:-5])] = m
    grants = items | cards

    def res_ok(p):
        return not p or os.path.exists(os.path.join(root, p[6:] if p.startswith("res://") else p))
    def cue_ok(cid):
        parts = cid.split(".")
        return any(".".join(parts[:i]) in cues for i in range(len(parts), 0, -1))

    # ---------- map helpers ----------
    def walkable(mp, cell):
        x, y = cell
        if not (0 <= x < int(mp.get("width", 0)) and 0 <= y < int(mp.get("depth", 0))):
            return False, "out of bounds"
        if int(mp.get("format", 1)) >= 2:
            k = f"{x},{y}"
            st = mp.get("tiles", {}).get(k)
            if not st:
                return False, "hole (no tiles)"
            ov = mp.get("gameplay", {}).get(k, {})
            if ov.get("walkable") is False:
                return False, "masked unwalkable"
            for o in mp.get("objects", []):
                if o.get("kind") in ("structure", "location") and list(o.get("cell", [-9, -9])) == [x, y]:
                    return False, f"under {o.get('kind')} {o.get('id')}"
            top = str(st[-1][1])
            tname = top[8:] if top.startswith("terrain:") else (tiles_db.get(top, {}) or {}).get("terrain", "concrete")
            if terrain.get(tname, {}).get("walkable") is False and "walkable" not in ov:
                return False, f"terrain {tname} unwalkable"
            return True, ""
        for c in mp.get("cells", []):
            if int(c.get("x", -1)) == x and int(c.get("y", -1)) == y:
                t = c.get("t", "concrete")
                if c.get("walkable") is False or (terrain.get(t, {}).get("walkable") is False and "walkable" not in c):
                    return False, f"terrain {t} unwalkable"
                return True, ""
        return (True, "") if mp.get("default_terrain") else (False, "no cell")

    # Only battle-map `props` with a loot_item_id become InteractionTriggers that emit
    # EventBus.loot_discovered (battle_map._spawn_prop -> interaction_trigger.gd).
    # Explore `objects` set flag "looted:<map>:<id>" instead; anchors emit nothing.
    loot_ids, loot_empty, other_ids = set(), set(), {}
    for mid, mp in maps.items():
        for p in mp.get("props", []):
            (loot_ids if p.get("loot_item_id") else loot_empty).add(p.get("id"))
        for o in mp.get("objects", []):
            other_ids[o.get("id")] = f"explore object on {mid}: use objective {{type: flag, target: looted:{mid}:{o.get('id')}}}"
        for a in mp.get("anchors", []):
            other_ids[a.get("id")] = f"anchor on {mid}: add action {{do: flag, arg: <flag>}} and use a `flag` objective"

    # ---------- flags set / read ----------
    set_flags, read_flags = set(), []
    for m in missions.values():
        set_flags |= set(m.get("story_flags_on_win", []))
    for q in quests.values():
        set_flags |= set(q.get("reward_flags", []))
        for f in q.get("prerequisite_flags", []):
            read_flags.append((f"quest {q['id']}", f))
        for o in q.get("objectives", []):
            if o.get("type") == "flag":
                read_flags.append((f"quest {q['id']} objective", o.get("target", "")))
    for n in npcs.values():
        for node in n.get("dialog", []):
            if node.get("sets_flag"):
                set_flags.add(node["sets_flag"])
            if node.get("requires_flag"):
                read_flags.append((f"npc {n['id']} dialog {node.get('id')}", node["requires_flag"]))
            for ch in node.get("choices", []):
                if ch.get("sets_flag"):
                    set_flags.add(ch["sets_flag"])
        if n.get("required_flag"):
            read_flags.append((f"npc {n['id']}", n["required_flag"]))
        for f in n.get("chain_requires", []):
            read_flags.append((f"npc {n['id']} chain_requires", f))
    for mid, mp in maps.items():
        for r in mp.get("regions", []):
            for t in r.get("triggers", []):
                if t.get("do") == "flag":
                    set_flags.add(t.get("arg", ""))
                for key in ("requires_flag", "blocks_flag"):
                    if t.get(key):
                        read_flags.append((f"map {mid} region {r.get('name')}", t[key]))
        for a in mp.get("anchors", []):
            for act in a.get("actions", []) + a.get("fail_actions", []):
                if act.get("do") == "flag":
                    set_flags.add(act.get("arg", ""))
            if a.get("requires_flag"):
                read_flags.append((f"map {mid} anchor {a.get('id')}", a["requires_flag"]))
    for d in dispatch:
        if d.get("required_flag"):
            read_flags.append((f"dispatch {d['id']}", d["required_flag"]))
    for vid, v in vendors.items():
        for s in v.get("stock", []):
            if s.get("required_flag"):
                read_flags.append((f"vendor {vid} stock {s.get('id')}", s["required_flag"]))
    # flags the engine sets by pattern (namespaced): treat as set
    dyn = re.compile(r"^(npc:|found_|trig:|ixstate:|visited|secret_|drunken_oracle)")

    # ---------- missions ----------
    for mid, m in missions.items():
        W = f"mission {mid}"
        mp = maps.get(m.get("map_id", ""))
        if mp is None:
            R.err(W, f"map_id '{m.get('map_id')}' not in data/maps")
        if m.get("loot_table_id") and m["loot_table_id"] not in loot:
            R.err(W, f"loot_table_id '{m['loot_table_id']}' unknown")
        for k in ("intro_cutscene", "outro_cutscene"):
            if not res_ok(m.get(k, "")):
                R.err(W, f"{k} file missing: {m.get(k)}")
        if m.get("music_id") and not _music_ok(root, m["music_id"]):
            R.warn(W, f"music '{m['music_id']}': no file in assets/music and no entry in data/music.json")
        for u in m.get("unlocks_mission_ids", []):
            if u not in missions:
                R.err(W, f"unlocks unknown mission '{u}'")
        if not m.get("story_flags_on_win"):
            R.warn(W, "no story_flags_on_win (nothing downstream can react to it)")
        enemy_ids, cells = [], {}
        for kind in ("enemies", "guests"):
            for i, e in enumerate(m.get(kind, [])):
                cid = e.get("character_id", "")
                if cid not in chars:
                    R.err(W, f"{kind}[{i}] character '{cid}' unknown")
                if kind == "enemies":
                    enemy_ids.append(cid)
                if e.get("ai", "") not in AI:
                    R.err(W, f"{kind}[{i}] ai '{e.get('ai')}' not in {sorted(AI)}")
                elif e.get("ai"):
                    R.warn(W, f"{kind}[{i}] ai '{e['ai']}' is IGNORED by battle_map._spawn_units (uses CharacterData.ai_behavior) until the per-unit override is wired")
                if kind == "guests" and e.get("statuses"):
                    R.warn(W, f"{kind}[{i}] statuses are IGNORED for guests (battle_map only applies enemy statuses)")
                for s in e.get("statuses", []):
                    if s not in statuses:
                        R.err(W, f"{kind}[{i}] status '{s}' unknown")
                c = tuple(e.get("cell", [-1, -1]))
                if c in cells:
                    R.err(W, f"{kind}[{i}] cell {list(c)} also used by {cells[c]}")
                cells[c] = f"{kind}[{i}] {cid}"
                if mp is not None:
                    ok, why = walkable(mp, c)
                    if not ok:
                        R.err(W, f"{kind}[{i}] {cid} at {list(c)}: {why}")
        if mp is not None:
            sp = [tuple(s) for s in mp.get("spawns", {}).get("player", [])]
            if len(sp) < int(m.get("max_party_size", 5)):
                R.warn(W, f"map has {len(sp)} player spawns < max_party_size {m.get('max_party_size', 5)}")
            for s in sp:
                if s in cells:
                    R.err(W, f"player spawn {list(s)} overlaps {cells[s]}")
        wc, wp = m.get("win_condition", "defeat_all"), str(m.get("win_param", ""))
        if wc not in WIN:
            R.err(W, f"win_condition '{wc}' not in {sorted(WIN)}")
        if wc == "defeat_target" and wp not in enemy_ids:
            R.err(W, f"defeat_target win_param '{wp}' is not one of the enemies")
        if wc == "survive" and not wp.isdigit():
            R.err(W, "survive needs win_param = number of rounds")
        if wc == "reach_cell":
            try:
                x, y = (int(v) for v in wp.split(","))
                if mp is not None and not walkable(mp, (x, y))[0]:
                    R.err(W, f"reach_cell {wp} is not walkable")
            except ValueError:
                R.err(W, "reach_cell needs win_param 'x,y'")
        lc, lp = m.get("lose_condition", "party_wiped"), str(m.get("lose_param", ""))
        if lc not in LOSE:
            R.err(W, f"lose_condition '{lc}' not in {sorted(LOSE)}")
        if lc in ("leader_down", "protect") and lp not in chars:
            R.err(W, f"{lc} lose_param '{lp}' is not a character id")
        if lc == "protect" and lp not in [g.get("character_id") for g in m.get("guests", [])]:
            R.warn(W, f"protect target '{lp}' is not in guests (fine only if it is a party member who is guaranteed to deploy)")
        if lc == "time_limit" and not lp.isdigit():
            R.err(W, "time_limit needs lose_param = rounds")

    # ---------- quests ----------
    for qid, q in quests.items():
        W = f"quest {qid}"
        if int(q.get("min_chapter", 1)) > 1:
            R.warn(W, f"min_chapter {q['min_chapter']} > 1 but nothing in src advances GameManager.story_chapter (locked forever until that is wired)")
        if q.get("giver_npc_id") and q["giver_npc_id"] not in npcs:
            R.err(W, f"giver_npc_id '{q['giver_npc_id']}' unknown")
        for p in q.get("prerequisite_quest_ids", []):
            if p not in quests:
                R.err(W, f"prerequisite quest '{p}' unknown")
        if q.get("next_quest_id") and q["next_quest_id"] not in quests:
            R.err(W, f"next_quest_id '{q['next_quest_id']}' unknown")
        for u in q.get("unlocks_mission_ids", []):
            if u not in missions:
                R.err(W, f"unlocks unknown mission '{u}'")
        for it in q.get("reward_items", {}):
            if it not in grants:
                R.err(W, f"reward item '{it}' unknown")
        for i, o in enumerate(q.get("objectives", [])):
            t, tg = o.get("type"), o.get("target", "")
            if t not in OBJ:
                R.err(W, f"objective[{i}] type '{t}' unknown")
            elif t == "complete_mission" and tg not in missions:
                R.err(W, f"objective[{i}] mission '{tg}' unknown")
            elif t == "collect_item" and tg not in grants:
                R.err(W, f"objective[{i}] item '{tg}' unknown")
            elif t == "talk_to" and tg not in npcs and tg not in chars:
                R.err(W, f"objective[{i}] talk_to '{tg}' is not an npc/character")
            elif t == "defeat_character" and tg not in chars:
                R.err(W, f"objective[{i}] character '{tg}' unknown")
            elif t == "find_loot" and tg not in loot_ids:
                if tg in loot_empty:
                    R.err(W, f"objective[{i}] find_loot '{tg}': prop has no loot_item_id, so it never emits loot_discovered")
                elif tg in other_ids:
                    R.err(W, f"objective[{i}] find_loot '{tg}' will never progress: it is an {other_ids[tg]}")
                else:
                    R.err(W, f"objective[{i}] find_loot '{tg}' is not a battle-map prop id on any map")
    # ---------- npcs ----------
    for nid, n in npcs.items():
        W = f"npc {nid}"
        if n.get("vendor_id") and n["vendor_id"] not in vendors:
            R.err(W, f"vendor_id '{n['vendor_id']}' unknown")
        if n.get("fight_mission_id") and n["fight_mission_id"] not in missions:
            R.err(W, f"fight_mission_id '{n['fight_mission_id']}' unknown")
        for q in n.get("quest_ids", []) + [n.get("offer_quest_id", ""), n.get("chain_quest_id", "")]:
            if q and q not in quests:
                R.err(W, f"quest '{q}' unknown")
        for it in [n.get("give_item_id", "")] + list(n.get("fetch_items", {})) + list(n.get("fetch_reward_items_each", {})) + list(n.get("fetch_reward_items_done", {})):
            if it and it not in grants:
                R.err(W, f"item '{it}' unknown")
        if n.get("after_talk", "none") not in AFTER_TALK:
            R.err(W, f"after_talk '{n.get('after_talk')}' unknown")
        if not res_ok(n.get("stage_cutscene", "")):
            R.err(W, f"stage_cutscene missing: {n.get('stage_cutscene')}")
        if n.get("location_id") and n["location_id"] != "neon_gutter" and n["location_id"] not in maps:
            R.warn(W, f"location_id '{n['location_id']}' is neither neon_gutter nor a map id")
        ids = {d.get("id") for d in n.get("dialog", [])}
        for d in n.get("dialog", []):
            for nx in [d.get("next", "")] + [c.get("next", "") for c in d.get("choices", [])]:
                if nx and nx not in ids:
                    R.err(W, f"dialog '{d.get('id')}' -> unknown node '{nx}'")
    # ---------- dispatch ----------
    for d in dispatch:
        W = f"dispatch {d['id']}"
        if d.get("loot_table_id") and d["loot_table_id"] not in loot:
            R.err(W, f"loot_table_id '{d['loot_table_id']}' unknown")
        for c in d.get("class_affinity", {}):
            if c not in classes:
                R.err(W, f"class_affinity '{c}' unknown")
        for s in d.get("stat_weights", {}):
            if s not in STATUS_PRIMARY:
                R.err(W, f"stat_weights key '{s}' not in {sorted(STATUS_PRIMARY)}")
        for r in d.get("rumor_ids", []):
            if r not in rumors:
                R.err(W, f"rumor '{r}' unknown")
    # ---------- map anchors / triggers ----------
    for mid, mp in maps.items():
        for a in mp.get("anchors", []):
            W = f"map {mid} anchor {a.get('id')}"
            for act in a.get("actions", []) + a.get("fail_actions", []):
                do, arg = act.get("do"), str(act.get("arg", ""))
                if do == "battle" and arg not in missions:
                    R.err(W, f"battle -> unknown mission '{arg}'")
                if do == "cue" and arg and not cue_ok(arg):
                    R.err(W, f"cue '{arg}' resolves to nothing in data/cues.json")
                if do in ("give", "take") and arg.split(":")[0] not in grants:
                    R.err(W, f"{do} unknown item '{arg}'")
                if do == "npc" and arg not in npcs:
                    R.err(W, f"npc '{arg}' unknown")
                if do == "spawn" and arg.split("@")[0] not in chars:
                    R.err(W, f"spawn unknown character '{arg}'")
                if do == "status" and arg.split("@")[0] not in statuses:
                    R.err(W, f"status '{arg}' unknown")
                if do == "cutscene" and not res_ok(arg):
                    R.err(W, f"cutscene missing: {arg}")
            if a.get("kind") == "npc" and a.get("npc_id") not in npcs:
                R.err(W, f"npc_id '{a.get('npc_id')}' unknown")
            if a.get("requires_item") and a["requires_item"] not in grants:
                R.err(W, f"requires_item '{a['requires_item']}' unknown")
            tr = a.get("trap")
            if isinstance(tr, dict) and tr.get("status") and tr["status"] not in statuses:
                R.err(W, f"trap status '{tr['status']}' unknown")
    # ---------- flags ----------
    for where, f in read_flags:
        if f and f not in set_flags and not dyn.match(f):
            R.warn(where, f"reads flag '{f}' that nothing in data sets (set by code? check)")

    # ---------- reachability ----------
    starts = ["m01_the_brew_plan"] + listarg(args, "--start")
    entry = listarg(args, "--entry-map") or [k for k, v in maps.items() if v.get("kind") in ("world", "hub", "city")]
    reach_maps, frontier = set(), [e for e in entry if e in maps]
    while frontier:
        mid = frontier.pop()
        if mid in reach_maps:
            continue
        reach_maps.add(mid)
        mp = maps[mid]
        for o in mp.get("objects", []):
            loc = o.get("location")
            if isinstance(loc, dict) and loc.get("target_map") in maps:
                frontier.append(loc["target_map"])
        for r in mp.get("regions", []):
            for t in r.get("triggers", []):
                if t.get("do") == "teleport":
                    frontier.append(str(t.get("arg", "")).split(":")[0])
        for a in mp.get("anchors", []):
            for act in a.get("actions", []):
                if act.get("do") == "teleport" and str(act.get("arg", "")).split(":")[0] in maps:
                    frontier.append(str(act["arg"]).split(":")[0])
    frontier = [s for s in starts if s in missions]
    for mid in reach_maps:
        mp = maps[mid]
        for r in mp.get("regions", []):
            frontier += [str(t.get("arg")) for t in r.get("triggers", []) if t.get("do") == "battle"]
            frontier += list(r.get("encounter", {}).get("missions", []))
        for a in mp.get("anchors", []):
            frontier += [str(x.get("arg")) for x in a.get("actions", []) if x.get("do") == "battle"]
    for n in npcs.values():
        if n.get("fight_mission_id"):
            frontier.append(n["fight_mission_id"])
    reach = set()
    changed = True
    while changed:
        changed = False
        while frontier:
            m = frontier.pop()
            if m in reach or m not in missions:
                continue
            reach.add(m)
            changed = True
            frontier += missions[m].get("unlocks_mission_ids", [])
        for q in quests.values():
            prereq_ok = all(p in quests for p in q.get("prerequisite_quest_ids", []))
            if q.get("giver_npc_id") in npcs and prereq_ok:
                for u in q.get("unlocks_mission_ids", []):
                    if u not in reach:
                        frontier.append(u)
    for mid in missions:
        if mid not in reach:
            (R.warn if mid.startswith(("demo_", "test_")) else R.err)(f"mission {mid}", "UNREACHABLE: nothing in the campaign can start it")
    # game-flow entry to exploration
    callers = []
    for dp, dn, fn in os.walk(os.path.join(root, "src")):
        for f in fn:
            if f.endswith(".gd"):
                p = os.path.join(dp, f)
                rel = os.path.relpath(p, root).replace("\\", "/")
                if "CampaignManager.explore(" in open(p, encoding="utf-8", errors="replace").read():
                    callers.append(rel)
    flow = [c for c in callers if not (c.startswith("src/tools/") or c.endswith("dev_console.gd") or c.endswith("explore_scene.gd"))]
    if not flow:
        R.warn("game flow", f"no in-game entry to exploration: CampaignManager.explore is only called from {callers} "
               "(Forge 'Play here', dev console tp, and explore_scene itself). Maps' battles are reachable only from there.")
    # ---------- output ----------
    errs = [i for i in R.items if i[0] == "ERROR"]
    warns = [i for i in R.items if i[0] != "ERROR"]
    if "--json" in args:
        print(json.dumps({"errors": errs, "warnings": warns, "reachable_missions": sorted(reach), "reachable_maps": sorted(reach_maps)}, indent=2))
    else:
        for lvl, w, msg in errs + warns:
            print(f"{lvl:5} {w}: {msg}")
        print(f"\nmissions reachable: {sorted(reach)}")
        print(f"maps reachable from entry {sorted(entry)}: {sorted(reach_maps)}")
        print(f"{len(errs)} error(s), {len(warns)} warning(s)")
    return 1 if errs or ("--strict" in args and warns) else 0

if __name__ == "__main__":
    sys.exit(main())
