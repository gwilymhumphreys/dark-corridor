extends EncounterDef
## Placeholder boss fight (decision #1) at the end of an act, rewarding a relic. On the final act the
## run manager ends the run instead.


func _init() -> void:
  id = 'fight_boss'
  type = Type.FIGHT
  name_key = 'The warden\'s gate'
  enemy_ids = ['boss']
  reward = Reward.RELIC
