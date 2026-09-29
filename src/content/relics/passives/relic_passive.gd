class_name RelicPassive
extends CombatHooks
## One always-on relic ability for one fight (docs/systems/content.md → Relic): built from an
## ItemEffect in RelicDef.passives by PassiveRegistry and held on the relic's Item (Item.passives).
## It is not a status, so nothing that removes, counts or consumes statuses reaches it; the hooks it
## overrides are called with the relic's owner as the holder. Stores only its effect, no actor or
## item reference, so it adds no reference cycle.

var effect: ItemEffect


func _init(passive_effect: ItemEffect) -> void:
  effect = passive_effect


## True when `item` is one of the holder's board items that the effect's shape and target filter
## pick. Only ALL_OWN_ITEMS picks items; a relic is never on the board, so it is never picked.
func covers(holder, item) -> bool:
  if item == null or holder == null or effect.shape != ItemEffect.Shape.ALL_OWN_ITEMS:
    return false
  if not holder.board.has(item):
    return false
  return effect.target_filter == null or effect.target_filter.matches(item)
