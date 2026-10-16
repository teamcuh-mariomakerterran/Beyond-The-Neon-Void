# Shader inventory (box snapshot, Godot 4.7.2)

There are 12 shaders: 3 `.gdshader` files and 9 inline GDScript string constants. All of them compile on `gl_compatibility` (box, Mesa llvmpipe) via `scripts/shader_check.py --compat`. Forward+ couldn't be checked on the box (no Vulkan), so run `shader_check.py` without `--compat` on Brian's PC. `shader_lint.py` reports 4 errors (all the same bug, below), 2 warnings and 7 infos.

| # | Shader | Where | Kind | Driven by | Key uniforms | Notes |
|---|---|---|---|---|---|---|
| 1 | Status look | `src/vfx/status_look.gdshader` (117 lines) | unit body | `StatusLook` (`status_look.gd`) ← `data/status_looks.json` (33 looks, one per status, full coverage) | `grey crack tint tint_amt pulse_speed pulse_amt flicker heat glitch dissolve frost scan shimmer alpha_mul darken sink_px` | Coordinates are local px with feet at y=0. Applied to the unit node, and the sprite uses `use_parent_material`. Stacking: numbers take the max, the highest `priority` picks the tint, and `freeze` pauses the sprite. Changes tween over 0.4 s (0.7 s for sink). **Double-colour bug (lines 67, 70, 71), known-gaps #34.** |
| 2 | Signage screen | `src/vfx/screen.gdshader` (64) | world quad | `src/world/signage.gd` ← `data/signage.json` | `mode` (0 LED, 1 LCD, 2 CRT, 3 holo), `cells`, `brightness` (1.6, blooms), `seed`, `power` (boot-on), `tint` | Reuse it for any in-world display. Don't fork it. |
| 3 | Heartbeat | `src/vfx/heartbeat.gdshader` (16) | full-screen overlay | `Cues` (`cues.gd:16`, preload); low HP ≤ 25% | `intensity`, `bpm` 72, `color` | Ignores TEXTURE, so neutral parity doesn't apply. |
| 4 | HD-2D post | `src/vfx/hd2d_post.gd` `SHADER` | screen post (`CanvasLayer` layer 5) | `HD2DPost.for_map(world.post)`; presets `off, hd2d_warm, neon_noir, toxic_haze, dream, cinematic`; Forge World Painter picker | `dof focus_y focus_band falloff bloom threshold haze haze_color rays ray_color warmth tint contrast saturation lift vignette grain` | Maps: `neon_noir` on vault_breach_demo, neon_block_demo and neo_kowloon_hub; `hd2d_warm` on neon_expanse; none on gutter_alley/supply_works_dock (format 1). There's no master `intensity`, so reduce_motion can't scale grain/rays (lint info). |
| 5 | Shockwave | `src/vfx/vfx_screen.gd` `SHOCK_CODE` | screen-reading VFX part | `data/vfx.json` part `type:"shockwave"` | `progress thickness strength rim fade dark chroma` | `rim` is HDR on purpose. The lint warns about a missing `source_color`; mark it `// lint:ok` if kept raw. |
| 6 | Glitch | `vfx_screen.gd` `GLITCH_CODE` | screen-reading VFX part | `vfx.json` `type:"glitch"` | `slices amount split seed_t intensity tint bars` | Same `tint` lint note. |
| 7 | Battle backdrop | `src/grid/battle_map.gd` `_backdrop_material()` (`sh.code = """…"""`) | full-screen bg (`CanvasLayer` −10) | hard-coded | none | Black-violet sky, data-ring bands and scanlines. Colours are hard-coded, so a per-map backdrop needs uniforms (and a `backdrop` map key). |
| 8 | Fog sheet | `src/vfx/particle_factory.gd` `FogSheet.CODE` | particle preset `fog`/`ground_mist` | `data/particles.json` | `noise_tex drift density` | **Double-colour bug (line 949)**: fog alpha gets squared, so it reads thinner than tuned. Uses a FastNoiseLite seamless 256² texture (seed 11). |
| 9 | Cutscene layer | `src/cutscene/cutscene_layer_item.gd` `LAYER_SHADER` | cutscene layer | cutscene JSON (`render_mode %s` templated: blend) | `bright contrast sat hue tint tint_amt` | Its comment correctly notes that COLOR already includes the texture. |
| 10 | Cutscene distort | `cutscene_distort_item.gd` `DISTORT_SHADER` | screen-reading | cutscene JSON | `rect mode(0 shimmer,1 ripple,2 warp) amp freq speed band falloff t` | `filter_nearest` screen read, so it's pixel-exact. |
| 11 | Cutscene post | `cutscene_player.gd` `POST_SHADER` | stage post | cutscene JSON | `src size bg zoom shake bright contrast sat … bars` | |
| 12 | Cutscene transition | `cutscene_player.gd` `TRANSITION_SHADER` | stage transition | `TRANSITIONS` (13: cut, fade, crossfade, flash, wipeL/R/U/D, slideL/R/U, iris, dissolve) | `cur prev size kind p has_prev color` | |

## Render baseline (the canvas every shader lands on)
- `project.godot`: `rendering/viewport/hdr_2d=true`, `textures/canvas_textures/default_texture_filter=0` (nearest), `stretch mode=canvas_items, aspect=expand`, window override 1600×900, clear colour `(0.02,0.01,0.05)`. No renderer key is set, so Forward+ is the default on desktop.
- `BattleMap._setup_environment()`: `Environment.BG_CANVAS`, `glow_enabled`, `glow_intensity 0.9`, `glow_bloom 0.05`, `glow_hdr_threshold 1.0`, glow levels 1 = 1.0 and 3 = 0.6. **Anything above 1.0 blooms.** That's the neon mechanism, so colours carry HDR multipliers (`"#ff2e88*1.6"` in data, `* glow` in shaders).
- HD2DPost runs on layer 5 and reads the screen. HUD CanvasLayers must be ≥ 10 or they get blurred and graded too.
- **Glow exists only in battle.** `BattleMap` is the only place that creates a `WorldEnvironment` (grep `glow_enabled` finds nothing else), so `ExploreScene` and the Forge World Painter show HDR colours clipped, without bloom. The painter preview doesn't match the battle look (known-gaps #35). The fix is a shared `NeonEnv.make()` (or a scene) used by all three.

## Shader-adjacent systems (not shaders, but the same look)
- `VFX` (`src/vfx/vfx.gd`, `data/vfx.json`, 29 effects): shapes, sims, lights and trails. See `godot-vfx-forge`.
- `vfx_light.gd`: `PointLight2D` parts. Lattice `emitters.beacons/windows` cap at 5 lights per clip.
- `ParticleFactory`: 15 weather/ambient presets, CPUParticles by default.
- `Cues` (`data/cues.json`): `flash` ColorRect, heartbeat and screen effects. Gameplay names the moment and data defines the feel (see `game-feel-polish`).
- `SettingsFlags.reduce_motion` (`src/core/settings_flags.gd`): honoured by `CameraManager` and `Cues` (no shake/zoom/slowmo, flash at half alpha). Shaders don't read it yet.
