extends EncounterDef
## Placeholder event (decision #1): prose and a choice between two outcomes on the player.


func _init() -> void:
  id = 'event_shrine'
  type = Type.EVENT
  name_key = 'A dripping shrine'
  image = 'res://assets/encounters/mystery_statue.jpg'   # placeholder image
  prose_key = 'A black idol slumps in an alcove, weeping cold water. ' \
    + 'You could kneel and drink, or pry the shard from its brow.'
  var pray := EventOptionDef.new()
  pray.label_key = 'Kneel and drink'
  pray.effects = [RunEffect.heal_fraction(0.4)]
  var pry := EventOptionDef.new()
  pry.label_key = 'Pry the shard loose'
  pry.effects = [RunEffect.max_hp(15)]
  event_options = [pray, pry]
