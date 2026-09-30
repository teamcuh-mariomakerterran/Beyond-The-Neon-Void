# Classes
36 playable classes. Cyberpunk takes on Final Fantasy Tactics jobs, plus originals. Source of truth: `data/classes.json` + `data/abilities.json` (the Neon Forge editor will edit these).
Unlocking works like FFT: reach class levels in prerequisite classes (class XP comes from battles). Secret classes also need a story flag. Abilities are learned at terminals with **microchips** — except Blue Magic, which the Bluescreen Mage only learns by getting hit by it.
| FFT inspiration | Our class |
|---|---|
| Squire / Warrior | Chrome Warrior |
| White Mage | Whitelight Medic |
| Black Mage | Blackcode Mage |
| Thief | Signal Thief |
| Archer | Laser Archer (laser guns) |
| Chemist | Stim Chemist |
| Monk | Iron Monk |
| Ninja | Neon Ninja |
| Samurai | Street Samurai |
| Knight | Digital Knight |
| Red Mage | Redline Mage |
| Blue Mage | Bluescreen Mage |
| Beast Master | Droid Master (builds Assault / Bulwark / Medic / Volt droids) |
| Tinker | Scrap Tinker |
| Time Mage | Timeslip Mage |
| Geomancer | Grid Geomancer |
| Summoner | Holo Summoner, Daemon Caller (FF-style summons + hidden data disks) |
| Bard / Dancer | Synth Bard / Holo Dancer |
| Dragoon | Jumpjet Dragoon |
| Dark Knight | Void Knight |
| Berserker | Stim Berserker |
| Oracle | Static Oracle |
| Assassin | Ghost Assassin |
| Mime | Echo Mime (secret) |
| Necromancer | Digimancer (secret) |

## Tier 1 — Starters
### Chrome Warrior — Melee
Shift-line muscle with chrome-plated forearms. Every crew starts with one.

- **Unlock:** Available from the start
- **Weapons:** sword, knuckles (specialty: sword)
- **Innate:** Rally Cry, Chrome Cleave
- **Learnable:** Throw Scrap (1 chips), Brace (1 chips), Second Wind (2 chips), Gutbuster (2 chips)
### Whitelight Medic — Support
Tender Circuit dropout with a glowing rod and a steady hand.

- **Unlock:** Available from the start
- **Weapons:** rod, injector (specialty: rod)
- **Innate:** Mend Light, Purge Code
- **Learnable:** Mend Field (2 chips), Regen Patch (1 chips), Aegis Light (1 chips), Holy Static (3 chips)
### Blackcode Mage — Ranged
Writes spells in forbidden syntax. Black-market coder with a pyromaniac streak.

- **Unlock:** Available from the start
- **Weapons:** rod, staff (specialty: staff)
- **Innate:** Plasma Bolt, Cryo Bolt
- **Learnable:** Volt Bolt (1 chips), Plasma Storm (3 chips), Cryo Lattice (3 chips), Thunderhead (3 chips)
### Signal Thief — Utility
Everyone in the district has lost something to a Signal Thief. Usually twice.

- **Unlock:** Available from the start
- **Weapons:** knife (specialty: knife)
- **Innate:** Lift Coins, Shadow Step
- **Learnable:** Steal Chip (2 chips), Backstab (1 chips), Inventory Loss (1 chips), Smoke Jammer (2 chips)
### Laser Archer — Ranged
Salvaged mining lasers, re-tuned for people. Stay high, stay far.

- **Unlock:** Available from the start
- **Weapons:** laser_gun (specialty: laser_gun)
- **Innate:** Charge Shot, Aim Assist
- **Learnable:** Pinning Beam (1 chips), Lance Beam (2 chips), Scatter Prism (2 chips)
### Stim Chemist — Support
Brews stims in the bar's back room. Half medicine, half moonshine.

- **Unlock:** Available from the start
- **Weapons:** injector, knife (specialty: injector)
- **Innate:** Throw Stim, Detox Dart
- **Learnable:** Phoenix Stim (3 chips), Ether Shot (1 chips), Brew Bomb (2 chips), Liquid Courage (1 chips)

## Tier 2 — Advanced
### Iron Monk — Melee
Meditates in the boiler room between 15-hour shifts. Hands like pistons.

- **Unlock:** Chrome Warrior 2
- **Weapons:** knuckles (specialty: knuckles)
- **Innate:** Piston Palm, Chakra Reboot
- **Learnable:** Shockwave Fist (2 chips), Earth Slam (2 chips), Wave Fist (1 chips)
### Neon Ninja — Utility
Moves between the neon signs like a glitch in the feed.

- **Unlock:** Signal Thief 3, Laser Archer 2
- **Weapons:** knife, katana (specialty: knife)
- **Innate:** Twin Strike, Throw Star
- **Learnable:** Shadow Clone (2 chips), Smoke Vault (2 chips), Neon Lotus (3 chips)
### Street Samurai — Melee
Honor is expensive. The katana was cheaper.

- **Unlock:** Chrome Warrior 3, Iron Monk 2
- **Weapons:** katana (specialty: katana)
- **Innate:** Neon Slash, Iai Strike
- **Learnable:** Ion Edge (2 chips), Blade Dance (3 chips), Bushido Code (1 chips)
### Digital Knight — Tank
A knight's oath burned into firmware. Nobody remembers who wrote it.

- **Unlock:** Chrome Warrior 3
- **Weapons:** sword, shield (specialty: sword)
- **Innate:** Firewall Guard, Shield Bash
- **Learnable:** Armor Break (2 chips), Power Break (2 chips), Hold the Line (3 chips)
### Redline Mage — Special
Jack of both codes, master of redlining the hardware.

- **Unlock:** Whitelight Medic 2, Blackcode Mage 2
- **Weapons:** sword, rod (specialty: sword)
- **Innate:** Dualcast, Red Spark
- **Learnable:** Red Mend (1 chips), Red Frost (1 chips), Spellblade (2 chips)
### Bluescreen Mage — Special
Lets enemy code crash into them — and keeps a copy. Learns abilities by getting hit.

- **Unlock:** Redline Mage 2
- **Weapons:** rod, sword (specialty: rod)
- **Innate:** Scan Signature
- **Learnable:** Arc Lash (blue magic), Bad Sector (blue magic), Essence Leech (blue magic), Sonic Screech (blue magic), Self Repair (blue magic), Crown Hymn (blue magic)
### Gunslinger — Ranged
Chrome revolver, bad attitude, great hat.

- **Unlock:** Laser Archer 3
- **Weapons:** pistol (specialty: pistol)
- **Innate:** Quick Draw, Plasma Burst
- **Learnable:** Ricochet (2 chips), Leg Shot (1 chips), Fan the Hammer (3 chips)
### Net Hacker — Support
Lives in the wires under the bar. Pays rent in stolen bandwidth.

- **Unlock:** Blackcode Mage 2, Stim Chemist 2
- **Weapons:** cyberdeck (specialty: cyberdeck)
- **Innate:** Data Spike, System Override
- **Learnable:** Backdoor (3 chips), Clarity Edit (2 chips), Firewall Up (1 chips)
### Scrap Tinker — Utility
Can fix anything with parts from the bar's jukebox. Has fixed the jukebox 11 times.

- **Unlock:** Stim Chemist 3
- **Weapons:** wrench (specialty: wrench)
- **Innate:** Shock Mine, Patch Job
- **Learnable:** Scrap Grenade (2 chips), Jury Rig (1 chips), Deploy Turret (3 chips)
### Droid Master — Special
The Beast Master of the Neon Void: builds a menagerie of droids, each with its own job.

- **Unlock:** Scrap Tinker 3, Net Hacker 2
- **Weapons:** wrench, controller (specialty: controller)
- **Innate:** Build: Assault Droid, Build: Medic Droid
- **Learnable:** Build: Bulwark Droid (2 chips), Build: Volt Droid (3 chips), Overclock (2 chips)
### Timeslip Mage — Support
Swears the bar's clock is four minutes fast. It is.

- **Unlock:** Blackcode Mage 3, Whitelight Medic 2
- **Weapons:** staff, rod (specialty: staff)
- **Innate:** Haste, Slow
- **Learnable:** Stop (3 chips), Quicken (3 chips), Gravity Crush (2 chips)
### Grid Geomancer — Special
Reads the city's ley-lines: power cables, coolant pipes, old blood.

- **Unlock:** Iron Monk 2, Blackcode Mage 2
- **Weapons:** sword, staff (specialty: sword)
- **Innate:** Geomancy
- **Learnable:** Terraform Pulse (2 chips), Fault Tremor (2 chips), Ley Feedback (2 chips)
### Holo Summoner — Support
Pirates the city's billboard feeds and turns ads into gods.

- **Unlock:** Timeslip Mage 2, Whitelight Medic 3
- **Weapons:** rod, staff (specialty: rod)
- **Innate:** Summon: Leviathan Feed
- **Learnable:** Summon: Seraph Ad (3 chips), Summon: Iron Titan (4 chips), Summon: Static Wyrm (4 chips)
### Daemon Caller — Special
Runs pirated daemons off a stack of cracked data disks. The daemons are loyal, enormous and, legally speaking, malware. Collects disks from every crate, vent and toilet tank in the city.

- **Unlock:** Blackcode Mage 3, Signal Thief 2
- **Weapons:** rod, codex (specialty: codex)
- **Innate:** Call: EMBER.EXE (plasma, every enemy), Call: FROSTBYTE (cryo, one target, huge)
- **Learnable by class level:** Call: NURSE.BAK (Lv 2, 2 chips — crew heal + cleanse), Call: GOODBOY.DLL (Lv 3, 3 chips — electric, every enemy), Call: LULLABY.SCR (Lv 4, 3 chips — sleep / blind / poison on the enemy party)
- **Data-disk summons (0 chips, need the disk in your inventory):** Call: LEVIATHAN_NULL (void, one target), Call: THE LANDLORD (kinetic, every enemy), Call: SAINT UPTIME (big crew heal + cleanse + regen)

Summons are expensive (22–50 MP) charged casts. "Every enemy" calls target the caster's own tile with a
map-wide diamond, so they hit the whole enemy party and never friendlies; party calls hit the whole crew.

### Synth Bard — Support
Plays unregistered hymns on a keytar. Technically a crime.

- **Unlock:** Whitelight Medic 3, Signal Thief 2
- **Weapons:** synth (specialty: synth)
- **Innate:** Anthem of the Off-Key
- **Learnable:** Last Call Ballad (2 chips), Tempo Riff (3 chips), Feedback Squeal (1 chips)
### Holo Dancer — Utility
Headlines the only club the Doctrine hasn't shut down. Yet.

- **Unlock:** Signal Thief 3, Iron Monk 2
- **Weapons:** ribbon, knife (specialty: ribbon)
- **Innate:** Strobe Step
- **Learnable:** Heartbreak Waltz (2 chips), Slow Dance (3 chips), Ribbon Lash (1 chips)
### Jumpjet Dragoon — Melee
Jump pack stolen from an Iron Choir air-drop crate.

- **Unlock:** Digital Knight 2, Laser Archer 2
- **Weapons:** lance (specialty: lance)
- **Innate:** Jet Jump
- **Learnable:** Grapple Line (2 chips), High Ground (2 chips), Lance Thrust (1 chips)
### Void Knight — Tank
A Digital Knight whose firmware got corrupted. Hits harder for it.

- **Unlock:** Digital Knight 4, Blackcode Mage 3
- **Weapons:** heavy_blade (specialty: heavy_blade)
- **Innate:** Void Wave
- **Learnable:** Abyssal Aegis (2 chips), Sanguine Edge (3 chips), Dread Mark (2 chips)
### Stim Berserker — Melee
Chemist's worst customer.

- **Unlock:** Iron Monk 3, Stim Chemist 2
- **Weapons:** knuckles, heavy_blade (specialty: heavy_blade)
- **Innate:** Red Mist
- **Learnable:** Frenzy Slash (2 chips), Rampage (3 chips), Pain Dampener (1 chips)

## Tier 3 — Elite
### Cyber Sniper — Ranged
Rooftop-to-rooftop. Never misses twice.

- **Unlock:** Gunslinger 4, Neon Ninja 2
- **Weapons:** rifle (specialty: rifle)
- **Innate:** Neural Link Shot, Steady Aim
- **Learnable:** Piercing Round (3 chips), Suppressive Fire (2 chips), Headhunter (4 chips)
### Ghost Assassin — Melee
Nobody hires a Ghost. The Ghost finds you.

- **Unlock:** Neon Ninja 4, Net Hacker 3
- **Weapons:** knife, katana (specialty: knife)
- **Innate:** Death Mark, Ghost Cut
- **Learnable:** Nerve Toxin (2 chips), Vanishing Act (2 chips), Final Invoice (4 chips)
### Plasma Vanguard — Tank
A walking reactor with a grudge.

- **Unlock:** Digital Knight 5, Scrap Tinker 3
- **Weapons:** heavy_blade, shield (specialty: shield)
- **Innate:** Thermal Shield, Plasma Ram
- **Learnable:** Meltdown (3 chips), Bastion (3 chips)
### Static Oracle — Support
Hears the Psalter Spires' hymns backwards. Won't say what they say.

- **Unlock:** Timeslip Mage 3, Net Hacker 3
- **Weapons:** codex, rod (specialty: codex)
- **Innate:** Dead Channel, Crown Dream
- **Learnable:** Archive Blindness (2 chips), Prophecy Static (3 chips)
### Void Technician — Utility
Services the machines nobody admits exist.

- **Unlock:** Grid Geomancer 3, Holo Summoner 2
- **Weapons:** controller, staff (specialty: controller)
- **Innate:** Gravity Well, Void Rift
- **Learnable:** Event Horizon (3 chips), Null Field (2 chips)

## Secret classes
### Vector Knight — Melee
Momentum is a weapon. Physics is a suggestion.

- **Unlock:** Jumpjet Dragoon 4, Street Samurai 3 + story flag `secret_vector_knight`
- **Weapons:** lance, sword (specialty: lance)
- **Innate:** Kinetic Charge, Gravitational Pull
- **Learnable:** Elastic Inertia (2 chips), Repulsor Strike (3 chips)
### Chrono-Stitcher — Special
Sews the seven-second gap shut. Or open.

- **Unlock:** Timeslip Mage 5, Static Oracle 2 + story flag `secret_chrono_stitcher`
- **Weapons:** staff, codex (specialty: staff)
- **Innate:** Delay Thread, Stitch Turn
- **Learnable:** Rewind Position (3 chips), Seven Stolen Seconds (3 chips)
### Cartographer — Special
Redraws the map. The map agrees.

- **Unlock:** Grid Geomancer 5, Void Technician 2 + story flag `secret_cartographer`
- **Weapons:** staff, controller (specialty: staff)
- **Innate:** Draw Fault Line, Isolate Elevation
- **Learnable:** Sink Ground (2 chips), Warp Coordinates (4 chips), Neon Fire Trace (3 chips)
### Deck Stacker — Utility
Fights with a deck instead of a weapon. Every card: once per battle. Build the deck, not the gun.

- **Unlock:** Signal Thief 4, Synth Bard 2 + story flag `secret_deck_stacker`
- **Weapons:** deck (specialty: deck)
- **Innate:** Shuffle Up
- **Learnable:** House Edge (2 chips), 52-Card Pickup (2 chips)
### Echo Mime — Special
Never speaks. Never needs to. Copies whatever the crew just did.

- **Unlock:** Chrome Warrior 5, Whitelight Medic 5, Blackcode Mage 5, Laser Archer 5 + story flag `secret_echo_mime`
- **Weapons:** — (specialty: —)
- **Innate:** Echo
### Digimancer — Special
The villain's own art, stolen back. Raises the fallen as echoes — 'those who never arrived'.

- **Unlock:** Void Knight 4, Static Oracle 3 + story flag `secret_digimancer`
- **Weapons:** codex, staff (specialty: codex)
- **Innate:** Raise Echo, Essence Siphon
- **Learnable:** Grave Protocol (3 chips), Soul Tax (2 chips), Crown of the Dead (5 chips)

## Droids (built by the Droid Master)
- **Assault Droid** — buzzsaw melee, aggressive AI.
- **Bulwark Droid** — fortifies adjacent allies, body-checks.
- **Medic Droid** — single and area heals.
- **Volt Droid** — electric Arc Lash / Chain Lightning, resists electric, weak to cryo.

Max 2 active droids per Droid Master. All droids take 1.5x electric damage except the Volt.

## Data disks (Daemon Caller)
FF8/FF9-style hidden loot: disk-gated summons are only learnable once the matching **KEY** item is in the
inventory (`Ability.requires_item_id`; the disk item carries `teaches_ability_id`). Class-level gates use
`Ability.required_class_level`. Both are enforced in `ProgressionSystem.learn_ability`.

| Disk | Teaches | Where |
|---|---|---|
| `dsk_leviathan_null` | Call: LEVIATHAN_NULL | Neon Gutter back alley — behind the neon sign (prop `prop_neon_sign_disk`) |
| `dsk_the_landlord` | Call: THE LANDLORD | Supply Works dock — under the rubble (prop `prop_rubble_disk`) |
| `dsk_saint_uptime` | Call: SAINT UPTIME | Rare roll in the `loot_dispatch_salvage` table |

New statuses for the summons: **Malware Poisoning** (`poisoned`, 6% max HP per turn) and **Screensaver Mode**
(`asleep`, can't act or move for 2 turns). Any `cleanse` summon removes them.
