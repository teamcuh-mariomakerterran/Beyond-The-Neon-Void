#!/usr/bin/env python3
"""Validate data/vfx.json against the REAL part code, and report coverage/taste stats.

  python vfx_lint.py <repo> [--json] [--strict] [--coverage]

Checks (errors unless noted):
  - JSON parses; top-level keys effects/types/kinds/specials/abilities
  - every part `type` is one VFXEffect._make_part knows
  - part keys exist in that part class's code (keys are scraped from src/vfx/vfx_*.gd at run
    time: num/vec/rnd/col/cols/d.get/d.has/d[...]) -> unknown key = WARN (typo, silently ignored)
  - colours parse (#rgb/#rrggbb/#rrggbbaa, optional *k, [r,g,b(,a)], $name(*k)); $name must exist
    in the effect palette (or be main/alt/hot/core, which params can supply -> WARN)
  - types/kinds/specials/abilities entries point at existing effects (cast/travel/impact/big/aoe)
  - vfx.json `abilities` ids exist in data/abilities.json; ability `vfx_id`s exist as effects
  - abilities.json `special`s with no vfx.json specials entry -> INFO (falls back to kind/type)
  - sim `count` > 600 (VFXSim.MAX_PARTICLES) -> WARN; part delay+life > 12 s (effect cap) -> WARN
--coverage prints which abilities get a bespoke look vs the generic element table, and an
"angularity" tally (shard/streak/poly/line/ray parts vs puff/soft/cloud/mist) for the rigid style.
"""
import json, os, re, sys

PART_FILES = {"sim": "vfx_sim", "burst": "vfx_sim", "lightning": "vfx_lightning",
              "flash": "vfx_shape", "ring": "vfx_shape", "pillar": "vfx_shape", "decal": "vfx_shape",
              "tear": "vfx_shape", "scan": "vfx_shape", "streaks": "vfx_shape",
              "shockwave": "vfx_screen", "glitch": "vfx_screen", "light": "vfx_light", "trail": "vfx_trail"}
PALETTE_PARAM_KEYS = {"main", "alt", "hot", "core"}
KEY_RE = re.compile(r'(?:\b(?:num|vec|rnd|col|cols|rangef)\(|d\.get\(|d\.has\(|d\[)\s*"([a-z_0-9]+)"')
COLOR_RE = re.compile(r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})(?:\*[0-9.]+)?$')


def load_jsonc(path):
    txt = open(path, encoding="utf-8").read()
    txt = re.sub(r'^\s*//.*$', '', txt, flags=re.M)
    return json.loads(txt)


def part_keys(repo):
    base = os.path.join(repo, "src", "vfx")
    common = set(KEY_RE.findall(open(os.path.join(base, "vfx_part.gd"), encoding="utf-8").read())) | {"type"}
    out = {}
    for t, f in PART_FILES.items():
        out[t] = common | set(KEY_RE.findall(open(os.path.join(base, f + ".gd"), encoding="utf-8").read()))
    return out


def iter_colors(v, path):
    if isinstance(v, str) and (v.startswith("#") or v.startswith("$")):
        yield path, v
    elif isinstance(v, list):
        if len(v) in (3, 4) and all(isinstance(x, (int, float)) for x in v):
            return
        for i, x in enumerate(v):
            yield from iter_colors(x, f"{path}[{i}]")


def main(argv):
    pos = [a for a in argv if not a.startswith("--")]
    if not pos:
        print(__doc__); return 2
    repo = os.path.abspath(pos[0])
    F = []
    def add(sev, where, msg):
        F.append({"severity": sev, "where": where, "msg": msg})
    try:
        d = load_jsonc(os.path.join(repo, "data", "vfx.json"))
    except Exception as e:
        print(f"error: data/vfx.json does not parse: {e}"); return 1
    keys = part_keys(repo)
    effects = d.get("effects", {})
    for k in ("effects", "types", "kinds", "specials", "abilities"):
        if not isinstance(d.get(k), dict):
            add("error", k, "missing or not an object")
    hdr = total_cols = 0
    angular = soft = 0
    for eid, e in effects.items():
        pal = e.get("palette", {})
        for pk, pv in pal.items():
            for where, c in iter_colors(pv, f"{eid}.palette.{pk}"):
                if c.startswith("$") or not COLOR_RE.match(c):
                    add("error", where, f"bad palette colour {c!r}")
        end = 0.0
        for i, p in enumerate(e.get("parts", [])):
            t = p.get("type", "sim")
            w = f"{eid}.parts[{i}]({t})"
            if t not in PART_FILES:
                add("error", w, f"unknown part type {t!r}"); continue
            for k in p:
                if k not in keys[t]:
                    add("warn", w, f"key {k!r} is not read by {PART_FILES[t]}.gd (typo? silently ignored)")
            for k, v in p.items():
                for where, c in iter_colors(v, f"{w}.{k}"):
                    total_cols += 1
                    if c.startswith("$"):
                        name = c[1:].split("*")[0]
                        if name not in pal:
                            add("warn" if name in PALETTE_PARAM_KEYS else "error", where, f"{c} not in palette {sorted(pal)}" + (" (ok only if callers pass params.color/palette)" if name in PALETTE_PARAM_KEYS else ""))
                        if "*" in c and float(c.split("*")[1]) > 1.0:
                            hdr += 1
                    elif not COLOR_RE.match(c):
                        add("error", where, f"bad colour {c!r}")
                    elif "*" in c and float(c.split("*")[1]) > 1.0:
                        hdr += 1
            if t == "sim" and int(p.get("count", 20)) > 600:
                add("warn", w, f"count {p['count']} > VFXSim.MAX_PARTICLES 600")
            life = p.get("life", 1.0)
            end = max(end, float(p.get("delay", 0)) + (float(life) if isinstance(life, (int, float)) else 1.0))
            tex, render = str(p.get("tex", "")), str(p.get("render", ""))
            if tex in ("shard", "streak", "beam", "chip", "glyph") or render in ("poly", "line", "trail") or t in ("streaks", "lightning", "scan", "tear") or (t == "flash" and p.get("rays")):
                angular += 1
            elif tex in ("puff", "soft", "cloud", "mist") :
                soft += 1
        if end > 12.0:
            add("warn", eid, f"parts run to {end:.1f}s; VFXEffect caps an effect at 12 s")
    for table in ("types", "kinds", "specials", "abilities"):
        for k, v in d.get(table, {}).items():
            refs = [v] if isinstance(v, str) else [v.get(x) for x in ("cast", "travel", "impact", "big", "aoe") if isinstance(v, dict) and v.get(x)]
            for r in refs:
                if r not in effects:
                    add("error", f"{table}.{k}", f"effect {r!r} does not exist")
    abil = load_jsonc(os.path.join(repo, "data", "abilities.json"))
    abil = abil if isinstance(abil, list) else abil.get("abilities", list(abil.values()))
    ids = {a["id"] for a in abil}
    for k in d.get("abilities", {}):
        if k not in ids:
            add("error", f"abilities.{k}", "no such ability in data/abilities.json")
    specials_seen = {}
    bespoke, generic = [], {}
    for a in abil:
        vid = a.get("vfx_id", "")
        if vid and vid not in effects:
            add("error", f"abilities.json:{a['id']}", f"vfx_id {vid!r} is not an effect")
        sp = a.get("special", "")
        if sp:
            specials_seen.setdefault(sp.split(".")[0], []).append(a["id"])
        kind = str(a.get("kind", "ATTACK")).upper()
        if (vid and vid in effects) or a["id"] in d.get("abilities", {}) or (sp and (sp in d["specials"] or sp.split(".")[0] in d["specials"])):
            bespoke.append(a["id"])
        else:
            dtype = str(a.get("damage_type", "physical")).lower()
            # Same rule as VFX.plan_for_ability: kinds win only for physical (or any HEAL).
            key = kind if kind in ("HEAL", "BUFF", "DEBUFF", "UTILITY") and (dtype == "physical" or kind == "HEAL") else "type:" + dtype
            generic.setdefault(key, []).append(a["id"])
    for sp, who in sorted(specials_seen.items()):
        if sp not in d.get("specials", {}):
            add("info", f"special {sp}", f"no vfx.json specials entry; {len(who)} abilit{'y' if len(who)==1 else 'ies'} fall back to kind/type ({', '.join(who[:4])}{'…' if len(who)>4 else ''})")
    if "--json" in argv:
        print(json.dumps({"effects": len(effects), "findings": F, "bespoke": bespoke, "generic": generic,
                          "hdr_colours": hdr, "colours": total_cols, "angular_parts": angular, "soft_parts": soft}, indent=2))
    else:
        order = {"error": 0, "warn": 1, "info": 2}
        for f in sorted(F, key=lambda f: (order[f["severity"]], f["where"])):
            print(f"{f['severity']:5} {f['where']}: {f['msg']}")
        c = {s: sum(1 for f in F if f["severity"] == s) for s in order}
        print(f"\n{len(effects)} effects: {c['error']} error, {c['warn']} warn, {c['info']} info")
        if "--coverage" in argv:
            nk = sum(len(v) for k, v in generic.items() if not k.startswith("type:"))
            nt = sum(len(v) for k, v in generic.items() if k.startswith("type:"))
            print(f"\nCoverage: {len(bespoke)}/{len(abil)} bespoke (vfx_id / abilities / specials), {nk} by kind (HEAL/BUFF/DEBUFF/UTILITY look), {nt} by element (types table)")
            for k, v in sorted(generic.items(), key=lambda kv: -len(kv[1])):
                print(f"  generic {k:16} {len(v):3}  e.g. {', '.join(v[:5])}")
            print(f"Taste: {hdr}/{total_cols} part colours are HDR (>1); parts angular={angular} soft={soft}")
    errs = any(f["severity"] == "error" for f in F)
    return 1 if errs or ("--strict" in argv and any(f["severity"] == "warn" for f in F)) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
