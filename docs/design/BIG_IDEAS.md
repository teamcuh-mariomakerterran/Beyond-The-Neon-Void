# Big Ideas — pushing the genre

The bar for this list: things tactics RPGs have rarely or never done, that grow out of *our* world (two truths, essence, a drunk found family, an unwinnable overseas war), and that our engine can actually support. Full research survey: `docs/research/GODOT_AND_TRPG_RESEARCH.md` (§B2 lists the genre gaps).

Each idea shows its **status**:
- **BUILT**: in the game now.
- **HOOKED**: the engine has the hooks, and it needs content or one system.
- **NEW**: needs a new system.

---

## Tier S: the ideas that define the game

### 1. The Lying HUD (Doctrine Overlay) · NEW, cheap
While a map's **Doctrine Relay** stands, the HUD reads state data:
- hit % and damage previews skew up to ±25% in the Doctrine's favour
- some enemies show up as "civilians"

Ways to see through it:
- Hackers can jack the relay.
- A unit carrying the `Clear Eyes` chip sees true numbers.
- Destroying the relay makes the HUD visibly *glitch back to the truth*.

This is "everything has two truths" as a mechanic, not a plot point.

- **Engine:** `DamageCalculator.forecast()` is already the single source the HUD reads. Adding an `InfoFilter` between them is a ~50-line change.
- **Default:** telegraphs stay truthful. Lying is a per-map state you can *see* is active.
- **Accessibility:** a toggle turns the lying off.

### 2. Essence Ledger: humanity as combat currency · HOOKED
- Every unit carries **Essence (0–100)**.
- Big abilities can be **overcast** by spending Essence for +50%. Digimancer echoes are fuelled by it.
- Essence only comes back through downtime at the Neon Gutter: drinking, talking, the jukebox.
- At 0 a crew member is **Hollowed**. They're AI-controlled next battle, and there's a redemption quest to bring them back.

The villain runs an essence factory, and you're running a small one inside yourself.

- **Engine:** the `essence` damage type, the `essence_bleed` status and Essence Shard materials already exist. Adding a stat on `UnitStats` plus an `overcast` flag on `Ability` gets us there.

### 3. Extraction Pods: a three-way choice mid-battle · HOOKED
Factory maps hold pods with people inside. For each one you pick:
- **Free** it: 2 turns, and you get a possible recruit.
- **Drain** it: instant full heal and a power spike, at a huge Essence and karma cost.
- **Ignore** it: the Digimancer boss gains a stack for every pod left full when the shift whistle blows.

This is a moral choice made *with your turn*, not in a dialogue menu.

- **Engine:** `InteractionTrigger` props, `EventBus`, win/lose conditions and the CT clock are all in place.

### 4. The Watcher: the state takes a turn · NEW
A Doctrine surveillance eye sits **in the CT turn-order strip** like a unit.
- It sweeps a vision cone. Crimes committed in view raise **Heat**.
- Heat thresholds rewrite the map's rules: curfew (−1 Move), reinforcements, and a Judge who enforces Laws (an FFTA2 nod).
- You can also **break the law on purpose**, when a reinforcement wave would drop enemies onto your trap.

- **Engine:** `TurnQueue` already schedules non-unit events (charged casts). The Watcher would be another of those.

### 5. Last Call: the drunk meter · BUILT (seed) → HOOKED
- The `buzzed` status already exists: attack and crit up, aim down. It comes from Liquid Courage and bar drinks.
- **Next:** before a mission, each crew member orders a drink. Buzz unlocks **Stumble** actions: a random-direction shove that knocks enemies off catwalks.
- Bonded pairs who are *both* buzzed unlock **Duo Techs**.
- The hangover rides into the next dispatch.

Comedy as a system, not just in dialogue.

- **Engine:** `KineticAbility` "repulse" already does the shove-into-wall math.

---

## Tier A: great, and they fit the systems we have

### 6. Rumour Mill Dispatch · BUILT (seed)
- **Built:** dispatch already returns rumours from `data/rumors.json`.
- **Next:** rumours become **two-truth intel cards**, such as "3 guards at the depot… or 9". Which one is true is rolled when you deploy, weighted by how sober and perceptive the dispatcher was.
- Failed dispatches can create **Wanted** crew members (hunted in later maps) or **captured** ones (rescue maps).

### 7. Weapons That Remember · HOOKED
- Gear instances already carry level, XP and potential. Kills already feed weapon XP.
- **Add:** a kill log by faction. At thresholds a weapon earns an **epithet**, like *Doctrine-Breaker* (+15% vs Doctrine).
- Your rule "craft late = higher cap" also decides **epithet slots**:
  - evolve at 10 → 1 slot
  - at 20 → 2 slots
  - at 30 → 3 slots
  - at 50 → 4 slots
- The old weapon's memory survives as a line of "ghost" flavour text.

### 8. Cards on the Grid · HOOKED
- **Built:** the Deck Stacker's cards (once per battle).
- **Next:** some cards are **played face-down onto tiles** as traps, blessings or pure bluffs.
- The enemy AI scores face-down tiles as risk (`AIBehavior.build_threat_map` is the hook), so bluffs genuinely herd enemies.
- Playing a pair or a straight on consecutive turns triggers bonus "hands".

### 9. Code-Layer Sight · NEW
- Only Hackers and Digimancers see **code objects**: traps, hidden loot, ghost enemies.
- They must spend an action to **Share**, which tags those objects for allies until the end of the turn.
- Information becomes logistics, and it pays off your FF8/FF9 hidden-loot design: a hacker in the party *finds more*.

### 10. Propaganda Duel · NEW
- Doctrine conscripts have **Belief**. The crew's talk abilities, backed by evidence found in the hub, erode it. At 0 a conscript defects or runs.
- Doctrine officers pump Belief back up with hymn broadcasts.
- Whether you spare or kill converts feeds the ending.

### 11. The News Reacts to You · HOOKED
- Your actions set story flags, and the Doctrine news ticker **spins them**.
- The canon scapegoat takes the blame for your explosion: "Greywrithe saboteur Kestral Omen-Six suspected. Again."
- The spin escalates the more you do: "Omen-Six sighted in four districts simultaneously."
- The overseas war never resolves. It just keeps interrupting your life.

- **Engine:** the hub ticker plus `EventBus.broadcast_line`. It needs a `required_flag` field on rumours.

---

## Tier B: signature polish

- **12. Two Faces.**
  - Each crew member has a Declared Face (the barfly) and a Hidden Face (lore: Twin Face philosophy). The Hidden Face unlocks through their quest chain and grants a *second* secondary job.
  - **Engine:** `CharacterData.secondary_class_id` and `JobHandler` already support one secondary job.
- **13. Graffiti Tiles.**
  - Rumour graffiti on map walls. Reading one (a free action, like searching a prop) grants a small buff or reveals a hidden route.
  - It's the same `InteractionTrigger` used for hidden loot.
- **14. Shift-Change Waves.**
  - Factory maps run on the CT clock as a *work clock*. Every 50 ticks the whistle blows, fresh Wardens clock in, and tired ones clock out and leave the map.
- **15. Hangover Morning.**
  - The hub between chapters becomes a tiny turn-based *social* grid, reusing the battle engine.
  - Seating chart, Toast, Roast, Buy a Round. Bond XP unlocks Duo Techs and "Bar Stories".
- **16. Voice Barks from Your Recordings.**
  - `voice_path` exists on dialog nodes. Extend it to battle barks: crits, kills, low HP, and drunk barks.
  - The editor already previews audio, and you record the lines yourself.

---

## What we already shipped that the genre rarely does

- **Deterministic damage, random hit** (Into the Breach clarity): the forecast is exactly what lands.
- **Blue Magic you learn by getting hit**, from enemy droids, Choir hymns and essence wraiths.
- **The Digimancer**: raise fallen *enemies* as fading echoes, using the villain's own art.
- **The Echo Mime**: repeats the last thing a crew member did, for free.
- **Chrono-Stitcher**: tie an enemy's turns to feed your ally's clock, and stitch deferred damage into their future.
- **Cartographer**: rewrite the battlefield (walls, elevation, swapping tiles *and whoever stands on them*).
- **Evolve-late-for-potential crafting**, which rewards patience with a permanent multiplier.
- **Hidden loot with no markers**: you learn to click everything, exactly like FF8/FF9.
