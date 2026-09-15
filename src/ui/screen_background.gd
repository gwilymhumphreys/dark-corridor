class_name ScreenBackground
extends NamedColourRect
## The colour rectangle behind a whole screen. It draws through `DebugPanels.background_material`
## (background_wear.gdshader), which can add print wear, and gives that shader its two mark colours
## from `Colours`. With every wear effect off it draws the plain colour
## (docs/systems/background_wear.md).


func _ready() -> void:
  super()
  material = DebugPanels.background_material
  material.set_shader_parameter('wear_dark_colour', Colours.UI_BACKGROUND_WEAR)
  material.set_shader_parameter('wear_light_colour', Colours.UI_BACKGROUND_WEAR_LIGHT)


func _exit_tree() -> void:
  material = null
