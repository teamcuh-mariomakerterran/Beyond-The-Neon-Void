# Formulas (single sources: `unit_stats.gd`, `damage_calculator.gd`, `additions.gd`)

`DamageCalculator.forecast(attacker, defender, ability, grid) -> {hit, damage, crit, kill}` is what the HUD and the AI read. **Every rule change goes into DamageCalculator (or UnitStats) so forecast and resolution can't disagree.** To print real numbers, use `scripts/gd/forecast_matrix.gd`. Don't re-implement the math in Python.

## Stats (`UnitStats.calculate`)
- Primary = `round(raw × class.multiplier × status_mult + equip_flat + status_flat)`, clamped 0–999.
- **Primaries grow only through `level_up(cls)` (class `growth`).** `Unit.setup(level_override)` sets `level` only (gap: enemy level = HP/MP only).

| Derived | Formula |
|---|---|
| max_hp | `(base_hp + hp_growth×(lv−1)) × (1 + vit/100)` |
| max_mp | `(base_mp + mp_growth×(lv−1)) × (1 + int/100)` |
| attack / magic | str / int |
| defense | vit × 0.75 |
| resistance | (int + vit) × 0.4 |
| speed | base_speed + agi/10 |
| evasion % | 5 + agi × 0.25 |
| accuracy % | 90 + agi × 0.2 |
| crit % | 5 + agi × 0.1 |
| move, jump, max_ap | from class |

Each derived stat is then `× status_mult + flat`, rounded once, and clamped: HP/MP 1–9999, speed ≥ 1, others 0–999. Level cap 99.

## Hit chance (`hit_chance`)
- `untouchable` tag (shielded, banished) → **0**. Heals and ALLY/SELF targets → 1.
- `(acc − eva)/100 + accuracy_bonus`, then:
  - angle: back +0.20, side +0.10
  - `− cover × 0.45`; full cover (≥0.999) → 0
  - height `clamp(dh × 0.03, ±0.09)`
- Disabled target → 1.0. Clamp to 0.05–0.99.
- `cloaked` tag: 0 beyond 1 tile, ×0.5 adjacent.
- Angle comes from `attack_angle` (dot of attacker offset with target facing): >0 front, <0 back, 0 side. **Facings are cardinal today** (`IsometricGrid.DIRECTIONS`); diagonal facing is **ASK BRIAN**.

## Damage (`damage`): deterministic, no variance
```
raw = stat(scaling_stat) × power × power_multiplier(attacker) × 100 / (100 + def×2)
      def = resistance if damage_type in MAGICAL_TYPES [tech, void, essence, electric, plasma, cryo] else defense
raw ×= height: +10%/level up (max +30%) | −5%/level down (max −15%)
raw ×= 1.15 if back                      (side: no damage bonus)
raw ×= 1 − cover × 0.4                    (magical types ignore cover except a full wall head-on)
raw ×= target.element_mult(damage_type) × Passives.damage_mult × (1.5 if 'stone' tag) × (1.5 if crit)
clamp(round(raw), 1, 9999)                 (then × ctx.power_mult for Additions)
```
- Crit chance `clamp(crit/100 + crit_bonus, 0, 0.75)`.
- Heal = `stat × power × 1.2` (stat = scaling_stat, or magic if it's "attack").

## Cover (`IsometricGrid.cover_fraction` / `cover_against`)
Directional: `COVER_HALF = 1`, `COVER_FULL = 2` from map masks, `HEAD_ON 0.92`, flank factors in `isometric_grid.gd:350-380`. Details in iso-tactics-grid.

## CT (`turn_queue.gd`)
- `CT_READY 100`, `CT_CARRY_CAP 60`, cost 100/80/60.
- Each tick adds `max(speed, 1)`.
- Ready order: CT, then speed, then player team.
- `forecast(count)` simulates the CT strip.
- Charged casts tick on the same clock and resolve first on ties.

## Additions (`additions.gd`)
- Multiplier `= 0.5 + per_hit × hits + finisher`, × `(1 + 0.08 × (mastery − 1))`.
- Window `0.13 + 0.012 × (lv − 1)` s.
- Mastery +1 per 15 uses (max 5).
- AI, headless and auto mode use `auto_hits` ≈ 70%.

## Hazards
- Per unit at end of turn: neon_fire 8% HP, static → slow, essence_leak 5% HP + 5 MP.
- Grid hazard duration ticks per round (10 ticks).
- Pathing cost +2 on hazard cells.
