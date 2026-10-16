#!/usr/bin/env python3
"""Static lint for BTNV shaders: *.gdshader / *.gdshaderinc files AND inline shaders in
GDScript string constants (\"\"\"...shader_type...\"\"\"). No Godot needed.

  python shader_lint.py <repo> [--json] [--strict]

Rules (id: severity):
  double-color  : error  `texture(TEXTURE, uv) * COLOR` in fragment(). In Godot 4 canvas_item
                  fragment COLOR already = vertex colour x modulate x TEXTURE, so this squares
                  rgb and alpha (verified on 4.7.2: 0.5 grey/0.5 a renders 0.06 instead of 0.25).
                  Fix: pass modulate from vertex() in a varying, or use COLOR alone.
  godot3-api    : error  SCREEN_TEXTURE / hint_color / hint_albedo / WORLD_MATRIX (Godot 3 names).
  screen-lod    : warn   textureLod() on a hint_screen_texture sampler without filter_*_mipmap.
  color-hint    : warn   `uniform vec4 <name>` that looks like a colour without `source_color`
                  (wrong in linear/HDR; inspector shows a vector instead of a colour picker).
  sin-hash      : info   fract(sin(dot(...))*43758...) hash: fine on desktop, banding/precision
                  issues on some mobile/low-precision GPUs and at large inputs (TIME*k).
  big-loop      : info   nested loops in fragment (cost x pixels; e.g. Voronoi 3x3 = 9 taps).
  no-reduce-motion: info full-screen shader animates with TIME but has no intensity/strength uniform
                  to scale (SettingsFlags.reduce_motion needs a knob).
Suppress a finding by putting `// lint:ok <reason>` on that shader line (e.g. an intentionally
raw HDR colour uniform). Exit 1 if any error (or any warn with --strict).
"""
import json, os, re, sys

SKIP_DIRS = {".godot", ".git", "legacy", "addons", "build", "export", ".claude"}

def shaders(repo):
    for root, dirs, files in os.walk(repo):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not os.path.exists(os.path.join(root, d, ".gdignore"))]
        for f in files:
            p = os.path.join(root, f)
            rel = os.path.relpath(p, repo).replace("\\", "/")
            if f.endswith((".gdshader", ".gdshaderinc")):
                yield rel, 1, open(p, encoding="utf-8", errors="replace").read()
            elif f.endswith(".gd"):
                src = open(p, encoding="utf-8", errors="replace").read()
                for m in re.finditer(r'"""(.*?)"""', src, re.S):
                    if "shader_type" in m.group(1):
                        line0 = src.count("\n", 0, m.start(1)) + 1
                        name = re.search(r'(?:const\s+([A-Z_0-9]+)[^\n]*|(\.code)\s*=\s*)$', src[:m.start()].rsplit("\n", 1)[-1])
                        tag = (name.group(1) or "code") if name else "inline"
                        yield f"{rel}:{tag}", line0, m.group(1)

def fn_body(code, name):
    m = re.search(r'void\s+' + name + r'\s*\(\s*\)\s*\{', code)
    if not m:
        return None, 0
    i, depth = m.end(), 1
    while i < len(code) and depth:
        depth += {"{": 1, "}": -1}.get(code[i], 0)
        i += 1
    return code[m.end():i - 1], m.end()

def lint(sid, line0, code):
    out = []
    lines = code.split("\n")
    def add(rule, sev, pos, msg):
        ln = code.count("\n", 0, pos)
        if ln < len(lines) and "lint:ok" in lines[ln]:
            return
        out.append({"shader": sid, "line": line0 + code.count("\n", 0, pos), "rule": rule, "severity": sev, "msg": msg})
    frag, fpos = fn_body(code, "fragment")
    if frag is not None and "canvas_item" in code:
        for m in re.finditer(r'texture\s*\(\s*TEXTURE\s*,[^;]*?\)\s*(?:\.\w+\s*)?\*\s*COLOR\b|COLOR(?:\.\w+)?\s*\*\s*texture\s*\(\s*TEXTURE', frag):
            add("double-color", "error", fpos + m.start(), "texture(TEXTURE)*COLOR double-applies the texture in Godot 4 (COLOR already includes it)")
        loops = [m.start() for m in re.finditer(r'\bfor\s*\(', frag)]
        if len(loops) >= 2:
            add("big-loop", "info", fpos + loops[0], f"{len(loops)} loops in fragment(): cost scales with covered pixels")
    for m in re.finditer(r'\b(SCREEN_TEXTURE|hint_color|hint_albedo|WORLD_MATRIX)\b', code):
        add("godot3-api", "error", m.start(), f"Godot 3 name {m.group(1)}")
    screens = re.findall(r'uniform\s+sampler2D\s+(\w+)\s*:\s*([^;]*hint_screen_texture[^;]*);', code)
    for name, hints in screens:
        if "mipmap" not in hints:
            for m in re.finditer(r'textureLod\s*\(\s*' + name + r'\b', code):
                add("screen-lod", "warn", m.start(), f"textureLod on {name} without filter_*_mipmap: LOD is ignored")
    for m in re.finditer(r'uniform\s+vec4\s+(\w+)\s*(:[^=;]*)?(=|;)', code):
        name, hints = m.group(1), m.group(2) or ""
        if re.search(r'col|tint|rim|glow|haze|ray|light|edge|hue|fog', name, re.I) and "source_color" not in hints:
            add("color-hint", "warn", m.start(), f"vec4 {name} looks like a colour but has no source_color hint (if it is deliberately raw/HDR, mark // lint:ok)")
    for m in re.finditer(r'fract\s*\(\s*sin\s*\(', code):
        add("sin-hash", "info", m.start(), "sin-hash: precision varies by GPU; consider an integer/PCG hash for wide-range inputs")
    if "hint_screen_texture" in code and "TIME" in code and not re.search(r'uniform\s+float\s+(intensity|strength|amount|fade|power)\b', code):
        add("no-reduce-motion", "info", 0, "animated screen shader without an intensity-style uniform to scale for reduce_motion")
    return out

def main(argv):
    pos = [a for a in argv if not a.startswith("--")]
    if not pos:
        print(__doc__); return 2
    repo = os.path.abspath(pos[0])
    findings, n = [], 0
    for sid, line0, code in shaders(repo):
        n += 1
        findings += lint(sid, line0, code)
    if "--json" in argv:
        print(json.dumps({"shaders": n, "findings": findings}, indent=2))
    else:
        order = {"error": 0, "warn": 1, "info": 2}
        for f in sorted(findings, key=lambda f: (order[f["severity"]], f["shader"], f["line"])):
            print(f"{f['severity']:5} {f['rule']:16} {f['shader']} (line {f['line']}): {f['msg']}")
        c = {s: sum(1 for f in findings if f["severity"] == s) for s in order}
        print(f"\n{n} shader(s): {c['error']} error, {c['warn']} warn, {c['info']} info")
    errs = any(f["severity"] == "error" for f in findings)
    warns = any(f["severity"] == "warn" for f in findings)
    return 1 if errs or ("--strict" in argv and warns) else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
