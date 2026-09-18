class_name PotionSlot
extends Button
## One potion in the combat view's potion row (docs/systems/run_screen.md): the potion's icon
## (`ConsumableDef.icon`) on the potion colour. The view connects `pressed` to the throw.
## Reads the Consumable; writes nothing.

@onready var _icon: TextureRect = $Icon

var consumable: Consumable


func setup(target: Consumable) -> void:
  consumable = target
  var path: String = consumable.def.icon
  _icon.texture = load(path) as Texture2D if path != '' else null


func _exit_tree() -> void:
  _icon.texture = null
  consumable = null
