# Palette clamp

Shaders that replace each pixel with the nearest colour in a chosen palette, so art from different
sources can be judged as one game. The full-screen clamp covers everything; the world clamp covers only
the combat corridor. Both are dev tools, switched from the [debug panel](debug_panel.md); off by default.

**Location:** `src/shaders/palette_clamp.gdshaderinc` (the matching, shared), `palette_clamp.gdshader`
(full screen), `corridor_look.gdshader` (corridor), the `ClampLayer` in `src/debug/debug_panels.tscn`,
`src/debug/palette_loader.gd`. Palettes in `assets/palettes/`.

## How it works

- A full-screen `ColorRect` on a `CanvasLayer` in the `DebugPanels` autoload reads the screen with
  `hint_screen_texture`. Its layer is above every game layer (HUD, tooltips, pause menu), so everything
  is clamped. Only the debug panel is above it.
- `DebugPanels.set_palette(colours)` writes the palette into two one-row textures (sRGB colours, and the
  same colours in OKLab as a float texture) plus a colour count. Switching palettes does not recompile
  the shader. An empty array hides the layer.
- The shaders handle up to `MAX_COLOURS` colours, which must match between `palette_clamp.gdshaderinc`
  and `DebugPanelsAutoload`. The largest bundled palettes fit. Each pixel is compared with every
  palette colour, so larger palettes cost more per pixel.
- Because the interface is clamped too, a palette is only usable if the effect colours (attack red,
  block blue, status colours) stay distinct under it.

| Setting | Options |
|---|---|
| Colour matching | Nearest in RGB, or nearest in OKLab (a perceptual colour space) |
| Dithering | Off, or a dot pattern choosing between the two nearest colours by how far the pixel lies between them |
| Dither pattern (`dither_pattern`) | Bayer 4x4 (default), Bayer 8x8, blue noise (`assets/textures/blue_noise_64.png`, a tileable void-and-cluster texture), or interleaved gradient noise |
| Dither size (`dither_size`) | Screen pixels per pattern cell, multiplied by the look shader's pixelate size |
| Supersample (`dither_supersample`) | Dither at twice the resolution and average each 2x2, the fix Obra Dinn uses against moire; the output mixes palette colours |

Matching and the dithering switch are set from the F1 panel; the pattern, size and supersample are set
from the look panel's Dithering section and reach the world clamp only (the full-screen clamp keeps the
defaults).

The OKLab conversion exists twice, in `PaletteLoader.to_oklab` and in `palette_clamp.gdshaderinc`; change
both together.

## World clamp

- The world clamp is one step of the [corridor look shader](corridor_look.md), the material of the
  combat corridor's `SubViewportContainer` and of the testbed corridor's image. It reads that image, not
  the screen, so it clamps the corridor walls and enemy images and nothing else (enemy HUDs, VFX,
  interface).
- Every corridor uses the one `DebugPanels.world_material`, so a change in the panel applies to the
  corridor on screen. With no palette set it passes colours through.
- Colour matching and dithering apply to both clamps. The `new/world` ramps are nearly grey, so OKLab
  matching picks almost only by lightness, while RGB matching can map saturated colours to other steps.

## Palettes

`assets/palettes/` keeps the owner's `good/`, `maybe/`, `na/`, `unsorted/` and dated (for example
`2026_09_15/`) subfolders. `shortlist/` collects palettes moved there with the debug panel's `'` key.
`new/` holds candidates for separate world, effects and interface
palettes (see [`../plans/separate_palettes.md`](../plans/separate_palettes.md)).

`PaletteLoader.load_palette(path)` reads two formats with `FileAccess` (works in debug runs, not in
exported builds):

| Format | Reading |
|---|---|
| Lospec PNG strip | Square swatches in one row; swatch size = image height; each swatch's centre pixel is its colour |
| GIMP `.gpl` | Lines of `R G B name`; header lines and `#` comments are skipped |

`PaletteLoader.find_palettes(root)` lists palette files grouped by subfolder at any depth (groups are
named by path, for example `new/world`), for the panel dropdown.

## Screenshots

`DebugPanels` reads user arguments at start-up: `--palette=<res path>`, `--world-palette=<res path>`, `--perceptual`, `--dither`, plus
`--corridor-set=` and `--monster-image=` (see [debug_panel.md](debug_panel.md#start-up-arguments)). For
example, with the corridor testbed's `--shot`:

```
<godot> --path . res://src/scenes/corridor_testbed.tscn -- --shot --palette=res://assets/palettes/good/waldgeist-32x.png
```

Tests: `tests/utils/test_palette_loader.gd`.

## Known issue

In about 1 in 12 screenshot runs the palette loaded without a warning but the screenshot showed no
clamp. It happened only while other Godot processes were running at the same time, and did not
happen in 16 repeated runs on their own. The cause is not known. When screenshotting palettes, check
each image (for example, the potion slot should not keep its original green).
