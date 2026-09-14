# Debug panel

A dev-only panel for comparing looks in game: the full-screen and world palette clamps and which corridor
renderer and enemy images fights use. It is on every screen, including the corridor testbed and combat sandbox.

**Location:** `src/debug/debug_panels.tscn` + `debug_panels.gd`, class `DebugPanelsAutoload`, registered
as the `DebugPanels` autoload.

## Behaviour

- F1 toggles the panel, only in debug builds (`OS.is_debug_build()`). The autoload processes while the
  game is paused.
- Choices last for the session only. `DebugPanels.reset_settings()` restores the defaults;
  `TestCleanup.reset_all_managers()` calls it.
- The palette folder is scanned the first time the panel opens, so headless tests and autotest runs do no
  extra work.
- Built as a `.tscn`, styled by the project theme, with a `UIJuice` node on each control.
- English only. `tools/extract_pot.gd` skips `src/debug/`, so panel labels stay out of the translation
  files.

## Controls

| Control | Effect | Read by |
|---|---|---|
| Palette | "Off", then every palette under `assets/palettes/`, grouped by subfolder. Applies immediately. | [Palette clamp](palette_clamp.md) |
| World palette (corridor) | "Off", then every palette. Applies immediately. | [World clamp](palette_clamp.md#world-clamp) on `CombatCorridor` |
| Colour matching | RGB or perceptual (OKLab), for both clamps. Applies immediately. | Palette clamp |
| Dithering | On or off, for both clamps. Applies immediately. | Palette clamp |
| Corridor | Scaled, perspective or 3D (`corridor_kind`). Applies from the next fight. | `CombatCorridor` via `DebugPanels.corridor_scene()` |
| 3D light | Shader or wall lights (`corridor_light`). Applies from the next fight. | `CombatCorridor` sets `Corridor3D.light_mode` |
| Enemy images | Painted samples, painted samples cut out of their black background (default), or the pixel sprite (`enemy_images`). Applies from the next fight. | `CombatCorridor`, the corridor testbed |

## Start-up arguments

Read once at start-up from the user arguments (after `--`), for screenshots and comparisons:

| Argument | Effect |
|---|---|
| `--palette=<res path>`, `--perceptual`, `--dither` | Palette clamp settings ([palette_clamp.md](palette_clamp.md)) |
| `--world-palette=<res path>` | World clamp palette |
| `--corridor=scaled\|perspective\|3d` | Sets `corridor_kind` |
| `--corridor-light=shader\|walls` | Sets `corridor_light` |
| `--corridor-set=property=value` | Sets any export on the fight's corridor renderer, before it is built (`corridor_settings`). Repeatable |
| `--monster-image=<res path>` | Every painted enemy uses this image (`MonsterImages.forced_path`) |

For example, a real fight in 3D under a palette:
`<godot> --path . -- --autostart --autofight --shot --shot-delay 5 --corridor=3d --palette=res://assets/palettes/good/waldgeist-32x.png`

## Public API

| Member | Use |
|---|---|
| `corridor_kind`, `enemy_images` | Current choices (enums `CorridorKind`, `EnemyImages`) |
| `corridor_scene() -> PackedScene` | The renderer scene for `corridor_kind` |
| `set_palette(colours: PackedColorArray)` | Clamp to these colours; empty turns the clamp off |
| `world_palette`, `world_material` | The world clamp palette path (`''` when off) and the material combat corridors use |
| `set_world_palette(path: String)` | Clamp the combat corridor to this palette file; `''` turns it off |
| `toggle_panel()` | Show or hide the panel |
| `reset_settings()` | Back to defaults |
