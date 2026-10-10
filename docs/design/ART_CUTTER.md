# Art Cutter

Turns generated art (sheets on a pink/magenta background, or single items
already cut out with a pink halo) into clean game sprites. Our own code:
`src/tools/art_cutter.gd`, run by `tools/art/cut_art.gd` (or `tools/cut_art.bat`
on Windows).

## Use it

1. Drop the art in `assets/incoming/rooms_props/<folder>/` (any folder names:
   `rooms`, `bar_props`, `catwalks`, `screens`…). Godot ignores `incoming`.
2. Double-click `tools/cut_art.bat`, or run
   `godot --headless -s tools/art/cut_art.gd -- assets/incoming/rooms_props assets/props`.
3. The sprites land in `assets/props/<folder>/`. The originals are never touched.

## What it does

* **Key:** the flat background colour (read from the corners; magenta if the
  art is already transparent) becomes transparent. Darker shades of it (drop
  shadows painted on the sheet) become soft black shadow.
* **Fringe:** the pink 1–4px rim left around already-cut art is removed (bright)
  or turned into a dark outline (dark). Pink *inside* the art (neon) is left alone.
* **Split:** every separate item on a sheet becomes its own PNG, in reading
  order (rows top to bottom, then left to right). Specks that nearly touch a
  bigger item (bottle caps, loose rungs) stay with it; two real items never
  merge. Each cut holds only its own pixels, even where boxes overlap.
* **Names:** `<sheet>_01.png`, `_02`… or put `<sheet>.names.txt` beside the
  sheet (one name per line, same reading order; blank line = keep the number).

## Living signage

Folders with `screen` or `sign` in the name also get `<name>.screen.json`:
the four corners of the display's glass (black, purple, whatever colour fills
the middle of the panel, as long as a frame surrounds it). Placing that prop in
the World Painter gives it a working screen straight away (`Signage.asset_screen`),
and ticking "This object has a screen" on an existing one uses those corners
too. Feed, display mode, brightness and corners are still editable per object.
