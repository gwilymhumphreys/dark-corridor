# Background wear

A dev tool that draws print wear on the screen background, like an old printed record sleeve: faded
areas, specks, rubbed edges, creases and folds. Only the background rectangle behind a screen is drawn,
so text, panels, icons and the corridor are unchanged. The owner's chosen settings are in the default
[look preset](look_presets.md).

**Location:** the effect functions in `src/shaders/print_wear.gdshaderinc`, shared with
[panel wear](panel_wear.md); the uniforms in `src/shaders/background_wear_settings.gdshaderinc`, used by
both `src/shaders/background_wear.gdshader` and the corridor overlay
([print_frame.md](print_frame.md)); `src/ui/screen_background.gd` (class `ScreenBackground`);
`PrintLook.background_material`. Settings are in the Background tab of the
[debug panel](debug_panel.md), `src/debug/background_panel.*` (class `BackgroundPanel`).

## How it works

- Each screen's `Background` node is a `ScreenBackground`, a [`NamedColourRect`](interface_palette.md)
  for `UI_BACKGROUND` that draws through the one shared `PrintLook.background_material`. A change in
  the panel applies to every background at once.
- The same wear can be drawn over the combat corridor with the same settings
  ([print_frame.md](print_frame.md)).
- Folds are drawn only during a run. The run screen's background sets `folds_shown`, and folds show
  while that background is in the tree, including on the settings screen opened from the pause menu.
  The title screen and the menus opened from it have no folds.
- The pattern is fixed to the screen and does not animate.
- Each mark takes one of two solid colours, `Colours.UI_BACKGROUND_WEAR` and
  `UI_BACKGROUND_WEAR_LIGHT`, which an [interface palette](interface_palette.md) can set.
  `ScreenBackground` passes them to the shader when it enters the tree. Light marks cover dark ones.
- Faded areas and fold shading are the only blended effects (the owner chose a smooth blend over
  dithered steps): the background blends towards `UI_BACKGROUND_WEAR`, and the solid marks draw on top.

| Group | Does |
|---|---|
| Background Pattern | Pixel size (1 draws at full resolution, 4 snaps marks to the interface pixel grid) and a seed that rearranges the marks |
| Background Faded Areas | A few large, soft patches where the background lifts towards the dark mark colour, from a second record sleeve. Coverage, amount, patch size, edge softness, upright stretch, and fine grain inside the fade. Meant to stay subtle |
| Background Specks | Small solid dots, one chance per cell. Clumping gathers them into patches with clear areas between; size variation makes most tiny with a few large; colour is dark, light or mixed (the default) |
| Background Edge Wear | Patchy rubbed wear along the screen edges, heavier at the corners; light at the heaviest, dark around it |
| Background Creases | One to four faint bands across the screen at an angle, broken up by noise |
| Background Folds | Straight folds like a sheet folded and opened out: a count top to bottom and a count side to side, a broken raised line along each, rubbed wear beside it that is heavier where folds cross, and each section between folds a little lighter or darker. With follow layout on a fight screen, the last fold in each direction sits past the corridor's right and bottom edges by the corridor's distance from the left and top of the screen, which is the [split point](ui_layout.md#screen-sections), and the others are spaced evenly before it; elsewhere folds are spaced evenly |

Sizes and distances are in pattern pixels, so raising the pixel size also scales every mark and the edge
wear width.

A soft mottled texture, faint elongated flecks and scratches were tried and removed by the owner. Faded
areas differ from that mottling: a few large patches with plain background between them, not a texture
over the whole screen.

## The Background tab

F4 opens the [debug panel](debug_panel.md) on this tab. `BackgroundPanel` extends the
[Corridor tab](corridor_look.md#the-corridor-tab) and builds one section per uniform group of
`background_wear.gdshader`. Every change applies to every screen background at once.

## Presets and screenshots

Background wear is its own part of a [preset](look_presets.md), saved in the `print_background`
section, written and read by `PrintLook.write_background_look`, `read_background_look` and
`reset_background_look`. It can be taken from another preset on its own, without touching the print
part. The mark colours are not saved; they come from `Colours`.

For screenshots, `--background-set=<uniform>=<value>` sets one setting (repeatable), for example
`--background-set=background_folds_on=true`, and `--background-panel` opens the Background tab
([dev_tools.md](dev_tools.md#look-arguments)).

Tests: `tests/debug/test_corridor_look.gd`, `tests/debug/test_print_frame.gd`.
