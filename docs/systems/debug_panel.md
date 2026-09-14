# Debug panel

A dev-only panel for comparing looks in game: the palette clamp and which corridor renderer and enemy
images fights use. It is on every screen, including the corridor testbed and combat sandbox.

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
| Colour matching | RGB or perceptual (OKLab). Applies immediately. | Palette clamp |
| Dithering | On or off. Applies immediately. | Palette clamp |
| Corridor | Scaled, perspective or 3D (`corridor_kind`). Applies from the next fight. | `CombatCorridor` via `DebugPanels.corridor_scene()` |
| Enemy images | Painted samples, painted samples cut out of their black background (default), or the pixel sprite (`enemy_images`). Applies from the next fight. | `CombatCorridor`, the corridor testbed |

## Public API

| Member | Use |
|---|---|
| `corridor_kind`, `enemy_images` | Current choices (enums `CorridorKind`, `EnemyImages`) |
| `corridor_scene() -> PackedScene` | The renderer scene for `corridor_kind` |
| `set_palette(colours: PackedColorArray)` | Clamp to these colours; empty turns the clamp off |
| `toggle_panel()` | Show or hide the panel |
| `reset_settings()` | Back to defaults |
