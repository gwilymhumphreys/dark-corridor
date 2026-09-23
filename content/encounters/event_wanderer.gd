extends EncounterDef
## Placeholder recruit event (decision #1): one option adds an ally for the rest of the run, the
## other declines for a small heal.


func _init() -> void:
  id = 'event_wanderer'
  type = Type.EVENT
  name_key = 'A figure in the dark'
  event_prose_key = 'A gaunt shape uncurls from a recess, a notched blade across its knees. ' \
    + 'It rasps an offer: walk together a while, and it will fight at your side.'
  var welcome := EventOptionDef.new()
  welcome.label_key = 'Let it join you'
  welcome.effect = EventOptionDef.Effect.ADD_ALLY
  welcome.ally_def_id = 'spore_thrall'
  var refuse := EventOptionDef.new()
  refuse.label_key = 'Walk on alone'
  refuse.effect = EventOptionDef.Effect.HEAL_FRACTION
  refuse.amount = 0.15
  event_options = [welcome, refuse]
