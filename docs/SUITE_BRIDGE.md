# Suite bridge: where the outside tools read and write

The contract between the game and Brian's outside suite (Chirp Lab, Beyond: SFX Lab, Lattice). Grok's suite hub uses it for its **Link project** button. Neon Forge (F1, in the game) edits the same files, so you can work in either place.

**Project root:** the folder holding `project.godot`, `data/` and `tools/chirp_studio/` (Brian's: `C:\godot and game projects\Beyond-The-Neon-Void`). Every path below is relative to it. The game reads `res://<path>`.

## Rules for every tool
- **Copy, never move.** Never write into the shared Black Doctrine asset folders. Copy from them.
- JSON in `data/` is indented with tabs and is UTF-8. Keep the keys you don't understand.
- Don't write `.import` files: Godot makes them.
- Names are lowercase with underscores. A numbered variant is `<name>_<n>.<ext>`.
- Audio can be `.ogg`, `.wav` or `.mp3`. The game finds any of them under the same base name.

## Chirp Lab (voice): `tools/chirp_studio/`
| What | Where |
|---|---|
| The app | `tools/chirp_studio/black_doctrine_chirp_studio.html` |
| Battle barks | `assets/voice/barks/<who>_<event>_<n>.ogg`. Lines live in `data/barks.json` or a character's `barks` field in `data/characters.json` |
| Dialog lines | `assets/voice/dialog/<npc>_<node>.ogg`. Lines live in each NPC's `dialog` in `data/npcs.json` (Neon Forge ▸ DIALOG GRAPH) |
| Voice profile per character | `voice_personality`, `voice_sex`, `voice_id` on entries in `data/characters.json` and `data/npcs.json` |
| Export manifest | `tools/chirp_studio/manifest.json` |

**Loop:**
1. `py -3 tools/chirp_studio/chirp_bridge.py sync` puts the game's current classes, cast, barks and dialog into the app.
2. Record the lines and bind the app's save folder to the project root, then use **Write**.
3. `py -3 tools/chirp_studio/chirp_bridge.py import` pushes voice picks and edited lines back into the game. Add `--audio-root <folder>` for an extracted ZIP, or `--dry-run` to preview.

The personality library's own recordings, which aren't tied to a character, go to `audio/barks/…` (the app's original layout). The game doesn't play those yet.

## Beyond: SFX Lab (sound): `assets/sfx/`
| What | Where |
|---|---|
| Sound files | `assets/sfx/<family>_<n>.wav\|ogg`. The game picks a random variant from each family, and saving over a file replaces it |
| Which sound plays for a game event | `data/sfx_events.json` |
| Battle moments (hit, crit, death…) | `data/cues.json` |
| Toasts (sound + animated icon per toast) | `data/toasts.json` |
| UI sounds | `data/sfx_events.json`. Only `ui_tone` and `ui_error` are mapped today; hover, confirm, cancel, menu move, save loaded and no save found come with the menu sandbox |
| Music | `assets/music/`. Track aliases (title, world map, battle, boss…) are in `data/music.json` |

## Lattice (animation, FX, interface)
| What | Where |
|---|---|
| Characters and units (Lattice clips) | `assets/units/<name>/`, which a character's `sprite_frames_path` points at |
| Ability FX flipbooks | `assets/vfx/<name>/`, used through `data/vfx.json` parts of type `"clip"` |
| Ambient particles and weather | `data/particles.json` |
| Structures and props | `assets/structures/`, `assets/props/` |
| Backgrounds and parallax | `assets/backgrounds/` |
| Splash and title art | `assets/ui/title/` (planned) |
| Interface parts: 9-slice frames, meters, button states, cursors, icons, glyph sheet, numbers | `assets/ui/` (existing sets: `frames_doctrine`, `glyphs_doctrine`, `hud_doctrine`, `icons`) |
| Fonts | `assets/fonts/` (OFL licences next to them) |

**The interface theme is still in code** (`src/ui/neon_theme.gd`: colours, fonts, panel and button styles). The next game-side step is `data/ui_theme.json`. It will hold every value the game uses now: colours, fonts, 9-slice frame paths and margins, meter, button states, cursors, icon and glyph sheets, and number styles. NeonTheme will read it, Lattice's interface section will read and write it, and an in-game UI sandbox will preview it before it goes live. Until then the screens keep reading the code values, so nothing changes on screen.

## The hub's Link project button
1. Ask for the project root. Confirm it holds `project.godot` and `data/characters.json`.
2. Remember it. Each app then reads and writes the paths above.
3. After writing, run the game-side step for that app: `chirp_bridge.py import` for Chirp Lab. SFX Lab and Lattice files are picked up when Godot next imports.
