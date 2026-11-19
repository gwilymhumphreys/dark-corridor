extends ItemDef
## Poker — a slower smithing tool that only applies burn (owner, 2026-09-23); smithing tools lean
## towards burn (docs/design/smith.md). Its whole budget goes on burn, priced at the burn rate
## (docs/design/item_heuristics.md). A weapon, like the other smithing tools (2026-11-20, agent's
## pick for the owner to check).


func _init() -> void:
  id = 'poker'
  name_key = 'Poker'
  tags = [BurnMechanic.ID, ItemType.WEAPON]
  icon = 'res://assets/icons/items/poker.png'   # PLACEHOLDER icon — owner's to swap
  cooldown = 6.0
  effects = [ItemEffect.make(BurnMechanic.ID, 12.0, ItemEffect.Shape.OPPONENT_LEFTMOST)]
