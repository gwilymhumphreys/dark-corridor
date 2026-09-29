class_name AnyOf
extends RunCondition
## Holds when at least one of `conditions` does. (A plain list of conditions, as in
## EncounterDef.requires, already means all of them.)

var conditions: Array[RunCondition] = []


func _init(any: Array[RunCondition]) -> void:
  conditions = any


func holds(run: RunManager) -> bool:
  return conditions.any(func(condition: RunCondition) -> bool: return condition.holds(run))
