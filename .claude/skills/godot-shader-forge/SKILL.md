---
name: godot-shader-forge
description: >-
  Use when writing, fixing or tuning shaders in Beyond The Neon Void (Godot
  4.7.2 canvas_item): status looks on units (status_look.gdshader +
  status_looks.json), HD-2D post presets per map, screen-reading effects
  (shockwave, glitch, distortion, cloak refraction), signage screens, outlines,
  shields, dissolves, holograms, HDR glow/bloom, the battle backdrop, fog, or
  cutscene shaders; also for "make it look insane/neon", shader compile errors,
  or a sprite that looks darker or washed out under a material. Particles and
  VFX choreography belong to godot-vfx-forge.
---

# Godot Shader Forge

BTNV's look is HDR neon on nearest-filtered isometric pixel art. Values above
1.0 bloom through the battle `WorldEnvironment`, an HD-2D post stack sits on
top, and one data-driven shader paints every status on a unit's body. Brian
wants **rigid, angular, "Blizzard/McFarlane"** neon and shaders that look insane.
This skill makes new shaders fit that look, stay data-driven and readable, and
**prove they compile and render** before anyone calls them done.

Load as needed:
- `references/shader-inventory.md`: all 12 shaders (3 files + 9 inline), uniforms, who drives them, the render baseline, known bugs
- `references/neon-look-guide.md`: HDR-not-blur, angular-over-soft, palette, readability, data-driven, comfort, budget
- `references/godot-canvas-shader-notes.md`: canvas_item facts **verified on 4.7.2** (COLOR semantics, screen mipmaps, instance uniforms, includes, globals, headless caveat)
- `references/recipes_preview.png`: what the recipes look like (box render)
- `scripts/shader_lint.py`: static lint, no Godot needed. Finds the double-colour bug, Godot 3 names, missing mipmap filters, colour hints, sin-hash and reduce-motion knobs
- `scripts/shader_check.py` (+ `gd/shader_check.gd`/`_body.gd`): compiles **every** shader, inline ones included, on a real renderer; reports errors per shader
- `scripts/gd/shader_lab.gd` (+ body): renders one shader with chosen uniforms (or `--status=burning,shocked` using the real `StatusLook.combine`) to a PNG strip you can look at
- `scripts/gd/neutral_parity.gd`: proves a body shader at default uniforms leaves the art unchanged
- `templates/unit_overlay.gdshader`, `templates/screen_post.gdshader`: starting points with BTNV conventions baked in
- `templates/recipes/`: `neon_outline`, `energy_shield` (for `shielded`), `cloak_refract` (for `cloaked`/`hidden`), `holo_scan`, `shard_dissolve` (angular death/teleport). All compile and render on the box.
- `templates/status_look_color_fix.diff`: verified fix for known-gaps #34 (applies cleanly to the snapshot)
- `templates/status_look_param.md`: checklist for adding a StatusLook channel
- `templates/inline_shader_const.gd.txt`: the inline-shader pattern (static Shader cache, data → uniforms with `VFX.parse_color`)

Related: `godot-vfx-forge` (vfx.json parts, particles, choreography), `game-feel-polish` (Cues timing, juice, reduce_motion), `tactics-combat-core/references/statuses.md` (what each status means), `godot-verify` (gate), `godot-frontier` (newer Godot features), and the shared `design-juice` skill (UI and deck visuals only, not in-game shaders).

## When to run
- Requests like: "new status look", "make burning look better", "shield effect on the boss", "cloak shimmer", "post for this map", "bloom too strong", "neon outline on the selected unit", "screen shake ripple", "hologram briefing", "shader error", "my sprite looks darker after poison wore off".
- Any change to a `.gdshader`, an inline `"""…shader_type…"""` constant, `status_looks.json`, `HD2DPost.PRESETS`, a map's `post`, or `BattleMap._setup_environment`.

## Ground truth (box snapshot)
- **Render setup:**
  - `hdr_2d=true` and nearest filter. No renderer key, so Forward+ on desktop.
  - Battle glow: `BG_CANVAS`, intensity 0.9, bloom 0.05, `glow_hdr_threshold 1.0`, levels 1 (1.0) and 3 (0.6).
  - **Only `BattleMap` has glow.** Explore and World Painter don't (#35).
- **Shaders:** 12 total, all compiling on `gl_compatibility`:
  - files: `status_look`, `screen`, `heartbeat`
  - inline: `hd2d_post.gd:SHADER`, `vfx_screen.gd:SHOCK_CODE/GLITCH_CODE`, `battle_map.gd` backdrop, `particle_factory.gd` FogSheet, and four in `src/cutscene/` (layer, distort, post, transition)
- **Convention:** shaders often live as GDScript string constants. Both checkers find them.
- **StatusLook:**
  - 33 looks, one per status (full coverage).
  - Stacking: max of numbers, highest `priority` tints, `freeze` pauses the sprite.
  - Tweens 0.4 s (0.7 s for sink). Lattice clip states (e.g. `petrified_SE`) override the sprite.
  - `Unit` assigns the material at the first status and **never removes it**.
- **Bug (#34):** `status_look.gdshader:67,70,71` and `particle_factory.gd:949` multiply `texture(TEXTURE)` by `COLOR`, which already contains it.
  - Measured: a unit's mid-tones and soft alpha are squared from its first status for the rest of the battle (0.25 → 0.06 on a 50% grey/50% alpha test pixel), and fog alpha is squared.
  - The fix is in `templates/status_look_color_fix.diff` (verified identical to no shader, modulate included).
  - **ASK BRIAN** before applying it: art and fog may have been tuned under the bug, so after the fix fog will look denser and status'd units brighter.
- **Lint baseline:** `shader_lint.py` on the snapshot gives 4 errors (#34), 2 warnings (HDR `rim`/`tint` without `source_color`, probably intentional) and 7 infos.
- **HD2DPost:**
  - Presets: `off, hd2d_warm, neon_noir, toxic_haze, dream, cinematic`.
  - Maps: `neon_noir` on vault_breach_demo, neon_block_demo and neo_kowloon_hub; `hd2d_warm` on neon_expanse.
  - Layer 5, so HUD layers must be ≥ 10. There's no `intensity` master.
- **Box limits:** no Vulkan, so Forward+ can't be checked here. Compat renders work under `xvfb-run`.

## Hard rules
1. **Never `texture(TEXTURE, uv) * COLOR` in a canvas_item fragment.** `COLOR` already includes the texture. Use `COLOR` alone, or pass modulate from `vertex()` (`varying vec4 v_mod; … v_mod = COLOR;`) when you resample at shifted UVs. `shader_lint` treats this as an error.
2. **Neutral is a no-op.** Every effect uniform defaults to 0 (or 1 for multipliers) and leaves the art pixel-identical. Prove it with `neutral_parity.gd` for body shaders.
3. **Glow through HDR, not blur.** Multiply colours above 1.0 (`* glow`) on edges, cores and screens only. No blur loops in sprite shaders. Large areas stay ≤ 1.0.
4. **Angular by default.** Use hard `step` edges, shards/hex/rows, stepped time (`floor(TIME*fps)/fps`, 8–15 fps) and art-pixel quantisation (`floor(local)`). Soft noise is a selector, not the visible shape. Write any exception into the shader header.
5. **Data drives looks.** Values live in JSON (`status_looks.json`, `vfx.json`, `particles.json`, `signage.json`, map `post`). Parse colours with `VFX.parse_color` (it keeps `#hex*k` HDR and `$palette`). No hard-coded look values in gameplay code.
6. **One Shader per class, many materials.** Use `preload` for files and a `static var _shader` for inline code. Never `Shader.new()` per instance or per frame.
7. **Readability over spectacle.** Silhouette, team ring and facing must survive every look at 1× zoom. HUD stays above post (layer ≥ 10). Post focus follows the active unit (`HD2DPost.set_focus`).
8. **Comfort.** Every full-screen or flashing shader has an `intensity`/`strength` master that `SettingsFlags.reduce_motion` can scale (≤ 50%), mirroring `Cues._do_flash`. No full-screen strobe faster than 3 Hz.
9. **Budget.** At most one new full-screen pass per scene; prefer adding uniforms to HD2DPost. Screen-reading effects are short-lived and grouped (the VFXScreen pattern).
10. **Prove it.** Lint clean (no new errors), `shader_check` clean on **both** renderers (box `--compat`, Brian's PC Forward+), and a `shader_lab` PNG looked at before you say it looks good. Never claim a visual result you didn't render.
11. **File vs inline.** Use a `.gdshader` when it's shared, larger than about 60 lines, or tuned by hand. Keep it inline when it's private to one class or templated (`render_mode %s`). Don't mass-migrate inline shaders without Brian's OK.

## Workflow: new status look (or improve one)
1. Read the status meaning (`tactics-combat-core/references/statuses.md`) and its current entry in `data/status_looks.json`.
2. If existing channels can express it, change only JSON. Otherwise add a channel following `templates/status_look_param.md`.
3. Render it: `& $env:GODOT --path . --rendering-method gl_compatibility -s "$PWD/.claude/skills/godot-shader-forge/scripts/gd/shader_lab.gd" -- --shader=res://src/vfx/status_look.gdshader --status=<id> --frames=4 --out="$env:TEMP/look.png"`, then open the PNG. Also render it stacked with a common partner (e.g. `burning,poisoned`) to check priority and tint.
4. Run `shader_lint.py`, `shader_check.py` and `neutral_parity.gd`.

## Workflow: new shader effect (shield, cloak, outline, dissolve…)
1. Start from a recipe or template. Rename the uniforms; keep the conventions.
2. Decide where it lives:
   - a unit child node (shield bubble, independent of the body)
   - the body (StatusLook channel)
   - a VFX part (godot-vfx-forge)
   - post (HD2DPost uniform)
3. Expose knobs and map them from data. Add an `intensity` master if it covers the screen.
4. Lab render (box: compat) → Brian checks it on Forward+ → lint/check → `godot-verify -Quick`.

## Workflow: per-map post look
1. Pick a preset in the World Painter (or the map JSON `post`: `"neon_noir"` or `{"preset":"neon_noir","bloom":0.6}`). Override keys match the HD2DPost uniforms.
2. A new preset goes into `HD2DPost.PRESETS` (the World Painter picker lists it automatically).
3. Check the HUD stays crisp (layer ≥ 10) and that the active unit sits in the focus band.
4. Remember that exploration has no glow (#35). Don't tune bloom in the painter and expect battle to match.

## Workflow: "sprite looks darker / fog too thin"
That's known-gaps #34. Show Brian a before/after (`shader_lab` with the original vs the patched shader, and `neutral_parity` output), **ASK BRIAN**, then apply `templates/status_look_color_fix.diff` and the same `v_mod`/`COLOR`-only fix to FogSheet. Re-tune fog `density` if he wants the old look.

## Commands (Windows, from the repo root)
```powershell
python .claude\skills\godot-shader-forge\scripts\shader_lint.py .
python .claude\skills\godot-shader-forge\scripts\shader_check.py .            # Forward+ (project default)
python .claude\skills\godot-shader-forge\scripts\shader_check.py . --compat   # also the compat path
& $env:GODOT --path . -s "$PWD/.claude/skills/godot-shader-forge/scripts/gd/neutral_parity.gd" -- --shader=res://src/vfx/status_look.gdshader
```
On Linux/CI, prefix the Godot calls with `xvfb-run -a` and add `--rendering-method gl_compatibility`. Headless never compiles shaders.

## Anti-patterns
- `vec4 c = texture(TEXTURE, UV) * COLOR;` (#34).
- Blur loops inside sprite shaders to fake glow; full-screen HDR > 1.0 washes.
- Smooth noise blobs as the visible effect on a rigid/angular game.
- Continuous `TIME` jitter on pixel art (swimming sub-pixel shimmer).
- Hard-coded colours in shaders that should come from `status_looks.json`/`vfx.json`, or `Color(str)` on data that contains `*1.6` (the HDR is lost).
- A new full-screen CanvasLayer for every effect.
- `Shader.new()` per unit, or `set_shader_parameter` every frame when a tween would do.
- Saying "looks great" without a rendered PNG, or testing only on compat.
- Shader logic that changes gameplay readability (hides team colour or facing) with no fallback.
- Editing `status_look.gdshader` channels without updating `StatusLook.NUMS` (the data key is silently ignored).

## Done checklist
- [ ] `shader_lint.py`: no new errors (paste the summary line)
- [ ] `shader_check.py --compat` clean (box) and `shader_check.py` clean on Forward+ (Brian's PC, or flagged as "not run")
- [ ] `shader_lab` PNG rendered and looked at; for statuses, also stacked with one partner
- [ ] Body shaders pass `neutral_parity.gd`
- [ ] Look values in JSON; colours parsed with `VFX.parse_color`; new StatusLook channels in `NUMS`
- [ ] Full-screen/flashing effects have an intensity master that respects `reduce_motion`
- [ ] HUD layer ≥ 10 above post; silhouette, team ring and facing readable at 1×
- [ ] `godot-verify -Quick` green
- [ ] known-gaps updated (#34/#35 closed if fixed); ASK-BRIAN items listed, not decided
