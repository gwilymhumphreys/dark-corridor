class_name StatusIcon
extends ColorRect
## One active status in a StatusIcons row (docs/systems/run_screen.md): the status's icon on a
## square of its colour, so the colour shows as a border, with its stacks (when more than one) in a value pill (the same
## pill as an item's values) centred on the bottom-left corner,
## half outside the frame. The pill is the size every value pill is (the `pill_size` print setting),
## whatever the icon's size. Reads the status; writes nothing.

@onready var _icon: TextureRect = $Icon
@onready var _count: ValuePill = $Count

var _icon_path: String = ''
var _pill_text: String = ''
var _pill_color: Color = Color.TRANSPARENT
var _pill_ratio: float = 0.0


## Show `status`. Loads the icon only when it differs from the one already shown, because the
## row calls this every frame.
func show_status(status: StatusEffect) -> void:
  color = status.color
  _count.visible = status.count > 1   # a single stack needs no number
  var text: String = str(status.count)
  var ratio: float = PrintLook.print_setting('pill_size')
  if text != _pill_text or status.color != _pill_color or ratio != _pill_ratio:
    # ValuePill.setup builds a new style, so it is only redone when the pill changes.
    _pill_text = text
    _pill_color = status.color
    _pill_ratio = ratio
    _count.setup(text, status.color, ratio)
    var pill_size: Vector2 = _count.get_combined_minimum_size()
    _count.size = pill_size
    _count.position = Vector2(-pill_size.x * 0.5, custom_minimum_size.y - pill_size.y * 0.5)
  if status.icon == _icon_path:
    return
  _icon_path = status.icon
  _icon.texture = load(_icon_path) as Texture2D if _icon_path != '' else null


func _exit_tree() -> void:
  _icon.texture = null
