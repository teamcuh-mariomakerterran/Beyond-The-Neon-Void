#!/usr/bin/env python3
"""Compare two ai_probe JSON reports (before/after an AI change) and flag regressions.

  python probe_diff.py before.json after.json [--strict]

Flags per mission/team: win-rate change, new stalemates, AP-unused up, idle% up,
ms/turn up >50% or max >150 ms. Exit 1 with --strict if any regression flagged.
"""
import json, sys

def load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)

def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    strict = "--strict" in argv
    if len(args) != 2:
        print(__doc__); return 2
    a, b = load(args[0]), load(args[1])
    bad = 0
    for mid in sorted(set(a) | set(b)):
        if mid not in a or mid not in b:
            print(f"{mid}: only in {'after' if mid in b else 'before'}"); continue
        ma, mb = a[mid], b[mid]
        wa, wb = ma["wins"] / max(ma["runs"], 1), mb["wins"] / max(mb["runs"], 1)
        line = f"{mid}: wins {ma['wins']}/{ma['runs']} -> {mb['wins']}/{mb['runs']}, stalemates {ma['capped']} -> {mb['capped']}"
        flags = []
        if mb["capped"] > ma["capped"]:
            flags.append("MORE STALEMATES")
        if abs(wb - wa) >= 0.34:
            flags.append(f"win-rate shift {wa:.0%}->{wb:.0%} (check balance band)")
        print(line + ("  !! " + "; ".join(flags) if flags else ""))
        bad += len([f for f in flags if f.startswith("MORE")])
        for team in ("player", "enemy"):
            ta, tb = ma["teams"].get(team), mb["teams"].get(team)
            if not ta or not tb:
                continue
            tf = []
            if tb["ap_unused_per_turn"] > ta["ap_unused_per_turn"] + 0.15:
                tf.append("AP unused up")
            if tb["idle_pct"] > ta["idle_pct"] + 10:
                tf.append("idle% up")
            if tb["ms_per_turn"] > ta["ms_per_turn"] * 1.5 + 2 or tb["max_ms"] > 150:
                tf.append("slower planning")
            bad += len(tf)
            print(f"  {team:6} act/turn {ta['actions_per_turn']:.2f}->{tb['actions_per_turn']:.2f}  AP unused {ta['ap_unused_per_turn']:.2f}->{tb['ap_unused_per_turn']:.2f}"
                  f"  idle {ta['idle_pct']:.0f}%->{tb['idle_pct']:.0f}%  ms {ta['ms_per_turn']:.1f}->{tb['ms_per_turn']:.1f} (max {tb['max_ms']:.0f})"
                  + ("  !! " + ", ".join(tf) if tf else ""))
    print(f"\n{bad} regression flag(s)")
    return 1 if strict and bad else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
