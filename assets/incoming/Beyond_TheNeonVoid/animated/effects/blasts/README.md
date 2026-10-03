# Effects blasts

Procedural one-shot explosion / energy FX inspired by Brian's 5 reference sprite sheets.

| id | Lattice gen | frames | fps | use |
|----|-------------|--------|-----|-----|
| `cauliflower_blast` | `fx.cauliflower_blast` | 10 | 12 | golden cauliflower fireball one-shot |
| `painterly_blast` | `fx.painterly_blast` | 10 | 12 | orange painterly blast → smoke ring |
| `mushroom_blast` | `fx.mushroom_blast` | 10 | 12 | ground mushroom cloud explosion |
| `energy_dome` | `fx.energy_dome` | 10 | 12 | cyan energy dome → lightning |
| `energy_orb` | `fx.energy_orb` | 10 | 12 | blue cellular orb → shatter arcs |

Each ships `*_strip.png` + `*_clip.json` (`lattice.clip` v1, kind=`fx`, loop=false).

Author in Lattice: **Effects** → pick the gen → tweak reach/intensity/seed → **Export → Clip**.

Also mirrored into `samples/map_ambient/map_fx/` (PACK.json updated).
Baker: `scripts/bake_effects_blasts.py`.
