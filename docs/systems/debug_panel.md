# Debug panel

A dev-only panel for trying and saving looks in game, with a [preset bar](look_presets.md) at the top and
one tab per part of the look. It is on every screen, including the [dev scenes](dev_tools.md#dev-scenes).

**Location:** `src/debug/debug_panels.tscn` + `debug_panels.gd`, class `DebugPanelsAutoload`, registered
as the `DebugPanels` autoload. The tabs are `look_panel.*`, `interface_look_panel.*`, `print_panel.*`,
`background_panel.*`, `feedback_panel.*`, `icon_panel.*` and `tokens_panel.*`. The palette rows are in the first two tab scenes, and `DebugPanels` runs them.

## Tabs

| Tab | Key | Sets |
|---|---|---|
| Corridor | F1 | The corridor [palette rows](#palette-rows), the [corridor look](corridor_look.md), light, Environment and fog |
| Interface | F2 | The interface [palette rows](#palette-rows), the [palette colours](#palette-colours), the [interface look](interface_look.md) and [interface glow](interface_glow.md) |
| Print | F3 | [Print frame](print_frame.md) and [panel wear](panel_wear.md) |
| Background | F4 | [Background wear](background_wear.md) on every screen |
| Feedback | F5 | [Control feedback](control_feedback.md): hover, selected and press on interactive controls |
| Icons | F6 | Which icon and colour each [icon slot](mechanics.md#iconslots) uses, with live samples of the choice; a mechanic's colour is written to the [custom palette](interface_palette.md) |
| Tokens | F7 | The [cardboard token look](print_frame.md) of items, potions and portraits: placement, shadow, fill and the portrait switches |

The tabs are `DebugPanels.Tab`, not `LookPresets.Part`. The first five line up
with the parts, but a tab that saves its own files rather than being part of a
preset has no `Part`. The Tokens tab's settings are print frame settings, so a
preset saves them with its Print part.

## Behaviour

- A tab's key opens the panel on that tab, switches to it if another tab is showing, and closes the
  panel if that tab is already showing. Debug builds only (`OS.is_debug_build()`). The autoload
  processes while the game is paused.
- Opening the panel during a run pauses it, like Space, and closing it resumes it
  (`panels_open_changed`, handled by the run screen). Closing does not resume a pause the player chose
  with Space or Escape. A panel opened by a start-up argument does not pause, so screenshot runs keep
  playing.
- Every look tab starts with a "Take this part from" row ([look_presets.md](look_presets.md#the-preset-bar)).
  The Icons tab has none, because it is not a preset part, and neither has the Tokens tab, whose
  settings belong to the Print part; `LookPanel` treats that row as optional.
- The palette keys below are ignored while a text field (the preset name) has focus.
- `]` and `[` select the next and previous entry in the World palette list, `'` and `;` in the
  Interface palette list and `.` and `,` in the Portrait palette list, with the panel open or closed,
  skipping folder headings and wrapping round through "Off". Debug builds only.
- `\` moves the selected world palette file (and its `.import` file) into
  `assets/palettes/shortlist/`, rewrites the palette's path in any preset or history file that uses it,
  then rescans the list and keeps that palette selected. It does nothing on "Off", for a palette
  already in the shortlist, or when a file of the same name is there.
- Backspace turns the world clamp's dithering on or off, keeping the Corridor tab's Dithering
  switch in step. It does not touch the interface clamp, which has its own switch.
- Changes last for the session only, unless saved as a preset. The default preset loads at start-up.
  `DebugPanels.reset_settings()` turns every part off; `TestCleanup.reset_all_managers()` calls it.
- The palette folder is scanned the first time the Corridor or Interface tab opens, so headless tests
  and autotest runs do no extra work.
- Every section starts closed, whether or not its effect is on; clicking a section's title shows its
  rows. `LookSection.set_open` overrides that; the Icons tab opens both of its sections (Choose and
  Samples), so its rows are usable without a click.
- Built as `.tscn` scenes, styled by the project theme, with a `UIJuice` node on each control.
- English only. `tools/extract_pot.gd` skips `src/debug/`, so panel labels stay out of the translation
  files.

## Palette rows

Rows at the top of the Corridor and Interface tabs, below "Take this part from".

| Tab | Control | Effect | Read by |
|---|---|---|---|
| Corridor | World palette (corridor) | "Off", then every palette under `assets/palettes/`, grouped by subfolder | [World clamp](palette_clamp.md#world-clamp) on `CombatCorridor` |
| Corridor | Colour matching | RGB or perceptual (OKLab) | World clamp and the portrait palette clamp |
| Interface | Interface palette | "Off", then every `.gpl` palette with at least one colour named after a `Colours` variable (`InterfacePalette.is_interface_palette`) | [Interface palette](interface_palette.md) |
| Interface | Portrait palette | "Off", "Same as corridor" (the world palette), "Same as interface" (the interface palette), or any palette file | [Interface images](interface_palette.md#images) |

## Palette colours

Above the look effect sections on the Interface tab, one section per group heading in
`src/data/colours.gd` (Mechanics, Statuses, Combat payloads, Relic panels, Beat categories, Combat
view, Map strip, Tooltip, Interface, Control feedback). Each row is a colour picker for one
`Colours` variable; changing one writes it to the [custom palette](interface_palette.md) and makes
that palette active. The grouping is `InterfaceLookPanel.COLOUR_SECTIONS`, not read from
`colours.gd`, so the panel owns its own layout.

`COOLDOWN_FILL` has no row. It is translucent and a `.gpl` carries no alpha, so it cannot be set
from a palette.

A mechanic's colour also has a row on the Icons tab, beside its icon. Both write the same file.

Each clamp's dithering switch is the Dithering section header in its own tab, and the two are
separate. Every control applies immediately. The corridor rows and its dithering are saved in a
preset's corridor part, and the interface rows and its dithering in its interface part.

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
| `set_interface_palette(path: String)`, `interface_palette` | Apply an interface palette file; `''` goes back to the default colours. Also recolours statuses in the current fight |
| `set_portrait_palette(choice: String)`, `portrait_palette` | What the interface images are clamped to: `''` for off, `PORTRAIT_SAME_AS_CORRIDOR`, `PORTRAIT_SAME_AS_INTERFACE`, or a palette file path |
| `interface_palette_changed` (signal) | Emitted after an interface palette is applied or reset; `NamedColourRect` copies its colour again |
| `write_corridor_palette(file)`, `read_corridor_palette(file)` | The `corridor_palette` section of a [preset](look_presets.md)'s corridor part |
| `write_interface_palettes(file)`, `read_interface_palettes(file)` | The `interface_palette` section of a preset's interface part |
| `reset_palettes()` | Every palette choice, matching and both dithering switches back to their defaults |
| `write_corridor_look(file)`, `read_corridor_look(file)`, `reset_look()` | The corridor part of a preset, and the corridor look defaults |
| `world_palette`, `world_material` | The world clamp palette path (`''` when off) and the corridor look material corridors are drawn through |
| `look_defaults() -> Dictionary`, `scene_values()` | Look shader uniform defaults, read from the shader code; the corridor scene's own light and Environment values |
| `set_dithering(on)`, `is_dithering()` | The world clamp's dithering switch, kept in step with the panel |
| `set_interface_dithering(on)`, `is_interface_dithering()` | The interface clamp's dithering switch, separate from the world clamp's |
| `set_world_palette(path: String)` | Clamp the combat corridor to this palette file; `''` turns it off |
| `cycle_palette(step: int)`, `cycle_interface_palette(step: int)`, `cycle_portrait_palette(step: int)` | Select the next (`1`) or previous (`-1`) world, interface or portrait palette |
| `shortlist_palette()` | Move the selected world palette into `SHORTLIST_DIR` |
| `move_palette_file(path, folder) -> String` (static) | Move a palette file and its `.import` file; returns the new path or `''` |
| `reset_settings()` | Every part of the look off, including the interface palette |

The [print frame](print_frame.md#public-api), [background wear](background_wear.md) and
[panel wear](panel_wear.md) materials and settings are owned by `PrintLook`, not `DebugPanels`.
