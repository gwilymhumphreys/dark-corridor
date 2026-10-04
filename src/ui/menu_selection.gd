class_name MenuSelection
extends Node
## Keyboard and controller selection for a row or column of buttons (docs/systems/menu_selection.md).
## One button is selected at a time and shows the selected border (`ControlFeedback.set_selected`).
## Hovering a button selects it, and leaving it keeps it selected. Godot's `ui_*` actions move the
## selection along the row or column, stopping at the ends and skipping disabled buttons, and
## `ui_accept` presses the selected button. Add it to a screen's scene and hand it the buttons with
## `setup()`. Switch it off with `set_process_unhandled_input(false)` while something covers the
## buttons.

signal selection_changed(index: int)

## A column moves with `ui_up` and `ui_down`; a row moves with `ui_left` and `ui_right`.
@export var vertical: bool = true

## The selected button's position in the list, or -1 before `setup()`.
var index: int = -1

var _buttons: Array[BaseButton] = []


## Take `buttons` in order and select the one at `start`.
func setup(buttons: Array[BaseButton], start: int = 0) -> void:
  _buttons = buttons
  for i: int in _buttons.size():
    _buttons[i].mouse_entered.connect(_on_hovered.bind(i))
  select(start)


## Select the button at `at`. Does nothing for the button already selected, a disabled one or one
## outside the list.
func select(at: int) -> void:
  if at == index or at < 0 or at >= _buttons.size() or _buttons[at].disabled:
    return
  if index >= 0:
    ControlFeedback.set_selected(_buttons[index], false)
  index = at
  ControlFeedback.set_selected(_buttons[index], true)
  selection_changed.emit(index)


## The selected button, or null before `setup()`.
func selected() -> BaseButton:
  return _buttons[index] if index >= 0 else null


func _unhandled_input(event: InputEvent) -> void:
  if _buttons.is_empty() or PageTurn.is_turning():
    return
  if event.is_action_pressed('ui_up' if vertical else 'ui_left', true):
    _move(-1)
  elif event.is_action_pressed('ui_down' if vertical else 'ui_right', true):
    _move(1)
  elif event.is_action_pressed('ui_accept'):
    var button: BaseButton = selected()
    if button != null and not button.disabled:
      button.pressed.emit()
  else:
    return
  get_viewport().set_input_as_handled()


# The next enabled button in `step`'s direction; none past the ends.
func _move(step: int) -> void:
  var at: int = index + step
  while at >= 0 and at < _buttons.size() and _buttons[at].disabled:
    at += step
  if at < 0 or at >= _buttons.size():
    return
  select(at)
  SfxManager.play_ui_hover()


func _on_hovered(at: int) -> void:
  select(at)
