# Corridor look

A dev-only post-processing shader and panel for trying looks on the corridor walls and enemy images:
colour grading, a colour ramp, halftone, hatching, bloom, screen effects, plus the corridor
light and camera Environment. Every shader effect is off by default. Settings are saved in the corridor part
of a [look preset](look_presets.md).

**Location:** `src/shaders/corridor_look.gdshader`, with most effects in `look_effects.gdshaderinc`
(shared with the [interface look](interface_look.md)); the Corridor tab in `src/debug/look_panel.*`,
`look_section.*`, `look_row.gd` and the three `look_*_row.tscn` scenes; writing, reading and reset in
`DebugPanelsAutoload` (`src/debug/debug_panels.gd`).

## The shader

- `DebugPanels.world_material` runs `corridor_look.gdshader`. It is the material of the combat corridor's
  `SubViewportContainer` and of the testbed corridor's `Display` sprite, so it reads the corridor image
  only; the interface, enemy HUDs and VFX are not affected.
- It includes `palette_clamp.gdshaderinc` inside a `dithering` group, so the
  [world palette clamp](palette_clamp.md#world-clamp) is one step of it. The palette and colour matching
  are set from the rows at the top of the Corridor tab.
- Each effect is a `group_uniforms` block whose first uniform is `<group>_on`. Effects run in the order of
  `fragment()`, which is the order of the table below; the panel lists the Dithering section last.
- Distances (line spacing, dot size, bloom radius) are in screen pixels.

| Group | Does |
|---|---|
| Pixelate | Draws the image in larger square pixels; the palette dithering follows the pixel size |
| Bloom | Adds a blurred glow of pixels brighter than a threshold |
| Grade | Exposure, contrast around a pivot, saturation, gamma, black and white points, tint |
| Colour ramp | Replaces each pixel by brightness with a dark, middle and light colour |
| Halftone | Dots on a plain ground, larger where brighter |
| Hatching | Line layers in three directions by brightness: light lines on dark, or dark lines over the image |
| Vignette | Darkens towards the edges |
| Grain | Animated noise |
| Posterize | Fewer brightness steps per channel |
| Dithering | The world palette clamp, with its dither pattern, dot size and 2x supersample ([palette_clamp.md](palette_clamp.md#how-it-works)) |
| Scanlines | Dark horizontal lines and optional red, green and blue vertical stripes |

## The Corridor tab

- F1 opens the [debug panel](debug_panel.md) on this tab. Its controls are built the first time it shows.
- One section per shader group, built from `Shader.get_shader_uniform_list(true)`: the header switch sets
  `<group>_on`, a float gets a slider using its `hint_range`, an int with `hint_enum` a dropdown, a bool a
  switch, a `source_color` a colour button. Adding a uniform to a group adds its control with no panel
  changes. The Dithering header switch is the world clamp's `dithering` switch (`DebugPanels.set_dithering`),
  which Backspace also sets. Every section starts closed, whether or not its effect is on; clicking the
  title shows or hides it.
- Defaults come from the shader and include code (`DebugPanels.look_defaults()`), because the rendering
  server does not report them when running headless. `PALETTE_UNIFORMS` (colour count, matching, the
  dithering switch) are left out; `DebugPanels` writes them in the preset's `corridor_palette` section.
- Three more sections set the corridor: **Light** (`Corridor3D` exports), **Environment** (properties of
  the corridor camera's `Environment`: Godot's glow and the tonemap exposure) and **Fog** (the same
  `Environment`'s fog properties, with the `fog_` prefix dropped from the row labels). Their lists are
  `CORRIDOR_PROPERTIES`, `ENVIRONMENT_PROPERTIES` and `FOG_PROPERTIES` in `look_panel.gd`; presets and
  `scene_values()` use `environment_properties()`, which is the last two merged. Changes go into
  `DebugPanels.corridor_settings` and `environment_settings` and are applied to every corridor in the
  `Corridor3D.GROUP` group; corridors built later apply them too.
- A group with no settings gets no section. The Print tab ([print_frame.md](print_frame.md)) and the
  Background tab ([background_wear.md](background_wear.md)) extend this tab.

## In a preset

The corridor part has sections `corridor_shader` (every look uniform), `corridor_light` and
`corridor_environment` (every Light and Environment property). Reading it starts from the look defaults and
the corridor scene's own values, and leaves the palettes and the other parts unchanged.

For a screenshot of a saved preset (arguments in [debug_panel.md](debug_panel.md#start-up-arguments)):

```
<godot> --path . res://src/scenes/corridor_testbed.tscn -- --shot --still --monster --shot-delay=3 --preset=<name> > _temp/shot.txt 2>&1; grep SHOT_SAVED _temp/shot.txt
```

Tests: `tests/debug/test_corridor_look.gd`.
