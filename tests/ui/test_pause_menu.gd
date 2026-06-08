extends GutTest
## The pause overlay — thin: its two buttons emit the resume/quit intents the run
## screen wires up.


func test_resume_button_emits_resume() -> void:
  var menu: PauseMenu = preload('res://src/scenes/screens/pause_menu.tscn').instantiate()
  add_child(menu)
  watch_signals(menu)
  menu._resume_button.pressed.emit()
  assert_signal_emitted(menu, 'resume_pressed')
  menu.free()


func test_settings_button_emits_settings() -> void:
  var menu: PauseMenu = preload('res://src/scenes/screens/pause_menu.tscn').instantiate()
  add_child(menu)
  watch_signals(menu)
  menu._settings_button.pressed.emit()
  assert_signal_emitted(menu, 'settings_pressed')
  menu.free()


func test_quit_button_emits_quit() -> void:
  var menu: PauseMenu = preload('res://src/scenes/screens/pause_menu.tscn').instantiate()
  add_child(menu)
  watch_signals(menu)
  menu._quit_button.pressed.emit()
  assert_signal_emitted(menu, 'quit_pressed')
  menu.free()
