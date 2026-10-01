extends EncounterDef
## A regular fight against one grunt.


func _init() -> void:
  id = 'fight_grunt'
  type = Type.FIGHT
  name_key = 'A dim corridor'
  image = 'res://assets/encounters/bone_golem.jpg'   # placeholder image
  enemy_ids = ['grunt']
  reward = Reward.NONE
