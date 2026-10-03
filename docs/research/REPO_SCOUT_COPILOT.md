# Repo scout: verifying Copilot's list against our game

_2026-10-03. Copilot proposed 46 Godot repos. Every one was checked: it exists, its licence was read from the repo itself, its last commit date was noted, and its shaders were classified 2D/3D by reading their `shader_type`. Each repo was then compared with what Beyond already has._

**Headline:** all 46 repos are real, and the list is good. But Copilot didn't know three things about us. The game is **2D canvas** (isometric sprites, not 3D). The UI, VFX, juice, World Painter and cutscenes are **already built and custom**. And a few repos have **no licence**, which legally means "look, don't copy". Filtered through those, about a dozen are worth our time.

Licence key: **MIT** = copy freely, keep the notice. **MPL-2.0** = copy the files; changes *to those files* stay open. **None** = ideas only, no code.

---

## Adopt: copy code in (MIT, 2D, fits a gap)

| Repo | What we take | Why it matters to Beyond |
|---|---|---|
| **zednaked/godot-canvas-shaders** (MIT, 9 shaders, 2026-09) | `led_panel`, `holographic`, `dissolve`, `shockwave`, `heat_distortion`, `chromatic_aberration` | Built for **GL Compatibility + 4.6/4.7**, the same renderer the game runs on. `led_panel` turns any texture into a street LED billboard, which suits a neon city. `holographic` is ready-made for Daemon Caller summons and hacked units. |
| **haowg/GODOT-VFX-LIBRARY** (MIT, 24 canvas shaders, shipped in *Land of Oblivion*) | Status shaders: **petrify, frozen, poison, burning, flash, dissolve** | Our 30 statuses have **no on-sprite look** today. Lattice also told us the game must **grey out petrify** and **sink banish** itself. These shaders drop onto `Unit` and get driven by status. |
| **youssof20/filtr** (MIT, 17 canvas shaders) | `glitch_lines`, `halftone`, `crt_warp`, `scanlines`, plus the **zone** idea | Our HD2DPost covers bloom, tilt-shift and grade. Filtr adds the cyberpunk extras. Its **FiltrZone** idea maps onto our **regions**: a "Security Cam" look inside the surveillance block, or the **lying-HUD warped zone** you approved. |
| **oxinosa/juicee** (MIT, 94 effects, 13 canvas shaders) | Preset vocabulary and the **ref-counted effect stack** | We have hit-flash, squash, damage arcs and banners. Missing: **low-HP heartbeat pulse**, **boss intro**, **victory**, and a guard so two effects fighting over the same property (zoom, time scale) never restore the wrong value. Copy the stack pattern; we already have the effects. |
| **Ark2000/PankuConsole** (MIT, 1.4k★) | Drop in as a **dev-only** addon | An in-game console that runs any GDScript expression, plus a live tweak panel. Tuning additions timing, VFX and AI while playing gets far faster. It disables itself in exported builds. |

## Study: steal the technique, write our own

| Repo | The idea | How it lands in Beyond |
|---|---|---|
| **saman-mb/crusade-rts** (MIT, isometric map engine + editor) | **Positional mega-tiles:** ground tiles are 32 diamond crops of one big seamless texture, cut at each cell's screen position, so the ground has **no visible repeat**. Also: a cliff-face renderer, shoreline transitions, golden-hour baked shadows, crash-safe atomic saves. | A World Painter "macro texture" fill for streets, sand and water, which kills the tiled-floor look in one feature. Atomic save (write temp, then rename) for our map saves. Their editor is close to ours, which confirms we're on the right track. |
| **vogitcode/Tactical-RPG** (no licence, ideas only) | **ReactionSystem:** checks for interrupts *every step of a move* (stop mid-path), plus hook-based passives. | **This is the big FFT gap. We have 195 abilities and zero Reaction / Support / Movement abilities.** FFT's identity is the 5-slot loadout (Action, Secondary, **Reaction**, **Support**, **Movement**): Counter, Auto-Potion, Move+1, Teleport. See "Legendary" below. |
| **LiGameAcademy/godot_ability_system** (MIT, Unreal GAS-style) | **Cue system** (gameplay logic emits cues, presentation listens), tags for immunity and exclusion, stacking strategies (refresh / stack / extend). | Our statuses need **stacking rules and immunity tags** (bosses immune to stop, droids immune to poison). The cue idea is already half there: our VFX are spawned from ability ids. |
| **AlexeyBond/godot-constraint-solving** (MIT, WFC) | Learns tile rules from an example region and fills a rectangle. | Already planned (EDITOR_IDEAS #12). This is the solver to adapt for "paint a sample street, fill the district". |
| **x3cca/Shader-Stacker** (MPL-2.0) | Sprite stacking: a column of slices rendered as a rotatable 2.5D object. | World-map **vehicles** (the half-submerged submarine, hover bikes) could turn smoothly in any direction from a single slice sheet, with no 8-direction painting needed. |
| **butter-stella/stella** (MIT, cinematic engine) | Backlog with **voice replay**, a sequential voice queue, named stage layers. | Ideas for our cutscene player once the voice barks land. |
| **xlljc/DsInspector** (MIT) | Click any node in the running game to inspect and edit it live, plus frame-by-frame stepping. | Optional dev addon, alongside Panku. |

## Skip, and why

| Repo(s) | Reason |
|---|---|
| gtibo/VFX-sketchbook | **43 of 48 shaders are 3D**, and it has **no licence**. Nice to look at, but we can't use or copy it. |
| AnnieIsthar hologram "AAA" | 3D only (`spatial`). zednaked's `holographic` does this for 2D. |
| Zorochase retro collection, AnalogFeelings PSX, MarcelloMorettoni mapgen, callmemhz map-builder | 3D (PSX vertex snapping, terrain meshes, TrenchBroom brush editing). Not our renderer. |
| 1hue/StorageBuffersCompute | Compute shaders; **won't run in Compatibility**. Our GPU particle path already exists. Revisit only for a "10,000-particle" set piece. |
| aroelke/godot-tbs-framework | **C#** (0 GDScript files). |
| nonunknown/godot-powerful, nezvers/Godot_goodies | Link lists (2 files each), not code. |
| EMChamp/fantasy-tactics, neohex sparkelite, DjinnFoundry map-cli, marinho visual-effects | No licence. The ideas are covered by better MIT picks above. |
| beehave, dialogue_manager, pandora, quest-system, gameplay-systems, comedot, FlowKit | Great projects, but **we already have** AI behaviours, dialogue, data (ContentDB + Forge), quests, stats/statuses and a component setup. Switching now would cost more than it gives. |
| terrain-autotiler | For Godot's TileMap. Our renderer draws its own stacks. |
| gdquest godot-shaders / VFX assets | Solid, but the 2D parts overlap our VFX library. The code is MIT and the art is CC-BY, so they're fine as reference. |
| script-ide, fennara AI, debug_draw_3d, Nothern131 plugins, simple-gui-transitions, VFEZ, saltmire, Ma-Ko-dev prototype | Editor quality-of-life you can install yourself (script-ide is nice), 3D, or already covered by our own systems. |

---

## Legendary features this surfaced (not repos, ideas)

1. **FFT loadout slots: Reaction / Support / Movement.** This is the most FFT thing we don't have. Examples of each:
   - **Reactions:** *Counter-Hack*, *Firewall* (null the first debuff), *Reroute* (dodge, then step 1 tile), *Overwatch* (shoot an enemy moving in range, using the per-step interrupt from Tactical-RPG).
   - **Supports:** *Overclock Cooling* (−1 AP on tech), *Concealed Carry* (dual wield).
   - **Movement:** *Jump+2*, *Grapple* (ignore height), *Phase Step* (teleport, chance-based like FFT's Teleport).
2. **Status looks:** every status gets an on-sprite shader (petrify grey + crack, frozen tint, poison pulse, burning flicker, glitch for short_circuit, dissolve for fading), plus the banish sink. Lattice is already timing their clips around this.
3. **District looks via regions:** a region carries a post-processing look that blends in as you walk through, such as Security Cam scanlines, glitch in corrupted zones, and the lying-HUD zone.
4. **No-repeat ground:** mega-tile macro textures in the World Painter.
5. **Living signage:** an LED billboard shader on sign objects, scrolling ads and propaganda. That fits with the propaganda/evidence system you approved.
