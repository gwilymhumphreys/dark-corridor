extends EncounterDef
## Placeholder elite (decision #2): two grunts, rewarding a relic.


func _init() -> void:
  id = 'fight_elite'
  type = Type.FIGHT
  name_key = 'An elite ambush'
  image = 'res://assets/encounters/fire_goblin.jpg'   # placeholder image
  enemy_ids = ['grunt', 'grunt']
  reward = Reward.ELITE
