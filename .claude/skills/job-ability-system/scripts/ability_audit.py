#!/usr/bin/env python3
"""Job & ability coverage + balance sheet for Beyond The Neon Void.

Usage:
  python ability_audit.py <repo_root>                 # checks + per-class summary
  python ability_audit.py <repo_root> --sheet out.csv  # full ability sheet (one row per ability)
  python ability_audit.py <repo_root> --class chrono_stitcher
  python ability_audit.py <repo_root> --json
Read-only. Checks (ERROR unless noted):
  * class lists reference real abilities; ability.class_id is a real class that lists it
  * ability owned by no class (warn; enemy 'bl_*' and card ids skipped)
  * special values the code handles (Ability._resolve_special + kinetic/time/terrain scripts)
  * script ∈ ContentDB.ABILITY_SCRIPTS and special prefix matches script ("terrain.*" needs script terrain)
  * status_ids exist; required_class_level <= ProgressionSystem.CLASS_LEVEL_MAX (8)
  * learnable abilities with chip_cost 0 (warn: free at terminals) ; innates with chip_cost (warn)
  * charge_ticks > 12 (warn: AI never casts it)
  * presentation coverage (info): vfx resolution (vfx_id / vfx.json abilities / specials / kinds / types),
    icon_path, sfx_id (NOTE: Ability.sfx_id is not read anywhere in src), cue
  * passives: slot valid, class exists, effect handled in src/combat/passives.gd (warn)
  * CLASS_ORDER (class_library.gd) vs playable classes in classes.json; doc headings in docs/design/CLASSES.md
"""
import csv, json, os, re, sys

def jl(p, d=None):
    try:
        with open(p, encoding="utf-8") as f:
            x = json.load(f)
        return x.get("entries", x) if isinstance(x, dict) and "entries" in x else x
    except FileNotFoundError:
        return d

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = os.path.abspath(args[0] if args else ".")
    opt = {a.split("=")[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:] if a.startswith("--")}
    for i, a in enumerate(sys.argv):
        if a in ("--sheet", "--class") and i + 1 < len(sys.argv):
            opt[a] = sys.argv[i + 1]
    D = os.path.join(root, "data")
    S = lambda *p: open(os.path.join(root, *p), encoding="utf-8").read()
    classes = {c["id"]: c for c in jl(os.path.join(D, "classes.json"), [])}
    abilities = {a["id"]: a for a in jl(os.path.join(D, "abilities.json"), [])}
    cards = {c["id"]: c for c in jl(os.path.join(D, "cards.json"), [])}
    statuses = {s["id"] for s in jl(os.path.join(D, "status_effects.json"), [])}
    passives = {p["id"]: p for p in jl(os.path.join(D, "passives.json"), [])}
    vfx = jl(os.path.join(D, "vfx.json"), {}) or {}
    cues = jl(os.path.join(D, "cues.json"), {}) or {}
    ab_src = S("src", "data", "ability.gd")
    handled = set(re.findall(r'^\t\t"([a-z_\.]+)"(?:, "([a-z_\.]+)")?:', ab_src, re.M))
    handled = {x for t in handled for x in t if x}
    script_specials = {}
    for sc in ("kinetic", "time", "terrain"):
        p = os.path.join(root, "src", "combat", "abilities", f"{sc}_ability.gd")
        if os.path.exists(p):
            script_specials[sc] = set(re.findall(r'"(%s\.[a-z_]+)"' % sc, open(p, encoding="utf-8").read()))
    cdb = S("src", "autoload", "content_db.gd")
    scripts = set(re.findall(r'"(\w+)":\s*\w+Ability', cdb))
    order = re.findall(r'"([a-z_]+)"', re.search(r"CLASS_ORDER: Array\[String\] = \[(.*?)\]", S("src", "autoload", "class_library.gd"), re.S).group(1))
    pas_src = S("src", "combat", "passives.gd")
    cmax = int(re.search(r"CLASS_LEVEL_MAX := (\d+)", S("src", "progression", "progression_system.gd")).group(1))
    E, W, I = [], [], []
    owner = {}
    for cid, c in classes.items():
        for kind in ("innate_ability_ids", "learnable_ability_ids"):
            for aid in c.get(kind, []):
                if aid not in abilities:
                    E.append(f"class {cid}: {kind} lists unknown ability '{aid}'")
                owner.setdefault(aid, []).append((cid, kind))
        for req in c.get("unlock_requirements", {}):
            if req not in classes:
                E.append(f"class {cid}: unlock requirement '{req}' unknown")
    def vfx_route(a):
        if a.get("vfx_id"):
            return "vfx_id" if a["vfx_id"] in vfx.get("effects", {}) else "vfx_id-MISSING"
        if a["id"] in vfx.get("abilities", {}):
            return "abilities"
        sp = a.get("special", "")
        if sp and (sp in vfx.get("specials", {}) or sp.split(".")[0] in vfx.get("specials", {})):
            return "specials"
        k = a.get("kind", "ATTACK")
        if k in vfx.get("kinds", {}) and k not in ("ATTACK", "MAGIC") and (a.get("damage_type", "physical") == "physical" or k == "HEAL"):
            return "kind"
        return "type:" + a.get("damage_type", "physical")
    rows = []
    for aid, a in abilities.items():
        W0 = f"ability {aid}"
        cid = a.get("class_id", "")
        if cid:
            if cid not in classes:
                E.append(f"{W0}: class_id '{cid}' unknown")
            elif aid not in classes[cid].get("innate_ability_ids", []) + classes[cid].get("learnable_ability_ids", []):
                E.append(f"{W0}: says class {cid} but that class doesn't list it")
        if aid not in owner and not aid.startswith("bl_") and aid != "basic_attack":
            W.append(f"{W0}: no class lists it (unreachable for players)")
        sp, sc = a.get("special", ""), a.get("script", "")
        if sc and sc not in scripts:
            E.append(f"{W0}: script '{sc}' not in ContentDB.ABILITY_SCRIPTS {sorted(scripts)}")
        if sp:
            head = sp.split(".")[0]
            if head in script_specials:
                if sc != head:
                    E.append(f"{W0}: special '{sp}' needs \"script\": \"{head}\" (else Ability.resolve ignores it)")
                elif sp not in script_specials[head]:
                    E.append(f"{W0}: special '{sp}' not handled in {head}_ability.gd ({sorted(script_specials[head])})")
            elif sp not in handled:
                E.append(f"{W0}: special '{sp}' not handled in Ability._resolve_special")
        for s in a.get("status_ids", []):
            if s not in statuses:
                E.append(f"{W0}: status '{s}' unknown")
        if int(a.get("required_class_level", 0)) > cmax:
            E.append(f"{W0}: required_class_level {a['required_class_level']} > CLASS_LEVEL_MAX {cmax}")
        kinds = [k for _, k in owner.get(aid, [])]
        if "learnable_ability_ids" in kinds and int(a.get("chip_cost", 0) or 0) == 0 and not a.get("absorb_only"):
            gate = "requires_item_id " + a["requires_item_id"] if a.get("requires_item_id") else ("required_class_level %s" % a["required_class_level"] if a.get("required_class_level") else "")
            (I if gate else W).append(f"{W0}: learnable with chip_cost 0" + (f" (gated by {gate})" if gate else " (free at terminals)"))
        if int(a.get("charge_ticks", 0)) > 12:
            W.append(f"{W0}: charge_ticks {a['charge_ticks']} > 12, AIBehavior never casts it")
        route = vfx_route(a)
        rows.append({"id": aid, "class": cid or (owner.get(aid, [("", "")])[0][0]), "slot": "/".join(sorted(set(k.split("_")[0] for k in kinds))) or "-",
                     "kind": a.get("kind", "ATTACK"), "target": a.get("target", "ENEMY"), "type": a.get("damage_type", "physical"),
                     "power": a.get("power", 1.0), "stat": a.get("scaling_stat", "attack"), "ap": a.get("ap_cost", 1), "mp": a.get("mp_cost", 0),
                     "hp%": a.get("hp_cost_pct", 0), "chips": a.get("chip_cost", 0), "charge": a.get("charge_ticks", 0),
                     "range": f"{a.get('range_min', 1)}-{a.get('range_max', 1)}{'+w' if a.get('uses_weapon_range') else ''}",
                     "shape": f"{a.get('shape', 'SINGLE')}{a.get('aoe_radius', 0) or ''}", "status": "|".join(a.get("status_ids", [])),
                     "special": sp, "script": sc, "addition": "y" if a.get("addition") else "", "blue": "y" if a.get("blue_learnable") else "",
                     "req_lv": a.get("required_class_level", 0), "vfx": route, "icon": "y" if a.get("icon_path") else "", "cutscene": "y" if a.get("cutscene") else ""})
    for pid, p in passives.items():
        if p.get("slot") not in ("reaction", "support", "movement"):
            E.append(f"passive {pid}: slot '{p.get('slot')}' invalid")
        if p.get("class_id") and p["class_id"] not in classes:
            E.append(f"passive {pid}: class '{p['class_id']}' unknown")
        eff = p.get("effect") or ""
        if eff and f'"{eff}"' not in pas_src:
            W.append(f"passive {pid}: effect '{eff}' not referenced in passives.gd (no behaviour?)")
        if not eff and not p.get("stat_flat") and not p.get("stat_multipliers"):
            W.append(f"passive {pid}: no effect and no stat mods (check movement passives read by id elsewhere)")
    playable = [c for c, v in classes.items() if v.get("playable", True)]
    for c in playable:
        if c not in order:
            W.append(f"class {c}: playable but not in ClassLibrary.CLASS_ORDER (appended after the ordered list)")
    for c in order:
        if c not in classes:
            E.append(f"CLASS_ORDER lists unknown class '{c}'")
    docp = os.path.join(root, "docs", "design", "CLASSES.md")
    if os.path.exists(docp):
        heads = set(re.findall(r"^### (.+?) —", open(docp, encoding="utf-8").read(), re.M))
        for c in order:
            if classes.get(c) and classes[c]["display_name"] not in heads:
                I.append(f"docs/design/CLASSES.md has no '### {classes[c]['display_name']} —' heading")
    vf = [r for r in rows if r["vfx"].startswith("type:")]
    I.append(f"vfx: {len(rows) - len(vf)}/{len(rows)} abilities have a specific look (vfx_id/abilities/specials/kind); {len(vf)} fall back to the damage-type look")
    I.append(f"icons: {sum(1 for r in rows if r['icon'])}/{len(rows)} have icon_path (others use UiIcons pack lookup by id)")
    if not re.search(r"\.sfx_id\b|get\(\"sfx_id\"\)", "".join(open(os.path.join(dp, f), encoding="utf-8", errors="ignore").read() for dp, _, fs in os.walk(os.path.join(root, "src")) for f in fs if f.endswith(".gd") and "tools" not in dp and f != "ability.gd")):
        I.append("Ability.sfx_id is declared but never read in src/ (ability sounds come from VFX/cues): known gap")
    cue_ids = set(cues.keys()) if isinstance(cues, dict) else set()
    react = [p for p in passives if f"reaction.{p}" not in cue_ids and passives[p].get("slot") == "reaction"]
    if react:
        I.append(f"reaction passives without a 'reaction.<id>' cue (Cues.resolve falls back to 'reaction' then nothing; 'reaction' defined: {'reaction' in cue_ids}): {react}")
    if opt.get("--class"):
        rows = [r for r in rows if r["class"] == opt["--class"]]
    if opt.get("--sheet"):
        with open(opt["--sheet"], "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            w.writeheader(); w.writerows(rows)
        print(f"sheet: {len(rows)} abilities -> {opt['--sheet']}")
    if opt.get("--json"):
        print(json.dumps({"errors": E, "warnings": W, "info": I, "abilities": rows}, indent=2)); sys.exit(1 if E else 0)
    per = {}
    for r in rows:
        per.setdefault(r["class"] or "-", []).append(r)
    print(f"{'class':<24}{'tier':>4}{'role':>9}{'inn':>4}{'lrn':>4}{'chg':>4}{'aoe':>4}{'stat':>5}  unlock")
    for c in order + [c for c in classes if c not in order]:
        v = classes.get(c)
        if not v or (opt.get("--class") and c != opt["--class"]):
            continue
        rs = per.get(c, [])
        print(f"{c:<24}{v.get('tier', 1):>4}{v.get('role', ''):>9}{len(v.get('innate_ability_ids', [])):>4}{len(v.get('learnable_ability_ids', [])):>4}"
              f"{sum(1 for r in rs if r['charge']):>4}{sum(1 for r in rs if r['shape'] != 'SINGLE'):>4}{sum(1 for r in rs if r['status']):>5}  "
              f"{','.join(f'{k}:{n}' for k, n in v.get('unlock_requirements', {}).items())}{' flag:' + v['unlock_flag'] if v.get('unlock_flag') else ''}{'' if v.get('playable', True) else ' (enemy/chassis)'}")
    print()
    for e in E: print("ERROR", e)
    for w in W: print("warn ", w)
    for i in I: print("info ", i)
    print(f"\n{len(abilities)} abilities, {len(classes)} classes ({len(playable)} playable, CLASS_ORDER {len(order)}), {len(passives)} passives, {len(cards)} cards: {len(E)} error(s), {len(W)} warning(s)")
    sys.exit(1 if E else 0)

if __name__ == "__main__":
    main()
