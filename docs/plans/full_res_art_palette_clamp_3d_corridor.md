# Plan: Full-Resolution Art, Palette Clamp and 3D Corridor

> Status: planned, not built. All parts are built on one branch, `full-res-art-3d-corridor`. Plans are
> not catalogued in the index; this graduates to `systems/` docs if it ships.

This plan tests three changes together: painted monster art at full resolution, a full-screen palette
clamp that makes art from different sources look like one game, and a real 3D corridor as an
alternative to the 2D corridors. It departs from the chunky pixel-art direction and the 2D scaled
corridor in [`../design/art_audio.md`](../design/art_audio.md), which that doc treats as open. The
goal is a prototype to judge the look in game, not final content.

## Owner decisions

- One branch for everything.
- Monster images are used at original resolution, not shrunk or cut out. Their black backgrounds are
  expected to merge with the dark corridor.
- Enemies get a random image from a sample folder. No enemy data changes; which image an enemy uses is
  not content yet.
- The 3D corridor is an alternative to the 2D corridor and otherwise behaves the same. The walk stops at
  a fixed spot for an encounter, as now.
- The corridor is modular, extended as the player moves. Code-built flat pieces come first; a bought kit
  is added second, and both must be usable interchangeably.
- The palette clamp covers everything on screen, including the HUD, overlays and menus.
- Enemies use the painted samples by default.
- Debug panels are toggled with F keys and get `UIJuice`, behaving like the rest of the game's UI.
- No asset may use generative AI (see [Asset rules](#asset-rules)).

## Monster art

**Source:** `../dark-corridor-design/monsters/`. About 3,600 painted images, mostly 2000x2000, almost
all with solid black backgrounds. Free for commercial use.

**Sample:** `assets/monsters/`. Nine images copied unchanged, renamed to snake_case. They cover glow
effects, heavy black shadows, and wide, rounded and armoured shapes.

- The project's default texture filter is Nearest. Monster sprites need a mipmapped Linear filter, or
  they look jagged and flicker when drawn smaller than their size.
- If memory becomes a problem, set a Size Limit in the images' import settings. The source files stay
  unchanged.

## Palette clamp

A full-screen shader replaces each pixel on screen with the nearest colour in the selected palette.
Selecting "Off" hides it.

**Location:** a `CanvasLayer` in the `DebugPanels` autoload scene (see [Debug panel](#debug-panel)), so
it covers every screen, the testbed and the combat sandbox.

- The shader runs on a full-screen `ColorRect`, reading the screen with `hint_screen_texture`.
- The palette is passed to the shader as a one-row texture of colours plus a colour count, so switching
  palettes does not recompile the shader. The shader's maximum colour count must cover the largest
  palettes in the source folder, which have 64 colours.
- The clamp layer is above every other layer, including the run screen HUD, tooltips and pause menu,
  so everything on screen is clamped. The debug panel is the only thing above it, so it stays readable
  while palettes are compared.
- Because the interface is clamped too, a palette is only usable if the effect colours (attack red,
  block blue, status colours) stay distinct under it.

Settings exposed in the debug panel, to compare in game:

| Setting | Options |
|---|---|
| Colour matching | Nearest in RGB, or nearest in a perceptual colour space |
| Dithering | Off, or an ordered dot pattern mixing the two nearest colours |

## Palettes

**Location:** `assets/palettes/`, copied from `../dark-corridor-design/palettes/`.

- Keep the owner's `good/`, `maybe/` and `na/` subfolders. The loose `.gpl` files at the top of the
  source folder go in `assets/palettes/` directly.
- Do not copy the duplicate files ending in `(1)`, the `examples/` folder, or `pQMBy4.png`, which is not
  a palette.
- Palette PNGs import as Lossless with no mipmaps, so their colours are not altered.
- `PaletteLoader` reads two formats into a list of colours:
  - Lospec PNG strips: square swatches in one row; the swatch size is the image height, and each
    swatch's centre pixel is its colour.
  - GIMP `.gpl` text files: one `R G B name` line per colour, after a header; lines starting with `#`
    are comments. Read with `FileAccess`, which works in debug runs; exported builds are out of scope.

## Debug panel

**Location:** `src/debug/`. An autoload scene, class `DebugPanelsAutoload`, registered as
`DebugPanels`.

- F1 toggles the panel. It only responds in debug builds (`OS.is_debug_build()`).
- Dev-only, so English text with no `tr()`. `tools/extract_pot.gd` collects every `text` line from
  every `.tscn` under `src/`, so it skips `src/debug/` to keep panel labels out of the translation
  files.
- The palette folder is scanned when the panel first opens, not at startup, so headless tests and
  autotest runs do no extra work.
- Choices last for the session only.
- Built as a `.tscn`, styled by the project theme, with a `UIJuice` node on each interactive control
  ([`../systems/ui_juice.md`](../systems/ui_juice.md)).

| Control | Effect |
|---|---|
| Palette dropdown | "Off", then every palette file under `assets/palettes/`, grouped by subfolder. Applies immediately. |
| Colour matching | RGB or perceptual. Applies immediately. |
| Dithering | On or off. Applies immediately. |
| Corridor renderer | Scaled, perspective or 3D. The combat view is rebuilt for each fight, so this applies from the next fight. |
| Enemy images | A random painted sample (default), or the original pixel sprite. Applies from the next fight. |

## 3D corridor

A 3D corridor renderer, `Corridor3D`, used wherever a 2D renderer can be.

### Fit with the existing corridor code

- `Corridor3D` extends `CorridorRenderer` (`src/scenes/corridors/corridor_renderer.gd`), a `Node2D`.
  It owns a `SubViewport` holding the 3D scene and draws that viewport's image at its `view_size`,
  centred on its origin (the vanishing point, as for the 2D renderers). The `SubViewport` is resized in
  `_build`, which the base class re-runs when the view size changes.
- The `SubViewport` uses its own 3D world (`own_world_3d`), so two corridors on screen do not share one
  scene.
- The base class's movement (`player_z`, `velocity`, `set_forward_held`, `set_back_held`,
  `input_enabled`) drives it, so hosts use it like the 2D renderers.
- `set_blur` and `sharp_bilinear.gdshader` do nothing for it; `_wall_nodes` returns no nodes. Distant
  wall flicker is handled by mipmaps.
- The project uses the Compatibility renderer (`project.godot`). It supports the single moving light
  this needs.

### Movement and pieces

- The corridor is divided into sections of equal length. The camera and its light stay at the origin;
  each frame, sections are placed from `player_z`, and each section's pieces are chosen by its absolute
  index (`floor(player_z)` plus its offset). The base class passes only the fraction to `_layout`, so
  `Corridor3D` also reads `player_z`. Keeping the camera still keeps positions small however long the
  run is.
- Sections are created ahead, beyond the reach of the light, and removed behind.
- A cell in the 2D renderers is one section in the 3D renderer, so depths passed in cells mean the same
  distance down the corridor.

For each section, `Corridor3D` asks a piece source for its pieces. The corridor code does not know
which source is in use.

| Piece source | Pieces | Configured by |
|---|---|---|
| `CodeBuiltPieceSource` | Flat textured rectangles for walls, floor and ceiling, created in code | A resource with the tiling texture for each side and the section size |
| `KitPieceSource` | Imported models from a bought kit | A resource with the model scene for each side and the section size |

- Both extend a `CorridorPieceSource` resource with one method that builds the pieces for a section
  index.
- The OrcPoweredGames kit snaps to a 3m grid, so code-built sections default to 3m.
- Kits that keep their textures in a shared atlas cannot tile across a flat rectangle, so they are only
  used through `KitPieceSource`.
- Pieces that are neither flat nor from a kit (doorways, set pieces) can be scenes; support is added
  when the first one is needed.

### Monsters in the corridor

The combat screen already runs the approach ([`../systems/run_screen.md`](../systems/run_screen.md),
"Enemy-in-corridor occupant"). `CombatCorridor` (`src/scenes/combat/combat_corridor.gd`) adds each
enemy as a 2D sprite on the corridor's centre line and moves it from `APPROACH_DEPTH_START` cells deep
to depth 0 (`Balance`). Its scale is `ENEMY_FULL_SCALE` times the renderer's `axis_scale(depth_cells)`,
and the fight starts on arrival.

- `axis_scale` moves from `CorridorScaled` to `CorridorRenderer`, implemented by every renderer:
  - `CorridorScaled`: unchanged, `depth_ratio` raised to the depth.
  - `CorridorPerspective`: the wall's on-screen distance at that depth divided by its distance at
    depth 0 (`_wall_x`).
  - `Corridor3D`: the camera's distance to the depth-0 point divided by its distance to the point that
    many sections further.
- `CombatCorridor` is typed against `CorridorRenderer` and instances the renderer chosen in the debug
  panel, instead of `corridor_scaled.tscn` fixed in its scene. It currently only hosts `CorridorScaled`.

With painted enemy images:

- Each enemy sprite gets a random image from `assets/monsters/`, scanned at runtime. The pick uses its
  own `RandomNumberGenerator`, never the run RNG, so seeded autotest runs are unchanged.
- Sprites use a mipmapped Linear filter.
- Painted images vary in size, so they are scaled to a target on-screen height (a new `Balance`
  constant) instead of `ENEMY_FULL_SCALE`.
- `enemy_anchor` uses each sprite's own image height, not `ENEMY_SPRITE`'s. The enemy HUDs are pinned
  from it, and VFX aim at the HUDs, so both follow.

### Testbed

The existing corridor testbed (`src/scenes/corridor_testbed.tscn`) is reused:

- `Corridor3D` is added to `CORRIDOR_SCENES` and `MODE_NAMES`, so the M key and Mode button cycle all
  three renderers.
- The N key places a random sample monster at `APPROACH_DEPTH_START` and walks it to depth 0 using the
  renderer's `axis_scale`, to check it grows with the walls and stops at full size.
- The debug panel (F1) is available, as on every screen.

## Asset rules

No asset may use generative AI. Check the "AI Disclosure" row on each itch.io page before buying; only
"No generative AI was used" passes, and a missing row counts as unknown. "AI Assisted" does not pass.
CC-BY assets need an attribution in the game's credits.

Candidate kits (all state "No generative AI was used", checked 2026-09-14):

| Pack | Relevant contents | Licence |
|---|---|---|
| [PSX / Retro Modular Dungeon Kit](https://orcpoweredgames.itch.io/psx-retro-modular-dungeon-kit) (OrcPoweredGames) | First choice for `KitPieceSource`. Modular walls, floors, trim; 1.5m / 3m grid; one texture atlas; FBX. Ceilings not listed. Small download, piece count not given. | Not stated |
| [PSX Dark Fantasy Dungeon Pack](https://amos-makes.itch.io/psx-dungeon-pack) (Amos) | Wall, rounded wall, wall door, floor and ceiling pieces; Godot project. Free showcase demo. | CC-BY 4.0 |
| [PSX / Modern Retro Modular Dungeon Assets](https://046games.itch.io/psx-dungeon) (046Games) | Walls, floors, stairs, ceilings, pillars; 1024px atlases; glTF. Free demo. | Page lists both CC0 and CC-BY 4.0 |
| [PS1 PSX Dungeon Modular Pack](https://crimsongcat.itch.io/ps1-dungeon-pack) (crimsongcat) | Floor, wall and ceiling tiles, arches, doors, stairs, columns. Demo available. | CC-BY 4.0 |

Rejected: [100 Stylized Wall Textures](https://kalponic-studio.itch.io/stylized-wall-textures)
(Kalponic Studio), marked "AI Assisted, Graphics".

## Implementation steps

1. Copy the palettes into `assets/palettes/`, set their import options, and run the Godot import.
2. `PaletteLoader` for PNG strips and `.gpl` files.
3. The `DebugPanels` autoload with the palette clamp layer and the palette, matching and dithering
   controls. Make `extract_pot.gd` skip `src/debug/`.
4. Move `axis_scale` to `CorridorRenderer`; implement it in `CorridorPerspective`; type `CombatCorridor`
   against the base and let it instance a chosen renderer. Add the renderer control to the debug panel.
5. `CorridorPieceSource` and `CodeBuiltPieceSource`, then `Corridor3D` using `test_wall.png`. Add it to
   the testbed.
6. Painted enemy images in `CombatCorridor`: random pick, Linear filter, target height, anchor. Add the
   enemy image control to the debug panel and the N key to the testbed.
7. Buy the kit (after confirming ceilings, piece count and licence), import it, and add
   `KitPieceSource`.

## Tests

New tests go in `tests/corridors/` and `tests/utils/`, following the existing GUT setup:

- `PaletteLoader` reads a PNG strip and a `.gpl` file into the expected colours.
- `axis_scale` returns 1 at depth 0 and decreases with depth for all three renderers.
- `CodeBuiltPieceSource` builds pieces for a section within that section's length.
- `CombatCorridor` hosts each renderer type, and `enemy_anchor` uses the sprite's own image height.
- The random enemy image pick leaves the run RNG untouched.

After the change: the full GUT suite, and the headless autotest with a fixed seed (`--nosave
--notutorial`, see [`../systems/autotest.md`](../systems/autotest.md)), which must still exit 0 with
unchanged results.

## Open questions

- Where the light fades to black, whether its falloff is smooth or banded, and whether it flickers.
- The approach will look different in 3D: the 2D scaled corridor shrinks by a fixed ratio per cell,
  while a 3D camera shrinks things in proportion to distance. `APPROACH_DEPTH_START`, the camera's
  field of view and distance to depth 0, and the target enemy height may need tuning for the 3D
  renderer.
- The OrcPoweredGames kit's licence, which its page does not state.

## Out of scope

- Cutting monsters out of their backgrounds.
- Choosing the final palette, kit or monster images (owner's decisions).
- An image field on `EnemyDef`.
- Palette loading in exported builds.

## Docs to update on ship

- `docs/design/art_audio.md`: rendering and corridor, resolution and asset style, cohesion.
- `docs/systems/corridors/common.md`: the renderer list, `axis_scale` on the base class, the filter model.
- `docs/systems/run_screen.md`: "Enemy-in-corridor occupant" (renderer choice, painted images).
- `docs/systems/localization.md`: `extract_pot.gd` skipping `src/debug/`.
- New `systems/` docs for the 3D corridor, the palette clamp and the debug panel, each catalogued in
  `docs/index.md`.
- `docs/decision_log.md`, if the owner adopts the direction.
