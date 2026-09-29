class_name AttackPercentBonusPassive
extends RelicPassive
## A relic passive of the attack percent bonus mechanic: raises every attack of the items it covers
## by the effect's value in percent, for the whole fight. The tooltip line is the same as an item's
## attack percent bonus line.


func outgoing_bonus(target, item = null, mechanic_id: String = AttackMechanic.ID) -> Dictionary:
  if mechanic_id == AttackMechanic.ID and covers(target, item):
    return {'percent': effect.value / 100.0}
  return {}
