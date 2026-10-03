# LATTICE — Black Doctrine playbook

Concrete runbook for the recovered modular tree. Style: poteto-bar — small changes, verify by build/render.

---

## 1. Open / run

```bash
# No server required
xdg-open /workspace/bd-tools/animation/lattice.html
# or: python3 -m http.server 8765  (then browse /lattice.html)
```

Self-contained: no network, no deps. `file://` works.

Shipped baseline (pre-clip uplift) is preserved at `lattice.original.html`.

---

## 2. Source layout & build

```
animation/
  lattice.html              # working app (rebuild target)
  lattice.original.html     # byte-identical recover baseline
  lattice.built.html        # last build.py output
  build.py                  # concatenates src/ → html
  recover_sources.py        # re-split a shipped html → src/
  PLAYBOOK.md / STATUS.md / LATTICE_HANDOFF.md
  clip_smoke.js             # Node smoke for 29_clip (not full ui_test)
  samples/                  # clip.v1 examples
  src/
    shell.html              # HTML + Cyanotype CSS; JS marker /*__LATTICE_JS__*/
    core_all.js             # math → juice (sections 0–37)
    MODULE_ORDER.txt
    js/
      15_features.js … 28_audit.js
      23_library.js / 25_libfile.js / 24_libraryui.js   # file order: 59→61→60
      29_clip.js            # lattice.clip.v1 + facing-batch scaffold
      99_boot.js            # MUST be last
```

```bash
cd /workspace/bd-tools/animation
python3 build.py                 # → lattice.built.html
python3 build.py --inplace       # → lattice.html
python3 recover_sources.py lattice.original.html   # only if src/ lost
```

**Boot order matters.** `99_boot.js` last. TDZ/`X is not defined` usually means a module landed after something that reads it at top level — move init onto `app`.

### Rebuild match status

| Artifact | Status |
|---|---|
| Recover from `lattice.original.html` → rebuild | **Byte-identical** to original (351165 bytes) |
| Current `lattice.html` | Original + `29_clip.js` (clip.v1 + facing-batch + ambient kinds) + combat audit rows + Clip tab + boot hook (**367181 bytes**, intentional) |

---

## 3. Tests

`ui_test.js` (183–205 jsdom tests) is **not** in the zip/HTML. Missing until recovered from another archive — **do not claim a full suite restore**.

### Clip / facing-batch smoke (shipped)

Loads `src/js/29_clip.js` (+ pure helper from `28_audit.js`) in a Node `vm` with canvas/DOM stubs. Asserts `parseFacingLabels`, `buildClipManifest`, `buildFacingBatch`, `aim_fire` kind/aliases/sample (empty → no batch; `N, NE, E` trim/blanks; `lattice.clip` v1 + rects; `labelSource:"user"`; no Forge DIR_ORDER invent), and `combatStripAuditRows` (strip gate, fx→kind warn, non-square combat warn, facings informational).

```bash
cd /workspace/bd-tools/animation
node clip_smoke.js
# expect: clip_smoke: N passed, 0 failed
```

### HTML parse smoke (no jsdom)

```bash
node -e '
const fs=require("fs");
const h=fs.readFileSync("lattice.html","utf8");
const m=h.match(/<script>([\s\S]*)<\/script>/);
new Function(m[1]);
console.log("parse OK");
'
```

When `ui_test.js` returns: `node ui_test.js` (needs jsdom; use `url:'http://localhost/'`).

---

## 4. Add a generator

One object literal — UI builds from `params`:

```js
G({
  id:'fx.example', group:'Effects', label:'Example', tile:'none',
  size:(p)=>[p.sz*p.frames, p.sz],
  params:[
    pEnum('sz','Frame size',[32,48,64,96],64),
    pInt('frames','Frames',2,16,8),
    pFlo('amount','Amount',0,1,0.5,0.05),
    pIdx('col','Colour',13), pSeed()
  ],
  draw(b,p,pal){ /* b.set(x,y,pal[i]) — palette INDICES, never hex */ }
});
```

Put Effects generators where peers live (`core_all.js` early sheets, or `26_fx2.js` / `27_beam_text.js` / `22_plume.js`). `installEdgeFade()` wraps Effects automatically.

Rebuild + open + generate one frame. Do not trust reasoning alone.

---

## 5. Strip / combine workflow (character clips)

1. Generate an Effects strip (`frames` ≥ 2) — or intake a sheet and repair.
2. Preview: player panel, `` ` `` live mode, scene board.
3. **Combine** (`mdCombine`): overlay (FX on FX) or sequence (charge→fire). Reconcile mismatched lengths with LCM (capped).
4. Per-frame holds (inspector): prefer holds over duplicating frames in the atlas.
5. **Export clip** (Export → Clip, or Preview → Export clip):
   - `*_strip.png` — horizontal strip
   - `*_clip.json` — `lattice.clip.v1` (rects, fps, holds, kind)
6. **Facing batch** (same Clip tab):
   - Enter facing labels as free text (comma / newline). Field starts **empty**.
   - Optional **Fill example labels** inserts `N, NE, E, SE, S, SW, W, NW` — **example text only**; edit to match Art Director. This is **not** Forge DIR_ORDER.
   - **Download facing-batch zip** → per-label `*_clip.json` + strip PNG + `*_facing_batch.json` index.
   - Scaffold reuses the **current** strip pixels for every label; swap in per-facing art later.
   - Each clip sets `dirs: [yourLabel]` with `labelSource: "user"` on the batch index — never claims Forge order.
7. **Audit** (inspector): multi-frame strips get soft combat-clip rows (kind / cell square / facing labels info). Amber = needs attention; no Forge DIR_ORDER invent.
8. Library: save params+palette (not just pixels); Export library is the real backup.

### Clip kinds for Black Doctrine combat

`idle | walk | aim_fire | aim | fire | hurt | death | fx | ambient | tile_loop | custom`

Prefer **`aim_fire`** (Forge combatSchema). `aim` / `fire` are aliases → export as `aim_fire`. Defaults: walk/idle/ambient **loop**; aim_fire/hurt/death **non-loop**. Soft audit budgets: aim_fire 3–11, hurt 2–3, death 4–6.

One **facing per file** (or N files via facing batch). For 8-dir, labels are **user / Art Director supplied** — **do not invent Forge DIR_ORDER in Lattice** (see `dirOrderNote` / batch `labelSource`).

---


---

## 5b. Samples (real Forge → clip.v1)

Under `samples/`:

| Path | Kind | Cell | Frames | Notes |
|---|---|---|---|---|
| `combat_clips/shared_aim_fire_84x84_f11_*` | **aim_fire** | 84×84 | 11 × 8 dirs-rows | Forge shared sheet; `labelSource:forge` N-first; loop false |
| `combat_clips/hurt/` | hurt | 84×84 | 1 per facing | Normalized facing batch (`loop:false`); labels **user** |
| `combat_clips/bd_death_falling_back_SE_*` | death | 92×92 | 7 | SE death; loop false (7f soft-budget amber) |
| `bd_hurt_84_facing_batch/` | hurt | 84×84 | 1 per facing | Original location (also under combat_clips/hurt/) |
| `bd_death_falling_back_SE_strip.png` + `*_clip.json` | death | 92×92 | 7 | Original SE Falling_Back_Death; strip 644×92 |
| `bd_trooper_walk_placeholder_*.json` | walk | 64×64 | 8 | Earlier FX placeholders (no PNG strip in tree) |
| `map_ambient/bd_map_smoke_vent_*` | ambient | 64×64 | 12 | Map smoke loop; `loop:true` fps 7; see `MAP_AMBIENT.md` |
| `map_ambient/bd_map_drone_orbit_*` | ambient | 32×32 | 8 | Procedural placeholder drone |
| `map_ambient/building_base_coolingtower.png` | — | — | — | Static base from `bsheet_040_14_2.png` |

**Open / verify in Lattice**

1. `xdg-open lattice.html` (or http.server).
2. **Intake** (toolbar) → drop a sample strip PNG (`*_strip.png` or the death strip). Confirm cell size / colours, then Preview player to scrub frames.
3. Or open the matching `*_clip.json` beside the PNG: check `format`/`version`/`kind`/`rects`/`fps`/`facing`/`dirs` and that `labelSource` on the hurt batch is `"user"`.
4. Export → Clip is for *authoring* new manifests from the current canvas; these samples are already packaged for engine handoff.

Do **not** treat hurt batch label order as Forge DIR_ORDER — Art Director owns that.

## 6. Export formats that matter for game handoff

| Format | Use |
|---|---|
| **`lattice.clip.v1`** | Character/combat **or** map ambient strips: PNG + frame rects + kind + timing (`ambient`/`tile_loop` + `loop`) |
| **`lattice.bundle.v1`** | Full asset pack: palette, params, atlas, iso constants (1088-px check) |
| **`lattice.building.v1`** | Building states + `BuildingSprite.ts` |
| **`lattice.library.v1` / `.index.v1`** | Library backup / external tool index |
| PNG / sheet+JSON / indexed+palette / GIF / ZIP | Ad-hoc art & review |
| TS / GLSL / Godot 4 stubs | Engine glue |

Engine path for units: **clip.v1 per anim×facing**, then Forge packs 8-dir sheets.

---

## 7. Black Doctrine gap list (honest)

Lattice is strong at: procedural FX strips, iso tiles/ramps/autotile, intake/repair, audit, combine, building states, palette-index workflow.

**Weak / missing for character combat:**

| Gap | Notes |
|---|---|
| No walk / aim / fire / hurt / death generators | FX only; characters are intake or external |
| No first-class 8-dir sheet layout | Horizontal strips only; no DIR_ORDER (correct — Forge owns it) |
| No bone/rig or onion across facings | Single-strip preview |
| No dedicated muzzle / reload / crouch clips | Closest: `fx.sparks`, `fx.impact`, `fx.beam`, combine+sequence |
| Clip metadata was missing | **Shipped** via `lattice.clip.v1` + facing-batch zip |
| Full `ui_test.js` absent | `clip_smoke.js` gates clip/batch; no 205-test suite |

---

## 8. Recommended first improvements (robustness)

**Done (this session):** `lattice.clip.v1` export — strip + JSON with rects/fps/holds/kind; Clip tab + player button; `dirs:null` + Art Director note.

**Done (facing batch):** Export → Clip facing list + zip of N `clip.v1` (+ PNGs) + batch index; labels user-supplied; example fill is editable non-Forge text. See §5 step 6.

**Done (smoke):** `clip_smoke.js` — Node asserts for parseFacingLabels / buildClipManifest / buildFacingBatch. Still no full `ui_test.js`.

**Done (combat audit):** `combatStripAuditRows` in `28_audit.js` — when `frameInfo.n ≥ 2`, soft amber for fx/custom kind and non-square combat cells; informational facing-labels row (no DIR_ORDER invent). Edge hug stays on existing Frame edges fail. Smoke covers the pure helper.

**Done (Forge samples):** real `hurt` 8-dir facing-batch + `death` Falling_Back_Death SE under `samples/` (see §5b). Attack packs still external.

**Done (combat_clips / aim_fire):** `aim_fire` kind + aliases; packaged `samples/combat_clips/`; soft frame budgets; `scripts/package_combat_clip.py`. Not combatReady.

**Next 1–2 (pick in order):**

1. **Confirm labels with Game Art Director** — replace example facing strings; optional N-strip intake (one PNG per facing) into the same zip path.
2. Optional: holds-sum vs fps readability row; or wire Intake “open sample” shortcuts for `samples/bd_hurt_*` / `bd_death_*`.

Rationale: facing-batch unblocks packaging without fighting Forge conventions; audit makes Verify catch combat-strip mistakes the same way iso already catches 1088-px tiles.

---

## 9. House rules

- Do **not** edit `lattice.html` by hand — edit `src/`, `python3 build.py --inplace`.
- Palette **indices**, not colours.
- Integer scale only for pixel art.
- Verify by rendering / tests, not vibes.
- Comments explain *why* (failure prevented).

---



---

## Map / tile ambient

Facing-agnostic building/city overlays (smoke, flicker, drones). **No character DIR_ORDER.**

- Design: [`MAP_AMBIENT.md`](./MAP_AMBIENT.md)
- Samples: `samples/map_ambient/` (smoke strip + clip, cooling-tower base, QA, optional drone)
- Export → Clip kind **`ambient`** (or **`tile_loop`**) after rebuild

```bash
cd /workspace/bd-tools/animation
# inspect sample
ls samples/map_ambient/
# Export→Clip can tag kind ambient once lattice.html rebuilt
python3 build.py --inplace
node clip_smoke.js
```

## Walk retarget (poteto)

Per-unit walk strips from canon shared walk + idle appearance.

```bash
# Default batch of 5 (no-ownWalk units); always writes verify_stats.json
/workspace/pixel-forge-sheets-venv/bin/python \
  /workspace/bd-tools/animation/scripts/retarget_walk.py --verify

# Specific units
/workspace/pixel-forge-sheets-venv/bin/python \
  /workspace/bd-tools/animation/scripts/retarget_walk.py --verify \
  --units 18f56b83_231e16eb 28b513aa_7d38d143
```

Inputs: `public/shared_clips/shared_walk_84x84_f9.png` + JSON (dirOrder/feetByDir), unit idle `*_idle_*_84x84.png` via `unit_bindings.json`.

Outputs: `samples/retargeted_walks/` and copy to `public/shared_clips/retargeted/`.

Do **not** invent DIR_ORDER — script reads Forge shared walk JSON. Method is silhouette color transfer, not IK.

