class_name FightBetween
extends RunCondition
## Holds when the next fight's number is from `first` to `last`, counting the run's fights from 1
## (RunMap.fight_number counts from 0). At a choice beat the next fight is the one straight after it.

var first: int = 1
var last: int = RunMap.TOTAL_FIGHTS


func _init(from_fight: int, to_fight: int = RunMap.TOTAL_FIGHTS) -> void:
  first = from_fight
  last = to_fight


func holds(run: RunManager) -> bool:
  var fight: int = RunMap.fight_number(run.position) + 1
  return fight >= first and fight <= last
