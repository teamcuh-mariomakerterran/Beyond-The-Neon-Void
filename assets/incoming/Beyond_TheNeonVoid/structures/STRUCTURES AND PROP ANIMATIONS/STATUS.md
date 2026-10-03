# LATTICE / Black Doctrine — STATUS

*Updated: Sat Sep 19, 2026 ~7:15 PM MT (America/Denver). PRIORITY 3 combat clip pipeline hardening shipped.*

---

## Shipped: combat clip kinds + pack (PRIORITY 3)

**Why:** Forge combatSchema uses `aim_fire` / hurt / death; Lattice had `aim`+`fire` split and no packaged shared aim_fire sample under `lattice.clip.v1`.

**What:**
- `29_clip.js`: `CLIP_KINDS` adds **`aim_fire`** (primary); `aim`/`fire` aliases resolve → `aim_fire`. `CLIP_KIND_DEFAULTS` (walk/idle/ambient loop; aim_fire/hurt/death **non-loop**). Manifest includes `loop`.
- `28_audit.js`: soft **frame budget** rows — aim_fire **3–11** (shared 11f ok), hurt 2–3, death 4–6. Amber only; never hard-fail.
- Samples: `samples/combat_clips/` — packaged shared aim_fire (dirs-rows, Forge N-first `labelSource:forge`), normalized hurt batch + SE death (`loop:false`).
- Helper: `scripts/package_combat_clip.py` (dirs-rows sheet + Forge dirOrder → clip.v1).
- Smoke: aim_fire kind/alias/sample parse + frame-budget asserts.

**Not claimed:** `combatReady`. Hurt remains 1f pose; death 7f outside soft 4–6 (amber).

**Next:** Wire combat_clips into Forge unit bindings / engine intake; optional multi-frame hurt flinch; death trim or budget confirm with GAD.

---

## Shipped: map / tile ambient scaffold (follow-up)

**Why:** Buildings/city tiles should feel alive (smoke, flicker, drones) without character facing / Forge DIR_ORDER.

**What:**
- Design: `MAP_AMBIENT.md` — layer model (static base + looping overlays), `kind: ambient` (+ `tile_loop`), timing defaults, export shape, iso 64×32 / elevationStep 16, honest limits.
- Sample pack: `samples/map_ambient/` — smoke strip **768×64** (12×64×64 from `smoke roll 001.png` 4×3 sheet), `bd_map_smoke_vent_clip.json` (`kind: ambient`, `loop: true`, fps 7, `anchor`/`sortBias`/`depthKey`), building base from `bsheet_040_14_2.png`, QA composite, optional procedural drone orbit clip.
- Lattice hook: `CLIP_KINDS` in `29_clip.js` adds **`ambient`** + **`tile_loop`**; `combatStripAuditRows` treats them as map-ambient **ok** (no combat-kind warn). Rebuild was **365113** bytes (ambient); now **367181** with aim_fire kinds.
- Smoke: `node clip_smoke.js` green (ambient/tile_loop asserts).

**Honest limits:** Placeholder crops + procedural drone — not final Map Workshop authored ambient. Sibling smoke sheets 002–005 unused (same layout).

**Next:** Map Workshop / engine bind table (building id → overlays); authored neon-flicker + vent-sized smoke; optional `lattice.ambient.pack.v1` index.

## Shipped: walk retarget batch 1 (PRIORITY)

**Why:** Shared walk is a mannequin motion placeholder — units still look like the pack6 silhouette colors in-game. Need unit-specific walk strips that keep Forge DIR_ORDER and look like THAT unit.

**What:**
- Script: `scripts/retarget_walk.py` (poteto — silhouette-guided color transfer from idle → walk alpha mask; feet-anchored uniform scale; nearest opaque sample; keep walk alpha).
- Outputs: `samples/retargeted_walks/{unitId}_walk_84x84_f9.png` + `*_clip.json` (lattice.clip.v1, layout `dirs-rows`, 756×672, 9×8, fps 8) + `qa_*.png` + `BATCH.md`.
- Forge mirror: `pixel-forge-app/public/shared_clips/retargeted/` (PNG+JSON).
- DIR_ORDER **copied** from `shared_walk_84x84_f9.json` / Forge `SHEET_DIR_ORDER` (N-first) — `labelSource:"forge"`. Not invented.
- Batch units (no ownWalk): `18f56b83_231e16eb`, `28b513aa_7d38d143`, `44cda66e_e35d5c38`, `72d85efc_e5b3d902`, `192e8278_dee4a155` (swapped for `857afbae_2b169d2c` which has ownWalk).

**Verify (`--verify`):** all 5 PASS — sheet 756×672; retarget opaque == mannequin opaque (same mask); mean color dist to idle palette << mannequin palette.

**Honest limits:** Not bone IK. Limb poses follow mannequin silhouette; colors from idle. Fine features may smear where idle ≠ walk pose.

**Next:** Socket/bindings wire (`walkMode` → retargeted path) + hand/weapon layer using `aim_hold_onehand_sockets.json`. Scale walk batch to full roster.

---



---

## Shipped: aim hold one-hand sockets (PRIORITY 2)

**Why:** Forge `aimSockets` / weapon grip+muzzle were zone-seeded defaults (`hand_r≈65,50`). Need measured pack7 one-hand aim anchors for combat socket schema.

**What:**
- Script: `scripts/measure_aim_sockets.py` (venv PIL) — idle-row 672×84, cell 84, **Forge DIR_ORDER N-first** (`labelSource:"forge"`). Heuristic dark-weapon blob + aim-tip muzzle (red-tip prefer); **S refined** to left-hand pistol (viewer-right).
- Outputs:
  - `samples/sockets/aim_hold_onehand_sockets.json`
  - Forge mirror: `pixel-forge-app/public/shared_clips/aim_hold_onehand_sockets.json`
  - QA: `samples/sockets/aim_hold_onehand_sockets_qa.png`
- Schema shape: `aimSockets.hand_r` / `hand_l` length-8; `weaponHint.grip` / `muzzle` length-8; coords 0..83.

**South (authoritative):** grip `(56,49)` muzzle `(58,62)` hand_l `(58,48)` hand_r `(34,55)` — weapon-side = left hand / higher x. **8-dir measured** (not S-expanded); S specially refined.

**Confidence:** S/E/SE high; N/NE/SW/W medium (occlusion / free-hand weaker); NW high-ish muzzle tip.

**Not claimed:** `combatReady`. Not wired into `defaultSocketMap84()` / unit bindings yet. Free-hand (`hand_r`) noisier than weapon hand. Two-hand pack1 not remeasured.

**Next:** Wire sockets into Forge combat unit / weapon attach; optional two-hand aim socket pass; idleSockets from unequipped sheet.


## Mastered

- Handoff model: palette indices, iso 1088 contract, `G()` generators, horizontal strips + `frameInfo`, audit-first culture, combine/stripFrom.
- Recover path: extract `<script>`, split on banners (**including multi-line** comment banners — 37 of 76), map to handoff modules, preserve **file concatenation order** (library is 59→61→60, not numeric sort).
- Build: `build.py` + `MODULE_ORDER.txt` + shell marker `/*__LATTICE_JS__*/`.
- Gap vs BD needs: Lattice = FX/iso/intake; **not** character combat/8-dir authoring (Forge owns DIR_ORDER).

---

## Shipped this session

### Source recovery

```
src/
  shell.html
  core_all.js          # sections 0–37
  MODULE_ORDER.txt
  build.py             # also /animation/build.py
  js/15_features.js … 28_audit.js
  js/23_library.js, 25_libfile.js, 24_libraryui.js
  js/29_clip.js        # lattice.clip.v1 + facing-batch scaffold
  js/99_boot.js
```

Also: `recover_sources.py`, `PLAYBOOK.md`, fluency note at
`/home/box/agent-data/agents/e483f6d0-17a7-4095-8c56-be1ac83809e5/notes/lattice-fluency.md`.

### Rebuild status

- **Baseline:** recover from shipped HTML → rebuild was **byte-identical** (351165 bytes). Saved as `lattice.original.html`.
- **Working app:** `lattice.html` / `lattice.built.html` = baseline + clip + facing-batch + combat audit (**367181 bytes** with ambient + aim_fire kinds). Rebuild matches inplace.
- **Smoke:** `node clip_smoke.js` — **green** (clip + facing-batch + `combatStripAuditRows`). Also HTML `new Function(script)` parse OK; sample JSON parse OK.
- **`ui_test.js`:** **still missing** from zip/HTML — no full 205 jsdom suite. Smoke is not a substitute.

### Surgical improvement: `lattice.clip.v1`

**Why:** BD needs walk/aim/fire/hurt/death handoff; PNG strips alone lack frame rects, timing, and clip kind.

**What:**
- `src/js/29_clip.js` — `buildClipManifest` / `exportClipFiles` / Export **Clip** tab / Preview **Export clip** button.
- Kinds: `idle|walk|aim_fire|aim|fire|hurt|death|fx|ambient|tile_loop|custom` (aim/fire → aim_fire).
- JSON includes `rects`, `fps`, optional `holds`/`tickSequence`, `dirs: null` (or user labels), `dirOrderNote` → Art Director / Forge 84×84.
- Sample: `samples/bd_trooper_walk_placeholder_clip.json`.


### Surgical improvement: combat-strip audit checklist (NEW)

**Why:** Verify should catch bad character strips the same way iso catches 1088-px tiles — soft amber only.

**What:**
- `combatStripAuditRows(fi, clip)` in `src/js/28_audit.js` (pure; wired into `auditAsset()` when `fi.n ≥ 2`).
- Rows: strip detected (ok); clip kind fx/custom → suggest walk|aim|fire|hurt|death (warn); non-square cell when combat-ish (warn); facing labels missing → informational ok pointing at Clip facing-batch / Art Director (never invents DIR_ORDER).
- Edge-hug clipping **not** duplicated — existing Frame edges check (#2) already hard-fails border contact.
- `clip_smoke.js` extended with pure-helper asserts (still no jsdom / ui_test).


### Real clip.v1 samples: hurt + death (NEW)

**Why:** Brian approved packaging existing Forge hurt pose + Falling_Back_Death SE into Lattice samples (attack packs hunted separately — do not wait).

**What (samples only — no app code):**
- `samples/bd_hurt_84_facing_batch/` — 8 user-labeled facings (N,NE,E,SE,S,SW,W,NW), `labelSource:"user"`, kind `hurt`, cell **84×84**, 1 frame/facing. Per-facing `*_strip.png` + `*_clip.json` + `bd_hurt_84_facing_batch.json` + overview strip 672×84. Source: `pack3/hurt/rotations` (e266df5a…). **Does not claim Forge DIR_ORDER.**
- `samples/bd_death_falling_back_SE_strip.png` + `*_clip.json` — kind `death`, facing SE, **7 frames**, cell **92×92**, strip **644×92**. Source: `raw/aaf91b42…/Falling_Back_Death/south-east/frame_000..006`.

**Verify:** open strip in Lattice **Intake**, or inspect JSON + PNG side-by-side. See PLAYBOOK § samples.

### Smoke harness: `clip_smoke.js` (NEW)

**Why:** Gate clip/facing-batch regressions without waiting for missing `ui_test.js`.

**What:** `/workspace/bd-tools/animation/clip_smoke.js` — Node `vm` + stubs, no jsdom. Covers empty labels → null batch; `N, NE, E` trim/blanks; manifest `format`/`version`/`rects`; batch `labelSource:"user"` and no Forge DIR_ORDER invent; `combatStripAuditRows` (fx warn, square ok, non-square warn, facings info).

**Run:** `cd /workspace/bd-tools/animation && node clip_smoke.js` → all pass.

**Not shipped:** full `ui_test.js` (never in zip).

### Surgical improvement: facing-batch scaffold (NEW)

**Why:** 8-dir production needs N clip manifests from one strip/param set without inventing Forge DIR_ORDER.

**What:**
- Same `29_clip.js` — `parseFacingLabels` / `buildFacingBatch` / `exportFacingBatch`.
- Export → Clip: editable **Facings** list (free text; default empty). **Fill example labels** inserts `N, NE, E, …` as **editable example only** with explicit “not Forge DIR_ORDER” copy.
- **Download facing-batch zip** → one `*_clip.json` + strip PNG per label + `*_facing_batch.json` index. Scaffold **reuses the current strip PNG** for every label (replace per-facing art later).
- Each clip: `facing` + `dirs: [label]` (user-supplied only); `labelSource: "user"` on batch index.
- Samples: `samples/bd_trooper_walk_facing_batch_example.json`, `samples/bd_trooper_walk_placeholder_NE_clip.json`.

**Before → after**

| | Before | After |
|---|---|---|
| Character strip export | PNG / GIF / generic atlas.json | + **clip.json** with frame rects + kind + timing |
| Multi-facing | Manual N× single export | **Facing-batch zip** from user label list |
| 8-dir / DIR_ORDER | Nothing (correct) | Still no Forge order; user labels + Art Director note |
| Rebuild size | 351165 → 356206 (clip) | **367181** (clip + facing + combat audit + ambient + aim_fire) |

---

## Top gaps (8-dir / combat)

1. No character generators (walk/aim/fire/hurt/death) — intake or external art.
2. No multi-row 8-dir packer — and **must not** invent DIR_ORDER (Forge / Art Director).
3. ~~No facing-batch export UI~~ — **scaffold shipped**; still needs per-facing art / Art Director label confirmation.
4. ~~Audit does not yet flag bad combat strips~~ — **soft checklist shipped** (kind / non-square / facings info).
5. No full `ui_test.js` in tree — `clip_smoke.js` only.

---

## Recommended next (for Brian)

1. Confirm facing label strings with Game Art Director (replace example list).
2. ~~Minimal clip smoke~~ — **`clip_smoke.js` shipped**. Full **`ui_test.js`** still absent if recovered later.
3. ~~Optional: combat checklist rows in `auditAsset()`~~ — **shipped** (amber soft warns).
4. ~~Hurt + death Forge samples as clip.v1~~ — **shipped** under `samples/` + `samples/combat_clips/` (aim_fire packaged; attack packs still outstanding).
5. Optional: N-strip intake (one strip per facing) into the same zip path; other attack packs when found.
6. ~~Map ambient scaffold~~ — **shipped** (`MAP_AMBIENT.md` + `samples/map_ambient/`). Point at specific city sheets if cooling-tower base is wrong; authored neon/drone next.

---

## How to continue in 60 seconds

```bash
cd /workspace/bd-tools/animation
python3 build.py --inplace
node clip_smoke.js          # clip + facing-batch assertions (no jsdom)
# open lattice.html → Effects strip → Export → Clip
#   single: Download strip + clip.json
#   batch:  edit Facings (or Fill example → edit) → Download facing-batch zip
```

Do not hand-edit `lattice.html`. Edit `src/`, rebuild.
