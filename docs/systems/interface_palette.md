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
palette. The other files in that folder are placeholder candidates.

A `.gpl` carries no alpha — the loader forces it to 1 — so a `Colours` variable that is translucent
cannot be set from a palette. `COOLDOWN_FILL` is the only one, and it is left out of the files.

Every palette in that folder lists every settable name, even though leaving one out is legal. A
palette that skips a name shows that colour's default inside its own scheme, which stands out badly
once a mechanic or status is added later. Three tests hold this: each name in `ui-default.gpl`
matches a variable, `ui-default.gpl` names every settable variable, and every other palette in the
folder names the same set as `ui-default.gpl`.

## What it changes

| Part | How |
|---|---|
| `Colours` variables | Set by name. They are static variables so they can be replaced, but keep constant-style names. |
| Colours placed in scenes | Health bars are `NamedColourRect` nodes, which copy their `Colours` variable (`colour_name`) when they enter the tree. Screen backgrounds are `ScreenBackground`, a `NamedColourRect` that also passes the [background wear](background_wear.md) mark colours. |
| Theme font colours | Each is placed by brightness on the `UI_TEXT_*` colours, dark to light, blending between the two nearest. |
| Theme images and flat panel colours | Every pixel of the theme's still-textured panel, button, item-cell and checkbox images is placed by brightness on the `UI_PANEL_*` colours in the same way. A [`WornStyleBox`](panel_wear.md) is recoloured through its wrapped `base`. The recoloured images are new textures; the files on disk are unchanged. |
| `PaletteStyleBox` fills | The theme's flat, palette-following panel styles ([ui_theme.md](ui_theme.md#flat-palette-following-panels)) are a `PaletteStyleBox` (`src/ui/palette_style_box.gd`) naming a `Colours` variable in its `colour_name`. Its `bg_color` is set straight from that variable, not the `UI_PANEL_*` brightness ramp, both when a palette is applied and on reset. |
| Interface images | Item, potion and status icons, keyword chip icons and character portraits are clamped to the portrait palette's colours, which by default are the interface palette's, see [Images](#images). The HP bars and item value pills are not: they are drawn through the [interface look](interface_look.md)'s element material, which is not clamped, so they keep the palette colour they are filled with. |
| Panel wear mark colours | `Colours.UI_PANEL_WEAR` / `UI_PANEL_WEAR_LIGHT`, pushed into `PrintLook.panel_material` (`PrintLook.push_wear_colours()`) alongside the [background wear](background_wear.md) colours. |

The `UI_PANEL_*` and `UI_TEXT_*` defaults are the greys the theme already uses, so a palette that does
not set them leaves the theme unchanged. `InterfacePalette.reset()` restores the defaults, the original
images and the theme colours.

Effect colours (the [mechanic colours](mechanics.md#colours) and the remaining `STATUS_*` and
`ARCANE`) are shared by item value badges, status swatches, projectiles, damage numbers
and the corridor's [hit lights](corridors/corridor_3d.md#hit-lights), so an interface palette changes
all of them. Effects have no palette of their own (owner, 2026-09-15): interface colours keep them
coherent with the interface and stand out against the desaturated corridor.

## Images

Interface images share `InterfaceLook.material` ([interface_look.md](interface_look.md)), whose shader
includes the [palette clamp](palette_clamp.md). `DebugPanels.set_portrait_palette` writes the portrait
palette's distinct colours into that material, so each pixel of those images becomes the nearest palette
colour. The HP bars and value pills use `InterfaceLook.element_material`, which no palette is written
to, so they are left at the colours the interface palette gave them. The portrait palette is its own Interface tab choice: off, the world palette, the interface palette,
or any palette file (default: the interface palette). The clamp follows the Corridor tab's colour matching
(RGB or OKLab) and does not dither. With no colours the colour count is 0 and images are unchanged.

Enemy images in the corridor are part of the corridor and use the [world clamp](palette_clamp.md#world-clamp).

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
- The corridor and the enemy images in it are not changed. Text colours set in scenes as per-instance
  overrides (the value pill's number and outline) are not recoloured by brightness.
- Reads files with `FileAccess`, so debug runs only, like the [palette clamp](palette_clamp.md).

## Public API

| Member | Use |
|---|---|
| `InterfacePalette.apply(path) -> int` | Reset, then apply a palette file; returns how many names matched |
| `InterfacePalette.reset()` | Back to the default colours and theme |
| `InterfacePalette.is_interface_palette(path) -> bool` | A `.gpl` file with at least one colour named after a `Colours` variable; only these are listed in the debug panel |
| `InterfacePalette.variable_name(colour_name) -> String` | `'hp bar fill'` -> `'HP_BAR_FILL'` |
| `PaletteLoader.load_named_colours(path) -> Dictionary` | Name -> colour for a `.gpl` file |
| `DebugPanels.set_interface_palette(path)`, `interface_palette` | Apply from the debug panel; `''` resets. The `'` and `;` keys step through the palettes, and [presets](look_presets.md) save one with the rest of the look |
| `DebugPanels.set_portrait_palette(choice)`, `portrait_palette` | What the interface images are clamped to: `''` for off, `PORTRAIT_SAME_AS_CORRIDOR`, `PORTRAIT_SAME_AS_INTERFACE`, or a palette file path. The `.` and `,` keys step through the choices |

Tests: `tests/debug/test_interface_palette.gd`.
