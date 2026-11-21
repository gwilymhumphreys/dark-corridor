# Print frame

A dev tool for making the combat screen look like a printed sheet: a border around the corridor, the
background wear carried over the corridor, a worn corridor edge, a pencil grid behind the player's
items, how far those items sit askew, and the padding of the
[screen sections](ui_layout.md#screen-sections). The border, the corridor overlay and the grid are
set on the Wear tab of the [debug panel](debug_panel.md), with the [background wear](background_wear.md),
and the padding and token settings on the Layout tab.

**Location:** `src/ui/print_frame.gd` (class `PrintFrame`), `src/shaders/print_border.gdshader`,
`src/shaders/corridor_overlay.gdshader`, `src/shaders/board_grid.gdshader`, the Wear and Layout tabs in `src/debug/wear_panel.*` and
`layout_panel.*`.
The materials, settings, defaults, reset, and writing and reading presets are owned by `PrintLook`
(`src/autoloads/print_look.gd`, class `PrintLookAutoload`), alongside [background wear](background_wear.md)
and [panel wear](panel_wear.md); `DebugPanels` keeps the tabs and the start-up arguments.

## How it works

- `combat_view_framed.tscn` has a `PrintFrame` node before the corridor panel, holding the `Border`
  rectangle, and a `CorridorOverlay` rectangle after the corridor panel and before the enemy HUDs. The
  border draws behind the corridor; the overlay draws over the corridor image but under the HUDs and
  VFX, so text is never covered.
- Each frame `PrintFrame` sizes the border and overlay around the corridor and hides either one while
  its effects are off. The corridor itself is placed by the screen sections.
- The border is printed in the same ink as the wear on the paper: the line is
  `Colours.UI_BACKGROUND_WEAR` and its rubbed spots are `UI_BACKGROUND_WEAR_LIGHT`, the same pair the
  background wear marks use, so the [main palette](interface_palette.md) sets both. Pixels off the
  line are fully transparent.
- The overlay reads the corridor from the screen and redraws it. `PrintFrame` copies every background
  wear setting and colour, and the fold positions, into `PrintLook.overlay_material`, so marks over the
  corridor match the background's and line up across the corridor's edge.
- The board grid is a rectangle behind the player's items in `combat_view_framed.tscn`, drawn through
  `PrintLook.grid_material`: grid paper drawn in pencil, one square per item cell, with each line
  running through the middle of the gap between cells. The potion row has its own grid of three
  squares on the same material. Each grid reads its own rectangle's pixels, so `CombatViewFramed`
  sets only the square size and the pencil colour, `Colours.UI_BACKGROUND_WEAR_LIGHT`. The gold box
  uses it too. The same material draws a single pencil rectangle instead of a grid when a node sets
  its `box_size` instance uniform, divided into equal cells by its `box_cells` instance uniform; the
  allies box (`PanelPencilBox`) is drawn this way, with a cell for each ally slot. With its
  `underline` instance uniform as well it draws one line along the node's bottom edge instead:
  `PencilLine` (`src/ui/pencil_line.gd`) sets both, and draws the write-in lines under the Name and
  Class fields.
- The player's items and potions are set down askew on the grid, like cardboard tokens placed by hand: each cell
  has its own random tilt and shift, scaled by the token settings `token_tilt` and `token_shift`
  (`ItemCell.set_askew`, drawn with the visual-only offset transform). The tilt and shift come from
  the cell's place in its row, so the cells rebuilt when a fight starts or ends sit as they did before.
- Item cells use the `PanelToken` theme style ([ui_theme.md](ui_theme.md)): the worn panel with a
  drop shadow onto the paper. `PrintLook.apply_token_style()` writes the shadow and fill settings onto
  `PanelToken` and `PanelTokenWide` whenever a print setting changes, on reset, and when the
  palettes are applied (the shadow colour is `Colours.UI_PANEL_SHADOW`). The fill is
  `Colours.UI_BACKGROUND` blended towards the card colour `Colours.UI_TOKEN_CARD` by
  `token_fill_amount`, so at 0 a token has the interface background colour and at 1 the card colour.
  Both colours come from the [main palette](interface_palette.md), so the fill is worked out again
  after a palette change. The token's edge is the
  panel wear's worn edge ([panel_wear.md](panel_wear.md)); it has no border.
- `token_portraits` puts the ally and enemy portraits in `PanelToken` frames instead of
  `PanelSlot`; the player's portrait is always in a `PanelToken` frame, so it has the items' drop
  shadow. `panel_background` is a dropdown for which character panels (`character_panel.tscn`) are
  drawn as a `PanelTokenWide` panel: none, the player's and the allies', the enemies', or all of them
  (`CharacterPanel.PanelBackground`). The others use `PanelBare`, which draws nothing, so an enemy
  panel without one sits transparent over the corridor.
- Three settings try character panel layouts ([run_screen.md](run_screen.md)). `item_layout` is a
  dropdown for where each panel's item cells go: beside (a grid to the right of the name, bar and
  status icons), under the bar, or on the name's line. `status_layout` is a dropdown for the status
  icons: beside the bar, under it, or under the items. `allies_box` (on by default) puts the ally rows
  in a box labelled "Allies" when the portraits are above the items, shown even with no allies.
  `medium_token_size`, `ally_item_size` and `status_size`
  are sliders for the enemy and ally item cells and the status icons, in pixels
  (`medium_token_size` is the medium token size, which the map tokens also use), and `pill_size`
  scales every value pill (item values and status stacks) together. `CombatViewFramed`
  applies all of these settings.
- `level_tag_corner` (a dropdown: top left, top right, bottom left, bottom right) and `level_tag_size`
  place and scale the level tag on an item cell above level 1 ([item.md → Levels](item.md#levels)).
  `ItemCell` applies them. The tag is a placeholder look.
- `map_icons_as_pictures` (on by default) draws the map's icons with the item icons' material, so they
  take every picture effect ([interface_look.md](interface_look.md)). Off, they use the interface
  element material like the value pills and keep their exact palette colour, which made them stand
  out against the graded item icons and portraits. `MapStrip` applies it. `map_cleared_look` is a
  dropdown for a cleared map square: its token face down, or burnt away when its fight is won (the
  default).
- The `paper_burn_*` settings set the [paper burn](paper_burn.md) effect, and the `page_turn_*`
  settings the [page turn](page_turn.md) between screens.
- Every setting in `PRINT_SETTING_DEFAULTS` is set with `--print-set=` and saved in the `print_layout`
  section of a preset. They are shown on three tabs: the Layout tab (`LayoutPanel`) has Spacing,
  Token placement (tilt, shift), Token shadow (size, offset, darkness), Token fill (amount; the card
  colour is the interface colour `UI_TOKEN_CARD`), Portraits (the portrait switch), Character panels
  (the layout, background, allies box and size settings), Item levels and Map (the map icon switch and
  the cleared square look); the Effects tab has the paper burn; the Motion tab has the encounter
  cards, character photos, page turn and reward spin ([run_screen.md](run_screen.md#overlays)).

| Group | Does |
|---|---|
| Spacing (Layout tab) | Padding: the space inside every side of each screen section ([ui_layout.md](ui_layout.md#screen-sections)), and the character sheet's section gap and label gap. Defaults in `PRINT_SETTING_DEFAULTS` |
| Print Border | A solid line around the corridor: width, gap from the corridor, edge roughness, rubbed spots and their size |
| Corridor Wear | The background wear, with its current settings, drawn over the corridor too |
| Corridor Worn Edge | The corridor image's edges rubbed away into the background colour, heavier at the corners: width, amount, patch size, corners |
| Board Grid | The pencil grid behind the player's items: squares per item cell, line width, darkness, wobble and its length, pressure, grain, gaps |

The owner's chosen settings are in the default [look preset](look_presets.md).

## The Wear and Layout tabs

F4 opens the Wear tab: background wear, panel wear, picture wear, then the corridor overlay, border
and grid groups. F5 opens the Layout tab. Both extend the
[Corridor tab](corridor_look.md#the-corridor-tab) and build their sections the same way.

## In a preset

The sections are `print_panel` (every [panel wear](panel_wear.md) uniform), `print_frame` (every
border, overlay and board grid uniform) and `print_layout` (every print frame setting). The first two
belong to the wear part; `print_layout` is split between the layout, effects and motion parts
([look_presets.md](look_presets.md#parts)). Sizes and colours set by `PrintFrame` are not saved.

For screenshots, `--print-set=<name>=<value>` sets one border, overlay or layout setting (repeatable)
and `--wear-panel` and `--layout-panel` open those tabs ([dev_tools.md](dev_tools.md#look-arguments)).

## Public API

| Member | Use |
|---|---|
| `PrintLook.border_material`, `overlay_material`, `grid_material`, `panel_material` | The border, corridor overlay, board grid and [panel wear](panel_wear.md) materials |
| `PrintLook.print_settings`, `print_setting(setting) -> Variant` | Print frame settings changed from `PRINT_SETTING_DEFAULTS`, and a setting's current value |
| `PrintLook.set_print_value(name, value)` | Set a border, overlay, board grid or panel wear uniform, or a print frame setting, by name |
| `PrintLook.apply_sheet_spacing()` | Write the `section_gap` and `label_gap` print settings onto the `Sheet*` theme variations ([ui_theme.md](ui_theme.md#spacing-on-the-character-sheet)) |
| `PrintLook.apply_token_style()` | Write the token shadow and fill settings onto the `PanelToken` and `PanelTokenWide` styles |
| `PrintLook.print_defaults() -> Dictionary`, `panel_defaults() -> Dictionary` | Border/overlay and panel wear uniform defaults, read from the shader code |
| `PrintLook.write_print_look(file)`, `read_print_look(file)`, `reset_print_look()` | The [print sections](#in-a-preset) of a preset, and the print defaults |
| `PrintLook.write_background_look(file)`, `read_background_look(file)`, `reset_background_look()` | The [background wear section](background_wear.md#presets-and-screenshots) of a preset, and the background defaults |

Tests: `tests/debug/test_print_frame.gd`.
