extends GutTest
## The HUD battle-speed dial — thin glue over Game.step_battle_speed. The label
## reflects the live Game.battle_speed; a left click steps faster, a right click slower.


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func test_label_opens_at_the_current_dial() -> void:
  var button: SpeedButton = preload('res://src/scenes/screens/speed_button.tscn').instantiate()
  add_child(button)
  assert_eq(button.text, '1x', 'opens at ×1')
  button.free()


func test_label_tracks_the_dial() -> void:
  var button: SpeedButton = preload('res://src/scenes/screens/speed_button.tscn').instantiate()
  add_child(button)
  Game.cycle_battle_speed()
  assert_eq(button.text, '2x', 'the label follows Game.battle_speed')
  Game.set_battle_speed_index(0)
  assert_eq(button.text, '0.1x', 'slow speeds show their decimal')
  button.free()


func test_pressing_cycles_the_game_dial() -> void:
  var button: SpeedButton = preload('res://src/scenes/screens/speed_button.tscn').instantiate()
  add_child(button)
  button.pressed.emit()
  assert_eq(Game.battle_speed_index, Balance.BATTLE_SPEED_DEFAULT_INDEX + 1,
    'a press advances the Game dial one notch')
  button.free()


func test_right_click_steps_the_dial_down() -> void:
  var button: SpeedButton = preload('res://src/scenes/screens/speed_button.tscn').instantiate()
  add_child(button)
  var click := InputEventMouseButton.new()
  click.button_index = MOUSE_BUTTON_RIGHT
  click.pressed = true
  button.gui_input.emit(click)
  assert_eq(Game.battle_speed_index, Balance.BATTLE_SPEED_DEFAULT_INDEX - 1,
    'a right click moves the Game dial one notch slower')
  button.free()
