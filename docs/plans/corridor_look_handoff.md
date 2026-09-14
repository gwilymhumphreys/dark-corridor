# Handoff: finding the corridor look

A starting point for the next agent. The owner wants a unique, coherent look for the game without
drawing art, using post-processing and palettes. The work so far is dev tooling for trying looks on the
corridor walls and enemy images; nothing is chosen.

Read `CLAUDE.md` first and follow it. Then read
[`../systems/corridor_look.md`](../systems/corridor_look.md),
[`../systems/palette_clamp.md`](../systems/palette_clamp.md),
[`../systems/corridors/corridor_3d.md`](../systems/corridors/corridor_3d.md) and
[`separate_palettes.md`](separate_palettes.md) (the earlier plan for separate world, effects and interface
palettes, which still applies). [`../design/art_audio.md`](../design/art_audio.md) is the owner's doc:
read it for intent, do not edit it.

## The owner's direction (2026-09-15)

- Get the corridor and enemy looking good first, then build the rest of the look around them.
- Full-screen effects are welcome (the owner mentioned CRT, colour, bloom, and the post-processing in
  Slots & Daggers).
- Not sure about rendering the corridor at a lower resolution; keep it as an option only.
- No pixel font by default. The interface needs a suitable smooth font instead of Godot's default,
  later.
- Looks are compared as settings plus screenshots in real fights, published on one page. The owner
  picks; do not rank options.

## What exists

- **The look shader and F2 panel** ([`corridor_look.md`](../systems/corridor_look.md)): grade, colour
  ramp, halftone, hatching, edges, bloom, warp, scanlines, grain, vignette, posterize, pixelate, and the
  world palette clamp with its dithering, plus the corridor light and the camera Environment (Godot fog
  and glow). Looks save to `assets/looks/*.cfg`.
- **Thirteen example looks** in `assets/looks/`, screenshotted on the owner's comparison page:
  https://claude.ai/artifact/DiA9cHCTciHbQNobpeKjsU (private to the owner). The page was built from a
  scratch script, not the repo; rebuild it the same way (real fight shots, 1:1 crops, a no-effects view,
  palette swatches, settings).
- **Dither options** for the palette clamp, added for testing in motion: pattern (Bayer 4x4, Bayer 8x8,
  blue noise, interleaved gradient noise), dot size, and 2x supersampling. The owner liked the
  Demichrome look (`demichrome.cfg`: 4-colour palette, 4-pixel blocks, dithered) and wants to see
  dithering in motion.

Screenshot commands (Godot exe path in [`../handoff.md`](../handoff.md)):

```
# A real fight under a look
<godot> --path . -- --autostart --autofight --nosave --notutorial --shot --shot-delay 5 --monster-image=res://assets/monsters/cut_out/bone_golem.png --look=res://assets/looks/<name>.cfg
# The testbed, still, with the enemy arrived; --look-panel opens the panel in the shot
<godot> --path . res://src/scenes/corridor_testbed.tscn -- --shot --still --monster --shot-delay=3 --look=<path>
```

## Open problem: dithering in motion

The dither pattern is fixed to the screen. When the corridor glides forward or the enemy walks in, the
image moves under a still pattern, and the light flicker makes dithered pixels flip even when nothing
moves. Nobody has seen this in motion yet.

Research so far:

- **Return of the Obra Dinn** (Lucas Pope,
  [forum post](https://forums.tigsource.com/index.php?topic=40832.msg1363742#msg1363742),
  [translation](https://sudonull.com/post/64811-The-effect-of-dithering-in-a-three-dimensional-game)):
  dithering in texture space and warping the pattern each frame both failed. He shifted the screen
  pattern by camera rotation, then mapped it to a sphere around the camera that turns with it, with 2x
  supersampling against moire. Both only fix camera rotation. Our camera never rotates; it only moves
  forward, so his fix does not apply here.
- **Surface-stable fractal dithering** (Rune Skovbo Johansen,
  [article](https://runevision.com/tech/dither3d/), [source](https://github.com/runevision/Dither3D),
  MPL-2.0, Unity built-in pipeline): the pattern is fixed to each surface's UVs and switches between
  pattern sizes by screen-space derivatives, so dots stay the same screen size while the camera moves.
  It is per-material shader code and looks portable to Godot. Here it would mean the dither decision
  moves into the wall and enemy sprite materials (which would then need to compute the one omni light
  themselves), or a second viewport renders only the per-surface threshold for the look shader to read.

## Suggested next steps

1. **Record motion.** There is no video capture yet. Add a testbed argument that saves a numbered frame
   sequence during a glide and an enemy approach (fixed timestep, for example `--frames=N`), then make
   an MP4 or GIF with ffmpeg (installed) for the owner's page. Capture Demichrome with each dither option,
   with the flicker off and on.
2. **Publish a motion comparison** so the owner can judge which cheap option is good enough.
3. **Only if none are**, prototype surface-stable dithering on the code-built walls and one enemy
   sprite, behind a setting, and compare it on the same page.
4. Other directions the owner has not ruled on: Godot glow and fog (the `fog_glow` look), hatching and
   halftone looks, and CRT effects over the whole screen rather than the corridor only (the look shader
   covers the corridor image; a full-screen pass would need its own layer like the palette clamp's).

## Known issues

- Every GUT run ends with "6 resources still in use at exit" (Actor, Item, Ticker and definition
  scripts), probably the Actor and Item link not being broken in combat tests. It predates this work and
  the owner has not said whether to fix it.
- The palette clamp sometimes fails to show in a screenshot when other Godot processes run at the same
  time ([palette_clamp.md](../systems/palette_clamp.md#known-issue)). Take screenshots one at a time.
