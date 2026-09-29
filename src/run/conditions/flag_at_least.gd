class_name FlagAtLeast
extends RunCondition
## Holds when the run flag `flag` (RunManager.flags) is at least `value`. An unset flag is 0.

var flag: String = ''
var value: int = 1


func _init(flag_name: String, at_least: int = 1) -> void:
  flag = flag_name
  value = at_least


func holds(run: RunManager) -> bool:
  return run.flag(flag) >= value
