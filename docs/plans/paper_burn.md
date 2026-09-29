# Plan: a paper burn effect for tokens

**Status: built 2026-09-30.** As-built detail is in [`../systems/paper_burn.md`](../systems/paper_burn.md). Differences from the plan are listed at the end.

A reusable effect that burns a Control away like paper or card catching fire: a ragged hole spreads
from a point on the edge, with a glowing ember line at the edge of the hole, a black charred band behind
it and a brown scorch ahead of it, sparks and ash rising from it, and nothing left at the end. The
first use is the map: when a fight is won, the token on its square burns away.

"Paper burn" is a visual effect only. It has nothing to do with the Burn mechanic, and the code and
settings use the `paper_burn` name so the two are never confused.

## Research

Burning paper shaders all build on the same parts (sources in the systems doc when built):

- **A dissolve threshold.** Each pixel has a value; the pixel is gone once the burn's progress passes
  its value. Noise alone gives scattered holes, so the good versions use the **distance from an
  ignition point**, pushed in and out by noise, which gives one hole with a ragged edge spreading
  outwards (Kyle Halladay's burning paper shader, Game Dev Bill's paper burn shader).
- **Bands along the edge**, in order from the hole: a bright ember line, a black charred band, then a
  brown scorch fading into the untouched paper. Real paper browns before it blackens, and blackens
  before the ember reaches it.
- **Emission** on the ember band so a bloom pass makes it glow.
- **Animated noise** on the ember band so it flickers, and small glowing specks left in the char.
- **Particles**: sparks and ash from the burning edge. Emitting from the edge is the expensive part in
  3D; here it is cheap because the edge is known on the CPU (a circle around the ignition point).
- Paper curl, flames and smoke are left out: a cardboard token does not curl, and smoke barely shows
  on the dark sheet.

## Fitting the look

- Colours come from the [interface palette](../systems/interface_palette.md): three new names,
  `paper burn ember`, `paper burn char` and `paper burn scorch`, in every palette file.
- The scorch is drawn with ordered dithering, like the dithered pictures, rather than as a smooth
  airbrushed gradient. A switch turns it back to a smooth gradient.
- The ember line is brighter than white while the effect runs, so the existing screen glow
  ([interface_glow.md](../systems/interface_glow.md)) blooms it. The glow is only on while something
  glows, so it costs nothing afterwards.
- Sparks and ash are small square particles, matching the square pixels of the dithering.
- All sizes are in pixels, so the ember line is the same thickness on a small map token and a large
  item token.

## How it works

`PaperBurn` (`src/ui/paper_burn.gd` + `.tscn`) is a Control added as the last child of the target.

- **The hole.** Godot's `clip_children` clips every child of a node to what the node itself draws.
  `PaperBurn` sets the target's `clip_children` to `CLIP_CHILDREN_ONLY`, gives the target the mask
  material, and draws one rectangle on the target through its `draw` signal. The mask shader outputs
  the alpha of the part not yet burnt. Everything under the target is clipped to it, including the
  worn panel and its drop shadow, which panel wear draws in child canvas items, the icon and the value
  pills. The rectangle is grown by a margin so the shadow and pills outside the target's rectangle are
  inside the mask; outside the rectangle the mask takes the value at the nearest point on its edge, so
  the shadow burns with the edge that casts it.
- **The colours.** `PaperBurn` itself covers the target's rectangle and draws the ember, char and
  scorch through the same shader with `mask_pass` off. Being a child, it is clipped by the mask too,
  so nothing is drawn in the hole. It follows the target's offset transform, so it stays on a tilted
  token.
- **One function.** Both passes call one function in `paper_burn.gdshaderinc` with the same
  uniforms, so the colours line up with the hole exactly.
- **Particles.** `Sparks` and `Ash` (`CPUParticles2D` in the scene) are `top_level`, so the mask
  does not clip them. Each frame their emission points are set to points on the burn front (the
  circle around the ignition point at the current distance, inside the rectangle).
- **The end.** When the burn finishes, the target's `clip_children`, material and draw connection
  are restored and its `modulate` alpha is set to 0, so it keeps its place in a container but shows
  nothing. The particles are moved to the target's parent and free themselves once the last one has
  died; then `PaperBurn` frees itself. `finished` is emitted.
- **The limit.** In the mask pass the target's own drawing becomes part of the mask and is not
  shown; only its children are. Worn panels draw as children, so tokens, status icons and panels
  work. A control that draws text itself, such as a Button's label, loses it for the length of the
  burn.

API: `PaperBurn.burn(target: Control) -> PaperBurn` starts one with the current settings. `hold(progress)`
stops it at a fixed progress, for the preview scene. `finish()` jumps to the end.

## Settings

Print settings (`PrintLook.PRINT_SETTING_DEFAULTS`), on a new **Paper burn** section of the F7 tab,
saved with presets and read when a burn starts:

| Setting | What it sets |
|---|---|
| `paper_burn_duration` | Seconds from the first mark to nothing left |
| `paper_burn_raggedness` | How far, in pixels, the noise pushes the edge in and out |
| `paper_burn_detail` | The size in pixels of the edge's bumps |
| `paper_burn_ember_width`, `paper_burn_char_width`, `paper_burn_scorch_width` | The bands, in pixels |
| `paper_burn_brightness` | How far above white the ember line goes |
| `paper_burn_dither` | Dithered scorch, or a smooth gradient |
| `paper_burn_particles` | Sparks and ash on or off |

The map gets `map_cleared_look` (a dropdown on the F7 Map section): *Face down* (the current look) or
*Burnt away* (the default). With *Burnt away*, a cleared square's token is hidden and the square is
left empty.

## The map

- `MapStrip.burn_square(index)` starts a burn on that token and remembers it, so `_update` leaves a
  burning token alone until it has finished. With *Face down* it does nothing, and the token flips
  when the run advances, as now.
- `_update` hides cleared tokens (modulate alpha 0) with *Burnt away*, and shows them face down with
  *Face down*. A resumed run therefore shows cleared squares already gone, with no burn.
- `RunScreen`: when a fight resolves and the run has not ended (so the fight was won), it calls
  `_map.burn_square(current square)`. A fight is always on a square, never at a choice beat.

## Preview scene

`src/debug/scenes/paper_burn_preview.tscn`: on the sheet background, a strip of map-size tokens held
at 0, 0.2, 0.4, 0.6 and 0.8, one of each at the item token size, and two live burns that repeat. The
settings are re-read on each repeat, so the F7 sliders can be tuned while watching.

## Tests

- `PaperBurn`: a burn sets and then restores the target's `clip_children` and material, hides it at
  the end, emits `finished`, and leaves nothing behind when the target is freed partway.
- `MapStrip`: `burn_square` starts a burn with *Burnt away* and not with *Face down*; cleared tokens
  are hidden or face down to match the setting.
- `test_print_frame.gd`: the Tokens tab's section list gains Paper burn.
- The palette tests cover the three new names once they are in every palette file.

## Docs

New `docs/systems/paper_burn.md` (catalogued), and updates to `run_screen.md` (the map),
`print_frame.md` (the settings), `dev_tools.md` (the scene), `interface_palette.md` if it lists names,
and `debug_panel.md` (the F7 row).

## How the build differs

- There is one pass, not a mask plus an overlay. In the Compatibility renderer a node that clips its
  children draws them itself through its material, like a `CanvasGroup`, so the shader reads the
  children's pixels from the screen texture. The bands are drawn on those pixels, which keeps them on a
  tilted token, and `PaperBurn` is a plain `Node` that draws nothing.
- The scorch multiplies the pixels towards the scorch colour instead of drawing over them.
- A worn panel cannot be the target: its background is drawn in a canvas item behind it, which covers
  its children in clip mode. Burn a plain Control holding the panel.
- `MapStrip.burn_current_square()` replaces `burn_square(index)`, because only the current square is
  ever burnt.
