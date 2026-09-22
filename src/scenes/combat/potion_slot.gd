class_name PotionSlot
extends Button
## One potion in the combat view's potion row (docs/systems/run_screen.md): a button wrapping the same
## `ItemCell` the board items use, showing the potion's icon (`ConsumableDef.icon`), so potions and
## items look alike. Built like `reward_option.tscn`. The view connects `pressed` to the throw and sizes
## and tilts the cell with the board's. Reads the Consumable; writes nothing.

@onready var cell: ItemCell = $Cell

var consumable: Consumable


func setup(target: Consumable) -> void:
  consumable = target
  var path: String = consumable.def.icon
  cell.show_picture(load(path) as Texture2D if path != '' else null)


## Size the button and its cell together, to the board's cell size.
func set_cell_size(px: float) -> void:
  custom_minimum_size = Vector2(px, px)
  size = custom_minimum_size
  cell.set_cell_size(px)


func _exit_tree() -> void:
  consumable = null
