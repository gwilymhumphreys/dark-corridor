# Debug panel

A dev-only panel for comparing looks in game: the full-screen and world palette clamps, plus start-up
arguments for screenshots of real fights. It is on every screen, including the corridor testbed and combat
sandbox. The same autoload holds the F2 [look panel](corridor_look.md).

**Location:** `src/debug/debug_panels.tscn` + `debug_panels.gd`, class `DebugPanelsAutoload`, registered
as the `DebugPanels` autoload.

## Behaviour

- F1 toggles the panel and F2 the look panel, only in debug builds (`OS.is_debug_build()`). The autoload
  processes while the game is paused.
- The palette keys below are ignored while a text field (the look name) has focus.
- `]` and `[` select the next and previous entry in the full-screen Palette list, with the panel open or
  closed, skipping folder headings and wrapping round through "Off". Debug builds only.
- `'` moves the selected full-screen palette file (and its `.import` file) into
  `assets/palettes/shortlist/`, then rescans the list and keeps that palette selected. It does nothing
  on "Off", for a palette already in the shortlist, or when a file of the same name is there.
- Choices last for the session only. `DebugPanels.reset_settings()` restores the defaults;
  `TestCleanup.reset_all_managers()` calls it.
- The palette folder is scanned the first time the panel opens, so headless tests and autotest runs do no
  extra work.
- Built as a `.tscn`, styled by the project theme, with a `UIJuice` node on each control.
- English only. `tools/extract_pot.gd` skips `src/debug/`, so panel labels stay out of the translation
  files.

## Controls

| Control | Effect | Read by |
|---|---|---|
| Palette | "Off", then every palette under `assets/palettes/`, grouped by subfolder. Applies immediately. | [Palette clamp](palette_clamp.md) |
| World palette (corridor) | "Off", then every palette. Applies immediately. | [World clamp](palette_clamp.md#world-clamp) on `CombatCorridor` |
| Colour matching | RGB or perceptual (OKLab), for both clamps. Applies immediately. | Palette clamp |
| Dithering | On or off, for both clamps. Applies immediately. | Palette clamp |

## Start-up arguments

Read once at start-up from the user arguments (after `--`), for screenshots and comparisons:

| Argument | Effect |
|---|---|
| `--palette=<res path>`, `--perceptual`, `--dither` | Palette clamp settings ([palette_clamp.md](palette_clamp.md)) |
| `--world-palette=<res path>` | World clamp palette |
| `--look=<path>` | Loads a [look file](corridor_look.md#look-files) before the other arguments, so they can override it |
| `--look-panel` | Opens the look panel |
| `--corridor-set=property=value` | Sets any `Corridor3D` export (`corridor_settings`). Repeatable |
| `--monster-image=<res path>` | Every enemy uses this image (`MonsterImages.forced_path`) |

For example, a real fight under a palette:
`<godot> --path . -- --autostart --autofight --shot --shot-delay 5 --nosave --notutorial --palette=res://assets/palettes/good/waldgeist-32x.png`

## Public API

| Member | Use |
|---|---|
| `corridor_settings`, `environment_settings` | Corridor exports and corridor camera Environment properties (property -> value), applied when a corridor is built |
| `apply_corridor_settings()` | Apply both to every corridor on screen |
| `set_palette(colours: PackedColorArray)` | Clamp to these colours; empty turns the clamp off |
| `world_palette`, `world_material` | The world clamp palette path (`''` when off) and the corridor look material corridors are drawn through |
| `look_defaults() -> Dictionary` | Look shader uniform defaults, read from the shader code |
| `save_look(path) -> Error`, `load_look(path) -> bool`, `reset_look()` | [Look files](corridor_look.md#look-files) and the look defaults |
| `toggle_look_panel()` | Show or hide the look panel |
| `set_dithering(on)`, `is_dithering()` | The dithering switch for both clamps, kept in step with the panel |
| `set_world_palette(path: String)` | Clamp the combat corridor to this palette file; `''` turns it off |
| `toggle_panel()` | Show or hide the panel |
| `cycle_palette(step: int)` | Select the next (`1`) or previous (`-1`) full-screen palette |
| `shortlist_palette()` | Move the selected full-screen palette into `SHORTLIST_DIR` |
| `move_palette_file(path, folder) -> String` (static) | Move a palette file and its `.import` file; returns the new path or `''` |
| `reset_settings()` | Back to defaults |
