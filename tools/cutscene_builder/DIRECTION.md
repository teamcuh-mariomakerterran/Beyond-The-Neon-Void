# Cutscene Direction Guide — Black Doctrine / PARALLAX (v1.8-bd+)

**App:** `cutscene-builder.html` · **Playbook:** `PLAYBOOK.md` · **Default stage:** 320×180 @ 30 fps  
**Audience:** agents and Brian authoring Nox-Aster cinematics in this builder only.  
**Rule:** do not invent fields. Every recipe below maps to verified JSON keys from the source.

---

## 0. Why v1 felt flat (confirmed)

1. **Layer order bug.** Layers are stored **front-first** (index `0` nearest the eye). The renderer draws **back → front**. v1 `generate_all.py` passed plate lists like `[bg_2, layer-1, far_city, FULL_CITY]` into `parallax_stack`, which reverses to put **FULL_CITY at index 0** with `parallax≈1.55`. That opaque 2048×1024 plate covered every other plane; camera pan only slid art that was **behind** an image already filling the screen — exactly Brian’s complaint.
2. **Monotone right-pan.** Most shots used `panX > 0` with little zoom variety; consecutive dialogue shots reused the same nudge.
3. **Unused depth tools.** Rare `speedX` drift, almost no true foreground framing (transparent / silhouette), little `blur`/`bright` atmospheric falloff, no band-sliced depth from flat plates, shake/flash underused except a few action beats.
4. **Opaque-on-opaque stacking.** Nearly all `backgrounds/*.png` are 100% opaque. Stacking multiple full-frame opaques can never show parallax between them — only the frontmost is visible.

**Hard rule:** a full-frame opaque image may only be the **rearmost** layer (highest index). Everything in front must have meaningful transparency, be a partial cutout, or be a band-slice / prop / character / FX / text / panel.

---

## 1. Capability catalog (what the app can do — use it)

Verified against `cutscene-builder.html` / PLAYBOOK §4.

### Layers (`shot.layers[]`, front-first)
| Capability | Fields | Notes |
|------------|--------|-------|
| Kinds | `kind` | `image` \| `anim` \| `solid` \| `text` \| `panel` \| `distort` |
| Pose | `x`,`y`,`scale`,`opacity`,`anchor` | `anchor`: `top`\|`center`\|`bottom`; **−y is up** |
| Flip | `flipH`,`flipV` | Face characters toward each other |
| Parallax | `parallax` | Multiplies camera pan (~0.05 sky → ~1.6 FG) |
| Drift | `speedX`,`speedY` | px/sec continuous (train windows, fog) |
| Tile | `tileX`,`tileY` | Seamless scroll plates |
| Bob | `bobAmp`,`bobSpeed` | Idle life |
| Grade per layer | `tint`,`tintAmt`,`bright`,`sat`,`contrast`,`hue`,`blur` | Atmospheric perspective |
| Blend | `blend` | `source-over`, `lighter` (add), `screen`, `multiply`, `overlay`, `soft-light` |
| Anim sheet | `frameW/H`,`frameCount`,`fps`,`loop`,`pingpong`,`delay`,`hideBefore`,`holdLast`,`startFrame` | GIFs auto-slice on import |
| Motion blur | `mblur`,`mblurSamples` | Fast moves |
| Hit-stop | `stopScale` | `1` = keep playing through stop |
| Mask / attach / group | `maskLayer`,`maskInvert`,`maskSource`,`attach`,`group` | |
| Text | `text`,`reveal`,`revealDelay`,`fontSize`,`wrap`,`wrapW`,… | `reveal` = **chars/sec**; `0` = instant |
| Panel 9-slice | `boxW/H`,`insL/R/T/B`,`edgeMode` | Dialogue chrome |
| Distort | `fxMode` `shimmer`\|`ripple`\|`warp` + `amp`,`freq`,`speed`,`band`,`fxW/H`,`falloff` | Heat / glitch |
| Keyframes | `k[field]=[{t,v,e,c?}]` | `e`: `linear`\|`in`\|`out`\|`inout`; optional cubic `c` |

**No camera rotation / Dutch angle field** — suggest unease via `fx.chroma`, `fx.scan`, distort warp, asymmetric framing, or slight `panY` drift instead.

### Camera (`shot.cam`)
| Field | Role |
|-------|------|
| `panX`,`panY` | Scene travel over shot (px); eased |
| `zoom0`→`zoom1` | Push / pull |
| `ease` | `linear` \| `in` \| `out` \| `inout` (quadratic; default `out`) |
| `shake`,`shakeFreq`,`shakeDecay` | Impact; use sparingly |
| `follow`,`followAmt`,`followX`,`followY` | Track a layer id |
| `k` | Keyframe any cam field |

Math: `camX = -panX * ease(t/dur)`; layer adds `camX * parallax`. Positive `panX` pans camera right (layers shift left).

### Shot / sequence
`dur` (sec), `bg`, `tin` (`cut`\|`fade`\|`crossfade`\|`flash`\|`wipeL/R/U/D`\|`slideL/R/U`\|`iris`\|`dissolve`), `stops`, `audio[{t,auId,vol}]`, `events`, `markers`, `branch`, `next`, `groups`, `fx` grade.

### Grade (`shot.fx`)
`bright`,`contrast`,`sat`,`hue`,`tint`,`tintAmt`,`vignette`,`scan`,`grain`,`chroma`,`bars` (letterbox), `flash`,`flashDur`,`flashColor`.

### Audio
Cues in **seconds**; embed compact mono WAV in `.parallax.json`. Prefer VO from `assets/audio/dialog_lines`, ambience/SFX from `assets/audio/newest_fx` + root `audio/`.

### Export
`.parallax.json` (editability + dataURLs) · `.cutscene.json` (engine recipe) · WebM · PNG zip · sheet. Bake needs a browser.

**v1 unused / underused:** true FG framing, band-sliced depth, left truck / vertical tilt / holds / cuts as coverage, `ease:inout` on travel, layer `blur`/`bright` falloff, `speedX` multi-rate trains, distort warp, flash+shake once, shot/reverse-shot cuts, reading-speed dialogue holds.

---

## 2. Research highlights (cited)

### Multiplane / parallax
- Disney Multiplane separates FG / mid / BG planes; nearer planes move more; distant stay relatively still. Atmospheric perspective: distant layers lighter, less saturated, hazier.  
  https://www.waltdisney.org/sites/default/files/2018-08/WDFMMultiplaneEducatorGuide.pdf  
  https://vectree.io/pdf/c/multiplane-camera-engineering
- Multiplaning / trucking for game-style parallax: nearer panoramas move faster; composite back-to-front.  
  https://media.disneyanimation.com/uploads/production/publication_asset/46/asset/multirama_1997.pdf
- 2D multiplane camera tools (truck-in with parallax vs zoom without):  
  https://github.com/RxLaboratory/Duik/wiki/camera-2d
- Perspective + ortho hybrid for parallax layers in engines:  
  https://www.gamedeveloper.com/programming/combining-perspective-and-orthographic-camera-for-parallax-effect-in-2d-game

### Film grammar → games
- Shot sizes as who/what/where (ELS→ECU), establishing vs coverage, reaction/insert, cutting on action, 180° / 30° rules, J/L-cuts:  
  https://writingwithacamera.com/Handouts/Cinematic-Language  
  https://www.adobe.com/creativecloud/video/discover/what-is-the-180-degree-rule.html  
  https://human.libretexts.org/Courses/Nashville_State_Community_College/Tokyo_in_Film/04%3A_Post-Production/4.03%3A_Editing_and_Animation/4.3.04%3A_Continuity_Editing
- Pace from dramatic turns, silence, and holds — not metronomic short cuts:  
  https://zksnyder.com/pace-scene-in-edit/

### 2D game cinematics
- Hyper Light Drifter: mix of short video + **in-engine** timed sequences (camera locks, particles, ordered events).  
  https://www.reddit.com/r/gamemaker/comments/73qlbh/how_did_hyper_light_drifter_make_its_cut_scenes/
- Katana Zero: dialogue tags drive animation/shake; interruptible lines keep action energy in talk scenes.  
  https://web.archive.org/web/20210930174946/https:/www.rockpapershotgun.com/how-katana-zero-brought-action-into-cutscenes

### Easing & dialogue timing
- Prefer ease-in/out (inertia); linear feels robotic (Lasseter principle via JCGT / practical easing guides).  
  https://jcgt.org/published/0011/03/02/paper.pdf  
  https://morphic.com/ai-glossary/easing-easing-functions  
  https://sunstrikestudios.com/en/blog/timing_in_animation/
- Auto-advance dialogue ≈ chars/CPS + fixed floor; VO duration wins when present.  
  https://vndev.wiki/Autoplay

**Reference games for look (study, don’t copy IP):** Hyper Light Drifter, Katana Zero, Octopath Traveler, Eastward, Sea of Stars, Chrono Trigger / FFVI, Celeste, Blasphemous, Owlboy, Ori — multiplane depth, letterbox, restrained pans, reaction holds, sparse shake.

---

## 3. Depth stack recipe (map to this app)

Store layers **front → back**. Suggested parallax bands:

| Plane | `parallax` | What belongs here | Atmosphere |
|-------|------------|-------------------|------------|
| FG framing | **1.25–1.60** | Pillars, cables, foliage, railings, crowd silhouettes, **erased** plates (`bg_*erased*`), structure cutouts | `bright` 0.35–0.7, optional `blur` 0.5–1.5, `tintAmt` small |
| Character | **0.95–1.10** | Actors, hero props | Full bright; eyelines via `flipH` |
| Near mid | **0.70–0.90** | Local architecture, train interior frame | Slight darken |
| Far mid | **0.35–0.60** | Skyline band, distant structures | `bright` 0.75–0.9, `sat` 0.85, light cyan/amber `tint` |
| Backdrop / sky | **0.05–0.18** | **Only** full-frame opaque plate (or sky band) | Can dim slightly; never cover with another opaque |

### Building depth when art is flat
1. Prefer **already layered** sets: `scene_1_layer_*`, `layer-*`, `md_*`, `bg_*erased*`, `props/structures/*`.
2. Else **band-slice** one opaque with Pillow: sky / horizon / ground strips on a full-size transparent canvas → three parallax rates.
3. Else **composite**: one opaque backdrop + structure cutouts + fog solid (`opacity` 0.08–0.2, `blend` `screen`/`lighter`) + FG erased/silhouette.
4. Fog / particles: low-opacity image or `solid` with `speedX` ≠ 0; smoke FX sheets; distort `shimmer` for heat.

### Opacity gate (authoring)
Before shipping: walk layers front→back; if a layer’s asset is ≥90% opaque and its drawn size ≥ ~90% of 320×180, it **must** be the last image layer (or only opaque). Text/panel/distort may sit in front.

---

## 4. Shot vocabulary → camera recipes

All use `shot.cam`. Prefer **`ease: "inout"`** for travel; **`out`** for settle/push landings; **`in`** for accelerating dread; avoid **`linear`** for camera.

| Intent | Recipe |
|--------|--------|
| **Establishing crane-down** | `panY: 18→`via keys or `panY: 22`, `panX: 28`, `zoom0: 1.12`, `zoom1: 1.0`, `ease: inout`, dur 4.5–6s, `tin: fade` 0.8–1.2 |
| **Slow push-in (emotion)** | `panX: 6–12`, `zoom0: 1.0`, `zoom1: 1.08–1.14`, `ease: out`, dur 3.5–5s |
| **Pull-back reveal** | `zoom0: 1.15–1.25`, `zoom1: 1.0`, `panX: ±20`, `ease: inout` — FG framing exits revealing mid |
| **Truck right** | `panX: 40–70`, `panY: −4..4`, `zoom0≈zoom1`, `ease: inout` |
| **Truck left** | `panX: −40..−70`, same |
| **Vertical tilt / rise** | `panY: −24..24`, small `panX`, hold zoom |
| **Hold / breathe** | `panX/Y: 0`, zoom flat; rely on `speedX` drift + bob |
| **Whip / hard cut** | Next shot `tin: cut` or `flash` 0.12–0.2; large framing change (≥30° feel via x offset / scale) |
| **Impact shake (once)** | `shake: 4–6`, `shakeFreq: 28–36`, `shakeDecay: true`, pair `fx.flash` 0.7–0.9 + `chroma` 1.5–2.5; **one** per scene unless motif demands more |
| **Creeping horror** | Tiny `panX: 2–6`, `zoom0→zoom1` +0.04–0.08 over long dur, `ease: in`, `fx.scan` 0.05–0.12, `grain` ↑, optional distort `warp` |

**Coverage rule:** no two consecutive shots share the same primary move (e.g. truck-right then truck-right). Alternate axis or push/pull/hold/cut.

### Dialogue coverage (shot / reverse-shot)
- Keep **180° line**: A left looking right (`flipH: false`), B right looking left (`flipH: true`); OTS / singles must not flip screen direction.
- Line on A → cut to B reaction (`tin: cut` 0.1–0.15) → back; matching scale band (MCU↔MCU).
- Slow push across the **emotional** line only; other lines hold or micro-drift.
- Panel: open `boxH` with keys ~0.28s; `reveal: 22–28`; `revealDelay` after open; hold = `len(text)/CPS + beat`.

---

## 5. Timing tables

| Element | Formula / default |
|---------|-------------------|
| Typewriter | `reveal` 22–28 chars/s (builder dialogue preset ~26) |
| Hold after typed | `max(1.2, len/CPS + 0.6)` sec; if VO present, `max(hold, vo_dur + 0.35)` |
| CPS reading (auto) | ~18–22 for player read; VO overrides |
| Beat / silence | 0.8–2.0s after last line before cut |
| Location card | Stagger place then region 0.6–1.0s; card shot 3.5–5s |
| Fade tin | 0.5–1.2s establish; 0.25–0.4 emotional; cut for coverage |
| Hit-stop | 0.06–0.12s on impact only |
| Letterbox | `fx.bars` 0.12–0.22 consistent per sequence |
| Grain | 0.06–0.12 story; 0.14–0.22 horror/glitch |

---

## 6. Faction motifs (from c19) → grade

| Motif | `fx` / tin hints |
|-------|------------------|
| Viel | Cyan/orange tint low, clean `wipeL/R` or fade, controlled pans, bars ~0.12 |
| Doctrine | Magenta windows tint, vertical emphasis (`panY`), hymn overlays, silhouettes |
| Library | Pale sat↓, annotation text layers, page-like wipes |
| Verge | Duped layers, mismatched parallax, impossible scale, delayed ghost (`opacity`/`speedX`), broken `dissolve`/`flash` tins, grain↑ |
| QN-0 | Soft bloom tint, contradictory temps, signal flash |

---

## 7. Pre-ship checklist

- [ ] Layer list front→back; **only rearmost** image is full-frame opaque
- [ ] FG framing present and moves faster than mid (`parallax` ≥ 1.25)
- [ ] Parallax rates visibly differ under Play (pan or `speedX` driver exists)
- [ ] Camera moves vary shot-to-shot; easing not `linear`
- [ ] Characters scaled for 320×180, feet planted (`anchor: bottom`), eyelines face
- [ ] Dialogue timed to read/VO; silence held where brief asks
- [ ] Audio cues placed; levels ~0.35–0.7 ambience, ~0.7–1.0 VO/SFX peaks
- [ ] Letterbox/grain/vignette consistent; no magenta key fringes
- [ ] No black/blank frames; cuts don’t pop (match exposure/bars)
- [ ] Saved `*_v2.parallax.json`; preview contact sheet inspected
- [ ] Console clean on load in builder

---

## 8. Authoring API (v2)

Use `tools/author.py` helpers: `depth_stack_v2`, `slice_bands`, `cam_move`, `dialog_dur`, `fg_framing`, `is_opaque_fullframe`. Default generation path is **v2**; pass `legacy=True` for old stack behavior.

---

## 9. v2.1 authoring helpers (procedural + layered)

Implemented in `tools/proc_art.py` + `tools/author.py` + `tools/generate_v2_flagships.py`.

| Helper | Purpose |
|--------|---------|
| `make_pillar` / `make_railing` / `make_sign_pole` | Crisp near-black FG silhouettes (hard edges, transparent canvas). Edge-only; never cover subject. |
| `make_carriage_interior` | Train cabin: opaque walls/seats/rails/floor, **transparent window panes** for streaming scenery. |
| `make_fog_band` | Soft horizontal fog gradient (low alpha). Prefer over smoke sheets. |
| `make_dust_particles` | 1–2px scattered dust/embers. |
| `make_title_card_bg` + `title_layers` | Lower-third scrim + large cinematic title text. |
| `load_char_mcu` | Dialogue characters: magenta-key, NN integer upscale (2×), larger `max_h`. |
| `depth_stack_v2` | Backdrop forced to BACK; reject opaque full-frames in mid/far. |
| `fg_pair` / `add_proc_fg` | Scene-grade FG accents (thin pillar + railing). **Do not** use erased smudge plates as FG. |

### Layered source assets (copied 2026-09-24)

From Brian Drive `parallax and back gorunds` → `assets/backgrounds/layered/`:
- `scene_layers/` — full `scene_1_layer_*` and `scene_2_layer_*` including **erased** alpha variants (true mid/near candidates)
- `skyline_cutouts/` — neon/futuristic skyscraper sprites with alpha
- `fg_buildings/` — transparent satellite/dish props

**Rule:** erased plates are for mid/far depth (with atmospheric tint), **not** as full-frame FG washes. FG = procedural crisp shapes or dedicated cutouts.

### Dialogue coverage recipe
1. Establish two-shot (both visible, eyelines face via `flipH`)
2. Cut to speaker A MCU (favoured, rule-of-thirds; other dimmed/off)
3. Cut to speaker B MCU
4. Emotional line: slow push `zoom0→zoom1` ≥ +0.25
5. Hold silence / pull-back

### Train recipe
Carriage layer (`fg:carriage`) in front → characters seated behind panes → city/skyline streaming at different `speedX` (near pylons ≈ −32, far ≈ −14, sky ≈ −4). Optional `bobAmp` on carriage for sway.

## 10. v2.2 hard fixes (third pass)

### Cast views (`tools/cast_views.json`)
- Solo sheets pack **SE (front) | NW (back)** on an **opaque black matte** with yellow header text.
- Using the whole solo sheet as one MCU asset placed left-of-frame showed the **NW/back half** (and the black matte read as “window frames”).
- **Rule:** load `03_front_se` only. `load_char_mcu` logs sheet/view/cell; never prefer `05_solo_sheet`.

### Zoom / edge coverage
- `zoom0`/`zoom1` must be **≥ 1.0** (`cam_safe` / `ZOOM_FLOOR`).
- Fullplane plates scale with **fill 1.28** so pan+parallax still covers the stage.
- QA (`tools/qa_frames.py`): fail only when content is **inset >12% on both sides** (ignores dark edge pillars).

### Train carriage depth (front-first)
`fg:carriage_pole` (parallax ~1.3) → **characters** → `carriage_seat` → `carriage_wall` (transparent panes) → streaming city → sky.

### Wrong Choir
- Own shelter set: scene_2 sky + ground + skyline cutouts + fog/dust + edge pillars/cables.
- Do **not** reuse carriage wall or solo-sheet chrome.

### FG framing
- Full-height edge pillars, bottom railings, top cables only — never tiny mid-frame glyphs.
- Scene midground neon baked into Drive plates may still read as floating signs (source art limit).

### Verge duplicate
- Second Nyx is a **glitch echo**: tint, chroma, low opacity, `speedX` offset — not an identical twin.

### QA automation
- `tools/qa_frames.py` + full frames at `projects/previews/frames/<scene>/full_*.png` (960×540 NN).
- Gates: edge coverage, zoom floor, char-in-front-of-set, floating small layers, adjacent mid-frame MAD.



---

## 11. Train dialogue OTS recipe (verified 2026-09-24)

Working values for `c6_quiet_conversation_train_v2` (320×180, `fx.bars≈0.14`):

### Coordinate gotcha
Builder `x` is the sprite **left edge**, not center. Use `author.x_from_center(cx, asset, scale)`.

### Two-shot (establish / hold)
- Klixx center-x ≈ 95, Pity ≈ 225, `scale` 0.88–0.95, `feet_y` ≈ -30 (bottom anchor)
- Klixx `flipH=false` (faces right), Pity `flipH=true` (faces left)
- Cam: `truck_right` panX 8–12, zoom 1.02→1.06, `ease:inout`, ~4s, `tin:fade`

### OTS MCU (speaker left / reverse right)
- **Focus:** `scale` 1.30–1.40, `feet_y` **+28** (positive — head under letterbox; feet may leave frame)
- **Other (FG shoulder):** `scale` ~2.1, `feet_x` toward edge (cx 275 / 45), `bright` 0.4, `blur` 1.2–1.3, `opacity` 1.0
- Cam: mild hold zoom 1.06→1.10 (keep dialogue on-screen; zoom crops corners)
- Emotional push: zoom 1.08→1.18 `ease:inout` over ~3.5s — do not exceed ~1.20 or dialogue clips

### Dialogue chrome
- Scrim: full-frame bottom gradient, opacity 0.9, frontmost behind text
- Speaker: anchor bottom, x=28, y=-58, fontSize 9, color `#3ee0d8`, reveal 0
- Line: anchor bottom, x=28, y=-40, fontSize 11, reveal 32, revealDelay 0.12
- Keep lines short (≤ ~28 chars) so mid-shot QA shows the FULL line
- `dialog_dur(..., cps=15, reveal=32, vo_sec=…, beat=1.0)`

### Carriage depth (front→back)
`fg:pole (parallax 1.3)` → chars (1.05) → seat (1.02) → wall panes transparent (0.98) → mid towers `speedX=-52` → far city `-16` → sky `-5`

### Reuse
`author.build_dialogue_scene(...)` + `dialogue_chrome` / `ots_characters` / `two_shot_characters`.

## 12. VN bust dialogue recipe (train v2, revised 2026-09-24)

Replace MCU/OTS body close-ups with a visual-novel bust overlay on a **wide two-shot**.

### Layout numbers (320×180 stage)
| Item | Value |
|------|-------|
| Bust NN scale from 256 source | **0.375** of cropped content (~74×93–104) |
| Speaker layer scale | **1.12** → ~104–116px tall (**~55–64% of stage**) |
| Listener layer scale | **1.00** → ~93–104px tall |
| Bust anchor | `bottom`, **y=0** (flush with stage bottom / dialogue panel bottom) |
| Left bust x | **2** (hug left); right x = `320 - margin - drawn_w` (hug right) |
| Facing | right bust `flipH=true` (inward) |
| Listener bright / sat / opacity | **1.0 / 0.88 / 0.88** (alpha dim ≈88% opacity (~70–75% perceived vs speaker size emphasis); do **not** crush navy art with CSS brightness <1) |
| Speaker bright | **1.0** (speak_scale 1.12 for size emphasis) |
| Camera during dialogue | **zoom0=zoom1=1.0** (pan only — zoom crops bust bottoms) |
| Letterbox `fx.bars` | **0** during dialogue (bars are post-FX and crop busts); ≈0.12 on S1/S5 |
| Dialogue panel | **152×56** dark plate, centered between busts, y=0 bottom; busts drawn **in front** of panel |
| Name plate | **ATTACHED** to panel top (`y=-(panel_h)`), **16px** tall, dark fill + **1px accent border** (Klixx cyan / Pity orange); text near-white **`#e8fbff` / `#fff0e4`**, fontSize 11, outline 1, left (Klixx) / right (Pity) |
| Line | left-aligned inside panel, `fontSize=10`, `wrap=True`, wrapW=`panel_w-16`, pre-wrapped at **0.70×font** advance |

### Helpers
- `author.load_bust(path, name, nn_scale=0.375)` — key + defringe @ full res, NN scale, scrub hot-pink
- `author.bust_dialogue(left, right, speaker=…, line=…, speak_side=…)` → `(layers, panel_asset)`
- `author.apply_set_focus(layers, blur=1.2, already=…)`
- `author.make_dialogue_panel_asset(w, h)`
- `author.make_nameplate_asset(w, h, accent=(r,g,b))` — dark plate + 1px accent border
- `author.measure_mono_wrap(text, font_size, wrap_w)`

### Train beat map (`c6_quiet_conversation_train_v2`)
| Beat | Speaker | Bust file | Listener file |
|------|---------|-----------|---------------|
| S2 | Klixx | `BD_bust256_57_klixx_tired.png` | `BD_bust256_58_pity_tired.png` |
| S3 | P.1.7.Y. | `BD_bust256_58_pity_sad.png` | `BD_bust256_57_klixx_think.png` |
| S4 | Klixx | `BD_bust256_57_klixx_allin.png` | `BD_bust256_58_pity_think.png` |

S1 establish (sharp, bars≈0.12, no busts) → S2–S4 dialogue (blur + busts, bars=0, zoom=1) → S5 silence (blur out, bars≈0.12).

### QA checklist
1. Bust height ≥ ~50% of frame; full head+hair+shoulders visible; no letterbox chin crop
2. Every character of every line visible inside the panel (no overflow onto busts)
3. Listener readable (~70–75% presence via opacity, not near-black)
4. Name plate clearly legible (bright accent text + crisp border), seated on panel top
5. Magenta count (R>150,B>100,G<80) = 0 in bust bboxes; hair edge clean at 3× zoom
