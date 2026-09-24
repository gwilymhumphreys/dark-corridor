# Dev tools

The code that exists only for screenshots, demos and checks by hand: the start-up arguments, the dev
scenes, and the `Dev` autoload that acts on the game's arguments. None of it is part of the game a
player sees.

**Location:** `src/debug/` (`dev.gd`, `dev_args.gd`, `screenshot.gd`, the debug panel, and the dev
scenes in `src/debug/scenes/`). The folder is skipped by POT extraction, so its text stays English.

The autotest is separate and has its own reference: [autotest.md](autotest.md).

## Keeping it out of game code

Screens and game systems hold no dev code. When a tool needs something from the game, the game
exposes a plain seam and the tool uses it:

| Seam | Used by |
|---|---|
| `Game.run_started(run)` | `Dev`, to add to a new run before any screen reads it |
| `TitleScreen.open_select()`, `open_settings()`, `DEFAULT_SEED` | `Dev`, for the title arguments |
| `ChoiceOverlay.picked` | `Dev`, for `--autofight` |
| `Save.disabled` | `Dev` (`--nosave`), the autotest |
| `InterfaceGlow.demo_brightness`, `MonsterImages.forced_path`, `ControlFeedback.set_demo` | the debug panel |
| `RunManager.pinned_enemy_ids` | the autotest (`--enemies`) |
| `DevArgs.is_silent_run()` | `Prefs`, `SfxManager`, `MusicManager`, to play no sound in autotest and screenshot runs |

A new argument goes in `Dev` (game arguments), `DebugPanels._apply_command_line` (look arguments) or
the dev scene it belongs to, and gets a row in the tables below.

## Parts

| Part | What it does |
|---|---|
| `DevArgs` (`dev_args.gd`) | Static helpers that read arguments: `has`, `value`, `values` (for repeated arguments), `is_silent_run`. It reads both the engine arguments and the user arguments, and a value can be written `--name=value` or `--name value` |
| `Dev` autoload (`dev.gd`) | Acts on the game arguments below. Does nothing unless one is present |
| `DebugPanels` | Acts on the look arguments ([debug_panel.md](debug_panel.md)) |
| `Screenshot` (`screenshot.gd`) | Saves a frame into the gitignored `screenshots/` folder as `<scene>_shot_<date>_<time>.png` and prints `SHOT_SAVED:<path>` |

## Game arguments

Read by `Dev`.

| Argument | Effect |
|---|---|
| `--shot`, `--shot-delay SECONDS` | Saves one frame of whatever scene is running after the delay (`DEFAULT_SHOT_DELAY` in `dev.gd`), then quits. Also mutes all sound |
| `--nosave` | Nothing is written to the run save slot. Use it for every screenshot run |
| `--notutorial` | Accepted and ignored; there is no tutorial yet |
| `--autostart`, `--character=ID` | Skips the title screen and starts a run as the default character or `ID` |
| `--select`, `--settings` | Opens character select or the settings screen on the title screen |
| `--autofight` | Picks the first fight on every path choice |
| `--allies N` | Adds N placeholder allies to a new run (`DEMO_ALLY_ID`) |
| `--board-items N` | Fills the board up to N items with copies of the starting items |
| `--potions N` | Gives the player N potions (`DEMO_POTION_ID`) |

The title arguments act on the first title screen only, so Quit to Menu stays on the title. The last
three act only on a new run (not on Resume). The first beat is saved before they are added, so use
them with `--nosave`.

## Look arguments

Read by `DebugPanels` after the default preset loads.

| Argument | Effect |
|---|---|
| `--preset=<name or res path>` | Loads a [preset](look_presets.md) before the other arguments, so they can override it |
| `--world-palette=<res path>`, `--perceptual`, `--dither` | World clamp settings ([palette_clamp.md](palette_clamp.md)) |
| `--interface-dither` | Turns dithering on for the interface clamp, which `--dither` does not touch |
| `--corridor-set=property=value` | Sets any `Corridor3D` export (`corridor_settings`). Repeatable |
| `--monster-image=<res path>` | Every enemy uses this image |
| `--ui-palette=<res path>` | Applies an [interface palette](interface_palette.md) before any screen is built |
| `--portrait-palette=<res path, corridor or interface>` | Sets the portrait palette before any screen is built |
| `--background-set=uniform=value` | Sets one [background wear](background_wear.md) setting. Repeatable |
| `--panel-set=uniform=value` | Sets one [panel wear](panel_wear.md) setting. Repeatable |
| `--print-set=name=value` | Sets one [print frame](print_frame.md) border, overlay, layout or token setting. Repeatable |
| `--interface-set=uniform=value` | Sets one interface look setting. Repeatable |
| `--feedback-set=name=value` | Sets one [control feedback](control_feedback.md) setting. Repeatable |
| `--feedback-demo=<amount>` | Holds every control at that much hover |
| `--glow-demo=<brightness>` | Every node drawn through a picture material glows ([interface_glow.md](interface_glow.md)) |
| `--look-panel`, `--interface-panel`, `--print-panel`, `--background-panel`, `--feedback-panel`, `--icon-panel`, `--tokens-panel` | Opens the panel on that tab |

## Dev scenes

Run one directly instead of the game: `<godot> --path . res://src/debug/scenes/<name>.tscn -- <arguments>`.
`--shot` and the look arguments work in all of them.

| Scene | Shows | Its own arguments |
|---|---|---|
| `combat_sandbox` | One real fight between the default character and an enemy (hover to slow down, R restarts) | none |
| `corridor_testbed` | The corridor with Forward and Back buttons; N places a monster ([corridor_3d.md](corridors/corridor_3d.md)) | `--set=property=value` sets a corridor export (repeatable); `--view=WIDTHxHEIGHT` fixes the view size; with `--shot`, `--still` keeps it from moving and `--monster` places a monster |
| `tooltip_demo` | The item tooltip held open over one item ([tooltips.md](tooltips.md)) | none |

## Screenshot commands

Redirect Godot's output to a file and read the `SHOT_SAVED` line; the `PreToolUse` hook in
`.claude/settings.json` requires the redirect.

A real fight with a saved preset (a delay under about 6 seconds catches the corridor approach instead
of the fight):

```
<godot> --path . -- --autostart --autofight --shot --shot-delay 6 --nosave --preset=candlelit > _temp/shot.txt 2>&1; grep SHOT_SAVED _temp/shot.txt
```

A late-run board with allies: add `--allies 2 --board-items 12 --potions 3` to the command above.
