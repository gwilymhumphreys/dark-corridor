class_name SliderValueLabel
extends Label
## A number that sits above a slider's handle and shows the slider's value as a whole number. Put it
## as the direct child of an HSlider. It follows the handle as it moves, and repositions when the
## slider is resized or the text size setting changes.
##
## The parent slider is not a container, so this label places itself.

## Text shown after the number, such as '%'.
@export var suffix: String = ''

var _slider: HSlider


func _ready() -> void:
  _slider = get_parent() as HSlider
  if _slider == null:
    push_warning('SliderValueLabel must be a child of an HSlider')
    return
  auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
  horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  mouse_filter = Control.MOUSE_FILTER_IGNORE
  _slider.value_changed.connect(_on_value_changed)
  _slider.resized.connect(_refresh)
  _refresh()


func _notification(what: int) -> void:
  if what == NOTIFICATION_THEME_CHANGED and _slider != null:
    _refresh.call_deferred()


func _on_value_changed(_value: float) -> void:
  _refresh()


## Set the text, shrink to fit it, then centre it above where the slider draws its handle, kept
## within the slider's width so the scroll area does not cut it off at either end.
func _refresh() -> void:
  text = str(roundi(_slider.value)) + suffix
  reset_size()
  var grabber: Texture2D = _slider.get_theme_icon('grabber')
  var grabber_width: float = grabber.get_width() if grabber != null else 0.0
  var handle_x: float = grabber_width * 0.5 + _slider.get_as_ratio() * (_slider.size.x - grabber_width)
  var x: float = clampf(handle_x - size.x * 0.5, 0.0, maxf(0.0, _slider.size.x - size.x))
  position = Vector2(x, -size.y)
