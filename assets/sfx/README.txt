Sound effects. Each family (gun_smg, hit, scream...) has numbered variants; the game picks one at random each time.
Which family plays for what lives in data/sfx_events.json (edit it to re-assign sounds). An ability's sfx_id in the Forge overrides it.
Drop new sounds in here as <family>_<n>.ogg/.wav to add variants (e.g. hit_14.wav), or a new family name and point an event at it.

Weapons:
  gun_smg            x4
  gun_auto           x4
  gun_mg             x4
  gun_mg_burst       x1
  gun_mg_reversed    x1
  gun_shotgun        x4
  gun_sniper         x4
  laser              x2

Combat:
  hit                x13
  scream             x12
  explosion          x4
  explosion_big      x4
  bomb_away          x1
  heal               x4
  magic              x16
  glitch             x4
  power_up           x4

World:
  security_door      x4
  terminal           x4
  siren              x4
  static             x23
  mech_step          x4
  tank_treads        x4
  tank_move          x4
  rat                x17
  ufo                x2
  theyre_here        x9
  zoned_in           x3
  queen_whisper      x4
  loot_found         x1
  coin               x7

UI:
  ui_beep            x1
  ui_tone            x8
  ui_chime           x4
  ui_error           x4

Stingers:
  sting_dramatic     x4
  sting_epic         x4

Ambience (loops):
  amb_rain           x8
  amb_rain_roof      x4
  amb_wind           x4
  amb_crowd          x4
  amb_bar            x4
