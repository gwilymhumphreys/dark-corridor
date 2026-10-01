extends EncounterDef
## A regular fight against one grunt.


func _init() -> void:
  id = 'fight_grunt'
  type = Type.FIGHT
  name_key = 'A dim corridor'
  enemy_ids = ['grunt']
  reward = Reward.NONE
