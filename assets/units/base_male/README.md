# Base male (modular system)

Brian's PixelLab character "base male for modular system" (2026-11-09): `source/dressed.zip` and `source/base.zip` are the free exports (both hold both states: `Idle` is the dressed corporate look, `same_character_no_c` the stripped base: bald, plain bodysuit, bare hands). Details JSON beside them.

First cut test (free): dressed minus base cleanly separates hair, the cybernetic eye piece, the cane and the red trim; the suit's dark body is too close to the dark bodysuit to separate (docs/screenshots/base_male_cut_test.png).

Light base (2026-11-09, 10 generations, `tools/pixellab/make_state.py`): `source/base_light.zip`, state `light_bodysuit` ("same character, bald, bare hands, wearing a plain light grey skin-tight bodysuit"). Against it the whole corporate suit cuts out in one piece (`tools/pixellab/cut_parts.py`, free), with the dressed character's own skin dropped so a recoloured body shows no seams: `parts/corporate_suit/<FACING>.png` (docs/screenshots/base_male_cut_light.png).
