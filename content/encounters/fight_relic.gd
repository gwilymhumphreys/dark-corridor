extends EncounterDef
## Placeholder relic fight (decision #2): one grunt, rewarding a relic only.


func _init() -> void:
  id = 'fight_relic'
  type = Type.FIGHT
  name_key = 'A warded vault'
  enemy_ids = ['grunt']
  reward = Reward.RELIC
