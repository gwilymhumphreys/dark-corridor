class_name SellButton
extends Button
## The Sell button shown below a selected board item (docs/systems/run_screen.md → Selling items). Its
## text gives the price; pressing it emits `sell_requested(item)`, and the run screen sells through
## RunManager.sell_item. The run screen places it each frame. Reads the item; writes nothing.

signal sell_requested(item: Item)

const GAP: float = 8.0   # pixels between the item's cell and the button

var item: Item


func _exit_tree() -> void:
  item = null


## Show the button for `target`, which sells for `price` gold.
func setup(target: Item, price: int) -> void:
  item = target
  text = tr('Sell for {0} gold').format([price])
  size = get_combined_minimum_size()


## Place the button centred below `cell_rect` (global), kept inside `screen`.
func place_below(cell_rect: Rect2, screen: Rect2) -> void:
  var spot := Vector2(cell_rect.get_center().x - size.x * 0.5, cell_rect.end.y + GAP)
  global_position = spot.clamp(screen.position, screen.end - size)


func _on_pressed() -> void:
  sell_requested.emit(item)
