class_name BlindStatus
extends TimedStatus
## Blind — the evasion status (docs/systems/spore_engine.md Cap 2): while it sits on an actor, that actor's
## outgoing DAMAGE Deliveries whiff (the "acts but misses" of blinding, distinct from Silence's
## "doesn't fire"). Timed; further applications extend the duration (TimedStatus stack default).

const ID := 'blind'


func _init() -> void:
  id = ID
  name_key = 'Blind'
  color = Colours.STATUS_BLIND


func causes_evasion() -> bool:
  return true
