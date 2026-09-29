class_name HasItems
extends RunCondition
## Holds when the player's board has at least `count` of each listed item id. Several ids make a
## combination: every one of them must be there.

var item_ids: Array[String] = []
var count: int = 1


func _init(ids: Array[String], at_least: int = 1) -> void:
  item_ids = ids
  count = at_least


func holds(run: RunManager) -> bool:
  for id: String in item_ids:
    var held: int = run.player.board.filter(func(item: Item) -> bool: return item.def.id == id).size()
    if held < count:
      return false
  return true
