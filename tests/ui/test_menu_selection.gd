extends GutTest
## MenuSelection: one button of a row or column is selected; hovering selects, the `ui_*` actions move
## the selection without wrapping and skip disabled buttons, and `ui_accept` presses the selected one.

var _selection: MenuSelection = null
var _buttons: Array[BaseButton] = []
var _presses: Array[int] = []


func before_each() -> void:
  TestCleanup.reset_all_managers()
  var holder: Control = Control.new()
  add_child_autofree(holder)
  _buttons = []
  _presses = []
  for i: int in 4:
    var button: Button = Button.new()
    holder.add_child(button)
    button.pressed.connect(_presses.append.bind(i))
    _buttons.append(button)
  _selection = MenuSelection.new()
  holder.add_child(_selection)


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_setup_selects_the_start_button() -> void:
  _selection.setup(_buttons, 2)
  assert_eq(_selection.index, 2)
  assert_eq(_selection.selected(), _buttons[2])


func test_down_and_up_move_the_selection_and_stop_at_the_ends() -> void:
  _selection.setup(_buttons)
  _selection._unhandled_input(_action('ui_up'))
  assert_eq(_selection.index, 0, 'no wrapping past the first button')
  _selection._unhandled_input(_action('ui_down'))
  assert_eq(_selection.index, 1)
  for i: int in 5:
    _selection._unhandled_input(_action('ui_down'))
  assert_eq(_selection.index, 3, 'no wrapping past the last button')


func test_a_row_moves_with_left_and_right() -> void:
  _selection.vertical = false
  _selection.setup(_buttons)
  _selection._unhandled_input(_action('ui_down'))
  assert_eq(_selection.index, 0, 'a row ignores up and down')
  _selection._unhandled_input(_action('ui_right'))
  assert_eq(_selection.index, 1)
  _selection._unhandled_input(_action('ui_left'))
  assert_eq(_selection.index, 0)


func test_moving_skips_disabled_buttons() -> void:
  _buttons[1].disabled = true
  _selection.setup(_buttons)
  _selection._unhandled_input(_action('ui_down'))
  assert_eq(_selection.index, 2)


func test_hovering_selects_and_leaving_keeps_it() -> void:
  watch_signals(_selection)
  _selection.setup(_buttons)
  _buttons[3].mouse_entered.emit()
  _buttons[3].mouse_exited.emit()
  assert_eq(_selection.index, 3)
  assert_signal_emitted_with_parameters(_selection, 'selection_changed', [3])


func test_hovering_a_disabled_button_does_not_select_it() -> void:
  _buttons[2].disabled = true
  _selection.setup(_buttons)
  _buttons[2].mouse_entered.emit()
  assert_eq(_selection.index, 0)


func test_accept_presses_the_selected_button() -> void:
  _selection.setup(_buttons, 1)
  _selection._unhandled_input(_action('ui_accept'))
  assert_eq(_presses, [1])


func test_switched_off_it_reads_no_keys() -> void:
  _selection.setup(_buttons)
  _selection.set_process_unhandled_input(false)
  get_viewport().push_input(_action('ui_down'))
  assert_eq(_selection.index, 0)


func _action(action: String) -> InputEventAction:
  var event: InputEventAction = InputEventAction.new()
  event.action = action
  event.pressed = true
  return event
