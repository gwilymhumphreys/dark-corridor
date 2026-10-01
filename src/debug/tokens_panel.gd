class_name TokensPanel
extends LookPanel
## The tokens tab of the debug panel (docs/systems/print_frame.md), opened with F7 by `DebugPanels`:
## how items, potions and, when switched on, portraits look as cardboard tokens on the board grid.
## These are print frame settings (`PrintLook.PRINT_SETTING_DEFAULTS`), so a look preset saves them
## with its Print part; the tab has no preset row of its own.

## The token settings by section: section title -> {setting -> [min, max, step]} ([] for a switch or
## a colour, the option names for a dropdown, in the order of the enum they index).
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
  'Encounter cards': {
    'card_deal_time': [0.05, 1.5, 0.05],
    'card_deal_gap': [0.0, 1.0, 0.05],
    'card_turn_time': [0.05, 1.0, 0.05],
    'card_tilt': [0.0, 15.0, 0.5],
    'card_spacing': [0.0, 1.0, 0.05],
    'deck_peek': [0.0, 1.0, 0.05],
  },
  'Paper burn': {
    'paper_burn_duration': [0.2, 6.0, 0.1],
    'paper_burn_raggedness': [0.0, 40.0, 0.5],
    'paper_burn_detail': [2.0, 60.0, 0.5],
    'paper_burn_ember_width': [0.0, 12.0, 0.25],
    'paper_burn_char_width': [0.0, 20.0, 0.25],
    'paper_burn_scorch_width': [0.0, 60.0, 0.5],
    'paper_burn_brightness': [1.0, 6.0, 0.05],
    'paper_burn_dither': [],
    'paper_burn_palette': [],
    'paper_burn_particles': [],
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


func rebuild() -> void:
  _built = true
  _clear_sections()
  for title: String in SECTIONS:
    var section: LookSection = _add_section(title)
    var settings: Dictionary = SECTIONS[title]
    for setting: String in settings:
      var set_value: Callable = func(new_value: Variant) -> void: PrintLook.set_print_value(setting, new_value)
      section.add_row(_make_row(setting.capitalize(), PrintLook.print_setting(setting), settings[setting], set_value))
    if title == 'Page turn':
      var replay: Button = Button.new()
      replay.text = 'Replay'
      replay.pressed.connect(PageTurn.replay)
      section.add_node(replay)
