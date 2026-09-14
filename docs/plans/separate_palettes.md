# Handoff: separate palettes for the world, effects and interface

A starting point for the next agent. The owner wants the game world, the combat effects and the
interface to each use their own palette. Nothing in this plan is built yet except the candidate
palettes and the tools listed under "What exists".

Read `CLAUDE.md` first and follow it. Then read, in this order:
[`../systems/palette_clamp.md`](../systems/palette_clamp.md),
[`../systems/debug_panel.md`](../systems/debug_panel.md),
[`../systems/run_screen.md`](../systems/run_screen.md) ("Enemies in the corridor"),
[`../systems/vfx_driver.md`](../systems/vfx_driver.md),
[`../systems/corridors/corridor_3d.md`](../systems/corridors/corridor_3d.md) ("Light"), and
`src/data/colours.gd`. [`../design/art_audio.md`](../design/art_audio.md) is the owner's doc: read it
for intent, but do not edit it.

## The owner's direction (2026-09-14)

- **World** (corridor and enemy images): black and white, greyscale or very desaturated, with a
  different tint per environment.
- **Effects** (projectiles, impacts, damage numbers): stand out against the world by hue and
  brightness, without needing strong saturation.
- **Interface**: its own muted palette.
- No fixed colour count. `art_audio.md` still says one shared palette of 32–64 colours; the owner has
  moved on from that and will update his doc himself.

## What exists

**The clamp.** One full-screen pass: the `ClampLayer` CanvasLayer (layer 126) in the `DebugPanels`
autoload holds a `ColorRect` running `src/shaders/palette_clamp.gdshader`, which reads the screen and
snaps every pixel to one palette. It is dev-only and clamps everything drawn below it.
`MAX_COLOURS` (64) is duplicated in the shader and `DebugPanelsAutoload`; the shader loops over every
palette colour for every pixel, so raising the limit costs time per pixel.

**Where the combat screen draws.** All in the root canvas unless a layer is given:

| Content | Node | Palette it would take |
|---|---|---|
| Corridor walls and enemy images | `CombatViewFramed/CorridorPanel` (the `combat_corridor.tscn` `SubViewportContainer`); enemy `Sprite2D`s are children of the renderer inside its `SubViewport` | World |
| Enemy HUDs, potions, item grid, player portrait and health, ally slots | `CombatViewFramed` children `EnemyArea`, `RightPanel`, `BottomBar` | Interface (see open questions for item icons) |
| Projectiles and damage numbers | `CombatViewFramed/VfxWall` (`VfxDriver`, a `Node2D` drawing circles in each delivery's colour and text with the fallback font); drawn after the panels, so above them | Effects |
| Map strip, speed button, gold and stats readouts | `RunScreen/HUD` CanvasLayer (default layer 1) | Interface |
| Draft, choice and event overlays | `Control`s under the run screen, no layer of their own | Interface |
| Item tooltip | `TooltipCluster` CanvasLayer, layer 50 | Interface |
| Pause menu and settings | `PauseMenu` CanvasLayer, layer 100 | Interface |

Game colours are named constants in `src/data/colours.gd`; interface styling is in the theme
`assets/themes/black_white_ui.tres`.

**Candidate palettes** in `assets/palettes/new/` (the F1 panel lists nested folders). All names are
placeholders:

| Folder | Contents |
|---|---|
| `world/` | Six 16-step ramps from black to mid-grey, evenly spaced in screen value, each with a slight tint: ash, iron, moss, crimson, bone, crypt |
| `effects/` | `effects-muted.gpl`: one muted hue per effect family in `colours.gd`, a light and a dark shade each, plus a flash grey. Hues are spread so heal, poison, spores and blind no longer share a colour |
| `ui/` | `ui-muted.gpl`: dark panels, text, rarity bronze, silver and gold, health, block and enemy colours |
| `combined/` | Each world ramp plus the effects and interface colours in one file, for the current single clamp |
| `downloaded/` | Lospec palettes (greyscale, tinted and desaturated), credited in `sources.txt` |

The owner has seen the made palettes' swatches and accepted their current brightness.

**Tools for comparing looks.**
- `DebugPanels` start-up arguments: `--palette=`, `--perceptual`, `--dither`, `--corridor-set=`,
  `--monster-image=` ([`debug_panel.md`](../systems/debug_panel.md#start-up-arguments)).
- A real fight screenshot:
  `<godot> --path . -- --autostart --autofight --nosave --notutorial --shot --shot-delay 5 --monster-image=res://assets/monsters/cut_out/bone_golem.png --palette=<path>`.
  The Godot exe path is in [`../handoff.md`](../handoff.md).
- The clamp sometimes fails to show in a screenshot
  ([known issue](../systems/palette_clamp.md#known-issue)). Check each image; the potion slot keeping
  its original green means the clamp was missing.
- Earlier comparison pages and full-size screenshots are saved locally in `comparisons/` (ignored by
  git). See "Presenting results" below.

## Approaches to evaluate

Each layer can be handled either by clamping it with a shader or by drawing it in palette colours to
begin with. These can be mixed.

1. **World: clamp the corridor viewport.** Put a clamp material on the `CombatCorridor`
   `SubViewportContainer` (a canvas shader reading the container's own texture, not the screen). It
   covers the walls and enemy images and nothing else. The world palette would change per
   environment by swapping the palette textures.
2. **Effects: choose colours at the source.** `VfxDriver` draws flat shapes and text, so the delivery
   colours could come straight from the effects palette (for example by pointing the effect constants
   in `colours.gd` at palette entries). No shader needed while effects stay flat. If sprite or
   particle effects arrive, they would need their own layer and clamp, which must leave transparent
   pixels alone.
3. **Interface: choose colours at the source.** Set the theme and the interface constants in
   `colours.gd` from the interface palette. Clamping the interface with a shader would mean moving it
   into its own viewport, which is a large change.
4. **Keep the single clamp as a comparison mode.** The `combined/` palettes let the owner judge the
   combined look before any of the above is built.

Things to check while building:
- **Colour count.** With no fixed count, the per-pixel loop may get slow. A lookup texture built when
  the palette is chosen would make the cost the same for any palette size; confirm that
  Compatibility supports the texture type used.
- **Light interaction.** `Corridor3D`'s lights make smooth fades, which a world ramp cuts into steps
  (dithering hides them), and the same light darkens the enemy sprites. Check they look right together.
- **Tests and autotest.** The full GUT suite must pass and the seeded autotest (`--seed 1 --nosave
  --notutorial`) must give unchanged results. Palette work is presentation-only, so it should not
  affect the autotest.

## Owner's answers (2026-09-14)

- An environment is an act: one world tint per act. Switching tints between acts is not a priority;
  the current work is trying looks to find a good visual style.
- Enemy images take the world palette.
- Item icons are interface.
- Damage numbers are effects.
- The effects palette is the same in every act.

## Progress

- **Approach 1 is built as a debug setting**: the [world clamp](../systems/palette_clamp.md#world-clamp)
  on the `CombatCorridor` container, choosing any palette file in the debug panel. The owner still has to
  judge the screenshots.
- Seeded autotest unchanged (report and log identical to the previous commit); GUT suite passes.
- The 3D corridor is now lit by one light at the camera; the shader light and the wall lights are gone
  ([corridor_3d.md](../systems/corridors/corridor_3d.md#light)).

## Presenting results

The owner compares looks from screenshots: build each choice as a setting, screenshot every option in
the same real fight, and publish them on one page with factual captions. Set sensible defaults, but
leave the choice to him. Update the affected docs in the same change, and delete this plan once the
work ships as a `systems/` doc.
