class_name BackgroundPanel
extends LookPanel
## The background tab of the debug panel (docs/systems/background_wear.md), opened with F4 by
## `DebugPanels`: the print wear on every screen background. One section per group of the background
## wear shader. The wear over the corridor, the border and the panel wear are in the Print tab
## (`PrintPanel`).


func rebuild() -> void:
  _built = true
  _clear_sections()
  _build_shader_sections(PrintLook.background_material, PrintLook.background_defaults())
