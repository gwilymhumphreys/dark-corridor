class_name Not
extends RunCondition
## Holds when `condition` does not.

var condition: RunCondition


func _init(inner: RunCondition) -> void:
  condition = inner


func holds(run: RunManager) -> bool:
  return not condition.holds(run)
