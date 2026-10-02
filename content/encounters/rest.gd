extends EncounterDef
## A rest that restores a share of maximum health.


func _init() -> void:
  id = 'rest'
  type = Type.REST
  name_key = 'A quiet alcove'
  image = 'res://assets/encounters/blue_light.jpg'   # placeholder image
  prose_key = 'Water drips somewhere in the dark. For a while nothing finds you, and you rest.'   # placeholder text
  heal_fraction = 0.3
  reward = Reward.NONE
