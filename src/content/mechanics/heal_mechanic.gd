class_name HealMechanic
extends Mechanic
## Heal — the mechanic for restoring health (docs/plans/mechanics.md). Restores health up to
## maximum, then removes some poison, burn and bleed from the healed actor.

const ID := 'heal'


func _init() -> void:
  id = ID
  name_key = 'Heal'
  desc_key = 'Restores health.'   # PLACEHOLDER desc — owner writes
  icon = 'res://assets/icons/potions/alchemy_31_bigheal_flask.png'   # PLACEHOLDER icon
  status_id = ''


func color() -> Color:
  return Colours.HEAL


func land(delivery: Delivery, combat: CombatManager) -> void:
  # The next step of docs/plans/mechanics.md fills this in; nothing calls it yet.
  pass
