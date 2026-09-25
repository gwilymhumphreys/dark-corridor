# Print frame

A dev tool for making the combat screen look like a printed sheet: a border around the corridor, the
background wear carried over the corridor, a worn corridor edge, a pencil grid behind the player's
items, how far those items sit askew, and the split point and padding of the
[screen sections](ui_layout.md#screen-sections). Every effect is set from the Print tab of the
[debug panel](debug_panel.md); the [background wear](background_wear.md) itself has its own tab.

**Location:** `src/ui/print_frame.gd` (class `PrintFrame`), `src/shaders/print_border.gdshader`,
`src/shaders/corridor_overlay.gdshader`, `src/shaders/board_grid.gdshader`, the Print tab in `src/debug/print_panel.*` (class `PrintPanel`).
The materials, settings, defaults, reset, and writing and reading presets are owned by `PrintLook`
(`src/autoloads/print_look.gd`, class `PrintLookAutoload`), alongside [background wear](background_wear.md)
and [panel wear](panel_wear.md); `DebugPanels` keeps the Print tab and the start-up arguments.

## How it works

- `combat_view_framed.tscn` has a `PrintFrame` node before the corridor panel, holding the `Border`
  rectangle, and a `CorridorOverlay` rectangle after the corridor panel and before the enemy HUDs. The
  border draws behind the corridor; the overlay draws over the corridor image but under the HUDs and
  VFX, so text is never covered.
- Each frame `PrintFrame` sizes the border and overlay around the corridor and hides either one while
  its effects are off. The corridor itself is placed by the screen sections.
- It also sets `print_corridor_rect` on `PrintLook.background_material`, the corridor's rectangle in
  window pixels, so [folds](background_wear.md) can line up with the corridor. It clears it on leaving
  the tree.
- The border is printed in the same ink as the wear on the paper: the line is
  `Colours.UI_BACKGROUND_WEAR` and its rubbed spots are `UI_BACKGROUND_WEAR_LIGHT`, the same pair the
  background wear marks use, so an [interface palette](interface_palette.md) sets both. Pixels off the
  line are fully transparent.
- The overlay reads the corridor from the screen and redraws it. `PrintFrame` copies every background
  wear setting and colour into `PrintLook.overlay_material`, so marks over the corridor match the
  background's and line up across the corridor's edge.
- The board grid is a rectangle behind the player's items in `combat_view_framed.tscn`, drawn through
  `PrintLook.grid_material`: grid paper drawn in pencil, one square per item cell, with each line
  running through the middle of the gap between cells. The potion row has its own grid of three
  squares on the same material. Each grid reads its own rectangle's pixels, so `CombatViewFramed`
  sets only the square size and the pencil colour, `Colours.UI_BACKGROUND_WEAR_LIGHT`.
- The player's items and potions are set down askew on the grid, like cardboard tokens placed by hand: each cell
  has its own random tilt and shift, scaled by the token settings `token_tilt` and `token_shift`
  (`ItemCell.set_askew`, drawn with the visual-only offset transform).
- Item cells use the `PanelToken` theme style ([ui_theme.md](ui_theme.md)): the worn panel with a
  drop shadow onto the paper. `PrintLook.apply_token_style()` writes the shadow and fill settings onto
  `PanelToken` and `PanelTokenWide` whenever a print setting changes, on reset, and when the
  interface palette changes (the shadow colour is `Colours.UI_PANEL_SHADOW`). The fill is
  `Colours.UI_BACKGROUND` blended towards `token_fill_colour` by `token_fill_amount`, so at 0 a token
  has the interface background colour and at 1 the card colour. It is worked out again after a palette
  change, because the palette sets the fill to `UI_BACKGROUND`. The token's edge is the
  panel wear's worn edge ([panel_wear.md](panel_wear.md)); it has no border.
- Two switches try looks on the portrait section. `token_portraits` puts the player and ally
  portraits in `PanelToken` frames instead of `PanelSlot`. `portrait_panel` draws every character panel
  (the player's, each ally's and each enemy's, `character_panel.tscn`) as a `PanelTokenWide` panel
  (`PanelBare`, which draws nothing, when off).
- Three settings try character panel layouts ([run_screen.md](run_screen.md)). `item_layout` is a
  dropdown for where each panel's item cells go: beside (a grid to the right of the name, bar and
  status icons), under the bar, or on the name's line. `status_layout` is a dropdown for the status
  icons: beside the bar or under it. `enemy_panel_background` (on by default) lets the enemy panels
  draw the `portrait_panel` background; off leaves them transparent over the corridor with their
  name, bar, statuses and items still shown. `CombatViewFramed` applies all five settings.
- The token settings are print frame settings (`PRINT_SETTING_DEFAULTS`, saved with the Print part of a
  preset, set with `--print-set=`), but they are shown on their own debug tab, Tokens (F7,
  `TokensPanel`), in five sections: Placement (tilt, shift), Shadow (size, offset, darkness), Fill
  (colour, amount), Portraits (the two switches) and Character panels (the three layout settings).

| Group | Does |
|---|---|
| Layout | Split across and split down: where the screen sections meet. Padding: the space inside every side of each section. Defaults in `PRINT_SETTING_DEFAULTS`. The token settings are on the Tokens tab (above) |
| Print Border | A solid line around the corridor: width, gap from the corridor, edge roughness, rubbed spots and their size |
| Corridor Wear | The background wear, with its current settings, drawn over the corridor too |
| Corridor Worn Edge | The corridor image's edges rubbed away into the background colour, heavier at the corners: width, amount, patch size, corners |
| Board Grid | The pencil grid behind the player's items: squares per item cell, line width, darkness, wobble and its length, pressure, grain, gaps |

The owner's chosen settings are in the print part of the default [look preset](look_presets.md).

## The Print tab

F3 opens the [debug panel](debug_panel.md) on this tab. `PrintPanel` extends the
[Corridor tab](corridor_look.md#the-corridor-tab) and builds its sections the same way: Layout, then
the border and overlay groups, then panel wear. The background wear groups are in the
[Background tab](background_wear.md#the-background-tab).

## In a preset

The print part has sections `print_panel` (every [panel wear](panel_wear.md) uniform), `print_frame`
(every border, overlay and board grid uniform) and `print_layout` (every print frame setting). Reading it starts
from the print defaults. Sizes and colours set by `PrintFrame` are not saved. Background wear is a
part of its own ([background_wear.md](background_wear.md#presets-and-screenshots)).

The presets `print_red_halftone` and `print_red_hatching` are two-ink corridor looks, red on dark grey
like a printed sleeve, using the grade, colour ramp and halftone or hatching. Their names are
placeholders.

For screenshots, `--print-set=<name>=<value>` sets one border, overlay or layout setting (repeatable)
and `--print-panel` opens the Print tab ([dev_tools.md](dev_tools.md#look-arguments)).

## Public API

| Member | Use |
|---|---|
| `PrintLook.border_material`, `overlay_material`, `grid_material`, `panel_material` | The border, corridor overlay, board grid and [panel wear](panel_wear.md) materials |
| `PrintLook.print_settings`, `print_setting(setting) -> Variant` | Print frame settings changed from `PRINT_SETTING_DEFAULTS`, and a setting's current value |
| `PrintLook.set_print_value(name, value)` | Set a border, overlay, board grid or panel wear uniform, or a print frame setting, by name |
| `PrintLook.apply_token_style()` | Write the token shadow and fill settings onto the `PanelToken` and `PanelTokenWide` styles |
| `PrintLook.print_defaults() -> Dictionary`, `panel_defaults() -> Dictionary` | Border/overlay and panel wear uniform defaults, read from the shader code |
| `PrintLook.write_print_look(file)`, `read_print_look(file)`, `reset_print_look()` | The [print part](#in-a-preset) of a preset, and the print defaults |
| `PrintLook.write_background_look(file)`, `read_background_look(file)`, `reset_background_look()` | The [background part](background_wear.md#presets-and-screenshots) of a preset, and the background defaults |

Tests: `tests/debug/test_print_frame.gd`.
