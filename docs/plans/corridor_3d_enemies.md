# Plan: 3D corridor only, with enemies in the 3D scene

A handoff plan. It removes the two 2D corridor renderers, makes `Corridor3D` the only corridor, and draws
enemy images as `Sprite3D` nodes inside the 3D scene, lit by the corridor's light.

Read `CLAUDE.md` first and follow it. Then read
[`../systems/corridors/corridor_3d.md`](../systems/corridors/corridor_3d.md),
[`../systems/corridors/common.md`](../systems/corridors/common.md),
[`../systems/run_screen.md`](../systems/run_screen.md) ("Enemy-in-corridor occupant"),
[`../systems/debug_panel.md`](../systems/debug_panel.md) and
[`../systems/palette_clamp.md`](../systems/palette_clamp.md) ("World clamp").

## The owner's decisions (2026-09-15)

- Remove the 2D corridors (`CorridorScaled`, `CorridorPerspective`). `Corridor3D` is the only corridor.
- Enemy images become `Sprite3D` nodes in the corridor's 3D scene, using alpha scissor for transparency
  (no alpha blending).
- Keep only the cut-out enemy images. Remove the painted-with-black-background and pixel sprite
  options.
- Merge the `CorridorRenderer` base class into `Corridor3D`.
- Delete `corridor_panel.tscn` and the `corridor_panel_example` scene.
- Record the change in the decision log and update `docs/design/art_audio.md` as well as the system docs.

## Current state

The branch is `full-res-art-3d-corridor`, last commit `2d4e42f` (one light at the camera). GUT: 388
tests pass. The uncommitted changes to `src/ui/ui_juice.gd`, `docs/systems/ui_juice.md`,
`docs/systems/ui_theme.md` and the UI juice row in `docs/index.md` are from other work; do not commit
them with this plan's changes.

Before changing code, save a seeded autotest report from this commit to compare against (command under
"Before finishing").

## Task 1: remove the 2D corridors and merge the base class

After this task enemies are still 2D sprites, scaled with `Corridor3D.axis_scale`, so the game keeps
working and the tests can pass before Task 2.

**Delete** (with their `.uid` files): `corridor_scaled.gd/.tscn`, `corridor_perspective.gd/.tscn`,
`corridor_renderer.gd`, `corridor_panel.tscn` (all in `src/scenes/corridors/`),
`src/scenes/corridor_panel_example.gd/.tscn` and `src/shaders/sharp_bilinear.gdshader`. Check whether
`assets/sprites/test_wall.png` is still used (`CodeBuiltPieceSource` defaults to it) before touching it.

**`Corridor3D`** extends `Node2D` directly and takes from the base class:
- `auto_view_size`, `view_size`, `_sync_view_size`, the resize handling and `rebuild()`.
- Movement: `speed`, `ramp_time`, `input_enabled`, `player_z`, `velocity`, `forward_held`, `back_held`,
  `set_forward_held`, `set_back_held`, and the velocity ramp in `_process`.
- Its own `_ready()`, which the base used to provide.

Drop everything that only served the 2D renderers: `blur_amount`, `aa_strength`, `_mat`,
`_filter_linear`, `_apply_filter`, `_wall_nodes`, `set_blur`.

**`DebugPanels`:** remove `CorridorKind`, `CORRIDOR_SCENES`, `corridor_kind`, `corridor_scene()`,
`--corridor=`, and the "Corridor" row in `debug_panels.tscn`. Remove `EnemyImages`, `enemy_images` and
the "Enemy images" row. Keep `corridor_settings` and `--corridor-set=`.

**`CombatCorridor`:** instance `corridor_3d.tscn` from a preload. It stays instanced in code, because
`corridor_settings` must be applied before the corridor's `_ready`. Remove the pixel sprite path:
`ENEMY_SPRITE`, `enemy_full_scale`, `_painted`, and `Balance.ENEMY_FULL_SCALE`. Grep for
`thorn-demon.png` before deciding whether the image stays.

**`MonsterImages`:** remove `folder_for_choice()` and make the cut-out folder the default. The
originals folder is still read by `tools/cut_out_monsters.gd`.

**Corridor testbed:** remove the renderer cycling (M key, Mode button, `--perspective`, `--3d`) and the
blur slider. Keep `--set=`, `--monster`, N and the shot arguments.

**Other references:** `tools/extract_pot.gd` `EXCLUDE_FILES` lists `corridor_panel_example`. Run a grep
for every deleted class and file name across `src/`, `tests/`, `tools/` and `docs/`.

**Tests:** `tests/corridors/test_corridor_renderers.gd` (the `SCENES` array and the `axis_scale` test
across renderers), `tests/corridors/test_combat_corridor.gd` (the renderer kind test and the painted and
pixel image tests) and `tests/ui/test_combat_view.gd` (`CorridorScaled.axis_scale`).

Run `godot --headless --import --exit` after deleting files, then GUT.

## Task 2: enemies as `Sprite3D` nodes

**Where they live:** add an `Enemies` `Node3D` under `SubViewport` in `corridor_3d.tscn`. `Corridor3D`
gets a small API that `CombatCorridor` and the testbed's N monster both use, for example
`add_enemy(texture) -> Sprite3D` and a way to place one by depth and horizontal offset. `CombatCorridor`
keeps deciding the count, spread and shrink (`SPREAD`, `_count_shrink`, `_offset_x`).

**Sprite settings:**
- `shaded = true`, so the corridor light lights them and the flicker reaches them.
- `alpha_cut = ALPHA_CUT_DISCARD` with an `alpha_scissor_threshold` export on `Corridor3D`.
- `texture_filter` linear with mipmaps. The cut-out imports already generate mipmaps.
- No billboard: the camera never rotates, so a sprite facing the camera's axis always faces it.

**Placement:** a sprite at depth `d` cells sits at `z = -(depth_zero_distance() + d * section_length)`,
centred on `y = 0` as the 2D sprite is centred on the vanishing point. At depth 0 the corridor's height
(`section_height`) fills the view's height (`view_size.y`), so screen pixels convert to metres at depth 0
as `metres = pixels / view_size.y * section_height`. Use that for:
- `pixel_size`: `Balance.ENEMY_PAINTED_HEIGHT` converted to metres, divided by the texture height, times
  the count shrink.
- The horizontal offset from `_offset_x`.

Perspective then sizes the sprite with depth, so `axis_scale` is no longer needed. Remove it if nothing
else uses it.

**Several enemies:** they share one depth. Where two sprites overlap they would be drawn at the same
distance and flicker, so give each a small distinct depth offset.

**HUD anchor:** `CombatViewFramed` pins each enemy HUD at `CombatCorridor.enemy_anchor(i)`. Compute it
from `Camera3D.unproject_position` of the sprite's top-centre point at its arrived depth, added to the
`CombatCorridor` container's global position. The corridor's image is drawn 1:1 with the container
(`view_size` equals the container size), so no scaling is needed; verify this once in a screenshot.
Projectiles and damage numbers use the HUD positions (`actor_pos`), so they need no change.

**Brightness:** the light now sets enemy brightness. Remove `enemy_brightness`,
`enemy_arrived_brightness`, `light_falloff`, `_light_curve`, `CombatCorridor._apply_brightness` and the
testbed monster's `modulate`.

**Cleanup:** set each `Sprite3D.texture = null` before freeing it (CLAUDE.md "Runtime Cleanup").

**Tests:** a sprite is created under `Enemies` for each enemy, with alpha scissor and shading on; a
sprite at depth 0 projects to `Balance.ENEMY_PAINTED_HEIGHT` pixels tall on screen (unproject its top
and bottom); a deeper sprite is further away; `enemy_anchor` sits above the sprite; enemies at the same
depth have distinct depths.

## Things to check with screenshots

Use the command from [`corridor_3d.md`](../systems/corridors/corridor_3d.md) "Testing it", one Godot
process at a time. Look at every image before describing it.

- **Lighting in the Compatibility renderer:** confirm the sprite is lit by the omni light and darkens
  with depth. If it is not lit, report it before working around it.
- **Alpha scissor edges:** the cut-out images have soft glows (the bone golem's red aura). The scissor
  cuts off the faint outer part and leaves a hard edge. Take shots at two or three threshold values and
  set the default to the one that keeps the most of the image without a dark fringe.
- **Size and HUD position:** at depth 0 the enemy should appear the same size and in the same place as
  before, with its HUD just above it. Compare with a shot from the commit before this plan.
- **The approach:** a shot mid-walk (a shorter `--shot-delay`) to see the enemy dark in the distance.
- **World palette:** with `--world-palette=res://assets/palettes/new/world/world-iron-16.gpl` the
  enemy must be grey like the corridor.
- If a fight with several enemies is reachable, check that they do not overlap badly or flicker.

Publish the shots as a comparison page, following [`separate_palettes.md`](separate_palettes.md)
"Presenting results".

## Docs and records

- **Delete** `docs/systems/corridors/scale_and_place.md` and `perspective_quad.md`. Fold what is still
  true from `common.md` (movement, project configuration, the testbed, running) into `corridor_3d.md`,
  then delete `common.md`. Update the corridors section and rows in `docs/index.md`, and every link to
  the deleted docs.
- **`corridor_3d.md`:** remove "alternative" wording and the base class section; add an "Enemies" section
  for the sprites, alpha scissor, placement and the HUD anchor.
- **`run_screen.md`** (the occupant section and its keywords in `index.md`), **`debug_panel.md`** (the
  removed rows and arguments), **`palette_clamp.md`** (only if its enemy image wording changes), and
  **`handoff.md`**. Grep `docs/` for `occupant`, `axis_scale`, `enemy_brightness`, `CorridorScaled` and
  `painted`.
- **Decision log:** add entry #36 for the corridor as a real 3D scene with enemies as lit `Sprite3D`
  nodes using alpha scissor, and say that it replaces the corridor part of #32 (fractional-scale 2D
  corridor). Do not edit older entries.
- **`docs/design/art_audio.md`:** the owner asked for this to be updated. Update the "Rendering &
  corridor" section to describe the 3D corridor and 3D enemy sprites; leave the rest of the doc alone.
  Its pixel art and palette leanings are the owner's and stay as written unless they describe the
  removed 2D corridor.
- **Build log** entry in `docs/history/build_log.md`.
- Delete this plan once the work is done and described in `corridor_3d.md`.

## Before finishing

- GUT: `<godot> --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit`.
- Seeded autotest must be unchanged apart from wall time: compare `autotest_results/autotest_report.md`
  from `<godot> --headless --path . res://src/autotest/autotest.tscn -- --autotest --seed 1 --speed 5
  --timeout 120 --wall-timeout 30 --nosave --notutorial` against the report saved before starting.
- The Godot exe path is in [`../handoff.md`](../handoff.md).
- Commit only when the owner asks.
