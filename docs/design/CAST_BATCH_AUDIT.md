# Cast batch audit (2026-11-07)

Every frame of the 25 characters checked against their own standing poses. Sheets: one row per animation and facing, standing pose on the left.

## What broke, by cause
1. **Front facings of attack, hurt, death and jump (SE, SW; template mode).** PixelLab redraws the body on its mannequin, so outer layers and held items drop out: cloaks and ponchos (#4, #21, #60, #132), long coats and robes (#9, #43, #54), capes, books and swords (#24, #3), staffs (#62, #64), helmets and faces (#127, #62, #64). Walk in the same mode mostly held up.
2. **Back facings of attack, hurt and death (NE, NW; skeleton-v3).** The outfit stays, but heads swell into blobs mid-motion, and the last 1-2 frames of attack and death smear into mush on nearly every character.
3. **Hurt SW** often changes colours (white gloves or patches on #3, #29, #64).
4. **One-offs:** a pink blob in #71 jump SE frame 2, a pink mouth in #4 death SE.
5. **Game bug:** skeleton-v3 frames are 96 px while the standing poses are 60 px, so back facings were drawn off the unit's spot. Fixed in cbcac693 ("skeleton-mode takes stand on their feet").

## Usable as is
- **Walk, all 4 facings:** good for most. Not for the cloak / poncho characters on SE and SW (#4, #21, #60, #132).
- **Jump NE / NW:** good for nearly all.
- **Death SE / SW** and **hurt SE:** fine for characters without long clothing or held items (#5, #6, #19, #29, #71, #74, #75, #78, #79, #97).

## Per character
| # | Verdict | Main problems |
|---|---|---|
| 3 | mixed | sword gone in front attack / hurt; back death melts |
| 4 | bad | camo cloak gone in every front facing; back attack / hurt / death are blobs |
| 5 | fair | coat thinner in front attack; back death melts |
| 6 | fair | back hurt / death heads swell |
| 9 | mixed | robe gone in front attack / hurt / death; bow kept on the back |
| 19 | good | back death last frames smear |
| 21 | bad | poncho gone in front; back attack / hurt are blobs |
| 24 | mixed | cape, book and sword gone in front attack / hurt / death |
| 25 | fair | skull face changes in hurt SE; back hurt / death smear |
| 27 | fair | robe gone in front hurt; back death smears |
| 29 | fair | hurt SW colour patches; back death smears |
| 43 | mixed | coat and back weapon gone in front attack / hurt |
| 54 | mixed | coat gone in front attack |
| 55 | fair | back death smears |
| 60 | bad | poncho gone in front; back hurt NW is a blob |
| 62 | mixed | staff and face gone in front attack / hurt |
| 64 | mixed | staff and cyborg eye gone in front attack / hurt / death / jump |
| 71 | good | one pink blob frame in jump SE |
| 74 | good | trousers turn pink in attack SE |
| 75 | good | back death last frames smear |
| 78 | good | back death last frames smear |
| 79 | good | back hurt / death heads blob |
| 97 | fair | back attack / hurt / death blobby |
| 127 | mixed | helmet shape gone in front attack / hurt |
| 132 | bad | same problems as #4 (camo cloak) |

## Free fixes before any new spending
- Drop the smeared final frames of back attack and death (hold the last clean frame) with a per-animation frame range in `pixellab.json`.
- Use the older kept takes where they're better for a facing.
