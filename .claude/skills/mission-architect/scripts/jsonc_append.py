#!/usr/bin/env python3
"""Strip // comments from a filled-in template and append it to a BTNV data array.

Usage:  python jsonc_append.py <entry.jsonc> <repo>/data/missions.json [--dry-run]
Refuses duplicates by id, keeps the file's 2-space/tab style guess, prints a diff summary.
Run validate_campaign.py afterwards.
"""
import json, re, sys

def strip_jsonc(t):
    out, i, q = [], 0, False
    while i < len(t):
        ch = t[i]
        if q:
            out.append(ch)
            if ch == "\\":
                out.append(t[i + 1]); i += 1
            elif ch == '"':
                q = False
        elif ch == '"':
            q = True; out.append(ch)
        elif t.startswith("//", i):
            while i < len(t) and t[i] != "\n":
                i += 1
            continue
        else:
            out.append(ch)
        i += 1
    s = "".join(out)
    return re.sub(r",(\s*[}\]])", r"\1", s)

def main():
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    if len(a) != 2:
        print(__doc__); sys.exit(2)
    entry = json.loads(strip_jsonc(open(a[0], encoding="utf-8").read()))
    raw = open(a[1], encoding="utf-8").read()
    data = json.loads(raw)
    if not isinstance(data, list):
        sys.exit(f"{a[1]} is not a JSON array (rumors.json is a dict: edit by key)")
    if any(isinstance(d, dict) and d.get("id") == entry.get("id") for d in data):
        sys.exit(f"id '{entry.get('id')}' already exists in {a[1]}")
    if "<" in json.dumps(entry):
        print("warning: entry still contains <placeholders>")
    data.append(entry)
    indent = "\t" if "\n\t" in raw[:200] else 2
    if "--dry-run" in sys.argv:
        print(json.dumps(entry, indent=2, ensure_ascii=False)); return
    with open(a[1], "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(data, indent=indent, ensure_ascii=False) + "\n")
    print(f"appended {entry.get('id')} -> {a[1]} ({len(data)} entries)")

if __name__ == "__main__":
    main()
