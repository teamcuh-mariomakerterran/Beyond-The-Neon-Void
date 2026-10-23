Neon Void PRESS START: Brian's hand-drawn 5x7 bitmap font (see LICENSE.txt; not OFL).
Copied from C:\Users\Brian\bd-tools-handoff\press_start_font (the .zip and the .py build scripts stay there).

Use the atlas + JSON metrics, not a TTF:

press_start_atlas.png + press_start_atlas.json  (plain white glyphs, scale 1)
  - cell 5x9, advance 6 px, lineHeight 11, baseline 7 px below each rect's y,
    capHeight 7, xHeight 5, descender 2, monospace.
  - glyphs{"A": {x, y, w, h, advance, file}}: source rect in the atlas per character.
  - Tint it in Godot (modulate) for any colour; draw at integer scales (2x, 3x...) with
    texture filter Nearest.

press_start_atlas_screen.png + press_start_atlas_screen.json  (pre-treated title look, scale 3)
  - cell 29x34, advance 18, baseline 23. Glyphs are italic-sheared with the cyan fill,
    magenta drop shadow and dark outline baked in, so neighbours overlap by
    cell - advance = 11 px: draw left to right at x += advance.
  - Don't tint this one; it's already coloured.

glyphs/white/*.png and glyphs/screen/*.png: the same glyphs as single files
(names like A_upper.png, a_lower.png, 0.png, colon.png, space.png).

Characters: A-Z a-z 0-9 space . , : ; ! ? " - ( ) [ ] # $  (the quote is a double quote; no apostrophe yet).
Keys are case-sensitive ('A' and 'a' are both there): Godot's JSON is fine with that, PowerShell's ConvertFrom-Json is not.

In Godot 4 a FontFile can be built from the white atlas (fixed size, 6 px advance);
otherwise draw it with a small TextureRect/draw_texture_rect_region helper using the JSON rects.

