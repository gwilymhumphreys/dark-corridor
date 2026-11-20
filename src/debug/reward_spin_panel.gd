class_name RewardSpinPanel
extends LookPanel
## The reward spin tab of the debug panel (docs/systems/debug_panel.md), opened with F8 by
## `DebugPanels`: the slot-machine reveal of the draft and shop goods (`RewardSpin`,
## docs/systems/run_screen.md → Overlays). These are print frame settings
## (`PrintLook.PRINT_SETTING_DEFAULTS`), so a look preset saves them with its Print part; the tab has no
## preset row of its own.

## The settings by section: section title -> {setting -> [min, max, step]} ([] for a switch, the
## option names for a dropdown, in the order of the enum they index).
const SECTIONS: Dictionary = {
  'Spin': {
    'reward_spin': [],
    'reward_spin_style': ['Reel', 'Flicker'],
    'reward_spin_time': [0.05, 3.0, 0.05],
    'reward_spin_gap': [0.0, 1.0, 0.05],
    'reward_spin_face_time': [0.01, 0.3, 0.01],
    'reward_spin_bump': [1.0, 1.6, 0.01],
  },
  'Reel': {
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
  for title: String in SECTIONS:
    var section: LookSection = _add_section(title)
    section.set_open(true)
    var settings: Dictionary = SECTIONS[title]
    for setting: String in settings:
      var set_value: Callable = func(new_value: Variant) -> void: PrintLook.set_print_value(setting, new_value)
      var label: String = setting.trim_prefix('reward_spin_').capitalize() if setting != 'reward_spin' else 'On'
      section.add_row(_make_row(label, PrintLook.print_setting(setting), settings[setting], set_value))
    if title == 'Spin':
      var respin: Button = Button.new()
      respin.text = 'Spin again'
      respin.pressed.connect(func() -> void: get_tree().call_group(RunScreen.GROUP, 'spin_rewards_again'))
      section.add_node(respin)
