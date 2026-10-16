# Neon look guide: rules for BTNV shaders

Brian's direction (STATE_OF_THE_GAME §7/§11): **rigid, angular, "Blizzard/McFarlane" neon**, "insane" shaders, on 64×32 isometric pixel art with HD-2D post. These rules turn that taste into decisions. When a rule fights a specific look Brian asks for, Brian wins. Note the exception in the shader's header comment.

## 1. Light is HDR, not blur
- Bloom comes from values above 1.0 through the WorldEnvironment glow (threshold 1.0). Make an element glow by multiplying its colour (`edge_color.rgb * glow`, glow 1.5–2.5), never with a blur pass inside a sprite shader.
- Keep the **core** of a glow hot (white-ish, ×2–3) and the **body** saturated (×1.2–1.8). That gives the "neon tube" read: white core, coloured halo, as in `vfx.json` palettes `{main, alt, hot, core}`.
- Don't push large areas above 1.0. Full-screen bloom wipes out the read. Keep HDR to edges, cores, sparks and screens (signage `brightness` 1.6 is the reference for "lights the street").

## 2. Angular beats soft
- Prefer `step()` and hard thresholds to wide `smoothstep()` for shapes on bodies. Keep `smoothstep` for anti-aliasing at 1–2 px and for post.
- Prefer shards, triangles, hex cells, scan bands and stepped rows to round noise blobs. Use noise as a selector (which shard, which row), not as the visible shape. See `templates/recipes/shard_dissolve.gdshader` vs the status_look `dissolve`.
- Quantise space to art pixels: `floor(local)` or `floor(UV / TEXTURE_PIXEL_SIZE)`. Effects mustn't introduce sub-pixel detail finer than the art (unless it's post/HDR glow).
- Quantise time: `floor(TIME * fps) / fps` with fps 8–15 matches sprite animation. Continuous `TIME` is fine for slow ambient drift (fog, backdrop rings, god rays).

## 3. Palette discipline
- Use `NeonTheme` (`src/ui/neon_theme.gd`): BG `07040d`, MAGENTA `ff2e88`, VIOLET `b14dff`, CYAN `3fd2ff`, GREEN `39ff9f`, AMBER `ffd23f`, TEXT `e9e1ff`.
- Element language (from `vfx.json` types): plasma, electric, cryo, void, essence, tech, kinetic, physical. A status or ability shader uses its element's palette, so players learn colour = element. Pull colours from `vfx.json` palettes rather than inventing new hexes.
- Status tints already exist in `status_looks.json`. Extend that file instead of hard-coding.

## 4. Readability first (tactics game)
- At gameplay zoom a unit's **silhouette, team and facing** must survive every effect. Test at 1× with `shader_lab --scale=1` as well as zoomed in.
- Never let post (`HD2DPost`) blur the focus band where the active unit is. `set_focus(screen_y)` exists, so keep focus tracking on the active unit or cursor.
- Allies and foes must stay distinguishable under `glitch`, `shimmer` and `dissolve`. Don't let effects recolour the team ring drawn in `Unit._draw()`.
- A status must be recognisable in under half a second. If two statuses look alike, change the data (tint/channel), not the shader.

## 5. Data-driven, always
- Look values live in JSON (`status_looks.json`, `vfx.json`, `particles.json`, `signage.json`, map `post`). Shaders expose uniforms, and GDScript maps data to uniforms (`StatusLook._apply`, `HD2DPost._apply`, `VFX.parse_color`).
- One uniform per idea, defaulting to a no-op (0). That makes stacking, tweening and reduce_motion trivial.
- New channels in status looks follow `templates/status_look_param.md`.

## 6. Comfort and accessibility
- Every full-screen or flashing shader has an `intensity`/`strength` master. When `SettingsFlags.reduce_motion` is on, scale strobing, shake-like distortion, flicker and grain down to ≤ 50% (mirror `Cues._do_flash`, which halves flash alpha).
- Avoid full-screen flashes faster than 3 per second (common photosensitivity guidance). `flicker`/`glitch` on a single unit are fine.

## 7. Budget
- Sprite shaders run per covered pixel. A unit is small, but 20 units × 3×3 Voronoi (status_look `crack`) is still cheap. Full-screen passes are the expensive ones: HD2DPost already does about 4 `textureLod` taps per pixel. **Add at most one more full-screen pass per scene**, and prefer extending an existing pass (add a uniform to HD2DPost) over stacking a new CanvasLayer.
- Screen-reading shaders each force a screen copy. Group them (VFXScreen does) and keep them short-lived (shockwave/glitch tween out).
