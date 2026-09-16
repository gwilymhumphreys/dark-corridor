class_name ScreenBackground
extends NamedColourRect
## The colour rectangle behind a whole screen. It draws through `PrintLook.background_material`
## (background_wear.gdshader), which can add print wear, and gives that shader its two mark colours
## from `Colours`. With every wear effect off it draws the plain colour
## (docs/systems/background_wear.md).

## True on the run screen. Folds are drawn only while a background with this set is in the tree, so
## menus opened from the title screen have none and the settings screen opened during a run keeps them.
@export var folds_shown: bool = false

static var _fold_backgrounds: int = 0


func _enter_tree() -> void:
  super()
  if folds_shown:
    _fold_backgrounds += 1
  PrintLook.background_material.set_shader_parameter('folds_shown', _fold_backgrounds > 0)


func _ready() -> void:
  material = PrintLook.background_material


func _copy_colour() -> void:
  super()
  PrintLook.background_material.set_shader_parameter('wear_dark_colour', Colours.UI_BACKGROUND_WEAR)
  PrintLook.background_material.set_shader_parameter('wear_light_colour', Colours.UI_BACKGROUND_WEAR_LIGHT)


func _exit_tree() -> void:
  super()
  if folds_shown:
    _fold_backgrounds -= 1
  PrintLook.background_material.set_shader_parameter('folds_shown', _fold_backgrounds > 0)
  material = null
