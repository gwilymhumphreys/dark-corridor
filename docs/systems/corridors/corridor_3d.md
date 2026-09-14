# `Corridor3D` — the 3D corridor

A real 3D corridor renderer, usable wherever a 2D renderer is. It is an alternative to
`CorridorScaled` for judging the look in game; see [common.md](common.md) for the shared base.

**Location:** `src/scenes/corridors/corridor_3d.gd` + `.tscn`, piece sources beside it.

## How it fits the base class

- Extends `CorridorRenderer`. It owns a `SubViewport` with its own 3D world (`own_world_3d`, so two
  corridors on screen do not share one scene) holding a `Camera3D` and the sections. A `Sprite2D` draws
  the viewport's image at `view_size`, centred on the node origin.
- `_build` resizes the `SubViewport` to `view_size`, so the base class's resize handling works as for the
  2D renderers.
- Movement (`player_z`, `velocity`, held flags, `input_enabled`) comes from the base class.
- `set_blur` and `sharp_bilinear.gdshader` do nothing for it; `_wall_nodes` returns no nodes. Distant
  walls use mipmapped textures instead (`test_wall.png` imports with mipmaps).

## Light

The corridor is lit by one Godot `OmniLight3D`, the `SubViewport/Light` node in `corridor_3d.tscn`, at
the camera (the origin of the 3D scene). The owner chose it over four lights on the walls, floor and
ceiling, which looked almost the same (2026-09-15).

- The environment has no ambient light and a black background, so everything past `light_range` is
  black. Code-built materials are shaded; kit models are lit the same way.
- Godot's omni light drops sharply to zero just before its range, so with a short `light_range` the fade
  to black looks abrupt.
- Raising `light_attenuation` above 1 makes the nearest surface brighter, not darker.
- Sections are built past `light_range`, so the end of the geometry is always in darkness.
- The flicker is 1D simplex noise (`flicker_level(time)`), sampled each frame in `_process`; the light's
  energy is `light_energy` times that level, which stays between `1 - flicker_amount` and 1.
- `_apply_light()` copies the exports to the light node when the corridor is built; call it after
  changing them at runtime.

| Export | Controls |
|---|---|
| `light_range` | The light's `omni_range`: where it reaches black; also how far sections are built |
| `light_energy` | The light's `light_energy` |
| `light_attenuation` | The light's `omni_attenuation` |
| `flicker_amount`, `flicker_speed` | How deep and how fast the flicker is; 0 amount is a steady light |
| `enemy_arrived_brightness` | An enemy image's brightness at depth 0; it darkens further away |
| `light_falloff` | Enemy images only: the shape of their fade; higher values darken sooner |

### Enemy images

Enemy images are 2D sprites drawn over the corridor image, so the lights do not reach them.
`enemy_brightness(depth_cells)` gives the colour multiplier the host sets on them:
`(1 - distance / light_range) ^ light_falloff` times the flicker, scaled so an arrived enemy (depth 0)
is at `enemy_arrived_brightness`. Their black backgrounds only merge
into the corridor when the walls around the sprite are dark, which depends on `light_range`.

## Sections

- The corridor is a row of equal-length sections. One 2D cell equals one section, so depths in cells mean
  the same distance in every renderer.
- The camera and light never move. Each frame `_layout` reads `player_z` and places section `i` with its
  near edge `i - player_z` sections past depth 0. This keeps positions small however long the run is.
- Sections are built from a little behind the camera to the light's reach, and freed once outside that
  range.
- **Depth 0** is `depth_zero_distance()`: the distance at which the corridor's height fills the view.
- `axis_scale(depth)` is `depth_zero_distance / (depth_zero_distance + depth * section_length)`.

## Piece sources

`Corridor3D.piece_source` is a `CorridorPieceSource` resource with one method,
`build_section(index) -> Node3D`. The corridor code does not know which source is in use.

| Source | Pieces | Configured by |
|---|---|---|
| `CodeBuiltPieceSource` (default in the scene) | Four `QuadMesh` rectangles (left, right, ceiling, floor), textured per side, repeated `uv_repeat` times per section | Per-side textures, section size |
| `KitPieceSource` | One model scene per side, instanced per section | Per-side scenes and offset transforms, section size |

- Section space: near edge at z = 0, far edge at z = `-section_length`, centred on X and Y.
- Section size defaults to 3m to match the OrcPoweredGames kit's grid.
- Kits whose textures share an atlas cannot tile across a flat rectangle, so they go through
  `KitPieceSource`. Each kit places its model pivots differently; the per-side offsets correct for that.
- Code-built materials disable back-face culling, so wall winding does not matter, and ignore alpha:
  transparent pixels in a texture draw as their stored colour, which is why `test_wall.png` shows jagged
  dark edges in 3D.
- The scene's code-built source uses `assets/textures/castle_wall_slates.png` (Poly Haven, Rob Tuytel)
  on all four sides. Textures used in 3D need mipmaps enabled in their import settings.

## Testing it

- Corridor testbed: M cycles to 3D, or start with `-- --3d`. N walks a random painted monster in (see
  [common.md](common.md#host-extras-corridor_testbedgd)). `-- --set=light_energy=0.2` (any export) and
  `--shot-delay=SECONDS` help compare lighting in screenshots.
- Light settings: edit the root node's "Light" exports in `corridor_3d.tscn`, save, then run the
  testbed and press M until it shows the 3D corridor. The testbed builds its 3D corridor from that scene.
- In a run: F1 → Corridor → 3D, applied from the next fight. For screenshots of a real fight,
  `--corridor=3d --corridor-set=light_energy=<value>`
  ([debug_panel.md](../debug_panel.md#start-up-arguments)).
- Tests: `tests/corridors/test_corridor_renderers.gd`.
