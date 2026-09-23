class_name CombatSteps
extends RefCounted
## Test helpers for driving a CombatManager outside its step loop. File is NOT named `test_*` so
## GUT does not collect it as a test case.


## Fire `it` and return the deliveries that fire spawned, still in flight.
static func fire(cm: CombatManager, it: Item) -> Array:
  var before: int = cm._deliveries.size()
  cm._fire_item(it)
  return cm._deliveries.slice(before)


## Fire `it` and land every delivery that fire spawned, without waiting out their travel. For tests
## of what a delivery does on landing, separate from the step loop. Returns those deliveries.
static func fire_and_land(cm: CombatManager, it: Item) -> Array:
  var spawned: Array = fire(cm, it)
  for d in spawned:
    cm._land(d)
  return spawned
