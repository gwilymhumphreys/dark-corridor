class_name MotionPanel
extends LookPanel
## The Motion tab of the debug panel (docs/systems/debug_panel.md), opened with F7 by `DebugPanels`:
## how controls answer the pointer (docs/systems/control_feedback.md), then the screen's animations:
## the encounter cards dealt before a fight and the character photos on character select
## (docs/systems/run_screen.md), the page turn (docs/systems/page_turn.md) and the reward spin of the
## draft and shop goods. Each animation section has a button to play it again.

## The control feedback settings that are not shader uniforms, by section: setting -> [min, max, step].
const FEEDBACK_SECTIONS: Dictionary = {
  'Hover and press timing': {
    'hover_time': [0.0, 0.6, 0.01],
    'press_depth': [0.0, 8.0, 0.5],
    'bloom_time': [0.0, 0.6, 0.01],
  },
  'Hover and press text': {
    'text_hover': [0.0, 1.0, 0.01],
    'text_press': [0.0, 1.0, 0.01],
  },
}
## The animations' print frame settings, by section: setting -> [min, max, step] ([] for a switch, the
## option names for a dropdown).
const ANIMATION_SECTIONS: Dictionary = {
  'Encounter cards': {
    'card_deal_time': [0.05, 1.5, 0.05],
    'card_deal_gap': [0.0, 1.0, 0.05],
    'card_turn_time': [0.05, 1.0, 0.05],
    'card_tilt': [0.0, 15.0, 0.5],
    'card_spacing': [0.0, 1.0, 0.05],
    'deck_peek': [0.0, 1.0, 0.05],
  },
  'Character photos': {
    'photo_tilt': [0.0, 20.0, 0.5],
    'photo_shift': [0.0, 80.0, 1.0],
    'photo_slide_distance': [0.0, 1.5, 0.05],
    'photo_slide_time': [0.1, 2.0, 0.05],
  },
  'Page turn': {
    'page_turn_duration': [0.2, 4.0, 0.05],
    'page_turn_hold': [0.0, 1.0, 0.01],
    'page_turn_easing': [1.0, 5.0, 0.1],
    'page_turn_lead': [-1.5, 1.5, 0.05],
    'page_turn_bend': [0.5, 6.0, 0.1],
    'page_turn_corner': [-1.5, 1.5, 0.05],
    'page_turn_camera_distance': [1.0, 8.0, 0.1],
    'page_turn_camera_offset': [-1.0, 1.0, 0.05],
    'page_turn_light_across': [-1.5, 1.5, 0.05],
    'page_turn_light_down': [-1.5, 1.5, 0.05],
    'page_turn_shading': [0.0, 1.0, 0.01],
    'page_turn_highlight': [0.0, 1.0, 0.01],
    'page_turn_show_through': [0.0, 0.5, 0.01],
    'page_turn_shadow_darkness': [0.0, 1.0, 0.01],
    'page_turn_shadow_softness': [0.0, 1.0, 0.01],
    'page_turn_edge_width': [0.0, 8.0, 0.25],
  },
}
## The reward spin's print frame settings, by section. Labels drop the `reward_spin_` prefix.
const REWARD_SPIN_SECTIONS: Dictionary = {
  'Reward spin': {
    'reward_spin': [],
    'reward_spin_style': ['Reel', 'Flicker'],
    'reward_spin_time': [0.05, 3.0, 0.05],
    'reward_spin_gap': [0.0, 1.0, 0.05],
    'reward_spin_face_time': [0.01, 0.3, 0.01],
    'reward_spin_bump': [1.0, 1.6, 0.01],
  },
  'Reward reel': {
    'reward_spin_window': [1.0, 3.0, 0.05],
    'reward_spin_curve': [0.0, 1.0, 0.01],
    'reward_spin_darkening': [0.0, 1.0, 0.01],
    'reward_spin_bounce': [],
    'reward_spin_bounce_size': [0.0, 0.6, 0.01],
  },
}


func rebuild() -> void:
  _built = true
  _clear_sections()
  for title: String in FEEDBACK_SECTIONS:
    var section: LookSection = _add_section(title)
    var properties: Dictionary = FEEDBACK_SECTIONS[title]
    for setting: String in properties:
      var set_value: Callable = func(new_value: Variant) -> void: ControlFeedback.settings[setting] = new_value
      section.add_row(_make_row(setting.capitalize(), ControlFeedback.setting_value(setting), properties[setting], set_value))
  # The highlight shares panel wear's material (docs/systems/control_feedback.md); only its own
  # settings are listed here, and panel wear's own groups are on the Wear tab.
  _build_shader_sections(PrintLook.panel_material, ControlFeedback.defaults())
  _build_print_sections(ANIMATION_SECTIONS)
  _build_print_sections(REWARD_SPIN_SECTIONS, 'reward_spin_')
  _add_button('Encounter cards', 'Restart encounter',
    func() -> void: get_tree().call_group(RunScreen.GROUP, 'restart_encounter'))
  _add_button('Page turn', 'Replay', PageTurn.replay)
  _add_button('Reward spin', 'Spin again',
    func() -> void: get_tree().call_group(RunScreen.GROUP, 'spin_rewards_again'))


# A button at the end of the section called `title`.
func _add_button(title: String, text: String, pressed: Callable) -> void:
  for section: LookSection in _sections.get_children():
    if section.title() == title:
      var button: Button = Button.new()
      button.text = text
      button.pressed.connect(pressed)
      section.add_node(button)
      return


func _section_title(group: String) -> String:
  if group.begins_with('highlight_'):
    return group.capitalize() + ' (hover and press)'
  return super(group)
