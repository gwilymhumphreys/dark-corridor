class_name MapStrip
extends VBoxContainer
## The 1D progress map (docs/systems/ui_layout.md): the current act's squares (RunMap.SQUARES) under
## an "Act N" label, as a row of pencil grid squares with a small cardboard token in each, showing
## what the square is (a fight, an elite fight, the boss). The tokens are the
## medium token size, the same as the enemy items (the `medium_token_size` print setting), or smaller
## if the row would be wider than the strip. A cleared square's token is gone, burnt away when its fight
## was won (`burn_square`, the paper burn effect), or flipped over to its blank back, as the
## `map_cleared_look` print setting says. The current one has the highlight border.
## A choice of encounters is not a square: during one, and during the encounter picked from it, a
## marker sits on the line before the next square. Reads RunMap and the position it is handed; writes
## nothing. The label is laid out like the
## character sheet's other labels (the `SheetSection` theme variation).

## How a cleared square's token looks (the `map_cleared_look` print setting).
enum ClearedLook { FACE_DOWN, BURNT_AWAY }

const ITEM_CELL: PackedScene = preload('res://src/scenes/combat/item_cell.tscn')
const GAP_SHARE: float = 0.35   # the space around a token as a share of its size
const ICONS: Dictionary = {
  RunMap.Square.FIGHT: preload('res://assets/icons/map/fight.png'),
  RunMap.Square.ELITE: preload('res://assets/icons/map/elite.png'),
  RunMap.Square.BOSS: preload('res://assets/icons/map/boss.png'),
}

var _position: int = 0
var _set_up: bool = false
var _fitted: Vector4 = -Vector4.ONE   # the token size, tilt, shift and strip width last fitted to
var _as_pictures: bool = false   # the `map_icons_as_pictures` print setting the icons were drawn with
var _cleared_look: int = ClearedLook.BURNT_AWAY   # the `map_cleared_look` setting the tokens were drawn with
# Square index -> true for the current square's token once its burn has started, so it stays gone
# before the run moves past it; and square index -> PaperBurn while one is burning.
var _burnt: Dictionary = {}
var _burning: Dictionary = {}

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
  if PrintLook.print_setting('map_icons_as_pictures') != _as_pictures or PrintLook.print_setting('map_cleared_look') != _cleared_look:
    _update()


func setup(pos: int) -> void:
  _position = pos
  _set_up = true
  _update()


func mark_position(pos: int) -> void:
  _position = pos
  _update()


## Burn the current square's token away, when its fight has been won. Does nothing at a choice of
## encounters, or when cleared tokens are shown face down instead.
func burn_current_square() -> void:
  var current: Array = current_square()
  var index: int = current[0]
  if current[1] or index < 0 or _burnt.has(index) or PrintLook.print_setting('map_cleared_look') != ClearedLook.BURNT_AWAY:
    return
  _burnt[index] = true
  var burn: PaperBurn = PaperBurn.burn(_tokens.get_child(index) as ItemCell)
  _burning[index] = burn
  burn.finished.connect(_on_burn_finished.bind(index))


## Whether a square's token is burning now.
func is_burning(index: int) -> bool:
  return _burning.has(index)


func _on_burn_finished(index: int) -> void:
  _burning.erase(index)


## Which square the player is on, and whether they are at the choice of encounters before it rather
## than on it. Returns [square index, at_choice].
func current_square() -> Array:
  var square: int = RunMap.square_at(_position)
  if square != -1:
    return [square, false]
  return [RunMap.square_at(_position + 1), true]   # a choice always comes straight before a square


func _update() -> void:
  if not is_node_ready():
    return
  _act_label.text = tr('Act {0}').format([RunMap.act_of(_position) + 1])
  var current: Array = current_square() if _set_up else [0, false]
  _as_pictures = PrintLook.print_setting('map_icons_as_pictures')
  _cleared_look = PrintLook.print_setting('map_cleared_look')
  for index: int in _burnt.keys():
    if index != current[0]:
      _burnt.erase(index)   # the run has moved past it, so it counts as cleared anyway
  for index: int in RunMap.SQUARES.size():
    var token: ItemCell = _tokens.get_child(index)
    var kind: RunMap.Square = RunMap.SQUARES[index]
    var cleared: bool = index < current[0] or _burnt.has(index)
    var face_down: bool = cleared and _cleared_look == ClearedLook.FACE_DOWN
    token.show_picture(null if face_down else ICONS[kind])
    token.tint_picture(_icon_colour(kind), _as_pictures)
    if not _burning.has(index):   # a burning token hides itself when its burn ends
      token.modulate.a = 0.0 if cleared and _cleared_look == ClearedLook.BURNT_AWAY else 1.0
    token.set_marked(index == current[0] and not current[1])
  _marks.queue_redraw()


func _icon_colour(kind: RunMap.Square) -> Color:
  match kind:
    RunMap.Square.BOSS:
      return Colours.BEAT_BOSS
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


# During a choice of encounters, a marker on the grid line before the next square.
func _draw_marks() -> void:
  if not _set_up:
    return
  var current: Array = current_square()
  if not current[1]:
    return
  var square: float = _boxes.size.y
  _marks.draw_circle(Vector2(current[0] * square, square * 0.5), square * 0.12, Colours.MAP_CURRENT_HALO)
