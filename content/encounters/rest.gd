extends EncounterDef
## A rest that restores a share of maximum health.


func _init() -> void:
  id = 'rest'
  type = Type.REST
  name_key = 'A quiet alcove'
  image = 'res://assets/encounters/blue_light.jpg'   # placeholder image
  heal_fraction = 0.3
  reward = Reward.NONE
