class_name KeybindRow
extends HBoxContainer
## One action's row on the settings screen's Controls tab: its name and a button per slot (main key,
## spare key), docs/systems/keybindings.md. Clicking a button waits for the next key press and binds
## it; Escape or a mouse click cancels, and a right click empties the slot. Reads and writes
## `Keybinds` only; the settings screen keeps one row capturing at a time and shows the messages.

## A slot was rebound. `taken_from` is the action that lost the key, or ''.
signal bound(taken_from: String)
## This row started waiting for a key.
signal capture_started()
## The key pressed is one the game keeps (`Keybinds.is_reserved`).
signal reserved_key_pressed()

const NO_SLOT: int = -1

var action: String = ''

var _capturing_slot: int = NO_SLOT

@onready var _name: Label = $Name
@onready var _buttons: Array[Button] = [$MainButton, $SpareButton]


func _ready() -> void:
  set_process_input(false)
  for slot in _buttons.size():
    _buttons[slot].pressed.connect(_start_capture.bind(slot))
    _buttons[slot].gui_input.connect(_on_button_gui_input.bind(slot))
  refresh()


## Set the action this row shows. Call before or after adding the row to the tree.
func setup(new_action: String) -> void:
  action = new_action
  if is_node_ready():
    refresh()


func refresh() -> void:
  _name.text = action_name()
  var slots: Array[Dictionary] = Keybinds.slots(action)
  for slot in _buttons.size():
    if slot == _capturing_slot:
      _buttons[slot].text = tr('Press a key')
    else:
      var label: String = Keybinds.slot_label(slots[slot])
      _buttons[slot].text = label if label != '' else '-'


## The action's shown name. Each name is a literal inside `tr()` so the text extractor finds it.
func action_name() -> String:
  match action:
    'battle_speed_down':
      return tr('Slower battle speed')
    'battle_speed_up':
      return tr('Faster battle speed')
    'toggle_pause':
      return tr('Pause')
  return action


func is_capturing() -> bool:
  return _capturing_slot != NO_SLOT


func cancel_capture() -> void:
  if not is_capturing():
    return
  _capturing_slot = NO_SLOT
  set_process_input(false)
  refresh()


func _start_capture(slot: int) -> void:
  _capturing_slot = slot
  set_process_input(true)
  refresh()
  capture_started.emit()


# `_input` runs before the interface and `_unhandled_input`, so the captured key reaches nothing else.
func _input(event: InputEvent) -> void:
  if event is InputEventMouseButton and event.pressed:
    cancel_capture()   # not marked handled, so a click on another binding still starts that one
    return
  var key: InputEventKey = event as InputEventKey
  if key == null or not key.pressed or key.echo:
    return
  get_viewport().set_input_as_handled()
  var physical: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
  if physical == KEY_ESCAPE:
    cancel_capture()
    return
  if Keybinds.is_reserved(physical):
    reserved_key_pressed.emit()
    return
  var slot: int = _capturing_slot
  cancel_capture()
  bound.emit(Keybinds.bind(action, slot, physical))


func _on_button_gui_input(event: InputEvent, slot: int) -> void:
  var mouse: InputEventMouseButton = event as InputEventMouseButton
  if mouse != null and mouse.button_index == MOUSE_BUTTON_RIGHT and mouse.pressed:
    cancel_capture()
    Keybinds.clear(action, slot)
    refresh()
    bound.emit('')
    accept_event()
