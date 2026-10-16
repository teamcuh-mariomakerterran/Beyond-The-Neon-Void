# VFX schema (from `src/vfx/*.gd` docstrings and code; `data/vfx.json`)

`vfx.json` is **strict JSON**: `VFX.reload()` uses `JSON.parse_string`, so `//` comments break it. Forge/user overrides merge from `user://content/vfx.json` (top-level tables merge key by key). `VFX.reload()` re-reads both.

## Effect
```json
"effect_id": {
  "palette": {"main": "#ff2e88", "alt": "#b14dff", "hot": "#ffd23f*1.6", "core": "#ffffff*2.2"},
  "shake": [intensity, seconds], "shake_delay": s,
  "hit_stop": seconds, "hit_stop_delay": s,
  "impact_at": s,              // when the effect "lands"; default = max(trail delay+travel)
  "z": 4080,                   // absolute z_index (VFX.DEFAULT_Z)
  "parts": [ {...}, ... ]
}
```
- The effect frees itself when the last part ends, **capped at 12 s**.
- An unknown id spawns a small white flash and a warning, so callers never get null.
- **Spawn:** `VFX.spawn(parent, id, at_ground_point, params)`. `at` is the ground point: sparks bounce on y = at.y, and parts lift themselves with `pos`.
- **Spawn params:**
  - `to: Vector2` and `targets: Array[Vector2]` (parent space)
  - `scale`
  - `color` (replaces palette `main`) and `palette` (merges)
  - `seed` (the effect RNG; random if absent, since this is presentation)
  - `z` and `floor_z` (absolute z for decals; BattleMap passes `draw_order(cell)*2`)
  - `shake: bool` and `hit_stop: bool` (opt out)
  - `texture` (death_dissolve samples it)
- **Signals:**
  - `VFXEffect.impacted(at)` at `impact_at`, `finished`
  - `VFX.events.shake/hit_stop/screen_flash/effect_spawned`
  - shakes are forwarded to `EventBus.camera_shake`
  - hit-stop sets `Engine.time_scale` to 0.03 unless `VFX.hit_stop_enabled` is false or a handler sets `VFX.events.handled_hit_stop`
- **Scrubbing:** set `VFX.paused = true`, then `fx.advance_to(seconds)` or `fx.step(dt)`. Used by `tests/vfx_showcase.gd` and this skill's `vfx_shot.gd`.

## Colours
`"#rgb"`, `"#rrggbb"`, `"#rrggbbaa"`, with `"*k"` as an HDR multiplier (blooms above 1.0). Also `[r,g,b(,a)]` and `"$name"` / `"$name*k"` from the palette. Parse with `VFX.parse_color(v, palette)`. In the snapshot, 220 of 335 part colours are HDR.

## Common part keys (`VFXPart`)
`type`, `delay`, `life`, `pos [x,y]`, `anchor` (`at` | `to` | `mid` | `t0..tN` chain targets; parts anchored to a missing `tN` are skipped), `blend` (`add` default, `mix`; decals default to mix), `z` (relative), `glow` (colour multiplier).

## Part types (14)
| type | class | keys (beyond common) |
|---|---|---|
| `sim` | VFXSim (CPU, `_draw`, deterministic, steppable, **max 600 particles**) | Emission: `count`, `emit` (0 = burst, else seconds), `shape` point/circle/ring/box/line/disc, `radius`, `box`, `iso` (squash y, default true), `even`, `sweep`. Motion: `dir` (deg, −90 = up), `spread`, `radial` ±1, `speed [a,b]`, `gravity` (y or [x,y]), `drag`, `turbulence`, `swirl`, `attract`/`attract_to`/`attract_offset`, `kill_radius`, `floor`, `floor_jitter`, `floor_offset`, `floor_kill`, `bounce`, `friction`, `friction_ground`, `orbit {radius, speed, rise, grow}`, `path "curve"` (`path_from`, `path_to`, `path_offset`, `arc`, `wobble`), `lift`, `iso_vel`, `vy_scale`. Look: `plife [a,b]`, `size [a,b]`, `size_curve [..]`, `stretch`, `colors [..]` (over life), `palette [..]` (random per particle), `fade` out/in_out/flicker/late/none/strobe, `tex`, `render` sprite/line/poly/trail, `width`, `trail`, `spin [a,b]`, `align`, `aspect` |
| `burst` | VFXSim with GPU request | Same as sim. GPUParticles2D with turbulence on Forward+/Mobile with a display, otherwise the CPU fallback. **Unused in data today.** |
| `lightning` | VFXLightning | `to` (`"to"` / `"chain"` / [x,y]), `to_offset`, `jag`, `detail`, `branches`, `branch_len`, `refresh`, `widths [glow,mid,core]`, `colors [glow,mid,core]`, `hop_delay`, `flicker`, `end_glow`, `attack` |
| `flash` | VFXShape | `size`, `squash`, `colors`, `attack`, `rays`, `ray_len`, `ray_width`, `ray_spin` |
| `streaks` | VFXShape | `count`, `len [a,b]`, `width`, `colors`, `spread`, `dir`, `travel` |
| `ring` | VFXShape | `r0`, `r1`, `width`, `count`, `stagger`, `squash`, `colors`, `dashes`, `dash_fill`, `rotate`, `ease`, `thin`, `inner` |
| `pillar` | VFXShape | `width`, `height`, `colors [outer, core]`, `base` |
| `decal` | VFXShape | `radius`, `squash`, `color`, `ember`, `ember_time` (sits on the floor via `floor_z`) |
| `tear` | VFXShape | `size [w,h]`, `colors [edge1, edge2, inside]`, `open`, `close` |
| `scan` | VFXShape | `box [w,h]`, `colors [wire, scan]`, `sweeps` |
| `shockwave` | VFXScreen (screen-reading shader) | `radius`, `squash`, `thickness`, `strength`, `rim`, `dark`, `chroma`, `ease`, `attack`, `power`, `p0`, `reverse` |
| `glitch` | VFXScreen | `size [w,h]`, `slices`, `amount`, `split`, `tint`, `rate`, `bars` |
| `light` | VFXLight (PointLight2D pulse) | `color`, `energy`, `radius`, `attack`, `power`, `flicker`, `mode` |
| `trail` | VFXTrail (projectile head plus Line2D ribbon; emits `impacted`) | `travel`, `arc`, `wiggle`, `wiggle_freq`, `width`, `colors [tail..head]`, `head`, `head_colors`, `ribbon`, `fade`, `spin_ribbon`, `to`, `to_offset` |

Part usage in the 29 effects: sim 55, light 27, flash 26, ring 22, trail 5, shockwave 4, glitch 4, lightning 4, pillar 4, decal 3, streaks 2, tear 1, scan 1, burst 0. `vfx_lint.py` scrapes the accepted keys from the code at run time, so this table can drift without the linter going wrong.

## Procedural textures (`VFX.texture(kind)`)
- `core`, `shard`, `star`, `glyph`, `chip`, `beam`, `scorch`, `light`, `droplet`
- from ParticleFactory: `soft`, `streak`, `square`, `puff`, `ring`, `cloud`, `mist`
- anything unknown becomes `core`

There are no image textures; everything is generated. The angular ones are `shard`, `streak`, `beam`, `chip` and `glyph`, plus `render: "poly"/"line"/"trail"`.

## Ability → effect mapping (`VFX.plan_for_ability(ability, ranged)`)
Returns `{cast, travel, impact, mode, multi}`. Lookup order:
1. `ability.vfx_id` (if it's an effect)
2. `vfx.json abilities[id]` (8 rows)
3. `specials[special]` or the special's head before `.` (13 rows)
4. `kinds[HEAL|BUFF|DEBUFF|UTILITY]`, only when `damage_type` is physical or the kind is HEAL (4 rows)
5. `types[damage_type]` (8 elements: plasma, electric, cryo, void, essence, tech, kinetic, physical)

- **Escalation:** `big` (and `big_mode`) when `aoe_radius ≥ 2` **or** `charge_ticks ≥ 2`; otherwise `aoe` (and `aoe_mode`) when `aoe_radius ≥ 1`.
- **Modes:** `point` (impact at the cell; travel only if ranged), `arc` (spawned at the caster with `to`), `stream` (motes flow target → caster), `chain` (caster → each affected unit, nearest first, max 6), `multi` (impact on every affected occupant, max 6).
- **Fallbacks:** a missing impact becomes `impact_physical`, and missing cast/travel become `""`.
- **Coverage today** (`vfx_lint.py --coverage`): 43/195 abilities are bespoke, 64 use their kind's look, and 88 use the element table. 49 of those are `physical` (tracer + impact_physical), including `basic_attack` and `chrome_cleave`. Only `blink` defines a `cast`.
- `ability.sfx_id` exists but is unused (known gap; see `job-ability-system`).
