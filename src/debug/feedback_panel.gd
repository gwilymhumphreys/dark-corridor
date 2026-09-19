class_name FeedbackPanel
extends LookPanel
## The feedback tab of the debug panel (docs/systems/control_feedback.md), opened with F5 by
## `DebugPanels`: how an interactive control answers the pointer. Timing first (how quickly the
## feedback comes in and how far a pressed control drops), then the border and fill groups of the
## control highlight shader.

## The settings that are not shader uniforms, by section: setting -> [min, max, step].
const SECTION_PROPERTIES: Dictionary = {
  'Timing': {
    'hover_time': [0.0, 0.6, 0.01],
    'press_depth': [0.0, 8.0, 0.5],
    'bloom_time': [0.0, 0.6, 0.01],
  },
  'Text': {
    'text_hover': [0.0, 1.0, 0.01],
    'text_press': [0.0, 1.0, 0.01],
  },
}


func rebuild() -> void:
  _built = true
  _clear_sections()
  for title: String in SECTION_PROPERTIES:
    var section: LookSection = _add_section(title)
    var properties: Dictionary = SECTION_PROPERTIES[title]
    for setting: String in properties:
      var set_value: Callable = func(new_value: Variant) -> void: ControlFeedback.settings[setting] = new_value
      section.add_row(_make_row(setting.capitalize(), ControlFeedback.setting_value(setting), properties[setting], set_value))
  # The highlight shares panel wear's material (docs/systems/control_feedback.md); only its own
  # settings are listed here, and panel wear's own groups stay in the Print tab.
  _build_shader_sections(PrintLook.panel_material, ControlFeedback.defaults())
