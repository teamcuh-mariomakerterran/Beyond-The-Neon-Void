#!/usr/bin/env python3
"""Schema-check Beyond The Neon Void's data/*.json against the GDScript @export vars.

Why: GameResource.apply_dict() silently DROPS keys that don't match an @export var,
and coerces types loosely. A typo ("soul_coins_reward") or a wrong type (a dict where
an Array[String] is expected) just vanishes at runtime. This catches it before Godot runs.

Usage:
  python validate_data.py <repo_root> [--json] [--strict] [--no-campaign] [--bucket missions]

Checks
  * every ContentDB.CATALOG bucket (classes, abilities, cards, status_effects, items,
    characters, missions, loot_tables, dispatch_missions, quests, npcs, passives):
    JSON parses, entries have unique string ids, every key is a real @export var of the
    resource class (abilities honour "script": kinetic/time/terrain subclasses), value
    types match (String/int/float/bool/Array[String]/Array[Dictionary]/Dictionary/enum
    names from the GDScript enum)
  * plain-dict files (terrain, vendors, rumors, recipes, particles, tiles, cues, vfx,
    signage, status_looks): parse and are objects
  * data/maps/*.json: parse, have an id, id unique across files
  * then runs mission-architect/scripts/validate_campaign.py if it sits beside this
    skill (cross references + reachability), unless --no-campaign
Exit code: 1 on errors (or warnings with --strict), else 0.  Read-only.
"""
import difflib, glob, json, os, re, subprocess, sys

ANNOT = re.compile(r"^\s*@export(?!_group|_category|_subgroup)\w*(\([^)]*\))?\s*(?:\n\s*)?(?:@\w+(\([^)]*\))?\s*)*var\s+(\w+)\s*(?::\s*([\w\[\]]+))?\s*(:?=)?\s*(.*)$", re.M)
ENUM = re.compile(r"^enum\s+(\w+)\s*\{([^}]*)\}", re.M)
CLASS = re.compile(r"^class_name\s+(\w+)", re.M)
EXT = re.compile(r"^extends\s+(\w+)", re.M)
DICT_FILES = ["terrain", "vendors", "rumors", "recipes", "particles", "tiles", "cues", "vfx", "signage", "status_looks"]
META_KEYS = {"abilities": {"script"}}


class Rep:
    def __init__(s):
        s.errors, s.warnings = [], []
    def err(s, w, m): s.errors.append(f"{w}: {m}")
    def warn(s, w, m): s.warnings.append(f"{w}: {m}")


def scan_scripts(root):
    classes = {}
    for p in glob.glob(os.path.join(root, "src", "**", "*.gd"), recursive=True):
        if os.sep + "legacy" + os.sep in p:
            continue
        t = open(p, encoding="utf-8", errors="replace").read()
        m = CLASS.search(t)
        if not m:
            continue
        enums = {n: [x.split("=")[0].strip() for x in body.replace("\n", " ").split(",") if x.strip()] for n, body in ENUM.findall(t)}
        fields = {}
        # join annotation-only lines with the following var line
        t2 = re.sub(r"(@export\w*(?:\([^)]*\))?)[ \t]*\n[ \t]*(var\s)", r"\1 \2", t)
        for line in t2.splitlines():
            mm = re.match(r"^\s*@export(?!_group|_category|_subgroup)\w*(?:\([^)]*\))?\s+(?:@\w+(?:\([^)]*\))?\s+)*var\s+(\w+)\s*(?::\s*([\w\[\]\.]+))?\s*(:?=)?\s*(.*)$", line)
            if mm:
                name, typ, op, default = mm.groups()
                if not typ and op == ":=":
                    d = default.strip()
                    typ = "String" if d.startswith('"') else "bool" if d in ("true", "false") else "float" if re.match(r"^-?\d+\.\d*", d) else "int" if re.match(r"^-?\d+$", d) else "Dictionary" if d.startswith("{") else "Array" if d.startswith("[") else "?"
                fields[name] = typ or "?"
        ex = EXT.search(t)
        classes[m.group(1)] = {"path": os.path.relpath(p, root), "extends": ex.group(1) if ex else "", "fields": fields, "enums": enums}
    return classes


def all_fields(classes, name):
    out, enums, seen = {}, {}, set()
    while name in classes and name not in seen:
        seen.add(name)
        c = classes[name]
        for k, v in c["fields"].items():
            out.setdefault(k, v)
        for k, v in c["enums"].items():
            enums.setdefault(k, v)
        name = c["extends"]
    return out, enums


def parse_catalog(root):
    t = open(os.path.join(root, "src", "autoload", "content_db.gd"), encoding="utf-8").read()
    cat = dict(re.findall(r'"(\w+)":\s*(\w+),', re.search(r"var CATALOG := \{(.*?)\}", t, re.S).group(1)))
    m = re.search(r"var ABILITY_SCRIPTS := \{(.*?)\}", t, re.S)
    scripts = dict(re.findall(r'"(\w+)":\s*(\w+),', m.group(1))) if m else {}
    return cat, scripts


def jload(path, R, where):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return None
    except json.JSONDecodeError as e:
        R.err(where, f"JSON parse error line {e.lineno} col {e.colno}: {e.msg}")
        return None


def type_ok(typ, v, enums):
    if typ in ("?", "Variant", ""):
        return True, ""
    base = typ.split(".")[-1]
    if base == "String" or base == "StringName":
        return isinstance(v, str), "String"
    if base == "int":
        return (isinstance(v, int) and not isinstance(v, bool)) or (isinstance(v, float) and v.is_integer()), "int"
    if base == "float":
        return isinstance(v, (int, float)) and not isinstance(v, bool), "float"
    if base == "bool":
        return isinstance(v, bool), "bool"
    if base == "Dictionary" or base.startswith("Dictionary["):
        return isinstance(v, dict), "Dictionary"
    if base == "Array[String]":
        return isinstance(v, list) and all(isinstance(x, str) for x in v), "Array[String]"
    if base == "Array[int]":
        return isinstance(v, list) and all(isinstance(x, (int, float)) and not isinstance(x, bool) for x in v), "Array[int]"
    if base == "Array[Dictionary]":
        return isinstance(v, list) and all(isinstance(x, dict) for x in v), "Array[Dictionary]"
    if base.startswith("Array"):
        return isinstance(v, list), "Array"
    if base in ("Color",):
        return isinstance(v, (str, list)), "Color (\"#rrggbb\" or [r,g,b(,a)])"
    if base in ("Vector2i", "Vector2"):
        return isinstance(v, list) and len(v) >= 2, base + " ([x, y])"
    if base in enums:
        names = [n.upper().replace(" ", "_") for n in enums[base]]
        if isinstance(v, str):
            return v.strip().upper().replace(" ", "_") in names, f"enum {base} {enums[base]}"
        return isinstance(v, int) and 0 <= v < len(names) + 32, f"enum {base}"
    return True, ""  # resource / object refs etc.


def check_bucket(root, bucket, cls, classes, scripts, R):
    D = os.path.join(root, "data")
    path = os.path.join(D, bucket + ".json")
    W0 = f"data/{bucket}.json"
    data = jload(path, R, W0)
    if data is None:
        if not os.path.exists(path):
            R.warn(W0, "missing (bucket stays empty)")
        return 0
    entries = data if isinstance(data, list) else data.get("entries") if isinstance(data, dict) else None
    if not isinstance(entries, list):
        R.err(W0, "must be an array or {\"entries\": [...]}")
        return 0
    base_fields, base_enums = all_fields(classes, cls)
    if not base_fields:
        R.warn(W0, f"class {cls} not found under src/ (skipping key checks)")
    ids = {}
    for i, e in enumerate(entries):
        W = f"{W0}[{i}]"
        if not isinstance(e, dict) or "id" not in e:
            R.err(W, "entry without id (ContentDB skips it)")
            continue
        eid = e["id"]
        W = f"{W0} {eid}"
        if not isinstance(eid, str) or not eid:
            R.err(W, "id must be a non-empty string")
        elif eid in ids:
            R.err(W, f"duplicate id (entries {ids[eid]} and {i}; the later one wins)")
        else:
            ids[eid] = i
        fields, enums = base_fields, base_enums
        if bucket == "abilities" and e.get("script"):
            if e["script"] not in scripts:
                R.err(W, f"script '{e['script']}' not in ContentDB.ABILITY_SCRIPTS {sorted(scripts)}")
            else:
                fields, enums = all_fields(classes, scripts[e["script"]])
        if not fields:
            continue
        for k, v in e.items():
            if k in META_KEYS.get(bucket, set()):
                continue
            if k not in fields:
                near = difflib.get_close_matches(k, fields.keys(), 1, 0.75)
                R.err(W, f"key '{k}' is not an @export var of {cls}" + (f" (did you mean '{near[0]}'?)" if near else "") + ": apply_dict drops it silently")
                continue
            ok, want = type_ok(fields[k], v, enums)
            if not ok:
                R.err(W, f"'{k}' should be {want}, got {type(v).__name__} {json.dumps(v)[:60]}")
    return len(entries)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = os.path.abspath(args[0] if args else ".")
    only = next((sys.argv[i + 1] for i, a in enumerate(sys.argv) if a == "--bucket" and i + 1 < len(sys.argv)), None)
    if not os.path.exists(os.path.join(root, "project.godot")):
        sys.exit(f"{root} has no project.godot")
    R = Rep()
    classes = scan_scripts(root)
    cat, scripts = parse_catalog(root)
    counts = {}
    for bucket, cls in cat.items():
        if only and bucket != only:
            continue
        counts[bucket] = check_bucket(root, bucket, cls, classes, scripts, R)
    D = os.path.join(root, "data")
    if not only:
        for name in DICT_FILES:
            p = os.path.join(D, name + ".json")
            if os.path.exists(p):
                d = jload(p, R, f"data/{name}.json")
                if d is not None and not isinstance(d, (dict, list)):
                    R.err(f"data/{name}.json", "must be a JSON object")
        seen = {}
        for p in sorted(glob.glob(os.path.join(D, "maps", "*.json"))):
            W = "data/maps/" + os.path.basename(p)
            d = jload(p, R, W)
            if d is None:
                continue
            if not isinstance(d, dict):
                R.err(W, "map must be an object"); continue
            mid = str(d.get("id", os.path.splitext(os.path.basename(p))[0]))
            if mid in seen:
                R.err(W, f"map id '{mid}' also in {seen[mid]} (one silently replaces the other)")
            seen[mid] = W
            if "id" not in d:
                R.warn(W, "no id (falls back to the file name)")
        counts["maps"] = len(seen)
    camp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "mission-architect", "scripts", "validate_campaign.py")
    campaign = None
    if not only and "--no-campaign" not in sys.argv and os.path.exists(camp):
        out = subprocess.run([sys.executable, camp, root, "--json"], capture_output=True, text=True)
        try:
            campaign = json.loads(out.stdout)
            fmt = lambda x: "campaign " + (": ".join(x[1:]) if isinstance(x, list) else str(x))
            R.errors += [fmt(x) for x in campaign.get("errors", [])]
            R.warnings += [fmt(x) for x in campaign.get("warnings", [])]
        except Exception:
            R.warn("campaign", "validate_campaign.py did not return JSON: " + (out.stderr or out.stdout)[-300:])
    if "--json" in sys.argv:
        print(json.dumps({"errors": R.errors, "warnings": R.warnings, "counts": counts}, indent=2))
    else:
        for e in R.errors:
            print("ERROR", e)
        for w in R.warnings:
            print("warn ", w)
        print("checked: " + ", ".join(f"{k} {v}" for k, v in counts.items()))
        print(f"DATA {'OK' if not R.errors else 'FAIL'}: {len(R.errors)} error(s), {len(R.warnings)} warning(s)")
    sys.exit(1 if R.errors or ("--strict" in sys.argv and R.warnings) else 0)


if __name__ == "__main__":
    main()
