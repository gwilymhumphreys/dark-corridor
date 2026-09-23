extends EncounterDef
## Placeholder event (decision #1): prose and a choice between two outcomes on the player.


func _init() -> void:
  id = 'event_shrine'
  type = Type.EVENT
  name_key = 'A dripping shrine'
  event_prose_key = 'A black idol slumps in an alcove, weeping cold water. ' \
    + 'You could kneel and drink, or pry the shard from its brow.'
  var pray := EventOptionDef.new()
  pray.label_key = 'Kneel and drink'
  pray.effect = EventOptionDef.Effect.HEAL_FRACTION
  pray.amount = 0.4
  var pry := EventOptionDef.new()
  pry.label_key = 'Pry the shard loose'
  pry.effect = EventOptionDef.Effect.MAX_HP_BONUS
  pry.amount = 15.0
  event_options = [pray, pry]
