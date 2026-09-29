class_name HealthAbove
extends RunCondition
## Holds when the player's health is above `fraction` of their maximum health.

var fraction: float = 0.5


func _init(of_max: float) -> void:
  fraction = of_max


func holds(run: RunManager) -> bool:
  return float(run.player.hp) > fraction * float(run.player.max_hp)
