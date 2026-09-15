class_name PrintPanel
extends LookPanel
## The print panel (docs/systems/print_frame.md), toggled with F3 by `DebugPanels`: the printed look
## around the corridor. One section per group of the background wear, then Layout (the corridor
## margin), then the border and the wear over the corridor. Its saved looks are print looks, in
## `DebugPanelsAutoload.PRINT_LOOK_DIR`, separate from the look panel's; reset leaves the corridor look
## alone.

## Print frame settings shown in the Layout section: setting -> [min, max, step].
const LAYOUT_PROPERTIES: Dictionary = {
  'corridor_margin': [0.0, 160.0, 1.0],
}


func rebuild() -> void:
  _built = true
  _clear_sections()
  _build_shader_sections(DebugPanels.background_material, DebugPanels.background_defaults())
  var layout: LookSection = _add_section('Layout')
  for setting: String in LAYOUT_PROPERTIES:
    var set_value: Callable = func(new_value: Variant) -> void: DebugPanels.print_settings[setting] = new_value
    layout.add_row(_make_row(setting.capitalize(), DebugPanels.print_setting(setting), LAYOUT_PROPERTIES[setting], set_value))
  _build_shader_sections(DebugPanels.border_material, DebugPanels.print_defaults())
  _build_shader_sections(DebugPanels.overlay_material, DebugPanels.print_defaults())


func _look_dir() -> String:
  return DebugPanelsAutoload.PRINT_LOOK_DIR


func _save_look(path: String) -> void:
  DebugPanels.save_print_look(path)


func _load_look(path: String) -> bool:
  return DebugPanels.load_print_look(path)


func _reset_look() -> void:
  DebugPanels.reset_print_look()
