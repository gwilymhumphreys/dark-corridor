# Handoff: 3D corridor lights

A starting point for the next agent. Remove the 3D corridor's shader light, keep the wall lights, add a
single light at the player's position, and compare the two with screenshots.

Read `CLAUDE.md` first and follow it. Then read
[`../systems/corridors/corridor_3d.md`](../systems/corridors/corridor_3d.md) ("Light" and "Wall lights"),
[`../systems/debug_panel.md`](../systems/debug_panel.md),
[`../systems/palette_clamp.md`](../systems/palette_clamp.md) ("World clamp") and
[`separate_palettes.md`](separate_palettes.md).

## The owner's decisions (2026-09-14)

- The wall lights at `light_energy = 0.1` look better than the shader light, with or without dithering.
- Remove the shader light (`corridor_light.gdshader` as a material overlay).
- Keep the shader light's formula for darkening enemy images (`Corridor3D.enemy_brightness` and
  `_light_curve`).
- "Leave as a toggle" was read as: dithering stays a toggle. Confirm with the owner if in doubt.
- Next to try: one light at the centre of the player's position (the camera), compared with the wall
  lights.
- Ignore the "ObjectDB instances leaked at exit" warnings for now (the owner's instruction).

## Current state

Nothing from this session is committed. The branch is `full-res-art-3d-corridor`; `git status` shows the
changes. GUT: 389 tests pass. The seeded autotest report was unchanged before the wall lights were added
and has not been rerun since.

Built this session:
- **World clamp:** `world_clamp.gdshader` on the `CombatCorridor` container, with the matching code shared
  in `palette_clamp.gdshaderinc`. F1 "World palette (corridor)" and `--world-palette=<path>`.
- **Light modes:** `Corridor3D.light_mode` (`SHADER` or `WALL_LIGHTS`), `wall_light_inset`,
  `wall_light_attenuation`. F1 "3D light" and `--corridor-light=shader|walls`.
- **`--corridor-set=property=value`** sets any export on a fight's corridor renderer before it is built
  (`DebugPanels.corridor_settings`, applied in `CombatCorridor._ready`). Repeatable.
- **Comparison page:** https://claude.ai/code/artifact/ed593368-26c2-444d-8f49-7801eeefd4ef, source in
  `comparisons/separate_palettes/` (ignored by git).

## Task 1: remove the shader light

Search for these to find every use: `corridor_light`, `light_bands`, `angle_shading`,
`measure_along_corridor`, `light_falloff`, `_light_material`, `unshaded`, `LightMode.SHADER`,
`_set_light_overlay`, `material_overlay`.

- **`corridor_3d.gd`:** remove `LIGHT_SHADER`, `_light_material`, `_set_light_overlay` and the overlay
  call in `_layout`, and the `SHADER` enum value. Make wall lights the default and set the
  `light_energy` default to 0.1.
- **Exports only the shader used:** `angle_shading` and `measure_along_corridor` can go. `light_falloff`
  and `light_bands` are also read by `enemy_brightness`. Ask the owner whether to keep them for enemy
  images only or drop them.
- **Ambient light:** `_build_wall_lights` duplicates the camera's `Environment` at runtime to turn ambient
  light off. Once there is no shader mode, set `ambient_light_source` to disabled in `corridor_3d.tscn`
  and remove the duplication.
- **`code_built_piece_source.gd`:** remove `unshaded`; materials are always shaded.
- **Delete** `src/shaders/corridor_light.gdshader`.
- **Debug panel:** remove "Shader" from the "3D light" option and `shader` from `--corridor-light`.
- **Tests** in `tests/corridors/test_corridor_renderers.gd`: the overlay test
  (`test_corridor_3d_lights_every_piece_and_builds_past_the_light`) must change; keep its check that
  sections are built past `light_range`.
- **Docs:** `corridor_3d.md` (the "Light" section, export table, "Testing it"), `debug_panel.md`, the
  corridors rows in `docs/index.md` (keywords), the `--set=light_bands=4` example comment in
  `src/scenes/corridor_testbed.gd`, and the "Light interaction" bullet in `separate_palettes.md`.

## Task 2: add a centre light

- Add a `LightMode` value for one `OmniLight3D` at the camera (the origin of the 3D scene). Reuse the
  wall lights' setup: `light_range`, `light_energy`, attenuation and flicker. Consider renaming
  `wall_light_attenuation` to a name that fits both modes.
- The walls are much further from a centre light than from the wall lights (`wall_light_inset`, 0.3m by
  default), so energy 0.1 will be darker. Find the matching brightness with screenshots.
- Add it to the F1 "3D light" option and `--corridor-light=`.
- Test: the mode builds one light at the origin; `CombatCorridor` passes the choice through.

## Task 3: compare with screenshots

Take every shot in the same real fight, one run at a time (the clamp has gone missing in screenshots
while other Godot processes were running). The Godot exe path is in
[`../systems/corridors/common.md`](../systems/corridors/common.md).

```
<godot> --path . -- --autostart --autofight --nosave --notutorial --shot --shot-delay 5 --corridor=3d --monster-image=res://assets/monsters/cut_out/bone_golem.png --corridor-light=walls --corridor-set=light_energy=0.1
```

The screenshot path is printed as `SHOT_SAVED:<path>`; copy each file out before the next run.

- **Reference:** wall lights at energy 0.1, without and with
  `--world-palette=res://assets/palettes/new/world/world-iron-16.gpl`, and with `--dither` added.
- **Centre light:** several energies until one matches the wall lights' brightness, then that energy
  with the iron palette, with and without dithering.
- **Check every image** before captioning it: the potion slot keeping its green is normal (it is outside
  the world clamp), but the corridor must be grey when a world palette is set.
- **Page:** convert to JPG (Python with PIL is installed), copy the layout and styles of
  `comparisons/separate_palettes/index.html` into a new `comparisons/<name>/`, caption each shot with its
  settings and only what you have seen in it, and publish it as an artifact.

## What was learned about the lights

- A Godot light close to a surface is many times brighter than at a metre. With the wall lights 0.3m in,
  the near walls stay at full brightness down to about energy 0.3; energy 0.1 matches the old shader
  light and 0.05 is darker.
- Raising attenuation above 1 makes the nearest surface brighter, not darker.
- Moving the wall lights 1m in barely changed brightness at energy 1.
- The world clamp's 16-step ramps show steps on a smooth fade; dithering hides them. With perceptual
  (OKLab) matching, the dark end of the corridor becomes a solid black shape unless dithered.

## Before finishing

- GUT: `<godot> --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gexit`.
- Seeded autotest must be unchanged: compare `autotest_results/autotest_report.md` from
  `--autotest --seed 1 --speed 5 --timeout 120 --wall-timeout 30 --nosave --notutorial` (scene
  `res://src/autotest/autotest.tscn`) against a run on the previous commit.
- Update the docs in the same change and add a build log entry.
- Commit only when the owner asks. Delete this plan once the lights are settled and described in
  `corridor_3d.md`.
