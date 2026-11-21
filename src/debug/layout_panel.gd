class_name LayoutPanel
extends LookPanel
## The Layout tab of the debug panel (docs/systems/debug_panel.md), opened with F5 by `DebugPanels`:
## where things sit and how big they are. The screen sections' padding and the character sheet's gaps,
## then how items, potions and, when switched on, portraits sit as cardboard tokens on the board grid
## (docs/systems/print_frame.md), the character panels, item levels and the map. These are print frame
## settings (`PrintLook.PRINT_SETTING_DEFAULTS`).

## The settings by section: section title -> {setting -> [min, max, step]} ([] for a switch, the option
## names for a dropdown, in the order of the enum they index).
const SECTIONS: Dictionary = {
  'Spacing': {
    'padding': [0.0, 160.0, 1.0],
    'section_gap': [0.0, 120.0, 1.0],
    'label_gap': [0.0, 40.0, 1.0],
  },
  'Token placement': {
    'token_tilt': [0.0, 15.0, 0.1],
    'token_shift': [0.0, 20.0, 0.5],
  },
  'Token shadow': {
    'token_shadow_size': [0.0, 24.0, 1.0],
    'token_shadow_offset': [0.0, 16.0, 1.0],
    'token_shadow_darkness': [0.0, 1.0, 0.01],
  },
  'Token fill': {
    'token_fill_amount': [0.0, 1.0, 0.01],
  },
  'Portraits': {
    'token_portraits': [],
  },
  'Character panels': {
    'item_layout': ['Beside', 'Under bar', 'Name row'],
    'status_layout': ['Beside bar', 'Under bar', 'Under items'],
    'panel_background': ['None', 'Player and allies', 'Enemies', 'All'],
    'allies_box': [],
    'medium_token_size': [24.0, 120.0, 1.0],
    'ally_item_size': [24.0, 120.0, 1.0],
    'status_size': [16.0, 96.0, 1.0],
    'pill_size': [0.4, 1.6, 0.05],
  },
  'Item levels': {
    'level_tag_corner': ['Top left', 'Top right', 'Bottom left', 'Bottom right'],
    'level_tag_size': [0.4, 2.0, 0.05],
  },
  'Map': {
    'map_icons_as_pictures': [],
    'map_cleared_look': ['Face down', 'Burnt away'],
  },
}


func rebuild() -> void:
  _built = true
  _clear_sections()
  _build_print_sections(SECTIONS)

