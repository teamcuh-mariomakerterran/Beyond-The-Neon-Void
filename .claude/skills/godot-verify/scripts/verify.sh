#!/usr/bin/env bash
# Beyond The Neon Void: one-shot verification gate (bash / Git Bash / WSL / Linux box).
#   verify.sh [repo] [--godot PATH] [--quick] [--only data|compile|tests|replay]
#             [--missions a,b] [--seeds N] [--rosters default|suite] [--baseline FILE] [--keep-going]
# Gates: preflight -> import -> data (validate_data.py) -> compile (tests/compile_all.gd + script-error scan)
#        -> tests (tests/run_tests.gd, known art failures allowed) -> replay (seeded determinism + win rates).
# Writes logs ONLY to ${TMPDIR:-/tmp}/btnv-verify/, never into the repo.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="."; GODOT="${GODOT:-}"; QUICK=0; ONLY=""; MISSIONS=""; SEEDS=2; ROSTERS=default; BASELINE="$HERE/known_failures.txt"; KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --godot) GODOT="$2"; shift 2;;
    --quick) QUICK=1; shift;;
    --only) ONLY="$2"; shift 2;;
    --missions) MISSIONS="$2"; shift 2;;
    --seeds) SEEDS="$2"; shift 2;;
    --rosters) ROSTERS="$2"; shift 2;;
    --baseline) BASELINE="$2"; shift 2;;
    --keep-going) KEEP=1; shift;;
    -h|--help) sed -n 2,7p "$0"; exit 0;;
    *) REPO="$1"; shift;;
  esac
done
REPO="$(cd "$REPO" && pwd)"
LOG="${TMPDIR:-/tmp}/btnv-verify"; mkdir -p "$LOG"
[ -f "$REPO/project.godot" ] || { echo "no project.godot in $REPO"; exit 2; }
if [ -z "$GODOT" ]; then
  for c in godot4 godot Godot_v4.7.2-stable_linux.x86_64 Godot_v4.7.2-stable_win64_console.exe; do
    command -v "$c" >/dev/null 2>&1 && { GODOT="$(command -v "$c")"; break; }
  done
fi
[ -n "$GODOT" ] && [ -x "$GODOT" ] || { echo "Godot 4.7 not found: pass --godot PATH or set GODOT"; exit 2; }
PY="$(command -v python3 || command -v python)"
declare -A RESULT; FAILED=0
run_gate() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }
mark() { RESULT[$1]="$2"; [ "$2" = PASS ] || [ "$2" = SKIP ] || [ "$2" = WARN ] || { FAILED=1; [ $KEEP = 1 ] || summary_and_exit; }; }
summary_and_exit() {
  echo; echo "== BTNV verify summary ($(date '+%H:%M')) =="
  for g in preflight import data compile tests replay; do printf '  %-9s %s\n' "$g" "${RESULT[$g]:-not run}"; done
  echo "  logs: $LOG"
  exit $FAILED
}

# 1. preflight
VER="$("$GODOT" --version 2>/dev/null | head -1)"
echo "Godot: $VER"
pf=PASS
case "$VER" in 4.7*) ;; *) echo "WARN: project targets Godot 4.7 (got $VER)"; pf=WARN;; esac
if [ -d "$REPO/legacy/original_gd" ] && [ ! -f "$REPO/legacy/original_gd/.gdignore" ] && [ ! -f "$REPO/legacy/.gdignore" ]; then  # either level hides it
  echo "FAIL: legacy/original_gd has no .gdignore: Godot parses the old scripts and autoloads break."
  echo "      Fix (with Brian's OK): create an empty file legacy/original_gd/.gdignore"
  pf=FAIL
fi
mark preflight $pf

# 2. import (builds .godot/ class cache; needed on a fresh clone)
if [ ! -d "$REPO/.godot" ] || [ $QUICK = 0 ]; then
  timeout 900 "$GODOT" --headless --path "$REPO" --import >"$LOG/import.log" 2>&1
  [ $? = 0 ] && mark import PASS || mark import FAIL
else mark import SKIP; fi

# 3. data
if run_gate data; then
  "$PY" "$HERE/validate_data.py" "$REPO" | tee "$LOG/data.log" | tail -8
  [ "${PIPESTATUS[0]}" = 0 ] && mark data PASS || mark data FAIL
fi

# 4. compile
if run_gate compile; then
  timeout 600 "$GODOT" --headless --path "$REPO" -s res://tests/compile_all.gd >"$LOG/compile.log" 2>&1; rc=$?
  grep -E "compile_all:|FAILED:|CANNOT INSTANTIATE" "$LOG/compile.log"
  errs=$(grep -cE "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script" "$LOG/compile.log")
  [ "$errs" -gt 0 ] && grep -E -A2 "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script" "$LOG/compile.log" | head -40
  [ $rc = 0 ] && [ "$errs" = 0 ] && mark compile PASS || mark compile FAIL
fi

# 5. tests
if run_gate tests && [ $QUICK = 0 ]; then
  timeout 1800 "$GODOT" --headless --path "$REPO" -s res://tests/run_tests.gd >"$LOG/tests.log" 2>&1
  grep -E "^=== |AI-vs-AI" "$LOG/tests.log"
  new=0; known=0
  while IFS= read -r line; do
    if grep -v '^#' "$BASELINE" | grep -v '^$' | while IFS= read -r pat; do echo "$line" | grep -qE "$pat" && echo hit; done | grep -q hit; then
      known=$((known+1)); else new=$((new+1)); echo "NEW $line" | cut -c1-220; fi
  done < <(grep -E "^FAIL" "$LOG/tests.log")
  serr=$(grep -c "SCRIPT ERROR" "$LOG/tests.log")
  echo "tests: $new new failure(s), $known known art/fixture failure(s), $serr SCRIPT ERROR line(s)"
  [ $new = 0 ] && mark tests PASS || mark tests FAIL
elif run_gate tests; then mark tests SKIP; fi

# 6. seeded replay
if run_gate replay && [ $QUICK = 0 ]; then
  args=("--seeds=$SEEDS" "--rosters=$ROSTERS" "--json=$LOG/replay.json"); [ -n "$MISSIONS" ] && args+=("--missions=$MISSIONS")
  timeout 1800 "$GODOT" --headless --path "$REPO" -s "$HERE/gd/replay_check.gd" -- "${args[@]}" >"$LOG/replay.log" 2>&1
  grep -E "player side won|MISMATCH|TURN CAP|replay_check:|REPLAY|SKIP" "$LOG/replay.log"
  grep -q "REPLAY OK" "$LOG/replay.log" && mark replay PASS || mark replay FAIL
elif run_gate replay; then mark replay SKIP; fi
summary_and_exit
