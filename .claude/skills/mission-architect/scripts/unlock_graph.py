#!/usr/bin/env python3
"""Draw BTNV's campaign unlock graph (missions, quests, maps, NPCs, flags).

Usage:  python unlock_graph.py <repo_root> [--mermaid | --dot] [--no-flags] [--start=<mission id>]
Reads data/missions.json, quests.json, npcs.json, data/maps/*.json. Read-only.
Edges:
  mission -> mission   unlocks_mission_ids
  quest   -> mission   unlocks_mission_ids
  quest   -> quest     next_quest_id / prerequisite_quest_ids
  map     -> mission   anchor action {do: battle}
  map     -> map       anchor action {do: teleport} / object location.target_map
  npc     -> quest     offer_quest_id / chain_quest_id / quest_ids
  npc     -> mission   fight_mission_id
  X --flag--> Y        X sets a flag that Y requires (missions/quests/npcs)
"""
import json, os, sys, glob, re

def jl(p, d):
    try:
        with open(p, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return d

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = args[0] if args else "."
    fmt = "dot" if "--dot" in sys.argv else "mermaid"
    flags_on = "--no-flags" not in sys.argv
    D = os.path.join(root, "data")
    missions = {m["id"]: m for m in jl(os.path.join(D, "missions.json"), [])}
    quests = {q["id"]: q for q in jl(os.path.join(D, "quests.json"), [])}
    npcs = {n["id"]: n for n in jl(os.path.join(D, "npcs.json"), [])}
    maps = {}
    for p in glob.glob(os.path.join(D, "maps", "*.json")):
        m = jl(p, {})
        if isinstance(m, dict) and m.get("id"):
            maps[m["id"]] = m
    nodes, edges = {}, []
    start = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--start=")), "m01_the_brew_plan")
    def node(kind, i):
        k = f"{kind}:{i}"
        nodes[k] = (kind, i)
        return k
    setters, readers = {}, {}
    for mid, m in missions.items():
        a = node("mission", mid)
        for u in m.get("unlocks_mission_ids", []):
            edges.append((a, node("mission", u), "unlocks"))
        for f in m.get("story_flags_on_win", []):
            setters.setdefault(f, []).append(a)
    for qid, q in quests.items():
        a = node("quest", qid)
        for u in q.get("unlocks_mission_ids", []):
            edges.append((a, node("mission", u), "unlocks"))
        if q.get("next_quest_id"):
            edges.append((a, node("quest", q["next_quest_id"]), "next"))
        for p in q.get("prerequisite_quest_ids", []):
            edges.append((node("quest", p), a, "prereq"))
        for f in q.get("reward_flags", []):
            setters.setdefault(f, []).append(a)
        for f in q.get("prerequisite_flags", []):
            readers.setdefault(f, []).append(a)
        for o in q.get("objectives", []):
            if o.get("type") == "complete_mission":
                edges.append((node("mission", o.get("target", "")), a, "objective"))
            if o.get("type") == "flag":
                readers.setdefault(o.get("target", ""), []).append(a)
    for nid, n in npcs.items():
        a = node("npc", nid)
        for q in set(n.get("quest_ids", []) + [n.get("offer_quest_id", ""), n.get("chain_quest_id", "")]):
            if q:
                edges.append((a, node("quest", q), "offers"))
        if n.get("fight_mission_id"):
            edges.append((a, node("mission", n["fight_mission_id"]), "fight"))
        if n.get("required_flag"):
            readers.setdefault(n["required_flag"], []).append(a)
        for dl in n.get("dialog", []) + n.get("eavesdrop_lines", []):
            if dl.get("requires_flag"):
                readers.setdefault(dl["requires_flag"], []).append(a)
        if n.get("location_id") in maps:
            edges.append((node("map", n["location_id"]), a, "lives"))
    for mid, mp in maps.items():
        anchors = mp.get("anchors", [])
        hit = False
        for an in anchors:
            for act in an.get("actions", []) + an.get("fail_actions", []):
                do, arg = act.get("do"), str(act.get("arg", ""))
                if do == "battle" and arg:
                    edges.append((node("map", mid), node("mission", arg), "battle")); hit = True
                elif do == "teleport" and re.match(r"^[a-z]", arg):
                    edges.append((node("map", mid), node("map", arg.split(":")[0]), "teleport")); hit = True
                elif do == "flag" and arg:
                    setters.setdefault(arg, []).append(node("map", mid)); hit = True
            if an.get("requires_flag"):
                readers.setdefault(an["requires_flag"], []).append(node("map", mid))
        for o in mp.get("objects", []):
            loc = o.get("location")
            if isinstance(loc, dict) and loc.get("target_map"):
                edges.append((node("map", mid), node("map", loc["target_map"]), "enter")); hit = True
        if hit:
            node("map", mid)
    if flags_on:
        for f, rs in readers.items():
            for s in setters.get(f, []):
                for r in rs:
                    edges.append((s, r, f"flag {f}"))
    nodes["start:new_game"] = ("start", "NEW GAME (hub mission board)")
    if start in missions:
        edges.insert(0, ("start:new_game", node("mission", start), "unlocked"))
    seen = set(); edges = [e for e in edges if not (e in seen or seen.add(e))]
    sid = lambda k: re.sub(r"[^A-Za-z0-9_]", "_", k)
    shape = {"start": ("((", "))"), "mission": ("[", "]"), "quest": ("(", ")"), "map": ("[(", ")]"), "npc": ("{{", "}}")}
    if fmt == "mermaid":
        print("```mermaid\nflowchart LR")
        for k, (kind, i) in sorted(nodes.items()):
            o, c = shape[kind]
            missing = (kind == "mission" and i not in missions) or (kind == "quest" and i not in quests) or (kind == "map" and i not in maps)
            label = f"{kind}: {i}" + (" MISSING" if missing else "")
            print(f'  {sid(k)}{o}"{label}"{c}')
        for a, b, l in edges:
            print(f'  {sid(a)} -->|{l}| {sid(b)}')
        print("  classDef mission fill:#3a1450,stroke:#ff3cac,color:#fff;")
        print("  classDef quest fill:#10304a,stroke:#2de2e6,color:#fff;")
        for kind in ("mission", "quest"):
            ids = [sid(k) for k, (kd, _) in nodes.items() if kd == kind]
            if ids:
                print(f"  class {','.join(ids)} {kind};")
        print("```")
    else:
        print("digraph btnv {\n  rankdir=LR;")
        for k, (kind, i) in sorted(nodes.items()):
            print(f'  {sid(k)} [label="{kind}\\n{i}", shape={"box" if kind=="mission" else "ellipse"}];')
        for a, b, l in edges:
            print(f'  {sid(a)} -> {sid(b)} [label="{l}"];')
        print("}")

if __name__ == "__main__":
    main()
