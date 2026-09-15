# Background wear

A dev tool that draws print wear on the screen background, like an old printed record sleeve: specks,
short scratches, rubbed edges and creases. Only the background rectangle behind a screen is drawn, so
text, panels, icons and the corridor are unchanged. Every effect is off by default.

**Location:** `src/shaders/background_wear.gdshader`, `src/ui/screen_background.gd` (class
`ScreenBackground`), `DebugPanels.background_material`. Settings are in the F2 look panel.

## How it works

- Each screen's `Background` node is a `ScreenBackground`, a [`NamedColourRect`](interface_palette.md)
  for `UI_BACKGROUND` that draws through the one shared `DebugPanels.background_material`. A change in
  the look panel applies to every background at once.
- The pattern is fixed to the screen and does not animate.
- Each mark takes one of two solid colours, `Colours.UI_BACKGROUND_WEAR` and
  `UI_BACKGROUND_WEAR_LIGHT`, which an [interface palette](interface_palette.md) can set.
  `ScreenBackground` passes them to the shader when it enters the tree. Nothing is blended.

| Group | Does |
|---|---|
| Background Pattern | Pixel size (1 draws at full resolution, 4 snaps marks to the interface pixel grid) and a seed that rearranges the marks |
| Background Specks | Small solid dots, one chance per cell; density, cell size, speck size, dark or light colour |
| Background Scratches | Short broken lines at an angle with a random spread; density, cell size, length, width, colour |
| Background Edge Wear | Patchy rubbed wear along the screen edges, heavier at the corners; light at the heaviest, dark around it |
| Background Creases | One to four faint bands across the screen at an angle, broken up by noise |

Sizes and distances are in pattern pixels, so raising the pixel size also scales every mark and the edge
wear width.

## Look files and screenshots

Background wear is saved in a look file's `background` section and reset with the rest of the look
([corridor_look.md](corridor_look.md#look-files)). The mark colours are not saved; they come from
`Colours`.

For screenshots, `--background-set=<uniform>=<value>` sets one setting (repeatable), for example
`--background-set=background_specks_on=true` ([debug_panel.md](debug_panel.md#start-up-arguments)).

Tests: `tests/debug/test_corridor_look.gd`.
