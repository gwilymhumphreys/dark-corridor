class_name LookRow
extends HBoxContainer
## One setting in the look panel (docs/systems/corridor_look.md): a label and one control. The
## same script drives three scenes: a slider (`Slider`), a switch (`Check`) or a colour button
## (`Colour`).

signal value_changed(value: Variant)


## Set the label, value and slider limits ([min, max, step]; ignored by switches and colours). Call
## before adding the row to the tree.
func setup(label_text: String, value: Variant, limits: Array) -> void:
  ($Label as Label).text = label_text
  if has_node('Slider'):
    var slider: HSlider = $Slider
    if limits.size() >= 2:
      slider.min_value = limits[0]
      slider.max_value = limits[1]
    slider.step = limits[2] if limits.size() >= 3 else 0.01
    slider.set_value_no_signal(value)
    _show_value(value)
    slider.value_changed.connect(_on_slider_changed)
  elif has_node('Check'):
    var check: CheckButton = $Check
    check.set_pressed_no_signal(value)
    check.toggled.connect(func(on: bool) -> void: value_changed.emit(on))
  elif has_node('Colour'):
    var colour: ColorPickerButton = $Colour
    colour.color = value
    colour.color_changed.connect(func(new_colour: Color) -> void: value_changed.emit(new_colour))


func _on_slider_changed(value: float) -> void:
  _show_value(value)
  value_changed.emit(value)


func _show_value(value: float) -> void:
  ($Value as Label).text = str(snappedf(value, 0.001))
