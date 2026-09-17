class_name PrintPanel
extends LookPanel
## The print panel (docs/systems/print_frame.md, docs/systems/panel_wear.md), toggled with F5 by
## `DebugPanels`: the printed look around the corridor and on UI panels. One section per group of the
## background wear, then Layout (the padding and split point of the screen sections), then the border and the wear over the corridor,
## then the panel wear groups. Its saved looks are print looks, in `DebugPanelsAutoload.PRINT_LOOK_DIR`,
## separate from the look panel's; reset leaves the corridor look alone.

## Print frame settings shown in the Layout section: setting -> [min, max, step].
const LAYOUT_PROPERTIES: Dictionary = {
  'padding': [0.0, 160.0, 1.0],
  'split_across': [800.0, 2400.0, 1.0],
  'split_down': [600.0, 1400.0, 1.0],
}


func rebuild() -> void:
  _built = true
  _clear_sections()
  _build_shader_sections(PrintLook.background_material, PrintLook.background_defaults())
  var layout: LookSection = _add_section('Layout')
  for setting: String in LAYOUT_PROPERTIES:
    var set_value: Callable = func(new_value: Variant) -> void: PrintLook.print_settings[setting] = new_value
    layout.add_row(_make_row(setting.capitalize(), PrintLook.print_setting(setting), LAYOUT_PROPERTIES[setting], set_value))
  _build_shader_sections(PrintLook.border_material, PrintLook.print_defaults())
  _build_shader_sections(PrintLook.overlay_material, PrintLook.print_defaults())
  _build_shader_sections(PrintLook.panel_material, PrintLook.panel_defaults())


func _look_dir() -> String:
  return DebugPanelsAutoload.PRINT_LOOK_DIR


func _save_look(path: String) -> void:
  PrintLook.save_print_look(path)


func _load_look(path: String) -> bool:
  return PrintLook.load_print_look(path)


func _reset_look() -> void:
  PrintLook.reset_print_look()
