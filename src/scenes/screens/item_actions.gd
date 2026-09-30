class_name ItemActions
extends HBoxContainer
## The buttons shown below a selected board item (docs/systems/run_screen.md → Selling and merging
## items): Sell, whose text gives the price, and Merge, shown only when the item can be merged.
## Pressing one emits `sell_requested(item)` or `merge_requested(item)`, and the run screen acts
## through RunManager. The run screen places the row each frame. Reads the item; writes nothing.

signal sell_requested(item: Item)
signal merge_requested(item: Item)

const GAP: float = 8.0   # pixels between the item's cell and the buttons

var item: Item

@onready var sell_button: Button = $SellButton
@onready var merge_button: Button = $MergeButton


func _exit_tree() -> void:
  item = null


## Show the buttons for `target`, which sells for `price` gold. Merge shows when `can_merge`, and says
## so when merging loses an enchantment (`loses_enchantment`).
func setup(target: Item, price: int, can_merge: bool, loses_enchantment: bool) -> void:
  item = target
  sell_button.text = tr('Sell for {0} gold').format([price])
  merge_button.visible = can_merge
  merge_button.text = tr('Merge (loses an enchantment)') if loses_enchantment else tr('Merge')
  size = get_combined_minimum_size()


## Place the row centred below `cell_rect` (global), kept inside `screen`.
func place_below(cell_rect: Rect2, screen: Rect2) -> void:
  var spot := Vector2(cell_rect.get_center().x - size.x * 0.5, cell_rect.end.y + GAP)
  global_position = spot.clamp(screen.position, screen.end - size)


func _on_sell_pressed() -> void:
  sell_requested.emit(item)


func _on_merge_pressed() -> void:
  merge_requested.emit(item)
