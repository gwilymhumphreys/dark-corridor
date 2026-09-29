class_name TimesPicked
extends RunCondition
## Holds when the encounter `encounter_id` has been picked from a choice of encounters, and finished,
## at least `count` times this run (RunManager.times_picked). The visit in progress is not counted,
## so inside an encounter `TimesPicked.new(its_own_id)` means "this is a later visit". Wrap it in
## `Not` for "fewer than".

var encounter_id: String = ''
var count: int = 1


func _init(id: String, at_least: int = 1) -> void:
  encounter_id = id
  count = at_least


func holds(run: RunManager) -> bool:
  return int(run.times_picked.get(encounter_id, 0)) >= count
