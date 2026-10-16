# Angular VFX library: what exists, what to add

Brian's direction is rigid and angular (Blizzard/McFarlane): hard silhouettes, shards, slashes, rays, hex and glyph geometry, and white-hot cores with saturated rims. Soft smoke is used sparingly.

## Already angular in the engine (use these first)
- `flash` with `rays`/`ray_len`/`ray_width`/`ray_spin`: star bursts. 2–4 rays read as a slash glint.
- `streaks`: speed lines and slash debris.
- `ring` with `dashes`/`dash_fill`/`rotate`/`thin`: tech rings and targeting reticles.
- `scan`: wireframe box sweep.
- `tear`: a dimensional rip with jagged edges.
- `lightning`: jagged arcs, branches and chains.
- `sim` with `render: "poly"` (spinning polygon debris), `"line"` (velocity-stretched sparks), `"trail"`, and `tex: "shard"|"streak"|"beam"|"chip"|"glyph"`.
- `pillar`: a vertical beam (summons, heals, strikes from above).
- Screen: `shockwave` (refraction ring with `chroma` split) and `glitch` (sliced RGB tears).

Taste tally in the snapshot (`vfx_lint.py --coverage`): 54 parts lean angular and 9 lean soft (`puff`/`soft`/`cloud`/`mist`). Sims without `tex` render the default soft `core` sprite, so check `render`/`tex` when you go for rigid.

## Missing primitives (each needs code, so propose before building)
1. **`slash` part (VFXShape type):** a crescent arc swept over `life`, with a hard leading edge, a tapered tail and an optional double arc. Keys (proposed): `radius`, `arc_deg`, `thickness`, `dir`, `sweep_time`, `colors [edge, body, tail]`, `squash` (iso). It's the biggest gap for melee (49 physical abilities). Implement it in `vfx_shape.gd` `_draw` with `draw_colored_polygon`, the same way the existing shapes are drawn.
2. **`flipbook` part:** plays a Lattice `kind:"fx"` clip (`LatticeClip` loader: strip, cells, fps/holds) as a VFX part with `delay`/`life`/`anchor`/`blend`/`glow`. This lets hand-made pixel FX (Brian's Lattice tool) slot into effects. Needs `LatticeClip` frame extraction into a `SpriteFrames` or a manual `draw_texture_rect_region`. Check `lattice_clip.gd` `unit_set` for reuse.
3. **`shard_ring` (or ring `shards: n`):** an expanding ring of triangles instead of a stroked circle. Impact tier marker.
4. **`hex` overlay for the ground:** a hex-cell decal for shields, tech zones and anchor auras. Could be a `decal` variant using the shield shader recipe from `godot-shader-forge`.
5. **Charge telegraph node:** the ground marker for pending casts (see `choreography.md`). Not a VFX part; a BattleMap overlay.

## Per-element signature (proposal to fill with Brian)
| Element | Shape language | Palette anchor | Residue |
|---|---|---|---|
| plasma | fat hot cores, poly debris, short rays | magenta/amber, core ×2.2 | scorch decal, embers |
| electric | lightning, `glitch`, jagged rings | cyan/white | static crackle sims (`fade: strobe`) |
| cryo | shards, hex frost, `stretch` lines | ice blue/white | frost decal, slow glints |
| void | `tear`, inward `radial: -1`, dark shockwave (`dark`) | violet/black | lingering rift motes |
| essence | `stream` motes, curves (`path: curve`) | crimson/violet | soul wisps upward |
| tech | `scan`, dashed rings, `glyph`/`chip` textures | green/cyan | data motes |
| kinetic | shockwave, poly debris, dust | white/steel | dust ring |
| physical | **slash arcs (missing)**, streaks, sparks | amber/white | sparks |

**ASK BRIAN:** confirm the shape language per element, and whether the Lattice tool should produce FX flipbooks (which decides between priority 1 and 2).
