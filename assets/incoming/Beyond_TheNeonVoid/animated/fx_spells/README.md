# fx_spells — Wave 12 spell pack (tech-magic, FFT-feel, Black Doctrine)

Sci-fi tech-magic for Black Doctrine (84x84 units, 64x32 iso tiles, NW/NE/SE/SW only) and the FFT-style Godot game. Everything is staged **cast -> travel -> impact**:

1. **Cast** on the caster tile: `spl_cast_circle_<elem>` (loop under the caster) + `spl_charge_<elem>` (one-shot; `emitters.releaseFrame` = when to launch) or `spl_channel_<elem>` (loop while held).
2. **Travel** (optional): `spl_plasma_bolt_<DIR>` / `spl_arc_beam_<DIR>`. Pin `spawn` (= `anchor`) on the caster's hand; `travelVector`, `rangePx`; `hits[0]` = arrival frame + point.
3. **Impact** on the target tile: the tier clips (`_t1`, `_t2`, `_t3_3x3`), support clips, or big spells. `hits[]` = frame(s) + point(s) where damage/heal lands.

Example chains: Plasma: `spl_charge_plasma` (caster) -> `spl_plasma_bolt_NE` -> `spl_plasma_t1` (target). Arcra: `spl_cast_circle_cyan` + `spl_charge_cyan` -> `spl_arc_t2`. Gravga: `spl_channel_void` -> `spl_void_t3_3x3` on the centre tile.

## Format (unchanged lattice.clip v1, no new fields)
- One clip file per effect (and per facing for projectiles): `<family>/<id>_clip.json` + `_strip.png` (horizontal strip, `rects`, `x=i*cell[0]`). Strips are hard alpha (0/255), normal blending.
- `anchor` = **ground point of the target tile** (bottom vertex of its 64x32 diamond) — for 3x3 spells the **centre** tile, for the limit break the centre of a 7x7. `groundPoint` = same. `config.tileCentre` = that tile's centre (16 px above the anchor); `config.footprintTiles` = `[1,1]`, `[3,3]` or `[7,7]`; `config.tier` = 1/2/3; `config.family`.
- `kind`: `fx` (one-shot effects), `ambient` (loops: cast circles, channel, barrier, stunned, auras). `loop` set accordingly. `frameMs = round(1000/fps)`, `holds: null`.
- `hits[{frame,x,y}]` (same field as fx_impacts burst) = when/where the hit lands; frame 0 is **not** the hit for these (they include a cast/build-up).
- Projectiles: `facing` (= travel direction), `dirOrder`, `dirIndex` (NE=1, SE=3, SW=5, NW=7), `spawn`, `travelVector` (screen space, y down), `rangePx` (108 = 3 tiles diagonal); plasma bolts also `emitters.projectilePath[{frame,x,y}]`.
- `endsOn`: `spl_barrier_raise` -> `spl_barrier_loop`, `spl_emp` -> `spl_stunned_loop`.
- `sortBias`/`depthKey`: effects `3/fx_over` (draw over units); cast circles `-5/ground_decal` (draw under the caster).
- Bolts, beams, rods and rockets enter from the sky at the top of the cell; the orbital beam and limit-break lances fade in (dithered) under a satellite-lens starflash, and arc strikes start under a small sky flash, so nothing is cut hard at the cell edge.
- Widest strip: `spl_limit_doctrine` 14400 px (under 15840; over 8192 — split if your target GPU caps at 8192).

## Style
Palette ramps (white-hot core -> darkest shade): cold cyan tech, plasma orange, toxic green, violet void, ice blue, arc blue-white, warning red, gold, mint. Selective outlining: every shape is outlined by **its own darkest shade**, never black; true black only inside the void singularity (real shadow). Brian's motifs: rocket smoke trails (plasma bolts, missile barrage, kinetic rod), flash + shock rings on every impact, radar ping arcs (scan, revive, limit break), the glitching skull, now Brian's own cyborg skull art (grey gunmetal, crosshair eyes, headphone pods) downscaled per clip (Doom 40-48 px, toxic t2 32 px, toxic t3 44 px, limit break 76 px), box-filtered then requantised to a 6-step gunmetal ramp with lone-pixel cleanup and a darkest-metal silhouette outline (no black). Crosshair eyes and cyan accents are redrawn per frame so they pulse and flicker; RGB split + slice shifts + scanline darkening glitches, scanline materialise in, ordered-dither dissolve out. Doom: cyan eyes turning red for the bite; toxic: green-tinted metal with cyan eyes (reads better against the green cloud than green eyes); limit break: eyes flare red.

## Clips

### Caster side (cast circles under the caster, charge-up, channel loops) (10)

| id | frames @fps | cell | grade | what |
|---|---|---|---|---|
| `spl_cast_circle_cyan` | 16 @10 loop | 96x64 | A- | Cast circle (hex/circuit runes) — cyan |
| `spl_cast_circle_plasma` | 16 @10 loop | 96x64 | A- | Cast circle (hex/circuit runes) — plasma |
| `spl_cast_circle_toxic` | 16 @10 loop | 96x64 | A- | Cast circle (hex/circuit runes) — toxic |
| `spl_cast_circle_void` | 16 @10 loop | 96x64 | A- | Cast circle (hex/circuit runes) — void |
| `spl_channel_cyan` | 12 @10 loop | 96x128 | B+ | Channel loop — cyan |
| `spl_channel_void` | 12 @10 loop | 96x128 | B+ | Channel loop — void |
| `spl_charge_cyan` | 16 @12 | 96x112 | A- | Charge-up — cyan |
| `spl_charge_plasma` | 16 @12 | 96x112 | A- | Charge-up — plasma |
| `spl_charge_toxic` | 16 @12 | 96x112 | A- | Charge-up — toxic |
| `spl_charge_void` | 16 @12 | 96x112 | A- | Charge-up — void |

### Plasma fire tiers (3)

| id | frames @fps | cell | grade | what |
|---|---|---|---|---|
| `spl_plasma_t1` | 14 @12 | 96x120 | B+ | Plasma (tier 1) — plasma bolt drops, flame burst on the tile |
| `spl_plasma_t2` | 18 @12 | 112x152 | A- | Plasmara (tier 2) — glyph ignites, plasma pillar erupts on the tile |
| `spl_plasma_t3_3x3` | 24 @12 | 224x200 | A- | Plasmaga (tier 3, 3x3) — target grid lights, plasma pillars erupt across 9 tiles, firestorm + shock |

### Cryo / ice-shard tiers (3)

| id | frames @fps | cell | grade | what |
|---|---|---|---|---|
| `spl_cryo_t1` | 14 @12 | 96x120 | B+ | Cryo (tier 1) — frost bloom, ice shards spike up and shatter |
| `spl_cryo_t2` | 18 @12 | 112x152 | A- | Cryora (tier 2) — cryo glyph, crystal cluster encases the tile, glint, shatters |
| `spl_cryo_t3_3x3` | 24 @12 | 224x200 | B+ | Cryoga (tier 3, 3x3) — frost sweeps the area, shard field erupts in waves, central spire, mass shatter |

### Arc lightning tiers (3)

| id | frames @fps | cell | grade | what |
|---|---|---|---|---|
| `spl_arc_t1` | 13 @12 | 96x120 | B+ | Arc (tier 1) — lightning strikes the tile (leader, double strike), ground arcs, sparks |
| `spl_arc_t2` | 17 @12 | 112x152 | A- | Arcra (tier 2) — three bolts converge into a crackling ball, which discharges into the tile |
| `spl_arc_t3_3x3` | 22 @12 | 224x200 | B+ | Arcga (tier 3, 3x3) — chain storm: strikes hop across all 9 tiles, then a mega bolt arcs out to every tile |

### Gravity well / void tiers (3)

| id | frames @fps | cell | grade | what |
|---|---|---|---|---|
| `spl_void_t1` | 14 @12 | 96x120 | B+ | Grav (tier 1) — singularity seed opens over the tile, crushes inward, implodes with a violet snap |
| `spl_void_t2` | 18 @12 | 112x152 | B+ | Gravra (tier 2) — gravity well: ground cracks, debris tears up and spirals in, crush pulse, outward blast |
| `spl_void_t3_3x3` | 24 @12 | 224x200 | B+ | Gravga (tier 3, 3x3) — event horizon: accretion disc over the area, debris from all 9 tiles, crush, violet nova |

### Toxic nanite cloud tiers (3)

| id | frames @fps | cell | grade | what |
|---|---|---|---|---|
| `spl_toxic_t1` | 16 @12 | 96x120 | B | Nanite (tier 1) — nanite swarm streams in, bursts into a toxic cloud that buzzes and thins |
| `spl_toxic_t2` | 20 @12 | 112x152 | A- | Nanitra (tier 2) — canister cracks, nanite cloud billows, a glitch skull flickers in the haze |
| `spl_toxic_t3_3x3` | 24 @12 | 224x200 | B+ | Nanitga (tier 3, 3x3) — nanite storm blankets 9 tiles: billowing cloud, swarm, giant glitch skull |

### Travel: plasma bolt + arc beam, 4 diagonals (separate files, no mirroring) (8)

| id | frames @fps | cell | grade | what |
|---|---|---|---|---|
| `spl_arc_beam_NE` | 12 @12 | 148x108 | B+ | Arc beam — lightning lance NE |
| `spl_arc_beam_NW` | 12 @12 | 148x108 | B+ | Arc beam — lightning lance NW |
| `spl_arc_beam_SE` | 12 @12 | 148x108 | B+ | Arc beam — lightning lance SE |
| `spl_arc_beam_SW` | 12 @12 | 148x108 | B+ | Arc beam — lightning lance SW |
| `spl_plasma_bolt_NE` | 12 @12 | 148x108 | B+ | Plasma bolt — travels NE |
| `spl_plasma_bolt_NW` | 12 @12 | 148x108 | B+ | Plasma bolt — travels NW |
| `spl_plasma_bolt_SE` | 12 @12 | 148x108 | B+ | Plasma bolt — travels SE |
| `spl_plasma_bolt_SW` | 12 @12 | 148x108 | B+ | Plasma bolt — travels SW |

### Support / status (16)

| id | frames @fps | cell | grade | what |
|---|---|---|---|---|
| `spl_barrier_loop` | 12 @10 loop | 96x128 | B+ | Energy barrier (loop) — dome holds, shimmer band sweeps, cells twinkle |
| `spl_barrier_raise` | 14 @12 | 96x128 | B+ | Energy barrier — hex-cell dome builds up from a ground ring, locks with a flash |
| `spl_buff_aura` | 12 @10 loop | 96x128 | B+ | Buff aura (loop) — warm gold ground ring, up-arrows climb the unit |
| `spl_cleanse` | 14 @12 | 96x128 | B+ | Cleanse — a white-cyan purge ring sweeps up the unit, dark ailment motes are torn out and dissolve into sparks |
| `spl_debuff_aura` | 12 @10 loop | 96x128 | B+ | Debuff aura (loop) — warning-red ground ring, down-arrows sink through the unit |
| `spl_doom` | 20 @12 | 96x150 | A- | Doom (curse) — the glitching blue skull materialises over the target, ticks a countdown, then bites down in a red flash |
| `spl_emp` | 14 @12 | 128x144 | B | Stun / EMP — EMP blast rings out with crackling arcs, static locks the unit |
| `spl_haste` | 14 @12 | 96x128 | B+ | Haste — speed chevrons climb, fast clock ring spins, motion streaks |
| `spl_nanoheal` | 16 @12 | 96x128 | B+ | Nano-heal (single) — repair nanites spiral down the unit, + motes rise, green-mint pulse |
| `spl_nanoheal_area` | 20 @12 | 224x192 | B+ | Nano-heal (area 3x3) — repair grid lights the area, nanite columns rise on every tile, + motes |
| `spl_protect` | 14 @12 | 96x128 | B+ | Protect — gold armour plates orbit in and lock into a ring, shield sigil flashes |
| `spl_revive` | 21 @12 | 128x160 | A- | Revive pulse — gold beam drops, ECG trace spikes, three defib ping rings, life sparks rise |
| `spl_scan` | 20 @12 | 224x192 | A- | Scan / reveal — radar ping arcs sweep the 3x3 area, sweep beam turns, target brackets lock with a ! marker |
| `spl_shell` | 14 @12 | 96x128 | B | Shell — teal hex sigil, bubble shell ripples around the unit (energy defence) |
| `spl_slow` | 16 @12 | 96x128 | B | Slow — violet hourglass, sluggish tick ring, sand motes sink |
| `spl_stunned_loop` | 12 @10 loop | 96x128 | B | Stunned (loop) — bolt icons orbit overhead, static sparks flicker on the unit |

### Big ones (6)

| id | frames @fps | cell | grade | what |
|---|---|---|---|---|
| `spl_kinetic_rod` | 24 @12 | 224x300 | B+ | Kinetic rod — orbital tungsten rod streaks down with a plasma sheath + smoke trail, white-out impact, dust shockwave, crater |
| `spl_limit_doctrine` | 30 @12 | 480x340 | A- | Limit break: DOCTRINE PROTOCOL (map-wide 7x7) — circuit grid floods the battlefield, the glitch skull rises, orbital lances rain on the field, white-out |
| `spl_missile_barrage` | 26 @12 | 224x240 | A- | Missile barrage — a salvo arcs in with smoke trails, rockets hit tile by tile across the 3x3, flashes + shock rings |
| `spl_orbital_laser` | 28 @12 | 224x300 | A- | Orbital strike — satellite laser: red lock-on, beam slams the 3x3, molten ground, smoke column |
| `spl_summon_drones` | 26 @12 | 224x220 | B+ | Summon: drone swarm — a V of strike drones descends, rings the target, strafes it with red tracers, peels away |
| `spl_summon_mech` | 24 @12 | 160x256 | B+ | Summon: mech drop — gold mech g02 (SE) descends on retro-thrusters, dust blast, heavy landing shock, visor glow |

### Summon: Brian's sigil head (+ life steal, 4 diagonals) (8)

Source art: Brian's circuit-diamond sigil sheet (3x3, 8 spin frames around an empty centre; read clockwise from top-left so the core drifts the same way on both faces; the red-glitch frame is part of the spin) and his spinning ghoul head GIF (8 frames). Both are 4x-upscaled pixel art: brought back to native pixels with nearest, then the sigil is 1/4-downscaled and the head 1/2-downscaled with a trace-preserving block filter, requantised to palettes taken from his art, and given a 1px silhouette outline in the darkest teal / navy (no black). The flat sigil on the tile is his front frame squashed into the 2:1 iso diamond.

Chain (all anchored on the summon tile ground point; `config.headPoint` = where the head floats, ~2 tiles of iso height above the tile):
- `spl_summon_sigil_head` (one-shot, `endsOn` the loop): sigil glitches in (RGB split, scanline slices) -> spins twice -> violet neon beam erupts (`hits[0]` / `emitters.beamFrame` 22) -> head rides up spinning and settles (`emitters.headSettledFrame` 36). Its last frame is the loop's frame 15.
- `spl_sigil_head_loop` (16 f, seamless): hold pose.
- `spl_head_lifesteal_<DIR>` (one-shot, `endsOn` the loop; starts on loop frame 0 and ends on loop frame 15): the target is 2 steps along the diagonal (`config.targetTileCentre`, `travelVector`, `rangePx`). `hits[0]` = soul rip on the target (frame 5), `hits[1]` = heal pulse lands in the sigil (frame 26): play `spl_lifesteal_heal` on the summoner there. Facings use the head frame whose open mouth points at the target: SE = 3/4 front-right, SW = 3/4 front-left, NE = profile right, NW = profile left (his GIF has no back-3/4 frame with the mouth visible).
- `spl_sigil_head_dismiss` (one-shot): head glitch-dissolves down the beam, beam collapses, sigil glitches out.
- Summon, loop, dismiss and life steal all put the anchor 196 px below the cell top, so the beam top does not jump when clips swap (life steal cells are wider/taller below for the target tile). The beam fades in (dithered taper) over the top 40 px of the cell.

| id | frames @fps | cell | grade | what |
|---|---|---|---|---|
| `spl_summon_sigil_head` | 46 @12 | 128x216 | A- | Summon: sigil head — Brian's circuit sigil glitches onto the tile, spins twice, a violet neon beam erupts from the ground and the spinning ghoul head rides it up to float ~2 tiles above the tile |
| `spl_sigil_head_loop` | 16 @12 | 128x216 | A- | Sigil head (loop) — the head floats ~2 tiles up, spinning and bobbing on the violet beam; sigil spins on the glowing tile |
| `spl_sigil_head_dismiss` | 16 @12 | 128x216 | B+ | Sigil head (dismiss) — the head glitches apart and sinks into the sigil, the beam collapses into the ground, the sigil glitches out |
| `spl_head_lifesteal_NE` | 32 @12 | 216x240 | A- | Sigil head: life steal NE — the head stops spinning, faces the target 2 tiles NE and opens its jaw; violet soul streams rip out of the target into its mouth (glitch slices, flaring eyes), then a heal pulse runs down the beam into the sigil and it spins back to idle |
| `spl_head_lifesteal_SE` | 32 @12 | 216x240 | A- | Sigil head: life steal SE — the head stops spinning, faces the target 2 tiles SE and opens its jaw; violet soul streams rip out of the target into its mouth (glitch slices, flaring eyes), then a heal pulse runs down the beam into the sigil and it spins back to idle |
| `spl_head_lifesteal_SW` | 32 @12 | 216x240 | A- | Sigil head: life steal SW — the head stops spinning, faces the target 2 tiles SW and opens its jaw; violet soul streams rip out of the target into its mouth (glitch slices, flaring eyes), then a heal pulse runs down the beam into the sigil and it spins back to idle |
| `spl_head_lifesteal_NW` | 32 @12 | 216x240 | A- | Sigil head: life steal NW — the head stops spinning, faces the target 2 tiles NW and opens its jaw; violet soul streams rip out of the target into its mouth (glitch slices, flaring eyes), then a heal pulse runs down the beam into the sigil and it spins back to idle |
| `spl_lifesteal_heal` | 16 @12 | 96x128 | B+ | Life steal: heal received — violet soul motes stream in and turn mint, + motes rise, pulse ring (play on the summoner) |

## Grades
A-: 25, B: 5, B+: 33

## Known limits
- `spl_toxic_t1` (B) is the smallest/quietest of the tiers; `spl_slow`, `spl_shell`, `spl_emp`, `spl_stunned_loop` (B) are readable but simpler than the rest (thin 1px arcs/rings at 1x).
- Back-side particles (helix, orbiting motes) are drawn in the same layer as the front ones (dimmer shade) — the clip is one layer drawn over the unit.
- `spl_summon_mech` composites gold mech **g02 SE** (Brian's painted art, unmodified) — SE only; other facings were not invented.
- Sky entry: the kinetic rod and missile barrage rockets still enter from the cell top (hidden by the rocket smoke); place these cells so their top is off-screen or under the UI if that matters.
- Sigil head: the sigil art is AI-style and not perfectly consistent between spin frames, so the spin has a slight wobble; the jaw drop is done by stretching the mouth row (1-3 px). NE/NW life steal use the profile frames.
- Generator: `/workspace/spells/` (sfx.py primitives, caster.py, el_*.py, proj.py, support.py, big.py, summon.py + sighead.py, pack.py).
