# Swords and physical combos: ideas (brainstorm, 2026-11-13)

These are ideas for Brian to pick from. Nothing here is built or spent yet.

## What we already have
- **Guns:** the arms are animated empty-handed on our own skeleton poses (`tools/pixellab/aim_pose.py`). The game attaches the weapon art to the hand points we wrote (`src/vfx/gear_attach.gd`), and two-hand guns use a second grip on the left hand.
- **Additions** (`src/combat/additions.gd`, the Sync Blade class): a timed button chain.
  - Each beat that lands adds a strike, a miss ends the chain, and a full chain fires the finisher.
  - Mastery grows with use. It's data in `abilities.json` (`addition: {beats, window, per_hit, finisher}`).
  - Right now it has no strike animations of its own.
- **One-picture weapon art plus PixelLab back views:** the pistols showed that `/rotate` draws the back view for 1 credit.
- **Known weak spot:** PixelLab smears a raised arm when it's up by the head (use_item and throw). Swings will hit this too.

## Swords

### 1. Same recipe as guns (recommended)
- The body swings empty-handed on our own keyframed poses, and the sword is game art on `hand_r`, turned along the forearm (as the pistols are).
- One art set per sword fits every unit and outfit.
- The swing arc is known exactly per frame (we write the hand and elbow points), so the blade can't drift off the hand.
- Sword art could come three ways:
  - (a) A sword sheet from you, cut like the pistols, with back views from PixelLab `/rotate` at about 1 credit each.
  - (b) `pilot_blade` as a placeholder.
  - (c) The 8-direction object route at about 10 each.

### 2. Engine swing trail
At 60 px a fast swing barely reads. The engine can draw a crisp arc (a smear or ribbon) along the blade tip's path from frame to frame.
- We know the hand and forearm angle on every frame, so the trail is exact.
- It hides the PixelLab arm smear on the fast frames.
- It's a VFX part (`streaks`/`trail` in vfx.json) fired by `Cues`, so the rules don't touch it.
- Its colour can come from the weapon (neon edge).

### 3. A small set of sword clips per unit (our own poses, about 3 credits a facing)
- **ready / guard:** the blade up, the idle in battle.
- **slash** (horizontal, shoulder to hip), **chop** (overhead down), **thrust**, **rising cut**.
- **heavy:** two-handed, for katanas and greatswords. The left hand takes `grips2` like a rifle.
- **sheathe / draw:** optional. The sword rides a back or hip slot while walking (the back slot already exists).
- To keep PixelLab from smearing: keep the hands below the chin on wind-ups (a low guard, a side draw), and let the fast frames be the smeared ones, since the trail covers them.

### 4. Variety without more spend
- **One-hand vs two-hand:** the same body clips, different grips.
- **Dual wield:** a second blade on `hand_l`, mirrored timing.
- **Daggers and batons:** the same clips at a smaller scale with a faster playback rate.

## Physical combos (punches, kicks, sword strings)

### 1. Beats as short clips that chain
- Each beat is a 3-4 frame strike that starts and ends in the same **guard pose**, so any beat can follow any other: jab, cross, kick, slash A, slash B and so on.
- An Addition's `beats` list names the clip for each beat. A miss plays a short **stagger** clip, and a full chain plays a **finisher**: spin slash, launcher, leap slam (the jump clip reused) or dash-through.
- Generation: `--chain` already starts a clip from another take's frame. Ending each beat on the guard pose keeps them seamless.
- **Cost per unit:** guard plus 4 beats plus a finisher plus a stagger is about 7 clips × 4 facings × 3, roughly 85. Mirroring symmetric outfits halves the facings.

### 2. The engine sells the hit, not the frames
- **Lunge:** the sprite slides toward the target on each beat and steps back on the finisher.
- **Hit-stop,** a camera nudge and an impact flash per landed beat, plus a growing beat counter on the Addition widget.
- **Target reaction:** the existing hit clip on each beat, and a knock-back slide or the death clip on the finisher.
- All through `Cues`/EventBus, with `animate=false` headless as the rules require.

### 3. Unarmed first, swords second
Punches and kicks need no weapon art and test the whole chain (beats → clips → Additions timing → hit-stop). Swords then reuse the same beat timing with the weapon on the hand.

### 4. Ideas to make combos feel ours
- **Finishers per job:** Sync Blade gets a slash string; a brawler job gets a kick launcher.
- **Combo branching:** pressing early or late picks a different next beat (a high or low strike). It's still the same clips, just picked by timing.
- **Team links:** a finisher on a target marked by an ally's shot triggers a two-unit follow-up, as a `[BNV PROPOSAL]`.

## A cheap first test
- One unit (street samurai, it fits), SE only:
  - guard + one slash: about 6 credits;
  - with `pilot_blade` on the hand;
  - the engine trail mocked in the preview.
- Look at it frame by frame. If the slash reads, do the beat set for that one unit, then roll out.

## Questions for Brian
- Do you have sword art (a sheet like the pistols), or should we start with `pilot_blade`?
- Which first: unarmed combos or swords?
- Should the Additions finishers be per job, or per weapon type?
