# Designing jobs and abilities for BTNV (FFT depth, BTNV voice)

## Identity first
Every class answers four things in one line each:
- **fantasy** (cyberpunk take on an FFT job, or an original)
- **verb** (what you do that nobody else does)
- **weakness**
- **combo partner** (which class it makes better)

`docs/design/CLASSES.md` already has the FFT mapping table. Keep it in sync.

## Kit shape (what the snapshot uses)
- **Innates:** 1–2, available from class level 1. Learnables: 2–6, bought with chips (1–5 chips in current data; 0 only when gated by a key item or class level). Data-disk abilities (Daemon Caller) are gated by key items you find (FF8/FF9 hidden loot).
- **Every class should have:**
  - one reliable action (AP 1, no charge)
  - one setup/positional tool (facing, height, terrain, CT)
  - one payoff
- **Charge time is the risk lever.** Big AoE needs `charge_ticks` of 2–8 (27 abilities use charge today). The AI won't cast anything above 12.
- **Use BTNV systems FFT lacks:**
  - cover (`ignores_cover`, magical types)
  - hazards (`terrain.hazard`)
  - CT manipulation (`time.*`)
  - echoes/summons
  - Additions (timed hits)
  - cards
  - anchors (abilities that interact with switches or doors are a future hook; tactics-ai)

## Numbers (anchor to existing data, then verify)
- `basic_attack` has power 1.4. Across class abilities in the snapshot, ATTACK power runs 0.7–3.2 (median 1.3) and MAGIC power 1.0–3.8 (median 1.5). The top end belongs to charged, data-disk or ultimate moves.
- Use `tactics-combat-core/scripts/gd/forecast_matrix.gd --classes=<new>` to see hits-to-kill against every mission enemy. Two to four hits for the reliable action on same-level trash is the current feel. Final bands are **ASK BRIAN**.
- Statuses: `status_chance` 0.2–0.5 on damaging moves, 1.0 on pure debuffs.

## Voice
Descriptions are one dry line: "Rip 60 CT out of an enemy." / "A data-disk daemon that collects rent…". Names are punny-cyberpunk but readable. No real-brand jokes. Check `franchise-bible` before naming anything after Doctrine bodies.

## New class checklist
1. Fill `templates/class.template.jsonc`, plus abilities from `templates/ability.template.jsonc` and passives from `templates/passive.template.jsonc`.
2. Add it to `ClassLibrary.CLASS_ORDER` (menu order) and fix the count comment.
3. Add its section to `docs/design/CLASSES.md` (same format: Unlock, Weapons, Innate, Learnable) and to `docs/design/ABILITY_LIST.md`.
4. Presentation:
   - VFX: a `vfx.json` `abilities` entry or a special. godot-vfx-forge.
   - Icon: icon pack name = id, or `icon_path`.
   - Status looks for new statuses.
   - Cues for reactions.
   - Optional cutscene for an ultimate.
5. Lattice/sprites: `sprite_sheet_path` on characters; clips per the lattice-in-game skill. Facings are **ASK BRIAN**.
6. Run `scripts/ability_audit.py` (0 errors), the forecast matrix and the `godot-verify` gate.
