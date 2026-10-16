# Wiring an effect into battle (no code)

1. Draft the effect JSON from `effect_impact.template.json` / `effect_cast.template.json`. Rename the id to `<element>_<what>` (e.g. `cryo_lance_impact`) and pull colours from the element row in `references/angular-library.md`.
2. Look at it **before** touching vfx.json:
   `& $env:GODOT --path . -s "$PWD/.claude/skills/godot-vfx-forge/scripts/gd/vfx_shot.gd" -- --def="$env:TEMP\fx.json" --times=0.03,0.08,0.15,0.4 --out="$env:TEMP\fx.png"`
3. Insert it in house style, optionally mapping it in the same step:
   - one ability: `python .claude\skills\godot-vfx-forge\scripts\vfx_upsert.py . $env:TEMP\fx.json --map=abilities:<ability_id>`
   - an anticipation for a whole element: `--map=types:<element>:cast`
   - the big tier for an element: `--map=types:<element>:big`
   - a special: `--map=specials:<special>`
   - Use `--dry-run` first to see the diff.
   - Alternative per ability: set `"vfx_id": "<effect>"` in `data/abilities.json` (it wins over every table, but makes the impact fixed: no aoe/big escalation).
4. `python .claude\skills\godot-vfx-forge\scripts\vfx_lint.py . --coverage`: 0 errors, and coverage moves the way you meant.
5. In context: `vfx_shot.gd -- --ability=<ability_id>` renders cast/travel/impact exactly as `plan_for_ability` resolves them.
6. `godot-verify -Quick`. The suite has VFX tests (`test_vfx_library`, `test_vfx_and_tiles` in `tests/test_suite.gd`); `tests/vfx_showcase.gd` makes a docs board if Brian wants one.
