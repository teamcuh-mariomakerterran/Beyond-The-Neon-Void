#!/usr/bin/env python3
"""Insert or replace ONE effect (and optional mapping rows) in data/vfx.json, written in the
file's house style (tab indent, palette inline, one part per line) so the git diff shows only
your change. Every other byte stays identical; the result is re-parsed before writing.

  python vfx_upsert.py <repo> <effect.json> [--id=NAME] [--map=table:key[:field]] ... [--dry-run]

<effect.json> is either a bare effect def {palette, parts, ...} (needs --id) or {"id": def}.
--map adds/updates a mapping row pointing at the effect, e.g.
   --map=abilities:plasma_ram            -> "plasma_ram": {"impact": "<id>"}
   --map=abilities:plasma_ram:travel     -> sets only "travel"
   --map=types:plasma:big                -> types.plasma.big = <id>
Tables: abilities | specials | kinds | types. Keys in `abilities` must exist in abilities.json.
--dry-run prints a unified diff instead of writing. Run vfx_lint.py afterwards.
"""
import difflib, json, os, re, sys

SEP = (", ", ": ")


def fmt_effect(eid, e):
    lines = [f'\t\t{json.dumps(eid)}: {{']
    keys = [k for k in e if k != "parts"]
    body = []
    if "palette" in e:
        keys.remove("palette")
        body.append(f'\t\t\t"palette": {json.dumps(e["palette"], separators=SEP)}')
    for k in keys:
        body.append(f'\t\t\t{json.dumps(k)}: {json.dumps(e[k], separators=SEP)}')
    parts = e.get("parts", [])
    pl = ['\t\t\t"parts": [']
    for i, p in enumerate(parts):
        pl.append("\t\t\t\t" + json.dumps(p, separators=SEP) + ("," if i < len(parts) - 1 else ""))
    pl.append("\t\t\t]")
    body.append("\n".join(pl))
    lines.append(",\n".join(body))
    lines.append("\t\t}")
    return "\n".join(lines)


def block_range(lines, start_pat, indent):
    """(first, last) line indexes of a block opened by a line matching start_pat and closed by
    the first following line that is exactly indent + '}' or indent + '},'."""
    for i, l in enumerate(lines):
        if re.match(start_pat, l):
            for j in range(i + 1, len(lines)):
                if lines[j] in (indent + "}", indent + "},"):
                    return i, j
    return None


def main(argv):
    pos = [a for a in argv if not a.startswith("--")]
    opts = [a for a in argv if a.startswith("--")]
    if len(pos) < 2:
        print(__doc__); return 2
    repo, src = pos[0], pos[1]
    path = os.path.join(repo, "data", "vfx.json")
    text = open(path, encoding="utf-8").read()
    data = json.loads(text)
    new = json.load(open(src, encoding="utf-8"))
    eid = next((o.split("=", 1)[1] for o in opts if o.startswith("--id=")), None)
    if eid is None:
        if len(new) == 1 and isinstance(next(iter(new.values())), dict) and "parts" in next(iter(new.values())):
            eid, new = next(iter(new.items()))
        else:
            print("Give --id=NAME for a bare effect def"); return 2
    if "parts" not in new:
        print("Effect def needs a parts list"); return 2
    lines = text.split("\n")
    eff = block_range(lines, r'^\t"effects": \{$', "\t")
    if not eff:
        print("Could not find the effects block (format changed?)"); return 2
    rng = block_range(lines[eff[0]:eff[1] + 1], r'^\t\t' + re.escape(json.dumps(eid)) + r': \{$', "\t\t")
    block = fmt_effect(eid, new).split("\n")
    if rng:
        a, b = eff[0] + rng[0], eff[0] + rng[1]
        trailing = lines[b].endswith(",")
        if trailing:
            block[-1] += ","
        lines[a:b + 1] = block
        action = "replaced"
    else:
        close = eff[1]
        lines[close - 1] = lines[close - 1] if lines[close - 1].endswith(",") else lines[close - 1] + ","
        lines[close:close] = block
        action = "inserted"
    abil_ids = None
    for o in opts:
        if not o.startswith("--map="):
            continue
        bits = o.split("=", 1)[1].split(":")
        table, key = bits[0], bits[1]
        field = bits[2] if len(bits) > 2 else "impact"
        if table not in ("abilities", "specials", "kinds", "types"):
            print(f"bad table {table}"); return 2
        if table == "abilities":
            if abil_ids is None:
                a = re.sub(r'^\s*//.*$', '', open(os.path.join(repo, "data", "abilities.json"), encoding="utf-8").read(), flags=re.M)
                a = json.loads(a)
                abil_ids = {x["id"] for x in (a if isinstance(a, list) else a.get("abilities", list(a.values())))}
            if key not in abil_ids:
                print(f"ability {key} not in abilities.json"); return 2
        tb = block_range(lines, r'^\t' + json.dumps(table) + r': \{$', "\t")
        row = {}
        cur = data.get(table, {}).get(key)
        if isinstance(cur, dict):
            row = dict(cur)
        row[field] = eid
        txt = f'\t\t{json.dumps(key)}: {json.dumps(row, separators=SEP)}'
        hit = None
        for i in range(tb[0] + 1, tb[1]):
            if lines[i].startswith(f'\t\t{json.dumps(key)}: '):
                hit = i
        if hit is not None:
            lines[hit] = txt + ("," if lines[hit].endswith(",") else "")
        else:
            if not lines[tb[1] - 1].endswith(","):
                lines[tb[1] - 1] += ","
            lines.insert(tb[1], txt)
    out = "\n".join(lines)
    json.loads(out)  # must still parse
    if "--dry-run" in opts:
        sys.stdout.writelines(difflib.unified_diff(text.splitlines(True), out.splitlines(True), "a/data/vfx.json", "b/data/vfx.json"))
        print(f"\n(dry run) would have {action} effect {eid!r}")
        return 0
    open(path, "w", encoding="utf-8", newline="").write(out)
    print(f"{action} effect {eid!r} in {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
