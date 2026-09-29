class_name AttackBonusPassive
extends RelicPassive
## A relic passive of the attack bonus mechanic: adds the effect's value to every attack of the items
## it covers, for the whole fight. The tooltip line is the same as an item's attack bonus line.


func outgoing_bonus(target, item = null, mechanic_id: String = AttackMechanic.ID) -> Dictionary:
  if mechanic_id == AttackMechanic.ID and covers(target, item):
    return {'flat': effect.value}
  return {}
