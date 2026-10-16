# Ambient particles and weather (`ParticleFactory`, `data/particles.json`)

- **15 presets:** rain, neon_rain, storm_clouds, fog, ground_mist, snow, ash, embers, sparks, dust, smoke, steam_vent, toxic_spores, data_motes, fireflies.
- **Keys:** `name, kind, color, color2, amount, lifetime, speed, spread, size, gravity, fall_from, glow, texture, texture_kind, direction [x,y], alpha, align, blend, fade, splash, wind [x,y], depth, stretch, droplets`, plus `turbulence` (enables GPU).
- **Build:**
  - `ParticleFactory.make(preset_id, region_px, cells, tile_w)` / `make_for_cells(preset_id, diamonds)` → Node2D.
  - CPUParticles2D by default. `use_gpu(p)` is true only if `turbulence > 0`, the display isn't headless, and the renderer is `forward_plus` or `mobile`. `force_cpu` overrides.
  - Fog is a special `FogSheet` (noise-masked blobs, inline shader with the double-colour bug #34).
- **Authoring:** painted per cell and layer in the World Painter (`world.particles`), with a `preview_icon(preset_id)`. Splash and droplet emitters exist for rain.
- **Budget:** each painted region is an emitter, so keep `amount` per region modest and prefer one large region to many small ones. GPU particles only help with turbulence. CPU is the safe path on `gl_compatibility`.
- **Preview:** `tests/particle_preview.gd` (needs a display). See `godot-verify` for the screenshot recipe.
- **Rule:** weather never changes rules. Hazards are terrain/hazard data (`tactics-combat-core`). If a weather preset implies a mechanic (toxic spores → poison), that's a design request for `mission-architect`/`tactics-combat-core`, not a particle change.
