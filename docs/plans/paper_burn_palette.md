# Plan: the paper burn snapped to the palette

The owner finds the map tile burn out of place because its colours are not snapped to a palette, unlike
the interface pictures and the combat effects. This plan snaps the burn's output to the same palette as
the combat effects.

**Status (2026-10-01):** built as below. The owner chose no glow, so `paper_burn_brightness` is 1 in
the default preset. The system doc is [paper_burn.md](../systems/paper_burn.md#look).

## What the burn draws now

`paper_burn.gdshader` reads the token's pixels, cuts the hole and colours three bands
([paper_burn.md](../systems/paper_burn.md)). Its three colours come from the interface palette
(`PAPER_BURN_EMBER`, `PAPER_BURN_CHAR`, `PAPER_BURN_SCORCH`), but the shader blends between them in
smooth gradients, multiplies the ember line above white so the screen glow blooms it, and multiplies the
token's own pixels towards the scorch colour. None of the result is snapped, so the ember line shows
smooth orange-to-yellow gradients next to dithered pictures.

## Changes

1. **Snap the bands.** `paper_burn.gdshader` includes `palette_clamp.gdshaderinc` and passes the
   colour of the ember line, the char and the scorch through `clamp_to_palette`. The token's untouched
   pixels are left alone, because its pictures are already snapped to their own palette (the corridor
   palette in the default preset) and snapping them again would change them.
2. **Which palette.** The same colours, matching and dithering as the combat effects
   (`InterfaceLook.effects_material`; the interface palette in the default preset). `PaperBurn` copies
   those uniforms onto its own material when a burn starts, as it already reads its print settings at
   the start. `DebugPanels` does not need to know about burns.
3. **The ember glow.** A snapped colour is never brighter than white, so the glow would stop. The
   shader snaps the ember line first and then multiplies it by `paper_burn_brightness`, so the line
   still blooms. With the brightness at 1 there is no glow and every pixel of the line is a palette
   colour. The sparks keep their glow either way.
4. **The hole's edge.** The one-pixel soft edge of the hole becomes solid or empty by the dither
   pattern, as in the combat effects with transparency dithering. The token's own see-through pixels,
   such as its drop shadow, keep their transparency.
5. **The scorch dithering** uses the palette clamp's dither pattern (`dither_threshold`) instead of the
   shader's own 4 by 4 Bayer, so both dot patterns line up. The shader's `bayer2` and `bayer4` go.
6. **A switch.** A new print setting `paper_burn_palette` on the F7 Paper burn section, on in the
   default preset, so the owner can compare.

Unchanged: the sparks and ash particles, which are drawn as particles and not through the shader.

## Screenshots for the owner

From `paper_burn_preview.tscn`: snapping off, snapping on with the current brightness, and snapping on
with the brightness at 1.

## Tests and docs

- `tests/ui/test_paper_burn.gd`: the burn material takes the effects material's colour count, and none
  when `paper_burn_palette` is off.
- `docs/systems/paper_burn.md` (Look and Settings), the "Page turn and paper burn" row of
  `docs/systems/shaders_and_palettes.md`, and a `docs/history/build_log.md` entry.
