extends EncounterDef
## Placeholder tougher regular fight (decision #1): one brute.


func _init() -> void:
  id = 'fight_tough'
  type = Type.FIGHT
  name_key = 'A blocked passage'
  enemy_ids = ['brute']
  reward = Reward.NONE
