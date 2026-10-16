# FFT parity map (what BTNV has, what's missing, who decides)

| FFT feature | BTNV today | Status / decision |
|---|---|---|
| CT clock, speed-based turns | `TurnQueue` (100 / carry 60 / 100-80-60) | ✅ |
| Charge time for spells, cast on a cell | `charge_ticks`, `queue_cast`, `charging` | ✅. AI skips `charge_ticks > 12` and can't predict casts (tactics-ai) |
| Facing + back/side attacks | hit +20%/+10%; damage ×1.15 back only | side damage bonus? **ASK BRIAN** |
| 8 facings / diagonal sprites | cardinal facings in code; art and ROADMAP want diagonals | **ASK BRIAN** (facings) |
| Height: jump, damage, range | jump in pathing, ±damage, ±hit, `vertical_tolerance` | ✅. AoE footprint ignores height (gap) |
| Damage variance | none ("players see exactly what a hit does") | intentional; keep unless Brian says otherwise |
| Brave / Faith | — | not planned; **ASK BRIAN** before adding |
| Zodiac compatibility | — | not planned |
| JP per job, spillover | class XP (`ProgressionSystem`, class levels 1–8, ×0.8 of mission XP) | different by design (job-ability-system) |
| Reaction / Support / Movement abilities | `passives.json` (6 reaction, 7 support, 6 movement) | ✅. Hooks: after_move, after_action |
| Secondary job | `secondary_class_id`; secondary innates not allowed | ✅ |
| Blue magic | `blue_learnable` + Bluescreen Mage | ✅ |
| Guests / AI allies | mission `guests` | ✅ (statuses ignored) |
| Crystals / treasure on death | corpses tracked; `reanimate`/`revive` | no crystal/chest; **ASK BRIAN** |
| Permadeath countdown | — | **ASK BRIAN** |
| Traps | Interactions `trap` anchors | ✅ (own RNG leak) |
| Weather / terrain effects | hazards (neon_fire, static, essence_leak) | extend via `hazard` |
| Enemy level scaling | HP/MP only | **gap**: apply class growth for `level - 1` levels |

Signature BTNV systems FFT doesn't have (protect these):
- Additions (timed hits)
- cards/decks (Deck Stacker)
- chips as ability currency
- Lattice clips with emitters
- cover masks (XCOM-like)
- anchors (terminals, switches, smoke)
- the planned Lying HUD
