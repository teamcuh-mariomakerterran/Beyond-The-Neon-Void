# interior_props_life — ambient idle loops for interior props (v1)

**244 props / 488 clips** (full + overlay each). Reviewed 647 unique interior props from the placement library; shipped A 1, A- 45, B+ 102, B 96; dropped 403 (B- 219, C 184).

Seamless idle loops for Black Doctrine interior props, built only from each prop's **own painted-lit pixels** (bright + saturated, contrast-checked against the
ring of body pixels around them) plus in-silhouette FX. The prop body is never recoloured and the silhouette (alpha) never changes.

## What moves
* **Screens / terminals / map tables / TVs:** a soft scanline band sweeps down the screen, **skewed to the screen's painted angle** (slope fitted from the panel's top and bottom
  edges), plus a one-frame interlace glitch (alternate rows dip one shade) at a seeded moment.
* **Glass / windows / lanterns:** a soft specular sheen glides across once per loop.
* **Holograms** (holo cubes, cylinders, projector pads, map crystals): fast faint scan lines + brightness jitter + a thicker travelling scan band.
* **Glowing tanks / cryo pods / energy capsules / IV bags:** rising bubbles that follow the tank's real inner shape, **selectively outlined** (rim = the liquid's own colour
  darkened, never black; core = near-white highlight), plus a gentle glow breathe.
* **Radar scope:** a bright sweep wedge with a fading trail rotates once per loop. **Warning beacon:** a light band sweeps round the amber dome.
* **Status lights:** blink / pulse with per-light phase and rate (seeded by prop id + light index), so neighbouring lights and props never pulse in sync.
* **Cables / energy strips / circuit traces:** a travelling pulse runs along each thin lit strip.
* Fans/vents were **not** spun: every fan/grille in this set is painted at an angle in a single view, so rotation could not be done cleanly; their lights still blink.

## Format
* 24 frames @ 100 ms (10 fps), loop = 2.4 s, seamless (every effect's period divides 24).
* Exact canvas of the source sprite; `anchor` = bottom-centre of the visible prop `[cx, bottom]`, `depthKey: share_base`; full clips keep the source alpha (transparent background).
* Two clips per prop: `ip_<id>` (full drop-in frames) and `ip_<id>_overlay` (changed pixels only, hard alpha). Overlay-over-static == full frame, verified for every frame of every clip.
* Emitters per clip JSON under `emitters`: `statusLights` (x, y, warm), `energyStrips` (bbox), `panels` (kind screen/glass/holo/tank/radar/beacon, bbox, slope, area), `counts`.
* Each clip JSON carries `qaGrade`, `qaNote`, `phaseSeed`, the per-prop `config` override (if any) and `sourceArt` (file, gamePath, placementKey, footprint, identicalFiles).

## Shipped
| clip | grade | what moves |
|---|---|---|
| `ip_observation_p05_2` | A | radar console: rotating radar sweep wedge + blinking LEDs |
| `ip_base_p10` | A- | circuit wall panel: energy traces sweep |
| `ip_briefing_back_sw_p02` | A- | wall monitor: skewed scanline sweep + interlace glitch, status LEDs |
| `ip_briefing_back_sw_p04` | A- | holo map table: scanline sweep + glitch |
| `ip_briefing_p02` | A- | wall monitor: skewed scanline sweep + interlace glitch, status LEDs |
| `ip_briefing_p04` | A- | holo map table: scanline sweep + glitch |
| `ip_briefing_upgraded_p02` | A- | wall monitor (upgraded): scanline sweep + glitch + LEDs |
| `ip_brig_p10_2` | A- | energy cell pillars: hologram shimmer |
| `ip_command_back_sw_p02_2` | A- | world-map wall display: sweep + glitch |
| `ip_command_back_sw_p04_2` | A- | holo map table: sweep + glitch |
| `ip_command_back_sw_p10_2` | A- | holo projector pad: shimmer + LEDs |
| `ip_command_p02_2` | A- | world-map wall display: scanline sweep + glitch + LEDs |
| `ip_command_p04_2` | A- | holo map table: sweep + glitch + LEDs |
| `ip_command_p10_2` | A- | holo projector pad: shimmer + LEDs |
| `ip_command_upgraded_back_sw_p02_2` | A- | world-map wall display: sweep + glitch |
| `ip_command_upgraded_back_sw_p04_2` | A- | holo cube on table: hologram shimmer + sweep |
| `ip_command_upgraded_back_sw_p07_2` | A- | holo crystal over projector: shimmer lines |
| `ip_command_upgraded_p02_2` | A- | world-map wall display (upgraded): sweep + glitch |
| `ip_command_upgraded_p04_2` | A- | holo cube on table: hologram shimmer lines + sweep |
| `ip_command_upgraded_p07_2` | A- | holo crystal over projector: shimmer lines |
| `ip_lab_back_sw_p02_2` | A- | cryo pod (back): bubbles + glow + LEDs |
| `ip_lab_p03_2` | A- | cryo pod: rising outlined bubbles + gentle glow breathe + LEDs |
| `ip_lab_upgraded_p03` | A- | cryo pod (upgraded): bubbles + glow + LEDs |
| `ip_living_back_sw_p04_2` | A- | TV: scanline sweep + glitch |
| `ip_living_p04_2` | A- | TV: scanline sweep + glitch |
| `ip_living_upgraded_p04_2` | A- | TV (upgraded): scanline sweep + glitch |
| `ip_lounge_upgraded_p02_2` | A- | computer terminal: text screen sweep + glitch |
| `ip_medbay_back_sw_p07_2` | A- | body-scan station: screen sweep + glitch |
| `ip_medbay_p08_2` | A- | body-scan station: screen sweep + glitch |
| `ip_medbay_upgraded_p09_2` | A- | body-scan station: screen sweep + glitch + LEDs |
| `ip_power_upgraded_p01_2` | A- | power cell with cable: bars sweep + cable pulse |
| `ip_power_upgraded_p06_2` | A- | energy cell: cyan bars sweep + cable pulse |
| `ip_power_upgraded_p09_2` | A- | energy core: bubbles rising in the glowing tube + arcs |
| `ip_security_upgraded_p01_2` | A- | security gate: energy-field arcs pulse |
| `ip_security_upgraded_p07_2` | A- | power tubes: bubbles rising in each tube + glow |
| `ip_server_back_sw_p02_2` | A- | holo cube: shimmer edges + particles |
| `ip_server_back_sw_p08` | A- | holo cylinder on pedestal: shimmer/sweep + LEDs |
| `ip_server_p02_2` | A- | holo cube: shimmer edges + inner cube + particles twinkle |
| `ip_server_p08` | A- | server wall: multiple displays sweep + radar scope |
| `ip_server_p09` | A- | holo cylinder on pedestal: shimmer/sweep + LEDs |
| `ip_server_upgraded_p02_2` | A- | holo cube: shimmer edges + particles |
| `ip_server_upgraded_p03_2` | A- | console: text screen sweep + glitch + LEDs |
| `ip_server_upgraded_p08` | A- | server wall (upgraded): displays sweep + scope + LEDs |
| `ip_server_upgraded_p09` | A- | holo cylinder on pedestal: shimmer/sweep + LEDs |
| `ip_set1_back_sw_p10` | A- | circuit wall panel: energy traces sweep |
| `ip_set1_upgraded_p08` | A- | circuit wall panel: energy traces sweep |
| `ip_airlock_p07` | B+ | wall unit: tube light flicker + sweep + LEDs |
| `ip_airlock_p09` | B+ | airlock console: screen sweep + glitch + LEDs |
| `ip_airlock_p10` | B+ | capsule light bank: tubes glow sweep |
| `ip_airlock_upgraded_p05` | B+ | gas tanks: cyan energy arcs pulse |
| `ip_airlock_upgraded_p07` | B+ | wall unit: tube light flicker + sweep |
| `ip_airlock_upgraded_p09` | B+ | airlock console: screen sweep + glitch + LEDs |
| `ip_airlock_upgraded_p10` | B+ | capsule light bank: tubes glow sweep |
| `ip_armory_upgraded_p05_2` | B+ | weapon crate: cyan light strips pulse + LEDs |
| `ip_base_p01` | B+ | triple-monitor desk: screens sweep + glitch |
| `ip_base_p03` | B+ | cyan-striped panel/door: sweep + glitch + LEDs |
| `ip_base_p06` | B+ | terminal: text screen sweep + glitch |
| `ip_base_p09` | B+ | orange energy capsule: bubbles rise in the glowing core + LEDs |
| `ip_bathroom_upgraded_p02_2` | B+ | shower glass: sheen sweep + LEDs |
| `ip_bathroom_upgraded_p03_2` | B+ | lit mirror: frame light pulse |
| `ip_briefing_back_sw_p06` | B+ | wall display: scanline sweep + glitch |
| `ip_briefing_back_sw_p10` | B+ | light bar: tube flicker + sweep |
| `ip_briefing_p06` | B+ | wall display: scanline sweep + glitch |
| `ip_briefing_p10` | B+ | light bar: tube flicker + sweep |
| `ip_briefing_upgraded_p05` | B+ | wall display: sweep + glitch |
| `ip_brig_p04_2` | B+ | glass window: soft specular sheen sweep |
| `ip_brig_p05_2` | B+ | control console: screen sweep + buttons blink |
| `ip_brig_p08_2` | B+ | control desk: screens sweep + buttons blink |
| `ip_cantina_back_sw_p02_2` | B+ | drinks fridge: glass sheen + LEDs |
| `ip_cantina_back_sw_p05_2` | B+ | neon sign: magenta panel scanline + cyan frame pulse |
| `ip_cantina_p02_2` | B+ | drinks fridge: glass sheen sweep + LEDs |
| `ip_cantina_p05_2` | B+ | neon sign: magenta panel scanline + cyan frame pulse |
| `ip_cantina_upgraded_p02_2` | B+ | drinks fridge (upgraded): glass sheen + LEDs |
| `ip_cantina_upgraded_p05_2` | B+ | neon sign: magenta panel scanline + cyan frame pulse |
| `ip_command_back_sw_p05_2` | B+ | control desk: button banks blink + small screens |
| `ip_command_back_sw_p07_2` | B+ | lock terminal: screen sweep + keypad LEDs |
| `ip_command_p05_2` | B+ | control desk: button banks blink + small screens |
| `ip_command_p07_2` | B+ | lock terminal: screen sweep + keypad LEDs |
| `ip_command_upgraded_back_sw_p03_2` | B+ | server tower: LED banks blink + cable pulse |
| `ip_command_upgraded_back_sw_p05_2` | B+ | control desk: button banks blink + small screens |
| `ip_command_upgraded_back_sw_p08_2` | B+ | lock terminal: screen sweep + keypad LEDs |
| `ip_command_upgraded_back_sw_p09_2` | B+ | control desk: screens sweep + button banks blink |
| `ip_command_upgraded_p03_2` | B+ | server tower: LED banks blink + cable pulse |
| `ip_command_upgraded_p05_2` | B+ | control desk: button banks blink + small screens |
| `ip_command_upgraded_p08_2` | B+ | lock terminal: screen sweep + keypad LEDs |
| `ip_command_upgraded_p09_2` | B+ | control desk: screens sweep + button banks blink |
| `ip_corridor_back_sw_p02_2` | B+ | wall light tube: flicker + sweep |
| `ip_corridor_p02_2` | B+ | wall light tube: flicker + sweep |
| `ip_corridor_upgraded_p02_2` | B+ | wall light tube: flicker + sweep |
| `ip_garage_p05_2` | B+ | kiosk terminal: screen sweep + glitch |
| `ip_garage_p09_2` | B+ | twin-screen console: screens sweep + glitch |
| `ip_gym_back_sw_p10_2` | B+ | wall display: scanline sweep + glitch |
| `ip_gym_p10_2` | B+ | wall display: scanline sweep + glitch |
| `ip_gym_upgraded_p06_2` | B+ | water cooler: bubbles rise in the jug + LEDs |
| `ip_gym_upgraded_p10_2` | B+ | wall display: sweep + glitch + LEDs |
| `ip_kitchen_upgraded_p02` | B+ | stove: cyan burner rings glow + oven display sweep + cable pulse |
| `ip_lab_back_sw_p10` | B+ | specimen fridge (back): glass sheen + LEDs |
| `ip_lab_p09` | B+ | lab monitor: screen sweep + glitch + LEDs |
| `ip_lab_p10` | B+ | specimen fridge: glass sheen sweep + LEDs |
| `ip_lab_upgraded_back_sw_p06` | B+ | microscope desk: monitor sweep + lit drawer |
| `ip_lab_upgraded_back_sw_p10` | B+ | specimen fridge (back): glass sheen + LEDs |
| `ip_lab_upgraded_p05` | B+ | microscope desk: monitor sweep + lit drawer |
| `ip_lab_upgraded_p09` | B+ | lab monitor (upgraded): sweep + glitch |
| `ip_lab_upgraded_p10` | B+ | specimen fridge: glass sheen sweep + LEDs |
| `ip_lounge_upgraded_p04_2` | B+ | coffee table holo screen: shimmer + mug unchanged |
| `ip_lounge_upgraded_p08_2` | B+ | circuit wall panel: trace sweep |
| `ip_medbay_back_sw_p01_2` | B+ | ECG monitor stack: trace screen sweep + LEDs |
| `ip_medbay_p01_2` | B+ | ECG monitor stack: trace screen sweep + LEDs |
| `ip_medbay_upgraded_p02_2` | B+ | heart monitor: ECG screen sweep + glitch + LEDs |
| `ip_power_p04_2` | B+ | power console: screen sweep + button LEDs |
| `ip_power_upgraded_p02_2` | B+ | generator: glowing window sweep + emitter glow |
| `ip_power_upgraded_p03_2` | B+ | power box: energy arcs pulse |
| `ip_power_upgraded_p04_2` | B+ | control console: screen sweep + discharge |
| `ip_power_upgraded_p07_2` | B+ | battery block: energy crackle pulse + cable |
| `ip_power_upgraded_p08_2` | B+ | power unit: discharge pulse + panel sweep |
| `ip_security_back_sw_p08_2` | B+ | security monitor: sweep + glitch |
| `ip_security_back_sw_p10_2` | B+ | warning sign: orange triangle neon pulse + LED |
| `ip_security_p08_2` | B+ | security monitor: sweep + glitch |
| `ip_security_p10_2` | B+ | warning sign: orange triangle neon pulse + LED |
| `ip_security_upgraded_p08_2` | B+ | sensor mast: cyan panels sweep + LEDs |
| `ip_security_upgraded_p09_2` | B+ | terminal: screen sweep + glitch |
| `ip_security_upgraded_p10_2` | B+ | warning sign: orange triangle neon pulse + LED |
| `ip_server_back_sw_p03_2` | B+ | terminal: text screen sweep + glitch |
| `ip_server_back_sw_p04_2` | B+ | cable tray: energy pulse along cyan cables |
| `ip_server_p03_2` | B+ | terminal: text screen sweep + glitch |
| `ip_server_p04_2` | B+ | cable tray: energy pulse along cyan cables |
| `ip_server_p06_2` | B+ | terminal: text screen sweep + glitch |
| `ip_server_upgraded_p01_2` | B+ | server rack: LEDs + cyan cable pulse |
| `ip_server_upgraded_p04_2` | B+ | cable tray: energy pulse along cyan cables |
| `ip_server_upgraded_p06_2` | B+ | terminal: text screen sweep + glitch + LEDs |
| `ip_set1_back_sw_p09` | B+ | orange energy capsule: bubbles rise in the glowing core + LEDs |
| `ip_set1_upgraded_p01` | B+ | triple-monitor desk: screens sweep + glitch |
| `ip_set1_upgraded_p03` | B+ | cyan-striped panel: sweep + glitch + LEDs |
| `ip_set1_upgraded_p05` | B+ | medical cabinet: glowing cross sign pulse |
| `ip_set1_upgraded_p06` | B+ | terminal: text screen sweep + glitch + LEDs |
| `ip_set1_upgraded_p10` | B+ | orange energy capsule: bubbles rise in the glowing core + LEDs |
| `ip_set1_variants_p01_2` | B+ | monitor desk: screens sweep + glitch |
| `ip_set1_variants_p03_2` | B+ | circuit wall screen: trace sweep |
| `ip_set1_variants_p04_2` | B+ | wall screen panel: sweep + glitch |
| `ip_set1_variants_p07` | B+ | terminal: text screen sweep + glitch |
| `ip_set1_variants_p09` | B+ | orange energy capsule: bubbles rise in the glowing core + LEDs |
| `ip_set2_upgraded_p03_2` | B+ | control desk: twin screens sweep + keyboard LEDs |
| `ip_set2_upgraded_p06_2` | B+ | hanging neon frame: energy pulse round the frame |
| `ip_storage_upgraded_p01` | B+ | crate with glowing windows: sweep + LEDs |
| `ip_storage_upgraded_p05` | B+ | holo-glass drum: circuit glass scanline sweep + glitch |
| `ip_storage_upgraded_p08` | B+ | capsule tank: bubbles in window + glow |
| `ip_storage_upgraded_p09` | B+ | circuit wall panel: cyan traces sweep + corner LEDs |
| `ip_utility_upgraded_p11` | B+ | barrel with glowing rings: ring pulse + sweep |
| `ip_airlock_upgraded_p01` | B | airlock door: side light flicker + sweep |
| `ip_bathroom_back_sw_p02_2` | B | shower (back): glass sheen sweep |
| `ip_bathroom_back_sw_p06_2` | B | wall dispenser (back): small screen sweep |
| `ip_bathroom_p02_2` | B | shower: glass sheen sweep |
| `ip_bathroom_p06_2` | B | wall dispenser: small screen sweep + button |
| `ip_bathroom_upgraded_p04_2` | B | appliance: lit panel sweep + LEDs |
| `ip_bathroom_upgraded_p05_2` | B | heated towel rail: electric field crackle shimmer (towel untouched) |
| `ip_bathroom_upgraded_p07_2` | B | water heater: small screen sweep + LEDs |
| `ip_bathroom_upgraded_p08_2` | B | fan unit: edge lights pulse (fan not spun: painted blades) |
| `ip_bathroom_upgraded_p09_2` | B | cabinet with lit top panel: sweep + LEDs |
| `ip_briefing_back_sw_p07` | B | projector unit: small display sweep |
| `ip_briefing_p07` | B | projector unit: small display sweep |
| `ip_brig_p09_2` | B | security camera: lens pulse + LEDs |
| `ip_cantina_back_sw_p09_2` | B | amber lantern: glass sheen glides over the glow |
| `ip_cantina_p09_2` | B | amber lantern: glass sheen glides over the glow |
| `ip_cantina_upgraded_p09_2` | B | cyan fire bin: flame shimmer/flicker |
| `ip_cantina_upgraded_p10_2` | B | amber lantern: glass sheen glides over the glow |
| `ip_command_back_sw_p03_2` | B | server tower: LED banks blink |
| `ip_command_back_sw_p06_2` | B | tactical map board: route lines pulse |
| `ip_command_back_sw_p08_2` | B | control desk with chair: screens sweep + buttons |
| `ip_command_back_sw_p09_2` | B | holo pad base: centre emitter glow sweep + LEDs |
| `ip_command_p03_2` | B | server tower: LED banks blink |
| `ip_command_p06_2` | B | tactical map board: cyan route lines pulse |
| `ip_command_p08_2` | B | control desk with chair: screens sweep + buttons |
| `ip_command_p09_2` | B | holo pad base: centre emitter glow sweep + LEDs |
| `ip_command_upgraded_back_sw_p10_2` | B | holo pad base: centre emitter glow sweep + LEDs |
| `ip_command_upgraded_p06_2` | B | tactical map board: route lines pulse |
| `ip_command_upgraded_p10_2` | B | holo pad base: centre emitter glow sweep + LEDs |
| `ip_garage_p07_2` | B | hanging lamp: bulb ring breathes |
| `ip_gym_upgraded_p01_2` | B | punching bag: neon strip pulse |
| `ip_gym_upgraded_p02_2` | B | weight bench: neon strip pulse |
| `ip_gym_upgraded_p03_2` | B | treadmill: console + rail lights pulse |
| `ip_gym_upgraded_p08_2` | B | lit mirror: frame light pulse |
| `ip_gym_upgraded_p09_2` | B | floor mat: glowing edge pulse |
| `ip_kitchen_p07` | B | microwave: display sweep + keypad LEDs |
| `ip_kitchen_upgraded_p01` | B | fridge: side canister glow + LEDs |
| `ip_kitchen_upgraded_p04` | B | sink: water sheen sweep + LEDs |
| `ip_lab_back_sw_p04_2` | B | specimen shelf: glowing jars breathe + bubbles |
| `ip_lab_back_sw_p05_2` | B | IV stand: bubbles in the drip bag |
| `ip_lab_back_sw_p06_2` | B | microscope desk: monitor sweep + lit drawer bar |
| `ip_lab_p04_2` | B | specimen shelf: glowing jars breathe + bubbles |
| `ip_lab_p05_2` | B | IV stand: bubbles in the drip bag |
| `ip_lab_p06_2` | B | microscope desk: monitor sweep + lit drawer bar |
| `ip_lab_upgraded_back_sw_p01_2` | B | lab bench: lit drawer + tube rack glow |
| `ip_lab_upgraded_back_sw_p04` | B | specimen shelf: glowing jars breathe + bubbles |
| `ip_lab_upgraded_back_sw_p05` | B | IV stand: bubbles in the drip bag |
| `ip_lab_upgraded_p01_2` | B | lab bench: lit drawer + tube rack glow |
| `ip_lab_upgraded_p04` | B | specimen shelf: glowing jars breathe + bubbles |
| `ip_lab_upgraded_p06` | B | IV stand: bubbles in the drip bag |
| `ip_laundry_p06_2` | B | wash basin: water sheen sweep |
| `ip_living_back_sw_p08_2` | B | floor lamp: bulb breathes |
| `ip_living_p10` | B | desk lamp: bulb breathes |
| `ip_living_upgraded_p05_2` | B | storage chest: glowing lights pulse |
| `ip_living_upgraded_p10` | B | desk lamp: bulb breathes |
| `ip_lounge_p02_2` | B | desktop monitor: screen glare sweep |
| `ip_lounge_upgraded_p01_2` | B | sofa neon piping: travelling pulse |
| `ip_lounge_upgraded_p07_2` | B | floor lamp: warm bulb breathes |
| `ip_lounge_upgraded_p09_2` | B | server rack: LEDs + cable pulse |
| `ip_medbay_back_sw_p03_2` | B | surgical lamp: bulbs breathe together |
| `ip_medbay_p03_2` | B | surgical lamp: bulbs breathe together |
| `ip_medbay_upgraded_p04_2` | B | surgical lamp: bulbs breathe together |
| `ip_observation_p01_2` | B | mountain-view window: glass sheen sweep (sky only) |
| `ip_observation_p03_2` | B | observation gear: small screens + LEDs |
| `ip_observation_p06_2` | B | console: small screen sweep + LEDs |
| `ip_observation_p07_2` | B | radio set: small display + LEDs |
| `ip_power_back_sw_p09_2` | B | warning beacon: light band sweeps round the amber dome + LEDs |
| `ip_power_p09_2` | B | warning beacon: light band sweeps round the amber dome + LEDs |
| `ip_power_upgraded_p05_2` | B | energised cable spool: light band sweeps over the glowing coil + clamp LED |
| `ip_security_back_sw_p01_2` | B | scanner gate: side light strips pulse |
| `ip_security_p01_2` | B | scanner gate: side light strips pulse |
| `ip_security_upgraded_p03_2` | B | generator: screen sweep + glowing canister |
| `ip_security_upgraded_p04_2` | B | small terminal: screen strip sweep + cable pulse |
| `ip_security_upgraded_p06_2` | B | safe: keypad glow + LEDs |
| `ip_server_back_sw_p01_2` | B | server rack: orange LED banks blink |
| `ip_server_back_sw_p09` | B | twin wall terminals: LED grids blink + cable pulse |
| `ip_server_back_sw_p10` | B | patch panel: port LEDs + cable pulse |
| `ip_server_p01_2` | B | server rack: orange LED banks blink |
| `ip_server_p10` | B | patch panel: port LEDs blink + cable pulse |
| `ip_server_upgraded_p10` | B | patch panel (upgraded): port LEDs + cable pulse |
| `ip_set2_back_sw_p05_2` | B | console: twin small screens sweep + keys |
| `ip_set2_back_sw_p06_2` | B | hanging frame: light bars flicker + sweep |
| `ip_set2_p05_2` | B | console: twin small screens sweep + keys |
| `ip_set2_p06_2` | B | hanging frame: light bars flicker + sweep |
| `ip_set2_upgraded_p04_2` | B | crate with lens: lens glow + LEDs |
| `ip_set2_upgraded_p07_2` | B | pipe junction: glowing ring bands pulse |
| `ip_set2_upgraded_p09_2` | B | security camera: lens pulse + LEDs |
| `ip_set2_variants_p04_2` | B | wall fan: blade glow pulse (blades not spun: painted view) |
| `ip_set2_variants_p05_2` | B | console: twin small screens sweep + keys |
| `ip_set2_variants_p06_2` | B | hanging frame: light bars flicker + sweep |
| `ip_storage_back_sw_p09_2` | B | fuel tank: gauge bars blink |
| `ip_storage_p09_2` | B | fuel tank: gauge bars blink |
| `ip_storage_upgraded_p02` | B | rack of lit modules: sweep + LEDs |
| `ip_storage_upgraded_p06` | B | crate: cyan lights pulse |
| `ip_storage_upgraded_p07` | B | tool chest: small screen + LEDs |
| `ip_utility_upgraded_p01_2` | B | cart with glowing crates: sweep + LEDs |
| `ip_utility_upgraded_p03_2` | B | control panel: lit buttons blink |

## Dropped (403)

B- = only one or two tiny LEDs / a hairline strip change, which does not read as life at game size; C = nothing truly lit, or the only 'lit' colours are paint (crate labels, bottle/metal glints, mattress/cross paint), so animating them would recolour the body.

| source | grade | why |
|---|---|---|
| `indoor_airlock_p01.png` | B- | airlock door: top LED only |
| `indoor_airlock_p02.png` | B- | docking clamp: small lights only |
| `indoor_airlock_p03.png` | B- | floor plate: edge lights only |
| `indoor_airlock_p06.png` | B- | airlock hatch: side lights blink only |
| `indoor_airlock_p08.png` | B- | floor hatch: faint edge lights |
| `indoor_airlock_upgraded_p02.png` | B- | docking clamp: small lights only |
| `indoor_airlock_upgraded_p03.png` | B- | floor plate: edge lights only |
| `indoor_airlock_upgraded_p06.png` | B- | airlock hatch: side lights blink only |
| `indoor_airlock_upgraded_p08.png` | B- | floor hatch: faint edge lights |
| `indoor_armory_back_sw_p06_2.png` | B- | crate: cyan strip only |
| `indoor_armory_back_sw_p08.png` | B- | backpack: few small lights |
| `indoor_armory_p08.png` | B- | backpack: cyan strip + tag lights |
| `indoor_armory_upgraded_back_sw_p05_2.png` | B- | crate: cyan strips pulse only |
| `indoor_armory_upgraded_p01_2.png` | B- | weapon lockers: tiny LEDs only |
| `indoor_armory_upgraded_p03_2.png` | B- | armour stand: few small lights |
| `indoor_armory_upgraded_p06_2.png` | B- | backpack: few small lights |
| `indoor_armory_workshop_p01_2.png` | B- | press machine: small lights only |
| `indoor_armory_workshop_p03_2.png` | B- | turret mount: one tiny light |
| `indoor_armory_workshop_p04_2.png` | B- | parts shelf: small cyan items blink |
| `indoor_armory_workshop_p06_2.png` | B- | gauge stand: small lights only |
| `indoor_armory_workshop_p08_2.png` | B- | workbench: bottle highlights only |
| `indoor_armory_workshop_p10_2.png` | B- | scope bench: lens glint + one LED |
| `indoor_base_p02.png` | B- | stool: base light only |
| `indoor_base_p04.png` | B- | locker: small LEDs only |
| `indoor_base_p07.png` | B- | crate: small LEDs only |
| `indoor_base_p08.png` | B- | storage shelf: jar/box lights blink only |
| `indoor_bathroom_back_sw_p01_2.png` | B- | sink: one tiny lit panel |
| `indoor_bathroom_back_sw_p03_2.png` | B- | appliance: one small side light |
| `indoor_bathroom_back_sw_p04_2.png` | B- | mirror: thin edge light only |
| `indoor_bathroom_back_sw_p07_2.png` | B- | wall fan: corner LEDs only |
| `indoor_bathroom_back_sw_p08_2.png` | B- | bin: one small light strip |
| `indoor_bathroom_back_sw_p09_2.png` | B- | cabinet: base strip only |
| `indoor_bathroom_p01_2.png` | B- | sink: one tiny lit panel |
| `indoor_bathroom_p03_2.png` | B- | appliance: one small side light |
| `indoor_bathroom_p04_2.png` | B- | mirror: thin edge light only |
| `indoor_bathroom_p07_2.png` | B- | wall fan: corner LEDs only (painted blades not spun) |
| `indoor_bathroom_p08_2.png` | B- | bin: one small light strip |
| `indoor_bathroom_p09_2.png` | B- | cabinet: base strip only |
| `indoor_bathroom_upgraded_p01_2.png` | B- | sink: only a tiny lit panel |
| `indoor_bathroom_upgraded_p06_2.png` | B- | lockers: base strip only |
| `indoor_briefing_back_sw_p03.png` | B- | chair: underglow only |
| `indoor_briefing_back_sw_p05.png` | B- | cabinet: one small screen |
| `indoor_briefing_back_sw_p09.png` | B- | floor crate: corner LEDs only |
| `indoor_briefing_p03.png` | B- | chair: underglow only |
| `indoor_briefing_p05.png` | B- | cabinet: one small screen |
| `indoor_briefing_p09.png` | B- | floor crate: corner LEDs only |
| `indoor_briefing_upgraded_p01.png` | B- | floor pad: faint lights |
| `indoor_briefing_upgraded_p03.png` | B- | chair: underglow only |
| `indoor_briefing_upgraded_p06.png` | B- | filing cabinet: side device light only |
| `indoor_brig_p01_2.png` | B- | cell door: lock LEDs only |
| `indoor_brig_p06_2.png` | B- | toilet: flush light only |
| `indoor_brig_p07_2.png` | B- | food hatch: small LEDs only |
| `indoor_cantina_back_sw_p07_2.png` | B- | dispenser: liquid tanks painted; little lit detail |
| `indoor_cantina_p01_2.png` | B- | bottle shelf: thin light bar only |
| `indoor_cantina_p08_2.png` | B- | dispenser: liquid tanks painted orange; little lit detail |
| `indoor_cantina_upgraded_p01_2.png` | B- | bottle shelf: thin light bar only |
| `indoor_cantina_upgraded_p03_2.png` | B- | bar counter: small lights + cable glints |
| `indoor_cantina_upgraded_p06_2.png` | B- | dartboard: one faint ring; mostly paint |
| `indoor_cantina_upgraded_p07_2.png` | B- | sofa: underglow only |
| `indoor_cantina_upgraded_p08_2.png` | B- | dispenser: liquid tanks are painted orange; little lit detail |
| `indoor_command_p01_2.png` | B- | chair: side lights only |
| `indoor_command_upgraded_back_sw_p01_2.png` | B- | command chair: underglow only |
| `indoor_command_upgraded_p01_2.png` | B- | command chair: few small lights |
| `indoor_corridor_back_sw_p04.png` | B- | floor hatch: faint edge lights |
| `indoor_corridor_p04.png` | B- | floor hatch: faint edge lights |
| `indoor_corridor_upgraded_p04.png` | B- | floor hatch: faint edge lights |
| `indoor_garage_p02_2.png` | B- | tool chest: small cyan lights only |
| `indoor_garage_p03_2.png` | B- | fuel pump: small screen only |
| `indoor_garage_p08_2.png` | B- | parts shelf: small cyan dots blink |
| `indoor_gym_back_sw_p02_2.png` | B- | treadmill: console display only |
| `indoor_gym_back_sw_p03_2.png` | B- | rack: only foot lights |
| `indoor_gym_back_sw_p04_2.png` | B- | lockers: cyan handle strips only |
| `indoor_gym_back_sw_p06_2.png` | B- | water cooler: jug not lit; tiny lights only |
| `indoor_gym_back_sw_p08_2.png` | B- | mirror: thin edge light only |
| `indoor_gym_p03_2.png` | B- | treadmill: console display only |
| `indoor_gym_p04_2.png` | B- | rack: only foot lights |
| `indoor_gym_p05_2.png` | B- | lockers: cyan handle strips only |
| `indoor_gym_p06_2.png` | B- | water cooler: jug not lit; tiny lights only |
| `indoor_gym_p08_2.png` | B- | mirror: thin edge light only |
| `indoor_gym_upgraded_p04_2.png` | B- | rack: only a few foot lights |
| `indoor_gym_upgraded_p05_2.png` | B- | lockers: tiny lock lights only |
| `indoor_kitchen_back_sw_p01.png` | B- | fridge: handle light only |
| `indoor_kitchen_back_sw_p02.png` | B- | stove: oven display only |
| `indoor_kitchen_back_sw_p03.png` | B- | counter: small blue display only |
| `indoor_kitchen_p01.png` | B- | fridge: handle light only |
| `indoor_kitchen_p02.png` | B- | stove: oven display only |
| `indoor_kitchen_p03.png` | B- | counter: small blue display only |
| `indoor_kitchen_p08.png` | B- | water dispenser: tap lights only |
| `indoor_kitchen_p10.png` | B- | wall screen (blank/off): footer lights only |
| `indoor_kitchen_upgraded_p03.png` | B- | counter: small blue display only |
| `indoor_lab_back_sw_p01_2.png` | B- | lab desk: flask glows blink only |
| `indoor_lab_back_sw_p03_2.png` | B- | med bed: base lights only |
| `indoor_lab_back_sw_p08.png` | B- | lab stool: stem light only |
| `indoor_lab_back_sw_p09.png` | B- | monitor (back): few LEDs |
| `indoor_lab_p01_2.png` | B- | lab desk: flask glows blink only |
| `indoor_lab_p02_2.png` | B- | med bed: base lights only |
| `indoor_lab_p07_2.png` | B- | biohazard locker: cyan LEDs only |
| `indoor_lab_upgraded_back_sw_p02_2.png` | B- | bed: thin base lights only |
| `indoor_lab_upgraded_back_sw_p03.png` | B- | generator: side LEDs only |
| `indoor_lab_upgraded_back_sw_p07.png` | B- | generator: side LEDs only |
| `indoor_lab_upgraded_back_sw_p09.png` | B- | generator: side LEDs only |
| `indoor_lab_upgraded_p02_2.png` | B- | bed: thin base lights only |
| `indoor_laundry_p01_2.png` | B- | washer: only base strip light |
| `indoor_laundry_p02_2.png` | B- | washer: control LEDs only |
| `indoor_laundry_p07_2.png` | B- | iron: one small light |
| `indoor_living_back_sw_p06_2.png` | B- | hanging gear: small lights only |
| `indoor_living_back_sw_p07_2.png` | B- | cabinet: small screen only |
| `indoor_living_back_sw_p09.png` | B- | shelf: one lit box screen |
| `indoor_living_p06_2.png` | B- | gear rack: tiny lights only |
| `indoor_living_p07_2.png` | B- | cabinet: small screen only |
| `indoor_living_p08_2.png` | B- | shelf: one lit box screen |
| `indoor_living_upgraded_p02_2.png` | B- | locker: few small lights |
| `indoor_living_upgraded_p06_2.png` | B- | hanging gear: small lights only |
| `indoor_living_upgraded_p07_2.png` | B- | cabinet: few small lights |
| `indoor_living_upgraded_p08_2.png` | B- | shelf: tiny lights only |
| `indoor_lounge_p04_2.png` | B- | coffee table: tiny tablet glow |
| `indoor_lounge_p05_2.png` | B- | media box: one strip light |
| `indoor_lounge_p09_2.png` | B- | cabinet: few small lights |
| `indoor_lounge_upgraded_p05_2.png` | B- | box: one strip light |
| `indoor_lounge_upgraded_p06_2.png` | B- | bookshelf: few small lights, spines are paint |
| `indoor_lounge_upgraded_p10_2.png` | B- | beanbag: thin piping lights only |
| `indoor_medbay_back_sw_p09_2.png` | B- | medical monitor: tiny gauges only |
| `indoor_medbay_p07_2.png` | B- | medical monitor: tiny gauges only |
| `indoor_medbay_upgraded_p03_2.png` | B- | gas tanks: clasp lights only |
| `indoor_medbay_upgraded_p06_2.png` | B- | vault: few small lights |
| `indoor_medbay_upgraded_p08_2.png` | B- | medical monitor: tiny gauges only |
| `indoor_observation_p02_2.png` | B- | binocular stand: lens glint + base light |
| `indoor_observation_p08.png` | B- | searchlight: base LEDs only (white lamp face can't brighten) |
| `indoor_observation_p09.png` | B- | map table: faint glints only |
| `indoor_power_back_sw_p01_2.png` | B- | generator: small cyan light only |
| `indoor_power_back_sw_p02_2.png` | B- | power cube: thin cyan seams pulse |
| `indoor_power_back_sw_p03_2.png` | B- | transformer: cable glow pulse only |
| `indoor_power_back_sw_p05_2.png` | B- | cable spool: clamp light only |
| `indoor_power_back_sw_p06_2.png` | B- | server cabinet: LEDs blink only |
| `indoor_power_back_sw_p07_2.png` | B- | AC unit: side light only |
| `indoor_power_back_sw_p08_2.png` | B- | battery block: thin seam lights only |
| `indoor_power_back_sw_p10_2.png` | B- | floor plate: edge lights only |
| `indoor_power_p01_2.png` | B- | generator: small cyan light only |
| `indoor_power_p02_2.png` | B- | power cube: thin seam lights only |
| `indoor_power_p03_2.png` | B- | generator: thin side lights only |
| `indoor_power_p05_2.png` | B- | cable spool: clamp light only |
| `indoor_power_p07_2.png` | B- | battery block: thin seam lights only |
| `indoor_power_p08_2.png` | B- | power cabinet: one small screen |
| `indoor_power_p10_2.png` | B- | floor plate: edge lights only |
| `indoor_power_upgraded_p10_2.png` | B- | floor plate: edge lights only |
| `indoor_security_back_sw_p02_2.png` | B- | desk: one small screen |
| `indoor_security_back_sw_p03_2.png` | B- | security camera: lens glint only |
| `indoor_security_back_sw_p04_2.png` | B- | barrier post: LED only |
| `indoor_security_back_sw_p05_2.png` | B- | pillar: one small screen |
| `indoor_security_back_sw_p06_2.png` | B- | safe: keypad blink only |
| `indoor_security_back_sw_p07_2.png` | B- | turnstile: base light only |
| `indoor_security_back_sw_p09_2.png` | B- | fuse panel: small cyan lights only |
| `indoor_security_p02_2.png` | B- | security camera: lens glint only |
| `indoor_security_p03_2.png` | B- | desk: one small screen |
| `indoor_security_p04_2.png` | B- | barrier post: LED only |
| `indoor_security_p05_2.png` | B- | pillar: one small screen |
| `indoor_security_p06_2.png` | B- | safe: keypad blink only |
| `indoor_security_p07_2.png` | B- | turnstile: base light only |
| `indoor_security_p09_2.png` | B- | fuse panel: small cyan lights only |
| `indoor_security_upgraded_p02_2.png` | B- | security camera: lens glint only |
| `indoor_security_upgraded_p05_2.png` | B- | barrier post: LEDs only |
| `indoor_server_back_sw_p05_2.png` | B- | junction box: few lights |
| `indoor_server_back_sw_p06_2.png` | B- | cable unit: cable pulse only |
| `indoor_server_p05_2.png` | B- | fan unit: vent lights only (fan face is angled, spin not clean) |
| `indoor_server_upgraded_p05_2.png` | B- | server box: thin vent lights; fan blades painted |
| `indoor_server_upgraded_p07_2.png` | B- | floor plate: faint edge lights |
| `indoor_set1_back_sw_p02.png` | B- | chair: base light only |
| `indoor_set1_back_sw_p04.png` | B- | locker: small LEDs only |
| `indoor_set1_back_sw_p05.png` | B- | cabinet: small display only |
| `indoor_set1_back_sw_p06.png` | B- | terminal crate: side lights only |
| `indoor_set1_back_sw_p07.png` | B- | crate: small LEDs only |
| `indoor_set1_back_sw_p08.png` | B- | storage shelf: jar/box lights blink only |
| `indoor_set1_upgraded_p02.png` | B- | chair: base light only |
| `indoor_set1_upgraded_p04.png` | B- | locker: two small LEDs only |
| `indoor_set1_upgraded_p07.png` | B- | crate: small LEDs only |
| `indoor_set1_upgraded_p09.png` | B- | storage shelf: jar/box lights blink only |
| `indoor_set1_variants_p02_2.png` | B- | chair: base light only |
| `indoor_set1_variants_p05.png` | B- | suit locker: small screen + LEDs |
| `indoor_set1_variants_p06.png` | B- | suit locker: small LEDs only |
| `indoor_set1_variants_p08.png` | B- | crate: small LEDs only |
| `indoor_set1_variants_p10.png` | B- | cable wall: tiny LEDs only |
| `indoor_set1_variants_p11.png` | B- | storage shelf: jar/box lights blink only |
| `indoor_set1_variants_p12.png` | B- | crate: small LEDs only |
| `indoor_set2_back_sw_p01_2.png` | B- | bunk bed: thin underglow only |
| `indoor_set2_back_sw_p02_2.png` | B- | wall rack: small lights only |
| `indoor_set2_back_sw_p04_2.png` | B- | vent panel: small cyan lights blink (grille not animated) |
| `indoor_set2_back_sw_p07_2.png` | B- | pipe elbow: cyan ring lights only |
| `indoor_set2_back_sw_p08_2.png` | B- | security camera: LEDs only |
| `indoor_set2_back_sw_p09_2.png` | B- | fridge: LEDs only |
| `indoor_set2_back_sw_p10_2.png` | B- | floor pad: corner LEDs only |
| `indoor_set2_p01_2.png` | B- | bunk bed: thin underglow only |
| `indoor_set2_p02_2.png` | B- | wall rack: small lights only |
| `indoor_set2_p04_2.png` | B- | vent panel: small cyan lights blink (grille not animated) |
| `indoor_set2_p07_2.png` | B- | pipe elbow: cyan ring lights only |
| `indoor_set2_p08_2.png` | B- | security camera: LEDs only |
| `indoor_set2_p09_2.png` | B- | fridge: LEDs only |
| `indoor_set2_p10_2.png` | B- | floor pad: corner LEDs only |
| `indoor_set2_upgraded_p01_2.png` | B- | bunk bed: thin underglow only |
| `indoor_set2_upgraded_p02_2.png` | B- | wall rack: small lights only |
| `indoor_set2_upgraded_p05_2.png` | B- | vent panel: small cyan lights blink (grille not animated) |
| `indoor_set2_upgraded_p08_2.png` | B- | locker: thin cyan strips pulse |
| `indoor_set2_upgraded_p10_2.png` | B- | floor plate: corner lights only |
| `indoor_set2_variants_p01_2.png` | B- | bunk bed: thin underglow only |
| `indoor_set2_variants_p02_2.png` | B- | wall rack: small lights only |
| `indoor_set2_variants_p07_2.png` | B- | pipe: thin band light |
| `indoor_set2_variants_p08_2.png` | B- | security camera: lens ring light only |
| `indoor_set2_variants_p09_2.png` | B- | fridge: LEDs only |
| `indoor_set2_variants_p10_2.png` | B- | floor pad: corner LEDs only |
| `indoor_storage_back_sw_p04_2.png` | B- | barrel: cyan gauge strip only |
| `indoor_storage_back_sw_p08_2.png` | B- | tool chest: one drawer light |
| `indoor_storage_p04_2.png` | B- | barrel: cyan gauge strip only |
| `indoor_storage_p08_2.png` | B- | tool chest: one side light |
| `indoor_storage_upgraded_p03.png` | B- | neon-strapped cargo: glowing straps scan/pulse |
| `indoor_storage_upgraded_p04.png` | B- | forklift: one small glowing crate |
| `indoor_utility_back_sw_p03_2.png` | B- | breaker panel: only tiny button specks |
| `indoor_utility_back_sw_p04_2.png` | B- | fuse panel: small LEDs only |
| `indoor_utility_p02_2.png` | B- | breaker panel: only tiny button specks |
| `indoor_utility_upgraded_p04_2.png` | B- | fuse panel: small LEDs only |
| `indoor_utility_upgraded_p09_2.png` | B- | lit step ladder: steps glow ripple (subtle) |
| `distillery_001.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `drive_hub_unkeyed_hub_3sdto.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_airlock_p04.png` | C | suit lockers: helmet visor glints are paint |
| `indoor_airlock_p05.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_airlock_upgraded_p04.png` | C | suit lockers: helmet visor glints are paint |
| `indoor_armory_back_sw_p01_2.png` | C | open cabinet: nothing lit |
| `indoor_armory_back_sw_p02_2.png` | C | crate labels read as lights -> would flicker the paint |
| `indoor_armory_back_sw_p03_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_armory_back_sw_p04_2.png` | C | lockers: nothing readable lit |
| `indoor_armory_back_sw_p05_2.png` | C | training dummy: nothing lit |
| `indoor_armory_back_sw_p07_2.png` | C | gun rack: metal glints read as lights |
| `indoor_armory_back_sw_p09.png` | C | boot rack: nothing truly lit, only paint glints |
| `indoor_armory_back_sw_p10.png` | C | bench: nothing lit |
| `indoor_armory_p01_2.png` | C | gun locker: metal glints read as lights |
| `indoor_armory_p02_2.png` | C | grey crate labels read as lights -> would flicker the paint |
| `indoor_armory_p03_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_armory_p04_2.png` | C | lockers: nothing readable lit |
| `indoor_armory_p05_2.png` | C | training dummy: nothing lit |
| `indoor_armory_p06_2.png` | C | crate: nothing readable lit |
| `indoor_armory_p07_2.png` | C | gun rack: metal glints read as lights |
| `indoor_armory_p09.png` | C | boot rack: nothing truly lit, only paint glints |
| `indoor_armory_p10.png` | C | bench: nothing lit |
| `indoor_armory_upgraded_back_sw_p01_2.png` | C | multi-piece sheet (several parts on one canvas), tiny lights |
| `indoor_armory_upgraded_back_sw_p02_2.png` | C | crate labels read as lights -> would flicker the paint |
| `indoor_armory_upgraded_back_sw_p03_2.png` | C | armour stand: paint glints only |
| `indoor_armory_upgraded_back_sw_p04_2.png` | C | training dummy: paint glints only |
| `indoor_armory_upgraded_back_sw_p06_2.png` | C | backpack: nothing readable lit |
| `indoor_armory_upgraded_back_sw_p07.png` | C | boot rack: nothing truly lit, only paint glints |
| `indoor_armory_upgraded_back_sw_p08.png` | C | bench: nothing lit |
| `indoor_armory_upgraded_p02_2.png` | C | crate labels read as lights -> would flicker the paint |
| `indoor_armory_upgraded_p04_2.png` | C | training dummy: paint glints only |
| `indoor_armory_upgraded_p07.png` | C | boot rack: nothing truly lit, only paint glints |
| `indoor_armory_upgraded_p08.png` | C | bench: nothing lit |
| `indoor_armory_workshop_p02_2.png` | C | gun bench: metal glints only |
| `indoor_armory_workshop_p05_2.png` | C | blueprint board: blue lines are ink, not light |
| `indoor_armory_workshop_p07_2.png` | C | target stand: nothing lit |
| `indoor_armory_workshop_p09_2.png` | C | barrel bands are paint |
| `indoor_base_p05.png` | C | medical locker: cross is paint |
| `indoor_bathroom_back_sw_p05_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_bathroom_back_sw_p10_2.png` | C | wall lamp face is near-white; only a 2px LED changes |
| `indoor_bathroom_p05_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_bathroom_p10_2.png` | C | wall lamp face is near-white; only a 2px LED changes |
| `indoor_bathroom_upgraded_p10_2.png` | C | UV lamp face is already near-white; no effect reads without recolouring |
| `indoor_briefing_back_sw_p01.png` | C | floor pallet: nothing lit |
| `indoor_briefing_back_sw_p08.png` | C | filing cabinet: nothing readable lit |
| `indoor_briefing_p01.png` | C | floor pallet: nothing lit |
| `indoor_briefing_p08.png` | C | filing cabinet: nothing readable lit |
| `indoor_brig_p02_2.png` | C | shackle panel: LEDs too tiny to read |
| `indoor_brig_p03_2.png` | C | cell bunk: nothing lit |
| `indoor_cantina_back_sw_p01_2.png` | C | bottle glints read as lights (glass paint), light bar not caught |
| `indoor_cantina_back_sw_p03_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_cantina_back_sw_p04_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_cantina_back_sw_p06_2.png` | C | dartboard rings are paint |
| `indoor_cantina_back_sw_p08_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_cantina_back_sw_p10_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_cantina_p03_2.png` | C | bar counter: nothing lit |
| `indoor_cantina_p04_2.png` | C | bar stool: nothing lit |
| `indoor_cantina_p06_2.png` | C | dartboard rings are paint |
| `indoor_cantina_p07_2.png` | C | sofa: nothing lit |
| `indoor_cantina_p10_2.png` | C | bin: nothing lit |
| `indoor_cantina_upgraded_p04_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_command_back_sw_p01_2.png` | C | chair: nothing readable lit |
| `indoor_command_upgraded_back_sw_p06_2.png` | C | wall frame: nothing readable lit |
| `indoor_corridor_back_sw_p03_2.png` | C | extinguisher: gauge too tiny to read |
| `indoor_corridor_p03_2.png` | C | extinguisher: gauge too tiny to read |
| `indoor_corridor_upgraded_p03_2.png` | C | extinguisher: gauge too tiny to read |
| `indoor_garage_p01_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_garage_p04_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_garage_p06_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_garage_p10_2.png` | C | hose reel: nothing lit |
| `indoor_gym_back_sw_p01_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_gym_back_sw_p05_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_gym_back_sw_p07_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_gym_back_sw_p09_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_gym_p01_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_gym_p02_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_gym_p07_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_gym_p09_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_gym_upgraded_p07_2.png` | C | cyan dumbbell ends are paint |
| `indoor_kitchen_back_sw_p04.png` | C | blue drawer stripes are paint |
| `indoor_kitchen_p04.png` | C | blue drawer stripes are paint |
| `indoor_kitchen_p05.png` | C | mess table: food tray glints read as lights |
| `indoor_kitchen_p06.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_kitchen_p09.png` | C | coloured box lids are paint |
| `indoor_lab_back_sw_p07.png` | C | locker: nothing lit |
| `indoor_lab_p08.png` | C | lab stool: nothing readable lit |
| `indoor_lab_upgraded_back_sw_p08.png` | C | lab stool: nothing readable lit |
| `indoor_lab_upgraded_p07.png` | C | biohazard locker: nothing readable lit |
| `indoor_lab_upgraded_p08.png` | C | lab stool: nothing readable lit |
| `indoor_laundry_p03_2.png` | C | bottle colours are paint |
| `indoor_laundry_p04_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_laundry_p05_2.png` | C | clothes are paint |
| `indoor_laundry_p08_2.png` | C | white fan hub is paint, not light |
| `indoor_laundry_p09_2.png` | C | hamper label is paint |
| `indoor_laundry_p10_2.png` | C | clothes colours are paint -> would recolour fabric |
| `indoor_living_back_sw_p01_2.png` | C | bunk bed: nothing lit |
| `indoor_living_back_sw_p02_2.png` | C | locker: nothing lit |
| `indoor_living_back_sw_p03_2.png` | C | office chair: nothing lit |
| `indoor_living_back_sw_p05_2.png` | C | trunk: nothing lit |
| `indoor_living_back_sw_p10.png` | C | curtain rail: nothing lit |
| `indoor_living_p01_2.png` | C | bunk bed: nothing lit |
| `indoor_living_p02_2.png` | C | locker: nothing lit |
| `indoor_living_p03_2.png` | C | office chair: nothing lit |
| `indoor_living_p05_2.png` | C | trunk: nothing lit |
| `indoor_living_p09_2.png` | C | curtain rail: nothing lit |
| `indoor_living_upgraded_p01_2.png` | C | bunk bed: nothing readable lit |
| `indoor_living_upgraded_p03_2.png` | C | office chair: nothing lit |
| `indoor_living_upgraded_p09.png` | C | curtain rail: nothing lit |
| `indoor_lounge_p01_2.png` | C | sofa base stripe is paint |
| `indoor_lounge_p03_2.png` | C | teal plant leaves are paint, not light |
| `indoor_lounge_p06_2.png` | C | magazine covers are paint |
| `indoor_lounge_p07_2.png` | C | floor lamp is painted off; nothing lit |
| `indoor_lounge_p08_2.png` | C | wall art: coloured shapes are paint |
| `indoor_lounge_p10_2.png` | C | beanbag: nothing lit, fabric highlight only |
| `indoor_lounge_upgraded_p03_2.png` | C | teal plant leaves are paint |
| `indoor_medbay_back_sw_p02_2.png` | C | gas cylinder band is paint |
| `indoor_medbay_back_sw_p04_2.png` | C | cyan drawer fronts are paint |
| `indoor_medbay_back_sw_p05_2.png` | C | cyan bed pads are paint |
| `indoor_medbay_back_sw_p06_2.png` | C | safe: nothing readable lit |
| `indoor_medbay_back_sw_p08_2.png` | C | cyan blanket is paint |
| `indoor_medbay_back_sw_p10_2.png` | C | med kit: cyan cross is paint |
| `indoor_medbay_p02_2.png` | C | gas cylinder band is paint |
| `indoor_medbay_p04_2.png` | C | cyan drawer fronts are paint |
| `indoor_medbay_p05_2.png` | C | cyan bed pads are paint |
| `indoor_medbay_p06_2.png` | C | safe: nothing readable lit |
| `indoor_medbay_p09_2.png` | C | cyan blanket is paint |
| `indoor_medbay_p10_2.png` | C | med kit: cyan cross is paint |
| `indoor_medbay_upgraded_p01_2.png` | C | cyan is cushion paint |
| `indoor_medbay_upgraded_p05_2.png` | C | cyan drawer fronts are paint |
| `indoor_medbay_upgraded_p07_2.png` | C | cyan is mattress paint, not light -> would pulse the body |
| `indoor_medbay_upgraded_p10_2.png` | C | medkit cross is paint |
| `indoor_observation_p04_2.png` | C | chair: base lights too tiny to read |
| `indoor_observation_p10.png` | C | vent grille: nothing readable lit |
| `indoor_power_back_sw_p04_2.png` | C | cabinet: nothing readable lit |
| `indoor_power_p06_2.png` | C | AC unit: nothing readable lit |
| `indoor_server_back_sw_p07_2.png` | C | floor tile: light cut off at canvas edge |
| `indoor_server_p07_2.png` | C | floor tile: light cut off at canvas edge |
| `indoor_set1_back_sw_p01.png` | C | desk monitors are painted off; nothing lit |
| `indoor_set1_back_sw_p03.png` | C | wall panel: nothing readable lit |
| `indoor_set1_variants_p13.png` | C | crate: LEDs too tiny to read |
| `indoor_set2_back_sw_p03_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_set2_p03_2.png` | C | crate: nothing readable lit |
| `indoor_set2_variants_p03_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_storage_back_sw_p01_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_storage_back_sw_p02_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_storage_back_sw_p03_2.png` | C | blue shelf posts are paint |
| `indoor_storage_back_sw_p05_2.png` | C | forklift: nothing readable lit |
| `indoor_storage_back_sw_p06_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_storage_back_sw_p07_2.png` | C | trunk: nothing lit |
| `indoor_storage_back_sw_p10.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_storage_p01_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_storage_p02_2.png` | C | blue shelf posts are paint |
| `indoor_storage_p03_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_storage_p05_2.png` | C | forklift: nothing readable lit |
| `indoor_storage_p06_2.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_storage_p07_2.png` | C | trunk: nothing lit |
| `indoor_storage_p10.png` | C | nothing lit: plain painted prop (no screens/LEDs/glow) |
| `indoor_utility_back_sw_p01_2.png` | C | blue bins are paint |
| `indoor_utility_back_sw_p02_2.png` | C | wrench grip colour is paint |
| `indoor_utility_back_sw_p05_2.png` | C | workbench item colours are paint |
| `indoor_utility_back_sw_p06_2.png` | C | wrench grip colour is paint |
| `indoor_utility_back_sw_p07_2.png` | C | wrench grip colour is paint |
| `indoor_utility_back_sw_p08_2.png` | C | janitor cart colours are paint |
| `indoor_utility_back_sw_p09_2.png` | C | step ladder: nothing lit |
| `indoor_utility_back_sw_p10_2.png` | C | drum: nothing lit |
| `indoor_utility_back_sw_p11.png` | C | parts bin: blue items are paint |
| `indoor_utility_back_sw_p12.png` | C | tool colours are paint |
| `indoor_utility_p01_2.png` | C | blue bins are paint |
| `indoor_utility_p03_2.png` | C | fuse panel: nothing readable lit |
| `indoor_utility_p04_2.png` | C | workbench item colours are paint |
| `indoor_utility_p05_2.png` | C | wrench grips are paint |
| `indoor_utility_p06_2.png` | C | wrench grip colour is paint |
| `indoor_utility_p07_2.png` | C | janitor cart colours are paint |
| `indoor_utility_p08_2.png` | C | step ladder: nothing lit |
| `indoor_utility_p09_2.png` | C | drum: nothing lit |
| `indoor_utility_p10_2.png` | C | parts bin: blue items are paint |
| `indoor_utility_p11.png` | C | tool colours are paint |
| `indoor_utility_upgraded_p02_2.png` | C | wrench grip colour is paint |
| `indoor_utility_upgraded_p05_2.png` | C | workbench item colours are paint |
| `indoor_utility_upgraded_p06_2.png` | C | wrench grip colour is paint |
| `indoor_utility_upgraded_p07_2.png` | C | wrench grip colour is paint |
| `indoor_utility_upgraded_p08_2.png` | C | janitor cart: bucket/bottle colours are paint |
| `indoor_utility_upgraded_p10_2.png` | C | tool colours are paint |
| `indoor_utility_upgraded_p12.png` | C | parts bin: blue items are paint |

Also skipped: 74 multi-prop overview sheets (>1000 px wide, e.g. `indoor_airlock_2.png`) — they are catalogue sheets, not placeable single props.


## QA
* GIFs: `samples/ui/qa_interior_props/ip_<id>.gif` (2x, on a dark floor colour, global 256-colour palette so colours band slightly; the PNG strips are exact).
* Contact sheet: `samples/ui/qa_interior_props.png` (frame 0 + every-pixel-touched map per prop).
* Vignette: `samples/ui/qa_interior_props_vignette.gif` — 10 animated props in a room on Brian's `floor_riveted_deck_128` with a `floor_cyan_inlay_128` walkway
  (tiles from `assets/tiles/battle_pack/03_floor_tiles`, shown 2x so one tile ~ one 1x1 prop footprint), props at native art size.

## Notes / limits
* Effects are deliberately subtle (shade steps of the art's own lit colours); at small in-game zoom single-pixel LEDs average out — screens, holograms, bubbles, radar and pulses read best.
* Painted-off screens (black desk monitors) and near-white lamp faces were left alone: there is no lit colour to animate without recolouring.
* Warm/orange glows are only treated as light when tagged per prop (capsule cores, beacon domes, signs, glowing coils/straps); orange trim stays paint.
* Source art is read-only; built from box copies of `public/assets/library/interior_structures/pieces/` staged via the handoff folder.
