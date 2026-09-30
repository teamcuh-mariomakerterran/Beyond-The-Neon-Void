# Cutscene Builder — Living Playbook (Cutscene Director)

**Canonical path:** `/workspace/bd-tools/cutscene/PLAYBOOK.md`  
**App:** `cutscene-builder.html` (v1.8-bd; brand **PARALLAX**)  
**Human guide:** `cutscene-builder-guide.html` / `.pdf`  
**Scope:** cutscenes only — not Pixel Forge combat characters / lattice animation.

This playbook is the agent-facing source of truth for field names, units, and workflows. Prefer it over re-reading the full guide.

---

## 1. How to open / run

| Item | Detail |
|------|--------|
| Path | `/workspace/bd-tools/cutscene/cutscene-builder.html` |
| Server | **Not required.** Single self-contained HTML; open via `file://` or any static host. |
| Browser | Needed for **preview, authoring UI, WebM, PNG zip, live sync**. |
| Offline | Fully offline. Autosave + shot library use **IndexedDB** in the browser. |
| Demo | **Proj** tab → **Load demo cutscene** (replaces current project with procedural art). |

**Agent note:** You can hand-edit / generate `*.parallax.json` (project) or `*.cutscene.json` (engine recipe) without a GUI, but **visual QA and WebM/PNG bake require a browser**. There is no headless CLI renderer in this folder.

Quick open (from the box):

```bash
# optional local static serve (only if file:// is awkward)
python3 -m http.server 8765 --directory /workspace/bd-tools/cutscene
# then browse http://127.0.0.1:8765/cutscene-builder.html
```

---


## Agent scene pack (v1.8-bd)

Authored batch lives in `projects/*.parallax.json` (see `projects/REVIEW.md`). Generator: `tools/generate_all.py` + `tools/author.py`.

In the builder **Proj** tab:
- **BD scene pack** lists filenames + one-line descriptions (`SCENE_PACK` constant).
- **Import scene pack (multi JSON)** opens multiple `.parallax.json` files (queued).
- **Template from library** scaffolds Location Reveal / Quiet Conversation / Wrong Choir / Mercy Cache as new projects (procedural layers).

Open a project → **▶ Play** to scrub. Do not replace `cutscene-builder.html` with a rewrite — only additive improvements.

## 2. Mental model (two sentences)

> A cutscene is a list of **shots**. A shot is a **stack of layers**. Everything else is a way of saying **when**.

- Time is the only input — scrubbing backwards matches export; nothing accumulates.
- Layer list is **front → back** (index `0` = nearest the eye). Renderer draws **back → front**.
- Parallax alone does nothing; it multiplies **camera pan** (or use per-layer `speedX`/`speedY` drift).

---

## 3. UI map

```
┌──────── header: New / Open / Save / Undo / Redo / ? ────────┐
│ Left          │ Middle (Stage)        │ Right               │
│ Shots list    │ Canvas + guides       │ Layer stack         │
│ Assets grid   │ Timeline + key lane   │ Tabs: Layer Shot FX │
│               │ Graph editor          │   Cam Units Proj Out│
└───────────────┴───────────────────────┴─────────────────────┘
```

**Layer add buttons:** `+ Image` · `+ Anim` · `+ Solid` · `+ Text` · `+ Panel` · `+ Distort`

**Tabs:** `layer` | `shot` | `fx` | `cam` | `units` | `proj` | `out` (Export)

---

## 4. Data model (exact field names)

### 4.1 Project (`P`) — save wrapper embeds this

```json
{
  "name": "untitled",
  "w": 320,
  "h": 180,
  "fps": 30,
  "units": [],
  "slots": [],
  "palettes": [],
  "vars": {},
  "shots": [ /* Shot */ ]
}
```

Default resolution presets (Proj tab): GBA 240×160, Advance Wars **320×180**, SNES 256×224, 16:9 384×216, Portrait 270×480.

### 4.2 Shot

| Field | Type | Units / notes |
|-------|------|----------------|
| `id` | string | uid |
| `name` | string | |
| `dur` | number | **seconds** (content length; default `2`) |
| `bg` | hex | solid background fill |
| `layers` | Layer[] | **front-first** |
| `groups` | Group[] | shared transform |
| `stops` | `{t, dur}[]` | hit-stops; `t`/`dur` in **seconds** (content time) |
| `audio` | `{t, auId, vol}[]` | cue times in **seconds**; `auId` → sounds map |
| `events` | `{t, name, data}[]` | engine callbacks; do not affect pixels |
| `markers` | `{t, name}[]` | keyframe snap beats |
| `branch` | `{cond, to}[]` | sequence branches by variable |
| `next` | string\|null | named next shot override |
| `tin` | Transition | plays **at start** of this shot |
| `cam` | Camera | |
| `fx` | Grade | post / screen FX |

**Real timeline length** of a shot = `dur + sum(stops[].dur)` (`shotReal`). Keyframes are authored in **content time** (`curLocal` / `warp`).

### 4.3 Camera (`shot.cam`)

| Field | UI label | Default | Notes |
|-------|----------|---------|-------|
| `panX` | pan x | `0` | px of scene travel over shot; eased by `ease` |
| `panY` | pan y | `0` | |
| `zoom0` | zoom start | `1` | |
| `zoom1` | zoom end | `1` | |
| `ease` | easing | `"out"` | `linear` \| `in` \| `out` \| `inout` |
| `shake` | amount | `0` | |
| `shakeFreq` | frequency | `22` | |
| `shakeDecay` | decay | `true` | fade shake over shot |
| `follow` | follow layer | `null` | layer `id` |
| `followAmt` | follow amount | `1` | 0–1 |
| `followX` / `followY` | screen x/y | `.5` / `.6` | fraction of frame |
| `k` | | | optional keyframe tracks on cam fields |

Render: `camX = -panX * ease(p)`, then each layer adds `camX * parallax`.

### 4.4 Grade / FX (`shot.fx`)

| Field | UI |
|-------|-----|
| `bright`, `contrast`, `sat`, `hue` | colour grade |
| `tint`, `tintAmt` | wash / wash amt |
| `vignette`, `scan`, `grain`, `chroma`, `bars` | screen (letterbox = `bars`; `chroma` = chromatic aberration) |
| `flash`, `flashDur`, `flashColor` | impact flash (fires at shot start) |
| `k` | keyframe tracks |

**FX presets (FX tab):** Clean · Battle impact · Night raid · Heal / calm · Status hex · Story beat.

### 4.5 Transition in (`shot.tin`)

```json
{ "type": "cut", "dur": 0.3, "color": "#000000" }
```

`type`: `cut` | `fade` | `crossfade` | `flash` | `wipeL` | `wipeR` | `wipeU` | `wipeD` | `slideL` | `slideR` | `slideU` | `iris` | `dissolve`  *(no slideD)*

### 4.6 Layer

**Kinds:** `image` | `anim` | `solid` | `text` | `panel` | `distort`

| Field | UI label | Default | Notes |
|-------|----------|---------|-------|
| `kind` | | | see kinds above |
| `name` | name | | |
| `assetId` | (click asset) | null | id into assets map |
| `slot` / `action` | slot / action | null / `"idle"` | role binding |
| `palette` | palette | null | palette id |
| `visible` | eye toggle | true | |
| `x`, `y` | offset x / y | 0 | **pixels**; +x right; **−y is up** |
| `scale` | scale | 1 | |
| `opacity` | opacity | 1 | |
| `anchor` | anchor | `"bottom"` | `top` \| `center` \| `bottom` |
| `flipH`, `flipV` | flip H / V | false | |
| `speedX`, `speedY` | speed x / y | 0 | **px/sec** continuous drift |
| `parallax` | parallax | 1 | multiplies camera pan (~1.6 near → 0.05 sky) |
| `tileX`, `tileY` | tile X / Y | false | |
| `bobAmp`, `bobSpeed` | bob amp / speed | 0 / 1 | sine bob |
| `tint`, `tintAmt` | tint / amt | | |
| `bright`, `sat`, `contrast`, `hue`, `blur` | | 1/1/1/0/0 | |
| `blend` | blend | `"source-over"` | normal / **add=`lighter`** / screen / multiply / overlay / soft-light |
| `color` | colour | | solids |
| `frameW`, `frameH`, `frameCount`, `fps` | frame w/h, count, fps | 32/32/0/12 | anim sheets |
| `loop`, `pingpong` | loop / ping-pong | true / false | |
| `delay` | delay | 0 | seconds before anim starts |
| `hideBefore` | hide before start | true | |
| `holdLast` | hold last frame | true | |
| `startFrame` | first frame | 0 | set `1` to skip pasted grey cell |
| `stopScale` | **ignore hit stop** | 0 | `0` freezes with stop; `1` keeps playing |
| `mblur`, `mblurSamples` | motion blur | 0 / 5 | |
| `group` | group | null | group **name** string |
| `maskLayer`, `maskInvert`, `maskSource` | mask with / invert / use as mask only | | |
| `attach` | attach to | null | ride named attach point |
| **Text** | | | |
| `text` | content | `"TEXT"` | supports `{VAR}` and `\n` |
| `fontMode`, `fontFam`, `fontSize` | font | system / monospace / 16 | `system` \| `bitmap` |
| `textColor`, `outline`, `outlineColor` | | | |
| `align`, `tracking` | align / tracking | center / 0 | |
| `wrap`, `wrapW`, `lineH` | wrap / wrap width / line height | false / 200 / 1.35 | |
| `reveal`, `revealDelay` | reveal chars/s / delay | 0 / 0 | chars **per second**; `0` = instant; dialogue ~26 |
| `glyphW`, `glyphH`, `charset` | | | bitmap font |
| **Panel (9-slice)** | | | |
| `boxW`, `boxH` | box width / height | 200 / 64 | |
| `insL`, `insR`, `insT`, `insB` | insets | 8 | border thickness in px |
| `edgeMode` | edge mode | `"stretch"` | |
| **Distort** | | | |
| `fxMode` | mode | `"shimmer"` | `shimmer` \| `ripple` \| `warp` |
| `amp`, `freq`, `speed`, `band` | | | |
| `fxW`, `fxH`, `falloff` | | | |
| `k` | ◈ diamonds | null | keyframe tracks |

### 4.7 Keyframes

- Stored on object as `obj.k[field] = [{ t, v, e, c? }, ...]` sorted by `t`.
- `t` = **seconds** (content time inside shot).
- `e` = `linear` | `in` | `out` | `inout` (segment uses **outgoing** key’s ease).
- Optional `c` = cubic-bezier `[x1,y1,x2,y2]`.
- Snap tolerance when editing: ~`0.008` s.
- Once a track exists, inspector edits write keys at the playhead (not a constant).

### 4.8 Groups

```json
{ "name": "world", "x": 0, "y": 0, "scale": 1, "opacity": 1, "visible": true, "parent": null, "k": null }
```

Layers reference group by **name** (`layer.group = "world"`). Nest via `parent`.

### 4.9 Units / slots / actions

- **Slot** = role name (`ATTACKER`) → `{ name, unit }` where `unit` is unit id.
- **Unit** = `{ id, name, actions: { fire: Action, ... } }`.
- **Action** = `{ assetId, frameW, frameH, frames, fps, pivotX, pivotY, groundOffsetY, attach }`.
- Layer with `slot` + `action` resolves sheet from the unit manifest (frame size travels with the sheet).

### 4.10 Variables

`P.vars = { "SPEAKER": "CMDR. VOSS", "PLACE": "...", "DAMAGE": "12" }`  
Text substitutes `{NAME}`. Engine export lists variable **names** only; game supplies values at runtime.

---

## 5. Coordinate & timing conventions

| Topic | Convention |
|-------|------------|
| Origin | Top-left of project frame (`w`×`h`) |
| `x` | +right (px), offset before camera/parallax |
| `y` | Added after anchor; **negative y moves up** on screen (title card drifts `y: -2 → -16`) |
| Anchor `bottom` | Feet / ground plant; use for units & ground art |
| Anchor `top` | Skies |
| Anchor `center` | FX / explosions |
| Parallax | ~`1.6` nearest FG → `1.0` subject → `0.3` hills → `0.05` sky |
| Timing | **Seconds** everywhere (`dur`, keys, stops, markers, events, audio) |
| Frames | Only via `fps` (project export fps; anim `fps`; arrow keys step `1/fps`) |
| Camera ease | Applies to pan/zoom progress over `0…dur` |

Placement (simplified):

```
bx = x + speedX*t + camX*parallax + groupOffset.x
by = anchorY(anchor) + y + speedY*t + camY*parallax + bob + groupOffset.y
camX = -panX * ease(t/dur)   // positive panX pans camera right (layers shift left)
```

---

## 6. Shot presets (+ Add shot)

| Preset key | Use when |
|------------|----------|
| `parallax` | Establishing / travel scene (FG→sky stack, pan seeded) |
| `anim` | Isolated FX cut (solid + anim, flash tin, shake) |
| `over` | Copy current shot + anim on top (charge / impact over scene) |
| `dialogue` | Conversation beat (panel + `{SPEAKER}` + typed line, crossfade) |
| `title` | Location card (`{PLACE}` / `{REGION}`, long fade, scrim) |
| `blank` | Empty shot |

**Generate attack scene** (Units tab button): builds Advance → Charge → Impact → Aftermath with markers/events — strong first draft, then edit.

---

## 7. Camera “shot types” (when to use what)

There are no named cinematic camera enums — compose from pan/zoom/shake/follow:

| Intent | Recipe |
|--------|--------|
| Slow push-in | `zoom0→zoom1` slight up (e.g. 1→1.07), `ease: "out"`, small `panX` (~20–30) |
| Pressure / charge | `zoom0` already tight → higher `zoom1`, `ease: "in"`, light `shake` with **decay off** |
| Impact | High `shake` (~5) + decay on; `zoom0` high → `zoom1` 1.0; FX flash + chroma |
| Settle / aftermath | Soft zoom out, low shake, dissolve tin |
| Dialogue tighten | Per-line zoom nudge 1.0 → 1.04 → 1.1 (barely perceptible) |
| Follow subject | `follow` = layer id, `followAmt` 0.3–1, `followX/Y` framing |
| Drift without pan | `panX=0`, set layer `speedX` near→far (−22 … −1.2) |

**Cam helpers:** *Auto‑stagger parallax by depth* · *Auto‑stagger scroll speed*.

---

## 8. Dialogue / beat conventions

1. Prefer shot preset **dialogue** (or library-saved dialogue shot).
2. **Panel** layer: set `insL`/`insR`/`insT`/`insB` to real border px; `boxW` ≈ `0.84*w`, anchor bottom; key `boxH` from small→full over ~0.28s so the box “opens”.
3. **Speaker** text: `{SPEAKER}`, accent color (cyan `#3ee0d8`), above the line.
4. **Line** text: `wrap: true`, `wrapW` slightly under box inner width; `reveal: 26` (chars/s; 20–35 spoken feel); `revealDelay` ~0.35–0.4 after box opens.
5. Define preview vars in **Proj** (`SPEAKER`, etc.).
6. One line per shot (or duplicate shot and change text); nudge zoom each line.
7. Tune reveal **by ear** — if you finish reading before the typewriter, it’s too slow.
8. Markers at line-start / emphasis; events if the game must react (e.g. portrait swap).

Location cards: `{PLACE}` + `{REGION}`, scrim solid, long `fade` tin (~0.8–1s), letterbox `fx.bars` ~0.18–0.22, grain `fx.grain` ~0.1–0.14; tin `type:"fade"` ~0.8–1s.

---

## 9. Authoring workflow (prose brief → cutscene)

1. **Brief → shot list** — name shots, rough `dur` (keep short; cut ~⅓ later).
2. **Proj** — set `name`, `w`/`h`/`fps` (default 320×180@30).
3. **Import art** — drop PNGs/GIFs anywhere (GIFs auto-slice to sheets).
4. **Shots** — add via presets (`parallax` / `dialogue` / `over`…) or Generate attack.
5. **Stack layers** front→back; assign assets; anchor bottom for grounded art.
6. **Depth** — parallax ramp + Cam pan **or** speedX drift; optional auto-stagger.
7. **Camera** — pan/zoom/ease/shake/follow per shot intent (§7).
8. **Timing** — keyframe motion (`K` for position); ease-out by default; markers for shared beats.
9. **Dialogue / text** — panels, reveal, vars (§8).
10. **Impact polish** — tin flash, FX flash, shake, hit-stop + ignore-hit-stop (`stopScale: 1`) on FX only, optional mask flash on target, `events` at contact.
11. **Grade** — vignette/grain/letterbox consistency; FX presets.
12. **Audio cues** (optional) — import sound, + Cue at playhead.
13. **Play / loop region** — `[` `]` around the half-second you’re tuning.
14. **Export** — Save project + engine JSON (and WebM/PNG if needed).
15. **Deliver** — project file + art filenames referenced by engine JSON + note events/vars/slots.

---

## 10. Export / save formats (where files land)

All downloads go to the **browser’s download folder** (or a chosen **File System Access** sync folder). Nothing is written beside the HTML automatically except IndexedDB.

| Action | Filename pattern | Contents |
|--------|------------------|----------|
| **Save project** | `{name}.parallax.json` | `{ version:1, project:P, assets:[{id,name,src,gif}], sounds:[{id,name,src}] }` — **includes image data URLs**; reopen to keep editing |
| **Export cutscene data** | `{name}.cutscene.json` | Engine **recipe** only — `format:"parallax-cutscene"`, asset **filenames**, no pixels |
| **Record WebM** | `{name}.webm` | Real-time MediaRecorder; keep tab focused; upscale 1–6× (default 4×) |
| **PNG sequence** | zip of `####.png` | Offline zip writer; upscale 1–4× |
| **Sprite sheet** | `{name}_sheet_{cols}x{rows}_{w}x{h}.png` | Whole cutscene as one sheet |
| **Batch render** | zip of per-unit sheets | Rebinds a slot across all units |
| **Units manifest** | `{name}.units.json` | Standalone unit/actions export |
| **Live sync** | `{name}.cutscene.json` in chosen folder | Rewrites engine JSON on every change |
| **Shot library** | IndexedDB `library` | Save shot + assets; insert into later projects |
| **Autosave** | IndexedDB `autosave` | Crash recovery prompt on reopen |

**Engine doc shape (from `buildEngineDoc`):**

```json
{
  "format": "parallax-cutscene",
  "version": 1,
  "minor": 1,
  "name": "...",
  "width": 320,
  "height": 180,
  "fps": 30,
  "assets": [{ "key": "<id>", "file": "sky.png", "width": 320, "height": 180 }],
  "sounds": [{ "key": "<id>", "file": "hit" }],
  "slots": [{ "name": "ATTACKER" }],
  "units": [{ "name": "...", "actions": { "fire": {
    "sheet": "tank_fire.png", "frameW": 32, "frameH": 32, "frames": 4, "fps": 12,
    "pivotX": 16, "pivotY": 32, "pivot": { "x": 0.5, "y": 1 }, "groundOffsetY": 0, "attach": {}
  } } }],
  "palettes": [{ "id": "...", "name": "...", "pairs": [["#ff00ff", "#00ffff"]] }],
  "variables": ["SPEAKER", "DAMAGE"],
  "shots": [{
    "name": "Impact",
    "duration": 2.0,
    "background": "#05060e",
    "transition_in": { "type": "flash", "dur": 0.14, "color": "#ffffff" },
    "camera": { "panX": 0, "panY": 0, "zoom0": 1.18, "zoom1": 1, "ease": "out",
                "shake": 5, "shakeFreq": 34, "shakeDecay": true, "follow": null,
                "followAmt": 1, "followX": 0.5, "followY": 0.6, "k": null },
    "grade": { "bright": 1, "contrast": 1.12, "sat": 1, "hue": 0, "flash": 0.9,
               "flashColor": "#ffffff", "flashDur": 0.16, "vignette": 0.5, "scan": 0,
               "grain": 0.16, "bars": 0.16, "tint": "#3ee0d8", "tintAmt": 0, "chroma": 2, "k": null },
    "stops": [{ "t": 0.12, "dur": 0.1 }],
    "groups": [],
    "markers": [{ "t": 0.12, "name": "impact" }],
    "branch": [],
    "next": null,
    "audio": [{ "t": 0.12, "sound": "boom", "volume": 1 }],
    "events": [{ "t": 0.12, "name": "impact", "data": null }],
    "layers": [{ "kind": "anim", "name": "Explosion", "asset": "fx_explosion.png",
                 "parallax": 1, "anchor": "center", "blend": "lighter", "stopScale": 1, "k": null }]
  }]
}
```

Notes: shot `duration` ← `dur`, `background` ← `bg`, `transition_in` ← `tin`, `camera` ← `cam` (fields kept: `panX`, `zoom0`, `shakeFreq`, `followAmt`, …), `grade` ← `fx` (fields kept: `chroma`, `bars`, `flashDur`, …). Layer `assetId` becomes `asset` filename; slotted layers get `slotAction` like `"ATTACKER.fire"`. Audio export uses `sound` + `volume` (not `auId`/`vol`).

For games: ship the **recipe** + PNG assets. For editing later: ship **`.parallax.json`**.

---

## 11. Keyboard shortcuts

| Key | Action |
|-----|--------|
| `Space` | Play / pause |
| `←` / `→` | Step 1 frame (`1/fps`) |
| `,` / `.` | Previous / next shot |
| `K` | Key selected layer **x & y** at playhead |
| `Ctrl/Cmd+Z` | Undo |
| `Ctrl/Cmd+Shift+Z` | Redo |
| `Ctrl/Cmd+S` | Save project |
| `[` / `]` | Loop start / end at playhead |
| Drop PNG/GIF/JSON | Import assets or open project |

Number fields accept maths: `w/2`, `-h*0.25`, `120+8`.

---

## 12. Common mistakes & fixes

| Mistake | Fix |
|---------|-----|
| Nothing moves | Set Cam `panX` **or** layer `speedX` — parallax needs a driver |
| Robotic motion | Ease keys / cam to **out** (fast then settle) |
| Key lands wrong | Move **playhead first**, then change value |
| Hit-stop looks like a glitch | Set layer **ignore hit stop** (`stopScale`) to **1** on FX only |
| Grey first anim frame | set `startFrame` to `1` |
| Sheet garbage / missing row | Fix `frameW` / `frameH`; use show-grid / auto-detect |
| Unit jumps between actions | Units → Pivot from artwork on each action |
| Unit floats | Pivot is on padded box — use feet-from-artwork |
| Magenta / halo BG | Asset ◧ key-out; re-export as **PNG** not JPG |
| Dialogue corners stretch | Match panel insets to border thickness |
| Shimmer while scrolling | Downscale source to true pixel size before import |
| Lost work | Reopen offers autosave restore — then Save project properly |
| First cutscene too long | Cut ~⅓ after first pass |

---

## 13. Delivery checklist (from a Brian prose brief)

- [ ] Shot list named with target durations (total runtime noted)
- [ ] Project `w`/`h`/`fps`/`name` set
- [ ] All required PNGs/GIFs imported; sheets framed correctly
- [ ] Each shot stacked front→back; anchors correct
- [ ] Parallax + pan **or** drift speeds verified (motion visible on Play)
- [ ] Camera pan/zoom/shake/follow matches beat intent
- [ ] Keyframes + easings on all motivated moves; markers on shared impacts
- [ ] Dialogue: panel insets, wrap, reveal rate, `{VARS}` defined
- [ ] Impact: tin + FX flash + shake + stop + `stopScale` on FX; `events` named if game listens
- [ ] Letterbox/grain/vignette consistent across sequence
- [ ] Slots/units wired if roster-swappable
- [ ] Saved `{name}.parallax.json` (editability)
- [ ] Exported `{name}.cutscene.json` (runtime) + listed asset files
- [ ] Optional WebM/PNG proof
- [ ] Notes for Brian: events, vars, slots, total duration, open issues

---

## 14. Browser vs JSON-only

| Task | Browser UI | JSON/files alone |
|------------------|------------------|
| Author / preview / scrub | **Required** | Schema-valid JSON possible but blind |
| Save/load project | Yes | Edit `.parallax.json` directly |
| Engine playback in game | — | **`.cutscene.json` + PNGs** |
| WebM / PNG bake / batch | **Required** | No CLI baker here |
| Live sync to engine | Browser folder picker | Write `.cutscene.json` by hand |

**Bottom line:** Agents can assemble or patch JSON from a brief using this schema, but **Cutscene Director should verify in the builder** before calling a cutscene done.

---

## 15. Mastery checklist (controls covered)

- [x] Shell layout: shots, assets, stage, layers, inspector tabs
- [x] Layer kinds: image, anim, solid, text, panel, distort
- [x] Depth: parallax, speedX/Y, tile, bob, auto-stagger
- [x] Camera: pan, zoom0/1, ease, shake, follow
- [x] Timing: dur (sec), keyframes, graph, onion, loop A/B, solo shot
- [x] Hit-stops + selective `stopScale`
- [x] Transitions (`tin` types)
- [x] FX grade + screen + impact flash + presets
- [x] Groups, masks, attach points, palettes
- [x] Dialogue: panel 9-slice, text reveal, variables
- [x] Units/slots/actions + Generate attack scene
- [x] Markers, events, audio cues, sequence branch/next
- [x] Export: parallax.json, cutscene.json, WebM, PNG zip, sheet, batch, live sync, library
- [x] Shortcuts and maths-in-fields
- [x] Gotchas / troubleshooting

---

## 16. Files in this folder

| File | Role |
|------|------|
| `cutscene-builder.html` | The app (do not replace; minimal edits only) |
| `cutscene-builder-guide.html` | Human user guide |
| `cutscene-builder-guide.pdf` | Same guide PDF |
| `PLAYBOOK.md` | **This file** — agent living playbook |
| `README.md` | One-line pointer for humans/agents |

*Verified against `newLayer` / `newShot` / `newProject` / `buildEngineDoc` / Export UI in `cutscene-builder.html` + guide v1.7 / builder v1.8-bd · Sep 2026.*

---

## 17. Asset pack intake (when Brian dumps art)

Expected drop: large asset pack for the cutscene editor. Until then, only the procedural demo is available.

**Drop target (prefer):** `/workspace/bd-tools/cutscene/assets/`  
Create subfolders on first intake if missing. Full checklist lives in `STATUS.md` in this folder — update that file when assets land.
