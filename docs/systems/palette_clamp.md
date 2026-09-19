# Palette clamp

A shader step that replaces each pixel of the combat corridor with the nearest colour in a chosen
palette, so art from different sources can be judged as one game. It is a dev tool, switched from the
[debug panel](debug_panel.md); off by default. Interface images are clamped separately, to the
[interface palette](interface_palette.md#images).

**Location:** `src/shaders/palette_clamp.gdshaderinc` (the matching), `corridor_look.gdshader` (which
includes it), `src/debug/palette_loader.gd`. Palettes in `assets/palettes/`.

## How it works

- `DebugPanels.set_world_palette(path)` writes the palette into two one-row textures (sRGB colours, and
  the same colours in OKLab as a float texture) plus a colour count. Switching palettes does not
  recompile the shader. `''` sets the count to 0, which passes colours through.
- The shader handles up to `MAX_COLOURS` colours, which must match between `palette_clamp.gdshaderinc`
  and `DebugPanelsAutoload`. The largest bundled palettes fit. Each pixel is compared with every
  palette colour, so larger palettes cost more per pixel.

| Setting | Options |
|---|---|
| Colour matching | Nearest in RGB, or nearest in OKLab (a perceptual colour space) |
| Dithering | Off, or a dot pattern choosing between the two nearest colours by how far the pixel lies between them |
| Dither pattern (`dither_pattern`) | Bayer 4x4 (default), Bayer 8x8, blue noise (`assets/textures/blue_noise_64.png`, a tileable void-and-cluster texture), or interleaved gradient noise |
| Dither size (`dither_size`) | Screen pixels per pattern cell, multiplied by the look shader's pixelate size |
| Supersample (`dither_supersample`) | Dither at twice the resolution and average each 2x2, the fix Obra Dinn uses against moire; the output mixes palette colours |

Matching is set from the Corridor tab's palette rows and each clamp's dithering switch from the
Dithering section header in its own tab (Corridor for the world clamp, Interface for the interface
clamp; the two switches are separate). The pattern, size and supersample are set from the same
section, per look.

The OKLab conversion exists twice, in `PaletteLoader.to_oklab` and in `palette_clamp.gdshaderinc`; change
both together.

## World clamp

- The world clamp is one step of the [corridor look shader](corridor_look.md), the material of the
  combat corridor's `SubViewportContainer` and of the testbed corridor's image. It reads that image, not
  the screen, so it clamps the corridor walls and enemy images and nothing else (enemy HUDs, VFX,
  interface).
- Every corridor uses the one `DebugPanels.world_material`, so a change in the panel applies to the
  corridor on screen. With no palette set it passes colours through.
- The `new/world` ramps are nearly grey, so OKLab
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

`DebugPanels` reads user arguments at start-up: `--world-palette=<res path>`, `--perceptual`, `--dither`, plus
`--corridor-set=` and `--monster-image=` (see [debug_panel.md](debug_panel.md#start-up-arguments)). For
example, with the corridor testbed's `--shot`:

```
<godot> --path . res://src/scenes/corridor_testbed.tscn -- --shot --world-palette=res://assets/palettes/good/waldgeist-32x.png
```

Tests: `tests/utils/test_palette_loader.gd`.

## Dithering in motion (research)

The dither pattern is fixed to the screen, so when the corridor glides or an enemy approaches, the image
moves under a still pattern, and the light flicker flips dithered pixels even when nothing moves. The
pattern, size and supersample options above are the cheap fixes; they have not been judged in motion
yet. The research behind them, so it does not need repeating:

**Return of the Obra Dinn** (Lucas Pope; [forum post](https://forums.tigsource.com/index.php?topic=40832.msg1363742#msg1363742),
[translation with detail](https://sudonull.com/post/64811-The-effect-of-dithering-in-a-three-dimensional-game)).
The game renders greyscale and converts to 1-bit in a post-process by comparing each pixel with a
tiling pattern: an 8x8 Bayer pattern for smooth gradients on some objects, a 128x128 blue noise pattern
for most geometry.

| Approach | Result |
|---|---|
| Pattern in each object's texture space | Failed: texels change size with distance, so resampling to the screen distorts the dots |
| Warping the pattern each frame to follow the motion | Failed: dots need their neighbours, and warping opened gaps |
| Screen pattern shifted by camera rotation (`offset = screen size * rotation / field of view`) | Kept as the game's "digital" mode: stays 1:1 with screen pixels, follows rotation only |
| Pattern mapped to the inside of a sphere around the camera, turning with it but not moving | Kept as the "analogue" mode: sticks to the scene when the camera turns; moire where texels nearly match pixels |
| That sphere dithering done at 2x resolution, then scaled down | Removes the moire; dots grow towards the screen edges and output is no longer strictly 1-bit |

Pope also raised the resolution from 640x360 to 800x450. None of his fixes handle the camera moving
rather than turning, which he accepted for a slow-moving game. This corridor's camera never turns, so
only the pattern choice and the 2x supersampling carry over.

**Surface-stable fractal dithering** (Rune Skovbo Johansen; [article](https://runevision.com/tech/dither3d/),
[source](https://github.com/runevision/Dither3D), MPL-2.0, Unity built-in pipeline). It handles a moving
and zooming camera. The pattern is fixed to each surface's UVs, stored as a 3D texture of Bayer dot
patterns at several scales, and screen-space derivatives pick the scale so dots keep a constant screen
size, adding or removing dots as the surface gets nearer or further. It is per-material shader code, so
it looks portable to a Godot spatial shader. Blue noise does not fit its self-similar scaling.

Applying it here would move the dither decision out of the look shader and into the wall and enemy
sprite materials. Those would need the colour after lighting, so they would compute the one omni light
themselves (no ambient light makes this simple), or a second viewport would render only the per-surface
threshold for the look shader to read instead of its screen pattern.
