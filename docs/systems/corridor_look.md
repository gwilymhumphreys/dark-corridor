# Corridor look

A dev-only post-processing shader and panel for trying looks on the corridor walls and enemy images:
colour grading, a colour ramp, halftone, hatching, edge lines, bloom, screen effects, plus the corridor
light and camera Environment. Every shader effect is off by default. Settings last for the session unless saved as
a look file.

**Location:** `src/shaders/corridor_look.gdshader`; the panel in `src/debug/look_panel.*`,
`look_section.*`, `look_row.gd` and the three `look_*_row.tscn` scenes; save, load and reset in
`DebugPanelsAutoload` (`src/debug/debug_panels.gd`). Saved looks in `assets/looks/`.

## The shader

- `DebugPanels.world_material` runs `corridor_look.gdshader`. It is the material of the combat corridor's
  `SubViewportContainer` and of the testbed corridor's `Display` sprite, so it reads the corridor image
  only; the interface, enemy HUDs and VFX are not affected.
- It includes `palette_clamp.gdshaderinc` inside a `dithering` group, so the
  [world palette clamp](palette_clamp.md#world-clamp) is one step of it. The palette and colour matching
  are set from the F1 panel.
- Each effect is a `group_uniforms` block whose first uniform is `<group>_on`. Effects run in the order of
  the groups in the file.
- Distances (line spacing, dot size, bloom radius) are in screen pixels.

| Group | Does |
|---|---|
| Warp | Bulges the image like a curved screen; corners go black |
| Pixelate | Draws the image in larger square pixels; the palette dithering follows the pixel size |
| Colour fringe | Separates red and blue towards the edges |
| Bloom | Adds a blurred glow of pixels brighter than a threshold |
| Grade | Exposure, contrast around a pivot, saturation, gamma, black and white points, tint |
| Colour ramp | Replaces each pixel by brightness with a dark, middle and light colour |
| Edges | Draws lines where brightness changes sharply |
| Halftone | Dots on a plain ground, larger where brighter |
| Hatching | Line layers in three directions by brightness: light lines on dark, or dark lines over the image |
| Vignette | Darkens towards the edges |
| Grain | Animated noise |
| Posterize | Fewer brightness steps per channel |
| Dithering | The world palette clamp, with its dither pattern, dot size and 2x supersample ([palette_clamp.md](palette_clamp.md#how-it-works)) |
| Scanlines | Dark horizontal lines and optional red, green and blue vertical stripes |

## The panel

- F2 toggles it, in debug builds. It is built the first time it opens.
- One section per shader group, built from `Shader.get_shader_uniform_list(true)`: the header switch sets
  `<group>_on`, a float gets a slider using its `hint_range`, an int with `hint_enum` a dropdown, a bool a
  switch, a `source_color` a colour button. Adding a uniform to a group adds its control with no panel
  changes. The Dithering header switch is the shared `dithering` switch (`DebugPanels.set_dithering`), so
  it and the F1 panel stay in step. A section starts expanded
  when its effect is on; clicking the title shows or hides it.
- Defaults come from the shader and include code (`DebugPanels.look_defaults()`), because the rendering
  server does not report them when running headless. `PALETTE_UNIFORMS` (colour count, matching, the
  dithering switch) are left out; the F1 panel and a look file's `palette` section set them.
- Two more sections set the corridor: **Light** (`Corridor3D` exports) and **Environment** (properties of
  the corridor camera's `Environment`, including Godot's glow and fog). Their lists are
  `CORRIDOR_PROPERTIES` and `ENVIRONMENT_PROPERTIES` in `look_panel.gd`. Changes go into
  `DebugPanels.corridor_settings` and `environment_settings` and are applied to every corridor in the
  `Corridor3D.GROUP` group; corridors built later apply them too.
- A group with no settings gets no section. The background wear is in the F3 print panel
  ([print_frame.md](print_frame.md)), which extends this panel.
- Save writes `assets/looks/<name>.cfg`; the dropdown loads one; Reset all returns every effect, the
  corridor, the world palette, matching and dithering to their defaults.

## Look files

A `ConfigFile` with sections `shader` (every look uniform), `corridor` and `environment` (only settings
that were changed), and `palette` (`world_palette`, `perceptual`, `dithering`). Loading starts from the
defaults. The background wear and print frame are saved separately, as print looks from the F3 panel
([print_frame.md](print_frame.md#print-looks)); loading or resetting a look leaves them unchanged.

For a screenshot of a saved look (arguments in [debug_panel.md](debug_panel.md#start-up-arguments)):

```
<godot> --path . res://src/scenes/corridor_testbed.tscn -- --shot --still --monster --shot-delay=3 --look=res://assets/looks/<name>.cfg
```

Tests: `tests/debug/test_corridor_look.gd`.
