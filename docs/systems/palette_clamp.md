# Palette clamp

A full-screen shader that replaces each pixel on screen with the nearest colour in a chosen palette, so
art from different sources can be judged as one game. It is a dev tool, switched from the
[debug panel](debug_panel.md); off by default.

**Location:** `src/shaders/palette_clamp.gdshader`, the `ClampLayer` in `src/debug/debug_panels.tscn`,
`src/debug/palette_loader.gd`. Palettes in `assets/palettes/`.

## How it works

- A full-screen `ColorRect` on a `CanvasLayer` in the `DebugPanels` autoload reads the screen with
  `hint_screen_texture`. Its layer is above every game layer (HUD, tooltips, pause menu), so everything
  is clamped. Only the debug panel is above it.
- `DebugPanels.set_palette(colours)` writes the palette into two one-row textures (sRGB colours, and the
  same colours in OKLab as a float texture) plus a colour count. Switching palettes does not recompile
  the shader. An empty array hides the layer.
- The shader handles up to `MAX_COLOURS` colours, which must match between the shader and
  `DebugPanelsAutoload`. The largest bundled palettes fit.
- Because the interface is clamped too, a palette is only usable if the effect colours (attack red,
  block blue, status colours) stay distinct under it.

| Setting | Options |
|---|---|
| Colour matching | Nearest in RGB, or nearest in OKLab (a perceptual colour space) |
| Dithering | Off, or a 4x4 ordered dot pattern choosing between the two nearest colours by how far the pixel lies between them |

The OKLab conversion exists twice, in `PaletteLoader.to_oklab` and in the shader; change both together.

## Palettes

`assets/palettes/` keeps the owner's `good/`, `maybe/` and `na/` subfolders from the design folder. Loose
`.gpl` files sit at the top.

`PaletteLoader.load_palette(path)` reads two formats with `FileAccess` (works in debug runs, not in
exported builds):

| Format | Reading |
|---|---|
| Lospec PNG strip | Square swatches in one row; swatch size = image height; each swatch's centre pixel is its colour |
| GIMP `.gpl` | Lines of `R G B name`; header lines and `#` comments are skipped |

`PaletteLoader.find_palettes(root)` lists palette files grouped by subfolder, for the panel dropdown.

## Screenshots

`DebugPanels` reads user arguments at start-up: `--palette=<res path>`, `--perceptual`, `--dither`, plus
`--corridor=` and `--monster-image=` (see [debug_panel.md](debug_panel.md#start-up-arguments)). For
example, with the corridor testbed's `--shot`:

```
<godot> --path . res://src/scenes/corridor_testbed.tscn -- --shot --palette=res://assets/palettes/good/waldgeist-32x.png
```

Tests: `tests/utils/test_palette_loader.gd`.
