# Hand touch-up list

Frames that are in the game (or about to be) but need a pixel pass by hand. Frame numbers count from 1 (PixelLab's files count from 0: frame 1 is `frame_000.png`). "Take" is the folder name inside the character's PixelLab export (`assets/units/pool_<n>/pool_<n>.zip`, under `Idle/animations/<take>/<direction>/`).

Add to it as we go; tick a line when it's done.

## #21 (camo poncho, cap, goggles)
- [ ] **hurt SE**, take `taking_a_punch` (skeleton-v3, group a48f7b90): frames **1, 2, 6**. The face goes dark and the goggles fade; frames 3-4 show the right face.
- [ ] **attack SE**, take `cross_punch_attack` (skeleton-v3, group 7f2f0229): frame **6** smears the poncho (trimmed in game).
- [ ] **attack SW**, same take: frame **6** smears the poncho (trimmed in game). The punch reads weakly: the fist stays inside the poncho on frames 1-5.
- [ ] **walk SW**, take `walking-9babe46a`: frame **6**, the poncho hem goes soft.
- [ ] **walk SE / SW gait** (Brian): the stride is small, closer to a march.

## Back facings (NE, NW; skeleton-v3), all 25
- [ ] **attack NE / NW, frame 6** (full reach) smears on nearly everyone. Trimmed in game (`keep_frames`), so the attack stops before full reach; touching up frame 6 brings the reach back.
- [ ] **death NE / NW, frames 6-7** smear. Trimmed in game, so some deaths end mid-fall instead of flat.
- [x] **death NE / NW, frame 3**: a grey whoosh mark beside the body on #3, #5, #6, #19, #21, #27, #43, #55, #60, #64, #75. Erased in game (`clean_frames`); the export still has it.
- [ ] **hurt and death, middle frames**: heads swell into blobs on #4, #5, #6, #24, #25, #79, #97, #132 (worst on #4 and #132, the camo cloaks).

## Front facings (template takes still in use)
- [ ] **#71 jump SE**, frame **2**: a pink blob on the face.
- [ ] **#74 attack SE**: the trousers turn pink.
- [ ] **#4 death SE**: a pink mouth.
- [ ] **hurt SW** colour patches: #3 (white gloves / blue arms), #29 (white patches), #64.

These front-facing items may be replaced by the skeleton-v3 redo instead (see `CAST_BATCH_AUDIT.md`).
