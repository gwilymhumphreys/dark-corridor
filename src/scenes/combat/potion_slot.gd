class_name PotionSlot
extends Button
## One potion in the combat view's potion row (docs/systems/run_screen.md): a button wrapping the same
## `ItemCell` the board items use, bound to an Item built from the potion's definition (a potion is an
## item definition), so it has the same icon, value pills and tooltip as an item. Built like
## `reward_option.tscn`. The view connects `pressed` to the throw and sizes and tilts the cell with the
## board's. Reads the Consumable; writes nothing.

@onready var cell: ItemCell = $Cell

var consumable: Consumable


func setup(target: Consumable) -> void:
  consumable = target
  cell.show_cooldown = false   # a potion has no timer
  cell.setup(Item.new(consumable.def))


## The Item the cell shows (built from the potion's definition, no owner) — the tooltip reads it.
func item() -> Item:
  return cell.item


## Size the button and its cell together, to the board's cell size.
func set_cell_size(px: float) -> void:
  custom_minimum_size = Vector2(px, px)
  size = custom_minimum_size
  cell.set_cell_size(px)


func _exit_tree() -> void:
  consumable = null
