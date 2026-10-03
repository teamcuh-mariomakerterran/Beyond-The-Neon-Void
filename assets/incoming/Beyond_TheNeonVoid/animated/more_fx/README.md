# Map FX pack

Reusable one-shot + looping overlays for the battle map (facing-agnostic).

| id | kind | loop | frames | fps | use |
|----|------|------|--------|-----|-----|
| `ping` | fx | False | 8 | 10 | selection / radar alert ping |
| `buff_aura` | ambient | True | 10 | 8 | looping buff halo on unit/building |
| `explosion_sm` | fx | False | 8 | 12 | small explosion one-shot |
| `shockwave` | fx | False | 8 | 10 | ground shock ring |
| `heal_motes` | ambient | True | 10 | 8 | rising heal motes |
| `alert_pulse` | fx | False | 8 | 10 | urgent red map ping |
| `emp_burst` | fx | False | 8 | 12 | electric arc EMP burst |

Each effect ships `*_strip.png` + `*_clip.json` (`lattice.clip.v1`).

Author more in Lattice: **Effects** → pick `fx.map_ping` / `fx.buff_aura` / … → **Export → Clip**.

See `PACK.json` (`lattice.map_fx.pack.v1`) and `../../MAP_AMBIENT.md`.

## Effects blasts (added)

Cauliflower / painterly / mushroom / energy_dome / energy_orb — see `../../effects/blasts/`.

## Effects wave2 (added)

Muzzle / impact / shield_break / teleport / scrap / acid / ice / heal — see `../../effects/wave2/`.

## Effects wave3 (added)

Status icons / weather / demolish / emp / poison / crit — see `../../effects/wave3/`.

## Effects wave4 (added)

Fire / smoke / plasma / laser / orbital / mine / oil / shield_up / cloak / pickup — see `../../effects/wave4/`.

## Smolder smoke

`smolder_smoke` — looping ambient grey wisps + optional embers for destroyed ruins (`fx.smolder_smoke`).
