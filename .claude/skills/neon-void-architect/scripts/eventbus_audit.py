#!/usr/bin/env python3
"""EventBus contract audit for Beyond The Neon Void.

Lists every signal declared in src/autoload/event_bus.gd with who emits it and
who connects to it, and flags:
  - signals nobody emits (dead contract)
  - signals nobody listens to (fire-and-forget; fine for logging, suspicious otherwise)
  - EventBus.<name> references to signals that are not declared (typos / removed)

Usage:  python eventbus_audit.py [repo_root] [--json]
Read-only. Works on Windows (py -3 eventbus_audit.py C:\\path\\to\\repo).
"""
import json, os, re, sys

def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = os.path.abspath(args[0] if args else ".")
    bus = os.path.join(root, "src", "autoload", "event_bus.gd")
    if not os.path.isfile(bus):
        print(f"event_bus.gd not found under {root}/src/autoload", file=sys.stderr)
        return 2
    decl = {}
    for line in open(bus, encoding="utf-8"):
        m = re.match(r"\s*signal\s+(\w+)\s*(\(([^)]*)\))?", line)
        if m:
            decl[m.group(1)] = (m.group(3) or "").strip()
    emit, conn, unknown = {k: set() for k in decl}, {k: set() for k in decl}, {}
    pat = re.compile(r"EventBus\.(\w+)(\.(emit|connect|disconnect|is_connected))?")
    for dp, dn, fn in os.walk(os.path.join(root, "src")):
        for f in fn:
            if not f.endswith(".gd"):
                continue
            p = os.path.join(dp, f)
            rel = os.path.relpath(p, root).replace("\\", "/")
            for i, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
                for m in pat.finditer(line):
                    name, op = m.group(1), m.group(3)
                    if name in decl:
                        if op == "emit":
                            emit[name].add(rel)
                        elif op in ("connect", "disconnect", "is_connected"):
                            conn[name].add(rel)
                    elif op:
                        unknown.setdefault(name, set()).add(f"{rel}:{i}")
    if "--json" in sys.argv:
        print(json.dumps({k: {"args": decl[k], "emitters": sorted(emit[k]), "listeners": sorted(conn[k])} for k in decl}
                         | {"_unknown": {k: sorted(v) for k, v in unknown.items()}}, indent=2))
        return 0
    print(f"EventBus: {len(decl)} signals  ({bus})\n")
    for k, a in decl.items():
        flag = "" if emit[k] and conn[k] else ("  <-- NO EMITTER" if not emit[k] else "  (no listener)")
        print(f"{k}({a}){flag}")
        print(f"    emit:   {', '.join(sorted(emit[k])) or '-'}")
        print(f"    listen: {', '.join(sorted(conn[k])) or '-'}")
    if unknown:
        print("\nUNDECLARED EventBus members used with emit/connect:")
        for k, v in unknown.items():
            print(f"  {k}: {', '.join(sorted(v))}")
    return 1 if unknown else 0

if __name__ == "__main__":
    sys.exit(main())
