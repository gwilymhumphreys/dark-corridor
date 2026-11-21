# Debug panel

A dev-only panel for trying and saving looks in game, with a [preset bar](look_presets.md) at the top and
one tab per part of the look. It is on every screen, including the [dev scenes](dev_tools.md#dev-scenes).

**Location:** `src/debug/debug_panels.tscn` + `debug_panels.gd`, class `DebugPanelsAutoload`, registered
as the `DebugPanels` autoload. The tabs are `colours_panel.*`, `look_panel.*`, `interface_look_panel.*`,
`print_panel.*`, `background_panel.*`, `feedback_panel.*`, `icon_panel.*`, `tokens_panel.*` and
`reward_spin_panel.*`. The palette rows are in the Colours tab's scene, and `DebugPanels` runs them.

## Tabs

| Tab | Key | Sets |
|---|---|---|
| Colours | F1 | The [palettes](interface_palette.md): the [Colours tab](#the-colours-tab) below |
| Corridor | F2 | The [corridor look](corridor_look.md), light, Environment and fog |
| Interface | F3 | The [interface look](interface_look.md) |
| Print | F4 | [Print frame](print_frame.md) and [panel wear](panel_wear.md) |
| Background | F5 | [Background wear](background_wear.md) on every screen |
| Feedback | F6 | [Control feedback](control_feedback.md): hover, selected and press on interactive controls |
| Icons | F7 | Which icon and colour each [icon slot](mechanics.md#iconslots) uses, with live samples of the choice; a mechanic's colour is written to the [custom mechanic palette](interface_palette.md#the-mechanic-palette) |
| Tokens | F8 | The [cardboard token look](print_frame.md) of items, potions and portraits: placement, shadow, fill, the portrait switches, the character panel layout, the map, the encounter cards dealt before a fight ([run_screen.md](run_screen.md#the-choice-of-encounters)), the pile of character photos on character select, the paper burn effect and the [page turn](page_turn.md), with a Replay button |
| Reward spin | F9 | The reward spin of the draft and shop goods ([run_screen.md](run_screen.md#overlays)): the switch, style and timings, the reel's look and overshoot, with a Spin again button |

The tabs are `DebugPanels.Tab`, not `LookPresets.Part`. A tab that saves its own files rather than
being part of a preset has no `Part`. The Tokens and Reward spin tabs' settings are print frame
settings, so a preset saves them with its Print part.

## Behaviour

- A tab's key opens the panel on that tab, switches to it if another tab is showing, and closes the
  panel if that tab is already showing. Debug builds only (`OS.is_debug_build()`). The autoload
  processes while the game is paused.
- Opening the panel during a run pauses it, like Space, and closing it resumes it
  (`panels_open_changed`, handled by the run screen). Closing does not resume a pause the player chose
  with Space or Escape. A panel opened by a start-up argument does not pause, so screenshot runs keep
  playing.
- Every look tab starts with a "Take this part from" row ([look_presets.md](look_presets.md#the-preset-bar)).
  The Icons tab has none, because it is not a preset part, and neither have the Tokens and Reward
  spin tabs, whose settings belong to the Print part; `LookPanel` treats that row as optional.
- The palette keys below only work while the panel is open, so they never take a game key (the
  battle speed keys are on `[` and `]`, [keybindings.md](keybindings.md)). They are also ignored while
  a text field (the preset name) has focus.
- `]` and `[` select the next and previous entry in the main palette list, and `'` and `;` in the
  mechanic palette list, skipping folder headings and wrapping round through "Off" or "Default".
- `\` moves the selected main palette file (and its `.import` file) into
  `assets/palettes/shortlist/`, rewrites the palette's path in any preset or history file that uses it,
  then rescans the list and keeps that palette selected. It does nothing on "Off", for a palette
  already in the shortlist, or when a file of the same name is there.
- Backspace turns the corridor's dithering on or off, keeping the Corridor tab's Dithering switch in
  step. It does not touch the pictures' and effects' dithering, which has its own switch.
- Changes last for the session only, unless saved as a preset. The default preset loads at start-up.
  `DebugPanels.reset_settings()` turns every part off; `TestCleanup.reset_all_managers()` calls it.
- The palette folder is scanned the first time the Colours tab opens or a palette key is pressed, so
  headless tests and autotest runs do no extra work.
- Every section starts closed, whether or not its effect is on; clicking a section's title shows its
  rows. `LookSection.set_open` overrides that; the Colours tab opens its Main palette section, the
  Icons tab both of its sections (Choose and Samples), and the Reward spin tab both of its (Spin and
  Reel), so their rows are usable without a click.
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
| One section per group of interface colours | A brightness slider for each, with a square showing the palette colour it landed on |
| Mechanic colours | A colour picker for each mechanic colour, writing the custom mechanic palette |

The dithering switches are still the Dithering section headers on the Corridor and Interface tabs. A
mechanic's colour also has a row on the Icons tab, beside its icon; both write the same file.

## Start-up arguments

The look arguments (`--preset=`, `--corridor-set=`, `--look-panel` and the rest) are read once at
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
| `write_corridor_look(file)`, `read_corridor_look(file)`, `reset_look()` | The corridor part of a preset, and the corridor look defaults |
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
