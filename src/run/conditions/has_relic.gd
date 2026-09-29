class_name HasRelic
extends RunCondition
## Holds when the run holds the relic `relic_id`.

var relic_id: String = ''


func _init(id: String) -> void:
  relic_id = id


func holds(run: RunManager) -> bool:
  return run.relics.any(func(relic: Relic) -> bool: return relic.def.id == relic_id)
