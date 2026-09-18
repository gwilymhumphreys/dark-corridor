class_name PrintPanel
extends LookPanel
## The print tab of the debug panel (docs/systems/print_frame.md, docs/systems/panel_wear.md), opened
## with F3 by `DebugPanels`: the printed look around the corridor and on UI panels. Layout first (the
## padding and split point of the screen sections), then the border and the wear over the corridor,
## then the panel wear groups. The wear on screen backgrounds is in the Background tab
## (`BackgroundPanel`).

## Print frame settings shown in the Layout section: setting -> [min, max, step].
const LAYOUT_PROPERTIES: Dictionary = {
  'padding': [0.0, 160.0, 1.0],
  'split_across': [800.0, 2400.0, 1.0],
  'split_down': [600.0, 1400.0, 1.0],
}


func rebuild() -> void:
  _built = true
  _clear_sections()
  var layout: LookSection = _add_section('Layout')
  for setting: String in LAYOUT_PROPERTIES:
    var set_value: Callable = func(new_value: Variant) -> void: PrintLook.print_settings[setting] = new_value
    layout.add_row(_make_row(setting.capitalize(), PrintLook.print_setting(setting), LAYOUT_PROPERTIES[setting], set_value))
  _build_shader_sections(PrintLook.border_material, PrintLook.print_defaults())
  _build_shader_sections(PrintLook.overlay_material, PrintLook.print_defaults())
  _build_shader_sections(PrintLook.panel_material, PrintLook.panel_defaults())


# Panel wear sections name what they apply to, so they are not mistaken for the picture wear on the
# images inside panels (Interface tab).
func _section_title(group: String) -> String:
  if group.begins_with('panel_'):
    return group.capitalize() + ' (item borders and other panels)'
  return super(group)
