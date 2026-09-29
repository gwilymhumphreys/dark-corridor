class_name HasItemType
extends RunCondition
## Holds when the player's board has at least `count` items with the type tag `item_type`
## (`ItemDef.types`, such as ItemType.WEAPON).

var item_type: String = ''
var count: int = 1


func _init(type_tag: String, at_least: int = 1) -> void:
  item_type = type_tag
  count = at_least


func holds(run: RunManager) -> bool:
  return run.player.board.filter(func(item: Item) -> bool: return item_type in item.def.types).size() >= count
