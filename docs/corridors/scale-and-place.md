# CorridorScaled — scale-and-place box (DEFAULT)

**Files:** `corridor_scaled.gd` (`class_name CorridorScaled`, extends
`CorridorRenderer`) on `corridor_scaled.tscn`. The host's default renderer.
**Textures:** four per-side slots, default `assets/sprites/test_wall.png` (52×192).

Extends the base (movement, blur/filter, interface — see
[common.md](common.md)); implements `_build()`, `_layout()`, `_wall_nodes()`.

## Idea

Each side is a stack of the same sprite, each tile scaled by a constant
`depth_ratio` relative to the one in front. Four such sides — rotated around the
vanishing point — form a full box (walls + floor + ceiling). Tiles are *rigidly*
scaled sprites, so the texture never shears (no swim); the perspective is baked in.

## Geometry from `view_size` + `depth_ratio`

Everything derives from the base `view_size` (W×H) and `depth_ratio` (r, the
cell-to-cell shrink). Per side, define the convergence half-length C (vanishing
point → outer edge along the wall's depth axis) and perpendicular half-length P:

```
left / right:  C = W/2,  P = H/2
top / bottom:  C = H/2,  P = W/2
```

The tile cell for that side is then `cell_w = C·(1−r)`, `cell_h = 2·P`. Tiles
nest inward as a geometric series; the distance to a tile's outer edge is the sum
of all tile widths from it outward:

```
outer(sc) = cell_w·sc·(1 + r + r² + …) = cell_w·sc / (1 − r)
```

so at sc=1 `outer = C` (reaches the edge) and the tile spans `±P` (the
cross-section). Placed (canonical frame: vanishing point at origin, wall in −X):

```
position = (−outer(sc), −cell_h·sc/2)
scale    = (cell_w/tex_w · sc, cell_h/tex_h · sc)   # stretch texture to the cell
```

**Corners meet at ANY aspect**: a tile's outer corner is at
`(−C·sc, −P·sc)`, which lies on the rectangle's corner→centre diagonal for every
sc. So unlike before, no special "square" ratio is needed — `r` is purely
perspective steepness, decoupled from aspect.

## Motion (treadmill)

`frac = fposmod(player_z, 1)` (from the base); tile `slot` uses
`sc = r^(slot − extra_near − frac)`. The first `extra_near` (3) slots are
larger-than-screen and off-screen, so the recycling tile is **fully off-screen** —
opaque, no fade. `z_index = n − slot` (nearer in front).

## Four sides via rotation

`_build` computes only the canonical **left** wall. Four parent `Node2D`s sit at
the vanishing point (= node origin) with rotations `[0, π, π/2, −π/2]` → left /
right / top / bottom; the sprite inherits the rotation (top/bottom show the tile
turned 90°). The node carries no `scale` — size/aspect come from `view_size`.

## Per-side textures (decoupled from geometry)

Each side's texture is stretched to its derived cell, so any per-side art of any
size fits without affecting the box. Set `tex_left/right/top/bottom`. To change
the corridor's size or aspect, change `view_size`; to change perspective
steepness, change `depth_ratio`.

## Depth

`num_tiles` auto-extends in `_build` so the far tile is < `min_tile_px` (2px).
Geometric shrink → only ~15 tiles per side.

## Key parameters (`@export`)

- `view_size` (base) — W×H rectangle / aspect the box fills.
- `depth_ratio` (0.5) — cell-to-cell shrink (perspective steepness).
- `extra_near` (3), `min_tile_px` (2), `num_tiles` (min).
- `tex_left/right/top/bottom` — per-side art.
- `speed`, `ramp_time` (from base); `BlurSlider` (host) → `set_blur`.

## Trade-offs

- ✅ Rigid scaling = zero swim; cheap; **per-side art**; **any aspect** (corners
  always meet); recycles fully off-screen; geometry independent of node `scale`.
- ⚠️ Baked perspective (a scaled tile is pixel-exact only at its native depth).
