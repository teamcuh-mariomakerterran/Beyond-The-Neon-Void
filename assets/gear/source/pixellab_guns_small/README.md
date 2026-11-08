# Hand-size gun redraws

Each of Brian's 15 gun objects redrawn by PixelLab at the size it's shown in a unit's hand (24 px handguns, 28 px SMGs and the spell blaster, 32 px long guns), from a reference picture of the original's side view (`tools/pixellab/make_gun.py`). 10 generations each, 150 in all (2026-11-08, Brian's ceiling 150). Every folder has the 8-rotation sheet, its layout, the object details, the reference picture and log.json (object id, balance drop).

Game art sets (`assets/gear/weapons/<name>`) use these at full size; Brian's grip marks carry over from the originals by their place in each picture's outline box. Notes: super_handgun_001's grip came out dark (the side view shows it dark); the heavy machine gun gained a few cyan lights; the assault rifle's E view points the wrong way (unused). The originals stay in `../pixellab_guns`.
