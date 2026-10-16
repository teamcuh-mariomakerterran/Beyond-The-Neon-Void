#!/usr/bin/env python3
"""Compile every BTNV shader (.gdshader files + inline GDScript string shaders) on a
real renderer and fail on any SHADER ERROR. Wraps gd/shader_check.gd.

  python shader_check.py <repo> [--godot=PATH] [--compat] [--only=substr] [--strict] [--log=FILE]

--strict   shader WARNINGs (e.g. a missing global uniform) also fail.

Godot path: --godot, else $GODOT, else 'godot' on PATH.
--compat   adds --rendering-method gl_compatibility (the box/CI path; also what
           headless-ish screenshot harnesses use). Without it the project's own
           renderer is used (Forward+ on Brian's PC). Run BOTH before shipping a shader:
           some built-ins/hints behave differently between the two.
On Linux without a usable display, it wraps the run in `xvfb-run -a`.
Exit: 0 all compiled, 1 shader errors, 2 harness failure.
"""
import os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))

def main(argv):
    opts = {a.split("=", 1)[0][2:]: (a.split("=", 1)[1] if "=" in a else True) for a in argv if a.startswith("--")}
    pos = [a for a in argv if not a.startswith("--")]
    if not pos:
        print(__doc__); return 2
    repo = os.path.abspath(pos[0])
    godot = opts.get("godot") or os.environ.get("GODOT") or "godot"
    script = os.path.join(HERE, "gd", "shader_check.gd").replace("\\", "/")
    cmd = [godot, "--path", repo, "--resolution", "640x360", "-s", script]
    if opts.get("compat"):
        cmd[1:1] = ["--rendering-method", "gl_compatibility"]
    if opts.get("only"):
        cmd += ["--", "--only=" + str(opts["only"])]
    if sys.platform.startswith("linux") and shutil.which("xvfb-run") and not os.environ.get("BTNV_USE_DISPLAY"):
        cmd = ["xvfb-run", "-a"] + cmd
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=900, encoding="utf-8", errors="replace")
    except FileNotFoundError:
        print(f"Godot not found: {godot} (set $GODOT or --godot=)"); return 2
    except subprocess.TimeoutExpired:
        print("Timed out (15 min)"); return 2
    out = p.stdout  # stderr merged in order, so errors land between @@BEGIN/@@END
    if opts.get("log"):
        with open(opts["log"], "w", encoding="utf-8") as f:
            f.write(out)
    if "@@FATAL" in out:
        print(re.search(r"@@FATAL.*", out).group(0)); return 2
    if "@@DONE" not in out:
        print("Harness did not finish. Tail of log:\n" + "\n".join(out.splitlines()[-30:])); return 2
    renderer = re.search(r"@@RENDERER (.*)", out)
    merged = out
    cur, errors, warns, seen = None, {}, {}, []
    for line in merged.splitlines():
        m = re.match(r"@@BEGIN (.*)", line)
        if m:
            cur = m.group(1); seen.append(cur); continue
        if line.startswith("@@END"):
            cur = None; continue
        if "SHADER ERROR" in line or re.match(r"\s*E\s+\d+->", line):
            errors.setdefault(cur or "?", []).append(line.strip())
        elif cur and line.startswith("WARNING:") and re.search(r"[Ss]hader|uniform|global parameter", line):
            warns.setdefault(cur, []).append(line.strip())
    print(f"renderer: {renderer.group(1) if renderer else '?'}  shaders: {len(seen)}")
    for sid in seen:
        print(("FAIL " if sid in errors else "warn " if sid in warns else "ok   ") + sid)
        for e in errors.get(sid, []) + warns.get(sid, []):
            print("       " + e)
    if "?" in errors:
        print("Unattributed shader errors:\n  " + "\n  ".join(errors["?"]))
    print(f"\n{len([s for s in errors if s != '?'])} failing shader(s), {len(warns)} with warnings")
    return 1 if errors or (opts.get("strict") and warns) else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
