class_name PassiveRegistry
## Which RelicPassive class a relic passive builds, chosen by its effect's mechanic (docs/systems/
## content.md → Relic). A mechanic with no class here cannot be a passive; the content checks fail
## for a relic that uses one.


## A new passive instance for `effect`, or null when its mechanic has no passive class.
static func create(effect: ItemEffect) -> RelicPassive:
  match effect.mechanic:
    AttackBonusMechanic.ID:
      return AttackBonusPassive.new(effect)
    AttackPercentBonusMechanic.ID:
      return AttackPercentBonusPassive.new(effect)
  return null


static func has(mechanic_id: String) -> bool:
  return create(ItemEffect.make(mechanic_id, 0.0, ItemEffect.Shape.ALL_OWN_ITEMS)) != null
