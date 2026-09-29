class_name GoldAtLeast
extends RunCondition
## Holds when the run's gold is at least `amount`.

var amount: int = 0


func _init(at_least: int) -> void:
  amount = at_least


func holds(run: RunManager) -> bool:
  return run.gold >= amount
