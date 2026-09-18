# Print frame

A dev tool for making the combat screen look like a printed sheet: a border around the corridor, the
background wear carried over the corridor, a worn corridor edge, and the split point and padding of the
[screen sections](ui_layout.md#screen-sections). Every effect is set from the Print tab of the
[debug panel](debug_panel.md); the [background wear](background_wear.md) itself has its own tab.

**Location:** `src/ui/print_frame.gd` (class `PrintFrame`), `src/shaders/print_border.gdshader`,
`src/shaders/corridor_overlay.gdshader`, the Print tab in `src/debug/print_panel.*` (class `PrintPanel`).
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

| Group | Does |
|---|---|
| Layout | Split across and split down: where the screen sections meet. Padding: the space inside every side of each section. Defaults in `PRINT_SETTING_DEFAULTS` |
| Print Border | A solid line around the corridor: width, gap from the corridor, edge roughness, rubbed spots and their size |
| Corridor Wear | The background wear, with its current settings, drawn over the corridor too |
| Corridor Worn Edge | The corridor image's edges rubbed away into the background colour, heavier at the corners: width, amount, patch size, corners |

The owner's chosen settings are in the print part of the default [look preset](look_presets.md).

## The Print tab

F3 opens the [debug panel](debug_panel.md) on this tab. `PrintPanel` extends the
[Corridor tab](corridor_look.md#the-corridor-tab) and builds its sections the same way: Layout, then
the border and overlay groups, then panel wear. The background wear groups are in the
[Background tab](background_wear.md#the-background-tab).

## In a preset

The print part has sections `print_panel` (every [panel wear](panel_wear.md) uniform), `print_frame`
(every border and overlay uniform) and `print_layout` (every print frame setting). Reading it starts
from the print defaults. Sizes and colours set by `PrintFrame` are not saved. Background wear is a
part of its own ([background_wear.md](background_wear.md#presets-and-screenshots)).

The presets `print_red_halftone` and `print_red_hatching` are two-ink corridor looks, red on dark grey
like a printed sleeve, using the grade, colour ramp and halftone or hatching. Their names are
placeholders.

For screenshots, `--print-set=<name>=<value>` sets one border, overlay or layout setting (repeatable)
and `--print-panel` opens the Print tab ([debug_panel.md](debug_panel.md#start-up-arguments)).

## Public API

| Member | Use |
|---|---|
| `PrintLook.border_material`, `overlay_material`, `panel_material` | The border, corridor overlay and [panel wear](panel_wear.md) materials |
| `PrintLook.print_settings`, `print_setting(setting) -> Variant` | Print frame settings changed from `PRINT_SETTING_DEFAULTS`, and a setting's current value |
| `PrintLook.set_print_value(name, value)` | Set a border, overlay or panel wear uniform, or a print frame setting, by name |
| `PrintLook.print_defaults() -> Dictionary`, `panel_defaults() -> Dictionary` | Border/overlay and panel wear uniform defaults, read from the shader code |
| `PrintLook.write_print_look(file)`, `read_print_look(file)`, `reset_print_look()` | The [print part](#in-a-preset) of a preset, and the print defaults |
| `PrintLook.write_background_look(file)`, `read_background_look(file)`, `reset_background_look()` | The [background part](background_wear.md#presets-and-screenshots) of a preset, and the background defaults |

Tests: `tests/debug/test_print_frame.gd`.
