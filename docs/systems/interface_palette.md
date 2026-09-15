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
| Theme images and flat panel colours | Every pixel of the theme's panel, button, item-cell and checkbox images, and the pause panel's fill and border, are placed by brightness on the `UI_PANEL_*` colours in the same way. The recoloured images are new textures; the files on disk are unchanged. |

The `UI_PANEL_*` and `UI_TEXT_*` defaults are the greys the theme already uses, so a palette that does
not set them leaves the theme unchanged. `InterfacePalette.reset()` restores the defaults, the original
images and the theme colours.

Effect colours (`DAMAGE`, `STATUS_*` and so on) are shared by item value badges, status swatches,
projectiles and damage numbers, so an interface palette changes all of them.

## Limits

- Colours are copied when things are built: item and status definitions when their catalog is first
  used, `NamedColourRect` nodes when added. A palette chosen in the F1 panel mid-run reaches only what
  is built afterwards. The `--ui-palette=` start-up argument applies it before anything is built.
- Item icons, enemy images and the corridor are not changed. Text colours set in code as per-instance
  overrides (the value badge text and outline) are not changed.
- Reads files with `FileAccess`, so debug runs only, like the [palette clamp](palette_clamp.md).

## Public API

| Member | Use |
|---|---|
| `InterfacePalette.apply(path) -> int` | Reset, then apply a palette file; returns how many names matched |
| `InterfacePalette.reset()` | Back to the default colours and theme |
| `InterfacePalette.variable_name(colour_name) -> String` | `'hp bar fill'` -> `'HP_BAR_FILL'` |
| `PaletteLoader.load_named_colours(path) -> Dictionary` | Name -> colour for a `.gpl` file |
| `DebugPanels.set_interface_palette(path)`, `interface_palette` | Apply from the debug panel; `''` resets |

Tests: `tests/debug/test_interface_palette.gd`.
