# Paper burn

A reusable effect that burns a Control away like paper catching fire. A ragged hole spreads from a
point on its edge. The edge of the hole has a glowing ember line, a black char band behind it and a
dithered scorch ahead of it, and sparks and ash rise from it. Nothing is left at the end. The map uses
it to burn away the token on a square once its fight is won. It is a visual effect only and has
nothing to do with the Burn mechanic.

**Location:** `src/ui/paper_burn.gd` + `.tscn` (`PaperBurn`), `src/shaders/paper_burn.gdshader`, the
Paper burn section of the F7 tab (`src/debug/tokens_panel.gd`), and the preview scene
`src/debug/scenes/paper_burn_preview.tscn`.

## How it works

- `PaperBurn.burn(target)` adds a `PaperBurn` node under the target. The node sets the target to clip
  its children (`clip_children = CLIP_CHILDREN_ONLY`), gives it the burn material, and draws a
  rectangle on it through its `draw` signal.
- In clip mode Godot draws the children into a buffer and then draws the target's own drawing over
  them, the way a `CanvasGroup` works. The burn shader reads the children's pixels from the screen
  texture, cuts the hole and colours the bands on those pixels. Everything under the target burns:
  a worn panel and its drop shadow, an icon, value pills and text. The bands take the children's shape,
  so they stay on a tilted token.
- The rectangle is the target grown by `MARGIN`, so the drop shadow and pills outside the target are
  drawn. Outside the target's own rectangle the hole takes its value from the nearest point on the
  edge and no bands are drawn.
- The hole is the distance from the ignition point, pushed in and out by warped noise. The ignition
  point is on the edge, on a side picked by `SIDE_WEIGHTS`.
- The ember line is brighter than white and flickers. The sparks ask `InterfaceGlow` for glow, which
  switches the screen glow on for the length of the burn ([interface_glow.md](interface_glow.md)).
- `Sparks` and `Ash` are `CPUParticles2D` set to `top_level`, so the clip does not cut them. Each frame
  they emit from points on the burn front, which is the circle around the ignition point where it
  crosses the target.
- At the end the target's `clip_children`, material and draw connection are put back, and its
  `modulate` alpha is set to 0, so it keeps its place in a container. The particles move to the
  target's parent and free themselves after their lifetime. If the `PaperBurn` node is freed early,
  it puts the target back and does not hide it.

**What to burn.** The target's own drawing is replaced by the burn rectangle, so burn a Control that
draws nothing itself and holds the visible nodes. An `ItemCell` or a `StatusIcon` qualifies. A panel
does not: a worn panel draws its background in a canvas item behind itself, and in clip mode that
background covers the panel's own children. Put the panel inside a plain Control and burn that. The
preview scene does this for its wide panel.

## Look

Colours come from the [interface palette](interface_palette.md): `PAPER_BURN_EMBER`,
`PAPER_BURN_CHAR` and `PAPER_BURN_SCORCH` in `Colours`, named in every palette file. The scorch
multiplies the pixels under it towards the scorch colour, so a light icon browns while the dark card
stays dark. It is dithered with a 4 by 4 Bayer pattern unless `paper_burn_dither` is off. Sizes are in
pixels, so the ember line is the same thickness on every size of token.

## Settings

Print settings (`PrintLook.PRINT_SETTING_DEFAULTS`), on the F7 tab's Paper burn section and saved in
presets ([print_frame.md](print_frame.md)). They are read when a burn starts.

| Setting | Sets |
|---|---|
| `paper_burn_duration` | Seconds from the first mark to nothing left |
| `paper_burn_raggedness` | How far the noise pushes the edge in and out, in pixels |
| `paper_burn_detail` | The size of the edge's bumps, in pixels |
| `paper_burn_ember_width`, `paper_burn_char_width`, `paper_burn_scorch_width` | The widths of the bands, in pixels |
| `paper_burn_brightness` | How far above white the ember line and sparks go |
| `paper_burn_dither` | Dithered or smooth scorch |
| `paper_burn_particles` | Sparks and ash on or off |

## Uses

- **The map.** When a fight is won, `RunScreen` calls `MapStrip.burn_current_square()`, which burns
  the current square's token when `map_cleared_look` is Burnt away ([run_screen.md](run_screen.md)).

## Preview

`paper_burn_preview.tscn` shows map-size and item-size tokens held at points through a burn, and a map
token, an item token and a wide panel burning over and over. The settings are read again each time
the burns restart, so the F7 sliders can be tuned while it runs ([dev_tools.md](dev_tools.md)).

## Public API

| Member | Use |
|---|---|
| `PaperBurn.burn(target: Control) -> PaperBurn` | Start a burn with the current settings |
| `finished` | Emitted when nothing is left |
| `hide_when_done` | Set false to leave the target shown at the end (the preview repeats burns) |
| `hold(progress)` | Stop at a fixed progress from 0 to 1 |
| `finish()` | Jump to the end |

Tests: `tests/ui/test_paper_burn.gd`, and the burn cases in `tests/ui/test_map_strip.gd` and
`tests/ui/test_run_screen.gd`.

Research the look was built from: [Kyle Halladay's burning paper shader](https://kylehalladay.com/blog/tutorial/2015/11/10/Dissolve-Shader-Redux.html)
(a dissolve spreading from a point, with noise on the distance), [Game Dev Bill's paper burn
shader](https://gamedevbill.com/paper-burn-shader-in-unity/) (the char, grey and ember bands), and the
[2D dissolve with burn edge](https://godotshaders.com/shader/2d-dissolve-with-burn-edge/) and
[burning paper](https://godotshaders.com/shader/burning-paper/) shaders on Godot Shaders.
