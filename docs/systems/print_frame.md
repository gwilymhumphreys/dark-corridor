# Print frame

A dev tool for making the combat screen look like a printed sheet: a border around the corridor, the
background wear carried over the corridor, a worn corridor edge, and the corridor moved in from the
screen edges to make room. Every effect is set from the F5 print panel, together with the
[background wear](background_wear.md).

**Location:** `src/ui/print_frame.gd` (class `PrintFrame`), `src/shaders/print_border.gdshader`,
`src/shaders/corridor_overlay.gdshader`, the panel in `src/debug/print_panel.*` (class `PrintPanel`).
The materials, settings, defaults and save/load/reset are owned by `PrintLook`
(`src/autoloads/print_look.gd`, class `PrintLookAutoload`), alongside [background wear](background_wear.md)
and [panel wear](panel_wear.md); `DebugPanels` keeps the F5 panel UI and the start-up arguments and
delegates to `PrintLook`.

## How it works

- `combat_view_framed.tscn` has a `PrintFrame` node before `CorridorPanel`, holding the `Border`
  rectangle, and a `CorridorOverlay` rectangle after `CorridorPanel` and before the enemy HUDs. The
  border draws behind the corridor; the overlay draws over the corridor image but under the HUDs and
  VFX, so text is never covered.
- Each frame `PrintFrame` moves the corridor in from its place in the scene by the corridor margin on
  every side, sizes the border and overlay around it, and hides either one while its effects are off.
  Enemy HUDs follow the corridor through `CombatCorridor.enemy_anchor`.
- It also sets `print_corridor_rect` on `PrintLook.background_material`, the corridor's rectangle in
  window pixels, so [folds](background_wear.md) can line up with the corridor. It clears it on leaving
  the tree.
- The border line is `Colours.UI_BORDER` with rubbed spots in `UI_BACKGROUND_WEAR`, so an
  [interface palette](interface_palette.md) can set both. Pixels off the line are fully transparent.
- The overlay reads the corridor from the screen and redraws it. `PrintFrame` copies every background
  wear setting and colour into `PrintLook.overlay_material`, so marks over the corridor match the
  background's and line up across the corridor's edge.

| Group | Does |
|---|---|
| Layout | Corridor margin: how far the corridor moves in on each side. Default in `PRINT_SETTING_DEFAULTS` |
| Print Border | A solid line around the corridor: width, gap from the corridor, edge roughness, rubbed spots and their size |
| Corridor Wear | The background wear, with its current settings, drawn over the corridor too |
| Corridor Worn Edge | The corridor image's edges rubbed away into the background colour, heavier at the corners: width, amount, patch size, corners |

The defaults are the owner's saved print look, `assets/print_looks/default.cfg`: the wear over the
corridor and the worn corridor edge are on, and the border is off.

## The print panel

- F5 toggles it, in debug builds. `PrintPanel` extends the [look panel](corridor_look.md#the-panel)
  and builds its sections the same way: the background wear groups, then Layout, then the border and
  overlay groups.
- Its save, load and reset work on print looks only, so the F2 and F5 panels keep separate saved looks
  and resetting one leaves the other unchanged.

## Print looks

A print look is a `ConfigFile` in `assets/print_looks/` with sections `background` (every background wear
uniform), `panel` (every [panel wear](panel_wear.md) uniform), `print` (every border and overlay
uniform) and `layout` (the print frame settings that were changed). Loading starts from the print
defaults. Sizes and colours set by `PrintFrame` are not saved.

`assets/looks/print_red_halftone.cfg` and `print_red_hatching.cfg` are two-ink corridor looks for the F2
panel, red on dark grey like a printed sleeve, using the grade, colour ramp and halftone or hatching.
Their names are placeholders.

For screenshots, `--print-look=<res path>` loads a print look, `--print-set=<name>=<value>` sets one
border, overlay or layout setting (repeatable) and `--print-panel` opens the panel
([debug_panel.md](debug_panel.md#start-up-arguments)).

## Public API

| Member | Use |
|---|---|
| `PrintLook.border_material`, `overlay_material`, `panel_material` | The border, corridor overlay and [panel wear](panel_wear.md) materials |
| `PrintLook.print_settings`, `print_setting(setting) -> Variant` | Print frame settings changed from `PRINT_SETTING_DEFAULTS`, and a setting's current value |
| `PrintLook.set_print_value(name, value)` | Set a border, overlay or panel wear uniform, or a print frame setting, by name |
| `PrintLook.print_defaults() -> Dictionary`, `panel_defaults() -> Dictionary` | Border/overlay and panel wear uniform defaults, read from the shader code |
| `PrintLook.save_print_look(path) -> Error`, `load_print_look(path) -> bool`, `reset_print_look()` | [Print looks](#print-looks) and the print defaults |
| `DebugPanels.toggle_print_panel()` | Show or hide the print panel |

Tests: `tests/debug/test_print_frame.gd`.
