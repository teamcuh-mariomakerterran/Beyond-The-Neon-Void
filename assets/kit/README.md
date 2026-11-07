# Animation kit

Every PixelLab take we've generated, kept whole (Brian, 2026-11-06: never delete a take; frames may be reused elsewhere). Each zip is a full PixelLab export of a character at the time of the take. The game never loads these: unit art lives in `assets/units/`.

- `pool_003/pool_003_takes_2026-11-06a.zip`: #3 with the template-mode back facings (NE/NW) of all 5 animations and the first skeleton-v3 test (NW cross-punch). Both were later deleted in PixelLab.
- `pool_005/pool_005_takes_2026-11-06a.zip`: #5 with the template-mode back facings of walk and attack, later deleted in PixelLab.

New takes now stay in PixelLab next to each other (separate animation groups), so they're in every fresh export too.

## Scrap frames (reuse freely)
- `pool_005/aim_pistol_SE/`: #5 pistol raise / hold / fire from our own skeleton poses (`tools/pixellab/aim_pose.py`, 4 generations, 2026-11-07). Frames 0-7 (raise, hold) are copied into `assets/units/pool_005/aim_pistol/SE/` for the game. Frames 8-14 are scrap: PixelLab drew a gun and a muzzle flash in the hand, and frame 14 snaps back to standing. `aim.json` has the hand point of every frame.
