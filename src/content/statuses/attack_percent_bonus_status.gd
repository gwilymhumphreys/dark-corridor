class_name AttackPercentBonusStatus
extends StatusEffect
## Attack Percent Bonus (PLACEHOLDER name — owner's to rename) — an item-targeted status that raises
## each attack its item fires by `count` percent, for the rest of the fight (docs/systems/mechanics.md
## → Attack bonuses). No timer; statuses are cleared at the end of a fight (#26). Reapply STACKS, so
## two +50% make +100%, the same as the additive combining rule.

const ID := 'attack_percent_bonus'


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
    return {'percent': count / 100.0}
  return {}
