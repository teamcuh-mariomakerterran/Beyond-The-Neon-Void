# Base male (modular system)

Brian's PixelLab character "base male for modular system" (2026-11-09): `source/dressed.zip` and `source/base.zip` are the free exports (both hold both states: `Idle` is the dressed corporate look, `same_character_no_c` the stripped base: bald, plain bodysuit, bare hands). Details JSON beside them.

First cut test (free): dressed minus base cleanly separates hair, the cybernetic eye piece, the cane and the red trim; the suit's dark body is too close to the dark bodysuit to separate (docs/screenshots/base_male_cut_test.png).

Light base (2026-11-09, 10 generations, `tools/pixellab/make_state.py`): `source/base_light.zip`, state `light_bodysuit` ("same character, bald, bare hands, wearing a plain light grey skin-tight bodysuit"). Against it the whole corporate suit cuts out in one piece (`tools/pixellab/cut_parts.py`, free), with the dressed character's own skin dropped so a recoloured body shows no seams: `parts/corporate_suit/<FACING>.png` (docs/screenshots/base_male_cut_light.png).

Walk SE on the light base (2026-11-09, skeleton-v3, 3 generations; in `source/base_light.zip`). The corporate suit is split into parts per facing by `tools/pixellab/split_parts.py` (free): `parts/corporate_suit/parts/<FACING>_<part>.png` with the standing skeleton in `bones.json` (docs/screenshots/base_male_parts_split.png). The cane isn't reliably picked out as a held item yet. PixelLab keeps no per-frame skeleton for animations, so riding the walk needs frame skeletons (/estimate-skeleton, 0.1 a frame).

First modular walk (2026-11-09): PixelLab's skeleton estimate on the 6 walk frames (0.6 generations, `tools/pixellab/estimate_frames.py`, `source/walk_SE_skeleton.json`); the suit's parts ride their bones (`tools/pixellab/ride_parts.py`, free). Bodysuit still showing on a clothed limb takes that limb's colours (`--lining`). Head, hair, eye piece and jacket follow cleanly; the legs carry a few stray pixels and the cane on SE still sits in the leg parts. docs/screenshots/base_male_suit_walk.gif.
