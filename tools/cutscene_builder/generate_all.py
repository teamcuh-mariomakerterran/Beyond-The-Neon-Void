#!/usr/bin/env python3
"""Generate Black Doctrine / Nox-Aster .parallax.json scene pack."""
from __future__ import annotations
import sys, json, random
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from author import (
    ROOT, ASSETS, PROJECTS, uid, load_asset, load_char, load_sound_compact,
    new_project, new_shot, new_layer, new_cam, new_fx, new_tin, write_project,
    pick_bg, text_layer, img_layer, parallax_stack, cue, dialog_pool,
)

random.seed(42)
REVIEW = []

def bg(name, max_w=400):
    p = pick_bg(name) if '*' in name or name.endswith('.png') or name.endswith('.jpg') else None
    if p is None:
        cand = ASSETS / 'backgrounds' / name
        p = cand if cand.is_file() else pick_bg('layer-1.png', 'bg_1.png', 'parallax.png')
    return load_asset(p, name=Path(p).stem[:28], max_w=max_w)

def ch(name, max_h=118):
    return load_char(name, prefer='front', max_h=max_h, name=name.split('_', 1)[-1].title())

def struct(name, max_w=180):
    d = ASSETS / 'props' / 'structures'
    p = d / name
    if not p.is_file():
        hits = list(d.glob(name)) if d.is_dir() else []
        p = hits[0] if hits else None
    return load_asset(p, name=p.stem, max_w=max_w) if p else None

def prop(glob, max_w=220):
    hits = sorted((ASSETS / 'props').glob(glob))
    return load_asset(hits[0], name=hits[0].stem[:20], max_w=max_w) if hits else None

def fx_img(glob, max_w=180):
    hits = sorted((ASSETS / 'fx').glob(glob))
    return load_asset(hits[0], name=hits[0].stem[:20], max_w=max_w) if hits else None

def sfx(*names, max_sec=3.0):
    for n in names:
        for base in (ASSETS / 'audio', ASSETS / 'audio' / 'newest_fx'):
            if not base.is_dir():
                continue
            p = base / n
            if p.is_file():
                return load_sound_compact(p, name=n, max_sec=max_sec)
            hits = sorted(base.glob(n), key=lambda x: x.stat().st_size)
            if hits:
                return load_sound_compact(hits[0], name=hits[0].name[:40], max_sec=max_sec)
    return None

def dlg(i=0, max_sec=2.8):
    pool = dialog_pool(16)
    if not pool:
        return sfx('electronic_click.wav', max_sec=1.0)
    return load_sound_compact(pool[i % len(pool)], name=f'dialog_{i}', max_sec=max_sec)

def bars(**kw):
    base = dict(bars=0.12, vignette=0.28, grain=0.08)
    base.update(kw)
    return new_fx(**base)

def stack(plates):
    n = len(plates)
    pvals = [0.05 + 1.5 * i / max(1, n - 1) for i in range(n)]
    return parallax_stack(plates, parallax_vals=pvals)

def save(fname, name, shots, assets, sounds=None, template='?', cast='', notes='', vars=None):
    seen, clean = set(), []
    for a in assets:
        if a and a['id'] not in seen:
            seen.add(a['id']); clean.append(a)
    sounds = [s for s in (sounds or []) if s]
    P = new_project(name)
    P['shots'] = shots
    if vars:
        P['vars'] = vars
    path = PROJECTS / fname
    write_project(path, P, clean, sounds)
    rt = sum(s.get('dur', 2) for s in shots)
    mb = path.stat().st_size / (1024 * 1024)
    REVIEW.append(dict(file=fname, name=name, template=template, cast=cast, shots=len(shots),
                       runtime=round(rt, 1), size_mb=round(mb, 2), notes=notes))
    print(f'  {fname}  {len(shots)}sh  {rt:.0f}s  {mb:.1f}MB')
    return path


def loc_reveal(fname, place, region, plate_names, watcher=None, tint='#3ee0d8'):
    plates = [bg(n) for n in plate_names]
    assets = list(plates)
    sounds = [s for s in [sfx('cyber_boot.wav'), sfx('futuristic_hover_veh.wav', max_sec=2.5)] if s]
    base = stack(plates)
    s1 = new_shot(name='Approach', dur=5.0, bg='#05060e', tin=new_tin('fade', 1.2),
                  cam=new_cam(panX=48, panY=-6, zoom0=1.05, zoom1=1.0, ease='inout'),
                  fx=bars(tint=tint, tintAmt=0.12), layers=[dict(L) for L in base],
                  audio=[cue(0.3, sounds[1], 0.4)] if len(sounds) > 1 else [])
    s2L = [dict(L) for L in base]
    for L in s2L:
        L['speedX'] = 4 if L.get('parallax', 0) > 0.8 else 1.2
    s2 = new_shot(name='Environment', dur=4.5, bg='#05060e', tin=new_tin('crossfade', 0.6),
                  cam=new_cam(panX=22, panY=4, zoom0=1.0, zoom1=1.08),
                  fx=bars(tint=tint, tintAmt=0.18, scan=0.04), layers=s2L)
    s3 = new_shot(name='Name Card', dur=4.0, bg='#05060e', tin=new_tin('fade', 0.5),
                  cam=new_cam(panX=8, zoom0=1.05, zoom1=1.05),
                  fx=bars(tint=tint, tintAmt=0.22, vignette=0.35),
                  layers=[text_layer('{'+ 'PLACE' +'}', name='Place', fontSize=14, y=-28, textColor='#f4fbff', reveal=0.8, revealDelay=0.2),
                          text_layer('{'+ 'REGION' +'}', name='Region', fontSize=8, y=-8, textColor='#8ad4ff', reveal=0.6, revealDelay=0.9)]
                         + [dict(L) for L in base],
                  audio=[cue(0.4, sounds[0], 0.55)] if sounds else [])
    cast = ''
    s4L = [dict(L) for L in base]
    if watcher:
        assets.append(watcher); cast = watcher['name']
        s4L = [img_layer(watcher, name=watcher['name'], x=-100, y=8, scale=1.15, parallax=1.45, anchor='bottom', speedX=16)] + s4L
    s4 = new_shot(name='Watcher', dur=4.0, bg='#05060e', tin=new_tin('crossfade', 0.5),
                  cam=new_cam(panX=16, zoom0=1.0, zoom1=1.12), fx=bars(tint=tint, tintAmt=0.15), layers=s4L)
    save(fname, f'Location Reveal — {place}', [s1, s2, s3, s4], assets, sounds,
         template='c5', cast=cast or 'environment', notes=f'PLACE={place} REGION={region}',
         vars={'PLACE': place, 'REGION': region})


def quiet(fname, title, plate_names, a, b, lines, tint='#6ec8ff', template='c6'):
    plates = [bg(n) for n in plate_names]
    assets = plates + [a, b]
    sounds = [dlg(i) for i in range(min(4, len(lines)))]
    soft = sfx('heal.wav', max_sec=2.0) or sfx('A_soft_futuristic_he_*.wav', max_sec=2.0)
    if soft: sounds.append(soft)
    base = stack(plates)
    est = [img_layer(a, name=a['name'], x=-70, y=6, scale=1.1, parallax=1.4, anchor='bottom'),
           img_layer(b, name=b['name'], x=70, y=6, scale=1.1, parallax=1.4, anchor='bottom', flipH=True)] + [dict(L) for L in base]
    shots = [new_shot(name='Establish', dur=3.5, bg='#080a14', tin=new_tin('fade', 0.8),
                      cam=new_cam(panX=10, zoom0=1.0, zoom1=1.06), fx=bars(tint=tint, tintAmt=0.1),
                      layers=[dict(L) for L in est], audio=[cue(0.2, soft, 0.35)] if soft else [])]
    zoom = 1.06
    for i, (sp, line) in enumerate(lines):
        zoom += 0.03
        Ls = [dict(L) for L in est]
        for L in Ls:
            if L.get('name') in (a['name'], b['name']):
                L['bright'] = 1.1 if L.get('name', '').lower() == sp.lower() else 0.72
        Ls = [text_layer(line, name='Line', fontSize=9, y=68, wrapW=260, textColor='#eef6ff', reveal=0.9, revealDelay=0.55),
              text_layer(sp.upper(), name='Speaker', fontSize=8, y=52, textColor='#ffb84d', reveal=0.25, revealDelay=0.28)] + Ls
        aud = [cue(0.35, sounds[i], 0.75)] if i < len(lines) and i < len(sounds) else []
        shots.append(new_shot(name=f'Line {i+1}', dur=3.8, bg='#080a14', tin=new_tin('cut', 0.15),
                              cam=new_cam(panX=4, zoom0=zoom-0.02, zoom1=zoom), fx=bars(tint=tint, tintAmt=0.08),
                              layers=Ls, audio=aud))
    shots.append(new_shot(name='Silence', dur=3.0, bg='#080a14', tin=new_tin('fade', 0.4),
                          cam=new_cam(panX=6, zoom0=zoom, zoom1=zoom-0.04, ease='inout'),
                          fx=bars(tint=tint, tintAmt=0.06, vignette=0.4), layers=[dict(L) for L in est]))
    save(fname, title, shots, assets, sounds, template=template, cast=f"{a['name']}, {b['name']}",
         notes='Dialog VO compact from dialog_lines.')


def wrong_choir():
    plates = [bg('md_3.png'), bg('layer-3.png'), bg('layer-5.png'), bg('A_war_torn_battlefield_2.png')]
    klixx, pity = ch('057_klixx', 125), ch('058_pity', 125)
    assets = plates + [klixx, pity]
    smoke = fx_img('smoke roll 001.png')
    if smoke: assets.append(smoke)
    sounds = [dlg(i+2) for i in range(4)]
    rain = sfx('Gentle_rain_falling__*.wav', 'Pattering_rain_on_as_*.wav', max_sec=4.0)
    click = sfx('electronic_click.wav')
    for s in (rain, click):
        if s: sounds.append(s)
    base = stack(plates[:3])
    L1 = []
    if smoke:
        L1.append(img_layer(smoke, name='Smoke', x=40, y=-20, scale=0.55, parallax=0.6, opacity=0.35, speedX=-6))
    L1 += [img_layer(klixx, name='Klixx', x=-55, y=8, scale=1.05, parallax=1.5, anchor='bottom'),
           img_layer(pity, name='Pity', x=60, y=8, scale=1.05, parallax=1.5, anchor='bottom', flipH=True)] + [dict(x) for x in base]
    shots = [new_shot(name='Shelter', dur=5.0, bg='#0a0c12', tin=new_tin('fade', 1.0),
                      cam=new_cam(panX=14, panY=-2, zoom0=1.0, zoom1=1.05),
                      fx=bars(tint='#7a8cff', tintAmt=0.15, sat=0.85, vignette=0.4), layers=L1,
                      audio=[cue(0.2, rain, 0.3)] if rain else [])]
    shots.append(new_shot(name='Records', dur=4.0, bg='#0a0c12', tin=new_tin('crossfade', 0.4),
                          cam=new_cam(panX=8, zoom0=1.1, zoom1=1.18),
                          fx=bars(tint='#5cffc8', tintAmt=0.12, scan=0.08, grain=0.15),
                          layers=[text_layer('ARCHIVE // RECOVERED', name='Arch', fontSize=7, y=-70, x=40, textColor='#9ef0c8', opacity=0.55, reveal=0.4),
                                  img_layer(pity, name='Pity', x=30, y=4, scale=1.25, parallax=1.5, anchor='bottom', flipH=True),
                                  img_layer(klixx, name='Klixx', x=-90, y=10, scale=0.95, parallax=1.3, anchor='bottom', bright=0.7)] + [dict(x) for x in base],
                          audio=[cue(0.5, click, 0.5)] if click else []))
    dialogue = [('Klixx', "They weren't soldiers."), ('Pity', 'They still sent the signal.'),
                ('Klixx', 'You know why.'), ('Pity', 'I know what happened because of it.')]
    zoom = 1.15
    for i, (sp, line) in enumerate(dialogue):
        zoom += 0.025
        shots.append(new_shot(name=sp, dur=3.6, bg='#0a0c12', tin=new_tin('cut', 0.12),
                              cam=new_cam(panX=3, zoom0=zoom-0.02, zoom1=zoom),
                              fx=bars(tint='#7a8cff', tintAmt=0.1),
                              layers=[text_layer(line, name='Line', fontSize=9, y=66, wrapW=270, textColor='#eef6ff', reveal=0.85, revealDelay=0.4),
                                      text_layer(sp.upper(), name='Sp', fontSize=8, y=50, textColor='#ff8ad4', reveal=0.2, revealDelay=0.25),
                                      img_layer(klixx, name='Klixx', x=-60, y=8, scale=1.1, parallax=1.5, anchor='bottom', bright=1.1 if sp=='Klixx' else 0.7),
                                      img_layer(pity, name='Pity', x=60, y=8, scale=1.1, parallax=1.5, anchor='bottom', flipH=True, bright=1.1 if sp=='Pity' else 0.7)] + [dict(x) for x in base],
                              audio=[cue(0.3, sounds[i], 0.8)]))
    shots.append(new_shot(name='Unresolved', dur=4.0, bg='#0a0c12', tin=new_tin('fade', 0.5),
                          cam=new_cam(panX=10, zoom0=1.2, zoom1=1.05, ease='inout'),
                          fx=bars(tint='#7a8cff', tintAmt=0.08, vignette=0.45, grain=0.18),
                          layers=[text_layer('…', name='E', fontSize=16, y=20, textColor='#c0d0ff', reveal=0.5),
                                  text_layer('NO RESPONSE IS DESIGNATED CORRECT', name='N', fontSize=6, y=70, textColor='#667788', reveal=0.4, revealDelay=1.0),
                                  img_layer(klixx, name='Klixx', x=-55, y=8, scale=1.0, parallax=1.4, anchor='bottom'),
                                  img_layer(pity, name='Pity', x=55, y=8, scale=1.0, parallax=1.4, anchor='bottom', flipH=True)] + [dict(x) for x in base]))
    save('c8_wrong_choir.parallax.json', 'Wrong Choir — Klixx & Pity', shots, assets, sounds,
         template='c8', cast='Klixx, Pity', notes='Production Ready. Dialog VO wired. Ends unfinished.')


def shared_silence():
    plates = [bg('bg_8.png'), bg('layer-2.png'), bg('layer-4.png'), bg('A_cyberpunk_city_1265508853_2.png')]
    klixx, pity = ch('057_klixx'), ch('058_pity')
    assets = plates + [klixx, pity]
    train, rain = sfx('futuristic_hover_veh.wav', max_sec=3.5), sfx('Gentle_rain_falling__*.wav', max_sec=4.0)
    sounds = [s for s in (train, rain) if s]
    base = stack(plates)
    L = [img_layer(klixx, name='Klixx', x=-40, y=10, scale=0.95, parallax=1.35, anchor='bottom'),
         img_layer(pity, name='Pity', x=45, y=10, scale=0.95, parallax=1.35, anchor='bottom', flipH=True)] + [dict(x) for x in base]
    for layer in L:
        if layer.get('parallax', 0) > 0.5: layer['speedX'] = 3
    shots = [
        new_shot(name='Platform', dur=8.0, bg='#060812', tin=new_tin('fade', 1.5),
                 cam=new_cam(panX=36, panY=-4, zoom0=1.0, zoom1=1.08, ease='inout'),
                 fx=bars(tint='#88a0ff', tintAmt=0.12, vignette=0.4), layers=L,
                 audio=[cue(0.5, train, 0.4), cue(3.0, rain, 0.25)] if sounds else []),
        new_shot(name='Stay', dur=7.0, bg='#060812', tin=new_tin('crossfade', 0.8),
                 cam=new_cam(panX=-20, panY=2, zoom0=1.08, zoom1=1.15),
                 fx=bars(tint='#88a0ff', tintAmt=0.1, vignette=0.45), layers=[dict(x) for x in L],
                 audio=[cue(1.0, train, 0.35)] if train else []),
        new_shot(name='Detail', dur=5.0, bg='#060812', tin=new_tin('fade', 0.6),
                 cam=new_cam(panX=8, zoom0=1.2, zoom1=1.28),
                 fx=bars(tint='#88a0ff', tintAmt=0.08, vignette=0.5, grain=0.15),
                 layers=[img_layer(klixx, name='Klixx', x=-25, y=14, scale=1.35, parallax=1.5, anchor='bottom'),
                         img_layer(pity, name='Pity', x=55, y=14, scale=1.2, parallax=1.4, anchor='bottom', flipH=True, opacity=0.85)] + [dict(x) for x in base]),
    ]
    save('c9_shared_silence.parallax.json', 'Shared Silence — Transit Platform', shots, assets, sounds,
         template='c9', cast='Klixx, Pity', notes='No dialogue. Relationship ambient.')


def voss_intro():
    plates = [bg('bg_2.png'), bg('layer-1.png'), bg('layer-3.png'), bg('A_cyberpunk_city_1197448950_1.png')]
    voss = ch('052_ivory', 130); voss['name'] = 'Voss (stand-in: Ivory)'
    citizen = ch('026_mira', 100)
    assets = plates + [voss, citizen]
    boot, alarm = sfx('cyber_boot.wav'), sfx('alarm_soft.wav', max_sec=2.0)
    sounds = [s for s in (boot, alarm) if s]
    base = stack(plates)
    shots = [
        new_shot(name='Civic Plaza', dur=6.0, bg='#0c1018', tin=new_tin('fade', 1.2),
                 cam=new_cam(panX=40, panY=-8, zoom0=0.95, zoom1=1.05, ease='inout'),
                 fx=bars(tint='#ff9a3c', tintAmt=0.2, bright=1.05), layers=[dict(x) for x in base],
                 audio=[cue(0.4, boot, 0.5)] if boot else []),
        new_shot(name='Among Citizens', dur=5.5, bg='#0c1018', tin=new_tin('crossfade', 0.5),
                 cam=new_cam(panX=18, zoom0=1.05, zoom1=1.12), fx=bars(tint='#ff9a3c', tintAmt=0.15),
                 layers=[img_layer(voss, name='Voss', x=-20, y=6, scale=1.2, parallax=1.5, anchor='bottom', speedX=10),
                         img_layer(citizen, name='Citizen', x=80, y=10, scale=0.9, parallax=1.2, anchor='bottom', opacity=0.9)] + [dict(x) for x in base]),
        new_shot(name='Reputations', dur=6.0, bg='#0c1018', tin=new_tin('dissolve', 0.5),
                 cam=new_cam(panX=6, zoom0=1.15, zoom1=1.22), fx=bars(tint='#ff9a3c', tintAmt=0.18, scan=0.06),
                 layers=[text_layer('PUBLIC SERVANT', name='L1', fontSize=8, y=-60, x=-40, textColor='#ffe0a0', reveal=0.5, revealDelay=0.2),
                         text_layer('SYSTEMS ARCHITECT', name='L2', fontSize=8, y=-40, x=20, textColor='#a0e0ff', reveal=0.5, revealDelay=1.0),
                         text_layer('DISPUTED', name='L3', fontSize=10, y=-15, textColor='#ff6a8a', reveal=0.4, revealDelay=2.0),
                         img_layer(voss, name='Voss', x=0, y=8, scale=1.35, parallax=1.4, anchor='bottom')] + [dict(x) for x in base],
                 audio=[cue(2.0, alarm, 0.35)] if alarm else []),
        new_shot(name='Reconstruction Flash', dur=3.5, bg='#1a0508', tin=new_tin('flash', 0.25, '#ffffff'),
                 cam=new_cam(shake=3, zoom0=1.25, zoom1=1.2),
                 fx=bars(flash=0.6, flashDur=0.2, tint='#ff3040', tintAmt=0.25, chroma=0.4),
                 layers=[text_layer('CASUALTY LIST // REDACTED', name='F', fontSize=7, y=-50, textColor='#ff4455', reveal=0.3),
                         img_layer(voss, name='Voss', x=10, y=6, scale=1.4, parallax=1.5, anchor='bottom', tint='#ff4466', tintAmt=0.25)] + [dict(x) for x in base]),
        new_shot(name='Voss Speaks', dur=7.0, bg='#0c1018', tin=new_tin('fade', 0.4),
                 cam=new_cam(panX=12, zoom0=1.1, zoom1=1.18), fx=bars(tint='#ff9a3c', tintAmt=0.2, vignette=0.4),
                 layers=[text_layer('Truth is not freedom.', name='Q1', fontSize=10, y=-40, textColor='#fff4e0', reveal=0.8, revealDelay=0.3),
                         text_layer('Truth is responsibility.', name='Q2', fontSize=10, y=-18, textColor='#fff4e0', reveal=0.8, revealDelay=1.4),
                         text_layer('Most people do not want it.', name='Q3', fontSize=9, y=6, textColor='#ffc080', reveal=0.7, revealDelay=2.6),
                         img_layer(voss, name='Voss', x=-70, y=8, scale=1.15, parallax=1.4, anchor='bottom')] + [dict(x) for x in base]),
        new_shot(name='Surveillance Geometry', dur=5.5, bg='#0c1018', tin=new_tin('crossfade', 0.6),
                 cam=new_cam(panX=30, panY=-10, zoom0=1.15, zoom1=0.92, ease='inout'),
                 fx=bars(tint='#3ee0d8', tintAmt=0.15, vignette=0.35, scan=0.1),
                 layers=[img_layer(voss, name='Voss', x=0, y=10, scale=0.85, parallax=1.3, anchor='bottom')] + [dict(x) for x in base]),
        new_shot(name='Three Labels', dur=5.5, bg='#05060e', tin=new_tin('fade', 0.5),
                 cam=new_cam(zoom0=1.0, zoom1=1.0), fx=bars(vignette=0.5, grain=0.12),
                 layers=[text_layer('PUBLIC SERVANT', name='A', fontSize=9, y=-30, textColor='#ffe0a0', reveal=0.4, revealDelay=0.2),
                         text_layer('SYSTEMS ARCHITECT', name='B', fontSize=9, y=0, textColor='#a0e0ff', reveal=0.4, revealDelay=1.5),
                         text_layer('DISPUTED', name='C', fontSize=12, y=30, textColor='#ff5080', reveal=0.5, revealDelay=3.0)] + [dict(x) for x in base]),
    ]
    save('c10_voss_intro.parallax.json', 'Boss Intro — Archduchess Elian Voss', shots, assets, sounds,
         template='c10', cast='Voss stand-in: Ivory (052); Mira citizen',
         notes='CAST STAND-IN: no Voss art — using 052_ivory.')


def boss_skeleton():
    plates = [bg('md_5.png'), bg('layer-4.png'), bg('A_war_torn_battlefield_1.png')]
    boss = ch('039_vicar', 130)
    assets = plates + [boss]
    sounds = [s for s in [sfx('alarm_soft.wav'), sfx('cyber_boot.wav')] if s]
    base = stack(plates)
    shots = []
    for i, (name, sub, col) in enumerate([
        ('Public Version', 'Who the world believes', '#ffcc66'),
        ('Personal Version', 'Who they believe they are', '#66ffcc'),
        ('Historical Version', 'What evidence disputes', '#ff6688'),
    ]):
        shots.append(new_shot(name=name, dur=4.5, bg='#08060c', tin=new_tin('wipeL' if i else 'fade', 0.6),
                              cam=new_cam(panX=12+i*4, zoom0=1.0, zoom1=1.1), fx=bars(tint=col, tintAmt=0.15),
                              layers=[text_layer(name.upper(), name='T', fontSize=11, y=-50, textColor=col, reveal=0.6),
                                      text_layer(sub, name='S', fontSize=8, y=-30, textColor='#c0d0e0', reveal=0.5, revealDelay=0.6),
                                      img_layer(boss, name='Boss', x=0, y=8, scale=1.3, parallax=1.45, anchor='bottom', tint=col, tintAmt=0.15)] + [dict(x) for x in base]))
    shots.append(new_shot(name='Arena Thesis', dur=4.0, bg='#08060c', tin=new_tin('crossfade', 0.4),
                          cam=new_cam(panX=20, zoom0=1.05, zoom1=1.0), fx=bars(vignette=0.4),
                          layers=[text_layer('ARENA REFLECTS PHILOSOPHY', name='A', fontSize=8, y=-40, textColor='#ddeeff'),
                                  text_layer('First objective emerges from this shot', name='O', fontSize=7, y=60, textColor='#8899aa'),
                                  img_layer(boss, name='Boss', x=-40, y=6, scale=1.15, parallax=1.4, anchor='bottom')] + [dict(x) for x in base]))
    save('c11_boss_intro_standard.parallax.json', 'Boss Intro Standard — Skeleton', shots, assets, sounds,
         template='c11', cast='Vicar (039) placeholder boss', notes='Reusable Public/Personal/Historical/Arena.')


def mercy_cache(branch='preserve'):
    plates = [bg('md_7.png'), bg('layer-5.png'), bg('bg_6.png')]
    klixx = ch('057_klixx', 120)
    assets = plates + [klixx]
    prop_a = prop('lab_props_sheet.png') or prop('*.png')
    if prop_a: assets.append(prop_a)
    sounds = [dlg(i+5) for i in range(3)]
    end_sfx = sfx('capture_success.wav', 'achievement.wav', max_sec=2.0) if branch=='preserve' else sfx('explosion_small.wav', 'bombaway.wav', max_sec=2.5)
    click = sfx('card_flip.wav', 'electronic_click.wav')
    for s in (end_sfx, click):
        if s: sounds.append(s)
    base = stack(plates)
    L1 = [text_layer('MEDICINE  ·  BANDS  ·  TOYS  ·  TESTIMONY', name='Items', fontSize=7, y=-60, textColor='#c8e8ff', reveal=0.7)]
    if prop_a: L1.append(img_layer(prop_a, name='Cache', x=0, y=-10, scale=0.7, parallax=0.8, anchor='center'))
    L1 += [dict(x) for x in base]
    shots = [new_shot(name='Cache Closeups', dur=4.0, bg='#0a1210', tin=new_tin('fade', 0.8),
                      cam=new_cam(panX=10, zoom0=1.1, zoom1=1.2), fx=bars(tint='#5cffb0', tintAmt=0.12), layers=L1,
                      audio=[cue(0.4, click, 0.5)] if click else [])]
    shots.append(new_shot(name='Recorder', dur=4.5, bg='#0a1210', tin=new_tin('crossfade', 0.4),
                          cam=new_cam(zoom0=1.15, zoom1=1.22), fx=bars(tint='#5cffb0', tintAmt=0.1),
                          layers=[text_layer('A child describes being rescued.', name='Child', fontSize=8, y=55, textColor='#e0ffe8', reveal=0.9, revealDelay=0.5),
                                  img_layer(klixx, name='Klixx', x=-50, y=8, scale=1.2, parallax=1.45, anchor='bottom')] + [dict(x) for x in base],
                          audio=[cue(0.4, sounds[0], 0.75)]))
    shots.append(new_shot(name='Physical Choice', dur=3.5, bg='#0a1210', tin=new_tin('fade', 0.3),
                          cam=new_cam(zoom0=1.2, zoom1=1.25), fx=bars(tint='#ffcc55', tintAmt=0.15, vignette=0.4),
                          layers=[text_layer('ARCHIVE  or  BURN', name='Choice', fontSize=12, y=-20, textColor='#ffe08a', reveal=0.5),
                                  text_layer(f'BRANCH: {branch.upper()}', name='Br', fontSize=8, y=10, textColor='#88aacc'),
                                  img_layer(klixx, name='Klixx', x=0, y=10, scale=1.1, parallax=1.4, anchor='bottom')] + [dict(x) for x in base]))
    if branch == 'preserve':
        shots.append(new_shot(name='Preserve', dur=5.0, bg='#061410', tin=new_tin('fade', 0.5),
                              cam=new_cam(zoom0=1.2, zoom1=1.35, ease='out'), fx=bars(tint='#5cffb0', tintAmt=0.22),
                              layers=[text_layer('FIELD ARCHIVE LOCKED', name='Lock', fontSize=9, y=-40, textColor='#7dffc0', reveal=0.5),
                                      text_layer('Somebody should remember this.', name='Line', fontSize=9, y=55, textColor='#eef6ff', reveal=0.8, revealDelay=1.0),
                                      img_layer(klixx, name='Klixx', x=-30, y=8, scale=1.25, parallax=1.5, anchor='bottom')] + [dict(x) for x in base],
                              audio=[cue(0.3, end_sfx, 0.6)] if end_sfx else []))
    else:
        shots.append(new_shot(name='Destroy', dur=5.0, bg='#1a0804', tin=new_tin('flash', 0.3, '#ff6622'),
                              cam=new_cam(shake=4, zoom0=1.25, zoom1=1.1),
                              fx=bars(tint='#ff4020', tintAmt=0.35, flash=0.4, grain=0.2, chroma=0.3),
                              layers=[text_layer('RECORDS BURN', name='Burn', fontSize=10, y=-40, textColor='#ff6644', reveal=0.4),
                                      text_layer('Somebody should remember this.', name='Line', fontSize=9, y=55, textColor='#ffccaa', reveal=0.8, revealDelay=1.2),
                                      img_layer(klixx, name='Klixx', x=-30, y=8, scale=1.25, parallax=1.5, anchor='bottom', tint='#ff5522', tintAmt=0.35)] + [dict(x) for x in base],
                              audio=[cue(0.2, end_sfx, 0.7)] if end_sfx else []))
    save(f'c12_mercy_cache_{branch}.parallax.json', f'Mercy Cache — {branch.upper()}', shots, assets, sounds,
         template='c12', cast='Klixx', notes=f'Branch={branch}. Dialog VO wired.')


def anera_sketchbook():
    plates = [bg('md_9.png'), bg('layer-3.png'), bg('bg_11.png')]
    pity = ch('058_pity', 110)
    assets = plates + [pity]
    book = prop('living_room_props_sheet.png') or prop('*.png')
    if book: assets.append(book)
    sounds = [s for s in [sfx('card_flip.wav'), sfx('cyber_jack_in.wav'), dlg(8, 2.0)] if s]
    base = stack(plates)
    L1 = [text_layer('a small closed book', name='Hint', fontSize=8, y=60, textColor='#99aabb', reveal=0.6, revealDelay=1.0)]
    if book: L1.insert(0, img_layer(book, name='Book', x=0, y=-5, scale=0.55, parallax=0.9, anchor='center'))
    L1 += [dict(x) for x in base]
    shots = [new_shot(name='Dust & Light', dur=4.0, bg='#12100e', tin=new_tin('fade', 1.2),
                      cam=new_cam(panX=8, zoom0=1.1, zoom1=1.18), fx=bars(tint='#e8d4a8', tintAmt=0.15, vignette=0.45, grain=0.2),
                      layers=L1, audio=[cue(0.5, sounds[0], 0.4)] if sounds else [])]
    for pg in ['cities', 'machines', 'children', 'QN-0', 'unfinished diagrams']:
        shots.append(new_shot(name=f'Page — {pg}', dur=2.8, bg='#12100e', tin=new_tin('wipeR', 0.35),
                              cam=new_cam(panX=4, zoom0=1.15, zoom1=1.18), fx=bars(tint='#e8d4a8', tintAmt=0.12, grain=0.15),
                              layers=[text_layer(pg.upper(), name='Page', fontSize=11, y=-20, textColor='#f5ecd4', reveal=0.5),
                                      img_layer(pity, name='Pity', x=90, y=10, scale=0.85, parallax=1.2, anchor='bottom', opacity=0.7, flipH=True)] + [dict(x) for x in base],
                              audio=[cue(0.15, sounds[0], 0.35)] if sounds else []))
    shots.append(new_shot(name='Annotations', dur=5.5, bg='#12100e', tin=new_tin('fade', 0.4),
                          cam=new_cam(zoom0=1.1, zoom1=1.15), fx=bars(tint='#e8d4a8', tintAmt=0.1, vignette=0.5),
                          layers=[text_layer('AUTHOR UNKNOWN', name='A', fontSize=7, y=-50, textColor='#88aacc', reveal=0.3, revealDelay=0.2),
                                  text_layer('PROBABLE AUTHOR: ANERA VALE', name='B', fontSize=7, y=-30, textColor='#aad4ff', reveal=0.3, revealDelay=1.2),
                                  text_layer('DISPUTED', name='C', fontSize=9, y=-8, textColor='#ff8090', reveal=0.4, revealDelay=2.4),
                                  text_layer('(one hand reaching toward another)', name='F', fontSize=8, y=50, textColor='#ddd0b0', reveal=0.6, revealDelay=3.2)] + [dict(x) for x in base]))
    save('c13_anera_sketchbook.parallax.json', "Anera's Last Sketchbook", shots, assets, sounds,
         template='c13', cast='Pity (observer)', notes='No reward sting. Annotation cycle.')


def first_questions():
    plates = [bg('bg_14.png'), bg('md_4.png'), bg('layer-2.png')]
    echo = ch('029_echo', 115)
    assets = plates + [echo]
    sounds = [s for s in [sfx('cyber_jack_in.wav'), dlg(1), dlg(3), sfx('glitch_stutter.wav')] if s]
    base = stack(plates)
    shots = [new_shot(name='Dark Archive', dur=3.5, bg='#020308', tin=new_tin('fade', 1.0),
                      cam=new_cam(zoom0=1.0, zoom1=1.05), fx=bars(vignette=0.6, grain=0.2, scan=0.1),
                      layers=[text_layer('●', name='Rec', fontSize=14, y=0, textColor='#ff4455', reveal=0.3, revealDelay=1.5)] + [dict(x) for x in base],
                      audio=[cue(1.5, sounds[0], 0.5)] if sounds else [])]
    for i, q in enumerate(['Can I leave?', 'Is fear normal?', 'Do I have a name yet?']):
        shots.append(new_shot(name=f'Q{i+1}', dur=3.5, bg='#020308', tin=new_tin('cut', 0.2),
                              cam=new_cam(zoom0=1.05+i*0.04, zoom1=1.08+i*0.04),
                              fx=bars(tint='#6688ff', tintAmt=0.1+i*0.04, vignette=0.5),
                              layers=[text_layer(f'"{q}"', name='Q', fontSize=11, y=-10, textColor='#d0e8ff', reveal=0.8, revealDelay=0.3),
                                      img_layer(echo, name='Echo', x=-80, y=10, scale=0.9, parallax=1.3, anchor='bottom', opacity=0.5+i*0.1)] + [dict(x) for x in base],
                              audio=[cue(0.35, sounds[1+(i%2)], 0.7)] if len(sounds)>2 else []))
    shots.append(new_shot(name='All Factions', dur=5.5, bg='#020308', tin=new_tin('fade', 0.5),
                          cam=new_cam(zoom0=1.15, zoom1=1.2), fx=bars(tint='#8899ff', tintAmt=0.15, vignette=0.55, grain=0.18),
                          layers=[text_layer('LIBRARY', name='Lib', fontSize=7, y=-55, x=-70, textColor='#cce0ff', reveal=0.4),
                                  text_layer('DOCTRINE', name='Doc', fontSize=7, y=-55, x=0, textColor='#ff88cc', reveal=0.4, revealDelay=0.4),
                                  text_layer('VIEL', name='Viel', fontSize=7, y=-55, x=70, textColor='#ffaa55', reveal=0.4, revealDelay=0.8),
                                  text_layer('"Will somebody answer me?"', name='Final', fontSize=10, y=10, textColor='#ffffff', reveal=0.9, revealDelay=1.5),
                                  img_layer(echo, name='Echo', x=0, y=12, scale=1.1, parallax=1.4, anchor='bottom')] + [dict(x) for x in base],
                          audio=[cue(1.5, sounds[-1], 0.45)] if sounds else []))
    shots.append(new_shot(name='Built on Fear', dur=4.0, bg='#020308', tin=new_tin('crossfade', 0.5),
                          cam=new_cam(panX=16, zoom0=1.1, zoom1=1.0), fx=bars(vignette=0.5),
                          layers=[text_layer('Every faction was built above frightened new people.', name='Thesis', fontSize=8, y=-20, wrapW=280, textColor='#c0d0e8', reveal=1.0)] + [dict(x) for x in base]))
    save('c14_first_questions.parallax.json', 'The First Questions (short cut)', shots, assets, sounds,
         template='c14', cast='Echo (029)', notes='Short cut of 4-min concept.')


def collection_standard():
    plates = [bg('md_2.png'), bg('layer-1.png')]
    assets = list(plates)
    sounds = [s for s in [sfx('coin.wav'), sfx('achievement.wav')] if s]
    base = stack(plates)
    shots = []
    for i in range(6):
        shots.append(new_shot(name=f'Fragment {i+1}', dur=2.5, bg='#081018', tin=new_tin('wipeD' if i else 'fade', 0.35),
                              cam=new_cam(panX=8+i*2, zoom0=1.0, zoom1=1.06), fx=bars(tint='#5cffc8', tintAmt=0.1),
                              layers=[text_layer(f'FRAGMENT {i+1:02d}', name='F', fontSize=10, y=-30, textColor='#9ef0c8', reveal=0.4),
                                      text_layer('distinct location · perspective · no raw dump', name='H', fontSize=7, y=50, textColor='#778899')] + [dict(x) for x in base],
                              audio=[cue(0.2, sounds[0], 0.4)] if sounds and i%2==0 else []))
    shots.append(new_shot(name='Completion Unlock', dur=3.5, bg='#081018', tin=new_tin('fade', 0.5),
                          cam=new_cam(zoom0=1.1, zoom1=1.2), fx=bars(tint='#5cffc8', tintAmt=0.2, vignette=0.4),
                          layers=[text_layer('PRESTIGE CINEMATIC UNLOCKED', name='U', fontSize=8, y=-20, textColor='#d0ffe8'),
                                  text_layer('+ companion · + archive change', name='U2', fontSize=7, y=10, textColor='#88aacc')] + [dict(x) for x in base],
                          audio=[cue(0.3, sounds[1], 0.6)] if len(sounds)>1 else []))
    save('c15_collection_standard.parallax.json', 'Legacy Collection Standard — Skeleton', shots, assets, sounds,
         template='c15', cast='n/a', notes='6 fragment slots + completion.')


def anera_echo():
    plates = [bg('bg_16.png'), bg('layer-4.png'), bg('md_8.png')]
    echo, lumen, nyx = ch('029_echo', 120), ch('021_lumen', 110), ch('005_nyx', 110)
    assets = plates + [echo, lumen, nyx]
    sounds = [s for s in [sfx('glitch_stutter.wav'), sfx('cyber_jack_in.wav'), dlg(6), sfx('Heavy_radio_static_c_*.wav', max_sec=2.5)] if s]
    base = stack(plates)
    shots = [new_shot(name='Recorders', dur=4.0, bg='#050610', tin=new_tin('fade', 0.8),
                      cam=new_cam(shake=1.5, zoom0=1.0, zoom1=1.08), fx=bars(scan=0.12, grain=0.2, chroma=0.25),
                      layers=[text_layer('● ● ●', name='R', fontSize=14, y=-40, textColor='#ff5566', reveal=0.8, revealDelay=0.5),
                              text_layer('recorders at different pitches', name='S', fontSize=7, y=60, textColor='#8899aa')] + [dict(x) for x in base],
                      audio=[cue(0.3, sounds[0], 0.5)] if sounds else [])]
    for i, (c, label) in enumerate([(lumen, 'younger?'), (nyx, 'elsewhere'), (echo, 'incomplete')]):
        shots.append(new_shot(name=f'Fragment {i+1}', dur=3.2, bg='#050610', tin=new_tin('dissolve', 0.4),
                              cam=new_cam(panX=10, zoom0=1.1, zoom1=1.15), fx=bars(tint='#8866ff', tintAmt=0.2, chroma=0.3),
                              layers=[text_layer(label, name='Lab', fontSize=8, y=-55, textColor='#c0a0ff', reveal=0.4),
                                      img_layer(c, name=c['name'], x=-40+i*30, y=8, scale=1.15, parallax=1.4, anchor='bottom', opacity=0.85, tint='#a080ff', tintAmt=0.2)] + [dict(x) for x in base]))
    shots.append(new_shot(name='Stabilize', dur=5.5, bg='#050610', tin=new_tin('fade', 0.6),
                          cam=new_cam(zoom0=1.2, zoom1=1.28, ease='out'), fx=bars(tint='#8866ff', tintAmt=0.18, vignette=0.45),
                          layers=[text_layer("I don't know if I'm her.", name='Line', fontSize=11, y=-35, textColor='#e8d0ff', reveal=0.9, revealDelay=1.0),
                                  text_layer('ANERA ECHO', name='Name', fontSize=8, y=55, textColor='#aa88ff', reveal=0.4, revealDelay=0.3),
                                  img_layer(echo, name='Anera Echo', x=0, y=8, scale=1.35, parallax=1.5, anchor='bottom', opacity=0.9, tint='#c0a0ff', tintAmt=0.15)] + [dict(x) for x in base],
                          audio=[cue(1.0, sounds[2], 0.7)] if len(sounds)>2 else []))
    save('c16_anera_echo.parallax.json', 'Anera Echo — Character Reward', shots, assets, sounds,
         template='c16', cast='Echo + Lumen/Nyx fragments', notes='Key line with dialog VO.')


def mission_package():
    plates_o = [bg('A_far_distant_cyberpunk.png'), bg('layer-2.png'), bg('bg_4.png')]
    plates_d = [bg('md_6.png'), bg('layer-5.png')]
    klixx, pity = ch('057_klixx'), ch('058_pity')
    tower = struct('16_comms_relay_tower.png') or struct('36_antenna_farm.png')
    assets = list(plates_o) + [klixx]
    if tower: assets.append(tower)
    sounds = [s for s in [sfx('cyber_boot.wav'), sfx('futuristic_hover_veh.wav', max_sec=2.5)] if s]
    base = stack(plates_o)
    L = [img_layer(klixx, name='Klixx', x=-80, y=8, scale=1.0, parallax=1.4, anchor='bottom', speedX=12)]
    if tower: L.append(img_layer(tower, name='Relay', x=60, y=5, scale=0.7, parallax=0.9, anchor='bottom'))
    L += [dict(x) for x in base]
    save('c17_mission_opening.parallax.json', 'Mission Package — Opening', [
        new_shot(name='Approach Sector', dur=5.0, bg='#060a12', tin=new_tin('fade', 1.0),
                 cam=new_cam(panX=40, zoom0=0.95, zoom1=1.08), fx=bars(tint='#3ee0d8', tintAmt=0.15), layers=L,
                 audio=[cue(0.3, sounds[0], 0.5)] if sounds else []),
        new_shot(name='Official Objective', dur=4.0, bg='#060a12', tin=new_tin('crossfade', 0.4),
                 cam=new_cam(zoom0=1.05, zoom1=1.12), fx=bars(tint='#ffaa55', tintAmt=0.12),
                 layers=[text_layer('OBJECTIVE: SECURE RELAY', name='Obj', fontSize=9, y=-40, textColor='#ffcc88', reveal=0.6),
                         text_layer('Viel Civil Compliance Order 7-14', name='Ord', fontSize=7, y=-20, textColor='#88aacc'),
                         img_layer(klixx, name='Klixx', x=0, y=8, scale=1.15, parallax=1.4, anchor='bottom')] + [dict(x) for x in base]),
    ], assets, sounds, template='c17', cast='Klixx', notes='Sample mission: Secure Relay.')

    assets = list(plates_d) + [klixx, pity]
    sounds = [s for s in [sfx('glitch_stutter.wav'), dlg(4)] if s]
    base = stack(plates_d)
    save('c17_mission_discovery.parallax.json', 'Mission Package — Discovery', [
        new_shot(name='Field Reality', dur=4.5, bg='#10080c', tin=new_tin('fade', 0.6),
                 cam=new_cam(panX=16, zoom0=1.0, zoom1=1.12), fx=bars(tint='#ff6688', tintAmt=0.15, grain=0.15),
                 layers=[text_layer('The relay is a shelter frequency.', name='Truth', fontSize=9, y=-40, textColor='#ffd0d8', reveal=0.8),
                         img_layer(pity, name='Pity', x=50, y=8, scale=1.1, parallax=1.4, anchor='bottom', flipH=True),
                         img_layer(klixx, name='Klixx', x=-50, y=8, scale=1.1, parallax=1.4, anchor='bottom')] + [dict(x) for x in base],
                 audio=[cue(0.5, sounds[0], 0.45)] if sounds else []),
        new_shot(name='Hidden Record', dur=4.0, bg='#10080c', tin=new_tin('dissolve', 0.4),
                 cam=new_cam(zoom0=1.15, zoom1=1.22), fx=bars(scan=0.1, tint='#5cffc8', tintAmt=0.12),
                 layers=[text_layer('WITNESS LOG — UNVERIFIED', name='Log', fontSize=8, y=-50, textColor='#9ef0c8'),
                         text_layer('They called for help. The grid called it targeting.', name='Line', fontSize=8, y=55, wrapW=280, textColor='#e8f0ff', reveal=0.9, revealDelay=0.5),
                         img_layer(pity, name='Pity', x=20, y=8, scale=1.25, parallax=1.5, anchor='bottom', flipH=True)] + [dict(x) for x in base],
                 audio=[cue(0.6, sounds[1], 0.75)] if len(sounds)>1 else []),
    ], assets, sounds, template='c17', cast='Klixx, Pity', notes='Shelter vs targeting.')

    assets = list(plates_d) + [klixx]
    sounds = [s for s in [sfx('electronic_click.wav'), dlg(7, 2.0)] if s]
    base = stack(plates_d)
    save('c17_mission_choice.parallax.json', 'Mission Package — Choice', [
        new_shot(name='Decision', dur=5.0, bg='#0c0a10', tin=new_tin('fade', 0.5),
                 cam=new_cam(zoom0=1.15, zoom1=1.25), fx=bars(tint='#ffcc66', tintAmt=0.18, vignette=0.4),
                 layers=[text_layer('REROUTE  ·  SILENCE  ·  BROADCAST', name='C', fontSize=9, y=-35, textColor='#ffe08a', reveal=0.5),
                         text_layer('Knowledge becomes a physical act.', name='S', fontSize=7, y=-12, textColor='#99aabb'),
                         img_layer(klixx, name='Klixx', x=0, y=10, scale=1.3, parallax=1.5, anchor='bottom')] + [dict(x) for x in base],
                 audio=[cue(0.4, sounds[0], 0.5)] if sounds else []),
    ], assets, sounds, template='c17', cast='Klixx', notes='Three physical options.')

    assets = list(plates_o) + [klixx, pity]
    sounds = [s for s in [sfx('defeat_dirge.wav', max_sec=3.0), sfx('alarm_soft.wav')] if s]
    base = stack(plates_o)
    save('c17_mission_ending.parallax.json', 'Mission Package — Ending', [
        new_shot(name='Immediate Consequence', dur=5.0, bg='#0a0610', tin=new_tin('fade', 0.8),
                 cam=new_cam(panX=20, zoom0=1.1, zoom1=1.0, ease='inout'),
                 fx=bars(tint='#8866aa', tintAmt=0.2, vignette=0.45, grain=0.15),
                 layers=[text_layer('The grid notices. The shelter does not thank you.', name='Cons', fontSize=8, y=-40, wrapW=280, textColor='#d0c0e8', reveal=1.0),
                         img_layer(klixx, name='Klixx', x=-40, y=8, scale=1.05, parallax=1.4, anchor='bottom'),
                         img_layer(pity, name='Pity', x=50, y=8, scale=1.05, parallax=1.4, anchor='bottom', flipH=True)] + [dict(x) for x in base],
                 audio=[cue(0.5, sounds[0], 0.45)] if sounds else []),
        new_shot(name='Unresolved', dur=3.5, bg='#0a0610', tin=new_tin('fade', 0.6),
                 cam=new_cam(zoom0=1.0, zoom1=1.05), fx=bars(vignette=0.55),
                 layers=[text_layer('ECHO ELIGIBLE', name='Echo', fontSize=8, y=0, textColor='#88ffcc', reveal=0.5, revealDelay=1.0)] + [dict(x) for x in base]),
    ], assets, sounds, template='c17', cast='Klixx, Pity', notes='Echo eligible.')


def echo_cinematic():
    plates = [bg('bg_9.png'), bg('md_1.png'), bg('layer-3.png')]
    klixx, pity = ch('057_klixx'), ch('058_pity')
    assets = plates + [klixx, pity]
    sounds = [s for s in [sfx('glitch_stutter.wav'), sfx('Heavy_radio_static_c_*.wav', max_sec=2.0), dlg(0, 2.0)] if s]
    base = stack(plates)
    shots = []
    for name, sub, c, col in [
        ('Klixx account', 'Mercy Cache — what was touched', klixx, '#88ffcc'),
        ('Pity account', 'Military report — what was measured', pity, '#88aaff'),
        ('Library account', 'Witness testimony — what was omitted', None, '#ffe088'),
    ]:
        L = [text_layer(name.upper(), name='Acc', fontSize=9, y=-50, textColor=col, reveal=0.5),
             text_layer(sub, name='Sub', fontSize=7, y=-30, textColor='#aabbcc', reveal=0.6, revealDelay=0.4)]
        if c: L.append(img_layer(c, name=c['name'], x=-40, y=8, scale=1.2, parallax=1.4, anchor='bottom', tint=col, tintAmt=0.2))
        L += [dict(x) for x in base]
        shots.append(new_shot(name=name, dur=4.0, bg='#060810', tin=new_tin('dissolve', 0.5),
                              cam=new_cam(panX=10, zoom0=1.05, zoom1=1.12), fx=bars(tint=col, tintAmt=0.15, scan=0.08), layers=L))
    shots.append(new_shot(name='No Final Truth', dur=4.5, bg='#060810', tin=new_tin('fade', 0.6),
                          cam=new_cam(zoom0=1.15, zoom1=1.05), fx=bars(vignette=0.5, grain=0.2),
                          layers=[text_layer('Accounts run together. Nothing is declared final.', name='End', fontSize=8, y=-10, wrapW=280, textColor='#d0e0f0', reveal=1.0),
                                  img_layer(klixx, name='Klixx', x=-50, y=10, scale=0.95, parallax=1.3, anchor='bottom', opacity=0.7),
                                  img_layer(pity, name='Pity', x=50, y=10, scale=0.95, parallax=1.3, anchor='bottom', flipH=True, opacity=0.7)] + [dict(x) for x in base],
                          audio=[cue(0.5, sounds[0], 0.4)] if sounds else []))
    save('c3_echo_cinematic.parallax.json', 'Echo Cinematic — Multi-Account Overlay', shots, assets, sounds,
         template='c3', cast='Klixx, Pity', notes='Multi-layer archive overlays.')


def consequence_review():
    plates = [bg('bg_12.png'), bg('layer-4.png')]
    klixx = ch('057_klixx', 100)
    assets = plates + [klixx]
    sounds = [s for s in [sfx('cyber_boot.wav'), sfx('electronic_click.wav')] if s]
    base = stack(plates)
    shots = []
    for title, body, col in [
        ('PLAYER ACTION', 'You preserved the Mercy Cache', '#88ffcc'),
        ('VIEL RECORD', 'Unauthorized archive retention', '#ffaa55'),
        ('DOCTRINE RECORD', 'Witnesses named in hymn', '#ff88cc'),
        ('LIBRARY STATUS', 'Confidence 0.41 — disputed', '#aaccff'),
        ('WITNESS', 'Still alive. Still afraid.', '#ffe0a0'),
    ]:
        shots.append(new_shot(name=title.title(), dur=3.2, bg='#0a0c14', tin=new_tin('wipeL', 0.35),
                              cam=new_cam(panX=6, zoom0=1.05, zoom1=1.08), fx=bars(tint=col, tintAmt=0.1, vignette=0.4, scan=0.05),
                              layers=[text_layer(title, name='T', fontSize=8, y=-40, textColor=col, reveal=0.35),
                                      text_layer(body, name='B', fontSize=9, y=-10, wrapW=280, textColor='#e8eef8', reveal=0.7, revealDelay=0.4),
                                      img_layer(klixx, name='Klixx', x=90, y=12, scale=0.8, parallax=1.2, anchor='bottom', opacity=0.5)] + [dict(x) for x in base],
                              audio=[cue(0.2, sounds[1], 0.35)] if len(sounds)>1 else []))
    shots.append(new_shot(name='Disputed Sentence', dur=4.5, bg='#0a0c14', tin=new_tin('fade', 0.5),
                          cam=new_cam(zoom0=1.1, zoom1=1.18), fx=bars(vignette=0.5, grain=0.15),
                          layers=[text_layer('"The cache was never there."', name='D', fontSize=11, y=-15, textColor='#ff8090', reveal=0.9, revealDelay=0.5),
                                  text_layer('— next act pressure', name='P', fontSize=7, y=20, textColor='#667788', reveal=0.4, revealDelay=2.0)] + [dict(x) for x in base]))
    save('c4_consequence_review.parallax.json', 'Consequence Review — Act Archive', shots, assets, sounds,
         template='c4', cast='Klixx', notes='Ends on disputed sentence.')


def originals():
    # QN-0
    plates = [bg('bg_17.png'), bg('layer-5.2.png'), bg('parallax.png')]
    echo = ch('029_echo')
    assets = plates + [echo]
    vortex = fx_img('A_flat_arcane_vortex*.png') or fx_img('*vortex*')
    if vortex: assets.append(vortex)
    sounds = [s for s in [sfx('glitch_stutter.wav'), sfx('Heavy_radio_static_c_*.wav', max_sec=2.5)] if s]
    base = stack(plates)
    Lbloom = [text_layer('QN-0', name='Sig', fontSize=16, y=-20, textColor='#c8b0ff', reveal=0.6)]
    if vortex: Lbloom.append(img_layer(vortex, name='Bloom', x=0, y=-10, scale=0.8, parallax=0.4, anchor='center', opacity=0.7))
    Lbloom += [dict(x) for x in base]
    L2 = [img_layer(echo, name='Fragment', x=0, y=8, scale=1.4, parallax=1.5, anchor='bottom', tint='#aa88ff', tintAmt=0.4, opacity=0.8)]
    if vortex: L2.append(img_layer(vortex, name='Bloom', x=0, y=-20, scale=1.1, parallax=0.5, anchor='center', opacity=0.5, speedX=4))
    L2 += [dict(x) for x in base]
    save('orig_qn0_signal_bloom.parallax.json', 'ORIGINAL — QN-0 Signal Bloom', [
        new_shot(name='Black Crown', dur=4.0, bg='#000000', tin=new_tin('fade', 1.0),
                 cam=new_cam(zoom0=0.9, zoom1=1.1), fx=bars(tint='#6644ff', tintAmt=0.3, chroma=0.5, grain=0.25),
                 layers=Lbloom, audio=[cue(0.4, sounds[0], 0.55)] if sounds else []),
        new_shot(name='Signal Bloom', dur=5.0, bg='#050018', tin=new_tin('flash', 0.3, '#8866ff'),
                 cam=new_cam(shake=2, zoom0=1.1, zoom1=1.3, ease='out'),
                 fx=bars(tint='#8866ff', tintAmt=0.4, flash=0.5, chroma=0.6, grain=0.3), layers=L2,
                 audio=[cue(0.2, sounds[1], 0.5)] if len(sounds)>1 else []),
        new_shot(name='Contradictory Temp', dur=4.0, bg='#100800', tin=new_tin('dissolve', 0.5),
                 cam=new_cam(panX=20, zoom0=1.2, zoom1=1.0), fx=bars(tint='#ffaa44', tintAmt=0.25, hue=20),
                 layers=[text_layer('soft voice fragments', name='V', fontSize=8, y=-40, textColor='#ffe0aa'),
                         img_layer(echo, name='Fragment', x=-30, y=8, scale=1.1, parallax=1.4, anchor='bottom')] + [dict(x) for x in base]),
    ], assets, sounds, template='c19/original', cast='Echo', notes='QN-0 motif.')

    # Train confession
    plates = [bg('bg_5.png'), bg('layer-2.1.png'), bg('A_cyberpunk_city_1265508853_3.png')]
    klixx, pity = ch('057_klixx'), ch('058_pity')
    assets = plates + [klixx, pity]
    sounds = [s for s in [sfx('futuristic_hover_veh.wav', max_sec=3), dlg(9), dlg(10)] if s]
    base = stack(plates)
    for L in base: L['speedX'] = 8 + L.get('parallax', 1) * 6
    save('orig_train_confession.parallax.json', 'ORIGINAL — Train Confession', [
        new_shot(name='Compartment', dur=4.0, bg='#0a0e16', tin=new_tin('fade', 0.8),
                 cam=new_cam(panX=30, zoom0=1.0, zoom1=1.08), fx=bars(tint='#6688cc', tintAmt=0.15, vignette=0.4),
                 layers=[img_layer(klixx, name='Klixx', x=-55, y=8, scale=1.1, parallax=1.45, anchor='bottom'),
                         img_layer(pity, name='Pity', x=60, y=8, scale=1.1, parallax=1.45, anchor='bottom', flipH=True)] + [dict(x) for x in base],
                 audio=[cue(0.2, sounds[0], 0.4)] if sounds else []),
        new_shot(name='Confession', dur=5.0, bg='#0a0e16', tin=new_tin('crossfade', 0.4),
                 cam=new_cam(zoom0=1.15, zoom1=1.25), fx=bars(tint='#6688cc', tintAmt=0.1, vignette=0.45),
                 layers=[text_layer('I kept a copy.', name='Line', fontSize=11, y=-35, textColor='#e8f0ff', reveal=0.8, revealDelay=0.5),
                         text_layer('KLIXX', name='Sp', fontSize=8, y=-55, textColor='#ff8ad4'),
                         img_layer(klixx, name='Klixx', x=-40, y=8, scale=1.3, parallax=1.5, anchor='bottom'),
                         img_layer(pity, name='Pity', x=70, y=10, scale=0.95, parallax=1.3, anchor='bottom', flipH=True, bright=0.7)] + [dict(x) for x in base],
                 audio=[cue(0.5, sounds[1], 0.75)] if len(sounds)>1 else []),
        new_shot(name='Response', dur=4.5, bg='#0a0e16', tin=new_tin('cut', 0.15),
                 cam=new_cam(zoom0=1.25, zoom1=1.28), fx=bars(vignette=0.5),
                 layers=[text_layer('Then we are both guilty of remembering.', name='Line', fontSize=9, y=-30, wrapW=260, textColor='#e8f0ff', reveal=0.9, revealDelay=0.4),
                         text_layer('PITY', name='Sp', fontSize=8, y=-50, textColor='#88c0ff'),
                         img_layer(pity, name='Pity', x=40, y=8, scale=1.3, parallax=1.5, anchor='bottom', flipH=True),
                         img_layer(klixx, name='Klixx', x=-70, y=10, scale=0.95, parallax=1.3, anchor='bottom', bright=0.7)] + [dict(x) for x in base],
                 audio=[cue(0.45, sounds[2], 0.75)] if len(sounds)>2 else []),
    ], assets, sounds, template='c19/original', cast='Klixx, Pity', notes='Dialog VO. speedX train motion.')

    # Library accusation
    plates = [bg('md_10.png'), bg('bg_13.png'), bg('layer-1.1.png')]
    pity, quorum = ch('058_pity'), ch('051_quorum')
    assets = plates + [pity, quorum]
    sounds = [s for s in [sfx('electronic_click.wav'), dlg(11), sfx('alarm_soft.wav')] if s]
    base = stack(plates)
    save('orig_library_accusation.parallax.json', 'ORIGINAL — Library Accusation', [
        new_shot(name='Reading Room', dur=4.0, bg='#141210', tin=new_tin('fade', 0.9),
                 cam=new_cam(panX=12, zoom0=1.0, zoom1=1.08), fx=bars(tint='#e8dcc0', tintAmt=0.12),
                 layers=[img_layer(pity, name='Pity', x=-60, y=8, scale=1.1, parallax=1.4, anchor='bottom'),
                         img_layer(quorum, name='Archivist', x=70, y=8, scale=1.1, parallax=1.4, anchor='bottom', flipH=True)] + [dict(x) for x in base]),
        new_shot(name='Accusation', dur=5.0, bg='#141210', tin=new_tin('wipeU', 0.4),
                 cam=new_cam(zoom0=1.15, zoom1=1.25), fx=bars(tint='#e8dcc0', tintAmt=0.1, scan=0.06),
                 layers=[text_layer('Your annotation is a weapon.', name='Line', fontSize=10, y=-40, textColor='#fff8e0', reveal=0.8, revealDelay=0.4),
                         text_layer('CLASSIFICATION: HOSTILE INFERENCE', name='Tag', fontSize=7, y=55, textColor='#ff8090', reveal=0.4, revealDelay=1.5),
                         img_layer(quorum, name='Archivist', x=20, y=8, scale=1.35, parallax=1.5, anchor='bottom', flipH=True)] + [dict(x) for x in base],
                 audio=[cue(0.4, sounds[1], 0.7)] if len(sounds)>1 else []),
        new_shot(name='Page Wipe', dur=3.5, bg='#141210', tin=new_tin('wipeL', 0.5),
                 cam=new_cam(panX=-16, zoom0=1.2, zoom1=1.1), fx=bars(vignette=0.5, grain=0.15),
                 layers=[text_layer('Pale institutional light becomes threatening.', name='M', fontSize=8, y=0, wrapW=280, textColor='#d0c8b0')] + [dict(x) for x in base]),
    ], assets, sounds, template='c19/original', cast='Pity, Quorum', notes='Library motif.')

    # Verge glitch
    plates = [bg('bg_10.png'), bg('layer-3.1.png'), bg('A_cyberpunk_city_1197448950_1.png')]
    nyx = ch('005_nyx')
    dup = bg('bg_10.png'); dup['name'] = 'dup_glitch'
    assets = plates + [nyx, dup]
    sounds = [s for s in [sfx('glitch_stutter.wav'), sfx('Aggressive_digital_g_*.wav', max_sec=2.0)] if s]
    base = stack(plates)
    save('orig_verge_glitch_arrival.parallax.json', 'ORIGINAL — Verge Glitch Arrival', [
        new_shot(name='Mismatch', dur=3.5, bg='#0a0010', tin=new_tin('cut', 0.1),
                 cam=new_cam(panX=50, panY=10, zoom0=1.0, zoom1=1.2, ease='in'),
                 fx=bars(chroma=0.8, tint='#ff00aa', tintAmt=0.25, grain=0.3, scan=0.2),
                 layers=[img_layer(dup, name='Dup', x=15, y=-8, scale=1.05, parallax=0.4, anchor='center', opacity=0.45, tint='#00ffff', tintAmt=0.4)] + [dict(x) for x in base],
                 audio=[cue(0.1, sounds[0], 0.6)] if sounds else []),
        new_shot(name='Impossible Scale', dur=4.0, bg='#0a0010', tin=new_tin('dissolve', 0.3),
                 cam=new_cam(shake=5, zoom0=1.4, zoom1=0.9, ease='inout'),
                 fx=bars(chroma=1.0, hue=40, tint='#00ffcc', tintAmt=0.3),
                 layers=[img_layer(nyx, name='Nyx', x=-20, y=0, scale=2.2, parallax=1.6, anchor='bottom', opacity=0.7),
                         img_layer(nyx, name='Nyx ghost', x=40, y=20, scale=0.5, parallax=0.8, anchor='bottom', opacity=0.4)] + [dict(x) for x in base],
                 audio=[cue(0.2, sounds[1], 0.5)] if len(sounds)>1 else []),
        new_shot(name='Delayed Shadow', dur=4.0, bg='#0a0010', tin=new_tin('flash', 0.2),
                 cam=new_cam(panX=-30, zoom0=1.0, zoom1=1.1), fx=bars(chroma=0.4, vignette=0.4),
                 layers=[text_layer('VERGE', name='Place', fontSize=14, y=-40, textColor='#ff66cc', reveal=0.5),
                         text_layer('Unmapped Seam', name='Reg', fontSize=8, y=-18, textColor='#66ffcc'),
                         img_layer(nyx, name='Nyx', x=0, y=8, scale=1.2, parallax=1.45, anchor='bottom')] + [dict(x) for x in base]),
    ], assets, sounds, template='c19/original', cast='Nyx', notes='Verge motif.', vars={'REGION': 'Unmapped Seam'})

    # Doctrine hymn
    plates = [bg('md_3.png'), bg('layer-5.png'), bg('A_war_torn_muddy_bat.png')]
    klixx, halo = ch('057_klixx'), ch('049_halo')
    assets = plates + [klixx, halo]
    sounds = [s for s in [sfx('defeat_dirge.wav', max_sec=3.5), dlg(2)] if s]
    base = stack(plates)
    save('orig_doctrine_hymn_wave.parallax.json', 'ORIGINAL — Doctrine Hymn-Wave', [
        new_shot(name='Magenta Windows', dur=4.5, bg='#0a0610', tin=new_tin('fade', 1.0),
                 cam=new_cam(panY=-12, zoom0=1.0, zoom1=1.1), fx=bars(tint='#ff4fa3', tintAmt=0.3, vignette=0.4),
                 layers=[img_layer(halo, name='Halo', x=40, y=5, scale=1.15, parallax=1.3, anchor='bottom'),
                         img_layer(klixx, name='Klixx', x=-70, y=10, scale=0.95, parallax=1.4, anchor='bottom')] + [dict(x) for x in base],
                 audio=[cue(0.4, sounds[0], 0.4)] if sounds else []),
        new_shot(name='Hymn Wave', dur=5.0, bg='#0a0610', tin=new_tin('crossfade', 0.5),
                 cam=new_cam(panX=8, zoom0=1.15, zoom1=1.22), fx=bars(tint='#ff4fa3', tintAmt=0.25, scan=0.1),
                 layers=[text_layer('cyan signal veins under the hymn', name='M', fontSize=8, y=-45, textColor='#66ffe0', reveal=0.7),
                         text_layer('BLACK DOCTRINE', name='N', fontSize=10, y=55, textColor='#ff8ad4'),
                         img_layer(halo, name='Halo', x=0, y=8, scale=1.35, parallax=1.5, anchor='bottom', tint='#ff4fa3', tintAmt=0.2)] + [dict(x) for x in base],
                 audio=[cue(0.6, sounds[1], 0.65)] if len(sounds)>1 else []),
    ], assets, sounds, template='c19/original', cast='Klixx, Halo', notes='Doctrine motif.')

    # Viel sweep
    plates = [bg('bg_1.png'), bg('layer-1.png'), bg('A_far_distant_cyberpunk.png')]
    ivory = ch('052_ivory')
    assets = plates + [ivory]
    tower = struct('08_radar_dome.png') or struct('34_sat_dish_farm.png')
    if tower: assets.append(tower)
    sounds = [s for s in [sfx('cyber_boot.wav'), sfx('Cold_War_nuclear_air_*.wav', max_sec=2.5)] if s]
    base = stack(plates)
    L = [img_layer(ivory, name='Operator', x=-60, y=8, scale=1.1, parallax=1.4, anchor='bottom')]
    if tower: L.append(img_layer(tower, name='Radar', x=70, y=0, scale=0.65, parallax=0.85, anchor='bottom'))
    L += [dict(x) for x in base]
    save('orig_viel_surveillance_sweep.parallax.json', 'ORIGINAL — Viel Surveillance Sweep', [
        new_shot(name='White Geometry', dur=4.0, bg='#101820', tin=new_tin('wipeR', 0.6),
                 cam=new_cam(panX=35, zoom0=1.0, zoom1=1.08), fx=bars(tint='#ff9a3c', tintAmt=0.2, bright=1.08),
                 layers=L, audio=[cue(0.3, sounds[0], 0.5)] if sounds else []),
        new_shot(name='Sweep', dur=4.5, bg='#101820', tin=new_tin('crossfade', 0.4),
                 cam=new_cam(panX=-40, zoom0=1.1, zoom1=1.15), fx=bars(tint='#3ee0d8', tintAmt=0.2, scan=0.12),
                 layers=[text_layer('CYAN TRANSIT GRID — LOCK', name='G', fontSize=8, y=-50, textColor='#3ee0d8', reveal=0.5),
                         img_layer(ivory, name='Operator', x=0, y=8, scale=1.25, parallax=1.45, anchor='bottom')] + [dict(x) for x in base],
                 audio=[cue(0.4, sounds[1], 0.4)] if len(sounds)>1 else []),
        new_shot(name='Orange Civic Light', dur=3.5, bg='#101820', tin=new_tin('fade', 0.5),
                 cam=new_cam(zoom0=1.15, zoom1=1.05), fx=bars(tint='#ff9a3c', tintAmt=0.28),
                 layers=[text_layer('VIEL', name='V', fontSize=14, y=-20, textColor='#ffb060', reveal=0.4)] + [dict(x) for x in base]),
    ], assets, sounds, template='c19/original', cast='Ivory', notes='Viel motif.')

    # Mercy corridor
    plates = [bg('enviro3.jpg'), bg('layer-4.png'), bg('md_7.png')]
    mercy, klixx = ch('063_mercy'), ch('057_klixx', 110)
    assets = plates + [mercy, klixx]
    sounds = [s for s in [sfx('footstep_soft.wav'), sfx('heal.wav'), sfx('A_soft_futuristic_he_*.wav', max_sec=2.5)] if s]
    base = stack(plates)
    save('orig_mercy_corridor_walk.parallax.json', 'ORIGINAL — Mercy Corridor Walk', [
        new_shot(name='Corridor', dur=5.0, bg='#0c1412', tin=new_tin('fade', 1.0),
                 cam=new_cam(panX=45, zoom0=1.0, zoom1=1.1, ease='inout'), fx=bars(tint='#5cffb0', tintAmt=0.12, vignette=0.4),
                 layers=[img_layer(mercy, name='Mercy', x=-100, y=8, scale=1.1, parallax=1.5, anchor='bottom', speedX=22),
                         img_layer(klixx, name='Klixx', x=-140, y=10, scale=0.95, parallax=1.35, anchor='bottom', speedX=18)] + [dict(x) for x in base],
                 audio=[cue(0.5, sounds[0], 0.5), cue(1.5, sounds[0], 0.45), cue(2.5, sounds[0], 0.45)] if sounds else []),
        new_shot(name='Pause', dur=4.0, bg='#0c1412', tin=new_tin('crossfade', 0.5),
                 cam=new_cam(zoom0=1.15, zoom1=1.22), fx=bars(tint='#5cffb0', tintAmt=0.15),
                 layers=[text_layer('Some doors only open for the wounded.', name='Line', fontSize=9, y=-40, wrapW=260, textColor='#d0ffe8', reveal=0.9, revealDelay=0.6),
                         img_layer(mercy, name='Mercy', x=10, y=8, scale=1.3, parallax=1.5, anchor='bottom'),
                         img_layer(klixx, name='Klixx', x=-70, y=10, scale=1.0, parallax=1.35, anchor='bottom', bright=0.75)] + [dict(x) for x in base],
                 audio=[cue(0.4, sounds[1], 0.4)] if len(sounds)>1 else []),
    ], assets, sounds, template='original', cast='Mercy, Klixx', notes='Footsteps + heal bed.')

    # Archive blackout
    plates = [bg('bg_15.png'), bg('layer-2.png')]
    shade = ch('064_shade')
    assets = plates + [shade]
    sounds = [s for s in [sfx('glitch_stutter.wav'), sfx('Heavy_radio_static_c_*.wav', max_sec=2.5)] if s]
    base = stack(plates)
    save('orig_archive_blackout.parallax.json', 'ORIGINAL — Archive Blackout', [
        new_shot(name='Lights Up', dur=3.0, bg='#0e1018', tin=new_tin('fade', 0.5),
                 cam=new_cam(zoom0=1.0, zoom1=1.05), fx=bars(bright=1.1, vignette=0.3),
                 layers=[text_layer('ARCHIVE NODE 7', name='N', fontSize=10, y=-30, textColor='#a0c0ff'),
                         img_layer(shade, name='Shade', x=0, y=8, scale=1.2, parallax=1.4, anchor='bottom')] + [dict(x) for x in base]),
        new_shot(name='Blackout', dur=2.5, bg='#000000', tin=new_tin('cut', 0.05),
                 cam=new_cam(shake=6, zoom0=1.2, zoom1=1.0),
                 fx=new_fx(bright=0.2, bars=0.2, grain=0.4, flash=0.8, flashColor='#ffffff', flashDur=0.1, chroma=0.7),
                 layers=[text_layer('MISSING DATA', name='M', fontSize=12, y=0, textColor='#445566', reveal=0.3)],
                 audio=[cue(0.05, sounds[0], 0.7)] if sounds else []),
        new_shot(name='Recovery Attempt', dur=4.0, bg='#060810', tin=new_tin('dissolve', 0.6),
                 cam=new_cam(panX=10, zoom0=1.0, zoom1=1.1), fx=bars(scan=0.15, grain=0.25, tint='#446688', tintAmt=0.2),
                 layers=[text_layer('████████ cannot be identified', name='R', fontSize=9, y=-20, textColor='#8899aa', reveal=0.8),
                         img_layer(shade, name='Shade', x=-20, y=8, scale=1.15, parallax=1.4, anchor='bottom', opacity=0.55)] + [dict(x) for x in base],
                 audio=[cue(0.3, sounds[1], 0.45)] if len(sounds)>1 else []),
    ], assets, sounds, template='c2/original', cast='Shade', notes='Missing-data motif.')


def write_review():
    lines = [
        '# Cutscene Scene Pack — REVIEW',
        '',
        '**Generated for Brian (Black Doctrine / Nox-Aster)**  ',
        '**Builder:** `cutscene-builder.html`  ',
        '**Projects:** `projects/*.parallax.json`',
        '',
        '## How to review',
        '1. Open `/workspace/bd-tools/cutscene/cutscene-builder.html` in a browser.',
        '2. Click **Open** and pick a `.parallax.json` from `projects/`.',
        '3. Press **▶ Play**.',
        '4. Or use **Import scene pack (multi JSON)** in the Proj tab (v1.8-bd).',
        '',
        '## Pack index',
        '',
        '| File | Template | Runtime | Shots | MB | Cast | Notes |',
        '|------|----------|---------|-------|----|------|-------|',
    ]
    for r in REVIEW:
        lines.append(f"| `{r['file']}` | {r['template']} | ~{r['runtime']}s | {r['shots']} | {r['size_mb']} | {r['cast']} | {r['notes']} |")
    lines += [
        '',
        '## Cast stand-ins / missing art',
        '- **Voss (c10):** no Voss sheet — **052_ivory** stand-in. Replace when Voss art lands.',
        '- **Anera Echo (c16):** **029_echo** + **021_lumen** / **005_nyx** as age/location fragments.',
        '- **Boss skeleton (c11):** **039_vicar** placeholder.',
        '',
        '## Audio',
        '- Dialogue scenes embed **compact** mono clips from `assets/audio/dialog_lines/`.',
        '- Ambience/combat from `assets/audio/` and `assets/audio/newest_fx/`.',
        '',
        '## Quality bar',
        'Every project has multiple shots, camera motion, letterbox, and readable staging. First-pass polish welcome in-builder.',
        '',
    ]
    (PROJECTS / 'REVIEW.md').write_text('\n'.join(lines))
    print(f'REVIEW.md — {len(REVIEW)} projects')


def main():
    PROJECTS.mkdir(parents=True, exist_ok=True)
    print('=== c5 Location Reveals ===')
    loc_reveal('c5_location_reveal_viel_plaza.parallax.json', 'Viel Plaza', 'Civic Core',
               ['bg_2.png', 'layer-1.png', 'A_far_distant_cyberpunk.png', 'A_cyberpunk_city_1197448950_1.png'],
               watcher=ch('052_ivory'), tint='#ff9a3c')
    loc_reveal('c5_location_reveal_doctrine_alley.parallax.json', 'Doctrine Alley', 'Black Hymn Ward',
               ['md_3.png', 'layer-5.png', 'A_war_torn_battlefield_3.png', 'bg_7.png'],
               watcher=ch('057_klixx'), tint='#ff4fa3')
    loc_reveal('c5_location_reveal_library_approach.parallax.json', 'The Library', 'Institutional Pale',
               ['md_10.png', 'bg_13.png', 'layer-1.1.png', 'layer-3.png'],
               watcher=ch('058_pity'), tint='#e8dcc0')
    loc_reveal('c5_location_reveal_verge_skyline.parallax.json', 'Verge Skyline', 'Unmapped Seam',
               ['bg_10.png', 'layer-3.1.png', 'parallax.png', 'A_cyberpunk_city_1265508853_2.png'],
               watcher=ch('005_nyx'), tint='#ff00aa')
    loc_reveal('c5_location_reveal_generic.parallax.json', 'Unknown District', 'Nox-Aster',
               ['scene_1_layer_1_sky.png', 'scene_1_layer_2_farbackground.png', 'layer-2.png', 'layer-4.png'],
               watcher=ch('001_kess'), tint='#3ee0d8')

    print('=== c6 Quiet Conversation ===')
    quiet('c6_quiet_conversation.parallax.json', 'Quiet Conversation — Base',
          ['md_4.png', 'layer-3.png', 'bg_8.png'], ch('057_klixx'), ch('058_pity'),
          [('Klixx', 'Say it without the report voice.'),
           ('Pity', 'The report voice is how I stay useful.'),
           ('Klixx', 'Useful to who?')])
    quiet('c6_quiet_conversation_train.parallax.json', 'Quiet Conversation — Train',
          ['bg_5.png', 'layer-2.1.png', 'A_cyberpunk_city_1265508853_3.png'], ch('057_klixx'), ch('058_pity'),
          [('Pity', 'If we miss this stop, we miss the hearing.'),
           ('Klixx', 'Then we hear each other instead.'),
           ('Pity', 'That is not a strategy.')], tint='#6688cc')
    quiet('c6_quiet_conversation_rooftop.parallax.json', 'Quiet Conversation — Signal Rooftop',
          ['bg_4.png', 'layer-4.png', 'A_far_distant_cyberpunk.png'], ch('057_klixx'), ch('011_orchid'),
          [('Orchid', 'The city looks honest from up here.'),
           ('Klixx', 'Honesty is a zoom setting.'),
           ('Orchid', 'Then zoom out with me.')], tint='#88e0ff')

    print('=== c7 Camp ===')
    quiet('c7_companion_camp_shelter.parallax.json', 'Companion Camp — Refugee Shelter',
          ['md_7.png', 'layer-5.png', 'A_war_torn_flat_muddy.png'], ch('057_klixx'), ch('058_pity'),
          [('Klixx', 'You can sleep first.'),
           ('Pity', 'I will invent sleep later.'),
           ('Klixx', 'That is not a joke that lands.')], tint='#c48cff', template='c7')
    quiet('c7_companion_camp_signal_rooftop.parallax.json', 'Companion Camp — Signal Rooftop',
          ['bg_3.png', 'layer-2.png', 'A_cyberpunk_city_1265508853_2.png'], ch('057_klixx'), ch('005_nyx'),
          [('Nyx', 'Your silence has a shape.'),
           ('Klixx', 'So does yours.'),
           ('Nyx', 'Then we are finally matching.')], tint='#ff88cc', template='c7')

    print('=== Story / templates ===')
    wrong_choir(); shared_silence(); voss_intro(); boss_skeleton()
    mercy_cache('preserve'); mercy_cache('destroy')
    anera_sketchbook(); first_questions(); collection_standard(); anera_echo()
    mission_package(); echo_cinematic(); consequence_review()
    print('=== Originals ===')
    originals()
    write_review()
    print(f'\nDONE — {len(REVIEW)} projects')


if __name__ == '__main__':
    main()
