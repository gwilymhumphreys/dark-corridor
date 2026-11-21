class_name InterfaceLookPanel
extends LookPanel
## The Pictures tab of the debug panel (docs/systems/interface_look.md), opened with F3 by
## `DebugPanels`: one section per filter the interface look uses on pictures, health bars, value pills
## and the combat effects, built from its shader's uniform groups, the glow on interface nodes
## (docs/systems/interface_glow.md), and buttons that copy the shared settings from or to the corridor
## look. Its dithering is on the Colours tab, its picture wear on the Wear tab and the combat effects'
## own settings on the Effects tab.

## The interface glow settings: property -> [min, max, step], or the option names for a dropdown in
## `Environment.GlowBlendMode` order.
const GLOW_PROPERTIES: Dictionary = {
  'glow_intensity': [0.0, 8.0, 0.01],
  'glow_strength': [0.0, 2.0, 0.01],
  'glow_hdr_threshold': [0.0, 4.0, 0.01],
  'glow_blend_mode': ['Additive', 'Screen', 'Soft light', 'Replace', 'Mix'],
}

@onready var _copy_from_button: Button = $CopyRow/CopyFromButton
@onready var _copy_to_button: Button = $CopyRow/CopyToButton


func _ready() -> void:
  _copy_from_button.pressed.connect(_on_copy_from_pressed)
  _copy_to_button.pressed.connect(_on_copy_to_pressed)


func rebuild() -> void:
  _built = true
  _clear_sections()
  _build_shader_sections(InterfaceLook.material, InterfaceLook.defaults(),
    func(group: String) -> bool: return group != 'dithering' and group != 'effects' and not group.begins_with('picture_'))
  var glow: LookSection = _add_section('Glow (nodes made to glow from code)')
  for property: String in GLOW_PROPERTIES:
    var set_value: Callable = func(new_value: Variant) -> void:
      InterfaceGlow.settings[property] = new_value
      InterfaceGlow.apply_settings()
    glow.add_row(_make_row(property.trim_prefix('glow_').capitalize(), InterfaceGlow.setting(property), GLOW_PROPERTIES[property], set_value))


func _on_copy_from_pressed() -> void:
  InterfaceLook.copy_from_corridor()
  rebuild()


func _on_copy_to_pressed() -> void:
  InterfaceLook.copy_to_corridor()
  DebugPanels.refresh_look_panel()
