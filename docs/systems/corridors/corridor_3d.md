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

The only light is a light at the camera, drawn by `src/shaders/corridor_light.gdshader` rather than a
Godot light node, so it can fade, band and flicker the same way in the Compatibility renderer.

- `_set_light_overlay` sets one shared `ShaderMaterial` as the `material_overlay` of every piece in a
  new section. The overlay uses a multiply blend: it scales the colour already drawn by the light level
  (0 to 1), so it works with any piece source. It adds no transparency.
- The pieces show their full colours underneath. Code-built materials are unshaded; kit models are lit
  by the environment's white ambient light. The background is black.
- Light level: `(1 - distance / light_range) ^ light_falloff`, then darkened by the angle between the
  surface and the camera (`angle_shading`), times `light_energy` and the flicker level. With
  `light_bands` above 0 the level is rounded up to that many steps, so the last step ends in a hard edge
  to black at `light_range`.
- Sections are built past `light_range`, so the end of the geometry is always in darkness.
- The flicker is 1D simplex noise (`flicker_level(time)`), sampled each frame in `_process` and sent to
  the shader. The level stays between `1 - flicker_amount` and 1.
- `_apply_light()` sends the exports to the shader; call it after changing them at runtime.

| Export | Controls |
|---|---|
| `light_range` | Distance in metres where the light reaches black; also how far sections are built |
| `light_energy` | Brightness at the camera; 1 shows the textures' own colours |
| `light_falloff` | Shape of the fade; higher values darken sooner |
| `angle_shading` | How much darker surfaces facing away from the camera are |
| `light_bands` | 0 is a smooth fade; above 0, the number of brightness steps |
| `measure_along_corridor` | Measure distance along the corridor, so fades and band edges are square rings instead of curves on the walls |
| `flicker_amount`, `flicker_speed` | How deep and how fast the flicker is; 0 amount is a steady light |
| `enemy_arrived_brightness` | An enemy image's brightness at depth 0; it darkens with the light further away |

Enemy images are 2D sprites drawn over the corridor image, so the shader does not reach them.
`enemy_brightness(depth_cells)` gives the colour multiplier the host sets on them: the same fade, bands
and flicker, scaled so an arrived enemy (depth 0) is at `enemy_arrived_brightness`. Their black
backgrounds only merge into the corridor when the walls around the sprite are dark, which depends on
`light_range` (and, with bands, on where the last band ends).

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
  [common.md](common.md#host-extras-corridor_testbedgd)). `-- --set=light_bands=4` (any export) and
  `--shot-delay=SECONDS` help compare lighting in screenshots.
- In a run: F1 → Corridor → 3D, applied from the next fight.
- Tests: `tests/corridors/test_corridor_renderers.gd`.
