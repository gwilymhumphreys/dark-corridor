# `Corridor3D` — the corridor

The first-person corridor behind every fight: a real 3D scene of corridor sections, lit by one light at
the camera, with the enemies drawn as lit sprites inside it.

**Location:** `src/scenes/corridors/corridor_3d.gd` + `.tscn`, piece sources beside it. Hosts:
`CombatCorridor` in fights ([run_screen.md](../run_screen.md#enemies-in-the-corridor)) and the corridor
testbed (`src/scenes/corridor_testbed.tscn`).

## Structure

- A `Node2D` that owns a `SubViewport` with its own 3D world (`own_world_3d`, so two corridors on screen
  do not share one scene). The viewport holds `Camera`, `Light`, `Sections` and `Enemies`. A `Sprite2D`
  (`Display`) draws the viewport's image at `view_size`, centred on the node's origin.
- `auto_view_size` (default on) sets `view_size` to the size of the viewport the corridor is in and
  re-syncs it on resize, so sizing the container sizes the corridor. The parent must sit at the viewport
  origin. Turn it off to set `view_size` yourself.
- Exports set before the corridor enters the tree are used by the first build (the testbed's `--set=`).
  After that, `apply_settings(corridor_values, environment_values)` sets exports and camera `Environment`
  properties and rebuilds; `CombatCorridor` and the testbed call it with the
  [Corridor tab](../corridor_look.md) settings.
- Each corridor duplicates its camera's `Environment` in `_ready`, so changing one does not change the
  others, and joins the `Corridor3D.GROUP` group so the Corridor tab can reach the corridors on screen.
- Both hosts draw the corridor image through `DebugPanels.world_material` (the
  [corridor look shader](../corridor_look.md)).

## Movement

- `set_forward_held` / `set_back_held`, or the `move_forward` / `move_back` actions while `input_enabled`
  is on. `CombatCorridor` turns input off so W/S cannot scroll a fight.
- `velocity` eases toward `speed` over `ramp_time`; `player_z` is the position in sections.
- A host can set `player_z` itself instead of holding a direction. `CombatCorridor.set_walk_distance`
  does this for the fight approach ([run_screen.md](../run_screen.md#enemies-in-the-corridor)), so
  the walk's timing comes from `Balance.APPROACH_DURATION` rather than `speed`.
- The camera and light never move. Each frame `_layout` places section `i` with its near edge
  `i - player_z` sections past depth 0, which keeps positions small however long the run is.

## Light

The corridor is lit by one Godot `OmniLight3D`, the `SubViewport/Light` node, at the camera. The owner
chose it over four lights on the walls, floor and ceiling, which looked almost the same (2026-09-15).

- The environment has no ambient light and a black background, so everything past `light_range` is
  black. Code-built materials, kit models and enemy sprites are all lit by it.
- Godot's omni light drops sharply to zero just before its range, so with a short `light_range` the fade
  to black looks abrupt.
- Raising `light_attenuation` above 1 makes the nearest surface brighter, not darker.
- The light does not flicker (owner, 2026-09-15): `flicker_amount` is 0 by default and in the scene. The
  flicker stays as a Corridor tab setting. It is 1D simplex noise (`flicker_level(time)`), sampled each frame; the light's energy is
  `light_energy` times that level, which stays between `1 - flicker_amount` and 1.
- `_apply_light()` copies the exports to the light node when the corridor is built; call it after
  changing them at runtime.

| Export | Controls |
|---|---|
| `light_range` | The light's `omni_range`: where it reaches black; also how far sections are built |
| `light_energy` | The light's `light_energy` |
| `light_attenuation` | The light's `omni_attenuation` |
| `flicker_amount`, `flicker_speed` | How deep and how fast the flicker is; 0 amount is a steady light |
| `alpha_scissor_threshold` | Enemy sprite pixels below this alpha are not drawn |

## Sections

- The corridor is a row of equal-length sections, built from a little behind the camera to past the
  light's reach and freed once outside that range, so the end of the geometry is always in darkness.
- **Depth 0** is `depth_zero_distance()`: the distance at which the corridor's height fills the view.
  Depths elsewhere (the enemy approach, `Balance.APPROACH_DEPTH_START`) are counted in sections past it.

## Enemies

Enemies are `Sprite3D` nodes under `SubViewport/Enemies`. The host decides how many there are and where
they go; the corridor creates, sizes and places them.

| Method | Use |
|---|---|
| `add_enemy(texture) -> Sprite3D` | A lit sprite with alpha scissor, linear mipmapped filtering |
| `size_enemy(sprite, height_pixels)` | Sets `pixel_size` so the sprite is that tall on screen at depth 0 |
| `enemy_position(depth_cells, offset_pixels) -> Vector3` | The centre of a sprite at that depth, offset sideways by screen pixels measured at depth 0 |
| `pixels_to_metres(pixels)` | A screen distance at depth 0 in metres: `pixels / view_size.y * section_height` |
| `unproject(point) -> Vector2` | Where a 3D point appears, in the node's local coordinates (origin at the view centre) |
| `remove_enemy(sprite)` | Clears the texture and frees the sprite |

- `shaded` is on, so the light darkens a sprite with distance; there is no separate
  brightness formula.
- Transparency is alpha scissor (`ALPHA_CUT_DISCARD`), not blending: a pixel is either drawn opaque or
  not drawn. The cut-out images' soft glows lose their faintest outer part. The default threshold was
  picked from screenshots as the lowest tried value that shows no dark fringe.
- No billboard: the camera never rotates, so a sprite facing the camera's axis always faces it.
- Perspective sizes the sprites with depth, so no scale is set during the approach.
- During the approach an enemy keeps its place in the corridor: the host moves `player_z` forward and
  lowers the depth by the same amount, so the sprite's world position does not change.

## Hit lights

A short `OmniLight3D` at an enemy when a delivery lands on it, in the delivery's colour, fading to
nothing. On by default and subtle (owner, 2026-09-15), with its energy near the camera light's. It is a
look setting, kept until the effects pass decides on hit visuals.

- The colour is the delivery's, which comes from the effect colours in `Colours`, so it follows the
  [interface palette](../interface_palette.md).

- `CombatCorridor.show_hits(deliveries, render_time)` runs each frame from the combat view. Each enemy
  hit less than `hit_light_duration` ago gets one light, from its newest hit, placed
  `hit_light_distance` in front of its sprite. Hits on items and on the player's side are not lit.
- `set_hit_lights(lights)` shows up to `MAX_HIT_LIGHTS`, reusing hidden light nodes under
  `SubViewport/HitLights`. The cap exists because each light costs another draw of every object it
  reaches in the Compatibility renderer.
- Strength is a function of render time since the hit, so slow motion slows the fade. A landed
  delivery is dropped after `Balance.DELIVERY_VISUAL_HOLD`, which ends a longer light early.
- The corridor look shader runs over the lit image, so a world palette snaps a light's colour to the
  palette.

| Export | Controls |
|---|---|
| `hit_lights_on` | Whether hit lights show |
| `hit_light_energy` | Energy at the moment of the hit |
| `hit_light_range` | The light's `omni_range` |
| `hit_light_duration` | Seconds of render time to fade out |
| `hit_light_distance` | Metres in front of the sprite |

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
  transparent pixels in a texture draw as their stored colour, which is why `test_wall.png` (the
  `CodeBuiltPieceSource` default texture) shows jagged dark edges.
- The scene's code-built source uses `assets/textures/castle_wall_slates.png` (Poly Haven, Rob Tuytel)
  on all four sides. Textures used in 3D need mipmaps enabled in their import settings.
- Code-built materials filter linear with mipmaps, matching enemy sprites and the project default.
  A chunky, blocky look comes from the screen-space `pixelate_on` setting in
  [corridor_look.md](../corridor_look.md), not from nearest filtering: the shader's blocks stay the
  same size across the whole view, while nearest filtering would give blocks that shrink with distance.

## Project configuration (`project.godot`)

- Window 2560×1440, `stretch/mode = canvas_items`, `aspect = keep`; the renderer is Compatibility.
- `default_texture_filter = Linear Mipmap` ([ui_theme.md](../ui_theme.md)); the corridor sets its own filters.
- Input map: `move_forward` = W + Up, `move_back` = S + Down.
- `main_scene` is `main.tscn`; the corridor testbed runs directly.

## Testing it

- Corridor testbed: `<godot> --path . res://src/scenes/corridor_testbed.tscn`. Forward/Back buttons
  glide; N places a random cut-out monster at `APPROACH_DEPTH_START` and walks the corridor up to
  it, overriding the buttons until the walk finishes.
- Testbed arguments (after `--`): `--set=property=value` sets any corridor export; `--monster` spawns a
  monster for the shot; `--shot` saves `screenshots/corridor_shot_<date>_<time>.png` mid-glide and quits (`--still` for a stopped
  frame, `--shot-delay=SECONDS` to wait longer), printing `SHOT_SAVED:<path>`. `--view=WIDTHxHEIGHT`
  (before `--`) forces a fixed `view_size`. The debug panel's `--monster-image=` and `--world-palette=` also
  apply.
- A real fight: `<godot> --path . -- --autostart --autofight --shot --shot-delay 5 --nosave --notutorial
  --corridor-set=light_energy=<value>` ([debug_panel.md](../debug_panel.md#start-up-arguments)).
- Light settings: edit the root node's "Light" exports in `corridor_3d.tscn`; fights and the testbed both
  build from that scene.
- Headless reimport after adding or replacing textures: `tools/import.sh`.
- The Godot exe path is in [`../../handoff.md`](../../handoff.md).
- Tests: `tests/corridors/test_corridor_renderers.gd`, `tests/corridors/test_combat_corridor.gd`.
