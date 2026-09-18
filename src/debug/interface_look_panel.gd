class_name InterfaceLookPanel
extends LookPanel
## The interface tab of the debug panel (docs/systems/interface_look.md), opened with F3 by
## `DebugPanels`: one section per effect the interface look uses, built from its shader's uniform
## groups, and buttons that copy the shared settings from or to the corridor look. A Glow section sets
## the interface glow (docs/systems/interface_glow.md).

## Interface glow settings shown in the Glow section: property -> [min, max, step] (option names for the
## blend mode).
const GLOW_PROPERTIES: Dictionary = {
  'glow_intensity': [0.0, 8.0, 0.01],
  'glow_strength': [0.0, 2.0, 0.01],
  'glow_hdr_threshold': [0.0, 4.0, 0.01],
  'glow_blend_mode': ['Additive', 'Screen', 'Softlight', 'Replace', 'Mix'],
}

@onready var _copy_from_button: Button = $CopyRow/CopyFromButton
@onready var _copy_to_button: Button = $CopyRow/CopyToButton


func _ready() -> void:
  _copy_from_button.pressed.connect(_on_copy_from_pressed)
  _copy_to_button.pressed.connect(_on_copy_to_pressed)


func rebuild() -> void:
  _built = true
  _clear_sections()
  _build_shader_sections(InterfaceLook.material, InterfaceLook.defaults())
  var glow: LookSection = _add_section('Glow')
  for property: String in GLOW_PROPERTIES:
    var set_value: Callable = func(new_value: Variant) -> void:
      InterfaceGlow.settings[property] = new_value
      InterfaceGlow.apply_settings()
    glow.add_row(_make_row(property.trim_prefix('glow_').capitalize(), InterfaceGlow.setting(property), GLOW_PROPERTIES[property], set_value))


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
