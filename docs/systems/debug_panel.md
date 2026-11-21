# Debug panel

A dev-only panel for trying and saving looks in game, with a [preset bar](look_presets.md) at the top and
one tab per part of the look. It is on every screen, including the [dev scenes](dev_tools.md#dev-scenes).

**Location:** `src/debug/debug_panels.tscn` + `debug_panels.gd`, class `DebugPanelsAutoload`, registered
as the `DebugPanels` autoload. The tabs are `colours_panel.*`, `look_panel.*`, `interface_look_panel.*`,
`wear_panel.*`, `layout_panel.*`, `effects_panel.*`, `motion_panel.*` and `icon_panel.*`; all extend
`LookPanel`. The palette rows are in the Colours tab's scene, and `DebugPanels` runs them.

## Tabs

Each tab holds one kind of setting. The tabs sit in key order from the left, so their titles leave the
keys out.

| Tab | Key | Sets |
|---|---|---|
| Colours | F1 | The [palettes](interface_palette.md) and both dithering switches: the [Colours tab](#the-colours-tab) below |
| Corridor | F2 | The [corridor look](corridor_look.md) filters, view, light, Environment and fog |
| Pictures | F3 | The [interface look](interface_look.md) filters on pictures, bars, pills and effects, and [interface glow](interface_glow.md) |
| Wear | F4 | Print wear everywhere: [background wear](background_wear.md), [panel wear](panel_wear.md), [picture wear](interface_look.md#picture-wear), and the corridor overlay, border and pencil grid of the [print frame](print_frame.md) |
| Layout | F5 | Spacing, the [cardboard token](print_frame.md) placement, shadow and fill, the portrait switch, the character panels, item levels and the map |
| Effects | F6 | The [combat effects](interface_look.md#the-combat-effects)' own settings, the [hit effect trials](vfx_driver.md), the [hit lights](corridors/corridor_3d.md#hit-lights) and the [paper burn](paper_burn.md) |
| Motion | F7 | [Control feedback](control_feedback.md) (hover and press), the encounter cards dealt before a fight and the character photos ([run_screen.md](run_screen.md)), the [page turn](page_turn.md) and the reward spin, each animation with a button to play it again |
| Icons | F8 | Which icon and colour each [icon slot](mechanics.md#iconslots) uses, with live samples of the choice; a mechanic's colour is written to the [custom mechanic palette](interface_palette.md#the-mechanic-palette) |

The tabs are `DebugPanels.Tab`. Every tab but Icons is the `LookPresets.Part` at the same position, and
its "Take this part from" row loads that part ([look_presets.md](look_presets.md#parts)). One shader's
groups can be spread over tabs: `LookPanel._build_shader_sections` takes a filter on group names.

## Behaviour

- A tab's key opens the panel on that tab, switches to it if another tab is showing, and closes the
  panel if that tab is already showing. Debug builds only (`OS.is_debug_build()`). The autoload
  processes while the game is paused.
- Opening the panel during a run pauses it, like Space, and closing it resumes it
  (`panels_open_changed`, handled by the run screen). Closing does not resume a pause the player chose
  with Space or Escape. A panel opened by a start-up argument does not pause, so screenshot runs keep
  playing.
- Every tab but Icons starts with a "Take this part from" row ([look_presets.md](look_presets.md#the-preset-bar)).
  The Icons tab is not a preset part; `LookPanel` treats that row as optional.
- The palette keys below only work while the panel is open, so they never take a game key (the
  battle speed keys are on `[` and `]`, [keybindings.md](keybindings.md)). They are also ignored while
  a text field (the preset name) has focus.
- `]` and `[` select the next and previous entry in the main palette list, and `'` and `;` in the
  mechanic palette list, skipping folder headings and wrapping round through "Off" or "Default".
- `\` moves the selected main palette file (and its `.import` file) into
  `assets/palettes/shortlist/`, rewrites the palette's path in any preset or history file that uses it,
  then rescans the list and keeps that palette selected. It does nothing on "Off", for a palette
  already in the shortlist, or when a file of the same name is there.
- Backspace turns the corridor's dithering on or off, keeping the Colours tab's Corridor dithering
  switch in step. It does not touch the pictures' and effects' dithering, which has its own switch.
- Changes last for the session only, unless saved as a preset. The default preset loads at start-up.
  `DebugPanels.reset_settings()` turns every part off; `TestCleanup.reset_all_managers()` calls it.
- The palette folder is scanned the first time the Colours tab opens or a palette key is pressed, so
  headless tests and autotest runs do no extra work.
- Every section starts closed, whether or not its effect is on; clicking a section's title shows its
  rows. `LookSection.set_open` overrides that; the Colours tab opens its Main palette section and the
  Icons tab both of its sections (Choose and Samples), so their rows are usable without a click.
- Built as `.tscn` scenes, styled by the project theme, with a `UIJuice` node on each control.
- English only. `tools/extract_pot.gd` skips `src/debug/`, so panel labels stay out of the translation
  files.

## The Colours tab

`ColoursPanel`. Every control applies at once and is saved in a preset's colours part.

| Row or section | Sets |
|---|---|
| Main palette | "Off", then every palette under `assets/palettes/` outside `mechanics/`, grouped by subfolder. A strip of its colours, dark to light, sits under it |
| Colour matching | RGB or perceptual (OKLab), for every snapped part |
| Mechanic palette | "Default", then every file in `assets/palettes/mechanics/` |
| Main palette section | The darkest colour setting (Off, Add a darker colour, Replace the darkest colour) and the colour it uses; Snap corridor, Snap pictures, Snap effects |
| Corridor dithering, Picture and effect dithering | Each section's switch turns that clamp's dithering on; its rows are the dither pattern, size and supersample |
| One section per group of interface colours | A brightness slider for each, with a square showing the palette colour it landed on |
| Mechanic colours | A colour picker for each mechanic colour, writing the custom mechanic palette |

A mechanic's colour also has a row on the Icons tab, beside its icon; both write the same file.

## Start-up arguments

The look arguments (`--preset=`, `--corridor-set=`, `--colours-panel` and the rest) are read once at
start-up, after the default preset, by `_apply_command_line`. The list and the screenshot commands are
in [dev_tools.md](dev_tools.md#look-arguments).

## Public API

| Member | Use |
|---|---|
| `toggle_tab(tab: int)`, `is_panel_open()` | Open, switch or close the panel; `tab` is a `DebugPanels.Tab` |
| `refresh_panels()` | Show the current settings in every tab after they change elsewhere |
| `panels_open_changed` (signal) | Emitted with true when the panel opens and false when it closes |
| `corridor_settings`, `environment_settings` | Corridor exports and corridor camera Environment properties (property -> value), applied when a corridor is built |
| `apply_corridor_settings()` | Apply both to every corridor on screen |
| `set_slot_icon(slot: String, path: String)` | Choose an [icon slot](mechanics.md#iconslots)'s icon: saves it, writes it into the shared `Mechanic` instances, and updates statuses in the current fight |
| `icons_changed` (signal) | Emitted after an icon slot's icon changes, so a node that copied one when built can take the new one |
| `set_main_palette(path)`, `set_mechanic_palette(path)`, `set_palette_setting(name, value)`, `apply_palettes()`, `colours_changed` (signal), `write_palettes(file)`, `read_palettes(file)`, `reset_palettes()` | The palettes; see [interface_palette.md](interface_palette.md#public-api) |
| `write_corridor_look(file)`, `read_corridor_look(file)`, `reset_look()` | The corridor look's preset sections, and the corridor look defaults |
| `world_material` | The corridor look material corridors are drawn through; its palette is the main palette while Snap corridor is on |
| `look_defaults() -> Dictionary`, `scene_values()` | Look shader uniform defaults, read from the shader code; the corridor scene's own light and Environment values |
| `set_dithering(on)`, `is_dithering()` | The corridor's dithering switch, kept in step with the panel |
| `set_interface_dithering(on)`, `is_interface_dithering()` | The pictures' and combat effects' dithering switch, separate from the corridor's |
| `cycle_palette(step: int)`, `cycle_mechanic_palette(step: int)` | Select the next (`1`) or previous (`-1`) main or mechanic palette |
| `shortlist_palette()` | Move the selected main palette into `SHORTLIST_DIR` |
| `move_palette_file(path, folder) -> String` (static) | Move a palette file and its `.import` file; returns the new path or `''` |
| `reset_settings()` | Every part of the look off, including both palettes |

The [print frame](print_frame.md#public-api), [background wear](background_wear.md) and
[panel wear](panel_wear.md) materials and settings are owned by `PrintLook`, not `DebugPanels`.
