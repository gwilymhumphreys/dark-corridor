class_name FlagBelow
extends RunCondition
## Holds when the run flag `flag` (RunManager.flags) is below `value`. An unset flag is 0, so
## `FlagBelow.new('offering_left')` holds until the flag is set.

var flag: String = ''
var value: int = 1


func _init(flag_name: String, below: int = 1) -> void:
  flag = flag_name
  value = below


func holds(run: RunManager) -> bool:
  return run.flag(flag) < value
