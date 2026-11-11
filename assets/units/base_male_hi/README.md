# Base male, high top-down (modular system)

Replaces `../base_male` (low top-down; kept as a record) so the base matches the cast's camera view (Brian, 2026-11-10). Source: Brian's high top-down "cyberpunk corporate characters" (a7653f4a), the same design as the low top-down one but drawn separately.

States (all `source/`, free exports): `base_light.zip` state `light_bodysuit` (bald, no cybernetics, no cane, bare hands, light grey bodysuit; 10 generations) with a walk SE (skeleton-v3; balance fell 18.2 during it, mostly Brian's tile work; the walk is 3); `dressed_nocane.zip` state `no_cane` (10). Walk frame skeletons: `walk_SE_skeleton.json` (0.6).

Parts (free): `parts/corporate_suit` (cut against the base, split per facing), `parts/cane` (dressed minus no-cane). Walk test: docs/screenshots/base_male_hi_suit_walk.gif. Open: this pair's faces are drawn a little differently, so the dressed eyes and brows ride with the head part; a few stray pixels at the back of the head and on the legs.

Walk from our own poses (2026-11-10): the template walk was audited and rejected (the body turns from SE toward E on frames 2-3, face features change, legs 3-4 px too long on frames 5-6; docs/screenshots/base_male_hi_template_walk_audit.png). `source/walk_own_SE/` is an 8-frame walk built on the standing skeleton (`tools/pixellab/aim_pose.py --clip walk --id ... --zip ...`, about 3 generations): facing and face hold on every frame, feet stay within 2 px of the standing ground line, and the skeleton of every frame is known (`walk_own_SE_skeleton.json`), so outfits ride it with no estimate cost. docs/screenshots/base_male_hi_own_walk.gif.

## Riding a walk (2026-11-10)
`ride_parts.py ... --lining --paint-legs --clip-far-arm --base-hands` is the current recipe:
- `--clip-far-arm`: the detailed far sleeve rides its bone but is only drawn where the base frame shows the far arm (plus a 1 px rim outside the body), so it passes behind the torso as PixelLab drew it. Use this for any limb clothing or armour with detail.
- `--paint-legs`: trousers are the base's drawn legs in the trouser colours (plain cloth). Detailed leg armour would use the same clipping as the far arm instead.
- `--base-hands`: hands come from the base frame with their outline.
- `--paint-far-arm`: older option, the far arm as plain recoloured base (no detail).

## Slot plan (Brian, 2026-11-11)
- **Chest + arms, legs:** PixelLab animates each outfit on the base's exact poses (`aim_pose.py go ... --clip walk2 --id <state>`); `mix_slots.py` mixes chest and legs between outfits at the waist. ~3 credits per facing per action.
- **Heads:** main characters share the base head for now; hair and helmets cover it. `swap_head.py` (heads from Brian's high top-down 60x60 characters) is for NPCs.
- **Back slot:** `cut_attachment.py` (outfit with minus without the piece) + `ride_parts.py --back`. Free.
- **Cut-and-turn riding** (`cut_parts` / `split_parts` / `ride_parts`): crowds and quick previews only; too noisy for detailed armour.
