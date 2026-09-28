class_name MapStrip
extends VBoxContainer
## The 1D progress map (docs/systems/ui_layout.md): the current act's squares (RunMap.SQUARES) under
## an "Act N" label, as a row of pencil grid squares with a small cardboard token in each, showing
## what the square is (a fight, an elite fight, the relic encounter, the boss). The tokens are the
## medium token size, the same as the enemy items (the `medium_token_size` print setting), or smaller
## if the row would be wider than the strip. A cleared square's token is flipped over (its blank back), and the current one has the highlight border.
## Events are not squares: during one, a marker sits on the line before the next square. Reads
## RunMap and the position and run seed it is handed; writes nothing. The label is laid out like the
## character sheet's other labels (the `SheetSection` theme variation).

const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')
const GAP_SHARE: float = 0.35   # the space around a token as a share of its size
const ICONS: Dictionary = {
  RunMap.Square.FIGHT: preload('res://assets/icons/map/fight.png'),
  RunMap.Square.ELITE: preload('res://assets/icons/map/elite.png'),
  RunMap.Square.RELIC: preload('res://assets/icons/map/relic.png'),
  RunMap.Square.BOSS: preload('res://assets/icons/map/boss.png'),
}

var _run_seed: int = 0
var _position: int = 0
var _set_up: bool = false
var _fitted: Vector4 = -Vector4.ONE   # the token size, tilt, shift and strip width last fitted to

@onready var _act_label: Label = $ActLabel
@onready var _track: Control = $Track
@onready var _boxes: ColorRect = $Track/Boxes
@onready var _tokens: HBoxContainer = $Track/Tokens
@onready var _marks: Control = $Track/Marks


func _ready() -> void:
  _boxes.material = PrintLook.grid_material
  _marks.draw.connect(_draw_marks)
  for square: int in RunMap.SQUARES.size():
    _tokens.add_child(ITEM_CELL.instantiate())
  _fit()
  _update()


func _exit_tree() -> void:
  _boxes.material = null


# The token size and the askew settings are print settings, so follow them and the strip's width as
# they change.
func _process(_delta: float) -> void:
  _fit()


func setup(run_seed: int, pos: int) -> void:
  _run_seed = run_seed
  _position = pos
  _set_up = true
  _update()


func mark_position(pos: int) -> void:
  _position = pos
  _update()


## Which square the player is on, and whether they are at the event before it rather than on it.
## Returns [square index, at_event].
func current_square() -> Array:
  var square: int = RunMap.square_at(_position, _run_seed)
  if square != -1:
    return [square, false]
  return [RunMap.square_at(_position + 1, _run_seed), true]   # an event always comes before a square


func _update() -> void:
  if not is_node_ready():
    return
  _act_label.text = tr('Act {0}').format([RunMap.act_of(_position) + 1])
  var current: Array = current_square() if _set_up else [0, false]
  for index: int in RunMap.SQUARES.size():
    var token: ItemCell = _tokens.get_child(index)
    var kind: RunMap.Square = RunMap.SQUARES[index]
    var cleared: bool = index < current[0]
    token.show_picture(null if cleared else ICONS[kind])   # a cleared square's token is face down
    token.tint_picture(_icon_colour(kind))
    token.set_marked(index == current[0] and not current[1])
  _marks.queue_redraw()


func _icon_colour(kind: RunMap.Square) -> Color:
  match kind:
    RunMap.Square.BOSS:
      return Colours.BEAT_BOSS
    RunMap.Square.RELIC:
      return Colours.BEAT_RELIC
  return Colours.UI_TEXT_DIM


# Size the tokens to the medium token size, shrunk if the row would be wider than the strip, with a
# gap of GAP_SHARE, and draw one pencil rectangle divided into a grid square per token (the grid
# material in box mode).
func _fit() -> void:
  var count: int = RunMap.SQUARES.size()
  var size_px: float = PrintLook.print_setting('medium_token_size')
  if _track.size.x > 0.0:
    size_px = minf(size_px, floorf((_track.size.x / count - 0.5) / (1.0 + GAP_SHARE)))   # 0.5: the gap is rounded up
  var tilt: float = PrintLook.print_setting('token_tilt')
  var shift: float = PrintLook.print_setting('token_shift') * size_px / ItemCell.CELL_SIZE.x
  var wanted: Vector4 = Vector4(size_px, tilt, shift, _track.size.x)
  if wanted == _fitted:
    return
  _fitted = wanted
  var gap: int = roundi(size_px * GAP_SHARE)
  var square: float = size_px + gap
  _track.custom_minimum_size.y = square
  _boxes.size = Vector2(square * count, square)
  var canvas_item: RID = _boxes.get_canvas_item()
  RenderingServer.canvas_item_set_instance_shader_parameter(canvas_item, 'box_size', _boxes.size)
  RenderingServer.canvas_item_set_instance_shader_parameter(canvas_item, 'box_cells', Vector2(count, 1))
  _tokens.add_theme_constant_override('separation', gap)
  _tokens.position = Vector2(gap, gap) * 0.5
  for token: Node in _tokens.get_children():
    (token as ItemCell).set_cell_size(size_px)
    (token as ItemCell).set_askew(tilt, shift)
  _tokens.reset_size()
  _marks.queue_redraw()


# During an event, a marker on the grid line before the next square.
func _draw_marks() -> void:
  if not _set_up:
    return
  var current: Array = current_square()
  if not current[1]:
    return
  var square: float = _boxes.size.y
  _marks.draw_circle(Vector2(current[0] * square, square * 0.5), square * 0.12, Colours.MAP_CURRENT_HALO)
