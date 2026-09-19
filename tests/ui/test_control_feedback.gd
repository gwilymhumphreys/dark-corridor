extends GutTest
## Control feedback: the highlight `ControlFeedback` draws on hovered, selected and pressed controls,
## its settings, and the hover and press tweens `UIJuice` drives (docs/systems/control_feedback.md).


func before_each() -> void:
  TestCleanup.reset_all_managers()


func after_each() -> void:
  TestCleanup.reset_all_managers()


func _button_with_juice() -> Button:
  var button: Button = Button.new()
  button.text = 'Press'
  button.size = Vector2(120, 40)
  var juice: UIJuice = UIJuice.new()
  button.add_child(juice)
  add_child_autofree(button)
  return button


func test_defaults_list_the_settings_but_not_the_colours_or_per_control_values() -> void:
  var defaults: Dictionary = ControlFeedback.defaults()
  assert_true(defaults.has('highlight_border_width'), 'border width is a setting')
  assert_true(defaults.has('highlight_fill_hover'), 'the hover fill is a setting')
  for uniform: String in ControlFeedback.COLOUR_UNIFORMS:
    assert_false(defaults.has(uniform), '%s is set from Colours or per control, not a setting' % uniform)


func test_settings_are_written_read_and_reset() -> void:
  ControlFeedback.set_setting('highlight_border_width', 7.0)
  ControlFeedback.set_setting('hover_time', 0.4)
  var file: ConfigFile = ConfigFile.new()
  ControlFeedback.write_look(file)
  assert_eq(file.get_value('control_highlight', 'highlight_border_width'), 7.0)
  assert_eq(file.get_value('control_settings', 'hover_time'), 0.4)
  ControlFeedback.reset()
  assert_eq(ControlFeedback.setting_float('hover_time'), ControlFeedback.SETTING_DEFAULTS['hover_time'], 'reset drops the timing change')
  ControlFeedback.read_look(file)
  assert_eq(ControlFeedback.setting_value('highlight_border_width'), 7.0, 'the preset is read back')
  assert_eq(ControlFeedback.setting_float('hover_time'), 0.4, 'the timing setting is read back')


func test_a_juiced_button_takes_a_highlight_and_drops_it_when_freed() -> void:
  var before: int = ControlFeedback.highlight_count()
  var button: Button = _button_with_juice()
  assert_true(ControlFeedback.has_highlight(button), 'the button has a highlight while it is in the tree')
  assert_eq(ControlFeedback.highlight_count(), before + 1, 'one more control has one')
  button.free()
  assert_eq(ControlFeedback.highlight_count(), before, 'the highlight goes with the button')


func test_hovering_a_button_darkens_its_text_and_leaving_puts_it_back() -> void:
  var button: Button = _button_with_juice()
  var resting: Color = button.get_theme_color('font_color')
  button.mouse_entered.emit()
  await wait_seconds(ControlFeedback.setting_float('hover_time') + 0.1)
  var hovered: Color = button.get_theme_color('font_color')
  assert_lt(hovered.v, resting.v, 'the text darkens as the body lights up')
  button.mouse_exited.emit()
  await wait_seconds(ControlFeedback.setting_float('hover_time') + 0.1)
  assert_almost_eq(button.get_theme_color('font_color').v, resting.v, 0.01, 'leaving puts the text back')


func test_a_card_takes_the_border_only() -> void:
  var card: Button = Button.new()
  var juice: UIJuice = UIJuice.new()
  juice.preset = UIJuice.Preset.CARD
  card.add_child(juice)
  add_child_autofree(card)
  var resting: Color = card.get_theme_color('font_color')
  card.mouse_entered.emit()
  await wait_seconds(ControlFeedback.setting_float('hover_time') + 0.1)
  assert_eq(card.get_theme_color('font_color'), resting, 'a card whose body is a picture keeps its text colour')
