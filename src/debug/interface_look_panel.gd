class_name InterfaceLookPanel
extends LookPanel
## The interface tab of the debug panel (docs/systems/interface_look.md), opened with F2 by
## `DebugPanels`: one section per effect the interface look uses, built from its shader's uniform
## groups, and buttons that copy the shared settings from or to the corridor look. Above those,
## one section per group of palette colours in `src/data/colours.gd`, each row a colour picker that
## writes its colour to the custom palette (docs/systems/interface_palette.md).

## The palette colours, by section title, in the order `src/data/colours.gd` declares them. Each
## entry is the `Colours` variable names that section shows. `COOLDOWN_FILL` is left out of the
## `Combat view` section: it is translucent and a `.gpl` file carries no alpha, so it is not
## settable from a palette.
const COLOUR_SECTIONS: Dictionary = {
  'Mechanics': ['ATTACK', 'SHIELD', 'HEAL', 'POISON', 'BURN', 'BLEED', 'REGEN', 'CRIT', 'CHARGE', 'DECHARGE'],
  'Statuses': ['STATUS_WEAK', 'STATUS_VULNERABLE', 'STATUS_BLIND', 'STATUS_SILENCE', 'STATUS_SPORES', 'STATUS_DECAY', 'STATUS_EMPOWERED'],
  'Combat payloads / item panels': ['ARCANE'],
  'Relic panels': ['RELIC_STONE_WARD', 'RELIC_VITAL_CHARM', 'RELIC_IRON_IDOL'],
  'Beat / encounter categories': ['BEAT_BOSS', 'BEAT_RELIC', 'BEAT_REST', 'BEAT_EVENT', 'BEAT_COMBAT'],
  'Combat view': ['PORTRAIT_PLAYER', 'PORTRAIT_ENEMY', 'HP_BAR_BG', 'HP_BAR_FILL', 'ENEMY_HP_BAR_BG', 'ENEMY_HP_BAR_FILL', 'COOLDOWN_RING', 'ALLY_DOWNED'],
  'Map strip': ['MAP_TRACK', 'MAP_CURRENT_HALO', 'MAP_CLEARED', 'MAP_ARROW', 'MAP_LABEL', 'MAP_ROLLED_BEAT'],
  'Tooltip': ['RARITY_COMMON', 'RARITY_UNCOMMON', 'RARITY_RARE', 'TOOLTIP_CHANGED'],
  'Interface': ['UI_BACKGROUND', 'UI_BACKGROUND_WEAR', 'UI_BACKGROUND_WEAR_LIGHT', 'UI_PANEL_SHADOW', 'UI_PANEL', 'UI_PANEL_EDGE', 'UI_PANEL_LIGHT', 'UI_PANEL_WEAR', 'UI_PANEL_WEAR_LIGHT', 'UI_TEXT_DISABLED', 'UI_TEXT_PRESSED', 'UI_TEXT_DIM', 'UI_TEXT_BUTTON', 'UI_TEXT'],
  'Control feedback': ['UI_BUTTON', 'UI_BUTTON_LIGHT', 'UI_TEXT_BUTTON_DARK', 'UI_HIGHLIGHT'],
}

@onready var _copy_from_button: Button = $CopyRow/CopyFromButton
@onready var _copy_to_button: Button = $CopyRow/CopyToButton


func _ready() -> void:
  _copy_from_button.pressed.connect(_on_copy_from_pressed)
  _copy_to_button.pressed.connect(_on_copy_to_pressed)


func rebuild() -> void:
  _built = true
  _clear_sections()
  _build_colour_sections()
  _build_shader_sections(InterfaceLook.material, InterfaceLook.defaults())


# One section per group in `COLOUR_SECTIONS`, each row a colour picker for a `Colours` variable.
# A change calls `InterfacePalette.write_custom`, which writes the custom palette and applies it.
func _build_colour_sections() -> void:
  for section_title: String in COLOUR_SECTIONS:
    var section: LookSection = _add_section(section_title)
    for variable: String in COLOUR_SECTIONS[section_title]:
      var label: String = (variable.to_lower().replace('_', ' ')).capitalize()
      var colour: Color = (Colours as Script).get(variable)
      section.add_row(_make_row(label, colour, [], func(new_value: Color) -> void:
        InterfacePalette.write_custom(variable, new_value)))


# Picture wear sections name what they apply to, so they are not mistaken for the panel wear on the
# borders around the images (Print tab). The Picture Wear switch turns all of them on or off.
func _section_title(group: String) -> String:
  if group == 'picture_wear':
    return 'Picture Wear (switches all picture wear: icons, portraits, bars)'
  if group.begins_with('picture_'):
    return group.capitalize() + ' (icons, portraits, bars)'
  return super(group)


func _on_copy_from_pressed() -> void:
  InterfaceLook.copy_from_corridor()
  rebuild()


func _on_copy_to_pressed() -> void:
  InterfaceLook.copy_to_corridor()
  DebugPanels.refresh_look_panel()
