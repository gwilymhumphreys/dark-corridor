class_name NamedColourRect
extends ColorRect
## A ColorRect that takes its colour from a `Colours` variable when it enters the tree, and again
## whenever an interface palette (docs/systems/interface_palette.md) is applied or reset. The `color`
## saved in the scene is only the editor preview.

## The `Colours` variable to use, for example `HP_BAR_FILL`.
@export var colour_name: String = ''


func _enter_tree() -> void:
  _copy_colour()
  DebugPanels.interface_palette_changed.connect(_copy_colour)


func _exit_tree() -> void:
  DebugPanels.interface_palette_changed.disconnect(_copy_colour)


func _copy_colour() -> void:
  var colour: Variant = (Colours as Script).get(colour_name)
  if colour is Color:
    color = colour
  else:
    push_warning('[NamedColourRect] Colours has no colour named %s' % colour_name)
