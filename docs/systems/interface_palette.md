# Interface palette

A dev tool that recolours the interface from a palette file, for comparing interface colour schemes
next to corridor looks. It changes colour values only; no shader runs over the interface.

**Location:** `src/debug/interface_palette.gd` (class `InterfacePalette`), `src/data/colours.gd`,
`src/ui/named_colour_rect.gd`. Palettes in `assets/palettes/new/ui/`. Chosen from the
[debug panel](debug_panel.md).

## Palette files

A GIMP `.gpl` file whose colour names match `Colours` variables, written in lower case with spaces:
`hp bar fill` sets `Colours.HP_BAR_FILL`. Colours with no name are ignored, names that match no variable
give a warning, and any variable the file leaves out keeps its default.

`assets/palettes/new/ui/ui-default.gpl` lists every name at its default colour; copy it to start a new
palette. A test checks that every name in it matches a variable. The other files in that folder are
placeholder candidates.

## What it changes

| Part | How |
|---|---|
| `Colours` variables | Set by name. They are static variables so they can be replaced, but keep constant-style names. |
| Colours placed in scenes | Health bars, portraits and the potion swatch are `NamedColourRect` nodes, which copy their `Colours` variable (`colour_name`) when they enter the tree. Screen backgrounds are `ScreenBackground`, a `NamedColourRect` that also passes the [background wear](background_wear.md) mark colours. |
| Theme font colours | Each is placed by brightness on the `UI_TEXT_*` colours, dark to light, blending between the two nearest. |
| Theme images and flat panel colours | Every pixel of the theme's still-textured panel, button, item-cell and checkbox images is placed by brightness on the `UI_PANEL_*` colours in the same way. A [`WornStyleBox`](panel_wear.md) is recoloured through its wrapped `base`. The recoloured images are new textures; the files on disk are unchanged. |
| `PaletteStyleBox` fills | The theme's flat, palette-following panel styles ([ui_theme.md](ui_theme.md#flat-palette-following-panels)) are a `PaletteStyleBox` (`src/ui/palette_style_box.gd`) naming a `Colours` variable in its `colour_name`. Its `bg_color` is set straight from that variable, not the `UI_PANEL_*` brightness ramp, both when a palette is applied and on reset. |
| Panel wear mark colours | `Colours.UI_PANEL_WEAR` / `UI_PANEL_WEAR_LIGHT`, pushed into `PrintLook.panel_material` (`PrintLook.push_wear_colours()`) alongside the [background wear](background_wear.md) colours. |

The `UI_PANEL_*` and `UI_TEXT_*` defaults are the greys the theme already uses, so a palette that does
not set them leaves the theme unchanged. `InterfacePalette.reset()` restores the defaults, the original
images and the theme colours.

Effect colours (`DAMAGE`, `STATUS_*` and so on) are shared by item value badges, status swatches,
projectiles, damage numbers and the corridor's [hit lights](corridors/corridor_3d.md#hit-lights), so an
interface palette changes all of them. Effects have no palette of
their own (owner, 2026-09-15): interface colours keep them coherent with the interface and stand out
against the desaturated corridor.

## Limits

- Things that copy `Colours` when built are updated when a palette is applied or reset, so it can be
  switched mid-fight:
  - Item, relic and potion definitions and keyword cards: `refresh_colours()` on each catalog.
  - `NamedColourRect` nodes (and `ScreenBackground`): `DebugPanels.interface_palette_changed`.
  - Statuses in the current fight: `DebugPanels.set_interface_palette` gives each the colour a new
    status of its class would have.
- Still not updated until rebuilt: the combat sandbox's `BoardView` portraits, combat-scoped summons'
  statuses, and projectiles already in flight. The `--ui-palette=` start-up argument applies before
  anything is built.
- Item icons, enemy images and the corridor are not changed. Text colours set in code as per-instance
  overrides (the value badge text and outline) are not changed.
- Reads files with `FileAccess`, so debug runs only, like the [palette clamp](palette_clamp.md).

## Public API

| Member | Use |
|---|---|
| `InterfacePalette.apply(path) -> int` | Reset, then apply a palette file; returns how many names matched |
| `InterfacePalette.reset()` | Back to the default colours and theme |
| `InterfacePalette.is_interface_palette(path) -> bool` | A `.gpl` file with at least one colour named after a `Colours` variable; only these are listed in the debug panel |
| `InterfacePalette.variable_name(colour_name) -> String` | `'hp bar fill'` -> `'HP_BAR_FILL'` |
| `PaletteLoader.load_named_colours(path) -> Dictionary` | Name -> colour for a `.gpl` file |
| `DebugPanels.set_interface_palette(path)`, `interface_palette` | Apply from the debug panel; `''` resets. The `'` and `;` keys step through the palettes, and [palette combos](debug_panel.md#behaviour) save one with a world palette |

Tests: `tests/debug/test_interface_palette.gd`.
