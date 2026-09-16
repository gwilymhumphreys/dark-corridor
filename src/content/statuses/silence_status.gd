class_name SilenceStatus
extends StatusEffect
## Silence — the static gate (#14/#20): while it sits on an ITEM, that item's fire is suppressed
## (distinct from Blind's "fires but whiffs"). No ticker — it persists until the fight ends.

const ID := 'silence'


func _init() -> void:
  id = ID
  name_key = 'Silence'
  desc_key = 'The affected item cannot fire.'   # PLACEHOLDER desc — owner writes
  color = Colours.STATUS_SILENCE
  icon = 'res://assets/icons/statuses/skill_shackle_nb.png'


func gates_fire() -> bool:
  return true
