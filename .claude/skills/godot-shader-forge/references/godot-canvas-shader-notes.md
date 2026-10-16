# Godot 4.7.2 canvas_item shader notes (verified on the box)

Everything marked ✅ was compiled or rendered on Godot 4.7.2 `gl_compatibility` (Mesa llvmpipe) with this skill's scripts. Re-check on Forward+ on Brian's PC with `shader_check.py` (no `--compat`). For version-sensitive questions beyond this list, use `godot-frontier` and cite the version.

| Fact | Status | Consequence for BTNV |
|---|---|---|
| Fragment `COLOR` already equals vertex colour × modulate × `TEXTURE` sample. `texture(TEXTURE, UV) * COLOR` squares it: 0.5 grey at 0.5 alpha composites to 0.06 instead of 0.25 | ✅ rendered (`neutral_parity.gd`) | Bug in status_look and FogSheet (known-gaps #34). For UV-shifted sampling, pass modulate through a varying from `vertex()` (`v_mod = COLOR;`). That's verified identical to no shader, including modulate. |
| `vertex()` `COLOR` includes the node's `modulate` | ✅ rendered | `v_mod` carries team tints and fades correctly. |
| `hint_screen_texture` + `filter_linear_mipmap` + `textureLod` gives a blurred screen read | ✅ compiled, rendered (HD2DPost lab shot) | Tilt-shift/bloom depend on the mipmap filter. `shader_lint` warns when it's missing. |
| `instance uniform` in `canvas_item` | ✅ compiles | Per-unit parameters without one material per unit become possible. Not used yet. Verify on Forward+ before adopting. |
| `#include "res://….gdshaderinc"` | ✅ compiles | Shared hash/noise/palette helpers can move into `src/vfx/shader_lib.gdshaderinc`. Inline string shaders can include it too. |
| `group_uniforms Name;` … `group_uniforms;` | ✅ compiles | Groups inspector knobs (useful for status_look's 16 uniforms). |
| `render_mode unshaded`, `blend_add`; `light()` function | ✅ compiles | Default canvas shaders are lit by `Light2D`/`PointLight2D` (`vfx_light.gd`, Lattice beacons). Use `unshaded` for emissive things (screens, sparks, outlines) so lights don't darken them. |
| `global uniform` without a matching Project Settings entry prints a WARNING, not an error ("global parameter … removed") | ✅ observed | `shader_check.py --strict` fails on it. Add globals in Project Settings › Shader Globals (e.g. a `btnv_beat` music pulse). |
| Headless (`--headless`, dummy renderer) never compiles shaders | ✅ observed | Shader checks need a display: `xvfb-run -a` on Linux CI, or a normal window on Windows. |
| Box has no Vulkan, so Forward+ falls back to OpenGL 3 | ✅ observed | Box screenshots are compat-renderer screenshots. Final look checks happen on Brian's PC. |
| `TIME` rolls over (Project Settings › Rendering › Limits › Time › Time Rollover Secs, default 3600) | docs | Long sessions get a visible jump in `TIME`-driven patterns at rollover. Use `fract`-friendly frequencies or a script-driven `t` uniform for cutscene-exact timing (cutscene_distort already uses `uniform float t`). |
| `SCREEN_TEXTURE`, `hint_color`, `hint_albedo` are Godot 3 names | docs | `shader_lint` flags them as errors. |

## Patterns that already work in BTNV
- **One Shader, many materials:** `static var _shader: Shader` per class (`VFXScreen`, `FogSheet`), or a `preload` of the `.gdshader` (`StatusLook.SHADER`, `Signage.SHADER`, `Cues.HEARTBEAT`).
- **Tweening uniforms:** `create_tween().tween_method(func(f): mat.set_shader_parameter(...), 0.0, 1.0, dur)`. See `StatusLook.update`.
- **Material on parent, sprite inherits:** `AnimatedSprite2D.use_parent_material = true`, so the unit's own `_draw()` placeholder and its sprite share one look.
- **Node-local pixel coords:** `varying vec2 local; void vertex(){ local = VERTEX; }`. Patterns don't swim when frames change.
