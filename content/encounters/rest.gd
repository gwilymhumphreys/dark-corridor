extends EncounterDef
## A rest that restores a share of maximum health.


func _init() -> void:
  id = 'rest'
  type = Type.REST
  name_key = 'A quiet alcove'
  heal_fraction = 0.3
  reward = Reward.NONE
