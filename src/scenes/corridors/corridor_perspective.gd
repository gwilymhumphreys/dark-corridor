class_name CorridorPerspective
extends CorridorRenderer
## Side walls as true perspective trapezoids: each cell is a Polygon2D quad with
## corners at the projected near plane (d) and far plane (d+1), subdivided into
## vertical strips (tapered with depth) to defeat affine texture swim. Floor and
## ceiling come from a static backdrop panel stretched to the view.
##
## Geometry is driven by the base `view_size`: the near wall fills the rect edges
## (× `overscan`) and recedes 1/d to the centre vanishing point. Side walls only.
##
## See docs/systems/corridors/perspective_quad.md.

@export var overscan: float = 1.05      ## near wall sits this much past the view edge (engulf)
@export var subdivisions: int = 12      ## vertical strips for the NEAREST cell (tapers to 1 far away)
@export var min_far_px: float = 2.0     ## keep adding depth cells until the far wall is this tall on screen
@export var show_backdrop: bool = true  ## off = magenta clear colour, to inspect wall tiling

# NOTE: the original Eye of the Beholder backdrop/wall art was removed; both
# placeholder on test_wall.png. BACKDROP wants a floor/ceiling panel and WALL_TEX
# a FLAT wall face (the renderer bakes the perspective) — swap in real art here.
const BACKDROP: Texture2D = preload('res://assets/sprites/test_wall.png')
const WALL_TEX: Texture2D = preload('res://assets/sprites/test_wall.png')

var num_segments: int = 6               ## computed in _build from min_far_px (depth in cells)
var _left: Array[Polygon2D] = []
var _right: Array[Polygon2D] = []
var _strips: Array[Vector3i] = []       ## one per polygon: (cell index, strip index, strips-in-cell)


func _build() -> void:
  # Clear any previous walls so this is safe to call again on resize (rebuild).
  for c in $LeftWalls.get_children():
    c.queue_free()
  for c in $RightWalls.get_children():
    c.queue_free()
  _left = []
  _right = []
  _strips = []

  # Backdrop fills the view rect, centred on the origin.
  $Backdrop.texture = BACKDROP
  $Backdrop.centered = true
  $Backdrop.position = Vector2.ZERO
  $Backdrop.scale = Vector2(view_size.x / float(BACKDROP.get_width()), view_size.y / float(BACKDROP.get_height()))
  $Backdrop.z_index = -2000             # behind even the farthest (sub-pixel) wall cell
  $Backdrop.visible = show_backdrop
  if not show_backdrop:
    RenderingServer.set_default_clear_color(Color(1, 0, 1))  # magenta = see gaps

  # Left wall in -X; right wall is the same, mirrored across the centre.
  $LeftWalls.position = Vector2.ZERO
  $LeftWalls.scale = Vector2.ONE
  $RightWalls.position = Vector2.ZERO
  $RightWalls.scale = Vector2(-1.0, 1.0)

  # Depth: near wall height = view_size.y*overscan at d=1, falling as 1/d.
  var near_wall_h: float = view_size.y * overscan
  num_segments = maxi(8, int(ceil(near_wall_h / maxf(min_far_px, 0.5))))

  # Tapered subdivisions: near cells get many strips (anti-swim); far tiny cells 1.
  for i in num_segments:
    var ki: int = clampi(int(round(float(subdivisions) / float(i + 1))), 1, subdivisions)
    for j in ki:
      _strips.append(Vector3i(i, j, ki))

  _spawn_side($LeftWalls, _left)
  _spawn_side($RightWalls, _right)


func _spawn_side(parent: Node2D, arr: Array[Polygon2D]) -> void:
  for _i in _strips.size():
    var p: Polygon2D = Polygon2D.new()
    p.texture = WALL_TEX
    p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    p.material = _mat
    parent.add_child(p)
    arr.append(p)


func _layout(frac: float) -> void:
  _layout_side(_left, frac)
  _layout_side(_right, frac)


func _layout_side(arr: Array[Polygon2D], frac: float) -> void:
  var w: float = float(WALL_TEX.get_width())
  var h: float = float(WALL_TEX.get_height())
  for idx in arr.size():
    var desc: Vector3i = _strips[idx]
    var i: int = desc.x       # cell index
    var j: int = desc.y       # strip index within cell
    var k: int = desc.z       # strips in this cell (tapers with depth)

    var d: float = float(i + 1) - frac
    var z_a: float = d + float(j) / float(k)
    var z_b: float = d + float(j + 1) / float(k)
    var u_a: float = float(j) / float(k) * w
    var u_b: float = float(j + 1) / float(k) * w

    var poly: Polygon2D = arr[idx]
    poly.polygon = PackedVector2Array([
      Vector2(_wall_x(z_a), _ceil_y(z_a)),    # near-top
      Vector2(_wall_x(z_b), _ceil_y(z_b)),    # far-top
      Vector2(_wall_x(z_b), _floor_y(z_b)),   # far-bottom
      Vector2(_wall_x(z_a), _floor_y(z_a)),   # near-bottom
    ])
    poly.uv = PackedVector2Array([
      Vector2(u_a, 0.0),
      Vector2(u_b, 0.0),
      Vector2(u_b, h),
      Vector2(u_a, h),
    ])
    poly.z_index = clampi(-int(d), -1900, 0)  # nearer (small d) in front


func _wall_x(d: float) -> float:
  return -(view_size.x * 0.5 * overscan) / d   # left edge; RightWalls mirrors


func _ceil_y(d: float) -> float:
  return -(view_size.y * 0.5 * overscan) / d


func _floor_y(d: float) -> float:
  return (view_size.y * 0.5 * overscan) / d


func _wall_nodes() -> Array:
  var nodes: Array = []
  nodes.append_array(_left)
  nodes.append_array(_right)
  return nodes
