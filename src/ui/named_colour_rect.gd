class_name NamedColourRect
extends ColorRect
## A ColorRect that takes its colour from a `Colours` variable when it enters the tree, so an
## interface palette (docs/systems/interface_palette.md) reaches colours placed in scenes. The
## `color` saved in the scene is only the editor preview.

## The `Colours` variable to use, for example `HP_BAR_FILL`.
@export var colour_name: String = ''


func _ready() -> void:
  var colour: Variant = (Colours as Script).get(colour_name)
  if colour is Color:
    color = colour
  else:
    push_warning('[NamedColourRect] Colours has no colour named %s' % colour_name)
