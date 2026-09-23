extends ItemDef
## Iron Maiden — a slow item that only applies bleed (owner, 2026-09-23). Its whole budget goes on
## bleed: N stacks deal N + (N-1) + ... + 1 damage as the enemy is hit, priced at the bleed rate
## (docs/design/item_heuristics.md). It has no type yet: it is not clearly a weapon, and which type
## it should be is the owner's to decide (docs/design/smith.md).


func _init() -> void:
  id = 'iron_maiden'
  name_key = 'Iron Maiden'
  types = []                         # no type yet — owner's to decide
  mechanics = [BleedMechanic.ID]
  icon = 'res://assets/icons/items/aura_coffin_nb.png'   # PLACEHOLDER icon — owner's to swap
  rarity = Rarity.UNCOMMON
  cooldown = 10.0
  effects = [ItemEffect.make(BleedMechanic.ID, 29.0, ItemEffect.Shape.OPPONENT_LEFTMOST)]
