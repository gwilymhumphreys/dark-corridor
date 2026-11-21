class_name WearPanel
extends LookPanel
## The Wear tab of the debug panel (docs/systems/debug_panel.md), opened with F4 by `DebugPanels`: print
## wear everywhere it is drawn. Background wear on every screen (docs/systems/background_wear.md), panel
## wear on item borders and other panels (docs/systems/panel_wear.md), picture wear on icons, portraits
## and bars (docs/systems/interface_look.md#picture-wear), then the wear and worn edge over the
## corridor, the border and the pencil grid (docs/systems/print_frame.md).


func rebuild() -> void:
  _built = true
  _clear_sections()
  _build_shader_sections(PrintLook.background_material, PrintLook.background_defaults())
  _build_shader_sections(PrintLook.panel_material, PrintLook.panel_defaults())
  _build_shader_sections(InterfaceLook.material, InterfaceLook.defaults(),
    func(group: String) -> bool: return group.begins_with('picture_'))
  _build_shader_sections(PrintLook.overlay_material, PrintLook.print_defaults())
  _build_shader_sections(PrintLook.border_material, PrintLook.print_defaults())
  _build_shader_sections(PrintLook.grid_material, PrintLook.print_defaults())


# The headings say what each kind of wear applies to, because the borders around icons are panels
# and their wear is panel wear. The Picture Wear switch turns all picture wear on or off.
func _section_title(group: String) -> String:
  if group == 'picture_wear':
    return 'Picture Wear (switches all picture wear: icons, portraits, bars)'
  if group.begins_with('picture_'):
    return group.capitalize() + ' (icons, portraits, bars)'
  if group.begins_with('panel_'):
    return group.capitalize() + ' (item borders and other panels)'
  return super(group)
