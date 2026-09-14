# `Corridor3D` — the 3D corridor

A real 3D corridor renderer, usable wherever a 2D renderer is. It is an alternative to
`CorridorScaled` for judging the look in game; see [common.md](common.md) for the shared base.

**Location:** `src/scenes/corridors/corridor_3d.gd` + `.tscn`, piece sources beside it.

## How it fits the base class

- Extends `CorridorRenderer`. It owns a `SubViewport` with its own 3D world (`own_world_3d`, so two
  corridors on screen do not share one scene) holding a `Camera3D`, an `OmniLight3D` at the camera and
  the sections. A `Sprite2D` draws the viewport's image at `view_size`, centred on the node origin.
- `_build` resizes the `SubViewport` to `view_size`, so the base class's resize handling works as for the
  2D renderers.
- Movement (`player_z`, `velocity`, held flags, `input_enabled`) comes from the base class.
- `set_blur` and `sharp_bilinear.gdshader` do nothing for it; `_wall_nodes` returns no nodes. Distant
  walls use mipmapped textures instead (`test_wall.png` imports with mipmaps).
- The camera environment has a black background and no ambient light, so the only light is the one at
  the camera. Light reach, energy and falloff are exports.

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
  [common.md](common.md#host-extras-corridor_testbedgd)).
- In a run: F1 → Corridor → 3D, applied from the next fight.
- Tests: `tests/corridors/test_corridor_renderers.gd`.
