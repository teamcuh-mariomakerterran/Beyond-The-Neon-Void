# Playing builder cutscenes in the game

The game has a native Godot player for PARALLAX scenes: `src/cutscene/`. It is a line-by-line port of `cutscene-builder.html`'s renderer:
- `pv` keyframes with ease and bezier curves
- `warp` hit-stops
- `place` anchors, parallax, drift and bob
- groups, pivots and attach points
- tiling and motion blur
- anim frame logic
- text wrap and reveal, 9-slice panels, distort layers
- camera pan, zoom, shake and follow
- the grade stack: vignette, scanlines, grain, flash and letterbox
- all 13 transitions
- audio cues, events and branches

What you see in the builder is what plays in-game.

## Workflow
1. Author the scene in `cutscene-builder.html` as usual.
2. **Save project**, which gives you a `.parallax.json` with the art embedded.
3. Get it into the game, either way:
   - Drop the file onto the Neon Forge window and open the **CUTSCENES** section.
   - Or copy it into `data/cutscenes/`.
4. Hook it up in Neon Forge:
   - **Missions** → `intro_cutscene` / `outro_cutscene`: plays before or after the fight.
   - **Abilities** → `cutscene`: a close-up when the ability is used.
5. **▶ Preview in game** in the CUTSCENES section plays it over the editor.

The lighter **Export cutscene data** (`.cutscene.json`) also works. It carries no pixels, so put its art in `assets/cutscenes/` (or anywhere under `assets/`), matched by file name.

## Variables the game fills in

| Where it plays | Variables |
|---|---|
| Mission intro | `{PLACE}` (map name), `{MISSION}` |
| Mission outro | `{MISSION}` |
| Ability close-up | `{ATTACKER}`, `{TARGET}`, `{ABILITY}`, `{DAMAGE}`. Slot `ATTACKER` is bound to the caster's name, so name your units after characters to swap sheets per attacker. |

Shot `events` fire `EventBus.cutscene_event(name, data)`, so gameplay can react. Examples: shake the battle camera on `impact`, or swap a portrait.

## Parity check (optional)
The builder and the Godot player were compared frame by frame on `data/cutscenes/demo_supply_works.parallax.json`. After fixes, the mean pixel difference was 0.2–2.7 out of 255, and what remains is font glyph shapes: the builder uses the browser's monospace font, the game uses JetBrains Mono.

To re-run it:
- **Builder frames:** a Playwright script calls the builder's own `renderFrame()`.
- **Godot frames:**
  ```
  xvfb-run godot --path . --rendering-method gl_compatibility \
    -s res://tests/cutscene_frames.gd -- <file> <out_prefix> 0.5 2.0 4.2
  ```

## Known approximations
- **Blend modes:** `screen` is drawn as add, and `overlay`/`soft-light` as normal. Godot's canvas has no destination-reading blend modes.
- **Ignored:** per-layer `blur`, palette swaps, and `fx.chroma`. `chroma` was already invisible in the builder, because the opaque frame is drawn over the offset copies.
- **Inverted masks** (`maskInvert`) draw unmasked.
- **Bitmap fonts work.** System fonts map to JetBrains Mono (monospace) or Space Grotesk.
