# Neon Void main menu (Godot 4.3)

This is a drop-in 640×360 title menu that matches the mockup pixel for pixel: the logo, PRESS START font, twinkling stars, scrolling grid, scanlines, bobbing cursor, and the cyan/magenta selected item.

## Open it

1. Install Godot 4.3 (the 4.3 stable build).
2. In Godot, choose **Import** and open `project.godot` in this folder.
3. Press F5 (or **Project → Run Project**).

The window opens at 1280×720, which is a sharp 2× scale of the 640×360 menu.

## Controls

- **Up / Down** or **W / S** — move the cursor. It wraps around the list.
- **Enter** or **Space** — pick the selected item.
- **Mouse** — hover to select, click to pick.

Items are Continue, New Game, Load Game, Options, Credits and Quit. Quit closes the window. The other items fire a signal that the game can hook up (see `CLAUDE_HANDOFF.md`).

To see Continue greyed out (no save file), select the `MainMenu` node in Godot and uncheck **Has Save** in the Inspector, then run again.

## What's in this folder

- `main_menu.tscn` / `main_menu.gd` — the menu scene and script
- `assets/` — prebaked background frames, logo, font art, and layout
- `project.godot` — a tiny demo project so you can run it on its own
- `CLAUDE_HANDOFF.md` — how to drop this into the Neon Void game and wire the signals
