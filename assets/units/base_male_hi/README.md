# Base male, high top-down (modular system)

Replaces `../base_male` (low top-down; kept as a record) so the base matches the cast's camera view (Brian, 2026-11-10). Source: Brian's high top-down "cyberpunk corporate characters" (a7653f4a), the same design as the low top-down one but drawn separately.

States (all `source/`, free exports): `base_light.zip` state `light_bodysuit` (bald, no cybernetics, no cane, bare hands, light grey bodysuit; 10 generations) with a walk SE (skeleton-v3; balance fell 18.2 during it, mostly Brian's tile work; the walk is 3); `dressed_nocane.zip` state `no_cane` (10). Walk frame skeletons: `walk_SE_skeleton.json` (0.6).

Parts (free): `parts/corporate_suit` (cut against the base, split per facing), `parts/cane` (dressed minus no-cane). Walk test: docs/screenshots/base_male_hi_suit_walk.gif. Open: this pair's faces are drawn a little differently, so the dressed eyes and brows ride with the head part; a few stray pixels at the back of the head and on the legs.

Walk from our own poses (2026-11-10): the template walk was audited and rejected (the body turns from SE toward E on frames 2-3, face features change, legs 3-4 px too long on frames 5-6; docs/screenshots/base_male_hi_template_walk_audit.png). `source/walk_own_SE/` is an 8-frame walk built on the standing skeleton (`tools/pixellab/aim_pose.py --clip walk --id ... --zip ...`, about 3 generations): facing and face hold on every frame, feet stay within 2 px of the standing ground line, and the skeleton of every frame is known (`walk_own_SE_skeleton.json`), so outfits ride it with no estimate cost. docs/screenshots/base_male_hi_own_walk.gif.
