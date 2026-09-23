class_name AttackBonusStatus
extends StatusEffect
## Attack Bonus (PLACEHOLDER name — owner's to rename) — an item-targeted status that adds `count`
## flat damage to each attack its item fires, for the rest of the fight (docs/systems/mechanics.md →
## Attack bonuses). No timer; statuses are cleared at the end of a fight (#26). Reapply STACKS.

const ID := 'attack_bonus'


func _init() -> void:
  id = ID
  # Presentation is written once, in the mechanic (docs/systems/mechanics.md).
  var mechanic: Mechanic = MechanicRegistry.get_mechanic(ID)
  name_key = mechanic.name_key
  desc_key = mechanic.desc_key
  icon = mechanic.icon
  color = Colours.ATTACK


## Only the item this sits on gains the bonus.
func outgoing_bonus(target, item = null) -> Dictionary:
  if item != null and target == item:
    return {'flat': count}
  return {}
