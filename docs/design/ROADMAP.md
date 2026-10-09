# Roadmap: Brian's calls (2026-10-02)

Decisions on `docs/research/EDITOR_IDEAS.md`, `docs/design/BIG_IDEAS.md` and the world-map research.

## Story / systems
- **Lying HUD:** **only in one warped zone**, not the whole game. It ties into the code-layer sight mechanic.
- **Propaganda:** works through NPCs. Find enough **evidence** and new dialogue unlocks, which gives a reason to go back to early areas. It can lead to new side quests and items.
- **Hangover morning:** yes.
- **Voice barks:** yes. Brian is recording voices for the other characters; lines get written when we reach that point.
- **Sync Blade:** BUILT (Stardust unlock, Additions).

## World map (see `docs/research/WORLD_MAP_FF8_FF9.md`)
- Huge map with an FF8/FF9 "go around the world" feel.
- **Vehicles:**
  - **submarine** (shown half out of the water, 8-direction sheet, 4 diagonals used)
  - **land** vehicle (later)
  - **air** vehicle (later)
- ✅ **Must come first:** a chunked renderer and chunk streaming. Built 2026-10-08: 32×32 chunks stream around the camera, with a lazy walk grid and big map files loading on first use.

## Editor: approved
- ✅ Scatter brush (built)
- ✅ Height sculpt brushes (raise / lower / flatten / smooth)
- ✅ Ramp + stairs tool (auto-uphill; any ground tile): slope a ground texture 2:1 up to the next elevation
- ✅ Mirror X / Y painting
- ✅ Procedural fill (terrain generator built; more modes later)
- ✅ Quick palette (recent and favourite tiles, number keys)
- ✅ Editor juice pack (built)
- ✅ Instant playtest round trip (return to the same camera, tool and selection)
- ⬜ Preview animated tiles, particles and lights at game speed while sculpting
- ✅ Painted lights and ambient (built)
- ✅ **Animated props and buildings at different timings:**
  - Grok is animating almost every building (window lights, chimney smoke) and doing an indoor-prop pass.
  - Every instance needs its own phase and speed so they don't pulse in sync. `random_start` exists; add a per-object phase/speed jitter.
  - The flickering computer consoles live in "animated items and props and busts".
- ✅ Per-tile variation: tint, flip, hue jitter
- ❌ **View rotation:** too much art to redraw. NOT doing.
- ✅ **Cutaway / x-ray** (almost a must, since there's no camera turn): fade or slice anything that hides the player or the cursor.
- ✅ Tactical overlay (built)
- ⬜ Typed entity fields and references
- ✅ Regions and triggers (enter / exit / interact → toast, dialog, cutscene, battle, flag, music, teleport; random encounters)
- ✅ Location graph view (world → hub → interior links as a node graph): ⛬ LINKS in the World Painter
- ✅ Asset-reference repair (⚕ LINKS in Assets; renames update every link) (fix links after renames or moves)

## Art pipeline
- Battle facings: **4 diagonals** (2 + mirror allowed per character). The other 4 facings are for cutscenes and menus.
- The first big asset dump is arriving in `assets/incoming/`. Claude sorts, renames and indexes it.

## Built 2026-10-03
- ✅ Overhead cable network (MST + density spans, sag, sway, live neon, hanging junk, anchor editing)
- ✅ Living signage (LED / LCD / CRT / hologram screens, shared feeds: news, propaganda, ads, stats, gossip, custom)
- ✅ Status looks (one data-driven unit shader; petrify stone, banish sink…)
- ✅ Cue system + juice (hit-stop, slow-mo, zoom punch, flashes, boss intro, low-HP heartbeat, override stack)
- ✅ FFT loadout: Reaction / Support / Movement passives + secondary job in the Crew tab
- ✅ Dev console
- ✅ PixelMatrix layered units + export sorter
- ✅ Lattice format guide adopted (holds = ticks, dirs-rows, unit packs, overlays)
- ⬜ Mega-tile ground (on hold, by request)

## Built 2026-10-07
- ✅ Tactical masks: directional cover, impassable / sight / door-group brushes, footprints → impassable
- ✅ Interaction anchors in battle + explore (terminals, switch sequences, traps, loot, doors, smoke devices, NPC hooks)
- ✅ Shielded / cloaked statuses; AI flanks walls
- ✅ NPC interaction stages (intro, gift, shop, quest, chain, fetch, fight, cutscene, repeat, closing)
- ✅ Vault Breach demo + Ma Rivet fetch quest on the Neon Block

## Built 2026-10-08 / 09
- ✅ Chunk streaming for big maps; campaign fixes (battles hand you back to the explore cell, saved explore position, shop stock saved, seeded RNG paths, enemy level growth)
- ✅ PixelLab units (zips drop in and play), test skirmish, Kade the test vendor
- ✅ **Voice barks:** crits, kills, ally down, low HP, big hits, misses, heals, battle start / victory, buzzed, shield down. Lines live in data/barks.json or on a character's Voice → barks field (with your recordings as voice_path).
- ✅ **Lying HUD**, in the one warped zone only (Relay District, `lying_hud`): forecasts skew up to 25% in the Doctrine's favour and some troops show as "Civilian". Clear Eyes chip, a relay terminal (anchor action `relay`) or killing the Doctrine Relay drops it with a glitch.
- ✅ **Propaganda through NPCs:** evidence (data/evidence.json) found in caches, drains and mission rewards; the hub case board; NPC evidence talks unlock new lines, items and quests (Otto, Benno, the Drunken Oracle); dialog nodes can need N pieces of evidence.

