# Drop the Neon Void main menu into the game

This folder is a self-contained Godot 4.3 menu. It was built to match the approved mockup exactly (640×360, nearest-neighbour). Do not re-layout, re-colour, or replace the font. Hook it up and leave the look alone.

## Copy

Copy this whole folder into the Neon Void repo, for example:

```
res://scenes/ui/nv_main_menu/
  main_menu.tscn
  main_menu.gd
  assets/
```

You do not need this demo's `project.godot`. Keep `assets/` next to the scene so the `res://` paths in `main_menu.gd` still work, **or** update the three `res://assets/...` paths in `_load_art()` / `_png()` to wherever you placed the files.

## Display (important)

The game viewport is 1920×1080. This menu is 640×360. That is an exact 3× integer scale. Do not run the menu as a 640×360 Control loose in the 1920×1080 tree — it will sit in the corner or get a dirty scale.

Wrap it in a 640×360 SubViewport and stretch it 3× with nearest-neighbour:

```
# e.g. scenes/ui/title.tscn  (this can be the new main scene)
Control  (full-rect)
  SubViewportContainer  (full-rect, stretch = true)
    SubViewport  (size = 640×360, disable 3D, default texture filter = Nearest)
      MainMenu  (instance of main_menu.tscn)
```

`SubViewportContainer` at 1920×1080 + a 640×360 viewport gives a sharp 3× blit. Leave the game's stretch settings alone.

## Signals

`main_menu.gd` emits:

| Signal              | When                         | Suggested hook |
|---------------------|------------------------------|----------------|
| `continue_pressed`  | Continue                     | `SaveManager.load_game()` then `CampaignManager.return_to_hub()` |
| `new_game_pressed`  | New Game                     | same as the current `_new_game()` in `src/ui/main_menu.gd` |
| `load_pressed`      | Load Game                    | open the load-game UI |
| `options_pressed`   | Options                      | open the options UI |
| `credits_pressed`   | Credits                      | open credits |
| `quit_pressed`      | Quit                         | already calls `get_tree().quit()` when `quit_on_quit` is true (the default). Set `quit_on_quit = false` if you want a confirm dialog first, then quit from your handler. |

Connect these from the wrapper scene or from a small script on it. Do not edit the look in `main_menu.gd` to add game logic; keep the hooks outside.

## Save file / Continue

`has_save` is an exported bool, default `true` (so the mock looks right in the demo). At runtime set:

```
menu.has_save = SaveManager.has_save_file()
```

When `has_save` is false, Continue is greyed out, skipped by the keyboard wrap, and not selectable with the mouse.

## Input

The menu already handles Up/Down, W/S, Enter, Space, hover and click. You do not need to add those to the Input Map. It uses `_unhandled_input` and `_gui_input`, so it will not eat the game's other actions if a later screen is on top.

## Replacing the old title

The current title is `src/ui/main_menu.gd` (Control, NeonTheme labels, "NEW SHIFT", etc.). Point `SceneManager` / `run/main_scene` at the new wrapper scene instead of instantiating that script. Keep the old script in the repo until the new hooks are proven; just stop using it as the title.

Neon Forge / F1 and "Quick Battle" are not on the mockup, so they are not on this menu. If you still need them for dev, add a quiet debug shortcut on the wrapper (for example F1 → Neon Forge) rather than drawing extra items on the menu.

## Do not

- Recreate the background, logo glow, or font in engine primitives. The frames and PNGs in `assets/` are the mockup.
- Change the item order, wording, or spacing.
- Enable linear filtering or a non-integer scale on the SubViewport.
- Point this at Godot 4.7-only APIs; it targets 4.3 and works there.

## Check

Run the game, open the title, and compare one frame against `nv_main_menu_mock.png` (t=4, New Game selected). It should be pixel-exact at 640×360 (or a sharp 3× of that). Step through a few frames and confirm the stars twinkle, the grid scrolls, the scanlines hold, and the cursor bobs every 3 frames.
