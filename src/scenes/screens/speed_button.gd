class_name SpeedButton
extends Button
## The always-visible battle-speed dial on the run HUD (docs/systems/ui_layout.md). A left
## click steps one notch faster and a right click one notch slower (Game.step_battle_speed,
## wrapping at either end of Balance.BATTLE_SPEEDS); the label reflects the
## live Game.battle_speed. The dial is a session preference on Game and this button is
## thin glue — the run screen applies the speed to each fight's Timekeeper base scale.


func _ready() -> void:
  gui_input.connect(_on_gui_input)
  pressed.connect(Game.cycle_battle_speed)
  Game.battle_speed_changed.connect(_refresh)
  _refresh(Game.battle_speed)


# A right click steps slower. The button's `pressed` only fires for the left button, so the
# right button is read here.
func _on_gui_input(event: InputEvent) -> void:
  var mouse: InputEventMouseButton = event as InputEventMouseButton
  if mouse != null and mouse.button_index == MOUSE_BUTTON_RIGHT and mouse.pressed:
    Game.step_battle_speed(-1)
    accept_event()


# The multiplier glyph is digits + 'x' — locale-neutral, so no tr() (localization.md).
# Whole speeds read '2x' and slow ones keep their decimal, '0.5x'.
func _refresh(speed: float) -> void:
  if is_equal_approx(speed, roundf(speed)):
    text = '%dx' % roundi(speed)
  else:
    text = '%sx' % String.num(speed, 1)


func _exit_tree() -> void:
  if Game.battle_speed_changed.is_connected(_refresh):
    Game.battle_speed_changed.disconnect(_refresh)
