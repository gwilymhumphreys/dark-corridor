class_name StatusIcon
extends Control
## One active status in a StatusIcons row (docs/systems/run_screen.md): the status's icon on a
## square of its colour (the Frame panel), so the colour shows as a border, with its stacks (when more than one) in a value pill (the same
## pill as an item's values) centred on the bottom-left corner,
## half outside the frame. The pill is the size every value pill is (the `pill_size` print setting),
## whatever the icon's size. Hovering it shows the printed hover border on the Frame and the status's
## tooltip (docs/systems/tooltips.md). Reads the status; writes nothing.

const FRAME_MARGIN: float = 3.0   # how much of the colour square shows around the icon

## The status shown, for the tooltip. Cleared when the icon leaves the tree.
var status: StatusEffect = null

## True while the tooltip poll reports this icon as the one under the pointer. Like a board item's
## cell, the icon takes no mouse events of its own; the framed combat view sets this.
var hovered: bool = false:
  set(value):
    if hovered == value:
      return
    hovered = value
    _hover_to(1.0 if value else 0.0)
    if value:
      SfxManager.play_ui_hover()

@onready var _frame: PanelContainer = $Frame
@onready var _icon: TextureRect = $Frame/Icon
@onready var _count: ValuePill = $Count

var _icon_path: String = ''
var _frame_color: Color = Color.TRANSPARENT
var _pill_text: String = ''
var _pill_color: Color = Color.TRANSPARENT
var _pill_ratio: float = 0.0
var _hover: float = 0.0
var _hover_tween: Tween


func _ready() -> void:
  # The hover border is drawn by panel wear, so it goes on the Frame, whose worn panel is the colour square.
  ControlFeedback.attach(_frame, false)


## Show `status`. Loads the icon only when it differs from the one already shown, because the
## row calls this every frame.
func show_status(shown: StatusEffect) -> void:
  status = shown
  if shown.color != _frame_color:
    # The colour comes from the status, so the square's style is built here, like a value pill's.
    _frame_color = shown.color
    var fill: StyleBoxFlat = StyleBoxFlat.new()
    fill.bg_color = shown.color
    fill.set_content_margin_all(FRAME_MARGIN)
    var worn: WornStyleBox = WornStyleBox.new()
    worn.base = fill
    _frame.add_theme_stylebox_override('panel', worn)
  _count.visible = shown.count > 1   # a single stack needs no number
  var text: String = str(shown.count)
  var ratio: float = PrintLook.print_setting('pill_size')
  if text != _pill_text or shown.color != _pill_color or ratio != _pill_ratio:
    # ValuePill.setup builds a new style, so it is only redone when the pill changes.
    _pill_text = text
    _pill_color = shown.color
    _pill_ratio = ratio
    _count.setup(text, shown.color, ratio)
    var pill_size: Vector2 = _count.get_combined_minimum_size()
    _count.size = pill_size
    _count.position = Vector2(-pill_size.x * 0.5, custom_minimum_size.y - pill_size.y * 0.5)
  if shown.icon == _icon_path:
    return
  _icon_path = shown.icon
  _icon.texture = load(_icon_path) as Texture2D if _icon_path != '' else null


func _hover_to(amount: float) -> void:
  if not is_node_ready():
    return
  if _hover_tween and _hover_tween.is_valid():
    _hover_tween.kill()
  var set_hover: Callable = func(value: float) -> void:
    _hover = value
    ControlFeedback.set_hover(_frame, value)
  _hover_tween = create_tween()
  _hover_tween.tween_method(set_hover, _hover, amount, ControlFeedback.setting_float('hover_time'))


func _exit_tree() -> void:
  if _hover_tween and _hover_tween.is_valid():
    _hover_tween.kill()
  _hover_tween = null
  status = null
  _icon.texture = null
