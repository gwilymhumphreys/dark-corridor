# Plan: the interface look on combat effects

The owner wants projectiles and impacts to take the same post-processing as the interface pictures,
dithering in particular, so they stop looking out of place next to them.

**Status (2026-09-30):** built, with every option off by default. The system doc is
[`../systems/interface_look.md`](../systems/interface_look.md#the-combat-effects). The comparison page
is published for the owner to pick from; the options differ from this plan only in that the switches
are uniforms of the `effects` group, set with `--interface-set=`, rather than separate arguments.

Read first: [`../systems/shaders_and_palettes.md`](../systems/shaders_and_palettes.md),
[`../systems/interface_look.md`](../systems/interface_look.md),
[`../systems/palette_clamp.md`](../systems/palette_clamp.md) and
[`../systems/vfx_driver.md`](../systems/vfx_driver.md).

## What exists

- Every effect (projectiles, impacts, damage numbers) is drawn by one `Node2D`, `VfxWall`
  (`VfxDriver`), with `draw_texture_rect`, `draw_circle`, `draw_arc` and `draw_string`, each turned
  and scaled with `draw_set_transform`. It has no material, so no shader runs on it.
- The pictures' dithering is part of the palette clamp: a pixel is dithered between the two nearest
  palette colours. With no palette colours there is nothing to dither between, so the effects must be
  snapped to a palette to be dithered at all.
- Effect colours are the mechanic colours from the interface palette. The pictures are snapped to the
  portrait palette. The default preset sets that to the world palette (`2bit-demichrome`), which has
  none of the mechanic colours, so effects snapped to it would lose their colours.
- Most of an effect's softness is transparency: the comet's glow and tail, the fades at the end of
  every effect, and the antialiased edges of the sprites. The interface look shader keeps transparency
  as it is, so snapping colour alone would leave those soft.

## The change

### A fifth interface look material

`src/shaders/interface_effects_material.tres` (`InterfaceLook.effects_material`), set on `VfxWall`
in `combat_view_framed.tscn`. It takes the same F2 settings through `InterfaceLook.set_setting`, with
these kept off (a new `EFFECTS_OFF_UNIFORMS`):

| Kept off | Why |
|---|---|
| Grade, colour ramp, posterize | They move a pixel off its mechanic colour, as on `element_material` |
| Vignette | It darkens the corners of each drawn rectangle, and a circle or arc has no rectangle |
| Picture wear | Wear marks on moving effects would read as noise |

It is not one of `InterfaceLook.picture_materials`. It gets its own palette choice, the **effects
palette**, set by a new `DebugPanels.set_effects_palette` in the same way as `set_portrait_palette`:
off, the interface palette (default), the portrait palette, or any palette file. The interface
palette holds every mechanic colour, so an effect's solid colour stays as it is and only the colours
in between change: the paler cores, the off-white glints and the blended edges. The Interface tab's
dithering switch and dither settings apply to it as they do to the pictures.

### Patterns laid out on the screen

The interface look lays its halftone, hatching, grain and pixelate patterns out from each drawn
rectangle's corner (from `UV`). Effect sprites are scaled and turned every frame, so a pattern laid
out that way would grow and spin with the sprite, and a circle or arc drawn without a texture has no
usable `UV` at all. The effects shader lays every pattern out on the screen instead.

A new `interface_effects.gdshader` defines `SCREEN_PATTERNS` before including
`interface_look.gdshaderinc`, the same way `interface_portrait.gdshader` defines `PICTURE_ZOOM`.
Under `SCREEN_PATTERNS` the include takes `local` from `FRAGCOORD` and pixelates on the screen grid.
The dithering already uses `FRAGCOORD`, so it is unchanged. No instance uniform is added (the limit
is in [`interface_look.md`](../systems/interface_look.md)).

### Dithering the transparency

A new setting in the dithering group, `dither_transparency`, applies to the effects material only
(written to it alone, like the palette colours to `picture_materials`). When on, each pixel is either
drawn at full strength or not at all, by comparing its transparency with the same threshold the
colour dithering uses (`dither_threshold` in `palette_clamp.gdshaderinc`). A soft glow then becomes
a dot pattern that thins towards its edge, and a fade becomes the dots dropping out.

### Damage numbers

The numbers are drawn on the same node, so they would take the effects material too. A setting
chooses between that and drawing them the way the value pills are drawn (`element_material`, not
snapped). The second option draws the numbers on a child `Node2D` of `VfxWall` with its own material.
`VfxDriver` draws into it from the same loop through the child's `draw` signal, so the numbers still
read the same clock.

### Settings and start-up arguments

An **Effects** section on the Interface tab (F2), saved in the interface part of a preset:

| Setting | Options |
|---|---|
| Effects take the interface look | On, off (off leaves `VfxWall` with no material, as now) |
| Effects palette | Off, the interface palette, the portrait palette, a palette file |
| Dither transparency | On, off |
| Damage numbers | Drawn with the effects, drawn like the value pills |

A start-up argument sets each one, for screenshots: `--effects-look=off|on`,
`--effects-palette=`, `--effects-dither-transparency`, `--damage-numbers=effects|pills`, listed in
[`dev_tools.md`](../systems/dev_tools.md#look-arguments). The defaults stay as now (off) until the
owner picks.

## Comparing the options

Screenshots from the same real fight, at several delays so projectiles, impacts and numbers are all
on screen, plus the frame strips from the `hit_effects_preview` dev scene, for:

1. Effects with no shader (now).
2. Effects with the interface look, colour dithering only.
3. The same, plus transparency dithering.
4. Option 3 with the numbers drawn like the value pills.

Published as one comparison page with factual captions. The owner picks; this plan does not choose a
default. Dithering in motion (the pattern stays still while the effect moves through it) cannot be
judged from stills, so the page says to try it in a fight too.

## Tests

In `tests/debug/test_interface_look.gd`:

- `VfxWall` in `combat_view_framed.tscn` draws through `InterfaceLook.effects_material`.
- `set_setting` writes to the effects material, except `EFFECTS_OFF_UNIFORMS`.
- The effects palette's colours reach the effects material, and the portrait palette's do not.
- `dither_transparency` reaches the effects material only.

The effects draw nothing the combat reads, so the seeded autotest must give the same results.

## Docs to update when built

- `interface_look.md`: the fifth material, `SCREEN_PATTERNS`, the transparency dithering and the
  Effects section.
- `vfx_driver.md`: the material on `VfxWall` and the numbers' child node.
- `shaders_and_palettes.md`: the effects row and the materials table.
- `dev_tools.md`: the four start-up arguments.

## Order of work

1. Add the material and the `SCREEN_PATTERNS` shader, set it on `VfxWall`, with the off list and tests.
2. Add transparency dithering.
3. Split the numbers onto their own child node.
4. Add the Effects section, the preset keys and the start-up arguments.
5. Take the screenshots and publish the comparison page.

Another session is working in `src/vfx/` at the same time. Stage by path, and read
`vfx_driver.gd` again before editing it.
