# Debug panel

A dev-only panel for comparing looks in game: the world and interface palettes, plus start-up
arguments for screenshots of real fights. It is on every screen, including the corridor testbed and combat
sandbox. The same autoload holds the F2 [look panel](corridor_look.md) and the F3
[print panel](print_frame.md).

**Location:** `src/debug/debug_panels.tscn` + `debug_panels.gd`, class `DebugPanelsAutoload`, registered
as the `DebugPanels` autoload.

## Behaviour

- F1 toggles the panel, F2 the look panel and F3 the print panel, only in debug builds (`OS.is_debug_build()`). The autoload
  processes while the game is paused.
- The palette keys below are ignored while a text field (a look or palette combo name) has focus.
- `]` and `[` select the next and previous entry in the World palette list, and `'` and `;` in the
  Interface palette list, with the panel open or closed, skipping folder headings and wrapping round
  through "Off". Debug builds only.
- `\` moves the selected world palette file (and its `.import` file) into
  `assets/palettes/shortlist/`, then rescans the list and keeps that palette selected. It does nothing
  on "Off", for a palette already in the shortlist, or when a file of the same name is there.
- Choices last for the session only, unless saved. `DebugPanels.reset_settings()` restores the
  defaults; `TestCleanup.reset_all_managers()` calls it.
- A **palette combo** is a saved set of palette choices: world palette, interface palette, colour
  matching and dithering. Combos are `.cfg` files in `assets/palette_combos/`, listed each time the
  panel opens.
- The combo chosen in "Load at start-up" is remembered in `START_UP_PATH` (`user://`, this computer
  only) and loaded before the start-up arguments. It is skipped in headless runs (tests, autotest),
  with `--shot`, and when an argument in `PALETTE_ARGUMENTS` sets palettes, so those runs stay
  predictable.
- The palette folder is scanned the first time the panel opens, so headless tests and autotest runs do no
  extra work.
- Built as a `.tscn`, styled by the project theme, with a `UIJuice` node on each control.
- English only. `tools/extract_pot.gd` skips `src/debug/`, so panel labels stay out of the translation
  files.

## Controls

| Control | Effect | Read by |
|---|---|---|
| World palette (corridor) | "Off", then every palette under `assets/palettes/`, grouped by subfolder. Applies immediately. | [World clamp](palette_clamp.md#world-clamp) on `CombatCorridor` |
| Interface palette | "Off", then every `.gpl` palette. Applies immediately. | [Interface palette](interface_palette.md) |
| Font | "Game default" (the `Prefs` font), then every font file in `assets/fonts/candidates/`. Applies immediately. | The project theme's default font ([ui_theme.md](ui_theme.md#font-candidates)) |
| Colour matching | RGB or perceptual (OKLab). Applies immediately. | World clamp |
| Dithering | On or off. Applies immediately. | World clamp |
| Save palette combo | Saves the current palette choices under the typed name, replacing a combo of the same name. | `load_palette_combo()` |
| Load palette combo | Applies a saved combo. | The palettes above |
| Load at start-up | "None", or a saved combo to load when the game starts. | `_apply_start_up_palette_combo()` |

## Start-up arguments

Read once at start-up from the user arguments (after `--`), for screenshots and comparisons:

| Argument | Effect |
|---|---|
| `--world-palette=<res path>`, `--perceptual`, `--dither` | World clamp settings ([palette_clamp.md](palette_clamp.md)) |
| `--look=<path>` | Loads a [look file](corridor_look.md#look-files) before the other arguments, so they can override it |
| `--look-panel` | Opens the look panel |
| `--corridor-set=property=value` | Sets any `Corridor3D` export (`corridor_settings`). Repeatable |
| `--monster-image=<res path>` | Every enemy uses this image (`MonsterImages.forced_path`) |
| `--font=<res path>` | The project theme's default font becomes this font file, replacing the one `Prefs` set ([ui_theme.md](ui_theme.md#font-candidates)) |
| `--ui-palette=<res path>` | Applies an [interface palette](interface_palette.md) before any screen is built |
| `--background-set=uniform=value` | Sets one [background wear](background_wear.md) setting. Repeatable |
| `--print-look=<path>` | Loads a [print look](print_frame.md#print-looks) before the other arguments, so they can override it |
| `--palette-combo=<path>` | Loads a palette combo before the other arguments, so they can override it |
| `--print-set=name=value` | Sets one [print frame](print_frame.md) border, overlay or layout setting. Repeatable |
| `--print-panel` | Opens the print panel |

For example, a real fight under a world palette:
`<godot> --path . -- --autostart --autofight --shot --shot-delay 5 --nosave --notutorial --world-palette=res://assets/palettes/good/waldgeist-32x.png`

## Public API

| Member | Use |
|---|---|
| `corridor_settings`, `environment_settings` | Corridor exports and corridor camera Environment properties (property -> value), applied when a corridor is built |
| `apply_corridor_settings()` | Apply both to every corridor on screen |
| `set_ui_font(path: String)`, `ui_font` | Use this font file as the project theme's default font; `ui_font` is that path, or `''` for the game's default font |
| `set_interface_palette(path: String)`, `interface_palette` | Apply an interface palette file; `''` goes back to the default colours. Also recolours statuses in the current fight |
| `interface_palette_changed` (signal) | Emitted after an interface palette is applied or reset; `NamedColourRect` copies its colour again |
| `save_palette_combo(path) -> Error`, `load_palette_combo(path) -> bool`, `palette_combo_path(name)` (static) | Palette combo files |
| `start_up_palette_combo()`, `set_start_up_palette_combo(name)`, `start_up_combo_allowed(args, headless)` (all static) | The combo loaded at start-up, and whether a run may load it |
| `world_palette`, `world_material` | The world clamp palette path (`''` when off) and the corridor look material corridors are drawn through |
| `background_material`, `background_defaults() -> Dictionary` | The [background wear](background_wear.md) material every screen background is drawn through, and its uniform defaults |
| `look_defaults() -> Dictionary` | Look shader uniform defaults, read from the shader code |
| `save_look(path) -> Error`, `load_look(path) -> bool`, `reset_look()` | [Look files](corridor_look.md#look-files) and the look defaults |
| `toggle_look_panel()` | Show or hide the look panel |
| `border_material`, `overlay_material`, `print_settings`, `print_setting()`, `set_print_value()`, `print_defaults()`, `save_print_look()`, `load_print_look()`, `reset_print_look()`, `toggle_print_panel()` | The [print frame](print_frame.md#public-api) |
| `set_dithering(on)`, `is_dithering()` | The world clamp's dithering switch, kept in step with the panel |
| `set_world_palette(path: String)` | Clamp the combat corridor to this palette file; `''` turns it off |
| `toggle_panel()` | Show or hide the panel |
| `cycle_palette(step: int)`, `cycle_interface_palette(step: int)` | Select the next (`1`) or previous (`-1`) world or interface palette |
| `shortlist_palette()` | Move the selected world palette into `SHORTLIST_DIR` |
| `move_palette_file(path, folder) -> String` (static) | Move a palette file and its `.import` file; returns the new path or `''` |
| `reset_settings()` | Back to defaults, including the interface palette |
