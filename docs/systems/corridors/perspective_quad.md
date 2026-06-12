# CorridorPerspective — perspective-quad walls (TOGGLE)

**Files:** `corridor_perspective.gd` (`class_name CorridorPerspective`, extends
`CorridorRenderer`) on `corridor_perspective.tscn`. The host's toggle renderer
(M key). **Texture:** wants a *flat* wall face; **backdrop:** a floor/ceiling
panel behind the walls. The original Eye of the Beholder art was removed, so both
currently placeholder on `assets/sprites/test_wall.png` — swap real art into
`WALL_TEX` / `BACKDROP` in `corridor_perspective.gd`.

Extends the base (movement, blur/filter, interface — see [common.md](common.md));
implements `_build()`, `_layout()`, `_wall_nodes()`.

## Idea

Left/right walls are drawn as true **perspective trapezoids** using `Polygon2D`
quads: each wall cell's 4 corners are placed at their real projected positions
(near edge tall, far edge short) and a flat texture is mapped on. The shape is
exactly perspective (no rotation artifact); only the texture *interior* is
approximate (see affine swim). Floor/ceiling come from the static backdrop.

## Projection

Driven by the base `view_size` (W×H): the near wall sits at the rect edges
(× `overscan`) and recedes 1/d to the centre vanishing point (node origin).

```
wall_x(d)   = −(W/2 · overscan) / d     # left edge; RightWalls mirrors (scale.x = −1)
ceil_y(d)   = −(H/2 · overscan) / d
floor_y(d)  =  (H/2 · overscan) / d
```

`d` is **grid distance in cells** (linear: 1, 2, 3, …); `1/d` is real pinhole
perspective. The right wall is the same layout under a `scale.x = −1` parent
(set in `_build`). The backdrop panel is stretched to fill W×H.

## A cell = a trapezoid spanning two depth planes

Cell `i` spans near plane `d = (i+1) − frac` to far plane `d+1`; corners use
`wall_x`/`ceil_y`/`floor_y` at `d` (near) and `d+1` (far). Adjacent cells share an
edge (cell i's far plane == cell i+1's near plane), so the wall tiles seamlessly
at any distance.

## Affine swim and the strip fix

`Polygon2D` uses **affine** (not perspective-correct) texture mapping → the
texture "swims" on a fat near quad during motion. Fix: subdivide each cell into
**vertical strips along depth**, each strip's boundaries at their true projected
depth, so affine error inside a thin strip is negligible. Strips **taper** with
distance (nearest cell `subdivisions`=12 strips; far tiny cells 1), kept in
`_strips: Array[Vector3i]` of (cell, strip, strips-in-cell). (Exact alternatives
not used: a perspective-correct shader, or real 3D quads.)

## Depth and z-order

`num_segments` auto-computed in `_build` so the far cell is < `min_far_px` (2px).
Cells are *linear* in depth and shrink as `1/d`, so reaching 2px needs many cells
— hence the tapered strips keep the polygon count sane. `z_index = -int(d)`
(clamped ±1900; backdrop at -2000).

## Key parameters (`@export`)

- `view_size` (base) — W×H rectangle / aspect the walls fill.
- `overscan` (1.05) — how far past the edge the near wall sits.
- `subdivisions` (12) — strips for the nearest cell.
- `min_far_px` (2) — depth cutoff.
- `show_backdrop` (false → magenta clear, to inspect wall tiling).
- `speed`, `ramp_time` (from base); `BlurSlider` (host) → `set_blur`.

## Trade-offs

- ✅ Fully parametric perspective (FOV via `view_size`/`overscan`); any flat
  texture; exact shape; seamless tiling; any aspect.
- ⚠️ Affine texture interior (mitigated by subdivision); many polygons to go deep;
  side walls only (floor/ceiling rely on the backdrop). For full walls+floor+
  ceiling and per-side art, use `CorridorScaled`.
