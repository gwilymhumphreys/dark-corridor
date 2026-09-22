class_name TokensPanel
extends LookPanel
## The tokens tab of the debug panel (docs/systems/print_frame.md), opened with F7 by `DebugPanels`:
## how items, potions and, when switched on, portraits look as cardboard tokens on the board grid.
## These are print frame settings (`PrintLook.PRINT_SETTING_DEFAULTS`), so a look preset saves them
## with its Print part; the tab has no preset row of its own.

## The token settings by section: section title -> {setting -> [min, max, step]} ([] for a switch or
## a colour).
const SECTIONS: Dictionary = {
  'Placement': {
    'token_tilt': [0.0, 15.0, 0.1],
    'token_shift': [0.0, 20.0, 0.5],
  },
  'Shadow': {
    'token_shadow_size': [0.0, 24.0, 1.0],
    'token_shadow_offset': [0.0, 16.0, 1.0],
    'token_shadow_darkness': [0.0, 1.0, 0.01],
  },
  'Fill': {
    'token_fill_colour': [],
    'token_fill_amount': [0.0, 1.0, 0.01],
  },
  'Portraits': {
    'token_portraits': [],
    'portrait_panel': [],
  },
}


func rebuild() -> void:
  _built = true
  _clear_sections()
  for title: String in SECTIONS:
    var section: LookSection = _add_section(title)
    var settings: Dictionary = SECTIONS[title]
    for setting: String in settings:
      var set_value: Callable = func(new_value: Variant) -> void: PrintLook.set_print_value(setting, new_value)
      section.add_row(_make_row(setting.capitalize(), PrintLook.print_setting(setting), settings[setting], set_value))
