extends EncounterDef
## Placeholder elite (decision #2): two grunts, rewarding a relic and a draft.


func _init() -> void:
  id = 'fight_elite'
  type = Type.FIGHT
  name_key = 'An elite ambush'
  enemy_ids = ['grunt', 'grunt']
  reward = Reward.ELITE
