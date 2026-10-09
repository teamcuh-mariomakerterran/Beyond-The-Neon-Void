# Battle bark voice script (ElevenLabs v3)

Every bark line the game has, ready for ElevenLabs. Each character has a **voice design brief** (paste it into Voice Design) and **delivery notes**, then their lines with v3 audio tags.

## How to record

- **Model:** use **Eleven v3**. It reads the `[audio tags]` in square brackets as performance directions; they aren't spoken.
- **Settings:** set stability to *Creative* or *Natural*. *Robust* mostly ignores the tags.
- **Short lines:** v3 is less consistent on very short lines. Generate a few takes and keep the best, or put 3–4 of a character's lines in one generation and cut them apart.
- **Tags used:** `[laughs] [giggles] [snickers] [sighs] [exhales] [whispers] [shouts] [sniffles]`, emotions like `[excited] [smug] [deadpan] [worried] [pompous]`, and `[beat]` for a short pause.
- **Pacing:** CAPS stress a word and `...` slows the delivery. Swap tags freely if a voice doesn't respond to one.
- **Saving:** export as **OGG** (or WAV). Save each take with the exact **file name** shown into `assets/voice/barks/`, either in the repo or through the intake bot. The game already points at these names: a line plays its recording as soon as the file exists, and stays a silent bubble until then.
- **Troopers:** Doctrine troopers share one voice set (`doctrine_trooper_*`). The generic crew lines (`team:0`) are fallbacks spoken by whoever triggers them, so they stay text-only.
- **New lines:** add them in the Forge (CHARACTERS → Voice → barks: event, text, voice_path) or in `data/barks.json`. Events: battle_start, turn_start, crit, kill, ally_down, low_hp, big_hit, miss, heal, victory, buzzed, shield_down.

## Rook Dannick

**Voice design:** Male, early 30s. Warm working-class baritone, quick talker, cocky but a half-beat late, like he's making the plan up as it comes out. Slight rasp from bar smoke.

**Delivery:** Fast, confident, then a tiny self-aware stumble. Grin in the voice.

| File | Event | Text for ElevenLabs |
|---|---|---|
| `rook_battle_start_1.ogg` | battle_start | [confident] Okay. Plan. We have a plan... [beat] Mostly. |
| `rook_battle_start_2.ogg` | battle_start | [smug] Everybody act like this was the idea. |
| `rook_crit_1.ogg` | crit | [excited] Called it! [beat] Didn't call it. [laughs] Still counts. |
| `rook_crit_2.ogg` | crit | [shouts] That's the PLAN working! |
| `rook_kill_1.ogg` | kill | [smug] Off the clock. |
| `rook_kill_2.ogg` | kill | [dry] Shift's over for you. |
| `rook_low_hp_1.ogg` | low_hp | [pained] This is fine. [strained laugh] This is a strategic bleed. |
| `rook_low_hp_2.ogg` | low_hp | [panicked] Patch? [shouts] PATCH! |
| `rook_ally_down_1.ogg` | ally_down | [shouts] No no no — we're NOT leaving anyone at this bar! |
| `rook_miss_1.ogg` | miss | [sighs] The plan had that one hitting. |
| `rook_victory_1.ogg` | victory | [laughs] Drinks are on Brannoc! |

## Mags Orrowin

**Voice design:** Female, mid 40s. Low, dry, factory-floor alto. Fifteen years of shouting over machines: clipped, flat, deadpan, never wastes a word.

**Delivery:** Short and level. Humor is bone-dry, never laughs at her own lines.

| File | Event | Text for ElevenLabs |
|---|---|---|
| `mags_battle_start_1.ogg` | battle_start | [flat] I know every blind spot on this floor. Follow me. |
| `mags_battle_start_2.ogg` | battle_start | [dry] Eyes up. Their sightlines suck. |
| `mags_crit_1.ogg` | crit | [quietly] Right through the gap. |
| `mags_crit_2.ogg` | crit | [matter-of-fact] Fifteen years on the line. I know where the seams are. |
| `mags_kill_1.ogg` | kill | [deadpan] Clocked out. |
| `mags_kill_2.ogg` | kill | [deadpan] Quota met. |
| `mags_low_hp_1.ogg` | low_hp | [through gritted teeth] Not dying on a Tuesday. |
| `mags_miss_1.ogg` | miss | [muttering] Wind. [beat] There's no wind indoors. [annoyed] Shut up. |
| `mags_victory_1.ogg` | victory | [exhales] That's a full shift. |

## Dez 'Dizzy' Kettleby

**Voice design:** Nonbinary-leaning, mid 20s. Bright, quick, slightly nasal hacker voice, giggly, talks faster when excited, pitch jumps around.

**Delivery:** Playful, mischievous, a little unhinged. Lots of up-talk and snickers.

| File | Event | Text for ElevenLabs |
|---|---|---|
| `dizzy_battle_start_1.ogg` | battle_start | [mischievously] Ooh, they've got firewalls. [giggles] Cute. |
| `dizzy_battle_start_2.ogg` | battle_start | [excited] I wrote this exploit on a napkin. [beat] The napkin was wet. |
| `dizzy_crit_1.ogg` | crit | [shouts] Segfault! [snickers] Their face, I mean. |
| `dizzy_crit_2.ogg` | crit | [playfully] Oops. Infinite loop. [whispers] In you. |
| `dizzy_kill_1.ogg` | kill | [robotic voice] Process... terminated. |
| `dizzy_kill_2.ogg` | kill | [laughs] Ctrl-alt-DEFEAT! |
| `dizzy_low_hp_1.ogg` | low_hp | [nervous laugh] I'd like to roll back to an earlier save, please. |
| `dizzy_buzzed_1.ogg` | buzzed | [drunk, dreamy] Everything's in hex now... [giggles] It's beautiful. |
| `dizzy_miss_1.ogg` | miss | [frustrated] Undefined behavior! UNDEFINED! |
| `dizzy_victory_1.ogg` | victory | [cheerful] Patch notes: we won! |

## Brannoc 'Tap' Hollis

**Voice design:** Male, 30s. Huge deep bass, soft and gentle, almost shy. A giant who apologises. Voice cracks with emotion easily.

**Delivery:** Slow and soft. Big when angry (ally_down), otherwise tender and sheepish.

| File | Event | Text for ElevenLabs |
|---|---|---|
| `brannoc_battle_start_1.ogg` | battle_start | [softly] I'm sorry in advance. |
| `brannoc_battle_start_2.ogg` | battle_start | [pleading] Please don't make me. |
| `brannoc_crit_1.ogg` | crit | [surprised, worried] Oh no. Did I do that? |
| `brannoc_crit_2.ogg` | crit | [apologetic] Sorry! Sorry. [beat] [proud] Good punch though. |
| `brannoc_kill_1.ogg` | kill | [worried whisper] ...he'll be okay. Right? [voice cracks] He'll be okay. |
| `brannoc_low_hp_1.ogg` | low_hp | [sniffles] I'm not crying. [shaky] It's the smoke. |
| `brannoc_ally_down_1.ogg` | ally_down | [roars] HEY! [angry] Nobody touches my friends. |
| `brannoc_victory_1.ogg` | victory | [hopeful, softly] Can we play the sad song on the jukebox? |

## Juniper 'Patch' Oyelaran

**Voice design:** Female, early 30s. Calm, warm mezzo, clinical precision, tired-nurse dryness, a faint West African lilt.

**Delivery:** Steady and controlled, sharp when urgent, deadpan jokes.

| File | Event | Text for ElevenLabs |
|---|---|---|
| `patch_battle_start_1.ogg` | battle_start | [sighs] Read the labels. Nobody reads the labels. |
| `patch_battle_start_2.ogg` | battle_start | [dry] Try not to need me. |
| `patch_heal_1.ogg` | heal | [calm] Hold still. |
| `patch_heal_2.ogg` | heal | [dry] That's twice today. I'm keeping a tab. |
| `patch_low_hp_1.ogg` | low_hp | [pained, wry] Medic's down to her last bandage. [beat] Mine. |
| `patch_ally_down_1.ogg` | ally_down | [urgent, shouts] Stay with me — I'm coming! |
| `patch_kill_1.ogg` | kill | [calm] First, do no harm. [beat] [cold] Second, do harm. |
| `patch_victory_1.ogg` | victory | [warmly] Everyone line up. Shots. [beat] The medical kind. |

## Foreman Grisk Harrowby

**Voice design:** Male, 50s. Pompous, nasal, bureaucratic tenor-baritone, a middle manager who believes in the quota like scripture.

**Delivery:** Self-important, indignant, sputtering when things go wrong.

| File | Event | Text for ElevenLabs |
|---|---|---|
| `foreman_grisk_battle_start_1.ogg` | battle_start | [pompous] The quota does not care about your feelings. |
| `foreman_grisk_battle_start_2.ogg` | battle_start | [barking orders] Back to your stations! |
| `foreman_grisk_low_hp_1.ogg` | low_hp | [outraged] This will be DOCKED from your pay! |
| `foreman_grisk_shield_down_1.ogg` | shield_down | [sputtering] My shield! [indignant] That was company property! |
| `foreman_grisk_kill_1.ogg` | kill | [smug] Insubordination: resolved. |

## Doctrine troopers (Wardens, Enforcers, Cantors…)

**Voice design:** Male or female, any age. Helmeted, slightly filtered, drilled zealot voice, chant-like, speaks in slogans.

**Delivery:** Barked, rhythmic, almost sung. Use one voice, or two to alternate.

| File | Event | Text for ElevenLabs |
|---|---|---|
| `doctrine_trooper_battle_start_1.ogg` | battle_start | [shouts, fervent] By the Hymn — hold the line! |
| `doctrine_trooper_battle_start_2.ogg` | battle_start | [alarmed, shouts] Unregistered persons on the floor! |
| `doctrine_trooper_crit_1.ogg` | crit | [zealous] For the Doctrine! |
| `doctrine_trooper_crit_2.ogg` | crit | [cold] Compliance achieved. |
| `doctrine_trooper_kill_1.ogg` | kill | [flat] Citizen corrected. |
| `doctrine_trooper_kill_2.ogg` | kill | [flat] Report filed. |
| `doctrine_trooper_low_hp_1.ogg` | low_hp | [strained, shouts] Requesting relief! |
| `doctrine_trooper_low_hp_2.ogg` | low_hp | [weakly, chanting] The Hymn... sustains... |
| `doctrine_trooper_ally_down_1.ogg` | ally_down | [shouts] Brother down! [chanting] Sing louder! |
| `doctrine_trooper_miss_1.ogg` | miss | [angry] Hold still, heretic! |

## Doctrine Relay (mast)

**Voice design:** Synthetic public-address announcer. Calm, sterile, female or neutral, heavy radio filter.

**Delivery:** Flat monotone. The low_hp line glitches and breaks apart.

| File | Event | Text for ElevenLabs |
|---|---|---|
| `doctrine_relay_battle_start_1.ogg` | battle_start | [monotone announcer] ATTENTION. All figures... are certified. |
| `doctrine_relay_low_hp_1.ogg` | low_hp | [glitching] SIGNAL... degraded... [static] TRUST... the... [cuts off] |
