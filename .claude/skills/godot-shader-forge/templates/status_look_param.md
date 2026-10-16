# Checklist: add a new effect channel to StatusLook (e.g. `outline`, `shatter`, `static`)

1. **Shader:** add `uniform float <name> : hint_range(0.0, 1.0) = 0.0;` to `src/vfx/status_look.gdshader`, plus an `if (<name> > 0.0) { ... }` block in `fragment()`. Put it in a sensible order: colour work before `darken`, alpha work (`dissolve`, `shimmer`, sink) last. It must be a no-op at 0.
2. **Blend list:** append `"<name>"` to `StatusLook.NUMS` in `src/vfx/status_look.gd`. Numbers combine by **max** across stacked statuses. If the channel needs other blending (additive, priority-only), change `combine()` deliberately and document it in the `_note` of `data/status_looks.json`.
3. **Data:** use the key in `data/status_looks.json` entries (`"<name>": 0.6`). Keys are 0–1 unless noted in `_note`. Keep `priority` meaningful (it decides which tint wins).
4. **Lattice:** Lattice clip states (`<unit>_<FACING>_<status>`, e.g. `petrified_SE`) override the sprite. Decide whether the shader channel should still apply on top (it does today, through `use_parent_material`).
5. **Verify:**
   - `python .claude/skills/godot-shader-forge/scripts/shader_lint.py .`
   - `python .claude/skills/godot-shader-forge/scripts/shader_check.py .` (Forward+) and again with `--compat`
   - `shader_lab.gd -- --shader=res://src/vfx/status_look.gdshader --status=<id>` to see it
   - `neutral_parity.gd`, so a unit with no statuses still matches its art
   - the existing docs shot `tests/status_shot.gd` (needs a unit PNG) for the full grid
6. **Docs:** update the status row in `tactics-combat-core/references/statuses.md` if the look changes what a status communicates.
