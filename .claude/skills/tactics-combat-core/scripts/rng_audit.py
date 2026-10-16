#!/usr/bin/env python3
"""Find randomness that can break seeded battles / replays in Beyond The Neon Void.

Usage:  python rng_audit.py <repo_root> [--json] [--strict]
Classifies every RNG use under src/ (tools/ and legacy/ skipped):
  RULES        combat, abilities, AI, statuses, interactions, campaign/dispatch/quest logic
  PRESENTATION ui, vfx, camera, audio, renderer, signage, hub ticker (allowed to be random)
and flags in RULES files:
  * global randf()/randi()/randi_range()/randf_range()/pick_random()/shuffle()  -> LEAK
  * RandomNumberGenerator.new() followed by randomize()                       -> LEAK
  * RandomNumberGenerator.new() used as a fallback (… else RandomNumberGenerator.new()) -> FALLBACK
  * uses of CombatManager.rng / ctx.rng / battle.rng                          -> ok (counted)
--strict exits 1 if any LEAK/FALLBACK is found in RULES files.
"""
import json, os, re, sys

RULES = ("src/combat/", "src/autoload/combat_manager.gd", "src/autoload/campaign_manager.gd",
         "src/autoload/dispatch_manager.gd", "src/autoload/quest_manager.gd", "src/autoload/class_library.gd",
         "src/world/interactions.gd", "src/world/explore_scene.gd", "src/world/npc_stages.gd", "src/data/",
         "src/autoload/game_manager.gd", "src/autoload/forge_manager.gd", "src/autoload/vendor_system.gd")
GLOBAL = re.compile(r"(?<![\w.])(randf|randi|randi_range|randf_range|randfn)\s*\(|\.(pick_random|shuffle)\s*\(")
NEW = re.compile(r"RandomNumberGenerator\.new\(\)")
SEEDED = re.compile(r"\b(CombatManager\.rng|ctx\.rng|battle\.rng|sub\.rng|\brng\.(randf|randi|randi_range|randf_range))")

def main():
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    root = os.path.abspath(a[0] if a else ".")
    findings, ok = [], 0
    for dp, dn, fn in os.walk(os.path.join(root, "src")):
        rel_d = os.path.relpath(dp, root).replace("\\", "/") + "/"
        if rel_d.startswith("src/tools/") or "/legacy/" in rel_d:
            continue
        for f in fn:
            if not f.endswith(".gd"):
                continue
            rel = rel_d + f
            rules = rel.startswith(RULES)
            lines = open(os.path.join(dp, f), encoding="utf-8", errors="replace").read().splitlines()
            text = "\n".join(lines)
            for i, ln in enumerate(lines, 1):
                s = ln.split("#", 1)[0]
                if SEEDED.search(s):
                    ok += 1
                for m in GLOBAL.finditer(s):
                    findings.append({"file": rel, "line": i, "kind": "LEAK" if rules else "presentation", "what": m.group(0).strip(), "code": ln.strip()[:120]})
                if NEW.search(s):
                    var = re.match(r"\s*(?:var\s+)?(\w+)", s)
                    name = var.group(1) if var else ""
                    if " else " in s or " if " in s:
                        kind = "FALLBACK"
                    elif name and re.search(rf"\b{re.escape(name)}\.seed\s*=", text):
                        kind = "seeded"  # may still randomize() when no seed is given
                    elif name and re.search(rf"\b{re.escape(name)}\.randomize\(\)", text):
                        kind = "LEAK"
                    else:
                        kind = "unseeded-new"
                    if not rules and kind in ("LEAK", "FALLBACK", "unseeded-new"):
                        kind = "presentation"
                    findings.append({"file": rel, "line": i, "kind": kind, "what": "RandomNumberGenerator.new()", "code": ln.strip()[:120]})
    bad = [f for f in findings if f["kind"] in ("LEAK", "FALLBACK", "unseeded-new")]
    if "--json" in sys.argv:
        print(json.dumps({"rules_issues": bad, "all": findings, "seeded_uses": ok}, indent=2))
    else:
        print(f"seeded rng uses (CombatManager.rng / ctx.rng / rng.*): {ok}")
        print("\nRULES-PATH ISSUES (break replays / seeded sims):")
        for f in bad:
            print(f"  {f['kind']:<13} {f['file']}:{f['line']}  {f['code']}")
        pres = [f for f in findings if f["kind"] == "presentation"]
        print(f"\npresentation-only randomness: {len(pres)} site(s) in {len(set(f['file'] for f in pres))} file(s) (allowed)")
        print(f"\n{len(bad)} rules-path issue(s)")
    sys.exit(1 if bad and "--strict" in sys.argv else 0)

if __name__ == "__main__":
    main()
