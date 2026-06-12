class_name CorridorScaled
extends CorridorRenderer
## Four-side box from rigidly-scaled tiles (Underkeep-style, no swim). Each side
## is a stack of the same image scaled by `depth_ratio` per cell; four sides
## rotated around the vanishing point form walls + floor + ceiling.
##
## The whole box is derived from the base `view_size` (the W×H rectangle it fills)
## and `depth_ratio` (perspective steepness) — so the four sides meet at the
## corners for ANY aspect ratio. Each side's tile cell is computed from view_size;
## the per-side texture is stretched to fill it, so any art of any size fits.
##
## See docs/systems/corridors/scale_and_place.md.

@export var depth_ratio: float = 0.5    ## cell-to-cell shrink (perspective steepness); 0..1
@export var num_tiles: int = 9          ## min per side; auto-extended to reach min_tile_px
@export var min_tile_px: float = 2.0    ## keep adding tiles until the far tile is this small on screen
@export var extra_near: int = 3         ## over-sized off-screen tiles so the nearest recycles fully off-screen

@export_group('Per-side textures')
@export var tex_left: Texture2D = preload('res://assets/sprites/test_wall.png')
@export var tex_right: Texture2D = preload('res://assets/sprites/test_wall.png')
@export var tex_top: Texture2D = preload('res://assets/sprites/test_wall.png')
@export var tex_bottom: Texture2D = preload('res://assets/sprites/test_wall.png')

var _sides: Array = []          ## four Array[Sprite2D]: left, right, top, bottom
var _tex: Array = []            ## per-side textures, parallel to _sides
var _cell_w: Array = []         ## per-side tile cell width  (convergence axis, design px)
var _cell_h: Array = []         ## per-side tile cell height (perpendicular axis, design px)


func _build() -> void:
  # Clear any previous tiles so this is safe to call again on resize (rebuild).
  for container in [$LeftWalls, $RightWalls, $TopWalls, $BottomWalls]:
    for c in container.get_children():
      c.queue_free()
  _sides = []
  _tex = []
  _cell_w = []
  _cell_h = []

  var w: float = view_size.x
  var h: float = view_size.y
  var r: float = depth_ratio

  # Per side (left, right, top, bottom): convergence half-length C (vanishing
  # point -> outer edge) and perpendicular half-length P. cell_w = C*(1-r) makes
  # the outer tile reach the edge; cell_h = 2P makes it span the cross-section.
  var conv_half: Array = [w * 0.5, w * 0.5, h * 0.5, h * 0.5]
  var perp_half: Array = [h * 0.5, h * 0.5, w * 0.5, w * 0.5]
  _cell_w = []
  _cell_h = []
  for i in 4:
    _cell_w.append(conv_half[i] * (1.0 - r))
    _cell_h.append(2.0 * perp_half[i])

  # Extend depth until the far tile is < min_tile_px on screen (geometric shrink).
  var big_px: float = maxf(w, h)
  if r > 0.0 and r < 1.0 and big_px > min_tile_px:
    num_tiles = maxi(num_tiles, int(ceil(log(min_tile_px / big_px) / log(r))) + 1)

  # Each parent sits at the vanishing point (node origin), rotated so the
  # canonical 'left wall' layout lands on its edge (top/bottom turned 90°).
  _sides = [[], [], [], []]
  _tex = [tex_left, tex_right, tex_top, tex_bottom]
  var parents: Array = [$LeftWalls, $RightWalls, $TopWalls, $BottomWalls]
  var rots: Array = [0.0, PI, PI / 2.0, -PI / 2.0]
  for i in 4:
    parents[i].position = Vector2.ZERO
    parents[i].rotation = rots[i]
    parents[i].scale = Vector2.ONE
    for _j in num_tiles + extra_near:
      var s: Sprite2D = Sprite2D.new()
      s.centered = false
      s.texture = _tex[i]
      s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
      s.material = _mat
      parents[i].add_child(s)
      _sides[i].append(s)


func _layout(frac: float) -> void:
  for i in _sides.size():
    _layout_side(i, frac)


func _layout_side(i: int, frac: float) -> void:
  var arr: Array = _sides[i]
  var tex: Texture2D = _tex[i]
  var cw: float = _cell_w[i]
  var ch: float = _cell_h[i]
  var tw: float = float(tex.get_width())
  var th: float = float(tex.get_height())
  var r: float = depth_ratio
  var n: int = arr.size()
  for slot in n:
    # The first `extra_near` slots are over-sized (off-screen) tiles that recycle
    # while fully off-screen, so no fade is needed (opaque the whole pass).
    var e: float = float(slot - extra_near) - frac
    var sc: float = pow(r, e)                # cell scale (grows as you approach)
    var outer: float = cw * sc / (1.0 - r)   # vanishing point -> outer edge
    var s: Sprite2D = arr[slot]
    s.position = Vector2(-outer, -ch * sc * 0.5)    # outer edge out, centred
    s.scale = Vector2(cw / tw * sc, ch / th * sc)   # fill the reference cell
    s.z_index = n - slot                     # nearer in front


func _wall_nodes() -> Array:
  var nodes: Array = []
  for arr in _sides:
    nodes.append_array(arr)
  return nodes


## Scale multiplier for an object sitting on the corridor's central axis at
## `depth_cells` deep — the SAME perspective law the walls use (`depth_ratio^e`).
## An on-axis object always projects to the vanishing point (the node origin), so
## only its scale changes with depth: `0` = at the mouth / full size, larger =
## deeper / smaller. The combat view uses this to scale the enemy occupant on the
## approach, keeping it locked to the wall perspective. See docs/history/phase4_plan.md.
func axis_scale(depth_cells: float) -> float:
  return pow(depth_ratio, depth_cells)
