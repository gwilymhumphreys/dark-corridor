# Docs index

Catalog of project documentation. Agents: scan this first to find the relevant
doc before diving into code. Each entry lists the path, what it covers, and
keywords to match against.

## Corridors (first-person renderer)

The game renders a first-person "dark corridor" from 2D pixel-art using a
fixed-perspective (pseudo-3D / 2.5D) approach — no `Camera3D`, no meshes. A thin
host scene (`main.tscn` / `main.gd`) instances one of two interchangeable
renderers and toggles between them at runtime with the **M key** / Mode button.
Both renderers extend a shared `CorridorRenderer` base, so they expose the same
interface and the host wiring is identical for either.

| Doc | Covers | Keywords |
|-----|--------|----------|
| [corridors/common.md](corridors/common.md) | Shared setup & base class: project.godot config, pixel-art pipeline, `CorridorRenderer` base (movement, velocity ramp, blur/filter model), `sharp_bilinear.gdshader`, the host (`main.gd`) that instances/toggles renderers, how to run + screenshot. | base class, CorridorRenderer, view_size, aspect ratio, drop-in, project settings, stretch, nearest, sharp bilinear, aa_strength, blur slider, velocity ramp, input map, host, toggle, run, --shot |
| [corridors/scale-and-place.md](corridors/scale-and-place.md) | **`CorridorScaled`** (default; `CorridorScaledScene.tscn`). Rigid scaled tiles in a geometric series; four rotated sides = full box; per-side textures; `view_size` (any aspect, corners auto-meet) + `depth_ratio`. | scale and place, rigid tiles, geometric series, view_size, aspect ratio, depth_ratio, box, four sides, per-side textures, Underkeep, default |
| [corridors/perspective-quad.md](corridors/perspective-quad.md) | **`CorridorPerspective`** (toggle; `CorridorPerspectiveScene.tscn`). Walls as textured `Polygon2D` trapezoids; per-cell depth quads subdivided into strips to kill affine swim. | perspective quad, Polygon2D, trapezoid, affine, swim, subdivision, proj_x, proj_y, vanishing point, flat texture, toggle |

### Quick "which renderer?" guide
- **Default — `CorridorScaled`**: rigid (no swim), four-side box (walls+floor+ceiling),
  **per-side textures**, easy tile-size experimentation. Build the game on this.
- **Toggle — `CorridorPerspective`**: fully parametric perspective (tune FOV
  freely) with any flat wall texture; side walls only (floor/ceiling = backdrop).

(A third "nested-frames" prototype was removed — `CorridorScaled` does the same
more flexibly via per-side textures.)

### Class / file map
Renderers live in `src/scenes/corridors/`, the host in `src/scenes/`, the shader
in `src/shaders/` (class names stay PascalCase; files are snake_case).
- `corridor_renderer.gd` — base `CorridorRenderer` (shared movement/filter/interface)
- `corridor_scaled.gd` + `corridor_scaled.tscn` — default renderer (`CorridorScaled`)
- `corridor_perspective.gd` + `corridor_perspective.tscn` — toggle renderer (`CorridorPerspective`)
- `main.gd` + `main.tscn` — host/testbed: UI + instances/toggles the renderers
- `corridor_panel.tscn` — drop-in: SubViewportContainer that auto-sizes + clips a renderer
- `src/shaders/sharp_bilinear.gdshader` — antialiased-nearest canvas shader

### Assets
- `assets/sprites/test_wall.png` (52×192) — the only bundled texture: default
  side-wall tile for `CorridorScaled` (all four sides), and a placeholder for
  `CorridorPerspective`'s wall + backdrop (its original Eye of the Beholder art
  was removed).
